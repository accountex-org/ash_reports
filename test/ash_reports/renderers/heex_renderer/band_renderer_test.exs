defmodule AshReports.HeexRenderer.BandRendererTest do
  use ExUnit.Case, async: true

  alias AshReports.{Band, Group, RenderContext, Report}
  alias AshReports.HeexRenderer.BandRenderer

  describe "render_report_bands/1" do
    test "renders empty report with no bands" do
      report = %Report{name: :test_report, bands: []}
      context = %RenderContext{report: report, records: []}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/<div class="ash-report"/
      assert result =~ ~r/data-locale="en"/
      assert result =~ ~r/dir="ltr"/
    end

    test "renders report with title band" do
      title_band = Band.new(:title,
        type: :title,
        elements: [
          %{name: :title_label, type: :label, text: "Sales Report", position: %{}, style: %{}}
        ]
      )

      report = %Report{name: :test_report, bands: [title_band]}
      context = %RenderContext{report: report, records: []}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/class="title-band"/
      assert result =~ ~r/Sales Report/
    end

    test "renders report with detail band and records" do
      detail_band = Band.new(:detail,
        type: :detail,
        elements: [
          %{name: :name_field, type: :field, source: :name, position: %{}, style: %{}}
        ]
      )

      report = %Report{name: :test_report, bands: [detail_band]}
      records = [
        %{name: "Alice"},
        %{name: "Bob"}
      ]
      context = %RenderContext{report: report, records: records}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/class="detail-band"/
      assert result =~ ~r/Alice/
      assert result =~ ~r/Bob/
    end

    test "renders nested bands recursively" do
      nested_band = Band.new(:nested_detail,
        type: :detail,
        elements: [
          %{name: :nested_label, type: :label, text: "Nested", position: %{}, style: %{}}
        ]
      )

      parent_band = Band.new(:parent,
        type: :detail_header,
        elements: [],
        bands: [nested_band]
      )

      report = %Report{name: :test_report, bands: [parent_band]}
      context = %RenderContext{report: report, records: [%{}]}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/class="detail-header-band"/
      assert result =~ ~r/Nested/
    end

    test "respects locale and text direction" do
      report = %Report{name: :test_report, bands: []}
      context = %RenderContext{
        report: report,
        records: [],
        locale: "ar",
        text_direction: "rtl"
      }

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/data-locale="ar"/
      assert result =~ ~r/dir="rtl"/
    end
  end

  describe "band type rendering" do
    test "renders all band types with correct CSS classes" do
      band_types = [
        {:title, "title-band"},
        {:page_header, "page-header-band"},
        {:column_header, "column-header-band"},
        {:group_header, "group-header-band"},
        {:detail_header, "detail-header-band"},
        {:detail, "detail-band"},
        {:detail_footer, "detail-footer-band"},
        {:group_footer, "group-footer-band"},
        {:column_footer, "column-footer-band"},
        {:page_footer, "page-footer-band"},
        {:summary, "summary-band"}
      ]

      for {band_type, expected_class} <- band_types do
        band = Band.new(band_type, type: band_type, elements: [])
        report = %Report{name: :test_report, bands: [band]}
        context = %RenderContext{report: report, records: [%{}]}

        result = BandRenderer.render_report_bands(context)

        assert result =~ ~r/class="#{expected_class}"/,
               "Expected #{band_type} to have class #{expected_class}"
      end
    end

    test "renders group bands with group level attribute" do
      group_header = Band.new(:group_header,
        type: :group_header,
        group_level: 2,
        elements: []
      )

      report = %Report{name: :test_report, bands: [group_header]}
      context = %RenderContext{report: report, records: []}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/data-group-level="2"/
    end
  end

  describe "element rendering" do
    test "renders field element with value from record" do
      element = %{
        name: :customer_name,
        type: :field,
        source: :name,
        position: %{x: 0, y: 0, width: 100, height: 20},
        style: %{}
      }

      band = Band.new(:detail, type: :detail, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      records = [%{name: "Acme Corp"}]
      context = %RenderContext{report: report, records: records}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/class="field-element"/
      assert result =~ ~r/Acme Corp/
    end

    test "renders label element with text" do
      element = %{
        name: :header_label,
        type: :label,
        text: "Customer Report",
        position: %{},
        style: %{}
      }

      band = Band.new(:title, type: :title, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      context = %RenderContext{report: report, records: []}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/class="label-element"/
      assert result =~ ~r/Customer Report/
    end

    test "renders aggregate element with variable value" do
      element = %{
        name: :total_amount,
        type: :aggregate,
        variable_name: :total,
        position: %{},
        style: %{}
      }

      band = Band.new(:summary, type: :summary, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      context = %RenderContext{
        report: report,
        records: [],
        variables: %{total: 1500.00}
      }

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/class="aggregate-element"/
      assert result =~ ~r/1500/
    end

    test "renders expression element with simple field reference" do
      element = %{
        name: :expr,
        type: :expression,
        expression: :amount,
        position: %{},
        style: %{}
      }

      band = Band.new(:detail, type: :detail, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      records = [%{amount: 250}]
      context = %RenderContext{report: report, records: records}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/class="expression-element"/
      assert result =~ ~r/250/
    end

    test "renders line element as hr" do
      element = %{
        name: :separator,
        type: :line,
        position: %{width: 100},
        style: %{}
      }

      band = Band.new(:detail_footer, type: :detail_footer, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      context = %RenderContext{report: report, records: []}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/<hr class="line-element"/
    end

    test "renders box element as div" do
      element = %{
        name: :box,
        type: :box,
        position: %{width: 50, height: 50},
        style: %{border: %{}}
      }

      band = Band.new(:title, type: :title, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      context = %RenderContext{report: report, records: []}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/<div class="box-element"/
    end

    test "renders image element with src and alt" do
      element = %{
        name: :logo,
        type: :image,
        source: "/images/logo.png",
        alt: "Company Logo",
        position: %{},
        style: %{}
      }

      band = Band.new(:page_header, type: :page_header, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      context = %RenderContext{report: report, records: []}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/<img class="image-element"/
      assert result =~ ~r/src="\/images\/logo.png"/
      assert result =~ ~r/alt="Company Logo"/
    end
  end

  describe "error handling" do
    test "shows error placeholder for missing field" do
      element = %{
        name: :missing_field,
        type: :field,
        source: :nonexistent,
        position: %{},
        style: %{}
      }

      band = Band.new(:detail, type: :detail, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      records = [%{name: "Test"}]
      context = %RenderContext{report: report, records: records}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/\[MISSING: nonexistent\]/
    end

    test "shows error placeholder for missing variable" do
      element = %{
        name: :missing_var,
        type: :aggregate,
        variable_name: :nonexistent_var,
        position: %{},
        style: %{}
      }

      band = Band.new(:summary, type: :summary, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      context = %RenderContext{report: report, records: [], variables: %{}}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/\[MISSING_VAR: nonexistent_var\]/
    end

    test "handles nil report gracefully" do
      context = %RenderContext{report: nil, records: []}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/<div class="ash-report"/
    end
  end

  describe "styling" do
    test "applies position styles to elements" do
      element = %{
        name: :positioned_field,
        type: :field,
        source: :value,
        position: %{x: 10, y: 20, width: 100, height: 30},
        style: %{}
      }

      band = Band.new(:detail, type: :detail, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      records = [%{value: "Test"}]
      context = %RenderContext{report: report, records: records}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/position: absolute/
      assert result =~ ~r/left: 10px/
      assert result =~ ~r/top: 20px/
      assert result =~ ~r/width: 100px/
      assert result =~ ~r/height: 30px/
    end

    test "applies text styles to elements" do
      element = %{
        name: :styled_label,
        type: :label,
        text: "Bold Title",
        position: %{},
        style: %{
          font: "Arial",
          font_size: 16,
          font_weight: :bold,
          text_align: :center,
          color: "#333"
        }
      }

      band = Band.new(:title, type: :title, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      context = %RenderContext{report: report, records: []}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/font-family: Arial/
      assert result =~ ~r/font-size: 16px/
      assert result =~ ~r/font-weight: bold/
      assert result =~ ~r/text-align: center/
      assert result =~ ~r/color: #333/
    end
  end

  describe "band visibility" do
    test "hides bands with visible: false" do
      hidden_band = Band.new(:hidden, type: :title, visible: false, elements: [
        %{name: :label, type: :label, text: "Should not appear", position: %{}, style: %{}}
      ])

      visible_band = Band.new(:visible, type: :summary, visible: true, elements: [
        %{name: :label, type: :label, text: "Should appear", position: %{}, style: %{}}
      ])

      report = %Report{name: :test_report, bands: [hidden_band, visible_band]}
      context = %RenderContext{report: report, records: []}

      result = BandRenderer.render_report_bands(context)

      refute result =~ ~r/Should not appear/
      assert result =~ ~r/Should appear/
    end
  end

  describe "value formatting" do
    test "formats currency values" do
      element = %{
        name: :amount,
        type: :field,
        source: :price,
        format: :currency,
        position: %{},
        style: %{}
      }

      band = Band.new(:detail, type: :detail, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      records = [%{price: 1500}]
      context = %RenderContext{report: report, records: records}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/\$1500/
    end

    test "formats percentage values" do
      element = %{
        name: :rate,
        type: :field,
        source: :discount,
        format: :percentage,
        position: %{},
        style: %{}
      }

      band = Band.new(:detail, type: :detail, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      records = [%{discount: 0.15}]
      context = %RenderContext{report: report, records: records}

      result = BandRenderer.render_report_bands(context)

      assert result =~ ~r/15\.0+%/
    end

    test "includes raw HTML values (HEEX engine will handle escaping)" do
      element = %{
        name: :description,
        type: :field,
        source: :desc,
        position: %{},
        style: %{}
      }

      band = Band.new(:detail, type: :detail, elements: [element])
      report = %Report{name: :test_report, bands: [band]}
      records = [%{desc: "<script>alert('xss')</script>"}]
      context = %RenderContext{report: report, records: records}

      result = BandRenderer.render_report_bands(context)

      # BandRenderer generates HEEX template strings, not rendered HTML
      # The HEEX engine will handle escaping when the template is compiled
      assert result =~ ~r/<script>/
    end
  end

  describe "group handling" do
    test "renders grouped report with single-level grouping" do
      group = %Group{name: :region_group, level: 1, expression: :region}

      group_header = Band.new(:group_header,
        type: :group_header,
        group_level: 1,
        elements: [
          %{name: :region_label, type: :label, text: "Region:", position: %{}, style: %{}}
        ]
      )

      detail = Band.new(:detail,
        type: :detail,
        elements: [
          %{name: :name, type: :field, source: :name, position: %{}, style: %{}}
        ]
      )

      group_footer = Band.new(:group_footer,
        type: :group_footer,
        group_level: 1,
        elements: [
          %{name: :count, type: :aggregate, variable_name: :count, position: %{}, style: %{}}
        ]
      )

      report = %Report{
        name: :grouped_report,
        bands: [group_header, detail, group_footer],
        groups: [group]
      }

      records = [
        %{region: "West", name: "Alice"},
        %{region: "West", name: "Bob"},
        %{region: "East", name: "Charlie"}
      ]

      context = %RenderContext{report: report, records: records}
      result = BandRenderer.render_report_bands(context)

      # Should have two group headers (West, East)
      assert result =~ ~r/class="group-header-band".*data-group-level="1"/s
      assert result =~ ~r/data-group-value="West"/
      assert result =~ ~r/data-group-value="East"/

      # Should have group footers with counts
      assert result =~ ~r/class="group-footer-band"/
      assert result =~ ~r/data-group-count="2"/ # West group has 2 records
      assert result =~ ~r/data-group-count="1"/ # East group has 1 record

      # Should have all detail records
      assert result =~ ~r/Alice/
      assert result =~ ~r/Bob/
      assert result =~ ~r/Charlie/
    end

    test "calculates group aggregates correctly" do
      group = %Group{name: :region_group, level: 1, expression: :region}

      detail = Band.new(:detail,
        type: :detail,
        elements: [
          %{name: :amount, type: :field, source: :amount, position: %{}, style: %{}}
        ]
      )

      group_footer = Band.new(:group_footer,
        type: :group_footer,
        group_level: 1,
        elements: [
          %{name: :amount_sum, type: :aggregate, variable_name: "amount_sum", position: %{}, style: %{}}
        ]
      )

      report = %Report{
        name: :grouped_report,
        bands: [detail, group_footer],
        groups: [group]
      }

      records = [
        %{region: "West", amount: 100},
        %{region: "West", amount: 200},
        %{region: "East", amount: 150}
      ]

      context = %RenderContext{report: report, records: records}
      result = BandRenderer.render_report_bands(context)

      # West group sum: 100 + 200 = 300
      assert result =~ ~r/300/

      # East group sum: 150
      assert result =~ ~r/150/
    end

    test "handles multi-level grouping" do
      region_group = %Group{name: :region_group, level: 1, expression: :region}
      category_group = %Group{name: :category_group, level: 2, expression: :category}

      group_header_1 = Band.new(:group_header_1,
        type: :group_header,
        group_level: 1,
        elements: []
      )

      group_header_2 = Band.new(:group_header_2,
        type: :group_header,
        group_level: 2,
        elements: []
      )

      detail = Band.new(:detail,
        type: :detail,
        elements: [
          %{name: :name, type: :field, source: :name, position: %{}, style: %{}}
        ]
      )

      report = %Report{
        name: :multilevel_report,
        bands: [group_header_1, group_header_2, detail],
        groups: [region_group, category_group]
      }

      records = [
        %{region: "West", category: "A", name: "Alice"},
        %{region: "West", category: "A", name: "Bob"},
        %{region: "West", category: "B", name: "Carol"},
        %{region: "East", category: "A", name: "Dave"}
      ]

      context = %RenderContext{report: report, records: records}
      result = BandRenderer.render_report_bands(context)

      # Should have group headers for both levels
      assert result =~ ~r/data-group-level="1"/
      assert result =~ ~r/data-group-level="2"/

      # Should have correct group values
      assert result =~ ~r/data-group-value="West"/
      assert result =~ ~r/data-group-value="East"/
      assert result =~ ~r/data-group-value="A"/
      assert result =~ ~r/data-group-value="B"/
    end

    test "renders without grouping when no groups configured" do
      detail = Band.new(:detail,
        type: :detail,
        elements: [
          %{name: :name, type: :field, source: :name, position: %{}, style: %{}}
        ]
      )

      report = %Report{
        name: :ungrouped_report,
        bands: [detail],
        groups: []
      }

      records = [
        %{name: "Alice"},
        %{name: "Bob"}
      ]

      context = %RenderContext{report: report, records: records}
      result = BandRenderer.render_report_bands(context)

      # Should render as regular detail band
      assert result =~ ~r/class="detail-band"/
      assert result =~ ~r/Alice/
      assert result =~ ~r/Bob/

      # Should not have group bands
      refute result =~ ~r/class="group-header-band"/
      refute result =~ ~r/class="group-footer-band"/
    end

    test "accesses group aggregates in footer elements" do
      group = %Group{name: :dept_group, level: 1, expression: :department}

      detail = Band.new(:detail, type: :detail, elements: [])

      group_footer = Band.new(:group_footer,
        type: :group_footer,
        group_level: 1,
        elements: [
          %{name: :total_label, type: :label, text: "Total:", position: %{}, style: %{}},
          %{name: :count_agg, type: :aggregate, variable_name: :count, position: %{}, style: %{}}
        ]
      )

      report = %Report{
        name: :dept_report,
        bands: [detail, group_footer],
        groups: [group]
      }

      records = [
        %{department: "Sales", value: 1},
        %{department: "Sales", value: 2},
        %{department: "Sales", value: 3}
      ]

      context = %RenderContext{report: report, records: records}
      result = BandRenderer.render_report_bands(context)

      # Should show count of 3 in footer
      assert result =~ ~r/Total:/
      assert result =~ "3"
      assert result =~ ~r/class="aggregate-element"/
    end

    test "renders title and summary bands alongside grouped bands" do
      title = Band.new(:title,
        type: :title,
        elements: [
          %{name: :title, type: :label, text: "Sales Report", position: %{}, style: %{}}
        ]
      )

      group = %Group{name: :region_group, level: 1, expression: :region}

      group_header = Band.new(:group_header, type: :group_header, group_level: 1, elements: [])
      detail = Band.new(:detail, type: :detail, elements: [])

      summary = Band.new(:summary,
        type: :summary,
        elements: [
          %{name: :summary, type: :label, text: "End of Report", position: %{}, style: %{}}
        ]
      )

      report = %Report{
        name: :full_report,
        bands: [title, group_header, detail, summary],
        groups: [group]
      }

      records = [
        %{region: "West", amount: 100},
        %{region: "East", amount: 200}
      ]

      context = %RenderContext{report: report, records: records}
      result = BandRenderer.render_report_bands(context)

      # Should have title at top
      assert result =~ ~r/class="title-band"/
      assert result =~ ~r/Sales Report/

      # Should have grouped content
      assert result =~ ~r/class="group-header-band"/

      # Should have summary at bottom
      assert result =~ ~r/class="summary-band"/
      assert result =~ ~r/End of Report/
    end
  end

  describe "realistic data integration" do
    setup do
      AshReports.RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
    end

    test "renders customer detail band with realistic data" do
      customers = AshReports.RealisticTestHelpers.list_customers(limit: 5)
      simple_customers = AshReports.RealisticTestHelpers.to_simple_maps(customers)

      detail_band = Band.new(:detail,
        type: :detail,
        elements: [
          %{name: :name_field, type: :field, source: :name, position: %{}, style: %{}}
        ]
      )

      report = %Report{name: :customer_report, bands: [detail_band]}
      context = %RenderContext{report: report, records: simple_customers}

      result = BandRenderer.render_report_bands(context)

      assert is_binary(result)
      assert result =~ "detail-band"
      # Should render all customers
      Enum.each(simple_customers, fn customer ->
        assert result =~ customer.name
      end)
    end

    test "renders invoice list with multiple band types" do
      invoices = AshReports.RealisticTestHelpers.list_invoices(limit: 10)
      simple_invoices = AshReports.RealisticTestHelpers.to_simple_maps(invoices)

      header_band = Band.new(:page_header, type: :page_header, elements: [
        %{name: :title, type: :label, text: "Invoice Report", position: %{}, style: %{}}
      ])

      detail_band = Band.new(:detail, type: :detail, elements: [
        %{name: :invoice_number, type: :field, source: :invoice_number, position: %{}, style: %{}}
      ])

      footer_band = Band.new(:page_footer, type: :page_footer, elements: [
        %{name: :footer_text, type: :label, text: "End of Report", position: %{}, style: %{}}
      ])

      report = %Report{name: :invoice_report, bands: [header_band, detail_band, footer_band]}
      context = %RenderContext{report: report, records: simple_invoices}

      result = BandRenderer.render_report_bands(context)

      assert result =~ "page-header-band"
      assert result =~ "detail-band"
      assert result =~ "page-footer-band"
    end

    test "handles large realistic dataset efficiently" do
      customers = AshReports.RealisticTestHelpers.list_customers(limit: 25)
      simple_customers = AshReports.RealisticTestHelpers.to_simple_maps(customers)

      detail_band = Band.new(:detail, type: :detail, elements: [
        %{name: :name, type: :field, source: :name, position: %{}, style: %{}}
      ])

      report = %Report{name: :large_report, bands: [detail_band]}
      context = %RenderContext{report: report, records: simple_customers}

      start_time = System.monotonic_time(:microsecond)
      result = BandRenderer.render_report_bands(context)
      processing_time = System.monotonic_time(:microsecond) - start_time

      assert is_binary(result)
      assert result =~ "detail-band"
      # Should complete in reasonable time
      assert processing_time < 1_000_000
    end
  end
end
