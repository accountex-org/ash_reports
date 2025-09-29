#!/usr/bin/env elixir

# Comprehensive DSLGenerator Test Suite
# Run with: mix run test_dsl_generator.exs

defmodule DSLGeneratorTestSuite do
  alias AshReports.{Report, Band}
  alias AshReports.Typst.DSLGenerator
  alias AshReports.Element.{Field, Label, Expression, Aggregate, Line, Box, Image}

  def run_all_tests do
    IO.puts("🧪 Running Comprehensive DSLGenerator Test Suite")
    IO.puts("=" |> String.duplicate(50))

    test_results = [
      test_basic_template_generation(),
      test_empty_report_handling(),
      test_debug_information(),
      test_all_element_types(),
      test_multiple_bands(),
      test_complex_report_structure(),
      test_band_processing(),
      test_element_positioning(),
      test_pdf_compilation()
    ]

    passed_tests = Enum.count(test_results, & &1)
    total_tests = length(test_results)

    IO.puts("\n" <> "=" |> String.duplicate(50))
    IO.puts("🏆 Test Results: #{passed_tests}/#{total_tests} passed")

    if passed_tests == total_tests do
      IO.puts("✅ All tests passed!")
      :ok
    else
      IO.puts("❌ Some tests failed")
      :error
    end
  end

  defp test_basic_template_generation do
    IO.puts("\n1. Testing basic template generation...")

    report = %Report{
      name: :basic_test,
      title: "Basic Test Report",
      bands: [
        %Band{
          name: :title_band,
          type: :title,
          elements: [
            %Label{name: :title_label, text: "Test Report"}
          ]
        }
      ]
    }

    case DSLGenerator.generate_template(report) do
      {:ok, template} ->
        checks = [
          String.contains?(template, "#let basic_test(data, config: (:)) = {"),
          String.contains?(template, "Test Report"),
          String.contains?(template, "set page("),
          String.contains?(template, "set document("),
          String.contains?(template, "set text(")
        ]

        if Enum.all?(checks) do
          IO.puts("✅ Basic template generation - PASSED")
          true
        else
          IO.puts("❌ Basic template generation - FAILED")
          false
        end
      {:error, error} ->
        IO.puts("❌ Basic template generation - ERROR: #{inspect(error)}")
        false
    end
  end

  defp test_empty_report_handling do
    IO.puts("\n2. Testing empty report handling...")

    empty_report = %Report{
      name: :empty_test,
      title: "Empty Report",
      bands: []
    }

    case DSLGenerator.generate_template(empty_report) do
      {:ok, template} ->
        if String.contains?(template, "#let empty_test(data, config: (:)) = {") do
          IO.puts("✅ Empty report handling - PASSED")
          true
        else
          IO.puts("❌ Empty report handling - FAILED")
          false
        end
      {:error, error} ->
        IO.puts("❌ Empty report handling - ERROR: #{inspect(error)}")
        false
    end
  end

  defp test_debug_information do
    IO.puts("\n3. Testing debug information...")

    report = %Report{
      name: :debug_test,
      title: "Debug Test",
      driving_resource: TestResource,
      bands: []
    }

    case DSLGenerator.generate_template(report, debug: true) do
      {:ok, template} ->
        checks = [
          String.contains?(template, "// Report Debug Information"),
          String.contains?(template, "// Name: debug_test"),
          String.contains?(template, "// Driving Resource: Elixir.TestResource")
        ]

        if Enum.all?(checks) do
          IO.puts("✅ Debug information - PASSED")
          true
        else
          IO.puts("❌ Debug information - FAILED")
          false
        end
      {:error, error} ->
        IO.puts("❌ Debug information - ERROR: #{inspect(error)}")
        false
    end
  end

  defp test_all_element_types do
    IO.puts("\n4. Testing all 7 element types...")

    context = %{debug: false}

    elements = [
      {%Field{name: :test_field, source: {:resource, :customer_name}}, "Field"},
      {%Label{name: :test_label, text: "Test Label"}, "Label"},
      {%Expression{name: :test_expr, expression: "record.amount * 1.1"}, "Expression"},
      {%Aggregate{name: :test_agg, function: :sum, source: :amount}, "Aggregate"},
      {%Line{name: :test_line, orientation: :horizontal, thickness: 2}, "Line"},
      {%Box{name: :test_box, border: %{width: 1, color: "blue"}}, "Box"},
      {%Image{name: :test_image, source: "logo.png", scale_mode: :fit}, "Image"}
    ]

    results = Enum.map(elements, fn {element, name} ->
      result = DSLGenerator.generate_element(element, context)
      is_valid = is_binary(result) && String.length(result) > 0
      IO.puts("  #{if is_valid, do: "✅", else: "❌"} #{name}: #{result}")
      is_valid
    end)

    if Enum.all?(results) do
      IO.puts("✅ All element types - PASSED")
      true
    else
      IO.puts("❌ All element types - FAILED")
      false
    end
  end

  defp test_multiple_bands do
    IO.puts("\n5. Testing multiple band types...")

    report = %Report{
      name: :multi_band_test,
      title: "Multi Band Test",
      bands: [
        %Band{name: :title_band, type: :title, elements: []},
        %Band{name: :header_band, type: :header, elements: []},
        %Band{name: :detail_band, type: :detail, elements: []},
        %Band{name: :footer_band, type: :footer, elements: []},
        %Band{name: :summary_band, type: :summary, elements: []}
      ]
    }

    case DSLGenerator.generate_template(report) do
      {:ok, template} ->
        checks = [
          String.contains?(template, "// Title Section"),
          String.contains?(template, "// Data Processing Section"),
          String.contains?(template, "// Summary Section")
        ]

        if Enum.all?(checks) do
          IO.puts("✅ Multiple band types - PASSED")
          true
        else
          IO.puts("❌ Multiple band types - FAILED")
          false
        end
      {:error, error} ->
        IO.puts("❌ Multiple band types - ERROR: #{inspect(error)}")
        false
    end
  end

  defp test_complex_report_structure do
    IO.puts("\n6. Testing complex report structure...")

    report = %Report{
      name: :complex_test,
      title: "Complex Report Test",
      bands: [
        %Band{
          name: :title_band,
          type: :title,
          elements: [
            %Label{name: :title, text: "Sales Report"},
            %Line{name: :separator, orientation: :horizontal}
          ]
        },
        %Band{
          name: :detail_band,
          type: :detail,
          elements: [
            %Field{name: :customer, source: {:resource, :customer_name}},
            %Field{name: :amount, source: {:resource, :amount}},
            %Expression{name: :tax, expression: "record.amount * 0.1"}
          ]
        }
      ]
    }

    case DSLGenerator.generate_template(report) do
      {:ok, template} ->
        checks = [
          String.contains?(template, "Sales Report"),
          String.contains?(template, "#record.customer_name"),
          String.contains?(template, "#record.amount"),
          String.contains?(template, "record.amount * 0.1"),
          String.contains?(template, "#line(")
        ]

        if Enum.all?(checks) do
          IO.puts("✅ Complex report structure - PASSED")
          true
        else
          IO.puts("❌ Complex report structure - FAILED")
          false
        end
      {:error, error} ->
        IO.puts("❌ Complex report structure - ERROR: #{inspect(error)}")
        false
    end
  end

  defp test_band_processing do
    IO.puts("\n7. Testing band processing...")

    band = %Band{
      name: :test_band,
      type: :detail,
      elements: [
        %Label{name: :label, text: "Test Content"}
      ]
    }

    context = %{debug: false, report: %Report{}}

    result = DSLGenerator.generate_band_section(band, context)

    if is_binary(result) && String.contains?(result, "Test Content") do
      IO.puts("✅ Band processing - PASSED")
      true
    else
      IO.puts("❌ Band processing - FAILED")
      false
    end
  end

  defp test_element_positioning do
    IO.puts("\n8. Testing element positioning and properties...")

    # Test elements with various properties
    line_element = %Line{
      name: :test_line,
      orientation: :vertical,
      thickness: 3
    }

    box_element = %Box{
      name: :test_box,
      border: %{width: 2, color: "red"},
      fill: %{color: "yellow"}
    }

    context = %{debug: false}

    line_result = DSLGenerator.generate_element(line_element, context)
    box_result = DSLGenerator.generate_element(box_element, context)

    line_ok = String.contains?(line_result, "angle: 90deg") && String.contains?(line_result, "3pt")
    box_ok = String.contains?(box_result, "2pt + red") && String.contains?(box_result, "fill: yellow")

    if line_ok && box_ok do
      IO.puts("✅ Element positioning - PASSED")
      true
    else
      IO.puts("❌ Element positioning - FAILED")
      false
    end
  end

  defp test_pdf_compilation do
    IO.puts("\n9. Testing PDF compilation...")

    report = %Report{
      name: :pdf_test,
      title: "PDF Compilation Test",
      bands: [
        %Band{
          name: :content_band,
          type: :title,
          elements: [
            %Label{name: :content, text: "PDF Test Content"}
          ]
        }
      ]
    }

    case DSLGenerator.generate_template(report) do
      {:ok, template} ->
        case AshReports.Typst.BinaryWrapper.compile(template, format: :pdf) do
          {:ok, pdf} ->
            if is_binary(pdf) && byte_size(pdf) > 1000 do
              IO.puts("✅ PDF compilation - PASSED (#{byte_size(pdf)} bytes)")
              true
            else
              IO.puts("❌ PDF compilation - FAILED (too small)")
              false
            end
          {:error, error} ->
            IO.puts("❌ PDF compilation - ERROR: #{inspect(error)}")
            false
        end
      {:error, error} ->
        IO.puts("❌ PDF compilation template generation - ERROR: #{inspect(error)}")
        false
    end
  end
end

# Run the test suite
DSLGeneratorTestSuite.run_all_tests()