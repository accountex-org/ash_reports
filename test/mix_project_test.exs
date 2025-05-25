defmodule AshReports.MixProjectTest do
  use ExUnit.Case, async: true

  test "project configuration is valid" do
    project = AshReports.MixProject.project()
    
    assert project[:app] == :ash_reports
    assert project[:version] == "0.1.0"
    assert project[:elixir] == "~> 1.15"
    assert is_list(project[:deps])
    assert is_map(project[:docs])
    assert is_map(project[:package])
    assert is_map(project[:dialyzer])
  end

  test "application configuration is valid" do
    application = AshReports.MixProject.application()
    
    assert :logger in application[:extra_applications]
  end

  test "elixirc_paths configured correctly" do
    assert AshReports.MixProject.elixirc_paths(:test) == ["lib", "test/support"]
    assert AshReports.MixProject.elixirc_paths(:dev) == ["lib"]
    assert AshReports.MixProject.elixirc_paths(:prod) == ["lib"]
  end

  test "required dependencies are present" do
    deps = AshReports.MixProject.deps()
    dep_names = Enum.map(deps, fn
      {name, _} -> name
      {name, _, _} -> name
    end)
    
    assert :ash in dep_names
    assert :spark in dep_names
    assert :chromic_pdf in dep_names
    assert :mox in dep_names
    assert :credo in dep_names
    assert :dialyxir in dep_names
  end

  test "aliases are configured" do
    aliases = AshReports.MixProject.aliases()
    
    assert aliases[:setup] == ["deps.get", "compile"]
    assert aliases[:"test.all"] == ["test", "credo --strict", "dialyzer"]
    assert aliases[:"test.coverage"] == ["coveralls.html"]
  end

  test "documentation groups are configured" do
    docs = AshReports.MixProject.docs()
    groups = docs[:groups_for_modules]
    
    assert is_list(groups["DSL"])
    assert is_list(groups["Extensions"])
    assert groups["Transformers"] == ~r/AshReports.Transformers.*/
    assert groups["Renderers"] == ~r/AshReports.Renderers.*/
  end
end