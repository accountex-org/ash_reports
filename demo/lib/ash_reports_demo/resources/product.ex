defmodule AshReportsDemo.Product do
  @moduledoc """
  Product resource for AshReports Demo.

  Represents products in the inventory system with pricing,
  cost tracking, and profitability calculations.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table :demo_products
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Product name"
      constraints max_length: 255
    end

    attribute :sku, :string do
      allow_nil? false
      description "Stock keeping unit"
      constraints max_length: 50
    end

    attribute :description, :string do
      description "Product description"
      constraints max_length: 1000
    end

    attribute :price, :decimal do
      allow_nil? false
      description "Product selling price"
      constraints decimal: [min: Decimal.new("0.01")]
    end

    attribute :cost, :decimal do
      allow_nil? false
      description "Product cost"
      constraints decimal: [min: Decimal.new("0.00")]
    end

    attribute :weight, :decimal do
      description "Product weight in pounds"
      constraints decimal: [min: Decimal.new("0.00")]
    end

    attribute :active, :boolean do
      description "Whether this product is currently active"
      default true
      allow_nil? false
    end

    attribute :created_at, :utc_datetime_usec do
      description "When the product was created"
      default &DateTime.utc_now/0
      allow_nil? false
    end

    attribute :updated_at, :utc_datetime_usec do
      description "When the product was last updated"
      default &DateTime.utc_now/0
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :active do
      description "Get active products only"
      filter expr(active == true)
    end

    read :by_category do
      description "Get products by category"
      argument :category_id, :uuid, allow_nil?: false
      filter expr(category_id == ^arg(:category_id) and active == true)
    end

    read :profitable do
      description "Get products with positive margin"
      filter expr(price > cost)
    end

    read :low_stock do
      description "Get products with low stock levels"
      # This would integrate with inventory in a real system
      filter expr(active == true)
    end

    update :update_pricing do
      description "Update product price and cost"
      accept [:price, :cost]
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end
  end

  relationships do
    belongs_to :category, AshReportsDemo.ProductCategory do
      description "Product category"
      allow_nil? false
    end

    has_one :inventory, AshReportsDemo.Inventory do
      description "Inventory record for this product"
      destination_attribute :product_id
    end

    has_many :invoice_line_items, AshReportsDemo.InvoiceLineItem do
      description "Invoice line items for this product"
      destination_attribute :product_id
    end
  end

  calculations do
    calculate :margin, :decimal, expr(price - cost) do
      description "Profit margin per unit"
    end

    calculate :margin_percentage, :decimal do
      description "Profit margin as percentage"

      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          percentage =
            if Decimal.gt?(product.price, 0) do
              margin = Decimal.sub(product.price, product.cost)

              Decimal.div(margin, product.price)
              |> Decimal.mult(100)
              |> Decimal.round(2)
            else
              Decimal.new("0.00")
            end

          {product.id, percentage}
        end)
        |> Map.new()
      end
    end

    calculate :profitability_grade, :string do
      description "Profitability grade (A-F)"

      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          margin =
            if Decimal.gt?(product.price, 0) do
              Decimal.sub(product.price, product.cost)
              |> Decimal.div(product.price)
              |> Decimal.mult(100)
              |> Decimal.to_float()
            else
              0.0
            end

          grade =
            cond do
              margin >= 50.0 -> "A"
              margin >= 30.0 -> "B"
              margin >= 15.0 -> "C"
              margin >= 5.0 -> "D"
              true -> "F"
            end

          {product.id, grade}
        end)
        |> Map.new()
      end
    end

    calculate :inventory_status, :string do
      description "Current inventory status"

      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          # For demo: simulate inventory status
          status = Enum.random(["In Stock", "Low Stock", "Out of Stock", "Backordered"])
          {product.id, status}
        end)
        |> Map.new()
      end
    end
  end

  aggregates do
    count :times_ordered, :invoice_line_items do
      description "Number of times this product has been ordered"
    end

    sum :total_quantity_sold, :invoice_line_items, field: :quantity do
      description "Total quantity of this product sold"
    end

    sum :total_revenue, :invoice_line_items, field: :line_total do
      description "Total revenue from this product"
    end
  end

  validations do
    validate present([:name, :sku, :price, :cost]),
      message: "name, SKU, price, and cost are required"

    validate attribute_does_not_equal(:name, ""), message: "name cannot be blank"
    validate attribute_does_not_equal(:sku, ""), message: "SKU cannot be blank"
    validate compare(:price, greater_than: 0), message: "price must be greater than 0"
    validate compare(:cost, greater_than_or_equal_to: 0), message: "cost must be non-negative"
  end

  identities do
    identity :unique_sku, [:sku] do
      message "SKU must be unique"
    end
  end

  changes do
    change fn changeset, _context ->
      # Auto-update the updated_at timestamp
      if changeset.action_type in [:update] do
        Ash.Changeset.change_attribute(changeset, :updated_at, DateTime.utc_now())
      else
        changeset
      end
    end
  end

  resource do
    description "Product catalog with pricing and inventory integration"
  end
end
