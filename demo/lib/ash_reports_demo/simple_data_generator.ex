defmodule AshReportsDemo.SimpleDataGenerator do
  @moduledoc """
  Simple data generator for Phase 8.1 testing.

  Creates basic test data to verify the data integration pipeline works.
  """

  alias AshReportsDemo.{Customer, CustomerAddress, CustomerType, Domain}

  @doc """
  Creates a minimal set of test data for Phase 8.1 validation.
  """
  def create_test_data do
    with {:ok, customer_type} <- create_customer_type(),
         {:ok, customers} <- create_customers(customer_type),
         {:ok, _addresses} <- create_addresses(customers) do
      {:ok, %{customers: customers, customer_type: customer_type}}
    end
  end

  @doc """
  Clears all test data.
  """
  def clear_test_data do
    # Clear ETS tables
    try do
      Customer.read!(domain: Domain) |> Enum.each(&Customer.destroy!(&1, domain: Domain))
    catch
      _, _ -> :ok
    end

    try do
      CustomerAddress.read!(domain: Domain)
      |> Enum.each(&CustomerAddress.destroy!(&1, domain: Domain))
    catch
      _, _ -> :ok
    end

    try do
      CustomerType.read!(domain: Domain) |> Enum.each(&CustomerType.destroy!(&1, domain: Domain))
    catch
      _, _ -> :ok
    end

    :ok
  end

  defp create_customer_type do
    attrs = %{
      name: "Gold",
      description: "Gold tier customers",
      credit_limit_multiplier: Decimal.new("2.0"),
      discount_percentage: Decimal.new("10.0"),
      active: true
    }

    CustomerType.create(attrs, domain: Domain)
  end

  defp create_customers(customer_type) do
    customers_data = [
      %{
        name: "Alice Johnson",
        email: "alice@example.com",
        status: :active,
        customer_type_id: customer_type.id
      },
      %{
        name: "Bob Smith",
        email: "bob@example.com",
        status: :active,
        customer_type_id: customer_type.id
      },
      %{
        name: "Carol Davis",
        email: "carol@example.com",
        status: :inactive,
        customer_type_id: customer_type.id
      }
    ]

    results =
      customers_data
      |> Enum.map(fn attrs ->
        Customer.create(attrs, domain: Domain)
      end)

    # Check if all succeeded
    errors =
      Enum.filter(results, fn
        {:error, _} -> true
        _ -> false
      end)

    if length(errors) > 0 do
      {:error, "Failed to create customers: #{inspect(errors)}"}
    else
      customers = Enum.map(results, fn {:ok, customer} -> customer end)
      {:ok, customers}
    end
  end

  defp create_addresses(customers) do
    addresses_data = [
      %{
        customer_id: List.first(customers).id,
        street: "123 Main St",
        city: "Los Angeles",
        state: "CA",
        zip_code: "90210",
        primary: true
      },
      %{
        customer_id: List.last(customers).id,
        street: "456 Oak Ave",
        city: "San Francisco",
        state: "CA",
        zip_code: "94102",
        primary: true
      }
    ]

    results =
      addresses_data
      |> Enum.map(fn attrs ->
        CustomerAddress.create(attrs, domain: Domain)
      end)

    # Check if all succeeded
    errors =
      Enum.filter(results, fn
        {:error, _} -> true
        _ -> false
      end)

    if length(errors) > 0 do
      {:error, "Failed to create addresses: #{inspect(errors)}"}
    else
      addresses = Enum.map(results, fn {:ok, address} -> address end)
      {:ok, addresses}
    end
  end
end
