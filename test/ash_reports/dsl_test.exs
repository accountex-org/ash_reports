defmodule AshReports.DslTest do
  use ExUnit.Case, async: true

  alias AshReports.Dsl
  alias Spark.Dsl.Entity

  describe "@column entity" do
    test "has correct structure" do
      assert %Entity{
               name: :column,
               target: AshReports.Dsl.Column,
               args: [:name],
               schema: schema
             } = Dsl.column()

      # Verify required args
      assert Keyword.get(schema, :name) == [
               type: :atom,
               required: true,
               doc: "The unique name of the column"
             ]

      # Verify optional fields
      assert Keyword.get(schema, :field) == [
               type: :atom,
               required: false,
               doc: "The field to get the value from"
             ]

      assert Keyword.get(schema, :value) == [
               type: {:or, [:string, :atom, {:fun, 2}]},
               required: false,
               doc: "Static value or function to calculate the value"
             ]

      assert Keyword.get(schema, :label) == [
               type: :string,
               required: false,
               doc: "Display label for the column header"
             ]

      assert Keyword.get(schema, :format) == [
               type: {:or, [:atom, :string, {:fun, 1}]},
               required: false,
               doc: "Format specifier or function"
             ]

      assert Keyword.get(schema, :visible) == [
               type: {:or, [:boolean, {:fun, 1}]},
               required: false,
               default: true,
               doc: "Whether the column is visible"
             ]

      assert Keyword.get(schema, :width) == [
               type: {:or, [:integer, :string]},
               required: false,
               doc: "Column width"
             ]

      assert Keyword.get(schema, :align) == [
               type: {:one_of, [:left, :center, :right]},
               required: false,
               default: :left,
               doc: "Column alignment"
             ]

      assert Keyword.get(schema, :aggregate) == [
               type: {:one_of, [:sum, :avg, :min, :max, :count]},
               required: false,
               doc: "Aggregation function for group bands"
             ]

      assert Keyword.get(schema, :group_by) == [
               type: :boolean,
               required: false,
               default: false,
               doc: "Whether this column is used for grouping"
             ]

      assert Keyword.get(schema, :order) == [
               type: :integer,
               required: false,
               doc: "Display order of the column"
             ]

      assert Keyword.get(schema, :metadata) == [
               type: :map,
               required: false,
               default: %{},
               doc: "Additional metadata"
             ]
    end
  end

  describe "@band entity" do
    test "has correct structure" do
      assert %Entity{
               name: :band,
               target: AshReports.Dsl.Band,
               args: [:type],
               entities: entities,
               recursive_as: :bands,
               schema: schema
             } = Dsl.band()

      # Verify entities
      assert [columns: [column_entity]] = entities
      assert column_entity.name == :column

      # Verify schema
      assert Keyword.get(schema, :type) == [
               type:
                 {:one_of,
                  [
                    :title,
                    :page_header,
                    :column_header,
                    :group_header,
                    :detail,
                    :group_footer,
                    :column_footer,
                    :page_footer,
                    :summary
                  ]},
               required: true,
               doc: "The type of band"
             ]

      assert Keyword.get(schema, :height) == [
               type: {:or, [:integer, :string]},
               required: false,
               doc: "Band height"
             ]

      assert Keyword.get(schema, :visible) == [
               type: {:or, [:boolean, {:fun, 1}]},
               required: false,
               default: true,
               doc: "Whether the band is visible"
             ]

      assert Keyword.get(schema, :split_type) == [
               type: {:one_of, [:stretch, :prevent, :immediate]},
               required: false,
               default: :stretch,
               doc: "How the band handles page breaks"
             ]

      assert Keyword.get(schema, :print_when_expression) == [
               type: {:or, [:string, {:fun, 1}]},
               required: false,
               doc: "Expression to determine when to print the band"
             ]

      assert Keyword.get(schema, :group_expression) == [
               type: {:or, [:atom, :string, {:fun, 1}]},
               required: false,
               doc: "Expression for grouping (for group bands)"
             ]

      assert Keyword.get(schema, :group_keep_together) == [
               type: :boolean,
               required: false,
               default: false,
               doc: "Keep group together on same page"
             ]

      assert Keyword.get(schema, :metadata) == [
               type: :map,
               required: false,
               default: %{},
               doc: "Additional metadata"
             ]
    end

    test "supports recursive bands" do
      band = Dsl.band()
      assert band.recursive_as == :bands
    end
  end

  describe "@report entity" do
    test "has correct structure" do
      assert %Entity{
               name: :report,
               target: AshReports.Dsl.Report,
               args: [:name],
               entities: entities,
               schema: schema
             } = Dsl.report()

      # Verify entities
      assert [bands: [band_entity]] = entities
      assert band_entity.name == :band

      # Verify schema
      assert Keyword.get(schema, :name) == [
               type: :atom,
               required: true,
               doc: "The unique name of the report"
             ]

      assert Keyword.get(schema, :title) == [
               type: :string,
               required: false,
               doc: "Report title"
             ]

      assert Keyword.get(schema, :description) == [
               type: :string,
               required: false,
               doc: "Report description"
             ]

      assert Keyword.get(schema, :data_source) == [
               type: {:or, [:atom, {:behaviour, AshReports.DataSource}]},
               required: false,
               doc: "Custom data source module"
             ]

      assert Keyword.get(schema, :renderer) == [
               type: {:or, [:atom, {:behaviour, AshReports.Renderer}]},
               required: false,
               doc: "Custom renderer module"
             ]

      assert Keyword.get(schema, :page_size) == [
               type: {:one_of, [:a4, :letter, :legal, :a3]},
               required: false,
               default: :a4,
               doc: "Page size"
             ]

      assert Keyword.get(schema, :orientation) == [
               type: {:one_of, [:portrait, :landscape]},
               required: false,
               default: :portrait,
               doc: "Page orientation"
             ]

      assert Keyword.get(schema, :margins) == [
               type: :map,
               required: false,
               default: %{top: 20, right: 20, bottom: 20, left: 20},
               doc: "Page margins"
             ]

      assert Keyword.get(schema, :locale) == [
               type: :string,
               required: false,
               default: "en",
               doc: "Default locale for formatting"
             ]

      assert Keyword.get(schema, :time_zone) == [
               type: :string,
               required: false,
               default: "UTC",
               doc: "Default time zone"
             ]

      assert Keyword.get(schema, :metadata) == [
               type: :map,
               required: false,
               default: %{},
               doc: "Additional metadata"
             ]
    end
  end

  describe "@parameter entity" do
    test "has correct structure" do
      assert %Entity{
               name: :parameter,
               target: AshReports.Dsl.Parameter,
               args: [:name],
               schema: schema
             } = Dsl.parameter()

      # Verify schema
      assert Keyword.get(schema, :name) == [
               type: :atom,
               required: true,
               doc: "Parameter name"
             ]

      assert Keyword.get(schema, :type) == [
               type: :atom,
               required: true,
               doc: "Parameter type"
             ]

      assert Keyword.get(schema, :default) == [
               type: :any,
               required: false,
               doc: "Default value"
             ]

      assert Keyword.get(schema, :required) == [
               type: :boolean,
               required: false,
               default: false,
               doc: "Whether the parameter is required"
             ]

      assert Keyword.get(schema, :description) == [
               type: :string,
               required: false,
               doc: "Parameter description"
             ]

      assert Keyword.get(schema, :constraints) == [
               type: :keyword_list,
               required: false,
               default: [],
               doc: "Type constraints"
             ]
    end
  end

  describe "@reports section" do
    test "has correct structure for domains" do
      assert %Spark.Dsl.Section{
               name: :reports,
               entities: entities,
               schema: schema
             } = Dsl.reports_section()

      # Verify entities
      assert Enum.any?(entities, &(&1.name == :report))
      assert Enum.any?(entities, &(&1.name == :parameter))

      # Verify schema
      assert Keyword.get(schema, :default_page_size) == [
               type: {:one_of, [:a4, :letter, :legal, :a3]},
               required: false,
               default: :a4,
               doc: "Default page size for reports"
             ]

      assert Keyword.get(schema, :default_orientation) == [
               type: {:one_of, [:portrait, :landscape]},
               required: false,
               default: :portrait,
               doc: "Default orientation for reports"
             ]

      assert Keyword.get(schema, :default_renderer) == [
               type: :atom,
               required: false,
               doc: "Default renderer module"
             ]

      assert Keyword.get(schema, :default_locale) == [
               type: :string,
               required: false,
               default: "en",
               doc: "Default locale for report formatting"
             ]

      assert Keyword.get(schema, :default_time_zone) == [
               type: :string,
               required: false,
               default: "UTC",
               doc: "Default time zone for report formatting"
             ]
    end
  end

  describe "@reportable section" do
    test "has correct structure for resources" do
      assert %Spark.Dsl.Section{
               name: :reportable,
               schema: schema
             } = Dsl.reportable_section()

      # Verify schema
      assert Keyword.get(schema, :reports) == [
               type: {:list, :atom},
               required: false,
               default: [],
               doc: "List of reports this resource can be used with"
             ]

      assert Keyword.get(schema, :default_columns) == [
               type: {:list, :atom},
               required: false,
               doc: "Default columns to include when used in reports"
             ]

      assert Keyword.get(schema, :column_labels) == [
               type: :map,
               required: false,
               default: %{},
               doc: "Custom labels for resource attributes when used as columns"
             ]

      assert Keyword.get(schema, :column_formats) == [
               type: :map,
               required: false,
               default: %{},
               doc: "Default formats for resource attributes when used as columns"
             ]

      assert Keyword.get(schema, :exclude_columns) == [
               type: {:list, :atom},
               required: false,
               default: [],
               doc: "Columns to exclude from reports"
             ]
    end
  end

end