defmodule AshReports.Dsl do
  @moduledoc """
  DSL components for AshReports.

  This module provides the core DSL building blocks for defining reports,
  including sections, entities, and their schemas.
  """

  alias Spark.Dsl.{Entity, Section}

  @doc """
  The main reports section that contains all report definitions.
  """
  def reports_section do
    %Section{
      name: :reports,
      describe: """
      Configure reports for this domain.

      Reports are defined with a hierarchical band structure and can be rendered
      in multiple formats (HTML, PDF, HEEX, JSON).
      """,
      examples: [
        """
        reports do
          report :sales_report do
            title "Monthly Sales Report"
            description "Summary of sales by region and product"
            driving_resource Sales

            parameters do
              parameter :start_date, :date, required: true
              parameter :end_date, :date, required: true
              parameter :region, :string
            end

            format_specs do
              format_spec :sales_currency do
                pattern "¤ #,##0.00"
                currency :USD
                locale "en"
              end

              format_spec :conditional_amount do
                condition value > 10000, pattern: "#,##0K", color: :green
                condition value < 0, pattern: "(#,##0)", color: :red
                pattern "#,##0.00"
              end
            end

            bands do
              band :title do
                type :title
                elements do
                  label :report_title do
                    text "Sales Report"
                  end
                end
              end

              band :details do
                type :detail
                elements do
                  field :product_name do
                    source :product.name
                  end
                  field :quantity do
                    source :quantity
                    format :number
                  end
                  field :total do
                    source :total_amount
                    format_spec :conditional_amount
                  end
                end
              end
            end
          end
        end
        """
      ],
      entities: [
        report_entity(),
        bar_chart_entity(),
        line_chart_entity(),
        pie_chart_entity(),
        area_chart_entity(),
        scatter_chart_entity(),
        gantt_chart_entity(),
        sparkline_entity()
      ],
      schema: []
    }
  end

  @doc """
  The report entity definition.
  """
  def report_entity do
    %Entity{
      name: :report,
      describe: """
      Defines a report with its structure, data source, and rendering options.
      """,
      examples: [
        """
        report :monthly_sales do
          title "Monthly Sales Report"
          driving_resource Sales
        end
        """
      ],
      target: AshReports.Report,
      args: [:name],
      schema: report_schema(),
      entities: [
        parameters: [parameter_entity()],
        bands: [band_entity()],
        variables: [variable_entity()],
        groups: [group_entity()],
        format_specs: [format_spec_entity()]
      ]
    }
  end

  @doc """
  The parameter entity for defining report parameters.
  """
  def parameter_entity do
    %Entity{
      name: :parameter,
      describe: """
      Defines a runtime parameter that can be passed to the report.
      """,
      examples: [
        """
        parameter :start_date, :date, required: true
        parameter :region, :string, default: "North"
        """
      ],
      target: AshReports.Parameter,
      args: [:name, :type],
      schema: parameter_schema()
    }
  end

  @doc """
  The band entity for defining report bands.
  """
  def band_entity do
    %Entity{
      name: :band,
      describe: """
      Defines a band within the report structure.

      Bands are the fundamental building blocks of reports and can be of various types:
      title, page_header, column_header, group_header, detail, etc.
      """,
      examples: [
        """
        band :header do
          type :page_header
          elements do
            label :page_title do
              text "Sales Report"
            end
          end
        end
        """
      ],
      target: AshReports.Band,
      args: [:name],
      schema: band_schema(),
      entities: [
        elements: [
          label_element_entity(),
          field_element_entity(),
          expression_element_entity(),
          aggregate_element_entity(),
          line_element_entity(),
          box_element_entity(),
          image_element_entity(),
          bar_chart_element_entity(),
          line_chart_element_entity(),
          pie_chart_element_entity(),
          area_chart_element_entity(),
          scatter_chart_element_entity(),
          gantt_chart_element_entity(),
          sparkline_element_entity()
        ],
        grids: [grid_entity()],
        tables: [table_entity()],
        stacks: [stack_entity()]
      ],
      recursive_as: :bands
    }
  end

  @doc """
  The variable entity for defining report variables.
  """
  def variable_entity do
    %Entity{
      name: :variable,
      describe: """
      Defines a variable that accumulates values during report execution.
      """,
      examples: [
        """
        variable :total_sales do
          type :sum
          expression expr(amount)
          reset_on :report
        end
        """
      ],
      target: AshReports.Variable,
      args: [:name],
      schema: variable_schema()
    }
  end

  @doc """
  The format specification entity for defining custom formatting patterns.
  """
  def format_spec_entity do
    %Entity{
      name: :format_spec,
      describe: """
      Defines a reusable format specification for consistent formatting across the report.

      Format specifications allow you to define complex formatting rules that can be
      referenced by name in field, expression, and aggregate elements.
      """,
      examples: [
        """
        format_spec :company_currency do
          pattern "¤ #,##0.00"
          currency :USD
          locale "en"
        end

        format_spec :conditional_amount do
          condition value > 1000, pattern: "#,##0K", color: :green
          condition value < 0, pattern: "(#,##0)", color: :red
          default_pattern "#,##0.00"
        end
        """
      ],
      target: AshReports.FormatSpecification,
      args: [:name],
      schema: format_spec_schema()
    }
  end

  @doc """
  The group entity for defining report grouping.
  """
  def group_entity do
    %Entity{
      name: :group,
      describe: """
      Defines a grouping level for the report data.
      """,
      examples: [
        """
        group :by_region do
          level 1
          expression expr(region)
          sort :asc
        end
        """
      ],
      target: AshReports.Group,
      args: [:name],
      schema: group_schema()
    }
  end

  # Element entities

  defp label_element_entity do
    %Entity{
      name: :label,
      describe: "A static text label element.",
      target: AshReports.Element.Label,
      args: [:name],
      schema: label_element_schema()
    }
  end

  defp field_element_entity do
    %Entity{
      name: :field,
      describe: "A data field element that displays resource attributes.",
      target: AshReports.Element.Field,
      args: [:name],
      schema: field_element_schema()
    }
  end

  defp expression_element_entity do
    %Entity{
      name: :expression,
      describe: "A calculated expression element.",
      target: AshReports.Element.Expression,
      args: [:name],
      schema: expression_element_schema()
    }
  end

  defp aggregate_element_entity do
    %Entity{
      name: :aggregate,
      describe: "An aggregate calculation element.",
      target: AshReports.Element.Aggregate,
      args: [:name],
      schema: aggregate_element_schema()
    }
  end

  defp line_element_entity do
    %Entity{
      name: :line,
      describe: "A line separator element.",
      target: AshReports.Element.Line,
      args: [:name],
      schema: line_element_schema()
    }
  end

  defp box_element_entity do
    %Entity{
      name: :box,
      describe: "A box container element.",
      target: AshReports.Element.Box,
      args: [:name],
      schema: box_element_schema()
    }
  end

  defp image_element_entity do
    %Entity{
      name: :image,
      describe: "An image element.",
      target: AshReports.Element.Image,
      args: [:name],
      schema: image_element_schema()
    }
  end

  defp bar_chart_element_entity do
    %Entity{
      name: :bar_chart,
      describe: """
      References a standalone bar chart definition in a report band.

      The chart_name must match a bar_chart defined at the reports level.
      """,
      target: AshReports.Element.BarChartElement,
      args: [:chart_name],
      schema: bar_chart_element_schema()
    }
  end

  defp line_chart_element_entity do
    %Entity{
      name: :line_chart,
      describe: """
      References a standalone line chart definition in a report band.

      The chart_name must match a line_chart defined at the reports level.
      """,
      target: AshReports.Element.LineChartElement,
      args: [:chart_name],
      schema: line_chart_element_schema()
    }
  end

  defp pie_chart_element_entity do
    %Entity{
      name: :pie_chart,
      describe: """
      References a standalone pie chart definition in a report band.

      The chart_name must match a pie_chart defined at the reports level.
      """,
      target: AshReports.Element.PieChartElement,
      args: [:chart_name],
      schema: pie_chart_element_schema()
    }
  end

  defp area_chart_element_entity do
    %Entity{
      name: :area_chart,
      describe: """
      References a standalone area chart definition in a report band.

      The chart_name must match an area_chart defined at the reports level.
      """,
      target: AshReports.Element.AreaChartElement,
      args: [:chart_name],
      schema: area_chart_element_schema()
    }
  end

  defp scatter_chart_element_entity do
    %Entity{
      name: :scatter_chart,
      describe: """
      References a standalone scatter chart definition in a report band.

      The chart_name must match a scatter_chart defined at the reports level.
      """,
      target: AshReports.Element.ScatterChartElement,
      args: [:chart_name],
      schema: scatter_chart_element_schema()
    }
  end

  defp gantt_chart_element_entity do
    %Entity{
      name: :gantt_chart,
      describe: """
      References a standalone gantt chart definition in a report band.

      The chart_name must match a gantt_chart defined at the reports level.
      """,
      target: AshReports.Element.GanttChartElement,
      args: [:chart_name],
      schema: gantt_chart_element_schema()
    }
  end

  defp sparkline_element_entity do
    %Entity{
      name: :sparkline,
      describe: """
      References a standalone sparkline definition in a report band.

      The chart_name must match a sparkline defined at the reports level.
      """,
      target: AshReports.Element.SparklineElement,
      args: [:chart_name],
      schema: sparkline_element_schema()
    }
  end

  # Layout container entities

  @doc """
  The grid layout container entity definition.
  """
  def grid_entity do
    %Entity{
      name: :grid,
      describe: """
      A grid layout container for 2D presentational layouts.

      Grids provide flexible layout capabilities with configurable columns and rows.
      Use grids for layout/presentation purposes where the arrangement itself
      doesn't convey tabular data semantics.
      """,
      examples: [
        """
        grid :metrics_grid do
          columns [fr(1), fr(1), fr(1)]
          gutter "10pt"
          align :center

          label :label1 do
            text "Revenue"
          end

          field :revenue do
            source :total_revenue
            format :currency
          end
        end
        """
      ],
      target: AshReports.Layout.Grid,
      args: [:name],
      schema: grid_schema(),
      entities: [
        elements: [
          label_element_entity(),
          field_element_entity(),
          expression_element_entity(),
          aggregate_element_entity(),
          line_element_entity(),
          box_element_entity(),
          image_element_entity(),
          bar_chart_element_entity(),
          line_chart_element_entity(),
          pie_chart_element_entity(),
          area_chart_element_entity(),
          scatter_chart_element_entity(),
          gantt_chart_element_entity(),
          sparkline_element_entity()
        ],
        row_entities: [row_entity()],
        grid_cells: [grid_cell_entity()]
      ]
    }
  end

  @doc """
  The table layout container entity definition.
  """
  def table_entity do
    %Entity{
      name: :table,
      describe: """
      A table layout container for semantic data presentation.

      Tables carry semantic meaning and are accessible to assistive technologies.
      Unlike grids, tables default to having visible borders (stroke: "1pt") and
      cell padding (inset: "5pt").
      """,
      examples: [
        """
        table :data_table do
          columns [fr(1), fr(2), fr(1)]
          stroke "0.5pt"
          inset "5pt"

          header repeat: true do
            cell do
              label text: "Name"
            end
          end

          cell do
            field source: :name
          end
        end
        """
      ],
      target: AshReports.Layout.Table,
      args: [:name],
      schema: table_schema(),
      entities: [
        elements: [
          label_element_entity(),
          field_element_entity(),
          expression_element_entity(),
          aggregate_element_entity(),
          line_element_entity(),
          box_element_entity(),
          image_element_entity(),
          bar_chart_element_entity(),
          line_chart_element_entity(),
          pie_chart_element_entity(),
          area_chart_element_entity(),
          scatter_chart_element_entity(),
          gantt_chart_element_entity(),
          sparkline_element_entity()
        ],
        row_entities: [row_entity()],
        table_cells: [table_cell_entity()],
        headers: [header_entity()],
        footers: [footer_entity()]
      ]
    }
  end

  @doc """
  The stack layout container entity definition.
  """
  def stack_entity do
    %Entity{
      name: :stack,
      describe: """
      A stack layout container for 1D sequential arrangement.

      Stacks arrange elements in a single direction with configurable spacing.
      Supports top-to-bottom (:ttb), bottom-to-top (:btt), left-to-right (:ltr),
      and right-to-left (:rtl) directions.
      """,
      examples: [
        """
        stack :address_info do
          dir :ttb
          spacing "3pt"

          label :street do
            text "[street_address]"
          end

          label :city_state do
            text "[city], [state] [zip]"
          end
        end
        """
      ],
      target: AshReports.Layout.Stack,
      args: [:name],
      schema: stack_schema(),
      entities: [
        elements: [
          label_element_entity(),
          field_element_entity(),
          expression_element_entity(),
          aggregate_element_entity(),
          line_element_entity(),
          box_element_entity(),
          image_element_entity(),
          bar_chart_element_entity(),
          line_chart_element_entity(),
          pie_chart_element_entity(),
          area_chart_element_entity(),
          scatter_chart_element_entity(),
          gantt_chart_element_entity(),
          sparkline_element_entity()
        ]
      ]
    }
  end

  @doc """
  The row entity for explicit row containers within grid/table.
  """
  def row_entity do
    %Entity{
      name: :row,
      describe: """
      An explicit row container within grid/table layouts.

      Rows allow grouping cells with shared properties like height, fill, stroke,
      and default alignment/padding that propagate to child cells.
      """,
      examples: [
        """
        row :header_row do
          height "30pt"
          fill "#f0f0f0"
          align :center

          cell do
            label text: "Name"
          end
        end
        """
      ],
      target: AshReports.Layout.Row,
      args: [:name],
      schema: row_schema(),
      entities: [
        elements: [
          label_element_entity(),
          field_element_entity(),
          expression_element_entity(),
          aggregate_element_entity(),
          line_element_entity(),
          box_element_entity(),
          image_element_entity(),
          bar_chart_element_entity(),
          line_chart_element_entity(),
          pie_chart_element_entity(),
          area_chart_element_entity(),
          scatter_chart_element_entity(),
          gantt_chart_element_entity(),
          sparkline_element_entity()
        ]
      ]
    }
  end

  @doc """
  The grid cell entity for individual cells within grids.
  """
  def grid_cell_entity do
    %Entity{
      name: :grid_cell,
      describe: """
      An individual cell within grid layouts.

      Grid cells can be positioned using x/y coordinates and override parent properties.
      They contain only leaf elements (no nested containers).
      """,
      examples: [
        """
        grid_cell do
          x 0
          y 1
          align :right

          field source: :total, format: :currency
        end
        """
      ],
      target: AshReports.Layout.GridCell,
      args: [],
      schema: grid_cell_schema(),
      entities: [
        elements: [
          label_element_entity(),
          field_element_entity(),
          expression_element_entity(),
          aggregate_element_entity(),
          line_element_entity(),
          box_element_entity(),
          image_element_entity(),
          bar_chart_element_entity(),
          line_chart_element_entity(),
          pie_chart_element_entity(),
          area_chart_element_entity(),
          scatter_chart_element_entity(),
          gantt_chart_element_entity(),
          sparkline_element_entity()
        ]
      ]
    }
  end

  @doc """
  The table cell entity for individual cells within tables.
  """
  def table_cell_entity do
    %Entity{
      name: :table_cell,
      describe: """
      An individual cell within table layouts.

      Table cells can span multiple columns/rows and override parent properties.
      They contain only leaf elements (no nested containers).
      """,
      examples: [
        """
        table_cell do
          colspan 2
          align :right

          field source: :total, format: :currency
        end
        """
      ],
      target: AshReports.Layout.TableCell,
      args: [],
      schema: table_cell_schema(),
      entities: [
        elements: [
          label_element_entity(),
          field_element_entity(),
          expression_element_entity(),
          aggregate_element_entity(),
          line_element_entity(),
          box_element_entity(),
          image_element_entity(),
          bar_chart_element_entity(),
          line_chart_element_entity(),
          pie_chart_element_entity(),
          area_chart_element_entity(),
          scatter_chart_element_entity(),
          gantt_chart_element_entity(),
          sparkline_element_entity()
        ]
      ]
    }
  end

  @doc """
  The header entity for table header sections.
  """
  def header_entity do
    %Entity{
      name: :header,
      describe: """
      A table header section that can repeat on each page.

      Headers are semantic table sections supporting accessibility requirements.
      """,
      examples: [
        """
        header repeat: true do
          cell do
            label text: "Name"
          end

          cell do
            label text: "Value"
          end
        end
        """
      ],
      target: AshReports.Layout.Header,
      args: [],
      schema: header_schema(),
      entities: [
        table_cells: [table_cell_entity()]
      ]
    }
  end

  @doc """
  The footer entity for table footer sections.
  """
  def footer_entity do
    %Entity{
      name: :footer,
      describe: """
      A table footer section that can repeat on each page.

      Footers are semantic table sections supporting accessibility requirements.
      """,
      examples: [
        """
        footer repeat: true do
          cell colspan: 2 do
            label text: "Total"
          end

          cell do
            field source: :grand_total, format: :currency
          end
        end
        """
      ],
      target: AshReports.Layout.Footer,
      args: [],
      schema: footer_schema(),
      entities: [
        table_cells: [table_cell_entity()]
      ]
    }
  end

  @doc """
  Standalone bar chart entity for reports section.
  """
  def bar_chart_entity do
    %Entity{
      name: :bar_chart,
      describe: """
      Defines a standalone bar chart that can be referenced in report bands.

      Bar charts are ideal for comparing values across categories with support
      for grouped and stacked variations.
      """,
      examples: [
        """
        bar_chart :sales_by_region do
          driving_resource Sales

          transform do
            group_by :region
            as_category :group_key
            as_value :total

            aggregates do
              aggregate type: :count, as: :total
            end
          end

          config do
            width 600
            height 400
            title "Sales by Region"
            type :simple
            orientation :vertical
            data_labels true
          end
        end
        """
      ],
      target: AshReports.Charts.BarChart,
      args: [:name],
      schema: bar_chart_schema(),
      entities: [
        transform: [transform_entity()],
        config: [bar_chart_config_entity()]
      ]
    }
  end

  defp bar_chart_config_entity do
    %Entity{
      name: :config,
      describe: "Configuration for bar chart rendering.",
      target: AshReports.Charts.BarChartConfig,
      schema: bar_chart_config_schema()
    }
  end

  @doc """
  Standalone line chart entity for reports section.
  """
  def line_chart_entity do
    %Entity{
      name: :line_chart,
      describe: """
      Defines a standalone line chart that can be referenced in report bands.

      Line charts are ideal for showing trends over time or continuous data.
      """,
      examples: [
        """
        line_chart :revenue_trend do
          driving_resource Sales

          transform do
            group_by {:created_at, :month}
            as_x :group_key
            as_y :total

            aggregates do
              aggregate type: :sum, field: :amount, as: :total
            end
          end

          config do
            width 800
            height 400
            title "Revenue Trend"
            smoothed true
            stroke_width "2"
          end
        end
        """
      ],
      target: AshReports.Charts.LineChart,
      args: [:name],
      schema: line_chart_schema(),
      entities: [
        transform: [transform_entity()],
        config: [line_chart_config_entity()]
      ]
    }
  end

  defp line_chart_config_entity do
    %Entity{
      name: :config,
      describe: "Configuration for line chart rendering.",
      target: AshReports.Charts.LineChartConfig,
      schema: line_chart_config_schema()
    }
  end

  @doc """
  Standalone pie chart entity for reports section.
  """
  def pie_chart_entity do
    %Entity{
      name: :pie_chart,
      describe: """
      Defines a standalone pie chart that can be referenced in report bands.

      Pie charts are ideal for showing proportions and percentage breakdowns.
      """,
      examples: [
        """
        pie_chart :market_share do
          driving_resource Customer

          transform do
            group_by :region
            as_category :group_key
            as_value :count

            aggregates do
              aggregate type: :count, as: :count
            end
          end

          config do
            width 500
            height 500
            title "Market Share by Region"
            data_labels true
          end
        end
        """
      ],
      target: AshReports.Charts.PieChart,
      args: [:name],
      schema: pie_chart_schema(),
      entities: [
        transform: [transform_entity()],
        config: [pie_chart_config_entity()]
      ]
    }
  end

  defp pie_chart_config_entity do
    %Entity{
      name: :config,
      describe: "Configuration for pie chart rendering.",
      target: AshReports.Charts.PieChartConfig,
      schema: pie_chart_config_schema()
    }
  end

  @doc """
  Standalone area chart entity for reports section.
  """
  def area_chart_entity do
    %Entity{
      name: :area_chart,
      describe: """
      Defines a standalone area chart that can be referenced in report bands.

      Area charts show cumulative totals or volume over time with filled areas.
      """,
      examples: [
        """
        area_chart :cumulative_sales do
          driving_resource Sales

          transform do
            group_by {:created_at, :day}
            as_x :group_key
            as_y :total

            aggregates do
              aggregate type: :sum, field: :amount, as: :total
            end
          end

          config do
            width 800
            height 400
            title "Cumulative Sales"
            mode :simple
            opacity 0.7
          end
        end
        """
      ],
      target: AshReports.Charts.AreaChart,
      args: [:name],
      schema: area_chart_schema(),
      entities: [
        transform: [transform_entity()],
        config: [area_chart_config_entity()]
      ]
    }
  end

  defp area_chart_config_entity do
    %Entity{
      name: :config,
      describe: "Configuration for area chart rendering.",
      target: AshReports.Charts.AreaChartConfig,
      schema: area_chart_config_schema()
    }
  end

  @doc """
  Standalone scatter chart entity for reports section.
  """
  def scatter_chart_entity do
    %Entity{
      name: :scatter_chart,
      describe: """
      Defines a standalone scatter chart that can be referenced in report bands.

      Scatter charts (point plots) show correlation between two variables.
      """,
      examples: [
        """
        scatter_chart :price_vs_quantity do
          driving_resource Product

          transform do
            as_x :price
            as_y :quantity
          end

          config do
            width 700
            height 500
            title "Price vs Quantity Analysis"
            axis_label_rotation :auto
          end
        end
        """
      ],
      target: AshReports.Charts.ScatterChart,
      args: [:name],
      schema: scatter_chart_schema(),
      entities: [
        transform: [transform_entity()],
        config: [scatter_chart_config_entity()]
      ]
    }
  end

  defp scatter_chart_config_entity do
    %Entity{
      name: :config,
      describe: "Configuration for scatter chart rendering.",
      target: AshReports.Charts.ScatterChartConfig,
      schema: scatter_chart_config_schema()
    }
  end

  @doc """
  Standalone Gantt chart entity for reports section.
  """
  def gantt_chart_entity do
    %Entity{
      name: :gantt_chart,
      describe: """
      Defines a standalone Gantt chart that can be referenced in report bands.

      Gantt charts visualize project timelines and task schedules.
      """,
      examples: [
        """
        gantt_chart :project_timeline do
          driving_resource Invoice

          transform do
            as_task :invoice_number
            as_start_date :date
            as_end_date {:date, :add_days, 30}
            sort_by {:date, :desc}
            limit 20

            filters do
              filter :status, [:sent, :paid, :overdue]
            end
          end

          config do
            width 900
            height 400
            title "Project Timeline"
            show_task_labels true
            padding 2
          end
        end
        """
      ],
      target: AshReports.Charts.GanttChart,
      args: [:name],
      schema: gantt_chart_schema(),
      entities: [
        transform: [transform_entity()],
        config: [gantt_chart_config_entity()]
      ]
    }
  end

  defp gantt_chart_config_entity do
    %Entity{
      name: :config,
      describe: "Configuration for Gantt chart rendering.",
      target: AshReports.Charts.GanttChartConfig,
      schema: gantt_chart_config_schema()
    }
  end

  @doc """
  Standalone sparkline entity for reports section.
  """
  def sparkline_entity do
    %Entity{
      name: :sparkline,
      describe: """
      Defines a standalone sparkline that can be referenced in report bands.

      Sparklines are compact inline charts showing trends at a glance.
      """,
      examples: [
        """
        sparkline :weekly_trend do
          driving_resource Customer

          transform do
            group_by {:updated_at, :day}
            as_values :avg_health
            sort_by {:group_key, :desc}
            limit 7

            aggregates do
              aggregate type: :avg, field: :customer_health_score, as: :avg_health
            end
          end

          config do
            width 100
            height 20
            spot_radius 2
            line_colour "rgba(0, 200, 50, 0.7)"
          end
        end
        """
      ],
      target: AshReports.Charts.Sparkline,
      args: [:name],
      schema: sparkline_schema(),
      entities: [
        transform: [transform_entity()],
        config: [sparkline_config_entity()]
      ]
    }
  end

  defp sparkline_config_entity do
    %Entity{
      name: :config,
      describe: "Configuration for sparkline rendering.",
      target: AshReports.Charts.SparklineConfig,
      schema: sparkline_config_schema()
    }
  end

  # Schemas

  defp report_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The unique name of the report."
      ],
      title: [
        type: :string,
        doc: "The display title of the report."
      ],
      description: [
        type: :string,
        doc: "A description of what the report contains."
      ],
      driving_resource: [
        type: :atom,
        required: true,
        doc: "The main Ash resource that drives the report data."
      ],
      base_filter: [
        type: :any,
        doc: "A function that takes params and returns an Ash.Query with base filters applied. This runs before parameter filters and sets the foundation for what data is loaded."
      ],
      permissions: [
        type: :any,
        default: [],
        doc: "List of required permissions to run this report."
      ],
      formats: [
        type: {:list, {:in, [:html, :pdf, :heex, :json]}},
        default: [:html],
        doc: "Supported output formats for this report."
      ]
    ]
  end

  defp parameter_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The parameter name."
      ],
      type: [
        type: :atom,
        required: true,
        doc: "The parameter type (e.g., :string, :integer, :date)."
      ],
      required: [
        type: :boolean,
        default: false,
        doc: "Whether this parameter is required."
      ],
      default: [
        type: :any,
        doc: "The default value for the parameter."
      ],
      constraints: [
        type: :keyword_list,
        default: [],
        doc: "Type-specific constraints for the parameter."
      ]
    ]
  end

  defp band_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The band identifier."
      ],
      type: [
        type:
          {:in,
           [
             :title,
             :page_header,
             :column_header,
             :group_header,
             :detail_header,
             :detail,
             :detail_footer,
             :group_footer,
             :column_footer,
             :page_footer,
             :summary
           ]},
        required: true,
        doc: "The type of band."
      ],
      group_level: [
        type: :pos_integer,
        doc: "For group bands, specifies the nesting level (1, 2, 3, etc.)."
      ],
      detail_number: [
        type: :pos_integer,
        doc: "For multiple detail bands, specifies which detail band (1, 2, etc.)."
      ],
      target_alias: [
        type: :any,
        doc: "Expression for related resource alias."
      ],
      on_entry: [
        type: :any,
        doc: "Expression to evaluate when entering the band."
      ],
      on_exit: [
        type: :any,
        doc: "Expression to evaluate when exiting the band."
      ],
      height: [
        type: :pos_integer,
        doc: "Fixed height of the band in rendering units."
      ],
      can_grow: [
        type: :boolean,
        default: true,
        doc: "Whether the band can expand to fit content."
      ],
      can_shrink: [
        type: :boolean,
        default: false,
        doc: "Whether the band can shrink if content is smaller."
      ],
      keep_together: [
        type: :boolean,
        default: false,
        doc: "Whether to prevent page breaks within this band."
      ],
      visible: [
        type: :any,
        default: true,
        doc: "Expression to determine if the band should be visible."
      ],
      columns: [
        type: {:or, [:pos_integer, :string, {:list, :string}]},
        default: 1,
        doc: """
        Column layout for this band. Can be:
        - Integer: Number of equal-width columns (e.g., 3)
        - String: Typst column spec (e.g., "(150pt, 1fr, 80pt)")
        - List of strings: Individual column widths (e.g., ["150pt", "1fr", "80pt"])
        Defaults to 1 (single column).
        """
      ],
      repeat_on_pages: [
        type: :boolean,
        default: true,
        doc: """
        For page_header and group_header bands, whether to repeat the header on each page.
        Defaults to true. Only applies to page_header and group_header band types.
        """
      ],
      padding: [
        type: :keyword_list,
        doc: """
        Padding for the band content. Controls the spacing inside table cells for this band.

        Accepts either:
        - A keyword list with directional values: `[left: "20pt", top: "10pt"]`
        - A single string value: `"10pt"` (applies to all sides)

        Directional options:
        - `left`: Left padding (e.g., "20pt")
        - `right`: Right padding (e.g., "15pt")
        - `top`: Top padding (e.g., "8pt")
        - `bottom`: Bottom padding (e.g., "8pt")

        Unspecified sides default to "5pt".

        Common use cases:
        - Indent detail rows in grouped reports: `padding left: "20pt"`
        - Add vertical spacing: `padding top: "10pt", bottom: "10pt"`
        - Remove padding: `padding "0pt"`

        Examples:
        ```elixir
        # Indent detail rows 20pt from the left
        band :customer_detail do
          type :detail
          padding left: "20pt"

          field :name do
            source :customer_name
          end
        end

        # Add vertical spacing to section headers
        band :section_header do
          type :group_header
          padding top: "15pt", bottom: "5pt"

          label :title do
            text("Section Title")
          end
        end

        # Apply uniform padding on all sides
        band :summary do
          type :summary
          padding "15pt"

          expression :total do
            expression :grand_total
          end
        end
        ```

        Implementation: Uses Typst's table `inset` property to control padding
        inside table cells. This is the recommended way to add spacing within bands.
        """
      ]
    ]
  end

  defp variable_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The variable name."
      ],
      type: [
        type: {:in, [:sum, :count, :average, :min, :max, :custom]},
        required: true,
        doc: "The type of variable calculation."
      ],
      expression: [
        type: :any,
        required: true,
        doc: "The expression to calculate the variable value."
      ],
      reset_on: [
        type: {:in, [:detail, :group, :page, :report]},
        default: :report,
        doc: "When to reset the variable value."
      ],
      reset_group: [
        type: :pos_integer,
        doc: "For group resets, which group level triggers the reset."
      ],
      initial_value: [
        type: :any,
        doc: "The initial value for the variable."
      ]
    ]
  end

  defp group_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The group identifier."
      ],
      level: [
        type: :pos_integer,
        required: true,
        doc: "The group nesting level (1 for top-level, 2 for sub-groups, etc.)."
      ],
      expression: [
        type: :any,
        required: true,
        doc: "The expression to calculate the group value."
      ],
      sort: [
        type: {:in, [:asc, :desc]},
        default: :asc,
        doc: "Sort order for the group values."
      ]
    ]
  end

  defp format_spec_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The format specification identifier."
      ],
      pattern: [
        type: :string,
        doc: "The default format pattern string."
      ],
      type: [
        type: {:in, [:number, :currency, :percentage, :date, :time, :datetime, :text, :custom]},
        doc: "The expected data type for this format specification."
      ],
      locale: [
        type: :string,
        doc: "Specific locale for this format specification."
      ],
      currency: [
        type: :atom,
        doc: "Currency code for currency formatting."
      ],
      conditions: [
        type: :keyword_list,
        default: [],
        doc: "List of conditional formatting rules as {condition, options} pairs."
      ],
      fallback: [
        type: :any,
        doc: "Fallback format specification or pattern when formatting fails."
      ],
      cache: [
        type: :boolean,
        default: true,
        doc: "Whether to cache the compiled format specification."
      ],
      transform: [
        type: {:in, [:none, :uppercase, :lowercase, :titlecase]},
        default: :none,
        doc: "Text transformation to apply."
      ],
      precision: [
        type: :non_neg_integer,
        doc: "Number of decimal places for number formatting."
      ],
      max_length: [
        type: :pos_integer,
        doc: "Maximum length for text formatting."
      ],
      truncate_suffix: [
        type: :string,
        default: "...",
        doc: "Suffix to add when text is truncated."
      ]
    ]
  end

  # Element schemas

  defp base_element_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The element identifier."
      ],
      position: [
        type: :keyword_list,
        default: [],
        doc: "Position properties (x, y, width, height). For absolute positioning only."
      ],
      style: [
        type: :keyword_list,
        default: [],
        doc: "Text style properties (font, font_size, font_weight, color, alignment). Maps to Typst text() function parameters."
      ],
      padding: [
        type: {:or, [:string, :keyword_list]},
        doc: "Padding around the element. Can be a single value (string like '10pt') or keyword list with :top, :bottom, :left, :right, :x, :y keys. Maps to Typst pad() function."
      ],
      margin: [
        type: {:or, [:string, :keyword_list]},
        doc: "Margin around the element. Can be a single value (string like '10pt') or keyword list with :top, :bottom, :left, :right, :x, :y keys. Used for spacing between elements."
      ],
      spacing_before: [
        type: :string,
        doc: "Vertical spacing before this element (e.g., '10pt', '1em'). Maps to Typst v() function."
      ],
      spacing_after: [
        type: :string,
        doc: "Vertical spacing after this element (e.g., '10pt', '1em'). Maps to Typst v() function."
      ],
      align: [
        type: :atom,
        doc: "Text alignment for this element (:left, :center, :right). Overrides table-level alignment for this cell."
      ],
      decimal_places: [
        type: :integer,
        doc: "Number of decimal places to display for numeric values. Uses Typst calc.round() for rounding."
      ],
      number_format: [
        type: :keyword_list,
        doc: "Number formatting options. Supports :decimal_places, :thousands_separator, :decimal_separator."
      ],
      conditional: [
        type: :any,
        doc: "Expression to determine if the element should be displayed."
      ]
    ]
  end

  defp label_element_schema do
    base_element_schema() ++
      [
        text: [
          type: :string,
          required: true,
          doc: "The label text to display."
        ]
      ]
  end

  defp field_element_schema do
    base_element_schema() ++
      [
        source: [
          type: :any,
          required: true,
          doc: "The field path or expression to get the value."
        ],
        format: [
          type: :any,
          doc:
            "Format specification for the field value. Can be a format type atom (:number, :currency, :date, :datetime, :percent), a custom pattern string, or a format specification name."
        ],
        decimal_places: [
          type: :non_neg_integer,
          doc: "Number of decimal places for numeric formatting."
        ],
        format_spec: [
          type: :atom,
          doc: "Named format specification to use for formatting this field."
        ],
        custom_pattern: [
          type: :string,
          doc: "Custom format pattern string for specialized formatting."
        ],
        conditional_format: [
          type: :keyword_list,
          doc: "List of conditional formatting rules as {condition, format_options} pairs."
        ]
      ]
  end

  defp expression_element_schema do
    base_element_schema() ++
      [
        expression: [
          type: :any,
          required: true,
          doc: "The expression to calculate."
        ],
        format: [
          type: :any,
          doc:
            "Format specification for the expression result. Can be a format type atom (:number, :currency, :date), a custom pattern string, or a format specification name."
        ],
        format_spec: [
          type: :atom,
          doc: "Named format specification to use for formatting this expression result."
        ],
        custom_pattern: [
          type: :string,
          doc: "Custom format pattern string for specialized formatting."
        ],
        conditional_format: [
          type: :keyword_list,
          doc: "List of conditional formatting rules as {condition, format_options} pairs."
        ]
      ]
  end

  defp aggregate_element_schema do
    base_element_schema() ++
      [
        function: [
          type: {:in, [:sum, :count, :average, :min, :max]},
          required: true,
          doc: "The aggregate function to apply."
        ],
        source: [
          type: :any,
          required: true,
          doc: "The field or expression to aggregate."
        ],
        scope: [
          type: {:in, [:band, :group, :page, :report]},
          default: :band,
          doc: "The scope of the aggregate calculation. :band resets for each record, :group resets when the group changes, :page resets for each page, :report accumulates across the entire report."
        ],
        format: [
          type: :any,
          doc:
            "Format specification for the aggregate result. Can be a format type atom (:number, :currency, :date), a custom pattern string, or a format specification name."
        ],
        format_spec: [
          type: :atom,
          doc: "Named format specification to use for formatting this aggregate result."
        ],
        custom_pattern: [
          type: :string,
          doc: "Custom format pattern string for specialized formatting."
        ],
        conditional_format: [
          type: :keyword_list,
          doc: "List of conditional formatting rules as {condition, format_options} pairs."
        ]
      ]
  end

  defp line_element_schema do
    base_element_schema() ++
      [
        orientation: [
          type: {:in, [:horizontal, :vertical]},
          default: :horizontal,
          doc: "The line orientation."
        ],
        thickness: [
          type: :pos_integer,
          default: 1,
          doc: "The line thickness in rendering units."
        ]
      ]
  end

  defp box_element_schema do
    base_element_schema() ++
      [
        border: [
          type: :keyword_list,
          default: [],
          doc: "Border properties (width, color, style)."
        ],
        fill: [
          type: :keyword_list,
          default: [],
          doc: "Fill properties (color, pattern)."
        ]
      ]
  end

  defp image_element_schema do
    base_element_schema() ++
      [
        source: [
          type: {:or, [:string, :any]},
          required: true,
          doc: "The image path or expression that returns a path/URL."
        ],
        scale_mode: [
          type: {:in, [:fit, :fill, :stretch, :none]},
          default: :fit,
          doc: "How to scale the image within its bounds."
        ]
      ]
  end

  defp bar_chart_element_schema do
    base_element_schema() ++
      [
        chart_name: [
          type: :atom,
          required: true,
          doc: "The name of the bar_chart definition to reference."
        ]
      ]
  end

  defp line_chart_element_schema do
    base_element_schema() ++
      [
        chart_name: [
          type: :atom,
          required: true,
          doc: "The name of the line_chart definition to reference."
        ]
      ]
  end

  defp pie_chart_element_schema do
    base_element_schema() ++
      [
        chart_name: [
          type: :atom,
          required: true,
          doc: "The name of the pie_chart definition to reference."
        ]
      ]
  end

  defp area_chart_element_schema do
    base_element_schema() ++
      [
        chart_name: [
          type: :atom,
          required: true,
          doc: "The name of the area_chart definition to reference."
        ]
      ]
  end

  defp scatter_chart_element_schema do
    base_element_schema() ++
      [
        chart_name: [
          type: :atom,
          required: true,
          doc: "The name of the scatter_chart definition to reference."
        ]
      ]
  end

  defp gantt_chart_element_schema do
    base_element_schema() ++
      [
        chart_name: [
          type: :atom,
          required: true,
          doc: "The name of the gantt_chart definition to reference."
        ]
      ]
  end

  defp sparkline_element_schema do
    base_element_schema() ++
      [
        chart_name: [
          type: :atom,
          required: true,
          doc: "The name of the sparkline definition to reference."
        ]
      ]
  end

  # Layout container schemas

  defp grid_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The grid identifier."
      ],
      columns: [
        type: {:or, [:pos_integer, {:list, :any}]},
        default: 1,
        doc: """
        Column track sizes. Can be:
        - Integer: Number of auto columns (e.g., 3)
        - List: Track sizes using auto(), fr(n), or strings (e.g., [fr(1), "100pt", auto()])
        """
      ],
      rows: [
        type: {:or, [:pos_integer, {:list, :any}, {:in, [:auto]}]},
        doc: """
        Row track sizes. Can be:
        - Integer: Number of rows
        - List: Track sizes
        - :auto: Rows expand as needed (default)
        """
      ],
      gutter: [
        type: :string,
        doc: "Spacing between all cells (e.g., '10pt'). Applies to both columns and rows."
      ],
      column_gutter: [
        type: :string,
        doc: "Horizontal spacing between columns. Overrides gutter for columns."
      ],
      row_gutter: [
        type: :string,
        doc: "Vertical spacing between rows. Overrides gutter for rows."
      ],
      align: [
        type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
        doc: """
        Cell alignment. Can be:
        - Atom: Horizontal alignment (:left, :center, :right)
        - Tuple: {horizontal, vertical} (e.g., {:left, :top})
        """
      ],
      inset: [
        type: :string,
        doc: "Default cell padding (e.g., '5pt')."
      ],
      fill: [
        type: {:or, [:string, {:fun, 2}]},
        doc: """
        Cell background fill. Can be:
        - String: Color for all cells (e.g., '#f0f0f0')
        - Function: (column, row) -> color for conditional fills
        """
      ],
      stroke: [
        type: {:or, [:string, {:in, [:none]}]},
        default: :none,
        doc: "Cell border stroke (e.g., '1pt'). Defaults to :none for grids."
      ]
    ]
  end

  defp table_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The table identifier."
      ],
      columns: [
        type: {:or, [:pos_integer, {:list, :any}]},
        default: 1,
        doc: """
        Column track sizes. Can be:
        - Integer: Number of auto columns (e.g., 3)
        - List: Track sizes using auto(), fr(n), or strings (e.g., [fr(1), "100pt", auto()])
        """
      ],
      rows: [
        type: {:or, [:pos_integer, {:list, :any}, {:in, [:auto]}]},
        doc: """
        Row track sizes. Can be:
        - Integer: Number of rows
        - List: Track sizes
        - :auto: Rows expand as needed (default)
        """
      ],
      gutter: [
        type: :string,
        doc: "Spacing between all cells (e.g., '10pt'). Applies to both columns and rows."
      ],
      column_gutter: [
        type: :string,
        doc: "Horizontal spacing between columns. Overrides gutter for columns."
      ],
      row_gutter: [
        type: :string,
        doc: "Vertical spacing between rows. Overrides gutter for rows."
      ],
      align: [
        type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
        doc: """
        Cell alignment. Can be:
        - Atom: Horizontal alignment (:left, :center, :right)
        - Tuple: {horizontal, vertical} (e.g., {:left, :top})
        """
      ],
      inset: [
        type: :string,
        default: "5pt",
        doc: "Default cell padding (e.g., '5pt'). Tables default to '5pt'."
      ],
      fill: [
        type: {:or, [:string, {:fun, 2}]},
        doc: """
        Cell background fill. Can be:
        - String: Color for all cells (e.g., '#f0f0f0')
        - Function: (column, row) -> color for conditional fills
        """
      ],
      stroke: [
        type: {:or, [:string, {:in, [:none]}]},
        default: "1pt",
        doc: "Cell border stroke (e.g., '1pt'). Tables default to '1pt' for visible borders."
      ]
    ]
  end

  defp stack_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The stack identifier."
      ],
      dir: [
        type: {:in, [:ttb, :btt, :ltr, :rtl]},
        default: :ttb,
        doc: """
        Stack direction:
        - :ttb - Top to bottom (default)
        - :btt - Bottom to top
        - :ltr - Left to right
        - :rtl - Right to left
        """
      ],
      spacing: [
        type: :string,
        doc: "Spacing between child elements (e.g., '10pt')."
      ]
    ]
  end

  defp row_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The row identifier."
      ],
      height: [
        type: :string,
        doc: "Fixed row height (e.g., '30pt')."
      ],
      fill: [
        type: :string,
        doc: "Row background color (e.g., '#f0f0f0')."
      ],
      stroke: [
        type: :string,
        doc: "Row border stroke (e.g., '1pt')."
      ],
      align: [
        type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
        doc: "Default cell alignment. Propagates to child cells."
      ],
      inset: [
        type: :string,
        doc: "Default cell padding. Propagates to child cells."
      ]
    ]
  end

  defp grid_cell_schema do
    [
      name: [
        type: :atom,
        doc: "Optional cell identifier."
      ],
      x: [
        type: :non_neg_integer,
        doc: "Explicit column position (0-indexed)."
      ],
      y: [
        type: :non_neg_integer,
        doc: "Explicit row position (0-indexed)."
      ],
      align: [
        type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
        doc: "Cell alignment. Overrides parent grid alignment."
      ],
      fill: [
        type: :string,
        doc: "Cell background color. Overrides parent."
      ],
      stroke: [
        type: :string,
        doc: "Cell border stroke. Overrides parent."
      ],
      inset: [
        type: :string,
        doc: "Cell padding. Overrides parent."
      ]
    ]
  end

  defp table_cell_schema do
    [
      name: [
        type: :atom,
        doc: "Optional cell identifier."
      ],
      colspan: [
        type: :pos_integer,
        default: 1,
        doc: "Number of columns this cell spans."
      ],
      rowspan: [
        type: :pos_integer,
        default: 1,
        doc: "Number of rows this cell spans."
      ],
      x: [
        type: :non_neg_integer,
        doc: "Explicit column position (0-indexed)."
      ],
      y: [
        type: :non_neg_integer,
        doc: "Explicit row position (0-indexed)."
      ],
      align: [
        type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
        doc: "Cell alignment. Overrides parent table alignment."
      ],
      fill: [
        type: :string,
        doc: "Cell background color. Overrides parent."
      ],
      stroke: [
        type: :string,
        doc: "Cell border stroke. Overrides parent."
      ],
      inset: [
        type: :string,
        doc: "Cell padding. Overrides parent."
      ],
      breakable: [
        type: :boolean,
        default: true,
        doc: "Whether the cell can be broken across pages."
      ]
    ]
  end

  defp header_schema do
    [
      name: [
        type: :atom,
        doc: "Optional header identifier."
      ],
      repeat: [
        type: :boolean,
        default: true,
        doc: "Whether to repeat header on each page when table spans pages."
      ],
      level: [
        type: :pos_integer,
        default: 1,
        doc: "Header level for cascading headers (1 = primary, 2 = secondary, etc.)."
      ]
    ]
  end

  defp footer_schema do
    [
      name: [
        type: :atom,
        doc: "Optional footer identifier."
      ],
      repeat: [
        type: :boolean,
        default: true,
        doc: "Whether to repeat footer on each page when table spans pages."
      ]
    ]
  end

  @doc """
  Transform entity for declarative data transformations in charts.
  """
  def transform_entity do
    %Entity{
      name: :transform,
      describe: """
      Defines declarative data transformation for chart data processing.

      Transform supports filtering, grouping, aggregation, mapping, sorting, and limiting
      of data from the driving resource before chart rendering.
      """,
      target: AshReports.Charts.TransformDSL,
      schema: transform_entity_schema()
    }
  end

  defp bar_chart_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The chart identifier."
      ],
      driving_resource: [
        type: :atom,
        required: true,
        doc: "The Ash resource module to query for chart data."
      ],
      base_filter: [
        type: {:fun, 1},
        required: false,
        doc: "Function that takes params and returns an Ash.Query for filtering."
      ],
      load_relationships: [
        type: :any,
        required: false,
        default: [],
        doc: "List of relationships to preload for optimization."
      ]
    ]
  end

  defp bar_chart_config_schema do
    [
      width: [
        type: :integer,
        default: 600,
        doc: "Chart width in pixels."
      ],
      height: [
        type: :integer,
        default: 400,
        doc: "Chart height in pixels."
      ],
      title: [
        type: :string,
        doc: "Chart title text."
      ],
      type: [
        type: {:in, [:simple, :grouped, :stacked]},
        default: :simple,
        doc: "Bar chart type: :simple, :grouped, or :stacked."
      ],
      orientation: [
        type: {:in, [:vertical, :horizontal]},
        default: :vertical,
        doc: "Bar orientation: :vertical or :horizontal."
      ],
      data_labels: [
        type: :boolean,
        default: true,
        doc: "Whether to show data labels on bars."
      ],
      padding: [
        type: :integer,
        default: 2,
        doc: "Padding between bars in pixels."
      ],
      colours: [
        type: {:list, :string},
        default: [],
        doc: "List of hex color codes (without #) for bars."
      ]
    ]
  end

  defp line_chart_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The chart identifier."
      ],
      driving_resource: [
        type: :atom,
        required: true,
        doc: "The Ash resource module to query for chart data."
      ],
      base_filter: [
        type: {:fun, 1},
        required: false,
        doc: "Function that takes params and returns an Ash.Query for filtering."
      ],
      load_relationships: [
        type: :any,
        required: false,
        default: [],
        doc: "List of relationships to preload for optimization."
      ]
    ]
  end

  defp line_chart_config_schema do
    [
      width: [
        type: :integer,
        default: 600,
        doc: "Chart width in pixels."
      ],
      height: [
        type: :integer,
        default: 400,
        doc: "Chart height in pixels."
      ],
      title: [
        type: :string,
        doc: "Chart title text."
      ],
      smoothed: [
        type: :boolean,
        default: true,
        doc: "Whether to smooth the line."
      ],
      stroke_width: [
        type: :string,
        default: "2",
        doc: "Line stroke width."
      ],
      axis_label_rotation: [
        type: {:in, [:auto, :"45", :"90"]},
        default: :auto,
        doc: "Axis label rotation: :auto, :\"45\", or :\"90\"."
      ],
      colours: [
        type: {:list, :string},
        default: [],
        doc: "List of hex color codes (without #) for lines."
      ]
    ]
  end

  defp pie_chart_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The chart identifier."
      ],
      driving_resource: [
        type: :atom,
        required: true,
        doc: "The Ash resource module to query for chart data."
      ],
      base_filter: [
        type: {:fun, 1},
        required: false,
        doc: "Function that takes params and returns an Ash.Query for filtering."
      ],
      load_relationships: [
        type: :any,
        required: false,
        default: [],
        doc: "List of relationships to preload for optimization."
      ]
    ]
  end

  defp pie_chart_config_schema do
    [
      width: [
        type: :integer,
        default: 600,
        doc: "Chart width in pixels."
      ],
      height: [
        type: :integer,
        default: 400,
        doc: "Chart height in pixels."
      ],
      title: [
        type: :string,
        doc: "Chart title text."
      ],
      data_labels: [
        type: :boolean,
        default: true,
        doc: "Whether to show data labels on slices."
      ],
      colours: [
        type: {:list, :string},
        default: [],
        doc: "List of hex color codes (without #) for slices."
      ]
    ]
  end

  defp area_chart_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The chart identifier."
      ],
      driving_resource: [
        type: :atom,
        required: true,
        doc: "The Ash resource module to query for chart data."
      ],
      base_filter: [
        type: {:fun, 1},
        required: false,
        doc: "Function that takes params and returns an Ash.Query for filtering."
      ],
      load_relationships: [
        type: :any,
        required: false,
        default: [],
        doc: "List of relationships to preload for optimization."
      ]
    ]
  end

  defp area_chart_config_schema do
    [
      width: [
        type: :integer,
        default: 600,
        doc: "Chart width in pixels."
      ],
      height: [
        type: :integer,
        default: 400,
        doc: "Chart height in pixels."
      ],
      title: [
        type: :string,
        doc: "Chart title text."
      ],
      mode: [
        type: {:in, [:simple, :stacked]},
        default: :simple,
        doc: "Area chart mode: :simple or :stacked."
      ],
      opacity: [
        type: :float,
        default: 0.7,
        doc: "Fill opacity (0.0 to 1.0)."
      ],
      smooth_lines: [
        type: :boolean,
        default: true,
        doc: "Whether to smooth the area boundaries."
      ],
      colours: [
        type: {:list, :string},
        default: [],
        doc: "List of hex color codes (without #) for areas."
      ]
    ]
  end

  defp scatter_chart_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The chart identifier."
      ],
      driving_resource: [
        type: :atom,
        required: true,
        doc: "The Ash resource module to query for chart data."
      ],
      base_filter: [
        type: {:fun, 1},
        required: false,
        doc: "Function that takes params and returns an Ash.Query for filtering."
      ],
      load_relationships: [
        type: :any,
        required: false,
        default: [],
        doc: "List of relationships to preload for optimization."
      ]
    ]
  end

  defp scatter_chart_config_schema do
    [
      width: [
        type: :integer,
        default: 600,
        doc: "Chart width in pixels."
      ],
      height: [
        type: :integer,
        default: 400,
        doc: "Chart height in pixels."
      ],
      title: [
        type: :string,
        doc: "Chart title text."
      ],
      axis_label_rotation: [
        type: {:in, [:auto, :"45", :"90"]},
        default: :auto,
        doc: "Axis label rotation: :auto, :\"45\", or :\"90\"."
      ],
      colours: [
        type: {:list, :string},
        default: [],
        doc: "List of hex color codes (without #) for data points."
      ]
    ]
  end

  defp gantt_chart_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The chart identifier."
      ],
      driving_resource: [
        type: :atom,
        required: true,
        doc: "The Ash resource module to query for chart data."
      ],
      base_filter: [
        type: {:fun, 1},
        required: false,
        doc: "Function that takes params and returns an Ash.Query for filtering."
      ],
      load_relationships: [
        type: :any,
        required: false,
        default: [],
        doc: "List of relationships to preload for optimization."
      ]
    ]
  end

  defp gantt_chart_config_schema do
    [
      width: [
        type: :integer,
        default: 600,
        doc: "Chart width in pixels."
      ],
      height: [
        type: :integer,
        default: 400,
        doc: "Chart height in pixels."
      ],
      title: [
        type: :string,
        doc: "Chart title text."
      ],
      show_task_labels: [
        type: :boolean,
        default: true,
        doc: "Whether to show task labels."
      ],
      padding: [
        type: :integer,
        default: 2,
        doc: "Padding between tasks in pixels."
      ],
      colours: [
        type: {:list, :string},
        default: [],
        doc: "List of hex color codes (without #) for tasks."
      ]
    ]
  end

  defp sparkline_schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The chart identifier."
      ],
      driving_resource: [
        type: :atom,
        required: true,
        doc: "The Ash resource module to query for chart data."
      ],
      base_filter: [
        type: {:fun, 1},
        required: false,
        doc: "Function that takes params and returns an Ash.Query for filtering."
      ],
      load_relationships: [
        type: :any,
        required: false,
        default: [],
        doc: "List of relationships to preload for optimization."
      ]
    ]
  end

  defp sparkline_config_schema do
    [
      width: [
        type: :integer,
        default: 100,
        doc: "Chart width in pixels (compact default)."
      ],
      height: [
        type: :integer,
        default: 20,
        doc: "Chart height in pixels (compact default)."
      ],
      title: [
        type: :string,
        doc: "Optional title to display above the sparkline."
      ],
      spot_radius: [
        type: :integer,
        default: 2,
        doc: "Radius of the spot marker."
      ],
      spot_colour: [
        type: :string,
        default: "red",
        doc: "Color of the spot marker."
      ],
      line_width: [
        type: :integer,
        default: 1,
        doc: "Width of the trend line."
      ],
      line_colour: [
        type: :string,
        default: "rgba(0, 200, 50, 0.7)",
        doc: "Color of the trend line."
      ],
      fill_colour: [
        type: :string,
        default: "rgba(0, 200, 50, 0.2)",
        doc: "Fill color beneath the line."
      ]
    ]
  end

  defp transform_entity_schema do
    [
      group_by: [
        type: :any,
        doc: "Field or tuple to group by (e.g., :status or {:created_at, :month})."
      ],
      aggregates: [
        type: {:list, :any},
        default: [],
        doc: "List of aggregate operations to perform."
      ],
      filters: [
        type: :any,
        default: %{},
        doc: "Map of filter conditions to apply before aggregation."
      ],
      sort_by: [
        type: :any,
        doc: "Field to sort by, optionally with direction (e.g., :name or {:value, :desc})."
      ],
      limit: [
        type: :pos_integer,
        doc: "Maximum number of results to return."
      ],
      as_category: [
        type: :any,
        doc: "Map to category field for pie/bar charts."
      ],
      as_value: [
        type: :atom,
        doc: "Map to value field for pie/bar charts."
      ],
      as_x: [
        type: :any,
        doc: "Map to X-axis field for line/scatter charts."
      ],
      as_y: [
        type: :atom,
        doc: "Map to Y-axis field for line/scatter charts."
      ],
      as_task: [
        type: :any,
        doc: "Map to task name field for Gantt charts."
      ],
      as_start_date: [
        type: :any,
        doc: "Map to start date field for Gantt charts."
      ],
      as_end_date: [
        type: :any,
        doc: "Map to end date field for Gantt charts (supports date calculations)."
      ],
      as_values: [
        type: :atom,
        doc: "Map to values field for sparklines."
      ]
    ]
  end
end
