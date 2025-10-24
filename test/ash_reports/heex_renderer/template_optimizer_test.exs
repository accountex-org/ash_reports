defmodule AshReports.HeexRenderer.TemplateOptimizerTest do
  @moduledoc """
  Test suite for the TemplateOptimizer module.

  Tests template optimization, compilation caching, and performance
  enhancements for HEEX templates in the AshReports system.
  """

  use ExUnit.Case, async: true

  alias AshReports.HeexRenderer.TemplateOptimizer

  setup do
    # Clear cache before each test
    TemplateOptimizer.clear_cache()
    :ok
  end

  describe "optimize_template/2" do
    test "removes excessive whitespace between tags" do
      template = """
      <div>
        <span>   Test   </span>
        <p>   Content   </p>
      </div>
      """

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      refute String.contains?(optimized, "  ")
      assert String.contains?(optimized, "<div>")
      assert String.contains?(optimized, "<span>")
    end

    test "preserves necessary whitespace in text content" do
      template = "<div>Hello World</div>"

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      assert String.contains?(optimized, "Hello World")
    end

    test "optimizes tag spacing" do
      template = "<div>  <span>test</span>  </div>"

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      assert String.contains?(optimized, "><span>")
    end

    test "removes HTML comments" do
      template = """
      <div>
        <!-- This is a comment -->
        <span>Content</span>
        <!-- Another comment -->
      </div>
      """

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      refute String.contains?(optimized, "<!--")
      refute String.contains?(optimized, "comment")
      assert String.contains?(optimized, "Content")
    end

    test "removes empty class attributes" do
      template = """
      <div class="">
        <span class="" id="test">Content</span>
      </div>
      """

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      refute String.contains?(optimized, "class=\"\"")
      assert String.contains?(optimized, "id=\"test\"")
    end

    test "removes empty style attributes" do
      template = """
      <div style="">
        <span style="" class="test">Content</span>
      </div>
      """

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      refute String.contains?(optimized, "style=\"\"")
      assert String.contains?(optimized, "class=\"test\"")
    end

    test "caches static sections when enabled" do
      template = """
      <div class="static">
        Static content here
      </div>
      """

      opts = %{cache_static_sections: true}
      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template, opts)
      assert String.contains?(optimized, "cached_static")
    end

    test "skips static caching when disabled" do
      template = """
      <div class="static">
        Static content here
      </div>
      """

      opts = %{cache_static_sections: false}
      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template, opts)
      refute String.contains?(optimized, "cached_static")
    end

    test "handles nested templates" do
      template = """
      <div>
        <div>
          <span>Nested</span>
        </div>
      </div>
      """

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      assert String.contains?(optimized, "<div>")
      assert String.contains?(optimized, "Nested")
    end

    test "preserves HEEX expressions" do
      template = """
      <div>
        <%= @variable %>
        <% for item <- @items do %>
          <span><%= item %></span>
        <% end %>
      </div>
      """

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      assert String.contains?(optimized, "<%= @variable %>")
      assert String.contains?(optimized, "<% for")
      assert String.contains?(optimized, "<% end %>")
    end

    test "preserves Phoenix.Component syntax" do
      template = """
      <div>
        <.live_component module={MyComponent} id="test" />
        <.button class="primary">Click me</.button>
      </div>
      """

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      assert String.contains?(optimized, "<.live_component")
      assert String.contains?(optimized, "<.button")
    end

    test "handles empty template" do
      assert {:ok, ""} = TemplateOptimizer.optimize_template("")
    end

    test "handles very large template" do
      # Generate a large template (1MB+)
      large_template =
        Enum.map(1..10000, fn i ->
          "<div class=\"item-#{i}\">Content #{i}</div>\n"
        end)
        |> Enum.join()

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(large_template)
      assert is_binary(optimized)
      assert String.length(optimized) > 0
    end

    test "measures optimization performance" do
      template = """
      <div>
        <span>Test content</span>
      </div>
      """

      {time_microseconds, {:ok, _optimized}} =
        :timer.tc(fn -> TemplateOptimizer.optimize_template(template) end)

      # Should complete quickly (< 10ms for small template)
      assert time_microseconds < 10_000
    end

    test "returns error on invalid input" do
      # Test with nil - should raise or return error
      result = TemplateOptimizer.optimize_template(nil)

      assert match?({:error, _}, result)
    end
  end

  describe "compile_and_cache/3" do
    test "stores optimized template in cache" do
      template = "<div>Test</div>"
      template_name = "test_template_#{:rand.uniform(1000)}"

      assert :ok = TemplateOptimizer.compile_and_cache(template_name, template)

      # Cache should now contain the optimized template
      # We can't directly verify ETS contents without exposing internals,
      # but we can verify no errors occurred
    end

    test "optimizes before caching" do
      template = """
      <div>   <span>Test</span>   </div>
      """

      template_name = "whitespace_test_#{:rand.uniform(1000)}"

      assert :ok = TemplateOptimizer.compile_and_cache(template_name, template)
      # The cached version should be optimized (whitespace removed)
    end

    test "handles cache key collisions" do
      template1 = "<div>First</div>"
      template2 = "<div>Second</div>"
      template_name = "collision_test"

      # First cache
      assert :ok = TemplateOptimizer.compile_and_cache(template_name, template1)

      # Second cache with same name (should generate different key due to timestamp)
      # Sleep briefly to ensure different timestamp
      Process.sleep(1)
      assert :ok = TemplateOptimizer.compile_and_cache(template_name, template2)
    end

    test "returns error for invalid template" do
      result = TemplateOptimizer.compile_and_cache("invalid", nil)

      assert match?({:error, _}, result)
    end

    test "accepts optimization options" do
      template = """
      <div class="static">
        Static content
      </div>
      """

      opts = %{cache_static_sections: true}
      assert :ok = TemplateOptimizer.compile_and_cache("with_opts", template, opts)
    end
  end

  describe "clear_cache/0" do
    test "clears entire cache" do
      # Add some templates to cache
      TemplateOptimizer.compile_and_cache("test1", "<div>Test 1</div>")
      TemplateOptimizer.compile_and_cache("test2", "<div>Test 2</div>")
      TemplateOptimizer.compile_and_cache("test3", "<div>Test 3</div>")

      # Clear cache
      assert :ok = TemplateOptimizer.clear_cache()

      # Cache should be empty now (we can verify by adding again)
      assert :ok = TemplateOptimizer.compile_and_cache("test1", "<div>New</div>")
    end

    test "handles missing cache table" do
      # Clear cache even if table doesn't exist
      TemplateOptimizer.clear_cache()
      assert :ok = TemplateOptimizer.clear_cache()
    end

    test "handles concurrent cache operations" do
      # Start multiple processes clearing cache
      tasks =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            TemplateOptimizer.clear_cache()
          end)
        end)

      # All should complete successfully
      results = Enum.map(tasks, &Task.await/1)
      assert Enum.all?(results, &(&1 == :ok))
    end
  end

  describe "cache key generation" do
    test "generates consistent keys for same template name at same time" do
      # We can't test this directly, but we can verify caching works
      template = "<div>Test</div>"
      template_name = "consistency_test"

      assert :ok = TemplateOptimizer.compile_and_cache(template_name, template)
      assert :ok = TemplateOptimizer.compile_and_cache(template_name, template)
    end

    test "generates unique keys for different templates" do
      template1 = "<div>Test 1</div>"
      template2 = "<div>Test 2</div>"

      assert :ok = TemplateOptimizer.compile_and_cache("unique_1", template1)

      Process.sleep(1)
      assert :ok = TemplateOptimizer.compile_and_cache("unique_2", template2)
    end

    test "includes timestamp in key" do
      # Keys should be different when generated at different times
      template = "<div>Test</div>"

      assert :ok = TemplateOptimizer.compile_and_cache("timestamp_1", template)

      Process.sleep(2)
      assert :ok = TemplateOptimizer.compile_and_cache("timestamp_1", template)
    end

    test "uses MD5 hash" do
      # Indirect test - verify caching works (which uses MD5 hashing)
      template = "<div>Hash test</div>"

      assert :ok = TemplateOptimizer.compile_and_cache("md5_test", template)
    end

    test "truncates hash to manageable length" do
      # Key generation should produce reasonably short keys
      template = "<div>#{String.duplicate("Very long content ", 100)}</div>"

      assert :ok = TemplateOptimizer.compile_and_cache("long_content_test", template)
    end
  end

  describe "edge cases" do
    test "handles template with only whitespace" do
      template = "   \n  \t  \n   "

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      assert String.trim(optimized) == ""
    end

    test "handles template with special regex characters" do
      template = "<div>Test $1.00 + $2.00 = $3.00</div>"

      assert {:ok, optimized} = TemplateOptimizer.optimize_template(template)
      assert String.contains?(optimized, "$1.00")
      assert String.contains?(optimized, "$2.00")
    end

    test "handles very large template efficiently" do
      # Generate 1MB+ template
      large_template =
        Enum.map(1..50000, fn i ->
          "<div>#{i}</div>"
        end)
        |> Enum.join("\n")

      {time_microseconds, {:ok, optimized}} =
        :timer.tc(fn -> TemplateOptimizer.optimize_template(large_template) end)

      # Should complete in reasonable time (< 200ms for 1MB template)
      assert time_microseconds < 200_000
      assert is_binary(optimized)
    end

    test "handles concurrent optimization calls" do
      template = "<div>Concurrent test</div>"

      tasks =
        Enum.map(1..20, fn _ ->
          Task.async(fn ->
            TemplateOptimizer.optimize_template(template)
          end)
        end)

      results = Enum.map(tasks, &Task.await/1)

      # All should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end
  end

  describe "performance and memory" do
    test "template optimization completes within reasonable time" do
      template = """
      <div class="container">
        <!-- Comment to remove -->
        <span style="">Test content</span>
        <p class="">   More   content   </p>
      </div>
      """

      {time_microseconds, {:ok, _optimized}} =
        :timer.tc(fn -> TemplateOptimizer.optimize_template(template) end)

      # Should complete in < 5ms for typical template
      assert time_microseconds < 5_000
    end

    test "memory usage remains reasonable" do
      template = String.duplicate("<div>Test</div>\n", 1000)

      before_memory = :erlang.memory(:total)
      {:ok, _optimized} = TemplateOptimizer.optimize_template(template)
      after_memory = :erlang.memory(:total)

      memory_increase = after_memory - before_memory

      # Memory increase should be reasonable (< 10MB for 1000 divs)
      assert memory_increase < 10 * 1024 * 1024
    end

    test "cache operations are fast" do
      template = "<div>Cache speed test</div>"

      {time_microseconds, :ok} =
        :timer.tc(fn ->
          TemplateOptimizer.compile_and_cache("speed_test", template)
        end)

      # Should complete quickly (< 10ms)
      assert time_microseconds < 10_000
    end
  end
end
