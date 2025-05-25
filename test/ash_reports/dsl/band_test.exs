defmodule AshReports.Dsl.BandTest do
  use ExUnit.Case, async: true
  
  alias AshReports.Dsl.Band
  alias AshReports.Dsl.Column
  
  describe "new/2" do
    test "creates a band with default values for each type" do
      for type <- Band.band_types() do
        band = Band.new(type)
        
        assert band.type == type
        assert band.columns == []
        assert band.bands == []
        assert band.visible == true
        assert band.style == %{}
        assert band.variables == %{}
        assert band.level == 0
      end
    end
    
    test "applies type-specific defaults" do
      title_band = Band.new(:title)
      assert title_band.reprint_on_new_page == false
      
      page_header = Band.new(:page_header)
      assert page_header.reprint_on_new_page == true
      
      summary_band = Band.new(:summary)
      assert summary_band.page_break == :before
      
      group_header = Band.new(:group_header)
      assert group_header.reset_options == :group
    end
    
    test "accepts custom options" do
      band = Band.new(:detail, 
        name: :main_detail,
        height: 0.5,
        visible: false,
        target_alias: :orders
      )
      
      assert band.name == :main_detail
      assert band.height == 0.5
      assert band.visible == false
      assert band.target_alias == :orders
    end
  end
  
  describe "validate/1" do
    test "validates a valid band" do
      band = Band.new(:detail, name: :test_band)
      assert {:ok, ^band} = Band.validate(band)
    end
    
    test "validates band type" do
      band = struct(Band, type: :invalid_type)
      assert {:error, "Invalid band type"} = Band.validate(band)
    end
    
    test "requires group_expression for group bands" do
      group_header = Band.new(:group_header, name: :group1)
      assert {:error, "Group bands require a group_expression"} = Band.validate(group_header)
      
      group_footer = Band.new(:group_footer, name: :group1)
      assert {:error, "Group bands require a group_expression"} = Band.validate(group_footer)
    end
    
    test "validates group bands with expression" do
      band = Band.new(:group_header, 
        name: :group1,
        group_expression: {:field, :category}
      )
      assert {:ok, ^band} = Band.validate(band)
    end
    
    test "validates detail band target_alias" do
      # nil is valid
      band = Band.new(:detail, target_alias: nil)
      assert {:ok, ^band} = Band.validate(band)
      
      # atom is valid
      band = Band.new(:detail, target_alias: :orders)
      assert {:ok, ^band} = Band.validate(band)
      
      # non-atom is invalid
      band = struct(Band, Band.default_values_for_type(:detail) |> Keyword.merge(type: :detail, target_alias: "invalid"))
      assert {:error, "Detail band target_alias must be an atom"} = Band.validate(band)
    end
  end
  
  describe "band_types/0" do
    test "returns all band types" do
      expected = [:title, :page_header, :column_header, :group_header, :detail, 
                  :group_footer, :column_footer, :page_footer, :summary]
      assert Band.band_types() == expected
    end
  end
  
  describe "supports_sub_bands?/1" do
    test "returns true for group and detail bands" do
      assert Band.supports_sub_bands?(:group_header)
      assert Band.supports_sub_bands?(:group_footer)
      assert Band.supports_sub_bands?(:detail)
    end
    
    test "returns false for other band types" do
      refute Band.supports_sub_bands?(:title)
      refute Band.supports_sub_bands?(:page_header)
      refute Band.supports_sub_bands?(:column_header)
      refute Band.supports_sub_bands?(:page_footer)
      refute Band.supports_sub_bands?(:summary)
    end
  end
  
  describe "supports_grouping?/1" do
    test "returns true for group bands" do
      assert Band.supports_grouping?(:group_header)
      assert Band.supports_grouping?(:group_footer)
    end
    
    test "returns false for non-group bands" do
      refute Band.supports_grouping?(:detail)
      refute Band.supports_grouping?(:title)
      refute Band.supports_grouping?(:page_header)
    end
  end
  
  describe "max_group_level/0" do
    test "returns 74" do
      assert Band.max_group_level() == 74
    end
  end
  
  describe "add_column/2" do
    test "adds a column to the band" do
      band = Band.new(:detail)
      column = %Column{name: :test_column}
      
      updated_band = Band.add_column(band, column)
      assert updated_band.columns == [column]
      
      column2 = %Column{name: :another_column}
      updated_band = Band.add_column(updated_band, column2)
      assert updated_band.columns == [column, column2]
    end
  end
  
  describe "add_sub_band/2" do
    test "adds sub-band to bands that support them" do
      parent = Band.new(:detail, level: 0)
      child = Band.new(:group_header, name: :sub_group, group_expression: {:field, :category})
      
      assert {:ok, updated_parent} = Band.add_sub_band(parent, child)
      assert length(updated_parent.bands) == 1
      
      [added_child] = updated_parent.bands
      assert added_child.level == 1
    end
    
    test "prevents adding sub-bands to unsupported band types" do
      parent = Band.new(:title)
      child = Band.new(:detail)
      
      assert {:error, "Band type title does not support sub-bands"} = Band.add_sub_band(parent, child)
    end
    
    test "enforces maximum group nesting level" do
      # Create a deeply nested group structure
      parent = Band.new(:detail, level: 73)
      child = Band.new(:group_header, 
        name: :deep_group,
        group_expression: {:field, :category}
      )
      
      # This should succeed (level 74)
      assert {:ok, _updated_parent} = Band.add_sub_band(parent, child)
      
      # Try to add another level (would be level 75)
      deep_parent = Band.new(:group_header, level: 74, group_expression: {:field, :subcategory})
      grandchild = Band.new(:group_header, 
        name: :too_deep,
        group_expression: {:field, :item}
      )
      
      assert {:error, message} = Band.add_sub_band(deep_parent, grandchild)
      assert message =~ "Maximum group nesting level"
    end
  end
  
  describe "get_all_columns/1" do
    test "returns columns from band and all sub-bands" do
      col1 = %Column{name: :col1}
      col2 = %Column{name: :col2}
      col3 = %Column{name: :col3}
      col4 = %Column{name: :col4}
      
      sub_band = Band.new(:detail, columns: [col3, col4])
      parent_band = Band.new(:detail, columns: [col1, col2], bands: [sub_band])
      
      all_columns = Band.get_all_columns(parent_band)
      assert all_columns == [col1, col2, col3, col4]
    end
  end
  
  describe "find_band_by_name/2" do
    test "finds band by name in hierarchy" do
      sub_sub_band = Band.new(:detail, name: :deep_band)
      sub_band = Band.new(:group_header, 
        name: :sub_band,
        bands: [sub_sub_band],
        group_expression: {:field, :category}
      )
      parent_band = Band.new(:detail, name: :parent_band, bands: [sub_band])
      
      assert Band.find_band_by_name(parent_band, :parent_band) == parent_band
      assert Band.find_band_by_name(parent_band, :sub_band) == sub_band
      assert Band.find_band_by_name(parent_band, :deep_band) == sub_sub_band
      assert Band.find_band_by_name(parent_band, :not_found) == nil
    end
  end
  
  describe "calculate_total_height/1" do
    test "returns explicit height when set" do
      band = Band.new(:detail, height: 2.5)
      assert Band.calculate_total_height(band) == 2.5
    end
    
    test "sums sub-band heights when no explicit height" do
      sub1 = Band.new(:detail, height: 1.0)
      sub2 = Band.new(:detail, height: 1.5)
      parent = Band.new(:detail, bands: [sub1, sub2])
      
      assert Band.calculate_total_height(parent) == 2.5
    end
    
    test "returns 0 for bands with no height or sub-bands" do
      band = Band.new(:detail)
      assert Band.calculate_total_height(band) == 0.0
    end
  end
  
  describe "band configuration" do
    test "page break options" do
      band = Band.new(:summary, page_break: :before)
      assert band.page_break == :before
      
      band = Band.new(:detail, page_break: :after)
      assert band.page_break == :after
    end
    
    test "reprint options" do
      header = Band.new(:page_header)
      assert header.reprint_on_new_page == true
      
      detail = Band.new(:detail)
      assert detail.reprint_on_new_page == false
    end
    
    test "style and variables" do
      band = Band.new(:detail,
        style: %{background: "blue", border: "1px solid black"},
        variables: %{counter: 0, total: 0}
      )
      
      assert band.style == %{background: "blue", border: "1px solid black"}
      assert band.variables == %{counter: 0, total: 0}
    end
  end
end