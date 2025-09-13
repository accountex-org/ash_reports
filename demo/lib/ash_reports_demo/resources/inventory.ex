defmodule AshReportsDemo.Inventory do
  @moduledoc """
  Inventory resource for AshReports Demo.

  Represents inventory tracking for products with stock levels,
  reorder points, and inventory management.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table :demo_inventory
  end

  attributes do
    uuid_primary_key :id

    attribute :current_stock, :integer do
      allow_nil? false
      description "Current stock quantity"
      default 0
      constraints min: 0
    end

    attribute :reserved_stock, :integer do
      description "Stock reserved for pending orders"
      default 0
      constraints min: 0
    end

    attribute :reorder_point, :integer do
      description "Minimum stock level before reordering"
      default 10
      constraints min: 0
    end

    attribute :reorder_quantity, :integer do
      description "Quantity to reorder when below reorder point"
      default 50
      constraints min: 1
    end

    attribute :location, :string do
      description "Warehouse location"
      default "Main Warehouse"
      constraints max_length: 100
    end

    attribute :last_received_date, :date do
      description "Date inventory was last received"
    end

    attribute :last_received_quantity, :integer do
      description "Quantity received in last shipment"
      constraints min: 0
    end

    attribute :created_at, :utc_datetime_usec do
      description "When the inventory record was created"
      default &DateTime.utc_now/0
      allow_nil? false
    end

    attribute :updated_at, :utc_datetime_usec do
      description "When the inventory was last updated"
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
    defaults [:read, :update, :destroy]
    
    create :create do
      primary? true
      accept [:current_stock, :reserved_stock, :reorder_point, :reorder_quantity, :location, :last_received_date, :last_received_quantity, :product_id]
    end

    read :low_stock do
      description "Get products with stock below reorder point"
      filter expr(current_stock <= reorder_point)
    end

    read :out_of_stock do
      description "Get products with zero stock"
      filter expr(current_stock == 0)
    end

    read :by_location do
      description "Get inventory by warehouse location"
      argument :location, :string, allow_nil?: false
      filter expr(location == ^arg(:location))
    end

    update :adjust_stock do
      description "Adjust stock levels"
      require_atomic? false
      accept [:current_stock, :reserved_stock]
      change set_attribute(:updated_at, &DateTime.utc_now/0)
    end

    update :receive_stock do
      description "Receive new inventory"
      require_atomic? false
      argument :quantity, :integer, allow_nil?: false
      argument :received_date, :date, default: Date.utc_today()

      change fn changeset, context ->
        quantity = Ash.Changeset.get_argument(changeset, :quantity)
        received_date = Ash.Changeset.get_argument(changeset, :received_date)

        current_stock = Ash.Changeset.get_attribute(changeset, :current_stock) || 0
        new_stock = current_stock + quantity

        changeset
        |> Ash.Changeset.change_attribute(:current_stock, new_stock)
        |> Ash.Changeset.change_attribute(:last_received_date, received_date)
        |> Ash.Changeset.change_attribute(:last_received_quantity, quantity)
        |> Ash.Changeset.change_attribute(:updated_at, DateTime.utc_now())
      end
    end
  end

  relationships do
    belongs_to :product, AshReportsDemo.Product do
      description "Product this inventory tracks"
      allow_nil? false
    end
  end

  calculations do
    calculate :available_stock, :integer, expr(current_stock - reserved_stock) do
      description "Stock available for sale"
    end

    calculate :stock_status, :string do
      description "Current stock status"

      calculation fn records, _context ->
        records
        |> Enum.map(fn inventory ->
          available = inventory.current_stock - inventory.reserved_stock

          status =
            cond do
              available <= 0 -> "Out of Stock"
              available <= inventory.reorder_point -> "Low Stock"
              available <= inventory.reorder_point * 2 -> "Normal Stock"
              true -> "High Stock"
            end

          {inventory.id, status}
        end)
        |> Map.new()
      end
    end

    calculate :days_since_received, :integer do
      description "Days since last inventory was received"

      calculation fn records, _context ->
        today = Date.utc_today()

        records
        |> Enum.map(fn inventory ->
          days =
            if inventory.last_received_date do
              Date.diff(today, inventory.last_received_date)
            else
              # Large number if never received
              999
            end

          {inventory.id, days}
        end)
        |> Map.new()
      end
    end

    calculate :reorder_needed, :boolean, expr(current_stock <= reorder_point) do
      description "Whether this product needs to be reordered"
    end
  end

  validations do
    validate compare(:current_stock, greater_than_or_equal_to: 0),
      message: "current stock cannot be negative"

    validate compare(:reserved_stock, greater_than_or_equal_to: 0),
      message: "reserved stock cannot be negative"

    validate compare(:reorder_point, greater_than_or_equal_to: 0),
      message: "reorder point must be non-negative"

    validate compare(:reorder_quantity, greater_than: 0),
      message: "reorder quantity must be positive"

    # Custom validation: reserved stock cannot exceed current stock
    validate fn changeset, _context ->
      current = Ash.Changeset.get_attribute(changeset, :current_stock) || 0
      reserved = Ash.Changeset.get_attribute(changeset, :reserved_stock) || 0

      if reserved > current do
        {:error, field: :reserved_stock, message: "reserved stock cannot exceed current stock"}
      else
        :ok
      end
    end
  end

  resource do
    description "Inventory management with stock tracking and reorder automation"
  end
end
