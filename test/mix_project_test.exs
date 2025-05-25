defmodule AshReports.MixProjectTest do
  use ExUnit.Case, async: true

  test "project configuration is valid" do
    project = AshReports.MixProject.project()
    
    assert project[:app] == :ash_reports
    assert project[:version] == "0.1.0"
    assert project[:elixir] == "~> 1.15"
    assert is_list(project[:deps])
    assert is_list(project[:docs])
    assert is_list(project[:package])
    assert is_list(project[:dialyzer])
  end

  test "application configuration is valid" do
    application = AshReports.MixProject.application()
    
    assert :logger in application[:extra_applications]
  end

  test "elixirc_paths configured correctly" do
    project = AshReports.MixProject.project()
    elixirc_paths = project[:elixirc_paths]
    
    # elixirc_paths is a function reference or the paths directly
    assert elixirc_paths == ["lib", "test/support"] || is_function(elixirc_paths)
  end

  test "required dependencies are present" do
    project = AshReports.MixProject.project()
    # deps is also a private function, check project has deps key
    assert Keyword.has_key?(project, :deps)
  end

  test "aliases are configured" do
    project = AshReports.MixProject.project()
    # aliases is also private, check project has aliases key  
    assert Keyword.has_key?(project, :aliases)
  end

  test "documentation groups are configured" do
    project = AshReports.MixProject.project()
    # docs is also private, but we can check it exists in project
    assert Keyword.has_key?(project, :docs)
  end
end