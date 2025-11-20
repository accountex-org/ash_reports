# Test domains for DSL testing
# These replace the Code.eval_string approach with proper compile-time modules

unless Code.ensure_loaded?(AshReports.Test.MinimalDomain) do
  defmodule AshReports.Test.MinimalDomain do
    @moduledoc "Minimal valid report for basic DSL testing"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :test_report do
        title("Test Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail
        end
      end
    end
  end

  defmodule AshReports.Test.MultiReportDomain do
    @moduledoc "Domain with multiple reports"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :first_report do
        title("First Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail
        end
      end

      report :second_report do
        title("Second Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail
        end
      end
    end
  end

  defmodule AshReports.Test.CompleteReportDomain do
    @moduledoc "Report with all top-level fields"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :complete_report do
        title("Complete Report")
        description "A complete report with all fields"
        driving_resource(AshReports.Test.Customer)
        formats([:html, :pdf, :json])
        permissions([:view_reports, :export_data])

        band :detail do
          type :detail
        end
      end
    end
  end

  defmodule AshReports.Test.ParametersDomain do
    @moduledoc "Report with parameters"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :parameterized_report do
        title("Parameterized Report")
        driving_resource(AshReports.Test.Customer)

        parameter(:start_date, :date)

        parameter :region, :string do
          required(true)
          default "North"
          constraints max_length: 50
        end

        band :detail do
          type :detail
        end
      end
    end
  end

  defmodule AshReports.Test.BandsDomain do
    @moduledoc "Report with various band types"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :multi_band_report do
        title("Multi-Band Report")
        driving_resource(AshReports.Test.Customer)

        band :title do
          type :title
        end

        band :page_header do
          type :page_header
        end

        band :detail do
          type :detail
        end

        band :page_footer do
          type :page_footer
        end

        band :summary do
          type :summary
        end
      end
    end
  end

  defmodule AshReports.Test.BandOptionsDomain do
    @moduledoc "Band with all options"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :band_options_report do
        title("Band Options Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail
          group_level(1)
          detail_number(1)
          height(100)
          can_grow(true)
          can_shrink(false)
          keep_together(true)
          visible(true)
        end
      end
    end
  end

  defmodule AshReports.Test.ElementsDomain do
    @moduledoc "Report with various element types"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :elements_report do
        title("Elements Report")
        driving_resource(AshReports.Test.Customer)

        band :title do
          type :title

          label :title_label do
            text("Report Title")
            position(x: 0, y: 0, width: 200, height: 20)
          end
        end

        band :detail do
          type :detail

          field :customer_name do
            source :name
          end

          expression :computed_value do
            expression(:id)
          end

          line :separator do
            orientation(:horizontal)
            thickness(2)
          end

          box :border_box do
            border(width: 1, color: "black")
            fill(color: "lightgray")
          end

          image :logo do
            source "/path/to/logo.png"
            scale_mode(:fit)
          end
        end

        band :summary do
          type :summary

          aggregate :total_count do
            function(:count)
            source :id
            reset_on(:report)
          end
        end
      end
    end
  end

  defmodule AshReports.Test.VariablesDomain do
    @moduledoc "Report with variables"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :variables_report do
        title("Variables Report")
        driving_resource(AshReports.Test.Customer)

        variable :total_count do
          type :count
          expression(:id)
        end

        variable :total_sales do
          type :sum
          expression(:total_amount)
          reset_on(:group)
          reset_group(1)
          initial_value(0)
        end

        band :detail do
          type :detail
        end
      end
    end
  end

  defmodule AshReports.Test.GroupsDomain do
    @moduledoc "Report with groups"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :grouped_report do
        title("Grouped Report")
        driving_resource(AshReports.Test.Customer)

        group :by_region do
          level(1)
          expression(:region)
        end

        group :by_status do
          level(2)
          expression(:status)
          sort :desc
        end

        band :detail do
          type :detail
        end
      end
    end
  end

  defmodule AshReports.Test.FormatSpecsDomain do
    @moduledoc "Report with format specifications"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :formatted_report do
        title("Formatted Report")
        driving_resource(AshReports.Test.Customer)

        format_spec :currency_format do
          pattern("¤ #,##0.00")
          currency(:USD)
          locale("en")
        end

        format_spec :date_format do
          pattern("MM/dd/yyyy")
          type :date
        end

        band :detail do
          type :detail

          field :amount do
            source :total_amount
            format_spec(:currency_format)
          end
        end
      end
    end
  end

  # Layout container test domains

  defmodule AshReports.Test.GridLayoutDomain do
    @moduledoc "Report with grid layout containers"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :grid_report do
        title("Grid Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail

          grid :metrics_grid do
            columns [1, 1, 1]
            gutter "10pt"
            align :center
            inset "5pt"
            stroke "0.5pt"

            label :revenue_label do
              text("Revenue")
            end

            label :costs_label do
              text("Costs")
            end

            label :profit_label do
              text("Profit")
            end
          end
        end
      end
    end
  end

  defmodule AshReports.Test.GridAllOptionsLayoutDomain do
    @moduledoc "Grid with all available options"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :grid_all_options_report do
        title("Grid All Options Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail

          grid :full_grid do
            columns 3
            rows 2
            gutter "5pt"
            column_gutter "8pt"
            row_gutter "12pt"
            align {:left, :top}
            inset "10pt"
            fill "#f0f0f0"
            stroke :none

            label :item do
              text("Item")
            end
          end
        end
      end
    end
  end

  defmodule AshReports.Test.TableLayoutDomain do
    @moduledoc "Report with table layout containers"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :table_report do
        title("Table Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail

          table :data_table do
            columns [1, 2, 1]
            stroke "0.5pt"
            inset "5pt"

            label :name_col do
              text("Name")
            end

            label :desc_col do
              text("Description")
            end

            label :value_col do
              text("Value")
            end
          end
        end
      end
    end
  end

  defmodule AshReports.Test.TableDefaultsDomain do
    @moduledoc "Table to verify defaults are correct"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :table_defaults_report do
        title("Table Defaults Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail

          table :default_table do
            columns 2

            label :col1 do
              text("Column 1")
            end
          end
        end
      end
    end
  end

  defmodule AshReports.Test.StackLayoutDomain do
    @moduledoc "Report with stack layout containers"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :stack_report do
        title("Stack Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail

          stack :address_stack do
            dir :ttb
            spacing "3pt"

            label :street do
              text("123 Main St")
            end

            label :city do
              text("City, State 12345")
            end
          end
        end
      end
    end
  end

  defmodule AshReports.Test.StackDirectionsDomain do
    @moduledoc "Stack with all direction options"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :stack_directions_report do
        title("Stack Directions Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail

          stack :ttb_stack do
            dir :ttb

            label :item do
              text("Top to Bottom")
            end
          end

          stack :btt_stack do
            dir :btt

            label :item do
              text("Bottom to Top")
            end
          end

          stack :ltr_stack do
            dir :ltr

            label :item do
              text("Left to Right")
            end
          end

          stack :rtl_stack do
            dir :rtl

            label :item do
              text("Right to Left")
            end
          end
        end
      end
    end
  end

  defmodule AshReports.Test.NestedLayoutDomain do
    @moduledoc "Report with nested layout containers"
    use Ash.Domain, extensions: [AshReports.Domain]

    reports do
      report :nested_layout_report do
        title("Nested Layout Report")
        driving_resource(AshReports.Test.Customer)

        band :detail do
          type :detail

          stack :outer_stack do
            dir :ttb
            spacing "10pt"

            label :header do
              text("Header")
            end
          end

          grid :inner_grid do
            columns 2

            label :col1 do
              text("Column 1")
            end

            label :col2 do
              text("Column 2")
            end
          end
        end
      end
    end
  end

  # Invalid/error cases for validation testing
  # Note: These are commented out because they fail at compile-time.
  # Validation errors should be tested differently (e.g., with verifier tests)

  # defmodule AshReports.Test.MissingTitleDomain do
  #   @moduledoc "Report missing required title - should fail validation"
  #   use Ash.Domain, extensions: [AshReports.Domain]
  #
  #   reports do
  #     report :invalid_report do
  #       # Missing title
  #       driving_resource AshReports.Test.Customer
  #
  #       band :detail do
  #         type :detail
  #       end
  #     end
  #   end
  # end
  #
  # defmodule AshReports.Test.MissingResourceDomain do
  #   @moduledoc "Report missing required driving_resource - should fail validation"
  #   use Ash.Domain, extensions: [AshReports.Domain]
  #
  #   reports do
  #     report :invalid_report do
  #       title "Invalid Report"
  #       # Missing driving_resource
  #
  #       band :detail do
  #         type :detail
  #       end
  #     end
  #   end
  # end
  #
  # defmodule AshReports.Test.NoDetailBandDomain do
  #   @moduledoc "Report without detail band - should fail validation"
  #   use Ash.Domain, extensions: [AshReports.Domain]
  #
  #   reports do
  #     report :invalid_report do
  #       title "Invalid Report"
  #       driving_resource AshReports.Test.Customer
  #
  #       band :title do
  #         type :title
  #       end
  #       # Missing required detail band
  #     end
  #   end
  # end
end
