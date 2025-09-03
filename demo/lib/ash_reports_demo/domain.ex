defmodule AshReportsDemo.Domain do
  @moduledoc """
  Ash Domain for AshReports Demo application.

  Defines the business domain with resources, reports, and policies
  for the comprehensive invoicing system demonstration.
  """

  use Ash.Domain, extensions: [AshReports.Domain]

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
    # Phase 7.5: Will be implemented with comprehensive report definitions
    # report :customer_summary
    # report :product_inventory
    # report :invoice_details
    # report :financial_summary
  end

  authorization do
    # Phase 7.4: Will be implemented with policy-based authorization
    authorize :when_requested
  end
end
