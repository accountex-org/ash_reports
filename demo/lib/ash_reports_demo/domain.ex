defmodule AshReportsDemo.Domain do
  @moduledoc """
  Ash Domain for AshReports Demo application.

  Defines the business domain with resources, reports, and policies
  for the comprehensive invoicing system demonstration.
  """

  use Ash.Domain, extensions: [AshReports.Domain]

  import Ash.Expr

  resources do
    # Phase 7.2: Business resources
    resource AshReportsDemo.Customer
    resource AshReportsDemo.CustomerAddress
    resource AshReportsDemo.CustomerType
    resource AshReportsDemo.Product
    resource AshReportsDemo.ProductCategory
    resource AshReportsDemo.Inventory
    resource AshReportsDemo.Invoice
    resource AshReportsDemo.InvoiceLineItem
  end

  reports do
    # Phase 7.5: Comprehensive report definitions demonstrating all AshReports features

    # Customer Summary Report - Multi-level grouping with business intelligence
    report :customer_summary do
      title("Customer Summary Report")
      description "Comprehensive customer analysis with geographic and tier grouping"
      driving_resource(AshReportsDemo.Customer)

      parameter(:region, :string)
      parameter(:tier, :string, constraints: [one_of: ["Bronze", "Silver", "Gold", "Platinum"]])
      parameter(:min_health_score, :integer, default: 0, constraints: [min: 0, max: 100])
      parameter(:include_inactive, :boolean, default: false)

      variable :customer_count do
        type :count
        expression(expr(1))
        reset_on(:report)
      end

      variable :total_lifetime_value do
        type :sum
        expression(expr(lifetime_value))
        reset_on(:report)
      end

      group :region do
        level(1)
        expression(expr(addresses.state))
      end

      band :title do
        type :title

        label :report_title do
          text("Customer Summary Report")
        end
      end

      band :customer_detail do
        type :detail

        field :customer_name do
          source :name
        end

        field :health_score do
          source :customer_health_score
        end

        field :tier do
          source :customer_tier
        end
      end

      band :summary do
        type :summary

        label :total_customers do
          text("Total Customers: [customer_count]")
        end

        label :total_value do
          text("Total Lifetime Value: [total_lifetime_value]")
        end
      end
    end

    # Product Inventory Report - Profitability analytics
    report :product_inventory do
      title("Product Inventory Report")
      description "Inventory analysis with profitability metrics"
      driving_resource(AshReportsDemo.Product)

      parameter(:category_id, :uuid)
      parameter(:include_inactive, :boolean, default: false)

      variable :total_products do
        type :count
        expression(expr(1))
        reset_on(:report)
      end

      variable :total_inventory_value do
        type :sum
        expression(expr(price))
        reset_on(:report)
      end

      band :title do
        type :title

        label :report_title do
          text("Product Inventory Report")
        end
      end

      band :product_detail do
        type :detail

        field :product_name do
          source :name
        end

        field :sku do
          source :sku
        end

        field :price do
          source :price
        end

        field :margin do
          source :margin_percentage
        end
      end

      band :inventory_summary do
        type :summary

        label :total_products_summary do
          text("Total Products: [total_products]")
        end

        label :inventory_value_summary do
          text("Total Inventory Value: [total_inventory_value]")
        end
      end
    end

    # Invoice Details Report - Master-detail financial analysis
    report :invoice_details do
      title("Invoice Details Report")
      description "Comprehensive invoice analysis with payment performance"
      driving_resource(AshReportsDemo.Invoice)

      parameter(:status, :atom,
        constraints: [one_of: [:draft, :sent, :paid, :overdue, :cancelled]]
      )

      parameter(:customer_id, :uuid)
      parameter(:include_paid, :boolean, default: true)

      variable :total_invoices do
        type :count
        expression(expr(1))
        reset_on(:report)
      end

      variable :total_invoice_amount do
        type :sum
        expression(expr(total))
        reset_on(:report)
      end

      band :title do
        type :title

        label :report_title do
          text("Invoice Details Report")
        end
      end

      band :invoice_detail do
        type :detail

        field :invoice_number do
          source :invoice_number
        end

        field :date do
          source :date
        end

        field :status do
          source :status
        end

        field :total do
          source :total
        end
      end

      band :financial_summary do
        type :summary

        label :invoice_metrics do
          text("Total Invoices: [total_invoices] | Total Amount: [total_invoice_amount]")
        end
      end
    end

    # Financial Summary Report - Executive dashboard
    report :financial_summary do
      title("Executive Financial Summary")
      description "Comprehensive financial dashboard with business intelligence"
      driving_resource(AshReportsDemo.Invoice)

      parameter(:period_type, :string,
        default: "monthly",
        constraints: [one_of: ["monthly", "quarterly", "yearly"]]
      )

      parameter(:fiscal_year, :integer, default: 2024)

      variable :total_revenue do
        type :sum
        expression(expr(total))
        reset_on(:report)
      end

      variable :invoice_count do
        type :count
        expression(expr(1))
        reset_on(:report)
      end

      band :executive_title do
        type :title

        label :report_title do
          text("Executive Financial Summary")
        end
      end

      band :invoice_details do
        type :detail

        field :invoice_number do
          source :invoice_number
        end

        field :date do
          source :date
        end

        field :total do
          source :total
        end
      end

      band :executive_summary do
        type :summary

        label :revenue_summary do
          text("Total Revenue: [total_revenue] across [invoice_count] transactions")
        end
      end
    end
  end

  authorization do
    # Phase 7.4: Will be implemented with policy-based authorization
    authorize :when_requested
  end
end
