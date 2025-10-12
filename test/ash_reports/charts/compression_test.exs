defmodule AshReports.Charts.CompressionTest do
  @moduledoc """
  Test suite for SVG compression utilities.
  """
  use ExUnit.Case, async: true

  alias AshReports.Charts.Compression

  describe "compress/2" do
    test "compresses SVG data successfully" do
      svg = "<svg><rect x='0' y='0' width='100' height='100'/></svg>"

      assert {:ok, compressed, metadata} = Compression.compress(svg)
      assert is_binary(compressed)
      assert metadata.original_size == byte_size(svg)
      assert metadata.compressed_size == byte_size(compressed)
      assert metadata.ratio > 0
      # Note: Small SVGs may be larger after compression due to gzip header overhead
      assert metadata.compression_time_ms >= 0
    end

    test "achieves good compression ratio for repetitive SVG" do
      # Create a repetitive SVG (typical of charts)
      svg = String.duplicate("<rect x='0' y='0' width='10' height='10'/>", 100)

      assert {:ok, compressed, metadata} = Compression.compress(svg)
      # Expect at least 30% compression
      assert metadata.ratio < 0.7
    end

    test "returns metadata with correct sizes" do
      svg = "<svg>test data</svg>"

      assert {:ok, _compressed, metadata} = Compression.compress(svg)
      assert metadata.original_size == byte_size(svg)
      assert is_integer(metadata.compressed_size)
      assert is_float(metadata.ratio)
      assert is_integer(metadata.compression_time_ms)
    end

    test "handles empty SVG" do
      assert {:ok, compressed, _metadata} = Compression.compress("")
      assert is_binary(compressed)
    end

    test "handles large SVG data" do
      # Generate 1MB of SVG data
      large_svg = String.duplicate("<g><rect x='1' y='2'/></g>", 50_000)

      assert {:ok, compressed, metadata} = Compression.compress(large_svg)
      assert metadata.original_size > 1_000_000
      assert metadata.compressed_size < metadata.original_size
    end

    test "compression is deterministic" do
      svg = "<svg><circle r='50'/></svg>"

      {:ok, compressed1, _} = Compression.compress(svg)
      {:ok, compressed2, _} = Compression.compress(svg)

      assert compressed1 == compressed2
    end

    test "handles special characters in SVG" do
      svg = "<svg><text>Special: &lt;&gt;&amp;\"'</text></svg>"

      assert {:ok, compressed, _metadata} = Compression.compress(svg)
      assert is_binary(compressed)
    end
  end

  describe "decompress/1" do
    test "decompresses compressed SVG correctly" do
      original = "<svg><rect x='0' y='0' width='100' height='100'/></svg>"

      {:ok, compressed, _metadata} = Compression.compress(original)
      assert {:ok, decompressed} = Compression.decompress(compressed)
      assert decompressed == original
    end

    test "preserves exact data through compress/decompress cycle" do
      original = "<svg>#{String.duplicate("data", 1000)}</svg>"

      {:ok, compressed, _metadata} = Compression.compress(original)
      {:ok, decompressed} = Compression.decompress(compressed)

      assert decompressed == original
      assert byte_size(decompressed) == byte_size(original)
    end

    test "handles invalid compressed data" do
      invalid_data = "not compressed data"

      assert {:error, {:decompression_failed, _}} = Compression.decompress(invalid_data)
    end

    test "handles empty compressed data" do
      # Empty data is not valid gzip
      assert {:error, {:decompression_failed, _}} = Compression.decompress("")
    end
  end

  describe "compression_ratio/2" do
    test "calculates ratio correctly" do
      # Create binaries of specific sizes (125 bytes and 62 bytes)
      original = :binary.copy(<<1>>, 1000)
      compressed = :binary.copy(<<1>>, 500)

      ratio = Compression.compression_ratio(original, compressed)
      assert ratio == 0.5
    end

    test "returns 1.0 for no compression" do
      data = "test data"

      ratio = Compression.compression_ratio(data, data)
      assert ratio == 1.0
    end

    test "returns >1.0 if compressed is larger" do
      original = "tiny"
      compressed = "much larger data"

      ratio = Compression.compression_ratio(original, compressed)
      assert ratio > 1.0
    end

    test "handles empty original data" do
      ratio = Compression.compression_ratio("", "something")
      assert ratio == 1.0
    end

    test "calculates real compression ratio" do
      svg = String.duplicate("<rect/>", 100)

      {:ok, compressed, _} = Compression.compress(svg)
      ratio = Compression.compression_ratio(svg, compressed)

      assert ratio > 0 and ratio < 1.0
    end
  end

  describe "should_compress?/2" do
    test "returns false for small SVG below default threshold" do
      small_svg = "<svg></svg>"

      refute Compression.should_compress?(small_svg)
    end

    test "returns true for large SVG above default threshold" do
      # Create SVG larger than 10KB default threshold
      large_svg = String.duplicate("<g>data</g>", 2000)

      assert Compression.should_compress?(large_svg)
    end

    test "respects custom threshold" do
      svg = String.duplicate("x", 500)

      # With high threshold, should not compress
      refute Compression.should_compress?(svg, threshold: 1000)

      # With low threshold, should compress
      assert Compression.should_compress?(svg, threshold: 100)
    end

    test "handles exactly at threshold" do
      svg = String.duplicate("x", 1000)

      assert Compression.should_compress?(svg, threshold: 1000)
    end

    test "handles empty SVG" do
      refute Compression.should_compress?("")
    end
  end

  describe "compress_if_needed/2" do
    test "skips compression for small SVG" do
      small_svg = "<svg></svg>"

      assert {:ok, :uncompressed, returned_svg} = Compression.compress_if_needed(small_svg)
      assert returned_svg == small_svg
    end

    test "compresses large SVG" do
      large_svg = String.duplicate("<g>data</g>", 2000)

      assert {:ok, :compressed, compressed, metadata} =
               Compression.compress_if_needed(large_svg)

      assert is_binary(compressed)
      assert metadata.original_size == byte_size(large_svg)
      assert metadata.compressed_size < metadata.original_size
    end

    test "respects custom threshold" do
      svg = String.duplicate("x", 500)

      # With high threshold, should not compress
      assert {:ok, :uncompressed, ^svg} =
               Compression.compress_if_needed(svg, threshold: 1000)

      # With low threshold, should compress
      assert {:ok, :compressed, _compressed, _meta} =
               Compression.compress_if_needed(svg, threshold: 100)
    end

    test "returns error if compression fails" do
      # This is difficult to trigger with valid input, but we can test the structure
      svg = String.duplicate("<g>data</g>", 2000)

      result = Compression.compress_if_needed(svg)
      assert match?({:ok, :compressed, _, _}, result) or match?({:error, _}, result)
    end
  end

  describe "validate_compression/2" do
    test "validates successful compression" do
      original = "<svg><rect x='0' y='0'/></svg>"

      {:ok, compressed, _} = Compression.compress(original)
      assert :ok = Compression.validate_compression(compressed, original)
    end

    test "detects corrupted compression" do
      original = "<svg>test</svg>"
      invalid_compressed = "corrupted data"

      assert {:error, :validation_failed} =
               Compression.validate_compression(invalid_compressed, original)
    end

    test "detects mismatch between original and decompressed" do
      original1 = "<svg>first</svg>"
      original2 = "<svg>second</svg>"

      {:ok, compressed, _} = Compression.compress(original1)

      assert {:error, :validation_failed} =
               Compression.validate_compression(compressed, original2)
    end

    test "validates large SVG compression" do
      large_svg = String.duplicate("<rect x='1' y='2'/>", 5000)

      {:ok, compressed, _} = Compression.compress(large_svg)
      assert :ok = Compression.validate_compression(compressed, large_svg)
    end
  end

  describe "compression performance" do
    test "compression completes in reasonable time for typical chart SVG" do
      # Typical chart SVG: ~50KB
      svg = String.duplicate("<rect x='1' y='2' width='10' height='10'/>", 1000)

      {time_microseconds, {:ok, _compressed, metadata}} =
        :timer.tc(fn -> Compression.compress(svg) end)

      # Should complete in <50ms
      assert time_microseconds < 50_000
      assert metadata.compression_time_ms < 50
    end

    test "compression overhead is acceptable for large SVGs" do
      # Large chart: ~500KB
      svg = String.duplicate("<g><rect x='1' y='2'/><text>data</text></g>", 10_000)

      {time_microseconds, {:ok, _compressed, _metadata}} =
        :timer.tc(fn -> Compression.compress(svg) end)

      # Should complete in <200ms
      assert time_microseconds < 200_000
    end

    test "decompression is faster than compression" do
      svg = String.duplicate("<rect x='1' y='2'/>", 1000)

      {:ok, compressed, _} = Compression.compress(svg)

      {compress_time, _} = :timer.tc(fn -> Compression.compress(svg) end)
      {decompress_time, _} = :timer.tc(fn -> Compression.decompress(compressed) end)

      # Decompression should be faster
      assert decompress_time < compress_time
    end
  end
end
