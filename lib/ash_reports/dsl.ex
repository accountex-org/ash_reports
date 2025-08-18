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
                    format :currency
                  end
                end
              end
            end
          end
        end
        """
      ],
      entities: [report_entity()],
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
        groups: [group_entity()]
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
          image_element_entity()
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
        type: {:list, :atom},
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
        doc: "Position properties (x, y, width, height)."
      ],
      style: [
        type: :keyword_list,
        default: [],
        doc: "Style properties (font, color, alignment, etc.)."
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
          doc: "Format specification for the field value."
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
          doc: "Format specification for the expression result."
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
          doc: "Format specification for the aggregate result."
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
end
