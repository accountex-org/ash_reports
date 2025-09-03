defmodule AshReportsDemo.CustomerAddress do
  @moduledoc """
  Customer address resource for AshReports Demo.

  Represents customer addresses with support for multiple addresses
  per customer including billing, shipping, and mailing addresses.
  """

  use Ash.Resource,
    domain: AshReportsDemo.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    table :demo_customer_addresses
  end

  attributes do
    uuid_primary_key :id

    attribute :address_type, :atom do
      description "Type of address"
      constraints one_of: [:billing, :shipping, :mailing, :other]
      default :billing
      allow_nil? false
    end

    attribute :street, :string do
      allow_nil? false
      description "Street address"
      constraints max_length: 255
    end

    attribute :street2, :string do
      description "Additional address line"
      constraints max_length: 255
    end

    attribute :city, :string do
      allow_nil? false
      description "City"
      constraints max_length: 100
    end

    attribute :state, :string do
      allow_nil? false
      description "State or province"
      constraints max_length: 100
    end

    attribute :postal_code, :string do
      allow_nil? false
      description "Postal or ZIP code"
      constraints max_length: 20
    end

    attribute :country, :string do
      allow_nil? false
      description "Country"
      default "United States"
      constraints max_length: 100
    end

    attribute :primary, :boolean do
      description "Whether this is the primary address"
      default false
      allow_nil? false
    end

    attribute :active, :boolean do
      description "Whether this address is currently active"
      default true
      allow_nil? false
    end

    attribute :created_at, :utc_datetime_usec do
      description "When the address was created"
      default &DateTime.utc_now/0
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :primary do
      description "Get primary addresses only"
      filter expr(primary == true and active == true)
    end

    read :by_type do
      description "Get addresses by type"
      argument :address_type, :atom, allow_nil?: false
      filter expr(address_type == ^arg(:address_type) and active == true)
    end

    read :by_state do
      description "Get addresses by state"
      argument :state, :string, allow_nil?: false
      filter expr(state == ^arg(:state) and active == true)
    end

    update :set_primary do
      description "Set this address as primary"
      change set_attribute(:primary, true)
      # Note: In a real system, we'd also unset other primary addresses
    end

    update :deactivate do
      description "Deactivate this address"
      change set_attribute(:active, false)
    end
  end

  relationships do
    belongs_to :customer, AshReportsDemo.Customer do
      description "Customer this address belongs to"
      allow_nil? false
    end
  end

  calculations do
    calculate :formatted_address, :string do
      description "Formatted address string for display"

      calculation fn records, _context ->
        records
        |> Enum.map(fn address ->
          formatted =
            [
              address.street,
              address.street2,
              "#{address.city}, #{address.state} #{address.postal_code}",
              address.country
            ]
            |> Enum.filter(&(&1 && String.trim(&1) != ""))
            |> Enum.join("\n")

          {address.id, formatted}
        end)
        |> Map.new()
      end
    end

    calculate :short_address, :string, expr(city <> ", " <> state) do
      description "Short address format for listings"
    end

    calculate :region, :string do
      description "Geographic region based on state"

      calculation fn records, _context ->
        records
        |> Enum.map(fn address ->
          region =
            case String.upcase(address.state) do
              state when state in ["CA", "OR", "WA", "NV", "AZ"] ->
                "West"

              state when state in ["NY", "NJ", "CT", "MA", "ME", "VT", "NH", "RI"] ->
                "Northeast"

              state when state in ["FL", "GA", "SC", "NC", "VA", "TN", "KY", "WV"] ->
                "Southeast"

              state when state in ["TX", "OK", "AR", "LA", "MS", "AL"] ->
                "South"

              state when state in ["IL", "IN", "OH", "MI", "WI", "MN", "IA", "MO"] ->
                "Midwest"

              state when state in ["CO", "UT", "WY", "MT", "ID", "ND", "SD", "NE", "KS"] ->
                "Mountain West"

              _ ->
                "Other"
            end

          {address.id, region}
        end)
        |> Map.new()
      end
    end
  end

  validations do
    validate present([:street, :city, :state, :postal_code]),
      message: "street, city, state, and postal code are required"

    validate attribute_does_not_equal(:street, ""), message: "street cannot be blank"
    validate attribute_does_not_equal(:city, ""), message: "city cannot be blank"
    validate attribute_does_not_equal(:state, ""), message: "state cannot be blank"
    validate attribute_does_not_equal(:postal_code, ""), message: "postal code cannot be blank"
  end

  resource do
    description "Customer address management with geographic support"
  end
end
