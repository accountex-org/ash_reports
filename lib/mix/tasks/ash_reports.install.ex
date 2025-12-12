if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshReports.Install do
    @shortdoc "Installs AshReports into a project. Should be called with `mix igniter.install ash_reports`"

    @moduledoc """
    #{@shortdoc}

    ## Options

    - `--example` - Creates an example report definition in the selected domain.

    ## What This Installer Does

    1. Ensures Ash Framework is properly configured
    2. Configures the Spark formatter with AshReports sections
    3. Adds AshReports supervision children to your application
    4. Configures AshReports settings in your config files
    5. Adds the `AshReports.Domain` extension to your selected Ash domain(s)

    ## Required Directories

    After installation, you may need to create these directories:

    - `priv/typst_templates` - For Typst report templates
    - `priv/reports` - For generated report output
    """

    use Igniter.Mix.Task

    @domain_section_order [:reports]

    @manual_lead_in """
    This guide will walk you through the process of manually installing AshReports into your project.
    AshReports provides a declarative DSL for defining reports that can query and present data from
    your Ash resources in multiple formats (HTML, PDF, JSON).
    """

    @dependency_setup """
    AshReports builds on top of Ash Framework. We'll ensure Ash is properly configured first.
    """

    @setup_formatter """
    Configure the DSL auto-formatter to include the `:reports` section in your Ash.Domain modules.
    This ensures consistent formatting when you define reports.
    """

    @setup_supervision """
    AshReports requires several GenServers for chart generation and caching.
    These will be added to your application's supervision tree.
    """

    @setup_config """
    Configure AshReports with sensible defaults for report generation, caching, and Typst integration.

    Required directories (create manually if needed):
    - `priv/typst_templates` - For Typst report templates
    - `priv/reports` - For generated report output
    """

    @setup_domain """
    Add the AshReports.Domain extension to your Ash domain(s) to enable the reports DSL.
    """

    @impl Igniter.Mix.Task
    def info(_argv, _source) do
      %Igniter.Mix.Task.Info{
        composes: ["ash.install"],
        example: "mix igniter.install ash_reports --example"
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.Scribe.start_document(
        "Manual Installation",
        @manual_lead_in,
        app_name: :my_app
      )
      |> Igniter.Scribe.section("Install Dependencies", @dependency_setup, fn igniter ->
        Igniter.Scribe.patch(igniter, &Igniter.compose_task(&1, "ash.install"))
      end)
      |> Igniter.Scribe.section("Setup The Formatter", @setup_formatter, fn igniter ->
        igniter
        |> Igniter.Scribe.patch(&Igniter.Project.Formatter.import_dep(&1, :ash_reports))
        |> Igniter.Scribe.patch(fn igniter ->
          Spark.Igniter.prepend_to_section_order(
            igniter,
            :"Ash.Domain",
            @domain_section_order
          )
        end)
      end)
      |> Igniter.Scribe.section("Add Supervision Children", @setup_supervision, fn igniter ->
        Igniter.Scribe.patch(igniter, fn igniter ->
          igniter
          |> Igniter.Project.Application.add_new_child(AshReports.Charts.Registry)
          |> Igniter.Project.Application.add_new_child(AshReports.Charts.Cache,
            after: [AshReports.Charts.Registry]
          )
          |> Igniter.Project.Application.add_new_child(AshReports.Charts.PerformanceMonitor,
            after: [AshReports.Charts.Registry, AshReports.Charts.Cache]
          )
        end)
      end)
      |> Igniter.Scribe.section("Configure AshReports", @setup_config, fn igniter ->
        Igniter.Scribe.patch(igniter, fn igniter ->
          igniter
          |> configure_base_settings()
          |> configure_typst_settings()
          |> configure_dev_settings()
          |> configure_test_settings()
          |> configure_prod_settings()
        end)
      end)
      |> Igniter.Scribe.section("Add Domain Extension", @setup_domain, fn igniter ->
        Igniter.Scribe.patch(igniter, &add_domain_extension/1)
      end)
      |> then(fn igniter ->
        if "--example" in igniter.args.argv_flags do
          generate_example(igniter)
        else
          igniter
        end
      end)
    end

    defp configure_base_settings(igniter) do
      igniter
      |> Igniter.Project.Config.configure(
        "config.exs",
        :ash_reports,
        [:default_formats],
        [:html, :pdf]
      )
      |> Igniter.Project.Config.configure(
        "config.exs",
        :ash_reports,
        [:report_storage_path],
        "priv/reports"
      )
      |> Igniter.Project.Config.configure(
        "config.exs",
        :ash_reports,
        [:cache_ttl],
        {:code, quote(do: :timer.minutes(15))}
      )
    end

    defp configure_typst_settings(igniter) do
      igniter
      |> Igniter.Project.Config.configure(
        "config.exs",
        :ash_reports,
        [:typst, :template_dir],
        "priv/typst_templates"
      )
      |> Igniter.Project.Config.configure(
        "config.exs",
        :ash_reports,
        [:typst, :cache_enabled],
        true
      )
      |> Igniter.Project.Config.configure(
        "config.exs",
        :ash_reports,
        [:typst, :timeout],
        {:code, quote(do: :timer.seconds(30))}
      )
    end

    defp configure_dev_settings(igniter) do
      igniter
      |> Igniter.Project.Config.configure(
        "dev.exs",
        :ash_reports,
        [:debug_mode],
        true
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        :ash_reports,
        [:cache_enabled],
        false
      )
    end

    defp configure_test_settings(igniter) do
      Igniter.Project.Config.configure(
        igniter,
        "test.exs",
        :ash_reports,
        [:cache_enabled],
        false
      )
    end

    defp configure_prod_settings(igniter) do
      Igniter.Project.Config.configure(
        igniter,
        "prod.exs",
        :ash_reports,
        [:cache_enabled],
        true
      )
    end

    defp add_domain_extension(igniter) do
      case find_ash_domains(igniter) do
        {igniter, []} ->
          Igniter.add_notice(
            igniter,
            """
            No Ash domains were found in your project.
            You can add the AshReports.Domain extension manually later:

                defmodule MyApp.MyDomain do
                  use Ash.Domain,
                    extensions: [AshReports.Domain]

                  reports do
                    # Define your reports here
                  end
                end
            """
          )

        {igniter, domains} ->
          selected =
            Igniter.Util.IO.select(
              "Which domain should have the AshReports extension added?",
              domains,
              display: &inspect/1
            )

          case selected do
            nil ->
              Igniter.add_notice(
                igniter,
                "No domain selected. You can add the extension manually later."
              )

            domain ->
              Spark.Igniter.add_extension(
                igniter,
                domain,
                Ash.Domain,
                :extensions,
                AshReports.Domain
              )
          end
      end
    end

    defp find_ash_domains(igniter) do
      igniter
      |> Igniter.Project.Module.find_all_matching_modules(fn _module, zipper ->
        case Igniter.Code.Module.move_to_use(zipper, Ash.Domain) do
          {:ok, _} -> true
          _ -> false
        end
      end)
      |> case do
        {:ok, {igniter, modules}} -> {igniter, modules}
        {:error, igniter} -> {igniter, []}
      end
    end

    defp generate_example(igniter) do
      case find_ash_domains(igniter) do
        {igniter, []} ->
          Igniter.add_warning(
            igniter,
            "Cannot generate example report: no Ash domains found in project."
          )

        {igniter, [domain | _]} ->
          # Find a resource in the domain to use for the example
          case find_domain_resource(igniter, domain) do
            {igniter, nil} ->
              Igniter.add_warning(
                igniter,
                "Cannot generate example report: no resources found in domain #{inspect(domain)}."
              )

            {igniter, resource} ->
              add_example_report(igniter, domain, resource)
          end
      end
    end

    defp find_domain_resource(igniter, domain) do
      case Spark.Igniter.get_option(igniter, domain, [:resources]) do
        {igniter, {:ok, resources}} when is_list(resources) and length(resources) > 0 ->
          # Get the first resource module
          first_resource =
            resources
            |> List.first()
            |> case do
              {module, _opts} -> module
              module when is_atom(module) -> module
              _ -> nil
            end

          {igniter, first_resource}

        {igniter, _} ->
          {igniter, nil}
      end
    end

    defp add_example_report(igniter, domain, resource) do
      resource_name =
        resource
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
        |> String.to_atom()

      report_code = """
      reports do
        report :#{resource_name}_report do
          title "#{Module.split(resource) |> List.last()} Report"
          driving_resource #{inspect(resource)}

          bands do
            band :title_band do
              type :title

              elements do
                label :report_title do
                  text "#{Module.split(resource) |> List.last()} Report"
                end
              end
            end

            band :detail_band do
              type :detail

              elements do
                # Add fields from your resource here
                # field :name do
                #   source :name
                # end
              end
            end
          end
        end
      end
      """

      Igniter.Project.Module.find_and_update_module!(igniter, domain, fn zipper ->
        case Igniter.Code.Function.move_to_function_call_in_current_scope(zipper, :reports, 1) do
          {:ok, _} ->
            # Reports section already exists
            {:ok, zipper}

          :error ->
            # Add the reports section
            Igniter.Code.Common.add_code(zipper, report_code)
        end
      end)
    end
  end
else
  defmodule Mix.Tasks.AshReports.Install do
    @moduledoc """
    Installs AshReports into a project. Should be called with `mix igniter.install ash_reports`

    This task requires Igniter to be installed. Please add igniter to your dependencies
    and try again.

    For more information, see: https://hexdocs.pm/igniter
    """

    @shortdoc @moduledoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_reports.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
