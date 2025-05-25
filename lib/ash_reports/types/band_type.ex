defmodule AshReports.Types.BandType do
  @moduledoc """
  Defines the band type enumeration for AshReports.
  
  This module provides the band type for use in Ash attributes and
  ensures consistent band type handling throughout the system.
  """
  
  use Ash.Type.Enum, values: [
    :title,
    :page_header, 
    :column_header,
    :group_header,
    :detail,
    :group_footer,
    :column_footer,
    :page_footer,
    :summary
  ]
  
  @band_hierarchy %{
    title: 0,
    page_header: 1,
    column_header: 2,
    group_header: 3,
    detail: 4,
    group_footer: 5,
    column_footer: 6,
    page_footer: 7,
    summary: 8
  }
  
  @doc """
  Returns the hierarchical order value for a band type.
  Lower values appear before higher values in report processing.
  """
  @spec hierarchy_order(atom()) :: integer()
  def hierarchy_order(band_type) when is_atom(band_type) do
    Map.get(@band_hierarchy, band_type, 999)
  end
  
  @doc """
  Compares two band types based on their hierarchical order.
  Returns :lt, :eq, or :gt.
  """
  @spec compare(atom(), atom()) :: :lt | :eq | :gt
  def compare(band1, band2) do
    order1 = hierarchy_order(band1)
    order2 = hierarchy_order(band2)
    
    cond do
      order1 < order2 -> :lt
      order1 > order2 -> :gt
      true -> :eq
    end
  end
  
  @doc """
  Sorts a list of band types by their hierarchical order.
  """
  @spec sort([atom()]) :: [atom()]
  def sort(band_types) when is_list(band_types) do
    Enum.sort_by(band_types, &hierarchy_order/1)
  end
  
  @doc """
  Checks if a band type appears only once in a report.
  """
  @spec single_occurrence?(atom()) :: boolean()
  def single_occurrence?(:title), do: true
  def single_occurrence?(:summary), do: true
  def single_occurrence?(_), do: false
  
  @doc """
  Checks if a band type supports sub-bands.
  """
  @spec supports_sub_bands?(atom()) :: boolean() 
  def supports_sub_bands?(:group_header), do: true
  def supports_sub_bands?(:group_footer), do: true
  def supports_sub_bands?(:detail), do: true
  def supports_sub_bands?(_), do: false
  
  @doc """
  Checks if a band type supports grouping.
  """
  @spec supports_grouping?(atom()) :: boolean()
  def supports_grouping?(:group_header), do: true
  def supports_grouping?(:group_footer), do: true
  def supports_grouping?(_), do: false
  
  @doc """
  Checks if a band type is reprinted on new pages by default.
  """
  @spec reprints_on_new_page?(atom()) :: boolean()
  def reprints_on_new_page?(:page_header), do: true
  def reprints_on_new_page?(:page_footer), do: true
  def reprints_on_new_page?(:column_header), do: true
  def reprints_on_new_page?(_), do: false
  
  @doc """
  Returns a human-readable description of the band type.
  """
  @spec band_description(atom()) :: String.t()
  def band_description(:title), do: "Report title band - appears once at the beginning"
  def band_description(:page_header), do: "Page header - appears at the top of each page"
  def band_description(:column_header), do: "Column headers for data tables"
  def band_description(:group_header), do: "Group header - appears before each group of data"
  def band_description(:detail), do: "Detail band - contains the main data rows"
  def band_description(:group_footer), do: "Group footer - appears after each group of data"
  def band_description(:column_footer), do: "Column footers with aggregations"
  def band_description(:page_footer), do: "Page footer - appears at the bottom of each page"
  def band_description(:summary), do: "Report summary band - appears once at the end"
  def band_description(_), do: "Unknown band type"
end