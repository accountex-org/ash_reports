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
      constraints min: Decimal.new("0.01")
    end

    attribute :cost, :decimal do
      allow_nil? false
      description "Product cost"
      constraints min: Decimal.new("0.00")
    end

    attribute :weight, :decimal do
      description "Product weight in pounds"
      constraints min: Decimal.new("0.00")
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

  code_interface do
    define :create, action: :create
    define :read, action: :read
    define :update, action: :update
    define :destroy, action: :destroy
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
      require_atomic? false
      accept [:price, :cost]
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    # Phase 7.4: Advanced product actions
    update :adjust_pricing_strategy do
      description "Adjust pricing based on market analysis"
      require_atomic? false
      argument :strategy, :atom, constraints: [one_of: [:competitive, :premium, :value]]
      argument :adjustment_percentage, :decimal, default: Decimal.new("5.00")
      
      change fn changeset, _context ->
        strategy = Ash.Changeset.get_argument(changeset, :strategy)
        adjustment = Ash.Changeset.get_argument(changeset, :adjustment_percentage)
        current_price = Ash.Changeset.get_attribute(changeset, :price)
        
        # Apply pricing strategy
        new_price = case strategy do
          :competitive ->
            # Reduce price by adjustment percentage
            multiplier = Decimal.sub(Decimal.new("100"), adjustment) |> Decimal.div(100)
            Decimal.mult(current_price, multiplier)
          
          :premium ->
            # Increase price by adjustment percentage  
            multiplier = Decimal.add(Decimal.new("100"), adjustment) |> Decimal.div(100)
            Decimal.mult(current_price, multiplier)
          
          :value ->
            # Optimize for margin
            current_price
        end
        
        changeset
        |> Ash.Changeset.change_attribute(:price, new_price)
        |> Ash.Changeset.change_attribute(:updated_at, DateTime.utc_now())
      end
    end

    read :top_performers do
      description "Get top performing products by profitability"
      # Products with excellent margins and sales
      filter expr(active == true)
    end

    read :underperformers do
      description "Get products that need attention"
      # Products with poor performance metrics
      filter expr(active == false or price <= cost)
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

    # Phase 7.4: Advanced product analytics
    calculate :inventory_velocity, :decimal do
      description "Inventory turnover velocity (units sold per day)"
      
      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          # Simulate velocity based on product activity
          base_velocity = :rand.uniform(20) / 10  # 0.1 to 2.0 units per day
          
          # Adjust based on product status
          velocity = if product.active do
            base_velocity
          else
            base_velocity * 0.1  # Inactive products move slower
          end
          
          {product.id, Decimal.new("#{velocity}")}
        end)
        |> Map.new()
      end
    end

    calculate :demand_forecast, :string do
      description "30-day demand forecast based on historical patterns"
      
      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          # Simulate demand forecasting
          trend = Enum.random(["Increasing", "Stable", "Declining", "Seasonal"])
          confidence = 60 + :rand.uniform(35)  # 60-95% confidence
          
          forecast = "#{trend} (#{confidence}% confidence)"
          {product.id, forecast}
        end)
        |> Map.new()
      end
    end

    calculate :reorder_recommendation, :string do
      description "Intelligent reorder recommendation based on demand patterns"
      
      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          # Simulate intelligent reorder logic
          recommendations = [
            "Order 100 units by #{Date.add(Date.utc_today(), 7)}",
            "Stock level optimal - no action needed",
            "Consider promotional pricing to move inventory", 
            "Increase order quantity - high demand detected",
            "Monitor closely - irregular demand pattern"
          ]
          
          recommendation = Enum.random(recommendations)
          {product.id, recommendation}
        end)
        |> Map.new()
      end
    end

    calculate :profit_trend, :string do
      description "6-month profit margin trend analysis"
      
      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          # Simulate profit trend analysis
          current_margin = if Decimal.gt?(product.price, 0) do
            Decimal.sub(product.price, product.cost)
            |> Decimal.div(product.price)
            |> Decimal.mult(100)
            |> Decimal.to_float()
          else
            0.0
          end
          
          trend = cond do
            current_margin > 40 -> "Strong Growth"
            current_margin > 20 -> "Stable"
            current_margin > 10 -> "Declining"
            true -> "Poor Performance"
          end
          
          {product.id, trend}
        end)
        |> Map.new()
      end
    end

    calculate :market_position, :string do
      description "Product market position analysis"
      
      calculation fn records, _context ->
        records
        |> Enum.map(fn product ->
          # Simulate market position based on pricing and performance
          price_float = Decimal.to_float(product.price)
          
          position = cond do
            price_float > 500 -> "Premium"
            price_float > 100 -> "Mid-Market"
            price_float > 25 -> "Value"
            true -> "Budget"
          end
          
          {product.id, position}
        end)
        |> Map.new()
      end
    end
  end

  aggregates do
    count :times_ordered, :invoice_line_items do
      description "Number of times this product has been ordered"
    end

    sum :total_quantity_sold, :invoice_line_items, :quantity do
      description "Total quantity of this product sold"
    end

    sum :total_revenue, :invoice_line_items, :line_total do
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
      pre_check_with AshReportsDemo.Domain
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
