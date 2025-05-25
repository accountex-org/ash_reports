defmodule AshReports.Types.BandTypeTest do
  use ExUnit.Case, async: true
  
  alias AshReports.Types.BandType
  
  describe "Ash.Type.Enum behavior" do
    test "includes all valid band types" do
      # The Ash.Type.Enum macro generates cast/1
      values = [:title, :page_header, :column_header, :group_header, :detail,
                :group_footer, :column_footer, :page_footer, :summary]
      
      for value <- values do
        # Test that cast works for valid values
        assert {:ok, ^value} = Ash.Type.cast_input(BandType, value, [])
        assert {:ok, ^value} = Ash.Type.cast_input(BandType, to_string(value), [])
      end
    end
    
    test "rejects invalid band types" do
      assert {:error, _} = Ash.Type.cast_input(BandType, :invalid, [])
      assert {:error, _} = Ash.Type.cast_input(BandType, "invalid", [])
      assert {:error, _} = Ash.Type.cast_input(BandType, nil, [])
    end
  end
  
  describe "hierarchy_order/1" do
    test "returns correct order for all band types" do
      assert BandType.hierarchy_order(:title) == 0
      assert BandType.hierarchy_order(:page_header) == 1
      assert BandType.hierarchy_order(:column_header) == 2
      assert BandType.hierarchy_order(:group_header) == 3
      assert BandType.hierarchy_order(:detail) == 4
      assert BandType.hierarchy_order(:group_footer) == 5
      assert BandType.hierarchy_order(:column_footer) == 6
      assert BandType.hierarchy_order(:page_footer) == 7
      assert BandType.hierarchy_order(:summary) == 8
    end
    
    test "returns 999 for unknown band types" do
      assert BandType.hierarchy_order(:unknown) == 999
    end
  end
  
  describe "compare/2" do
    test "compares band types correctly" do
      assert BandType.compare(:title, :page_header) == :lt
      assert BandType.compare(:detail, :group_header) == :gt
      assert BandType.compare(:detail, :detail) == :eq
      
      assert BandType.compare(:title, :summary) == :lt
      assert BandType.compare(:summary, :title) == :gt
    end
  end
  
  describe "sort/1" do
    test "sorts band types by hierarchy" do
      unsorted = [:summary, :detail, :title, :page_footer, :group_header]
      expected = [:title, :group_header, :detail, :page_footer, :summary]
      
      assert BandType.sort(unsorted) == expected
    end
    
    test "handles empty list" do
      assert BandType.sort([]) == []
    end
    
    test "preserves order of already sorted list" do
      sorted = [:title, :page_header, :detail, :summary]
      assert BandType.sort(sorted) == sorted
    end
  end
  
  describe "single_occurrence?/1" do
    test "returns true for title and summary" do
      assert BandType.single_occurrence?(:title) == true
      assert BandType.single_occurrence?(:summary) == true
    end
    
    test "returns false for other band types" do
      assert BandType.single_occurrence?(:page_header) == false
      assert BandType.single_occurrence?(:detail) == false
      assert BandType.single_occurrence?(:group_header) == false
      assert BandType.single_occurrence?(:column_footer) == false
    end
  end
  
  describe "supports_sub_bands?/1" do
    test "returns true for group and detail bands" do
      assert BandType.supports_sub_bands?(:group_header) == true
      assert BandType.supports_sub_bands?(:group_footer) == true
      assert BandType.supports_sub_bands?(:detail) == true
    end
    
    test "returns false for other band types" do
      assert BandType.supports_sub_bands?(:title) == false
      assert BandType.supports_sub_bands?(:page_header) == false
      assert BandType.supports_sub_bands?(:summary) == false
    end
  end
  
  describe "supports_grouping?/1" do
    test "returns true for group bands only" do
      assert BandType.supports_grouping?(:group_header) == true
      assert BandType.supports_grouping?(:group_footer) == true
    end
    
    test "returns false for non-group bands" do
      assert BandType.supports_grouping?(:detail) == false
      assert BandType.supports_grouping?(:title) == false
      assert BandType.supports_grouping?(:page_header) == false
    end
  end
  
  describe "reprints_on_new_page?/1" do
    test "returns true for headers that reprint" do
      assert BandType.reprints_on_new_page?(:page_header) == true
      assert BandType.reprints_on_new_page?(:page_footer) == true
      assert BandType.reprints_on_new_page?(:column_header) == true
    end
    
    test "returns false for other band types" do
      assert BandType.reprints_on_new_page?(:title) == false
      assert BandType.reprints_on_new_page?(:detail) == false
      assert BandType.reprints_on_new_page?(:summary) == false
    end
  end
  
  describe "band_description/1" do
    test "returns descriptions for all valid band types" do
      assert BandType.band_description(:title) =~ "Report title"
      assert BandType.band_description(:page_header) =~ "Page header"
      assert BandType.band_description(:column_header) =~ "Column headers"
      assert BandType.band_description(:group_header) =~ "Group header"
      assert BandType.band_description(:detail) =~ "Detail band"
      assert BandType.band_description(:group_footer) =~ "Group footer"
      assert BandType.band_description(:column_footer) =~ "Column footers"
      assert BandType.band_description(:page_footer) =~ "Page footer"
      assert BandType.band_description(:summary) =~ "Report summary"
    end
    
    test "returns unknown description for invalid type" do
      assert BandType.band_description(:invalid) == "Unknown band type"
    end
  end
end