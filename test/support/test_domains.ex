unless Code.ensure_loaded?(AshReports.Test.SimpleDomain) do
  defmodule AshReports.Test.SimpleDomain do
    @moduledoc """
    Simple test domain with minimal report for basic DSL testing.
    """

    use Ash.Domain, extensions: [AshReports.Domain], validate_config_inclusion?: false

    reports do
      report :test_report do
        title "Test Report"
        driving_resource AshReports.Test.Customer

        band :detail do
          type :detail
        end
      end
    end
  end

  defmodule AshReports.Test.BandOptionsDomain do
    @moduledoc """
    Test domain for testing band options.
    """

    use Ash.Domain, extensions: [AshReports.Domain], validate_config_inclusion?: false

    reports do
      report :test_report do
        title "Test Report"
        driving_resource AshReports.Test.Customer

        bands do
          band :detail do
            type :detail
            group_level 1
            detail_number 1
            height 100
            can_grow true
            can_shrink false
            keep_together true
            visible true
          end
        end
      end
    end
  end

  defmodule AshReports.Test.ParametersDomain do
    @moduledoc """
    Test domain for testing parameters.
    """

    use Ash.Domain, extensions: [AshReports.Domain], validate_config_inclusion?: false

    reports do
      report :test_report do
        title "Test Report"
        driving_resource AshReports.Test.Customer

        parameters do
          parameter :start_date, :date do
            required true
          end

          parameter :region, :string do
            default "North"
          end
        end

        band :detail do
          type :detail
        end
      end
    end
  end

  defmodule AshReports.Test.VariablesDomain do
    @moduledoc """
    Test domain for testing variables.
    """

    use Ash.Domain, extensions: [AshReports.Domain], validate_config_inclusion?: false

    reports do
      report :test_report do
        title "Test Report"
        driving_resource AshReports.Test.Customer

        variables do
          variable :total_sales do
            type :sum
            expression :total_amount
            reset_on :group
            reset_group 1
            initial_value 0
          end
        end

        band :detail do
          type :detail
        end
      end
    end
  end

  defmodule AshReports.Test.GroupsDomain do
    @moduledoc """
    Test domain for testing groups.
    """

    use Ash.Domain, extensions: [AshReports.Domain], validate_config_inclusion?: false

    reports do
      report :test_report do
        title "Test Report"
        driving_resource AshReports.Test.Customer

        groups do
          group :by_region do
            level 1
            expression :region
            sort :desc
          end

          group :by_status do
            level 2
            expression :status
          end
        end

        band :detail do
          type :detail
        end
      end
    end
  end
end
