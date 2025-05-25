defmodule AshReports.Dsl do
  @moduledoc """
  Defines the DSL entities and sections for AshReports.
  
  This module contains all the Spark DSL entity definitions for reports,
  bands, and columns that are used to build the reporting extension.
  """
  
  alias Spark.Dsl.Entity
  alias Spark.Dsl.Section
  
  @doc false
  def column do
    %Entity{
      name: :column,
      target: AshReports.Dsl.Column,
      args: [:name],
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: "The unique name of the column"
        ],
        field: [
          type: :atom,
          required: false,
          doc: "The field to get the value from"
        ],
        value: [
          type: {:or, [:string, :atom, {:fun, 2}]},
          required: false,
          doc: "Static value or function to calculate the value"
        ],
        label: [
          type: :string,
          required: false,
          doc: "Display label for the column header"
        ],
        format: [
          type: {:or, [:atom, :string, {:fun, 1}]},
          required: false,
          doc: "Format specifier or function"
        ],
        visible: [
          type: {:or, [:boolean, {:fun, 1}]},
          required: false,
          default: true,
          doc: "Whether the column is visible"
        ],
        width: [
          type: {:or, [:integer, :string]},
          required: false,
          doc: "Column width"
        ],
        align: [
          type: {:one_of, [:left, :center, :right]},
          required: false,
          default: :left,
          doc: "Column alignment"
        ],
        aggregate: [
          type: {:one_of, [:sum, :avg, :min, :max, :count]},
          required: false,
          doc: "Aggregation function for group bands"
        ],
        group_by: [
          type: :boolean,
          required: false,
          default: false,
          doc: "Whether this column is used for grouping"
        ],
        order: [
          type: :integer,
          required: false,
          doc: "Display order of the column"
        ],
        metadata: [
          type: :map,
          required: false,
          default: %{},
          doc: "Additional metadata"
        ]
      ]
    }
  end
  
  @doc false
  def band do
    %Entity{
      name: :band,
      target: AshReports.Dsl.Band,
      args: [:type],
      entities: [
        columns: [column()]
      ],
      recursive_as: :bands,
      schema: [
        type: [
          type: {:one_of, [:title, :page_header, :column_header, :group_header, 
                          :detail, :group_footer, :column_footer, :page_footer, :summary]},
          required: true,
          doc: "The type of band"
        ],
        height: [
          type: {:or, [:integer, :string]},
          required: false,
          doc: "Band height"
        ],
        visible: [
          type: {:or, [:boolean, {:fun, 1}]},
          required: false,
          default: true,
          doc: "Whether the band is visible"
        ],
        split_type: [
          type: {:one_of, [:stretch, :prevent, :immediate]},
          required: false,
          default: :stretch,
          doc: "How the band handles page breaks"
        ],
        print_when_expression: [
          type: {:or, [:string, {:fun, 1}]},
          required: false,
          doc: "Expression to determine when to print the band"
        ],
        group_expression: [
          type: {:or, [:atom, :string, {:fun, 1}]},
          required: false,
          doc: "Expression for grouping (for group bands)"
        ],
        group_keep_together: [
          type: :boolean,
          required: false,
          default: false,
          doc: "Keep group together on same page"
        ],
        metadata: [
          type: :map,
          required: false,
          default: %{},
          doc: "Additional metadata"
        ]
      ]
    }
  end
  
  @doc false
  def report do
    %Entity{
      name: :report,
      target: AshReports.Dsl.Report,
      args: [:name],
      entities: [
        bands: [band()]
      ],
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: "The unique name of the report"
        ],
        title: [
          type: :string,
          required: false,
          doc: "Report title"
        ],
        description: [
          type: :string,
          required: false,
          doc: "Report description"
        ],
        data_source: [
          type: {:or, [:atom, {:behaviour, AshReports.DataSource}]},
          required: false,
          doc: "Custom data source module"
        ],
        renderer: [
          type: {:or, [:atom, {:behaviour, AshReports.Renderer}]},
          required: false,
          doc: "Custom renderer module"
        ],
        page_size: [
          type: {:one_of, [:a4, :letter, :legal, :a3]},
          required: false,
          default: :a4,
          doc: "Page size"
        ],
        orientation: [
          type: {:one_of, [:portrait, :landscape]},
          required: false,
          default: :portrait,
          doc: "Page orientation"
        ],
        margins: [
          type: :map,
          required: false,
          default: %{top: 20, right: 20, bottom: 20, left: 20},
          doc: "Page margins"
        ],
        locale: [
          type: :string,
          required: false,
          default: "en",
          doc: "Default locale for formatting"
        ],
        time_zone: [
          type: :string,
          required: false,
          default: "UTC",
          doc: "Default time zone"
        ],
        metadata: [
          type: :map,
          required: false,
          default: %{},
          doc: "Additional metadata"
        ]
      ]
    }
  end
  
  @doc false
  def parameter do
    %Entity{
      name: :parameter,
      target: __MODULE__.Parameter,
      args: [:name],
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: "Parameter name"
        ],
        type: [
          type: :atom,
          required: true,
          doc: "Parameter type"
        ],
        default: [
          type: :any,
          required: false,
          doc: "Default value"
        ],
        required: [
          type: :boolean,
          required: false,
          default: false,
          doc: "Whether the parameter is required"
        ],
        description: [
          type: :string,
          required: false,
          doc: "Parameter description"
        ],
        constraints: [
          type: :keyword_list,
          required: false,
          default: [],
          doc: "Type constraints"
        ]
      ]
    }
  end
  
  @doc false
  def reports_section do
    %Section{
      name: :reports,
      entities: [report(), parameter()],
      schema: [
        default_page_size: [
          type: {:one_of, [:a4, :letter, :legal, :a3]},
          required: false,
          default: :a4,
          doc: "Default page size for reports"
        ],
        default_orientation: [
          type: {:one_of, [:portrait, :landscape]},
          required: false,
          default: :portrait,
          doc: "Default orientation for reports"
        ],
        default_renderer: [
          type: :atom,
          required: false,
          doc: "Default renderer module"
        ],
        default_locale: [
          type: :string,
          required: false,
          default: "en",
          doc: "Default locale for report formatting"
        ],
        default_time_zone: [
          type: :string,
          required: false,
          default: "UTC",
          doc: "Default time zone for report formatting"
        ]
      ]
    }
  end
  
  @doc false
  def reportable_section do
    %Section{
      name: :reportable,
      schema: [
        reports: [
          type: {:list, :atom},
          required: false,
          default: [],
          doc: "List of reports this resource can be used with"
        ],
        default_columns: [
          type: {:list, :atom},
          required: false,
          doc: "Default columns to include when used in reports"
        ],
        column_labels: [
          type: :map,
          required: false,
          default: %{},
          doc: "Custom labels for resource attributes when used as columns"
        ],
        column_formats: [
          type: :map,
          required: false,
          default: %{},
          doc: "Default formats for resource attributes when used as columns"
        ],
        exclude_columns: [
          type: {:list, :atom},
          required: false,
          default: [],
          doc: "Columns to exclude from reports"
        ]
      ]
    }
  end
  
  # Dummy module for parameter entity target
  defmodule Parameter do
    defstruct [:name, :type, :default, :required, :description, :constraints]
  end
end