defmodule Emakola.Factory do
  @moduledoc "Test factories for Emakola resources."

  def unique_email, do: "user_#{System.unique_integer([:positive])}@example.com"

  def build_user(attrs \\ %{}) do
    default = %{
      email: unique_email(),
      hashed_password: Bcrypt.hash_pwd_salt("Password123!"),
      name: "Test User"
    }

    Map.merge(default, Map.new(attrs))
  end

  def create_user!(attrs \\ %{}) do
    Emakola.Accounts.User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: attrs[:email] || unique_email(),
      password: attrs[:password] || "Password123!",
      password_confirmation: attrs[:password_confirmation] || attrs[:password] || "Password123!"
    })
    |> Ash.create!()
  end

  def build_organisation(attrs \\ %{}) do
    default = %{
      name: "Test Org #{System.unique_integer([:positive])}"
    }

    Map.merge(default, Map.new(attrs))
  end

  def create_organisation!(attrs \\ %{}) do
    params = build_organisation(attrs)

    Emakola.Accounts.Organisation
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_membership!(user, org, role \\ :member) do
    Emakola.Accounts.Membership
    |> Ash.Changeset.for_create(:create, %{role: role, user_id: user.id, organisation_id: org.id})
    |> Ash.create!()
  end

  # ── Merchant (ecommerce auth) ──────────────────────────────────

  def create_merchant!(attrs \\ %{}) do
    Emakola.Accounts.Merchant
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: attrs[:email] || unique_email(),
      password: attrs[:password] || "Password123!",
      password_confirmation: attrs[:password_confirmation] || attrs[:password] || "Password123!"
    })
    |> Ash.create!()
  end

  # ── Store ─────────────────────────────────────────────────────

  @store_create_fields ~w(name slug currency)a

  def create_store!(attrs \\ %{}) do
    default = %{
      name: "Test Store #{System.unique_integer([:positive])}",
      slug: "test-store-#{System.unique_integer([:positive])}",
      currency: "GHS"
    }

    params = Map.merge(default, Map.new(attrs))
    {create_params, settings_params} = Map.split(params, @store_create_fields)

    store =
      Emakola.Accounts.Store
      |> Ash.Changeset.for_create(:create, create_params)
      |> Ash.create!()

    if settings_params == %{} do
      store
    else
      store
      |> Ash.Changeset.for_update(:update_settings, settings_params)
      |> Ash.update!()
    end
  end

  def create_store_membership!(merchant, store, role \\ :staff) do
    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      role: role,
      merchant_id: merchant.id,
      store_id: store.id
    })
    |> Ash.create!()
  end

  # ── Catalog ───────────────────────────────────────────────────

  def create_category!(store, attrs \\ %{}) do
    default = %{
      name: "Test Category #{System.unique_integer([:positive])}",
      store_id: store.id
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Catalog.Category
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_product!(store, attrs \\ %{}) do
    attrs = Map.new(attrs)
    {status, attrs} = Map.pop(attrs, :status)

    default = %{
      title: "Test Product #{System.unique_integer([:positive])}",
      store_id: store.id
    }

    params = Map.merge(default, attrs)

    product =
      Emakola.Catalog.Product
      |> Ash.Changeset.for_create(:create, params)
      |> Ash.create!()

    if status do
      product
      |> Ash.Changeset.for_update(:update, %{})
      |> Ash.Changeset.force_change_attribute(:status, status)
      |> Ash.update!()
    else
      product
    end
  end

  def create_option_type!(product, store, attrs \\ %{}) do
    default = %{
      name: "Option #{System.unique_integer([:positive])}",
      product_id: product.id,
      store_id: store.id
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Catalog.OptionType
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_option_value!(option_type, store, attrs \\ %{}) do
    default = %{
      value: "Value #{System.unique_integer([:positive])}",
      option_type_id: option_type.id,
      store_id: store.id
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Catalog.OptionValue
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_variant!(product, store, attrs \\ %{}) do
    default = %{
      price: 5000,
      product_id: product.id,
      store_id: store.id
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Catalog.Variant
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_variant_option_value!(variant, option_value, store) do
    Emakola.Catalog.VariantOptionValue
    |> Ash.Changeset.for_create(:create, %{
      variant_id: variant.id,
      option_value_id: option_value.id,
      store_id: store.id
    })
    |> Ash.create!()
  end

  # ── Billing (legacy from FounderPad) ──────────────────────────

  def create_plan!(attrs \\ %{}) do
    default = %{
      name: "Test Plan #{System.unique_integer([:positive])}",
      slug: "test-plan-#{System.unique_integer([:positive])}",
      stripe_product_id: "prod_test_#{System.unique_integer([:positive])}",
      stripe_price_id: "price_test_#{System.unique_integer([:positive])}",
      price_cents: 2900,
      interval: :monthly,
      features: ["Feature A"],
      max_seats: 5,
      max_agents: 10,
      max_api_calls_per_month: 10_000
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Billing.Plan
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_agent!(org, attrs \\ %{}) do
    default = %{
      name: "Test Agent #{System.unique_integer([:positive])}",
      system_prompt: "You are a helpful test assistant.",
      model: "claude-sonnet-4-20250514",
      provider: :anthropic,
      organisation_id: org.id
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.AI.Agent
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_invoice!(org, attrs \\ %{}) do
    default = %{
      invoice_number: "INV-#{System.unique_integer([:positive])}",
      amount_cents: 14900,
      status: :paid,
      period_start: Date.utc_today() |> Date.beginning_of_month(),
      period_end: Date.utc_today() |> Date.end_of_month(),
      organisation_id: org.id
    }

    Emakola.Billing.Invoice
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!()
  end

  def create_conversation_chain! do
    org = create_organisation!()
    user = create_user!()
    agent = create_agent!(org)

    {:ok, conversation} =
      Emakola.AI.Conversation
      |> Ash.Changeset.for_create(:create, %{
        title: "Test Conversation",
        agent_id: agent.id,
        organisation_id: org.id,
        user_id: user.id
      })
      |> Ash.create()

    {org, user, agent, conversation}
  end

  # ── Merchant + Store (convenience) ─────────────────────────

  def create_merchant_with_store!(store_attrs \\ %{}) do
    merchant = create_merchant!()
    store = create_store!(store_attrs)

    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      merchant_id: merchant.id,
      store_id: store.id,
      role: :owner
    })
    |> Ash.create!()

    {merchant, store}
  end

  # ── Images ──────────────────────────────────────────────────

  def create_image!(product, store, attrs \\ %{}) do
    attrs = Map.new(attrs)
    {position, attrs} = Map.pop(attrs, :position)

    default = %{
      url: "https://s3.example.com/test/#{System.unique_integer([:positive])}.jpg",
      content_type: "image/jpeg",
      file_size_bytes: 500_000,
      product_id: product.id,
      store_id: store.id
    }

    params = Map.merge(default, attrs)

    image =
      Emakola.Catalog.Image
      |> Ash.Changeset.for_create(:create, params)
      |> Ash.create!()

    if position do
      image
      |> Ash.Changeset.for_update(:update, %{position: position})
      |> Ash.update!()
    else
      image
    end
  end

  # ── Customers ────────────────────────────────────────────────────

  def create_customer!(store, attrs \\ %{}) do
    default = %{
      email: unique_email(),
      name: "Test Customer #{System.unique_integer([:positive])}",
      store_id: store.id
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Customers.Customer
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  # ── Orders ───────────────────────────────────────────────────────

  def create_order!(store, attrs \\ %{}) do
    attrs = Map.new(attrs)
    {status, attrs} = Map.pop(attrs, :status)

    default = %{
      store_id: store.id
    }

    params = Map.merge(default, attrs)

    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, params)
      |> Ash.create!()

    if status do
      order
      |> Ash.Changeset.for_update(:update, %{})
      |> Ash.Changeset.force_change_attribute(:status, status)
      |> Ash.update!()
    else
      order
    end
  end

  # ── Payments ──────────────────────────────────────────────────────

  def create_payment!(store, attrs \\ %{}) do
    default = %{
      store_id: store.id,
      amount: 500_000,
      currency: "GHS",
      gateway: :paystack,
      gateway_reference: "PAY-test-#{System.unique_integer([:positive])}-ref",
      customer_email: "customer@example.com"
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Payments.Payment
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  # ── Delivery Zones ────────────────────────────────────────────────

  def create_delivery_zone!(store, attrs \\ %{}) do
    default = %{
      name: "Zone #{System.unique_integer([:positive])}",
      fee: 1500,
      estimated_days: 1,
      store_id: store.id
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Shipping.DeliveryZone
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  # ── Addresses ──────────────────────────────────────────────────────

  def create_address!(customer, store, attrs \\ %{}) do
    default = %{
      line_1: "#{System.unique_integer([:positive])} Test Street",
      city: "Accra",
      customer_id: customer.id,
      store_id: store.id
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Customers.Address
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  # ── Customer Notes ─────────────────────────────────────────────────

  def create_customer_note!(customer, store, attrs \\ %{}) do
    default = %{
      content: "Test note #{System.unique_integer([:positive])}",
      customer_id: customer.id,
      store_id: store.id
    }

    params = Map.merge(default, Map.new(attrs))

    Emakola.Customers.CustomerNote
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  # ── Content (Blog Posts, Pages) ──────────────────────────────────

  def create_post!(store, attrs \\ %{}) do
    attrs = Map.new(attrs)

    default = %{
      store_id: store.id,
      type: :blog_post,
      title: "Test Post #{System.unique_integer([:positive])}",
      body: "This is test content for the blog post.",
      excerpt: "Test excerpt"
    }

    Emakola.Content.Post
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!()
  end

  def create_platform_post!(attrs \\ %{}) do
    attrs = Map.new(attrs)

    default = %{
      store_id: nil,
      type: :blog_post,
      title: "Platform Post #{System.unique_integer([:positive])}",
      body: "Platform blog content.",
      excerpt: "Platform excerpt"
    }

    Emakola.Content.Post
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!()
  end
end
