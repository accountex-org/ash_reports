defmodule AshReportsDemo.ProductCategory do
  @moduledoc """
  Product category resource for AshReports Demo.

  Represents product categorization for inventory management
  and reporting with hierarchical support.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table :demo_product_categories
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Category name"
      constraints max_length: 100
    end

    attribute :description, :string do
      description "Category description"
      constraints max_length: 500
    end

    attribute :active, :boolean do
      description "Whether this category is currently active"
      default true
      allow_nil? false
    end

    attribute :sort_order, :integer do
      description "Sort order for displaying categories"
      default 0
    end

    attribute :created_at, :utc_datetime_usec do
      description "When the category was created"
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
      accept [:name, :description, :active, :sort_order]
    end

    read :active do
      description "Get active categories only"
      filter expr(active == true)
    end
  end

  relationships do
    has_many :products, AshReportsDemo.Product do
      description "Products in this category"
      destination_attribute :category_id
    end
  end

  calculations do
    calculate :display_name, :string, expr(name) do
      description "Category name for display"
    end
  end

  aggregates do
    count :product_count, :products do
      description "Number of products in this category"
    end

    count :active_product_count, :products do
      description "Number of active products in this category"
      filter expr(active == true)
    end
  end

  validations do
    validate present(:name), message: "name is required"
    validate attribute_does_not_equal(:name, ""), message: "name cannot be blank"
  end

  identities do
    identity :unique_name, [:name] do
      message "category name must be unique"
      pre_check_with AshReportsDemo.Domain
    end
  end

  resource do
    description "Product categorization for inventory management"
  end
end
