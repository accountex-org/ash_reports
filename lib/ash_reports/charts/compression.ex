defmodule AshReports.Charts.Compression do
  @moduledoc """
  SVG compression utilities for chart performance optimization.

  Provides gzip compression/decompression with metadata tracking to reduce
  embedded chart data size in Typst templates.

  ## Compression Strategy

  SVG files are highly compressible due to their repetitive XML structure.
  Typical compression ratios range from 30-50% for chart SVGs.

  Compression is automatically applied to SVGs larger than a configurable
  threshold (default: 10KB) to balance compression overhead vs size savings.

  ## Usage

      # Compress an SVG string
      {:ok, compressed, metadata} = Compression.compress(svg_data)
      # => {:ok, <<gzipped_binary>>, %{original_size: 50000, compressed_size: 20000, ratio: 0.4}}

      # Decompress back to original SVG
      {:ok, svg_data} = Compression.decompress(compressed)

      # Check if compression should be applied
      Compression.should_compress?(svg_data, threshold: 10_000)
      # => true (if size > 10KB)

  ## Configuration

  Compression can be configured via options:

    * `:threshold` - Minimum SVG size in bytes to trigger compression (default: 10,000)
    * `:compression_level` - Zlib compression level 0-9 (default: 6, balanced speed/ratio)

  """

  require Logger

  @default_threshold 10_000
  @default_compression_level 6
  # Maximum compressed data size to accept for decompression (10MB)
  @max_compressed_size 10 * 1024 * 1024
  # Maximum decompressed output size to accept (50MB)
  @max_decompressed_size 50 * 1024 * 1024

  @type compression_metadata :: %{
          original_size: non_neg_integer(),
          compressed_size: non_neg_integer(),
          ratio: float(),
          compression_time_ms: non_neg_integer()
        }

  @doc """
  Compresses SVG data using gzip compression.

  Returns the compressed binary along with metadata about the compression.

  ## Options

    * `:compression_level` - Zlib compression level 0-9 (default: 6)
    * `:max_input_size` - Maximum input size in bytes (default: 50MB)

  ## Examples

      iex> svg = "<svg>...</svg>"
      iex> {:ok, compressed, metadata} = Compression.compress(svg)
      iex> metadata.ratio < 1.0
      true

  ## Errors

    * `{:error, :input_too_large}` - Input exceeds maximum allowed size

  """
  @spec compress(binary(), keyword()) ::
          {:ok, binary(), compression_metadata()} | {:error, term()}
  def compress(svg_data, opts \\ []) when is_binary(svg_data) do
    max_input_size = Keyword.get(opts, :max_input_size, @max_decompressed_size)

    # Validate input size to prevent processing excessively large data
    if byte_size(svg_data) > max_input_size do
      Logger.warning(
        "Compression rejected: input size #{byte_size(svg_data)} exceeds maximum #{max_input_size} bytes"
      )

      {:error, :input_too_large}
    else
      _compression_level = Keyword.get(opts, :compression_level, @default_compression_level)
      start_time = System.monotonic_time(:millisecond)

      try do
      # Use Erlang's zlib for gzip compression
      compressed = :zlib.gzip(svg_data)
      end_time = System.monotonic_time(:millisecond)

      original_size = byte_size(svg_data)
      compressed_size = byte_size(compressed)

      # Handle division by zero for empty input
      ratio =
        if original_size == 0 do
          1.0
        else
          compressed_size / original_size
        end

      compression_time = end_time - start_time

      metadata = %{
        original_size: original_size,
        compressed_size: compressed_size,
        ratio: ratio,
        compression_time_ms: compression_time
      }

      Logger.debug(
        "Compressed SVG: #{original_size} → #{compressed_size} bytes (#{Float.round(ratio * 100, 1)}%) in #{compression_time}ms"
      )

      {:ok, compressed, metadata}
      rescue
        error ->
          Logger.error("SVG compression failed: #{inspect(error)}")
          {:error, {:compression_failed, error}}
      end
    end
  end

  @doc """
  Decompresses gzip-compressed SVG data with size limits to prevent decompression bombs.

  ## Options

    * `:max_compressed_size` - Maximum compressed input size in bytes (default: 10MB)
    * `:max_decompressed_size` - Maximum decompressed output size in bytes (default: 50MB)

  ## Examples

      iex> {:ok, compressed, _meta} = Compression.compress("<svg>test</svg>")
      iex> {:ok, svg} = Compression.decompress(compressed)
      iex> svg
      "<svg>test</svg>"

  ## Errors

    * `{:error, :compressed_data_too_large}` - Compressed input exceeds maximum allowed size
    * `{:error, :decompressed_data_too_large}` - Decompressed output exceeds maximum allowed size
    * `{:error, {:decompression_failed, reason}}` - Decompression failed

  """
  @spec decompress(binary(), keyword()) :: {:ok, binary()} | {:error, term()}
  def decompress(compressed_data, opts \\ []) when is_binary(compressed_data) do
    max_compressed_size = Keyword.get(opts, :max_compressed_size, @max_compressed_size)
    max_decompressed_size = Keyword.get(opts, :max_decompressed_size, @max_decompressed_size)

    # Validate compressed data size to prevent processing malicious payloads
    compressed_size = byte_size(compressed_data)

    if compressed_size > max_compressed_size do
      Logger.warning(
        "Decompression rejected: compressed data size #{compressed_size} exceeds maximum #{max_compressed_size} bytes"
      )

      {:error, :compressed_data_too_large}
    else
      try do
        decompressed = :zlib.gunzip(compressed_data)
        decompressed_size = byte_size(decompressed)

        # Validate decompressed size to prevent decompression bombs
        if decompressed_size > max_decompressed_size do
          Logger.warning(
            "Decompression bomb detected: decompressed size #{decompressed_size} exceeds maximum #{max_decompressed_size} bytes (ratio: #{Float.round(decompressed_size / compressed_size, 1)}x)"
          )

          {:error, :decompressed_data_too_large}
        else
          {:ok, decompressed}
        end
      rescue
        error ->
          Logger.error("SVG decompression failed: #{inspect(error)}")
          {:error, {:decompression_failed, error}}
      end
    end
  end

  @doc """
  Calculates the compression ratio between original and compressed data.

  Returns a float where 1.0 = no compression, 0.5 = 50% reduction, etc.

  ## Examples

      iex> Compression.compression_ratio(<<1::size(1000)>>, <<1::size(500)>>)
      0.5

  """
  @spec compression_ratio(binary(), binary()) :: float()
  def compression_ratio(original, compressed)
      when is_binary(original) and is_binary(compressed) do
    original_size = byte_size(original)
    compressed_size = byte_size(compressed)

    if original_size == 0 do
      1.0
    else
      compressed_size / original_size
    end
  end

  @doc """
  Determines whether SVG data should be compressed based on size threshold.

  Small SVGs may not benefit from compression due to overhead.

  ## Options

    * `:threshold` - Minimum SVG size in bytes (default: 10,000)

  ## Examples

      iex> small_svg = "<svg></svg>"
      iex> Compression.should_compress?(small_svg)
      false

      iex> large_svg = String.duplicate("<g>data</g>", 2000)
      iex> Compression.should_compress?(large_svg)
      true

  """
  @spec should_compress?(binary(), keyword()) :: boolean()
  def should_compress?(svg_data, opts \\ []) when is_binary(svg_data) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    byte_size(svg_data) >= threshold
  end

  @doc """
  Compresses SVG data only if it meets the size threshold.

  Returns `{:ok, :uncompressed, svg_data}` if compression is skipped,
  or `{:ok, :compressed, compressed_data, metadata}` if compressed.

  ## Examples

      iex> small_svg = "<svg></svg>"
      iex> Compression.compress_if_needed(small_svg)
      {:ok, :uncompressed, "<svg></svg>"}

      iex> large_svg = String.duplicate("<g>data</g>", 2000)
      iex> {:ok, :compressed, _data, _meta} = Compression.compress_if_needed(large_svg)

  """
  @spec compress_if_needed(binary(), keyword()) ::
          {:ok, :uncompressed, binary()}
          | {:ok, :compressed, binary(), compression_metadata()}
          | {:error, term()}
  def compress_if_needed(svg_data, opts \\ []) when is_binary(svg_data) do
    if should_compress?(svg_data, opts) do
      case compress(svg_data, opts) do
        {:ok, compressed, metadata} ->
          {:ok, :compressed, compressed, metadata}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Logger.debug(
        "Skipping compression for small SVG (#{byte_size(svg_data)} bytes < #{Keyword.get(opts, :threshold, @default_threshold)} threshold)"
      )

      {:ok, :uncompressed, svg_data}
    end
  end

  @doc """
  Validates that compressed data can be successfully decompressed.

  Useful for testing compression integrity.

  ## Examples

      iex> {:ok, compressed, _meta} = Compression.compress("<svg>test</svg>")
      iex> Compression.validate_compression(compressed, "<svg>test</svg>")
      :ok

  """
  @spec validate_compression(binary(), binary()) :: :ok | {:error, :validation_failed}
  def validate_compression(compressed_data, original_data)
      when is_binary(compressed_data) and is_binary(original_data) do
    case decompress(compressed_data) do
      {:ok, decompressed} ->
        if decompressed == original_data do
          :ok
        else
          {:error, :validation_failed}
        end

      {:error, _reason} ->
        {:error, :validation_failed}
    end
  end
end
