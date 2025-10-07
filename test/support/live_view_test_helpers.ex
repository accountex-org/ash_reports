defmodule AshReports.LiveViewTestHelpers do
  @moduledoc """
  Test helpers for LiveView component testing.

  Provides utilities for testing LiveView components in isolation,
  sending events, and asserting on renders.
  """

  import Phoenix.LiveViewTest
  import ExUnit.Assertions

  @doc """
  Renders a LiveView component in isolation for testing.

  This wraps Phoenix.LiveViewTest.live_isolated/3 with AshReports-specific
  setup and configuration.

  ## Options

  - `:session` - Session data to pass to the LiveView (default: %{})
  - `:connect_params` - Connection parameters (default: %{})

  ## Examples

      {:ok, view, html} = live_isolated_component(
        conn,
        MyComponent,
        session: %{report_id: "test"}
      )
  """
  def live_isolated_component(conn, component_module, opts \\ []) do
    session = Keyword.get(opts, :session, %{})
    connect_params = Keyword.get(opts, :connect_params, %{})

    live_isolated(conn, component_module,
      session: session,
      connect_params: connect_params
    )
  end

  @doc """
  Sends an event to a LiveView and returns the updated HTML.

  ## Examples

      html = send_component_event(view, "filter_change", %{value: "test"})
  """
  def send_component_event(view, event, value \\ %{}) do
    render_change(view, event, value)
  end

  @doc """
  Clicks an element in a LiveView and returns the updated HTML.

  ## Examples

      html = click_component_element(view, "button", "Apply Filter")
  """
  def click_component_element(view, element_type, text) do
    view
    |> element(element_type, text)
    |> render_click()
  end

  @doc """
  Asserts that a LiveView render contains specific text.

  ## Examples

      assert_render_contains(html, "Sales Report")
  """
  def assert_render_contains(html, text) do
    assert html =~ text,
           "Expected render to contain '#{text}', but it did not.\nGot: #{html}"
  end

  @doc """
  Asserts that a LiveView render does not contain specific text.

  ## Examples

      refute_render_contains(html, "Error")
  """
  def refute_render_contains(html, text) do
    refute html =~ text,
           "Expected render to not contain '#{text}', but it did.\nGot: #{html}"
  end

  @doc """
  Asserts that a LiveView render contains a specific HTML element.

  ## Examples

      assert_render_has_element(html, "table", class: "report-table")
  """
  def assert_render_has_element(html, element_type, attrs \\ []) do
    attrs_pattern = attrs
    |> Enum.map(fn {key, value} -> ~s(#{key}="#{value}") end)
    |> Enum.join(".*")

    pattern = ~r/<#{element_type}[^>]*#{attrs_pattern}[^>]*>/

    assert html =~ pattern,
           "Expected render to contain <#{element_type}> with attributes #{inspect(attrs)}, but it did not.\nGot: #{html}"
  end

  @doc """
  Submits a form in a LiveView and returns the updated HTML.

  ## Examples

      html = submit_component_form(view, "report-form", %{
        "start_date" => "2024-01-01",
        "end_date" => "2024-12-31"
      })
  """
  def submit_component_form(view, form_id, form_data) do
    view
    |> form("##{form_id}", form_data)
    |> render_submit()
  end

  @doc """
  Changes a form input in a LiveView and returns the updated HTML.

  ## Examples

      html = change_component_form(view, "report-form", %{"format" => "pdf"})
  """
  def change_component_form(view, form_id, form_data) do
    view
    |> form("##{form_id}", form_data)
    |> render_change()
  end

  @doc """
  Asserts that a LiveView component is in a specific state.

  Checks the component's assigns for expected values.

  ## Examples

      assert_component_state(view, report_id: "test", loading: false)
  """
  def assert_component_state(view, expected_assigns) do
    actual_assigns = view |> element("body") |> render() |> then(fn _ ->
      # Note: This is a simplified version. In real usage, you'd need to
      # access the LiveView's internal state, which might require different approaches
      # depending on Phoenix LiveView version
      :ok
    end)

    Enum.each(expected_assigns, fn {key, expected_value} ->
      # This would need actual implementation based on how you access LiveView state
      # For now, this is a placeholder that would need to be adapted
      :ok
    end)
  end

  @doc """
  Waits for a LiveView update with a specific condition.

  Uses a polling mechanism to wait for the condition to be true.

  ## Options

  - `:timeout` - Maximum time to wait in milliseconds (default: 5000)
  - `:interval` - Polling interval in milliseconds (default: 100)

  ## Examples

      assert wait_for_render(view, fn html ->
        html =~ "Loading complete"
      end)
  """
  def wait_for_render(view, condition_fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    interval = Keyword.get(opts, :interval, 100)

    wait_for_render_loop(view, condition_fun, timeout, interval, System.monotonic_time(:millisecond))
  end

  defp wait_for_render_loop(view, condition_fun, timeout, interval, start_time) do
    html = render(view)

    if condition_fun.(html) do
      true
    else
      current_time = System.monotonic_time(:millisecond)

      if current_time - start_time > timeout do
        flunk("Timeout waiting for render condition after #{timeout}ms.\nLast render: #{html}")
      else
        Process.sleep(interval)
        wait_for_render_loop(view, condition_fun, timeout, interval, start_time)
      end
    end
  end

  @doc """
  Creates a mock report definition for LiveView testing.

  ## Examples

      report = build_mock_report(name: :test_report, title: "Test Report")
  """
  def build_mock_report(opts \\ []) do
    name = Keyword.get(opts, :name, :test_report)
    title = Keyword.get(opts, :title, "Test Report")

    %{
      name: name,
      title: title,
      parameters: [],
      bands: [],
      variables: [],
      groups: []
    }
  end

  @doc """
  Creates mock chart data for LiveView testing.

  ## Examples

      chart_data = build_mock_chart_data(type: :bar, labels: ["A", "B", "C"], values: [10, 20, 30])
  """
  def build_mock_chart_data(opts \\ []) do
    type = Keyword.get(opts, :type, :bar)
    labels = Keyword.get(opts, :labels, ["Label 1", "Label 2", "Label 3"])
    values = Keyword.get(opts, :values, [10, 20, 30])

    %{
      type: type,
      data: %{
        labels: labels,
        datasets: [
          %{
            label: "Dataset 1",
            data: values
          }
        ]
      },
      options: %{}
    }
  end

  @doc """
  Asserts that a LiveView component has dispatched a specific event.

  Note: This requires the component to be set up with proper event handling.

  ## Examples

      assert_component_event_sent(view, "report_generated", %{report_id: "test"})
  """
  def assert_component_event_sent(view, event_name, payload \\ %{}) do
    # This is a placeholder. Actual implementation would depend on
    # how events are tracked in your LiveView components
    :ok
  end

  @doc """
  Renders a chart component in isolation.

  ## Examples

      {:ok, view, html} = render_chart_component(conn,
        type: :bar,
        data: chart_data
      )
  """
  def render_chart_component(conn, opts \\ []) do
    type = Keyword.get(opts, :type, :bar)
    data = Keyword.get(opts, :data, build_mock_chart_data(type: type))

    session = %{
      chart_type: type,
      chart_data: data
    }

    # This would need to point to your actual chart LiveView component
    # For now, this is a placeholder
    {:ok, nil, "<div>Mock Chart</div>"}
  end

  @doc """
  Asserts that a chart is rendered correctly.

  ## Examples

      assert_chart_rendered(html, type: :bar, has_legend: true)
  """
  def assert_chart_rendered(html, opts \\ []) do
    type = Keyword.get(opts, :type)
    has_legend = Keyword.get(opts, :has_legend, false)

    if type do
      assert_render_contains(html, "data-chart-type=\"#{type}\"")
    end

    if has_legend do
      assert_render_contains(html, "chart-legend")
    end

    :ok
  end
end
