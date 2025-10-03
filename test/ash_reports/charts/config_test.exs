defmodule AshReports.Charts.ConfigTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Config

  describe "new/1" do
    test "creates config with valid attributes" do
      attrs = %{
        title: "Test Chart",
        width: 800,
        height: 600,
        colors: ["#FF0000", "#00FF00"]
      }

      assert {:ok, config} = Config.new(attrs)
      assert config.title == "Test Chart"
      assert config.width == 800
      assert config.height == 600
      assert config.colors == ["#FF0000", "#00FF00"]
    end

    test "uses default values when not provided" do
      assert {:ok, config} = Config.new(%{})
      assert config.width == 600
      assert config.height == 400
      assert config.show_legend == true
      assert config.show_grid == true
      assert config.font_family == "sans-serif"
      assert config.font_size == 12
    end

    test "validates width and height" do
      assert {:error, changeset} = Config.new(%{width: -100})
      assert "must be greater than %{number}" in errors_on(changeset, :width)

      assert {:error, changeset} = Config.new(%{width: 10_000})
      assert "must be less than or equal to %{number}" in errors_on(changeset, :width)

      assert {:error, changeset} = Config.new(%{height: 0})
      assert "must be greater than %{number}" in errors_on(changeset, :height)
    end

    test "validates color format" do
      assert {:ok, _config} = Config.new(%{colors: ["#FF6B6B", "#4ECDC4"]})

      assert {:error, changeset} = Config.new(%{colors: ["invalid"]})
      assert "must be valid hex color codes (e.g., #FF6B6B)" in errors_on(changeset, :colors)

      assert {:error, changeset} = Config.new(%{colors: ["#ZZZZZZ"]})
      assert "must be valid hex color codes (e.g., #FF6B6B)" in errors_on(changeset, :colors)
    end

    test "validates legend position" do
      assert {:ok, config} = Config.new(%{legend_position: :top})
      assert config.legend_position == :top

      assert {:ok, config} = Config.new(%{legend_position: :bottom})
      assert config.legend_position == :bottom

      assert {:error, _changeset} = Config.new(%{legend_position: :invalid})
    end
  end

  describe "default_colors/0" do
    test "returns list of default colors" do
      colors = Config.default_colors()

      assert is_list(colors)
      assert length(colors) == 10
      assert Enum.all?(colors, &String.match?(&1, ~r/^#[0-9A-F]{6}$/i))
    end
  end

  describe "changeset/2" do
    test "creates valid changeset" do
      changeset = Config.changeset(%{width: 800})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :width) == 800
    end

    test "includes errors for invalid data" do
      changeset = Config.changeset(%{width: -100, font_size: 200})

      refute changeset.valid?
      assert "must be greater than %{number}" in errors_on(changeset, :width)
      assert "must be less than or equal to %{number}" in errors_on(changeset, :font_size)
    end
  end

  # Helper function
  defp errors_on(changeset, field) do
    changeset.errors
    |> Enum.filter(fn {key, _} -> key == field end)
    |> Enum.map(fn {_key, {message, _opts}} -> message end)
  end
end
