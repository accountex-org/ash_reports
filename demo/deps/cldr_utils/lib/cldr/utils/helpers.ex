defmodule Cldr.Helpers do
  @moduledoc """
  General purpose helper functions for CLDR
  """

  @doc """
  Returns a boolean indicating if a data
  structure is semanically empty.

  Applies to lists, maps and `nil`
  """

  def empty?([]), do: true
  def empty?(%{} = map) when map == %{}, do: true
  def empty?(nil), do: true
  def empty?(_), do: false

  cond do
    function_exported?(:persistent_term, :get, 2) ->
      @doc false
      def get_term(key, default) do
        :persistent_term.get(key, default)
      end

      @doc false
      def put_term(key, value) do
        :persistent_term.put(key, value)
      end

    function_exported?(:persistent_term, :get, 1) ->
      @doc false
      def get_term(key, default) do
        :persistent_term.get(key)
      rescue
        ArgumentError ->
          default
      end

      @doc false
      def put_term(key, value) do
        :persistent_term.put(key, value)
      end

    true ->
      @doc false
      def get_term(_key, default) do
        default
      end

      @doc false
      def put_term(_key, value) do
        value
      end
  end
end
