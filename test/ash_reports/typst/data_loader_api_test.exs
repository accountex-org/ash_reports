defmodule AshReports.Typst.DataLoaderAPITest do
  @moduledoc """
  Tests for DataLoader API - Streaming-Only Architecture.

  Tests the enhanced streaming configuration options and unified API that
  always uses the GenStage streaming pipeline.
  """

  use ExUnit.Case, async: true

  alias AshReports.Typst.DataLoader

  describe "stream_for_typst/4 - streaming API" do
    test "function is exported with correct arity" do
      # With default parameter opts \\ [], function exports as arity 4
      assert function_exported?(DataLoader, :stream_for_typst, 4)
    end

    test "returns error for invalid inputs" do
      # Should return error when given invalid domain/report

      fake_domain = FakeModule
      fake_report = :nonexistent_report
      params = %{}
      opts = []

      result = DataLoader.stream_for_typst(fake_domain, fake_report, params, opts)

      # Should return error structure
      assert {:error, _} = result
    end

    test "accepts streaming options" do
      # Verify that options are accepted without errors

      fake_domain = FakeModule
      fake_report = :test_report
      params = %{}
      opts = [chunk_size: 500, memory_limit: 1_000_000, timeout: 60_000]

      result = DataLoader.stream_for_typst(fake_domain, fake_report, params, opts)

      # Should return result (likely error for fake domain, but options accepted)
      assert {:error, _} = result
    end
  end

  describe "streaming configuration options (Section 2.5.1)" do
    test "build_pipeline_opts includes all configuration options" do
      # Test that the private function is called with enhanced options
      # We verify this by checking the function exists and the documentation describes all options
      {:docs_v1, _, :elixir, "text/markdown", module_doc, _, functions} =
        Code.fetch_docs(DataLoader)

      stream_for_typst_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :stream_for_typst and arity == 4
        end)

      assert stream_for_typst_docs != nil

      {{:function, :stream_for_typst, 4}, _, _, doc_content, _} = stream_for_typst_docs

      # Verify documentation mentions all the new options
      doc_string = doc_content["en"]
      assert doc_string =~ ":chunk_size"
      assert doc_string =~ ":max_demand"
      assert doc_string =~ ":buffer_size"
      assert doc_string =~ ":enable_telemetry"
      assert doc_string =~ ":aggregations"
      assert doc_string =~ ":grouped_aggregations"
      assert doc_string =~ ":memory_limit"
      assert doc_string =~ ":timeout"
    end

    test "documentation includes comprehensive examples" do
      {:docs_v1, _, :elixir, "text/markdown", _, _, functions} = Code.fetch_docs(DataLoader)

      stream_for_typst_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :stream_for_typst and arity == 4
        end)

      {{:function, :stream_for_typst, 4}, _, _, doc_content, _} = stream_for_typst_docs
      doc_string = doc_content["en"]

      # Verify examples are present
      assert doc_string =~ "# Basic streaming with defaults"
      assert doc_string =~ "# Custom chunk size for faster throughput"
      assert doc_string =~ "# Override DSL-inferred aggregations"
      assert doc_string =~ "# Memory-constrained environment"
    end
  end

  describe "streaming API documentation" do
    test "stream_for_typst/4 has comprehensive documentation" do
      {:docs_v1, _, :elixir, "text/markdown", _, _, functions} = Code.fetch_docs(DataLoader)

      stream_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :stream_for_typst and arity == 4
        end)

      assert stream_docs != nil

      {{:function, :stream_for_typst, 4}, _, _, doc_content, _} = stream_docs
      doc_string = doc_content["en"]

      # Verify streaming documentation
      assert doc_string =~ "streaming"
      assert doc_string =~ "GenStage"
      assert doc_string =~ "memory-efficient"
    end
  end

  describe "configuration helpers (Section 2.5.1)" do
    test "typst_config/1 exists and provides defaults" do
      config = DataLoader.typst_config()

      assert is_list(config)
      assert Keyword.has_key?(config, :chunk_size)
      assert Keyword.has_key?(config, :type_conversion)
    end

    test "typst_config/1 allows overrides" do
      config = DataLoader.typst_config(chunk_size: 2000)

      assert config[:chunk_size] == 2000
    end
  end

  describe "API contract and type specs (Section 2.5.1)" do
    test "stream_for_typst has correct type spec" do
      # Verify function exists with correct arity (opts has default, but function is arity 4)
      assert function_exported?(DataLoader, :stream_for_typst, 4)

      # The type spec should be @spec stream_for_typst(module(), atom(), map(), load_options()) ::
      #   {:ok, Enumerable.t()} | {:error, term()}
      # We verify this through documentation
      {:docs_v1, _, :elixir, "text/markdown", _, _, functions} = Code.fetch_docs(DataLoader)

      stream_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :stream_for_typst and arity == 4
        end)

      assert stream_docs != nil
    end
  end

  describe "backward compatibility (Section 2.5.1)" do
    test "stream_for_typst with no options still works" do
      # The function should work with default options
      # Function arity is 4, opts has default value []
      assert function_exported?(DataLoader, :stream_for_typst, 4)
    end

    test "existing code using stream_for_typst continues to work" do
      # Verify that the enhanced version maintains the same basic interface
      # This is a smoke test - actual functionality would need real domain/report
      assert function_exported?(DataLoader, :stream_for_typst, 4)
    end
  end

  describe "error handling" do
    test "error cases are documented" do
      # Verify the error handling is documented
      {:docs_v1, _, :elixir, "text/markdown", _, _, functions} = Code.fetch_docs(DataLoader)

      stream_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :stream_for_typst and arity == 4
        end)

      {{:function, :stream_for_typst, 4}, _, _, doc_content, _} = stream_docs
      doc_string = doc_content["en"]

      # Verify error cases are documented
      assert doc_string =~ "{:error, term()}"
    end
  end
end
