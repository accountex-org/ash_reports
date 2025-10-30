defmodule AshReports.RealisticTestHelpersTest do
  use ExUnit.Case, async: false

  alias AshReports.RealisticTestHelpers
  alias AshReportsDemo.EtsDataLayer

  describe "setup_ets_tables/0" do
    test "returns list of ETS table names" do
      tables = RealisticTestHelpers.setup_ets_tables()

      assert is_list(tables)
      assert length(tables) == 8
      assert :demo_customers in tables
      assert :demo_invoices in tables
      assert :demo_products in tables
    end

    test "clears existing data from tables" do
      # First, ensure some data exists
      RealisticTestHelpers.generate_test_data(scenario: :small)

      # Verify data exists
      stats_before = EtsDataLayer.table_stats()
      assert stats_before.total_records > 0

      # Setup tables (should clear data)
      RealisticTestHelpers.setup_ets_tables()

      # Verify data is cleared
      stats_after = EtsDataLayer.table_stats()
      assert stats_after.total_records == 0
    end
  end

  describe "cleanup_ets_tables/0" do
    test "clears all data from ETS tables" do
      # Generate some data
      RealisticTestHelpers.generate_test_data(scenario: :small)

      # Verify data exists
      stats_before = EtsDataLayer.table_stats()
      assert stats_before.total_records > 0

      # Cleanup
      assert :ok == RealisticTestHelpers.cleanup_ets_tables()

      # Verify data is cleared
      stats_after = EtsDataLayer.table_stats()
      assert stats_after.total_records == 0
    end
  end

  describe "generate_test_data/1" do
    setup do
      # Clean up before each test
      RealisticTestHelpers.setup_ets_tables()
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)
      :ok
    end

    test "generates empty scenario with no data" do
      result = RealisticTestHelpers.generate_test_data(scenario: :empty)

      assert is_map(result)
      assert result.customers == []
      assert result.invoices == []
      assert result.products == []

      # Verify ETS tables are still empty
      stats = EtsDataLayer.table_stats()
      assert stats.total_records == 0
    end

    test "generates small scenario with data" do
      result = RealisticTestHelpers.generate_test_data(scenario: :small)

      assert is_map(result)
      assert result.scenario == :small
      assert result.status == :generated

      # Verify ETS tables have data
      stats = EtsDataLayer.table_stats()
      assert stats.total_records > 0
    end

    test "generates medium scenario with more data" do
      result = RealisticTestHelpers.generate_test_data(scenario: :medium)

      assert is_map(result)
      assert result.scenario == :medium
      assert result.status == :generated

      # Verify ETS tables have data
      stats = EtsDataLayer.table_stats()
      assert stats.total_records > 0
    end

    @tag timeout: 180_000
    test "generates large scenario with lots of data" do
      result = RealisticTestHelpers.generate_test_data(scenario: :large)

      assert is_map(result)
      assert result.scenario == :large
      assert result.status == :generated

      # Verify ETS tables have data
      stats = EtsDataLayer.table_stats()
      assert stats.total_records > 0
    end

    # Note: Seed reproducibility not implemented because Faker library
    # doesn't use Erlang's :rand module. This is a nice-to-have feature
    # that can be added later if needed for debugging purposes.
  end

  describe "setup_realistic_test_data/1" do
    test "sets up ETS tables and generates data" do
      result = RealisticTestHelpers.setup_realistic_test_data(scenario: :small)

      assert is_map(result)
      assert result.scenario == :small
      assert is_list(result.ets_tables)
      assert is_map(result.counts)
      assert is_map(result.generated_data)

      # Verify data was generated
      stats = EtsDataLayer.table_stats()
      assert stats.total_records > 0
    end

    test "defaults to small scenario" do
      result = RealisticTestHelpers.setup_realistic_test_data()

      assert result.scenario == :small
    end

    test "handles empty scenario" do
      result = RealisticTestHelpers.setup_realistic_test_data(scenario: :empty)

      assert result.scenario == :empty

      # Verify no data was generated
      stats = EtsDataLayer.table_stats()
      assert stats.total_records == 0
    end

    test "returns record counts" do
      result = RealisticTestHelpers.setup_realistic_test_data(scenario: :small)

      counts = result.counts
      assert is_map(counts)

      # Should have counts for all resource types
      assert Map.has_key?(counts, :customers)
      assert Map.has_key?(counts, :invoices)
      assert Map.has_key?(counts, :products)
    end
  end

  describe "integration tests" do
    test "full lifecycle: setup, use, cleanup" do
      # Setup
      result = RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      assert result.scenario == :small

      # Verify data exists
      stats_with_data = EtsDataLayer.table_stats()
      assert stats_with_data.total_records > 0

      # Cleanup
      RealisticTestHelpers.cleanup_ets_tables()

      # Verify data is gone
      stats_after_cleanup = EtsDataLayer.table_stats()
      assert stats_after_cleanup.total_records == 0
    end

    test "multiple setups clean up previous data" do
      # First setup
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      stats_1 = EtsDataLayer.table_stats()

      # Second setup (should clean previous data first)
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      stats_2 = EtsDataLayer.table_stats()

      # Both should have similar record counts (not double)
      assert_in_delta(stats_1.total_records, stats_2.total_records, 50)
    end
  end

  # Phase 3: Query Helpers Tests
  describe "list_customers/1" do
    setup do
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)
      :ok
    end

    test "lists all customers without options" do
      customers = RealisticTestHelpers.list_customers()

      assert is_list(customers)
      assert length(customers) > 0
      customer = List.first(customers)
      assert customer.__struct__ == AshReportsDemo.Customer
      assert is_binary(customer.name)
      assert is_binary(customer.email)
    end

    test "respects limit option" do
      customers = RealisticTestHelpers.list_customers(limit: 5)

      assert is_list(customers)
      assert length(customers) <= 5
    end

    test "respects offset option" do
      all_customers = RealisticTestHelpers.list_customers()
      offset_customers = RealisticTestHelpers.list_customers(offset: 2)

      assert length(offset_customers) == length(all_customers) - 2
    end

    test "respects limit and offset together" do
      customers = RealisticTestHelpers.list_customers(limit: 3, offset: 2)

      assert is_list(customers)
      assert length(customers) <= 3
    end

    test "filters by status" do
      customers = RealisticTestHelpers.list_customers(filter: [status: :active])

      assert is_list(customers)
      assert Enum.all?(customers, fn c -> c.status == :active end)
    end

    test "loads relationships" do
      customers = RealisticTestHelpers.list_customers(limit: 1, load: [:invoices])

      assert is_list(customers)
      customer = List.first(customers)
      assert Ash.Resource.loaded?(customer, :invoices)
    end

    test "sorts by name ascending" do
      customers = RealisticTestHelpers.list_customers(sort: [name: :asc], limit: 10)

      names = Enum.map(customers, & &1.name)
      assert names == Enum.sort(names)
    end

    test "sorts by name descending" do
      customers = RealisticTestHelpers.list_customers(sort: [name: :desc], limit: 10)

      names = Enum.map(customers, & &1.name)
      assert names == Enum.sort(names, :desc)
    end
  end

  describe "get_customer/2" do
    setup do
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)

      # Get a customer ID to use in tests
      customer = RealisticTestHelpers.list_customers(limit: 1) |> List.first()
      {:ok, customer_id: customer.id}
    end

    test "gets customer by ID", %{customer_id: customer_id} do
      customer = RealisticTestHelpers.get_customer(customer_id)

      assert customer.__struct__ == AshReportsDemo.Customer
      assert customer.id == customer_id
      assert is_binary(customer.name)
      assert is_binary(customer.email)
    end

    test "loads relationships", %{customer_id: customer_id} do
      customer = RealisticTestHelpers.get_customer(customer_id, load: [:invoices, :addresses])

      assert Ash.Resource.loaded?(customer, :invoices)
      assert Ash.Resource.loaded?(customer, :addresses)
    end
  end

  describe "count_customers/1" do
    setup do
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)
      :ok
    end

    test "counts all customers" do
      count = RealisticTestHelpers.count_customers()

      assert is_integer(count)
      assert count > 0

      # Verify count matches list length
      customers = RealisticTestHelpers.list_customers()
      assert count == length(customers)
    end

    test "counts customers with filter" do
      active_count = RealisticTestHelpers.count_customers(filter: [status: :active])

      assert is_integer(active_count)

      # Verify count matches filtered list length
      active_customers = RealisticTestHelpers.list_customers(filter: [status: :active])
      assert active_count == length(active_customers)
    end
  end

  describe "list_invoices/1" do
    setup do
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)
      :ok
    end

    test "lists all invoices without options" do
      invoices = RealisticTestHelpers.list_invoices()

      assert is_list(invoices)
      assert length(invoices) > 0
      invoice = List.first(invoices)
      assert invoice.__struct__ == AshReportsDemo.Invoice
      assert is_binary(invoice.invoice_number)
    end

    test "respects limit option" do
      invoices = RealisticTestHelpers.list_invoices(limit: 5)

      assert is_list(invoices)
      assert length(invoices) <= 5
    end

    test "filters by status" do
      # Get all statuses first
      all_invoices = RealisticTestHelpers.list_invoices()
      statuses = Enum.map(all_invoices, & &1.status) |> Enum.uniq()

      # Pick the first status and filter by it
      if length(statuses) > 0 do
        status = List.first(statuses)
        filtered = RealisticTestHelpers.list_invoices(filter: [status: status])
        assert Enum.all?(filtered, fn i -> i.status == status end)
      end
    end

    test "loads customer relationship" do
      invoices = RealisticTestHelpers.list_invoices(limit: 1, load: [:customer])

      assert is_list(invoices)
      invoice = List.first(invoices)
      assert Ash.Resource.loaded?(invoice, :customer)
    end

    test "sorts by date descending" do
      invoices = RealisticTestHelpers.list_invoices(sort: [date: :desc], limit: 10)

      dates = Enum.map(invoices, & &1.date)
      assert dates == Enum.sort(dates, {:desc, Date})
    end
  end

  describe "get_invoice/2" do
    setup do
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)

      # Get an invoice ID to use in tests
      invoice = RealisticTestHelpers.list_invoices(limit: 1) |> List.first()
      {:ok, invoice_id: invoice.id}
    end

    test "gets invoice by ID", %{invoice_id: invoice_id} do
      invoice = RealisticTestHelpers.get_invoice(invoice_id)

      assert invoice.__struct__ == AshReportsDemo.Invoice
      assert invoice.id == invoice_id
      assert is_binary(invoice.invoice_number)
    end

    test "loads relationships", %{invoice_id: invoice_id} do
      invoice = RealisticTestHelpers.get_invoice(invoice_id, load: [:customer, :line_items])

      assert Ash.Resource.loaded?(invoice, :customer)
      assert Ash.Resource.loaded?(invoice, :line_items)
    end
  end

  describe "list_products/1" do
    setup do
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)
      :ok
    end

    test "lists all products without options" do
      products = RealisticTestHelpers.list_products()

      assert is_list(products)
      assert length(products) > 0
      product = List.first(products)
      assert product.__struct__ == AshReportsDemo.Product
      assert is_binary(product.name)
      assert is_binary(product.sku)
    end

    test "respects limit option" do
      products = RealisticTestHelpers.list_products(limit: 5)

      assert is_list(products)
      assert length(products) <= 5
    end

    test "filters by active status" do
      products = RealisticTestHelpers.list_products(filter: [active: true])

      assert is_list(products)
      assert Enum.all?(products, fn p -> p.active == true end)
    end

    test "loads category relationship" do
      products = RealisticTestHelpers.list_products(limit: 1, load: [:category])

      assert is_list(products)
      product = List.first(products)
      assert Ash.Resource.loaded?(product, :category)
    end

    test "sorts by name ascending" do
      products = RealisticTestHelpers.list_products(sort: [name: :asc], limit: 10)

      names = Enum.map(products, & &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "get_product/2" do
    setup do
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)

      # Get a product ID to use in tests
      product = RealisticTestHelpers.list_products(limit: 1) |> List.first()
      {:ok, product_id: product.id}
    end

    test "gets product by ID", %{product_id: product_id} do
      product = RealisticTestHelpers.get_product(product_id)

      assert product.__struct__ == AshReportsDemo.Product
      assert product.id == product_id
      assert is_binary(product.name)
      assert is_binary(product.sku)
    end

    test "loads relationships", %{product_id: product_id} do
      product = RealisticTestHelpers.get_product(product_id, load: [:category])

      assert Ash.Resource.loaded?(product, :category)
    end
  end

  # Phase 4: Conversion Utilities Tests
  describe "to_simple_map/2" do
    setup do
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)
      :ok
    end

    test "converts Ash resource to simple map" do
      customer = RealisticTestHelpers.list_customers(limit: 1) |> List.first()
      simple_map = RealisticTestHelpers.to_simple_map(customer)

      # Should be a plain map, not a struct
      refute is_struct(simple_map)
      assert is_map(simple_map)

      # Should have customer attributes
      assert Map.has_key?(simple_map, :id)
      assert Map.has_key?(simple_map, :name)
      assert Map.has_key?(simple_map, :email)
      assert Map.has_key?(simple_map, :status)

      # Values should match
      assert simple_map.id == customer.id
      assert simple_map.name == customer.name
      assert simple_map.email == customer.email
    end

    test "excludes metadata fields by default" do
      customer = RealisticTestHelpers.list_customers(limit: 1) |> List.first()
      simple_map = RealisticTestHelpers.to_simple_map(customer)

      refute Map.has_key?(simple_map, :__meta__)
      refute Map.has_key?(simple_map, :__metadata__)
      refute Map.has_key?(simple_map, :aggregates)
      refute Map.has_key?(simple_map, :calculations)
    end

    test "respects exclude_fields option" do
      customer = RealisticTestHelpers.list_customers(limit: 1) |> List.first()
      simple_map = RealisticTestHelpers.to_simple_map(customer, exclude_fields: [:email, :phone])

      refute Map.has_key?(simple_map, :email)
      refute Map.has_key?(simple_map, :phone)
      assert Map.has_key?(simple_map, :name)
      assert Map.has_key?(simple_map, :id)
    end

    test "handles loaded relationships" do
      customer = RealisticTestHelpers.list_customers(limit: 1, load: [:invoices]) |> List.first()
      simple_map = RealisticTestHelpers.to_simple_map(customer)

      # Should include loaded invoices
      assert Map.has_key?(simple_map, :invoices)
      assert is_list(simple_map.invoices)

      # Each invoice should also be a simple map
      if length(simple_map.invoices) > 0 do
        invoice = List.first(simple_map.invoices)
        refute is_struct(invoice)
        assert is_map(invoice)
        assert Map.has_key?(invoice, :invoice_number)
      end
    end

    test "excludes relationships with include_relationships: false" do
      customer = RealisticTestHelpers.list_customers(limit: 1, load: [:invoices]) |> List.first()
      simple_map = RealisticTestHelpers.to_simple_map(customer, include_relationships: false)

      # Should not include invoices even though they're loaded
      refute Map.has_key?(simple_map, :invoices)
    end

    test "skips unloaded relationships" do
      customer = RealisticTestHelpers.list_customers(limit: 1) |> List.first()
      simple_map = RealisticTestHelpers.to_simple_map(customer)

      # Should not include unloaded invoices
      refute Map.has_key?(simple_map, :invoices)
    end

    test "handles nil input" do
      result = RealisticTestHelpers.to_simple_map(nil)
      assert result == nil
    end

    test "handles plain map input" do
      input_map = %{id: 1, name: "Test"}
      result = RealisticTestHelpers.to_simple_map(input_map)
      assert result == input_map
    end

    test "preserves Decimal values" do
      product = RealisticTestHelpers.list_products(limit: 1) |> List.first()
      simple_map = RealisticTestHelpers.to_simple_map(product)

      assert %Decimal{} = simple_map.price
      assert %Decimal{} = simple_map.cost
    end

    test "preserves Date and DateTime values" do
      invoice = RealisticTestHelpers.list_invoices(limit: 1) |> List.first()
      simple_map = RealisticTestHelpers.to_simple_map(invoice)

      assert %Date{} = simple_map.date
      assert %DateTime{} = simple_map.created_at
    end
  end

  describe "to_simple_maps/2" do
    setup do
      RealisticTestHelpers.setup_realistic_test_data(scenario: :small)
      on_exit(fn -> RealisticTestHelpers.cleanup_ets_tables() end)
      :ok
    end

    test "converts list of Ash resources to simple maps" do
      customers = RealisticTestHelpers.list_customers(limit: 5)
      simple_maps = RealisticTestHelpers.to_simple_maps(customers)

      assert is_list(simple_maps)
      assert length(simple_maps) == length(customers)

      # Each should be a plain map
      Enum.each(simple_maps, fn map ->
        refute is_struct(map)
        assert is_map(map)
        assert Map.has_key?(map, :id)
        assert Map.has_key?(map, :name)
      end)
    end

    test "handles empty list" do
      result = RealisticTestHelpers.to_simple_maps([])
      assert result == []
    end

    test "passes options to each conversion" do
      customers = RealisticTestHelpers.list_customers(limit: 3)
      simple_maps = RealisticTestHelpers.to_simple_maps(customers, exclude_fields: [:email])

      Enum.each(simple_maps, fn map ->
        refute Map.has_key?(map, :email)
        assert Map.has_key?(map, :name)
      end)
    end

    test "handles relationships in list conversion" do
      customers = RealisticTestHelpers.list_customers(limit: 3, load: [:invoices])
      simple_maps = RealisticTestHelpers.to_simple_maps(customers)

      Enum.each(simple_maps, fn map ->
        assert Map.has_key?(map, :invoices)
        assert is_list(map.invoices)
      end)
    end
  end
end
