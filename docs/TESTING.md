# Emakola — Testing Strategy

## Philosophy

- **TDD always** — write the test first, then the code
- **Test behavior, not implementation** — tests should survive refactoring
- **Fast feedback** — unit tests run in < 30s, full suite in < 5min
- **Realistic data** — use Ghanaian names, phone formats, addresses in factories

## Test Pyramid

```
         ╱  E2E (Playwright)  ╲         5% — Critical purchase flow
        ╱   LiveView Tests     ╲       15% — Full render + interaction
       ╱   Integration Tests    ╲      20% — Multi-resource, database
      ╱      Unit Tests          ╲     60% — Ash resources, services
```

## Directory Structure

```
test/
├── emakola/
│   ├── accounts/
│   │   ├── merchant_test.exs
│   │   ├── store_test.exs
│   │   └── store_config_test.exs
│   ├── catalog/
│   │   ├── product_test.exs
│   │   ├── variant_test.exs
│   │   ├── category_test.exs
│   │   └── image_test.exs
│   ├── orders/
│   │   ├── order_test.exs
│   │   ├── line_item_test.exs
│   │   ├── payment_test.exs
│   │   └── refund_test.exs
│   ├── customers/
│   │   ├── customer_test.exs
│   │   └── address_test.exs
│   ├── payments/
│   │   ├── gateways/
│   │   │   ├── paystack_test.exs
│   │   │   ├── hubtel_test.exs
│   │   │   └── cash_on_delivery_test.exs
│   │   └── payment_service_test.exs
│   ├── shipping/
│   │   ├── shipping_zone_test.exs
│   │   └── fulfillment_test.exs
│   ├── marketing/
│   │   └── discount_test.exs
│   └── messaging/
│       ├── sms_test.exs
│       └── whatsapp_test.exs
├── emakola_web/
│   ├── live/
│   │   ├── admin/
│   │   │   ├── dashboard_live_test.exs
│   │   │   ├── product_live_test.exs
│   │   │   ├── order_live_test.exs
│   │   │   └── settings_live_test.exs
│   │   └── storefront/
│   │       ├── home_live_test.exs
│   │       ├── product_listing_live_test.exs
│   │       ├── product_detail_live_test.exs
│   │       ├── cart_live_test.exs
│   │       └── checkout_live_test.exs
│   └── controllers/
│       └── webhook_controller_test.exs
├── support/
│   ├── factories.ex
│   ├── mocks.ex
│   ├── conn_case.ex
│   ├── data_case.ex
│   └── fixtures/
│       └── webhooks/
│           ├── paystack_success.json
│           ├── paystack_failed.json
│           ├── hubtel_momo_success.json
│           └── hubtel_momo_failed.json
└── test_helper.exs
```

## Test Factories

```elixir
defmodule Emakola.Factories do
  # Ghanaian-realistic test data

  def merchant_attrs(overrides \\ %{}) do
    Map.merge(%{
      email: "kwame.asante#{System.unique_integer()}@example.com",
      password: "SecurePass123!",
      name: "Kwame Asante",
      phone: "+233241234567"
    }, overrides)
  end

  def store_attrs(overrides \\ %{}) do
    slug = "store-#{System.unique_integer([:positive])}"
    Map.merge(%{
      name: "Accra Fashion Hub",
      slug: slug,
      description: "Premium fashion from Accra",
      currency: :GHS
    }, overrides)
  end

  def product_attrs(overrides \\ %{}) do
    Map.merge(%{
      title: "Kente Cloth Dress",
      description: "Handwoven authentic kente cloth dress",
      status: :active
    }, overrides)
  end

  def variant_attrs(overrides \\ %{}) do
    Map.merge(%{
      sku: "KCD-#{System.unique_integer([:positive])}",
      price: 15000,           # GH₵ 150.00 in pesewas
      compare_at_price: nil,
      inventory_quantity: 25,
      option_values: %{"size" => "M", "color" => "Multicolor"}
    }, overrides)
  end

  def order_attrs(overrides \\ %{}) do
    Map.merge(%{
      customer_email: "ama.mensah@example.com",
      customer_phone: "+233501234567",
      subtotal: 15000,
      shipping_total: 2000,
      tax_total: 0,
      total: 17000,
      currency: :GHS
    }, overrides)
  end

  def address_attrs(overrides \\ %{}) do
    Map.merge(%{
      first_name: "Ama",
      last_name: "Mensah",
      address1: "15 Oxford Street",
      address2: "Osu",
      city: "Accra",
      region: "Greater Accra",
      postal_code: "GA-123",
      country: :GH,
      phone: "+233501234567"
    }, overrides)
  end
end
```

## Mocking External Services

```elixir
# test/support/mocks.ex
Mox.defmock(Emakola.Payments.PaystackMock, for: Emakola.Payments.Gateway)
Mox.defmock(Emakola.Payments.HubtelMock, for: Emakola.Payments.Gateway)
Mox.defmock(Emakola.Messaging.SMSMock, for: Emakola.Messaging.SMSProvider)
Mox.defmock(Emakola.Messaging.WhatsAppMock, for: Emakola.Messaging.WhatsAppProvider)
Mox.defmock(Emakola.Storage.S3Mock, for: Emakola.Storage.StorageProvider)
```

```elixir
# config/test.exs
config :emakola, Emakola.Payments, gateway: Emakola.Payments.PaystackMock
config :emakola, Emakola.Messaging, sms: Emakola.Messaging.SMSMock
config :emakola, Emakola.Messaging, whatsapp: Emakola.Messaging.WhatsAppMock
```

## Critical Test Scenarios

### Multi-Tenant Isolation
```elixir
test "store A cannot access store B products" do
  store_a = create_store("store-a")
  store_b = create_store("store-b")
  product = create_product(store: store_a, title: "Secret Product")

  # Query with store_b tenant context should NOT return store_a products
  assert {:ok, []} = Emakola.Catalog.Product
    |> Ash.Query.for_read(:list)
    |> Ash.Query.set_tenant(store_b.id)
    |> Ash.read()
end
```

### Payment Flow: Mobile Money (Async)
```elixir
test "MTN MoMo payment: initiate → webhook → order confirmed" do
  order = create_order(total: 15000, currency: :GHS)

  # 1. Initiate payment
  expect(HubtelMock, :initiate_payment, fn order, %{phone: "+233241234567", method: :mtn_momo} ->
    {:ok, %{reference: "hub_ref_123", status: :pending}}
  end)

  assert {:ok, payment} = Payments.initiate(order, %{
    gateway: :hubtel, method: :mtn_momo, phone: "+233241234567"
  })
  assert payment.status == :pending

  # 2. Simulate webhook callback (MoMo confirmed)
  webhook_payload = Jason.decode!(File.read!("test/support/fixtures/webhooks/hubtel_momo_success.json"))
  assert {:ok, _event} = Payments.handle_webhook(:hubtel, webhook_payload, "valid_signature")

  # 3. Verify order updated
  order = Ash.get!(Emakola.Orders.Order, order.id)
  assert order.payment_status == :paid
  assert order.status == :confirmed
end
```

### Concurrent Checkout (Last Item)
```elixir
test "two customers buying last item — one succeeds, one fails" do
  product = create_product_with_variant(inventory_quantity: 1)

  task1 = Task.async(fn -> Checkout.process(build_checkout(product)) end)
  task2 = Task.async(fn -> Checkout.process(build_checkout(product)) end)

  results = Task.await_many([task1, task2])
  successes = Enum.count(results, &match?({:ok, _}, &1))
  failures = Enum.count(results, &match?({:error, :out_of_stock}, &1))

  assert successes == 1
  assert failures == 1
end
```

### Currency: No Floating Point Errors
```elixir
test "money calculations never use floats" do
  items = [
    %{price: 9999, quantity: 3},   # GH₵ 99.99 × 3
    %{price: 1550, quantity: 2}    # GH₵ 15.50 × 2
  ]

  total = Enum.reduce(items, 0, fn item, acc ->
    acc + (item.price * item.quantity)
  end)

  assert total == 33097  # GH₵ 330.97 in pesewas — exact, no float drift
  assert is_integer(total)
end
```

## Running Tests

```bash
mix test                           # All tests
mix test --cover                   # With coverage report
mix test test/emakola/             # Domain layer only
mix test test/emakola_web/         # Web layer only
mix test --only integration        # Integration tests
mix test --only payment            # Payment tests
mix test --stale                   # Only tests affected by changes
MIX_ENV=test mix ecto.reset        # Reset test database
```

## CI Pipeline Checks

1. `mix format --check-formatted`
2. `mix compile --warnings-as-errors`
3. `mix credo --strict`
4. `mix sobelow --config`
5. `mix test --cover --warnings-as-errors`
6. Coverage threshold: 90% minimum
