# AshReports Testing Guide - ECommerce Domain

This document provides a comprehensive testing strategy for the AshReports extension using an ECommerce domain context. It includes complete Ash.Domain and Ash.Resource definitions that exercise all features of the extension including self-referencing resources, hierarchical bands, multiple formats, aggregations, and complex reporting scenarios.

## Overview

The test domain simulates a complete ECommerce system with the following key features:
- Customer management with hierarchical relationships (customer referrals)
- Product catalog with categories and variants
- Order processing with line items
- Inventory tracking
- Sales analytics and reporting
- Self-referencing relationships for categories and customer referrals

## Test Domain Structure

```
ECommerce Domain
├── Customer (self-referencing: referrer)
├── Category (self-referencing: parent_category)
├── Product (belongs_to: category)
├── ProductVariant (belongs_to: product)
├── Order (belongs_to: customer)
├── LineItem (belongs_to: order, product_variant)
├── Payment (belongs_to: order)
└── Inventory (belongs_to: product_variant)
```

## Domain Definition

```elixir
defmodule TestECommerce.Domain do
  @moduledoc """
  ECommerce domain for testing AshReports extension.
  Demonstrates all reporting capabilities including hierarchical data,
  self-referencing resources, and complex aggregations.
  """
  
  use Ash.Domain,
    extensions: [AshReports.Domain]

  # Configure domain-wide reporting settings
  reports do
    # Default formats for all reports in this domain
    default_formats [:html, :pdf, :heex]
    
    # Storage configuration
    storage_path "ecommerce_reports"
    cache_enabled true
    
    # Domain-level sales analytics report
    report :sales_analytics do
      title "Sales Analytics Dashboard"
      description "Comprehensive sales analytics with multiple breakdowns"
      resource TestECommerce.Order
      formats [:html, :pdf, :xlsx]
      
      # Main report structure
      band :header, :report_header do
        title "SALES ANALYTICS DASHBOARD"
        
        column :generated_at, "Generated"
        column :period, "Period"
        column :total_orders, "Total Orders"
        column :total_revenue, "Total Revenue"
      end
      
      # Monthly breakdown
      band :detail, :monthly_sales do
        title "Monthly Sales Breakdown"
        data_source :monthly_aggregates
        
        column :month, :month
        column :order_count, :order_count
        column :revenue, :revenue, format: :currency
        column :avg_order_value, :avg_order_value, format: :currency
        column :growth_rate, :growth_rate, format: :percentage
        
        # Customer segment breakdown within each month
        band :detail, :customer_segments do
          title "Customer Segments"
          data_source :customer_segments
          
          column :segment, :segment_name
          column :customer_count, :customer_count
          column :segment_revenue, :revenue, format: :currency
          column :percentage, :percentage_of_total, format: :percentage
          
          # Top customers in each segment
          band :detail, :top_customers do
            title "Top Customers"
            data_source :top_customers
            
            column :customer_name, :name
            column :orders, :order_count
            column :revenue, :total_spent, format: :currency
            column :avg_order, :avg_order_value, format: :currency
          end
        end
        
        # Product category performance
        band :detail, :category_performance do
          title "Category Performance"
          data_source :category_sales
          
          column :category, :category_name
          column :units_sold, :units_sold
          column :revenue, :revenue, format: :currency
          column :margin, :gross_margin, format: :percentage
          
          # Top products in each category
          band :detail, :top_products do
            title "Top Products"
            data_source :top_products
            
            column :product_name, :name
            column :sku, :sku
            column :units_sold, :units_sold
            column :revenue, :revenue, format: :currency
            column :margin, :margin_percentage, format: :percentage
          end
        end
      end
      
      # Summary footer with totals
      band :footer, :summary do
        column :total_label, "TOTAL"
        column :total_orders, :total_orders
        column :total_revenue, :total_revenue, format: :currency
        column :avg_monthly_growth, :avg_growth_rate, format: :percentage
      end
    end
    
    # Customer hierarchy report (demonstrating self-referencing)
    report :customer_hierarchy do
      title "Customer Referral Hierarchy"
      description "Shows customer referral chains and their performance"
      resource TestECommerce.Customer
      formats [:html, :pdf]
      
      band :header, :report_header do
        title "CUSTOMER REFERRAL HIERARCHY"
        column :generated_at, "Generated"
      end
      
      # Root customers (no referrer)
      band :detail, :root_customers do
        title "Top Level Customers"
        data_source :root_customers
        
        column :name, :name
        column :email, :email
        column :join_date, :created_at, format: :date
        column :total_spent, :lifetime_value, format: :currency
        column :referrals_count, :direct_referrals_count
        
        # First level referrals
        band :detail, :level_1_referrals do
          title "Direct Referrals"
          data_source :direct_referrals
          
          column :name, :name
          column :email, :email
          column :join_date, :created_at, format: :date
          column :total_spent, :lifetime_value, format: :currency
          column :referrals_count, :direct_referrals_count
          
          # Second level referrals
          band :detail, :level_2_referrals do
            title "Second Level Referrals"
            data_source :direct_referrals
            
            column :name, :name
            column :email, :email
            column :join_date, :created_at, format: :date
            column :total_spent, :lifetime_value, format: :currency
            
            # Third level (demonstrating deep nesting)
            band :detail, :level_3_referrals do
              title "Third Level Referrals"
              data_source :direct_referrals
              
              column :name, :name
              column :email, :email
              column :total_spent, :lifetime_value, format: :currency
            end
          end
        end
      end
      
      band :footer, :summary do
        column :total_customers, :total_customers
        column :total_referrals, :total_referrals
        column :referral_revenue, :referral_revenue, format: :currency
      end
    end
    
    # Category hierarchy report (another self-referencing example)
    report :category_hierarchy do
      title "Product Category Hierarchy"
      description "Hierarchical view of product categories and their performance"
      resource TestECommerce.Category
      formats [:html, :pdf]
      
      band :header, :report_header do
        title "PRODUCT CATEGORY HIERARCHY"
        column :generated_at, "Generated"
      end
      
      # Root categories
      band :detail, :root_categories do
        title "Main Categories"
        data_source :root_categories
        
        column :name, :name
        column :description, :description
        column :product_count, :product_count
        column :total_sales, :total_sales, format: :currency
        
        # Subcategories
        band :detail, :subcategories do
          title "Subcategories"
          data_source :subcategories
          
          column :name, :name
          column :product_count, :product_count
          column :total_sales, :total_sales, format: :currency
          column :percentage_of_parent, :percentage_of_parent, format: :percentage
          
          # Sub-subcategories
          band :detail, :sub_subcategories do
            title "Sub-subcategories"
            data_source :subcategories
            
            column :name, :name
            column :product_count, :product_count
            column :total_sales, :total_sales, format: :currency
          end
        end
      end
    end
  end

  resources do
    resource TestECommerce.Customer
    resource TestECommerce.Category
    resource TestECommerce.Product
    resource TestECommerce.ProductVariant
    resource TestECommerce.Order
    resource TestECommerce.LineItem
    resource TestECommerce.Payment
    resource TestECommerce.Inventory
  end
end
```

## Resource Definitions

### 1. Customer Resource (Self-Referencing)

```elixir
defmodule TestECommerce.Customer do
  @moduledoc """
  Customer resource with self-referencing relationship for referrals.
  Demonstrates hierarchical customer data and reporting.
  """
  
  use Ash.Resource,
    domain: TestECommerce.Domain,
    extensions: [AshReports.Resource]

  attributes do
    uuid_primary_key :id
    
    attribute :email, :string do
      allow_nil? false
      constraints [
        match: ~r/^[^\s]+@[^\s]+\.[^\s]+$/
      ]
    end
    
    attribute :name, :string, allow_nil? false
    attribute :phone, :string
    attribute :birth_date, :date
    attribute :join_date, :date, default: &Date.utc_today/0
    attribute :customer_type, :atom, constraints: [one_of: [:individual, :business]]
    attribute :status, :atom, constraints: [one_of: [:active, :inactive, :blocked]]
    
    # Aggregated fields for reporting
    attribute :lifetime_value, :decimal, default: Decimal.new(0)
    attribute :total_orders, :integer, default: 0
    attribute :last_order_date, :date
  end

  relationships do
    # Self-referencing relationship for customer referrals
    belongs_to :referrer, __MODULE__ do
      allow_nil? true
      attribute_writable? true
    end
    
    has_many :referrals, __MODULE__ do
      destination_attribute :referrer_id
    end
    
    # Order relationships
    has_many :orders, TestECommerce.Order
    has_many :payments, TestECommerce.Payment
  end

  aggregates do
    count :direct_referrals_count, :referrals
    sum :total_spent, :orders, :total
    max :last_purchase_date, :orders, :order_date
    avg :avg_order_value, :orders, :total
  end

  calculations do
    calculate :customer_segment, :string, expr(
      cond do
        lifetime_value >= 10000 -> "VIP"
        lifetime_value >= 5000 -> "Premium" 
        lifetime_value >= 1000 -> "Regular"
        true -> "New"
      end
    )
    
    calculate :referral_tree_size, :integer do
      # Custom calculation to count total referrals in tree
      calculation fn records, _context ->
        # Implementation would count all nested referrals
        Enum.map(records, fn record ->
          count_referral_tree(record)
        end)
      end
    end
  end

  # Configure reporting capabilities
  reportable do
    enabled? true
    title_field :name
    default_columns [:name, :email, :customer_type, :lifetime_value, :total_orders]
    group_by_fields [:customer_type, :status, :customer_segment, :referrer_id]
    
    # Customer lifetime value report
    report :customer_lifetime_value do
      title "Customer Lifetime Value Analysis"
      description "Detailed analysis of customer value and behavior patterns"
      formats [:html, :pdf, :csv]
      
      band :header, :report_header do
        title "CUSTOMER LIFETIME VALUE ANALYSIS"
        column :generated_at, "Report Generated"
        column :total_customers, "Total Customers"
      end
      
      # Group by customer segment
      band :group_header, :segment_header do
        data_source :customer_segments
        
        column :segment, :customer_segment
        column :count, :customer_count
        column :avg_value, :avg_lifetime_value, format: :currency
        column :total_value, :total_lifetime_value, format: :currency
      end
      
      # Customer details within each segment
      band :detail, :customer_details do
        data_source :customers_in_segment
        
        column :name, :name
        column :email, :email
        column :join_date, :join_date, format: :date
        column :orders, :total_orders
        column :lifetime_value, :lifetime_value, format: :currency
        column :avg_order, :avg_order_value, format: :currency
        column :last_order, :last_order_date, format: :date
        column :referrals, :direct_referrals_count
        
        # Order history for each customer
        band :detail, :order_history do
          title "Recent Orders"
          data_source :recent_orders
          
          column :order_date, :order_date, format: :date
          column :order_total, :total, format: :currency
          column :items, :item_count
          column :status, :status
        end
      end
      
      # Segment summary
      band :group_footer, :segment_footer do
        column :segment_total, "Segment Total"
        column :total_value, :segment_total_value, format: :currency
        column :percentage, :percentage_of_total, format: :percentage
      end
      
      band :footer, :report_footer do
        column :grand_total_label, "GRAND TOTAL"
        column :total_customers, :total_customers
        column :total_lifetime_value, :total_lifetime_value, format: :currency
        column :avg_customer_value, :avg_customer_value, format: :currency
      end
    end
    
    # Referral performance report
    report :referral_performance do
      title "Customer Referral Performance"
      description "Analysis of customer referral patterns and success rates"
      
      band :header, :report_header do
        title "CUSTOMER REFERRAL PERFORMANCE"
        column :period, "Analysis Period"
      end
      
      # Top referrers
      band :detail, :top_referrers do
        title "Top Referrers"
        data_source :top_referrers
        
        column :referrer_name, :name
        column :direct_referrals, :direct_referrals_count
        column :total_tree_size, :referral_tree_size
        column :referral_revenue, :referral_revenue, format: :currency
        column :referrer_bonus, :referrer_bonus, format: :currency
        
        # Referrals made by this customer
        band :detail, :referral_details do
          title "Referrals Made"
          data_source :direct_referrals
          
          column :referral_name, :name
          column :referral_date, :join_date, format: :date
          column :referral_value, :lifetime_value, format: :currency
          column :referral_orders, :total_orders
          column :still_active, :is_active
        end
      end
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    read :with_referral_hierarchy do
      prepare build(load: [
        referrals: [
          referrals: [
            referrals: []
          ]
        ]
      ])
    end
  end

  # Private helper function for referral tree counting
  defp count_referral_tree(customer) do
    # Implementation would recursively count all referrals
    # This is a placeholder for the actual calculation
    customer.direct_referrals_count || 0
  end
end
```

### 2. Category Resource (Self-Referencing)

```elixir
defmodule TestECommerce.Category do
  @moduledoc """
  Product category with hierarchical structure.
  Demonstrates nested category reporting and self-referencing relationships.
  """
  
  use Ash.Resource,
    domain: TestECommerce.Domain,
    extensions: [AshReports.Resource]

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil? false
    attribute :description, :string
    attribute :slug, :string
    attribute :sort_order, :integer, default: 0
    attribute :is_active, :boolean, default: true
    attribute :image_url, :string
    attribute :seo_title, :string
    attribute :seo_description, :string
  end

  relationships do
    # Self-referencing for category hierarchy
    belongs_to :parent_category, __MODULE__ do
      allow_nil? true
      attribute_writable? true
    end
    
    has_many :subcategories, __MODULE__ do
      destination_attribute :parent_category_id
    end
    
    # Product relationships
    has_many :products, TestECommerce.Product
    has_many :product_variants, TestECommerce.ProductVariant do
      filter expr(product.category_id == ^id)
    end
  end

  aggregates do
    count :product_count, :products
    count :total_product_count, :product_variants
    sum :total_sales, :product_variants, :total_sales
    avg :avg_product_price, :products, :price
  end

  calculations do
    calculate :category_path, :string do
      # Calculate full category path (e.g., "Electronics > Computers > Laptops")
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          build_category_path(record)
        end)
      end
    end
    
    calculate :depth_level, :integer do
      # Calculate how deep in the hierarchy this category is
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          calculate_depth(record)
        end)
      end
    end
  end

  reportable do
    enabled? true
    title_field :name
    default_columns [:name, :product_count, :total_sales]
    group_by_fields [:parent_category_id, :depth_level, :is_active]
    
    # Category hierarchy performance report
    report :category_performance do
      title "Category Performance Analysis"
      description "Hierarchical analysis of category performance and trends"
      
      band :header, :report_header do
        title "CATEGORY PERFORMANCE ANALYSIS"
        column :period, "Analysis Period"
        column :total_categories, "Total Categories"
      end
      
      # Root categories
      band :detail, :root_categories do
        title "Main Categories"
        data_source :root_categories
        
        column :name, :name
        column :product_count, :product_count
        column :sales, :total_sales, format: :currency
        column :avg_price, :avg_product_price, format: :currency
        column :subcategory_count, :subcategory_count
        
        # Level 1 subcategories
        band :detail, :level_1_subcategories do
          title "Subcategories"
          data_source :subcategories
          
          column :name, :name
          column :products, :product_count
          column :sales, :total_sales, format: :currency
          column :parent_percentage, :percentage_of_parent, format: :percentage
          
          # Top products in this subcategory
          band :detail, :top_products do
            title "Top Products"
            data_source :top_products
            
            column :product_name, :name
            column :sku, :sku
            column :price, :price, format: :currency
            column :units_sold, :units_sold
            column :revenue, :revenue, format: :currency
          end
          
          # Level 2 subcategories
          band :detail, :level_2_subcategories do
            title "Sub-subcategories"
            data_source :subcategories
            
            column :name, :name
            column :products, :product_count
            column :sales, :total_sales, format: :currency
            
            # Level 3 (demonstrating deep nesting)
            band :detail, :level_3_subcategories do
              title "Level 3 Categories"
              data_source :subcategories
              
              column :name, :name
              column :products, :product_count
              column :sales, :total_sales, format: :currency
            end
          end
        end
      end
      
      band :footer, :category_summary do
        column :total_categories, :total_categories
        column :total_products, :total_products
        column :total_sales, :total_sales, format: :currency
        column :avg_sales_per_category, :avg_sales_per_category, format: :currency
      end
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    read :with_full_hierarchy do
      prepare build(load: [
        subcategories: [
          subcategories: [
            subcategories: []
          ]
        ]
      ])
    end
    
    read :root_categories do
      filter expr(is_nil(parent_category_id))
    end
  end

  # Helper functions for calculations
  defp build_category_path(category) do
    # Implementation would build full path from root
    category.name
  end

  defp calculate_depth(category) do
    # Implementation would calculate depth in hierarchy
    0
  end
end
```

### 3. Product Resource

```elixir
defmodule TestECommerce.Product do
  @moduledoc """
  Product resource with variants and complex reporting relationships.
  """
  
  use Ash.Resource,
    domain: TestECommerce.Domain,
    extensions: [AshReports.Resource]

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil? false
    attribute :description, :string
    attribute :sku, :string, allow_nil? false
    attribute :price, :decimal, allow_nil? false
    attribute :cost, :decimal
    attribute :weight, :decimal
    attribute :dimensions, :map
    attribute :is_active, :boolean, default: true
    attribute :is_featured, :boolean, default: false
    attribute :tags, {:array, :string}, default: []
  end

  relationships do
    belongs_to :category, TestECommerce.Category
    has_many :variants, TestECommerce.ProductVariant
    has_many :line_items, TestECommerce.LineItem do
      filter expr(product_variant.product_id == ^id)
    end
    has_many :inventory_records, TestECommerce.Inventory do
      filter expr(product_variant.product_id == ^id)
    end
  end

  aggregates do
    count :variant_count, :variants
    sum :total_inventory, :inventory_records, :quantity
    sum :units_sold, :line_items, :quantity
    sum :revenue, :line_items, :total_price
  end

  calculations do
    calculate :profit_margin, :decimal, expr(
      if(revenue > 0, (revenue - (cost * units_sold)) / revenue * 100, 0)
    )
    
    calculate :inventory_value, :decimal, expr(cost * total_inventory)
    calculate :avg_selling_price, :decimal, expr(
      if(units_sold > 0, revenue / units_sold, price)
    )
  end

  reportable do
    enabled? true
    title_field :name
    default_columns [:name, :sku, :price, :units_sold, :revenue]
    group_by_fields [:category_id, :is_featured, :is_active]
    
    # Product performance report
    report :product_performance do
      title "Product Performance Analysis"
      description "Detailed analysis of product sales and profitability"
      
      band :header, :report_header do
        title "PRODUCT PERFORMANCE ANALYSIS"
        column :period, "Analysis Period"
        column :total_products, "Total Products"
      end
      
      # Group by category
      band :group_header, :category_header do
        data_source :categories
        
        column :category_name, :name
        column :product_count, :product_count
        column :category_revenue, :total_revenue, format: :currency
      end
      
      # Products in category
      band :detail, :products do
        data_source :products_in_category
        
        column :name, :name
        column :sku, :sku
        column :price, :price, format: :currency
        column :units_sold, :units_sold
        column :revenue, :revenue, format: :currency
        column :profit_margin, :profit_margin, format: :percentage
        column :inventory, :total_inventory
        
        # Product variants
        band :detail, :variants do
          title "Product Variants"
          data_source :variants
          
          column :variant_name, :name
          column :variant_sku, :sku
          column :variant_price, :price, format: :currency
          column :variant_sold, :units_sold
          column :variant_revenue, :revenue, format: :currency
          column :variant_inventory, :inventory_quantity
        end
      end
      
      band :group_footer, :category_footer do
        column :category_total, "Category Total"
        column :total_revenue, :category_revenue, format: :currency
        column :avg_margin, :avg_profit_margin, format: :percentage
      end
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

### 4. Order Resource (Main Transaction Entity)

```elixir
defmodule TestECommerce.Order do
  @moduledoc """
  Order resource demonstrating complex reporting with related entities.
  """
  
  use Ash.Resource,
    domain: TestECommerce.Domain,
    extensions: [AshReports.Resource]

  attributes do
    uuid_primary_key :id
    attribute :order_number, :string, allow_nil? false
    attribute :order_date, :date, default: &Date.utc_today/0
    attribute :status, :atom, constraints: [one_of: [:pending, :confirmed, :shipped, :delivered, :cancelled]]
    attribute :subtotal, :decimal, allow_nil? false
    attribute :tax_amount, :decimal, default: Decimal.new(0)
    attribute :shipping_amount, :decimal, default: Decimal.new(0)
    attribute :discount_amount, :decimal, default: Decimal.new(0)
    attribute :total, :decimal, allow_nil? false
    attribute :notes, :string
    attribute :shipping_address, :map
    attribute :billing_address, :map
  end

  relationships do
    belongs_to :customer, TestECommerce.Customer
    has_many :line_items, TestECommerce.LineItem
    has_many :payments, TestECommerce.Payment
  end

  aggregates do
    count :item_count, :line_items
    sum :total_quantity, :line_items, :quantity
    count :payment_count, :payments
    sum :amount_paid, :payments, :amount
  end

  calculations do
    calculate :is_fully_paid, :boolean, expr(amount_paid >= total)
    calculate :outstanding_balance, :decimal, expr(total - amount_paid)
    calculate :avg_item_price, :decimal, expr(
      if(item_count > 0, subtotal / item_count, 0)
    )
  end

  reportable do
    enabled? true
    title_field :order_number
    default_columns [:order_number, :order_date, :customer_name, :total, :status]
    group_by_fields [:status, :order_date, :customer_id]
    
    # Daily sales report
    report :daily_sales do
      title "Daily Sales Report"
      description "Comprehensive daily sales breakdown with customer and product details"
      
      band :header, :report_header do
        title "DAILY SALES REPORT"
        column :report_date, "Report Date"
        column :total_orders, "Total Orders"
        column :total_revenue, "Total Revenue"
      end
      
      # Group by order status
      band :group_header, :status_header do
        data_source :order_statuses
        
        column :status, :status
        column :order_count, :order_count
        column :status_revenue, :total_revenue, format: :currency
        column :avg_order_value, :avg_order_value, format: :currency
      end
      
      # Orders in each status
      band :detail, :orders do
        data_source :orders_in_status
        
        column :order_number, :order_number
        column :customer_name, :customer_name
        column :order_time, :created_at, format: :datetime
        column :items, :item_count
        column :subtotal, :subtotal, format: :currency
        column :tax, :tax_amount, format: :currency
        column :shipping, :shipping_amount, format: :currency
        column :total, :total, format: :currency
        
        # Line items for each order
        band :detail, :line_items do
          title "Order Items"
          data_source :line_items
          
          column :product_name, :product_name
          column :variant, :variant_name
          column :sku, :sku
          column :quantity, :quantity
          column :unit_price, :unit_price, format: :currency
          column :total_price, :total_price, format: :currency
          column :discount, :discount_amount, format: :currency
        end
        
        # Payments for each order
        band :detail, :payments do
          title "Payments"
          data_source :payments
          
          column :payment_date, :payment_date, format: :date
          column :payment_method, :payment_method
          column :amount, :amount, format: :currency
          column :status, :status
          column :transaction_id, :transaction_id
        end
      end
      
      band :group_footer, :status_footer do
        column :status_summary, "Status Total"
        column :status_total, :status_total_revenue, format: :currency
        column :percentage, :percentage_of_total, format: :percentage
      end
      
      band :footer, :daily_summary do
        column :grand_total_label, "GRAND TOTAL"
        column :total_orders, :total_orders
        column :total_customers, :unique_customers
        column :total_revenue, :total_revenue, format: :currency
        column :avg_order_value, :avg_order_value, format: :currency
        column :total_items_sold, :total_items_sold
      end
    end
    
    # Customer order history report
    report :customer_order_history do
      title "Customer Order History"
      description "Detailed order history for individual customers"
      
      band :header, :report_header do
        title "CUSTOMER ORDER HISTORY"
        column :customer_name, "Customer"
        column :period, "Period"
      end
      
      # Customer summary
      band :detail, :customer_summary do
        title "Customer Summary"
        data_source :customer
        
        column :name, :name
        column :email, :email
        column :customer_since, :join_date, format: :date
        column :total_orders, :total_orders
        column :lifetime_value, :lifetime_value, format: :currency
        column :avg_order_value, :avg_order_value, format: :currency
        column :last_order_date, :last_order_date, format: :date
      end
      
      # Orders grouped by year
      band :group_header, :year_header do
        data_source :order_years
        
        column :year, :year
        column :orders_in_year, :order_count
        column :year_total, :year_total, format: :currency
      end
      
      # Orders in each year
      band :detail, :yearly_orders do
        data_source :orders_in_year
        
        column :order_number, :order_number
        column :order_date, :order_date, format: :date
        column :status, :status
        column :items, :item_count
        column :total, :total, format: :currency
        column :payment_status, :payment_status
        
        # Order items summary
        band :detail, :order_items_summary do
          title "Items in Order"
          data_source :line_items_summary
          
          column :category, :category_name
          column :item_count, :item_count
          column :category_total, :category_total, format: :currency
        end
      end
      
      band :group_footer, :year_footer do
        column :year_total_label, "Year Total"
        column :year_total, :year_total, format: :currency
        column :year_avg_order, :year_avg_order, format: :currency
      end
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    read :with_full_details do
      prepare build(load: [
        :customer,
        line_items: [:product_variant, :product],
        payments: []
      ])
    end
  end
end
```

### 5. Supporting Resources

```elixir
# ProductVariant Resource
defmodule TestECommerce.ProductVariant do
  use Ash.Resource,
    domain: TestECommerce.Domain,
    extensions: [AshReports.Resource]

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :sku, :string, allow_nil? false
    attribute :price, :decimal
    attribute :cost, :decimal
    attribute :weight, :decimal
    attribute :barcode, :string
    attribute :is_active, :boolean, default: true
  end

  relationships do
    belongs_to :product, TestECommerce.Product
    has_many :line_items, TestECommerce.LineItem
    has_many :inventory_records, TestECommerce.Inventory
  end

  aggregates do
    sum :units_sold, :line_items, :quantity
    sum :revenue, :line_items, :total_price
    sum :inventory_quantity, :inventory_records, :quantity
  end

  reportable do
    enabled? true
    title_field :name
    default_columns [:name, :sku, :price, :units_sold, :inventory_quantity]
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# LineItem Resource
defmodule TestECommerce.LineItem do
  use Ash.Resource,
    domain: TestECommerce.Domain,
    extensions: [AshReports.Resource]

  attributes do
    uuid_primary_key :id
    attribute :quantity, :integer, allow_nil? false
    attribute :unit_price, :decimal, allow_nil? false
    attribute :discount_amount, :decimal, default: Decimal.new(0)
    attribute :total_price, :decimal, allow_nil? false
  end

  relationships do
    belongs_to :order, TestECommerce.Order
    belongs_to :product_variant, TestECommerce.ProductVariant
  end

  calculations do
    calculate :product_name, :string, expr(product_variant.product.name)
    calculate :variant_name, :string, expr(product_variant.name)
    calculate :sku, :string, expr(product_variant.sku)
    calculate :category_name, :string, expr(product_variant.product.category.name)
  end

  reportable do
    enabled? true
    title_field :product_name
    default_columns [:product_name, :quantity, :unit_price, :total_price]
    group_by_fields [:order_id, :product_variant_id]
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Payment Resource
defmodule TestECommerce.Payment do
  use Ash.Resource,
    domain: TestECommerce.Domain,
    extensions: [AshReports.Resource]

  attributes do
    uuid_primary_key :id
    attribute :amount, :decimal, allow_nil? false
    attribute :payment_method, :atom, constraints: [one_of: [:credit_card, :debit_card, :paypal, :bank_transfer, :cash]]
    attribute :payment_date, :date, default: &Date.utc_today/0
    attribute :status, :atom, constraints: [one_of: [:pending, :completed, :failed, :refunded]]
    attribute :transaction_id, :string
    attribute :notes, :string
  end

  relationships do
    belongs_to :order, TestECommerce.Order
    belongs_to :customer, TestECommerce.Customer
  end

  reportable do
    enabled? true
    title_field :transaction_id
    default_columns [:payment_date, :amount, :payment_method, :status]
    group_by_fields [:payment_method, :status, :payment_date]
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Inventory Resource
defmodule TestECommerce.Inventory do
  use Ash.Resource,
    domain: TestECommerce.Domain,
    extensions: [AshReports.Resource]

  attributes do
    uuid_primary_key :id
    attribute :quantity, :integer, allow_nil? false
    attribute :reserved_quantity, :integer, default: 0
    attribute :reorder_point, :integer, default: 0
    attribute :last_updated, :datetime, default: &DateTime.utc_now/0
    attribute :location, :string
  end

  relationships do
    belongs_to :product_variant, TestECommerce.ProductVariant
  end

  calculations do
    calculate :available_quantity, :integer, expr(quantity - reserved_quantity)
    calculate :needs_reorder, :boolean, expr(available_quantity <= reorder_point)
  end

  reportable do
    enabled? true
    title_field :product_variant_name
    default_columns [:product_variant_name, :quantity, :available_quantity, :needs_reorder]
    group_by_fields [:location, :needs_reorder]
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

## Testing Scenarios

### 1. Basic Report Generation

```elixir
# Test basic HTML report generation
test "generates basic sales analytics HTML report" do
  # Create test data
  customer = create_customer()
  product = create_product()
  order = create_order(customer, [product])
  
  # Generate report
  {:ok, html} = TestECommerce.Domain.Reports.SalesAnalytics.Html.generate(%{
    start_date: Date.add(Date.utc_today(), -30),
    end_date: Date.utc_today()
  })
  
  assert html =~ "SALES ANALYTICS DASHBOARD"
  assert html =~ "Monthly Sales Breakdown"
  assert html =~ customer.name
end
```

### 2. Hierarchical Data Testing

```elixir
# Test customer referral hierarchy
test "generates customer hierarchy report with nested referrals" do
  # Create referral chain: root_customer -> level_1 -> level_2 -> level_3
  root_customer = create_customer(%{name: "Root Customer"})
  level_1 = create_customer(%{name: "Level 1 Referral", referrer_id: root_customer.id})
  level_2 = create_customer(%{name: "Level 2 Referral", referrer_id: level_1.id})
  level_3 = create_customer(%{name: "Level 3 Referral", referrer_id: level_2.id})
  
  {:ok, html} = TestECommerce.Domain.Reports.CustomerHierarchy.Html.generate()
  
  assert html =~ "Root Customer"
  assert html =~ "Level 1 Referral"
  assert html =~ "Level 2 Referral"
  assert html =~ "Level 3 Referral"
end

# Test category hierarchy
test "generates category hierarchy with nested subcategories" do
  electronics = create_category(%{name: "Electronics"})
  computers = create_category(%{name: "Computers", parent_category_id: electronics.id})
  laptops = create_category(%{name: "Laptops", parent_category_id: computers.id})
  gaming_laptops = create_category(%{name: "Gaming Laptops", parent_category_id: laptops.id})
  
  {:ok, html} = TestECommerce.Domain.Reports.CategoryHierarchy.Html.generate()
  
  assert html =~ "Electronics"
  assert html =~ "Computers"
  assert html =~ "Laptops"
  assert html =~ "Gaming Laptops"
end
```

### 3. Multi-Format Testing

```elixir
# Test multiple output formats
test "generates reports in all supported formats" do
  setup_test_data()
  
  # Test HTML
  {:ok, html} = TestECommerce.Domain.Reports.SalesAnalytics.Html.generate()
  assert is_binary(html)
  assert html =~ "<html>"
  
  # Test PDF
  {:ok, pdf_path} = TestECommerce.Domain.Reports.SalesAnalytics.Pdf.generate()
  assert File.exists?(pdf_path)
  
  # Test HEEX
  {:ok, heex} = TestECommerce.Domain.Reports.SalesAnalytics.Heex.generate()
  assert is_binary(heex)
end
```

### 4. Complex Data Relationships

```elixir
# Test report with complex joins and aggregations
test "generates order report with full relationship data" do
  customer = create_customer()
  category = create_category()
  product = create_product(category)
  variant = create_product_variant(product)
  order = create_order(customer)
  line_item = create_line_item(order, variant, quantity: 5, unit_price: 10.00)
  payment = create_payment(order, amount: 50.00)
  
  {:ok, html} = TestECommerce.Order.generate_customer_order_history_report(
    :html, 
    %{customer_id: customer.id}
  )
  
  assert html =~ customer.name
  assert html =~ product.name
  assert html =~ "$50.00"
  assert html =~ "5" # quantity
end
```

### 5. Performance Testing

```elixir
# Test with large datasets
test "handles large datasets efficiently" do
  # Create 1000 customers with referral chains
  customers = create_customers_with_referrals(1000)
  
  # Create 10000 orders
  orders = create_bulk_orders(customers, 10000)
  
  start_time = System.monotonic_time()
  {:ok, _html} = TestECommerce.Domain.Reports.SalesAnalytics.Html.generate()
  end_time = System.monotonic_time()
  
  duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
  
  # Should complete within reasonable time
  assert duration_ms < 5000 # 5 seconds
end
```

### 6. Custom Aggregations and Calculations

```elixir
# Test custom calculations in reports
test "includes custom calculations in reports" do
  customer = create_customer()
  
  # Create orders with different values to test calculations
  create_order(customer, total: 100.00)
  create_order(customer, total: 200.00)
  create_order(customer, total: 300.00)
  
  {:ok, html} = TestECommerce.Customer.generate_customer_lifetime_value_report(
    :html,
    %{customer_id: customer.id}
  )
  
  assert html =~ "$600.00" # total lifetime value
  assert html =~ "$200.00" # average order value
  assert html =~ "3" # total orders
end
```

### 7. Error Handling

```elixir
# Test error handling with invalid data
test "handles missing data gracefully" do
  # Generate report with no data
  {:ok, html} = TestECommerce.Domain.Reports.SalesAnalytics.Html.generate()
  
  assert html =~ "No data available"
  assert html =~ "SALES ANALYTICS DASHBOARD"
end

# Test with invalid parameters
test "handles invalid parameters" do
  {:error, reason} = TestECommerce.Domain.Reports.SalesAnalytics.Html.generate(%{
    start_date: "invalid-date"
  })
  
  assert reason =~ "Invalid date format"
end
```

## Performance Benchmarks

### Dataset Sizes for Testing

1. **Small Dataset**: 100 customers, 1,000 orders, 5,000 line items
2. **Medium Dataset**: 1,000 customers, 10,000 orders, 50,000 line items  
3. **Large Dataset**: 10,000 customers, 100,000 orders, 500,000 line items

### Expected Performance Targets

- **Small Dataset**: Reports should generate within 1 second
- **Medium Dataset**: Reports should generate within 5 seconds
- **Large Dataset**: Reports should generate within 30 seconds

### Memory Usage Targets

- **Small Dataset**: < 50MB peak memory usage
- **Medium Dataset**: < 200MB peak memory usage
- **Large Dataset**: < 500MB peak memory usage

## Test Data Factories

```elixir
defmodule TestECommerce.Factory do
  @moduledoc """
  Factory functions for creating test data.
  """
  
  def create_customer(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Customer #{System.unique_integer()}",
      email: "customer#{System.unique_integer()}@example.com",
      customer_type: :individual,
      status: :active
    }
    
    attrs = Map.merge(default_attrs, attrs)
    TestECommerce.Customer.create!(attrs)
  end
  
  def create_category(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Category #{System.unique_integer()}",
      description: "Test category description",
      is_active: true
    }
    
    attrs = Map.merge(default_attrs, attrs)
    TestECommerce.Category.create!(attrs)
  end
  
  def create_product(category \\ nil, attrs \\ %{}) do
    category = category || create_category()
    
    default_attrs = %{
      name: "Test Product #{System.unique_integer()}",
      sku: "TEST-#{System.unique_integer()}",
      price: Decimal.new("19.99"),
      cost: Decimal.new("10.00"),
      category_id: category.id,
      is_active: true
    }
    
    attrs = Map.merge(default_attrs, attrs)
    TestECommerce.Product.create!(attrs)
  end
  
  def create_product_variant(product \\ nil, attrs \\ %{}) do
    product = product || create_product()
    
    default_attrs = %{
      name: "Test Variant #{System.unique_integer()}",
      sku: "VAR-#{System.unique_integer()}",
      price: product.price,
      cost: product.cost,
      product_id: product.id,
      is_active: true
    }
    
    attrs = Map.merge(default_attrs, attrs)
    TestECommerce.ProductVariant.create!(attrs)
  end
  
  def create_order(customer \\ nil, variants \\ [], attrs \\ %{}) do
    customer = customer || create_customer()
    variants = if Enum.empty?(variants), do: [create_product_variant()], else: variants
    
    subtotal = Enum.reduce(variants, Decimal.new(0), fn variant, acc ->
      Decimal.add(acc, variant.price)
    end)
    
    total = Decimal.add(subtotal, Decimal.new("5.00")) # Add shipping
    
    default_attrs = %{
      order_number: "ORD-#{System.unique_integer()}",
      customer_id: customer.id,
      status: :confirmed,
      subtotal: subtotal,
      shipping_amount: Decimal.new("5.00"),
      total: total
    }
    
    attrs = Map.merge(default_attrs, attrs)
    order = TestECommerce.Order.create!(attrs)
    
    # Create line items
    Enum.each(variants, fn variant ->
      create_line_item(order, variant)
    end)
    
    order
  end
  
  def create_line_item(order, variant, attrs \\ %{}) do
    default_attrs = %{
      order_id: order.id,
      product_variant_id: variant.id,
      quantity: 1,
      unit_price: variant.price,
      total_price: variant.price
    }
    
    attrs = Map.merge(default_attrs, attrs)
    TestECommerce.LineItem.create!(attrs)
  end
  
  def create_customers_with_referrals(count) do
    # Create root customers (25% of total)
    root_count = div(count, 4)
    root_customers = Enum.map(1..root_count, fn _ ->
      create_customer()
    end)
    
    # Create referral chains
    remaining = count - root_count
    Enum.reduce(1..remaining, root_customers, fn _, acc ->
      referrer = Enum.random(acc)
      new_customer = create_customer(%{referrer_id: referrer.id})
      [new_customer | acc]
    end)
  end
  
  def create_bulk_orders(customers, count) do
    Enum.map(1..count, fn _ ->
      customer = Enum.random(customers)
      variant_count = Enum.random(1..5)
      variants = Enum.map(1..variant_count, fn _ -> create_product_variant() end)
      create_order(customer, variants)
    end)
  end
end
```

This comprehensive testing guide provides a complete ECommerce domain that exercises all the features of the AshReports extension:

1. **Self-referencing relationships** in Customer (referrals) and Category (hierarchy)
2. **Complex nested bands** with multiple levels of detail
3. **Multiple output formats** (HTML, PDF, HEEX)
4. **Aggregations and calculations** at various levels
5. **Real-world data relationships** between customers, orders, products, etc.
6. **Performance testing** with different dataset sizes
7. **Error handling** scenarios

The test domain provides a realistic foundation for testing all aspects of the extension as it's developed through the implementation phases.
