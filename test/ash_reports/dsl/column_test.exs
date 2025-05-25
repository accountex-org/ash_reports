defmodule AshReports.Dsl.ColumnTest do
  use ExUnit.Case, async: true
  
  alias AshReports.Dsl.Column
  
  describe "new/2" do
    test "creates a column with default values" do
      column = Column.new(:test_column)
      
      assert column.name == :test_column
      assert column.format == :text
      assert column.alignment == :left
      assert column.vertical_alignment == :middle
      assert column.visible == true
      assert column.sortable == false
      assert column.word_wrap == false
      assert column.style == %{}
    end
    
    test "creates a column with custom values" do
      column = Column.new(:price,
        label: "Unit Price",
        field: :unit_price,
        format: :currency,
        alignment: :right,
        width: "100px"
      )
      
      assert column.name == :price
      assert column.label == "Unit Price"
      assert column.field == :unit_price
      assert column.format == :currency
      assert column.alignment == :right
      assert column.width == "100px"
    end
  end
  
  describe "validate/1" do
    test "validates a valid column with field" do
      column = Column.new(:test, field: :test_field)
      assert {:ok, ^column} = Column.validate(column)
    end
    
    test "validates a valid column with value" do
      column = Column.new(:test, value: "Static Value")
      assert {:ok, ^column} = Column.validate(column)
    end
    
    test "requires a name" do
      column = struct(Column, name: nil)
      assert {:error, "Column name is required"} = Column.validate(column)
    end
    
    test "requires name to be an atom" do
      column = struct(Column, name: "not_atom")
      assert {:error, "Column name must be an atom"} = Column.validate(column)
    end
    
    test "requires either field or value" do
      column = Column.new(:test)
      assert {:error, "Column must have either a field or value"} = Column.validate(column)
    end
    
    test "validates format type" do
      column = struct(Column, name: :test, field: :test, format: :invalid)
      assert {:error, "Invalid column format"} = Column.validate(column)
    end
    
    test "validates alignment" do
      column = struct(Column, Column.default_values() |> Keyword.merge(name: :test, field: :test, alignment: :invalid, vertical_alignment: :middle))
      assert {:error, "Invalid alignment settings"} = Column.validate(column)
    end
    
    test "validates aggregate type" do
      column = struct(Column, Column.default_values() |> Keyword.merge(name: :test, field: :test, aggregate: :invalid))
      assert {:error, "Invalid aggregate type"} = Column.validate(column)
    end
    
    test "validates width formats" do
      # Valid widths
      assert {:ok, _} = Column.validate(Column.new(:test, field: :test, width: 100))
      assert {:ok, _} = Column.validate(Column.new(:test, field: :test, width: "100px"))
      assert {:ok, _} = Column.validate(Column.new(:test, field: :test, width: "50%"))
      assert {:ok, _} = Column.validate(Column.new(:test, field: :test, width: "10em"))
      assert {:ok, _} = Column.validate(Column.new(:test, field: :test, width: "5rem"))
      
      # Invalid widths
      column = Column.new(:test, field: :test, width: -10)
      assert {:error, "Width must be a positive number or valid CSS width string"} = Column.validate(column)
      
      column = Column.new(:test, field: :test, width: "invalid")
      assert {:error, "Invalid width format"} = Column.validate(column)
    end
  end
  
  describe "format_types/0" do
    test "returns all format types" do
      expected = [:text, :number, :currency, :percentage, :date, :datetime, :boolean, :custom]
      assert Column.format_types() == expected
    end
  end
  
  describe "aggregate_types/0" do
    test "returns all aggregate types" do
      expected = [:count, :sum, :avg, :min, :max, :first, :last, :list]
      assert Column.aggregate_types() == expected
    end
  end
  
  describe "format_value/3" do
    test "formats text values" do
      column = Column.new(:test, format: :text)
      assert Column.format_value(column, "Hello") == "Hello"
      assert Column.format_value(column, 123) == "123"
      assert Column.format_value(column, nil) == ""
    end
    
    test "formats number values" do
      column = Column.new(:test, format: :number, format_options: [precision: 2])
      assert Column.format_value(column, 1234.567) == "1234.57"
      assert Column.format_value(column, 1000) == "1000.00"
      assert Column.format_value(column, nil) == ""
    end
    
    test "formats number with German locale" do
      column = Column.new(:test, format: :number, format_options: [precision: 2])
      assert Column.format_value(column, 1234.56, locale: "de") == "1234,56"
    end
    
    test "formats currency values" do
      column = Column.new(:test, format: :currency, format_options: [currency: "USD"])
      assert Column.format_value(column, 99.99) == "$99.99"
      assert Column.format_value(column, nil) == ""
    end
    
    test "formats currency with EUR and German locale" do
      column = Column.new(:test, format: :currency, format_options: [currency: "EUR"])
      result = Column.format_value(column, 100, locale: "de")
      assert result == "100,00 €"
    end
    
    test "formats percentage values" do
      column = Column.new(:test, format: :percentage)
      assert Column.format_value(column, 0.75) == "75.0%"
      
      # Without multiplication
      column = Column.new(:test, 
        format: :percentage, 
        format_options: [multiply: false, precision: 0]
      )
      assert Column.format_value(column, 75) == "75%"
    end
    
    test "formats date values" do
      column = Column.new(:test, format: :date)
      date = ~D[2024-01-15]
      result = Column.format_value(column, date)
      assert result == "2024-01-15"
    end
    
    test "formats date with German locale" do
      column = Column.new(:test, format: :date, format_options: [format: :long])
      date = ~D[2024-01-15]
      result = Column.format_value(column, date, locale: "de")
      assert result == "2024-01-15"
    end
    
    test "formats datetime values" do
      column = Column.new(:test, format: :datetime)
      datetime = ~U[2024-01-15 14:30:00Z]
      result = Column.format_value(column, datetime)
      assert result == "2024-01-15T14:30:00Z"
      
      naive_datetime = ~N[2024-01-15 14:30:00]
      result = Column.format_value(column, naive_datetime)
      assert result == "2024-01-15T14:30:00"
    end
    
    test "formats boolean values" do
      column = Column.new(:test, format: :boolean)
      assert Column.format_value(column, true) == "Yes"
      assert Column.format_value(column, false) == "No"
      assert Column.format_value(column, nil) == ""
      
      # Custom text
      column = Column.new(:test, 
        format: :boolean,
        format_options: [true_text: "Active", false_text: "Inactive", nil_text: "Unknown"]
      )
      assert Column.format_value(column, true) == "Active"
      assert Column.format_value(column, false) == "Inactive"
      assert Column.format_value(column, nil) == "Unknown"
    end
    
    test "formats boolean with Spanish locale" do
      column = Column.new(:test, format: :boolean)
      assert Column.format_value(column, true, locale: "es") == "Sí"
      assert Column.format_value(column, false, locale: "es") == "No"
    end
    
    test "handles custom format" do
      column = Column.new(:test, format: :custom)
      assert Column.format_value(column, "custom") == "custom"
    end
  end
  
  describe "get_label/1" do
    test "returns explicit label when set" do
      column = Column.new(:test_field, label: "Custom Label")
      assert Column.get_label(column) == "Custom Label"
    end
    
    test "humanizes name when label not set" do
      column = Column.new(:user_name)
      assert Column.get_label(column) == "User Name"
      
      column = Column.new(:total_order_amount)
      assert Column.get_label(column) == "Total Order Amount"
    end
  end
  
  describe "get_sort_field/1" do
    test "returns nil when not sortable" do
      column = Column.new(:test, field: :test_field, sortable: false)
      assert Column.get_sort_field(column) == nil
    end
    
    test "returns sort_field when specified" do
      column = Column.new(:test, 
        field: :display_name,
        sortable: true,
        sort_field: :last_name
      )
      assert Column.get_sort_field(column) == :last_name
    end
    
    test "returns field when sortable but no sort_field specified" do
      column = Column.new(:test, field: :name, sortable: true)
      assert Column.get_sort_field(column) == :name
    end
  end
  
  describe "column configuration" do
    test "visibility can be boolean or expression" do
      column = Column.new(:test, field: :test, visible: false)
      assert column.visible == false
      
      column = Column.new(:test, field: :test, visible: {:expr, :some_expression})
      assert column.visible == {:expr, :some_expression}
    end
    
    test "aggregate options" do
      column = Column.new(:total,
        field: :amount,
        aggregate: :sum,
        aggregate_options: [precision: 2, group_by: :category]
      )
      
      assert column.aggregate == :sum
      assert column.aggregate_options == [precision: 2, group_by: :category]
    end
    
    test "style options" do
      column = Column.new(:test,
        field: :test,
        style: %{color: "red", font_weight: "bold"},
        header_style: %{background: "blue"},
        footer_style: %{border_top: "1px solid black"}
      )
      
      assert column.style == %{color: "red", font_weight: "bold"}
      assert column.header_style == %{background: "blue"}
      assert column.footer_style == %{border_top: "1px solid black"}
    end
    
    test "word wrap and truncate" do
      column = Column.new(:description,
        field: :long_description,
        word_wrap: true,
        truncate: 100
      )
      
      assert column.word_wrap == true
      assert column.truncate == 100
    end
  end
end