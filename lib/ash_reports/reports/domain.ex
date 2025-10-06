defmodule AshReports.Domain do
  @moduledoc """
  Domain extension for AshReports.

  This extension adds reporting capabilities to an Ash domain, allowing you to define
  reports that can query and present data from your domain's resources.

  ## Usage

      defmodule MyApp.Reporting do
        use Ash.Domain,
          extensions: [AshReports.Domain]

        reports do
          report :user_activity do
            title "User Activity Report"
            driving_resource MyApp.Accounts.User

            bands do
              band :header do
                type :title
                elements do
                  label :title do
                    text "User Activity Report"
                  end
                end
              end

              band :details do
                type :detail
                elements do
                  field :name do
                    source :name
                  end
                  field :last_login do
                    source :last_login_at
                    format :datetime
                  end
                end
              end
            end
          end
        end
      end
  """

  @reports_section AshReports.Dsl.reports_section()

  use Spark.Dsl.Extension,
    sections: [@reports_section],
    transformers: [
      AshReports.Transformers.BuildReportModules
    ],
    verifiers: [
      AshReports.Verifiers.ValidateReports,
      AshReports.Verifiers.ValidateBands,
      AshReports.Verifiers.ValidateElements
    ]
end
