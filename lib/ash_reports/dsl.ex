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
        ]
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
      scope: [
        type: :any,
        doc: "An Ash query expression to scope the report data."
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
      column: [
        type: :non_neg_integer,
        doc: "Zero-indexed column position for this element (0 = first column). Used for column-based layout."
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
            "Format specification for the field value. Can be a format type atom (:number, :currency, :date), a custom pattern string, or a format specification name."
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
          doc: "The scope over which to calculate the aggregate."
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
      scope: [
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
      scope: [
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
      scope: [
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
      scope: [
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
      scope: [
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
      scope: [
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
      scope: [
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
