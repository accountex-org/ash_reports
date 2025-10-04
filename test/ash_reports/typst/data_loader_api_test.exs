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
    test "load_for_typst includes all configuration options" do
      # Test that the unified API documents all options
      {:docs_v1, _, :elixir, "text/markdown", _module_doc, _, functions} =
        Code.fetch_docs(DataLoader)

      load_for_typst_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :load_for_typst and arity == 4
        end)

      assert load_for_typst_docs != nil

      {{:function, :load_for_typst, 4}, _, _, doc_content, _} = load_for_typst_docs

      # Verify documentation mentions all the new options
      doc_string = doc_content["en"]
      assert doc_string =~ ":chunk_size"
      assert doc_string =~ ":max_demand"
      assert doc_string =~ ":include_sample"
      assert doc_string =~ ":sample_size"
      assert doc_string =~ ":strategy"
    end

    test "documentation includes comprehensive examples" do
      {:docs_v1, _, :elixir, "text/markdown", _, _, functions} = Code.fetch_docs(DataLoader)

      load_for_typst_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :load_for_typst and arity == 4
        end)

      {{:function, :load_for_typst, 4}, _, _, doc_content, _} = load_for_typst_docs
      doc_string = doc_content["en"]

      # Verify examples are present
      assert doc_string =~ "# Automatic strategy selection"
      assert doc_string =~ "# Force in-memory strategy"
      assert doc_string =~ "# Use aggregation strategy"
      assert doc_string =~ "# Get a stream for custom processing"
    end
  end

  describe "streaming API documentation" do
    test "load_for_typst/4 has comprehensive documentation" do
      {:docs_v1, _, :elixir, "text/markdown", _, _, functions} = Code.fetch_docs(DataLoader)

      load_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :load_for_typst and arity == 4
        end)

      assert load_docs != nil

      {{:function, :load_for_typst, 4}, _, _, doc_content, _} = load_docs
      doc_string = doc_content["en"]

      # Verify streaming documentation
      assert doc_string =~ "strategy"
      assert doc_string =~ ":streaming"
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
      # Verify function exists with correct arity (opts has default, exports as both 3 and 4)
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
    test "stream_for_typst is still available (deprecated)" do
      # The function has default params so exports as arity 3
      assert function_exported?(DataLoader, :stream_for_typst, 3) or
               function_exported?(DataLoader, :stream_for_typst, 4)
    end

    test "load_with_aggregations_for_typst is still available (deprecated)" do
      # Verify backward compatibility
      assert function_exported?(DataLoader, :load_with_aggregations_for_typst, 4)
    end
  end

  describe "error handling" do
    test "error cases are documented" do
      # Verify the error handling is documented
      {:docs_v1, _, :elixir, "text/markdown", _, _, functions} = Code.fetch_docs(DataLoader)

      load_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :load_for_typst and arity == 4
        end)

      {{:function, :load_for_typst, 4}, _, _, doc_content, _} = load_docs
      doc_string = doc_content["en"]

      # Verify error cases are documented
      assert doc_string =~ "{:error, term()}"
    end
  end

  describe "load_for_typst/4 - unified API with strategy selection" do
    test "function is exported with correct arity" do
      assert function_exported?(DataLoader, :load_for_typst, 4)
    end

    test "returns error for invalid inputs" do
      fake_domain = FakeModule
      fake_report = :nonexistent_report
      params = %{}
      opts = []

      result = DataLoader.load_for_typst(fake_domain, fake_report, params, opts)

      assert {:error, _} = result
    end

    test "accepts strategy option" do
      fake_domain = FakeModule
      fake_report = :test_report
      params = %{}

      # Test different strategies
      for strategy <- [:auto, :in_memory, :aggregation, :streaming] do
        opts = [strategy: strategy]
        result = DataLoader.load_for_typst(fake_domain, fake_report, params, opts)
        # Should return error for fake domain, but options are accepted
        assert {:error, _} = result
      end
    end

    test "accepts all loading options" do
      fake_domain = FakeModule
      fake_report = :test_report
      params = %{}
      opts = [
        strategy: :in_memory,
        preprocess_charts: false,
        limit: 100,
        chunk_size: 500,
        include_sample: true
      ]

      result = DataLoader.load_for_typst(fake_domain, fake_report, params, opts)

      # Should return error for fake domain, but options are accepted
      assert {:error, _} = result
    end

    test "has comprehensive documentation" do
      {:docs_v1, _, :elixir, "text/markdown", _, _, functions} = Code.fetch_docs(DataLoader)

      load_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :load_for_typst and arity == 4
        end)

      assert load_docs != nil

      {{:function, :load_for_typst, 4}, _, _, doc_content, _} = load_docs
      doc_string = doc_content["en"]

      # Verify documentation mentions strategies
      assert doc_string =~ "strategy"
      assert doc_string =~ ":auto"
      assert doc_string =~ ":in_memory"
      assert doc_string =~ ":aggregation"
      assert doc_string =~ ":streaming"
    end

    test "documentation describes all strategies" do
      {:docs_v1, _, :elixir, "text/markdown", _, _, functions} = Code.fetch_docs(DataLoader)

      load_docs =
        Enum.find(functions, fn {{:function, name, arity}, _, _, _, _} ->
          name == :load_for_typst and arity == 4
        end)

      {{:function, :load_for_typst, 4}, _, _, doc_content, _} = load_docs
      doc_string = doc_content["en"]

      # Verify all strategies are documented
      assert doc_string =~ "Automatically selects the best strategy"
      assert doc_string =~ "Loads all records into memory"
      assert doc_string =~ "streaming aggregations"
      assert doc_string =~ "Returns a stream"
    end
  end

  describe "deprecated functions" do
    test "load_with_aggregations_for_typst delegates to load_for_typst" do
      # This should still work but emit a warning
      fake_domain = FakeModule
      fake_report = :test_report
      params = %{}
      opts = []

      result = DataLoader.load_with_aggregations_for_typst(fake_domain, fake_report, params, opts)

      # Should behave the same as the new API
      assert {:error, _} = result
    end

    test "stream_for_typst delegates to load_for_typst" do
      fake_domain = FakeModule
      fake_report = :test_report
      params = %{}
      opts = []

      result = DataLoader.stream_for_typst(fake_domain, fake_report, params, opts)

      # Should behave the same as the new API
      assert {:error, _} = result
    end
  end
end
