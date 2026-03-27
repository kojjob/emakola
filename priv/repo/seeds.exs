# Emakola Seed Data
#
# Run with: mix run priv/repo/seeds.exs
# Reset and seed: mix ecto.reset && mix run priv/repo/seeds.exs
#
# Creates a realistic Ghanaian ecommerce dataset:
#   - 2 merchants with stores (Kente Kingdom, Accra Fresh Market)
#   - Categories, products with variants, images
#   - Customers, orders at various stages, payments
#   - Delivery zones, feature flags, billing plans

alias Emakola.Repo

IO.puts("🌱 Seeding Emakola database...")

# =============================================================================
# HELPERS
# =============================================================================

defmodule Seeds do
  @doc "Create via Ash changeset, raise on failure"
  def create!(resource, action, params, opts \\ []) do
    resource
    |> Ash.Changeset.for_create(action, params, opts)
    |> Ash.create!()
  end

  def update!(record, action, params, opts \\ []) do
    record
    |> Ash.Changeset.for_update(action, params, opts)
    |> Ash.update!()
  end

  def unique_email(prefix), do: "#{prefix}+#{System.unique_integer([:positive])}@emakola.com"
end

# =============================================================================
# 1. BILLING PLANS
# =============================================================================

IO.puts("  Creating billing plans...")

free_plan =
  Seeds.create!(Emakola.Billing.Plan, :create, %{
    name: "Free",
    slug: "free",
    stripe_product_id: "prod_free_seed",
    stripe_price_id: "price_free_seed",
    price_cents: 0,
    interval: :monthly,
    features: ["1 store", "50 products", "Basic analytics", "Email support"],
    max_seats: 1,
    max_agents: 1,
    max_api_calls_per_month: 500,
    sort_order: 0
  })

starter_plan =
  Seeds.create!(Emakola.Billing.Plan, :create, %{
    name: "Starter",
    slug: "starter",
    stripe_product_id: "prod_starter_seed",
    stripe_price_id: "price_starter_seed",
    price_cents: 4900,
    interval: :monthly,
    features: [
      "1 store",
      "500 products",
      "Advanced analytics",
      "WhatsApp notifications",
      "Custom domain",
      "Priority support"
    ],
    max_seats: 3,
    max_agents: 5,
    max_api_calls_per_month: 5000,
    sort_order: 1
  })

growth_plan =
  Seeds.create!(Emakola.Billing.Plan, :create, %{
    name: "Growth",
    slug: "growth",
    stripe_product_id: "prod_growth_seed",
    stripe_price_id: "price_growth_seed",
    price_cents: 14900,
    interval: :monthly,
    features: [
      "3 stores",
      "Unlimited products",
      "Full analytics suite",
      "WhatsApp + SMS notifications",
      "Custom domain",
      "Rider dispatch",
      "API access",
      "Dedicated support"
    ],
    max_seats: 10,
    max_agents: 20,
    max_api_calls_per_month: 50_000,
    sort_order: 2
  })

_enterprise_plan =
  Seeds.create!(Emakola.Billing.Plan, :create, %{
    name: "Enterprise",
    slug: "enterprise",
    stripe_product_id: "prod_enterprise_seed",
    stripe_price_id: "price_enterprise_seed",
    price_cents: 49900,
    interval: :monthly,
    features: [
      "Unlimited stores",
      "Unlimited products",
      "White-label storefront",
      "All notification channels",
      "Multi-currency",
      "Dedicated account manager",
      "SLA guarantee",
      "Custom integrations"
    ],
    max_seats: 50,
    max_agents: 100,
    max_api_calls_per_month: 500_000,
    sort_order: 3
  })

# =============================================================================
# 2. FEATURE FLAGS
# =============================================================================

IO.puts("  Creating feature flags...")

feature_flags = [
  %{
    key: "whatsapp_ordering",
    name: "WhatsApp Ordering",
    description: "Allow customers to place orders via WhatsApp",
    enabled: true
  },
  %{
    key: "rider_dispatch",
    name: "Rider Dispatch",
    description: "Enable motorbike rider dispatch for deliveries",
    enabled: false,
    required_plan: "growth"
  },
  %{
    key: "multi_currency",
    name: "Multi-Currency",
    description: "Support for multiple currencies (GHS, NGN, USD)",
    enabled: false,
    required_plan: "enterprise"
  },
  %{
    key: "sms_notifications",
    name: "SMS Notifications",
    description: "Send SMS order updates to customers",
    enabled: true
  },
  %{
    key: "email_receipts",
    name: "Email Receipts",
    description: "Send email receipts after purchase",
    enabled: true
  },
  %{
    key: "storefront_v2",
    name: "Storefront V2",
    description: "New high-fidelity storefront design",
    enabled: true
  },
  %{
    key: "product_reviews",
    name: "Product Reviews",
    description: "Allow customers to leave product reviews",
    enabled: false
  },
  %{
    key: "inventory_alerts",
    name: "Inventory Alerts",
    description: "Low stock alerts via WhatsApp/SMS",
    enabled: true
  },
  %{
    key: "analytics_dashboard",
    name: "Analytics Dashboard",
    description: "Enhanced analytics with charts and exports",
    enabled: true,
    required_plan: "starter"
  },
  %{
    key: "custom_domain",
    name: "Custom Domain",
    description: "Use a custom domain for the storefront",
    enabled: false,
    required_plan: "starter"
  }
]

for flag <- feature_flags do
  Seeds.create!(Emakola.FeatureFlags.FeatureFlag, :create, flag)
end

# =============================================================================
# 3. MERCHANT 1: KENTE KINGDOM (Fashion & Textiles)
# =============================================================================

IO.puts("  Creating Merchant 1: Kente Kingdom...")

# -- Merchant account --
merchant1 =
  Seeds.create!(Emakola.Accounts.Merchant, :register_with_password, %{
    email: "kwame@kentekingdom.com",
    password: "Password123!",
    password_confirmation: "Password123!"
  })

merchant1 =
  Seeds.update!(merchant1, :update_profile, %{
    name: "Kwame Asante",
    phone: "+233244123456",
    business_name: "Kente Kingdom"
  })

# -- Organisation --
org1 =
  Seeds.create!(Emakola.Accounts.Organisation, :create, %{
    name: "Kente Kingdom Ltd",
    billing_email: "billing@kentekingdom.com"
  })

# -- User for org membership (merchant's user account) --
user1 =
  Seeds.create!(Emakola.Accounts.User, :register_with_password, %{
    email: "kwame@kentekingdom.com",
    password: "Password123!",
    password_confirmation: "Password123!"
  })

Seeds.create!(Emakola.Accounts.Membership, :create, %{
  user_id: user1.id,
  organisation_id: org1.id,
  role: :owner
})

# -- Store --
store1 =
  Seeds.create!(Emakola.Accounts.Store, :create, %{
    name: "Kente Kingdom",
    slug: "kente-kingdom",
    currency: "GHS"
  })

store1 =
  Seeds.update!(store1, :update_settings, %{
    description:
      "Premium handwoven Kente cloth and modern African fashion from Bonwire, Ashanti Region. Every piece tells a story of heritage and craftsmanship.",
    contact_email: "hello@kentekingdom.com",
    contact_phone: "+233244123456",
    whatsapp_number: "+233244123456",
    city: "Kumasi",
    region: "Ashanti"
  })

Seeds.create!(Emakola.Accounts.StoreMembership, :create, %{
  merchant_id: merchant1.id,
  store_id: store1.id,
  role: :owner
})

# -- Subscription --
Seeds.create!(Emakola.Billing.Subscription, :create, %{
  stripe_subscription_id: "sub_kente_seed_001",
  stripe_customer_id: "cus_kente_seed_001",
  status: :active,
  current_period_start: DateTime.utc_now() |> DateTime.add(-15, :day),
  current_period_end: DateTime.utc_now() |> DateTime.add(15, :day),
  organisation_id: org1.id,
  plan_id: growth_plan.id
})

# -- Categories --
IO.puts("    Categories...")

cat_kente =
  Seeds.create!(Emakola.Catalog.Category, :create, %{
    name: "Kente Cloth",
    store_id: store1.id,
    description: "Traditional handwoven Kente cloth in authentic Ashanti patterns",
    position: 0
  })

cat_fashion =
  Seeds.create!(Emakola.Catalog.Category, :create, %{
    name: "Modern Fashion",
    store_id: store1.id,
    description: "Contemporary African fashion with Kente accents",
    position: 1
  })

cat_accessories =
  Seeds.create!(Emakola.Catalog.Category, :create, %{
    name: "Accessories",
    store_id: store1.id,
    description: "Handcrafted bags, jewelry, and accessories",
    position: 2
  })

_cat_mens =
  Seeds.create!(Emakola.Catalog.Category, :create, %{
    name: "Men's Collection",
    store_id: store1.id,
    description: "Traditional and modern menswear",
    parent_id: cat_fashion.id,
    position: 0
  })

_cat_womens =
  Seeds.create!(Emakola.Catalog.Category, :create, %{
    name: "Women's Collection",
    store_id: store1.id,
    description: "Dresses, skirts, and blouses with Kente motifs",
    parent_id: cat_fashion.id,
    position: 1
  })

cat_bags =
  Seeds.create!(Emakola.Catalog.Category, :create, %{
    name: "Bags & Clutches",
    store_id: store1.id,
    description: "Handmade bags with Kente fabric accents",
    parent_id: cat_accessories.id,
    position: 0
  })

# -- Products --
IO.puts("    Products & Variants...")

# Product 1: Royal Kente Cloth
p1 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Royal Adweneasa Kente Cloth",
    store_id: store1.id,
    category_id: cat_kente.id,
    description:
      "A masterpiece of Ashanti weaving. The Adweneasa pattern — meaning 'my ideas are exhausted' — represents the highest level of creativity in Kente design. Handwoven by master weavers in Bonwire using premium silk and cotton threads. Each piece takes 3-4 weeks to complete.",
    tags: ["kente", "handwoven", "premium", "ashanti", "bonwire", "silk"],
    seo_title: "Royal Adweneasa Kente Cloth | Authentic Ashanti Weaving",
    seo_description:
      "Premium handwoven Adweneasa Kente cloth from Bonwire, Ashanti Region. Authentic master weaver craftsmanship."
  })

# Size option for kente
size_type_p1 =
  Seeds.create!(Emakola.Catalog.OptionType, :create, %{
    name: "Size",
    product_id: p1.id,
    store_id: store1.id,
    position: 0
  })

size_6yard =
  Seeds.create!(Emakola.Catalog.OptionValue, :create, %{
    value: "6 Yards",
    option_type_id: size_type_p1.id,
    store_id: store1.id,
    position: 0
  })

size_12yard =
  Seeds.create!(Emakola.Catalog.OptionValue, :create, %{
    value: "12 Yards",
    option_type_id: size_type_p1.id,
    store_id: store1.id,
    position: 1
  })

v1a =
  Seeds.create!(Emakola.Catalog.Variant, :create, %{
    product_id: p1.id,
    store_id: store1.id,
    price: 85_000,
    compare_at_price: 95_000,
    sku: "KK-ADW-6YD",
    stock_quantity: 8,
    weight_grams: 800,
    position: 0
  })

Seeds.create!(Emakola.Catalog.VariantOptionValue, :create, %{
  variant_id: v1a.id,
  option_value_id: size_6yard.id,
  store_id: store1.id
})

v1b =
  Seeds.create!(Emakola.Catalog.Variant, :create, %{
    product_id: p1.id,
    store_id: store1.id,
    price: 150_000,
    compare_at_price: 170_000,
    sku: "KK-ADW-12YD",
    stock_quantity: 4,
    weight_grams: 1600,
    position: 1
  })

Seeds.create!(Emakola.Catalog.VariantOptionValue, :create, %{
  variant_id: v1b.id,
  option_value_id: size_12yard.id,
  store_id: store1.id
})

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: p1.id,
  store_id: store1.id,
  url: "/images/seed/kente-kingdom/kente-adweneasa-1.jpg",
  alt_text: "Royal Adweneasa Kente cloth in gold and green",
  content_type: "image/jpeg",
  file_size_bytes: 450_000
})

p1 = Seeds.update!(p1, :activate, %{})

# Product 2: Ewe Kente Stole
p2 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Ewe Kente Graduation Stole",
    store_id: store1.id,
    category_id: cat_kente.id,
    description:
      "Celebrate your achievement with an authentic Ewe Kente stole. Woven in the Volta Region with vibrant patterns symbolizing wisdom and success. Perfect for graduation ceremonies.",
    tags: ["kente", "graduation", "ewe", "stole", "ceremony"]
  })

v2 =
  Seeds.create!(Emakola.Catalog.Variant, :create, %{
    product_id: p2.id,
    store_id: store1.id,
    price: 25_000,
    sku: "KK-EWE-STOLE",
    stock_quantity: 35,
    weight_grams: 200
  })

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: p2.id,
  store_id: store1.id,
  url: "/images/seed/kente-kingdom/kente-stole-1.jpg",
  alt_text: "Ewe Kente graduation stole in multicolor",
  content_type: "image/jpeg",
  file_size_bytes: 320_000
})

p2 = Seeds.update!(p2, :activate, %{})

# Product 3: Ankara-Kente Fusion Dress
p3 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Ankara-Kente Fusion Midi Dress",
    store_id: store1.id,
    category_id: cat_fashion.id,
    description:
      "A stunning blend of Ankara prints and Kente strips. This midi dress features a fitted bodice with Kente-accented sleeves and hem. Made-to-measure for the perfect fit.",
    tags: ["ankara", "kente", "fusion", "dress", "women", "modern"]
  })

dress_size =
  Seeds.create!(Emakola.Catalog.OptionType, :create, %{
    name: "Size",
    product_id: p3.id,
    store_id: store1.id
  })

fusion_variants =
  for {size, pos} <- [{"S", 0}, {"M", 1}, {"L", 2}, {"XL", 3}] do
    ov =
      Seeds.create!(Emakola.Catalog.OptionValue, :create, %{
        value: size,
        option_type_id: dress_size.id,
        store_id: store1.id,
        position: pos
      })

    v =
      Seeds.create!(Emakola.Catalog.Variant, :create, %{
        product_id: p3.id,
        store_id: store1.id,
        price: 45_000,
        sku: "KK-FUSION-#{size}",
        stock_quantity: 12,
        weight_grams: 350,
        position: pos
      })

    Seeds.create!(Emakola.Catalog.VariantOptionValue, :create, %{
      variant_id: v.id,
      option_value_id: ov.id,
      store_id: store1.id
    })

    v
  end

fusion_m = Enum.at(fusion_variants, 1)

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: p3.id,
  store_id: store1.id,
  url: "/images/seed/kente-kingdom/fusion-dress-1.jpg",
  alt_text: "Ankara-Kente fusion midi dress",
  content_type: "image/jpeg",
  file_size_bytes: 380_000
})

p3 = Seeds.update!(p3, :activate, %{})

# Product 4: Kente Clutch Bag
p4 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Handwoven Kente Clutch Bag",
    store_id: store1.id,
    category_id: cat_bags.id,
    description:
      "Elegant clutch bag lined with authentic Kente fabric. Features a gold clasp and detachable chain strap. Perfect for weddings, funerals, and special occasions.",
    tags: ["clutch", "bag", "kente", "wedding", "accessories"]
  })

v4 =
  Seeds.create!(Emakola.Catalog.Variant, :create, %{
    product_id: p4.id,
    store_id: store1.id,
    price: 18_000,
    compare_at_price: 22_000,
    sku: "KK-CLUTCH-01",
    stock_quantity: 20,
    weight_grams: 250
  })

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: p4.id,
  store_id: store1.id,
  url: "/images/seed/kente-kingdom/kente-clutch-1.jpg",
  alt_text: "Kente clutch bag with gold clasp",
  content_type: "image/jpeg",
  file_size_bytes: 290_000
})

p4 = Seeds.update!(p4, :activate, %{})

# Product 5: Fugu Smock (Northern Ghana)
p5 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Authentic Dagomba Fugu Smock",
    store_id: store1.id,
    category_id: cat_fashion.id,
    description:
      "Traditional hand-woven smock from Tamale, Northern Region. The Fugu is worn during festivals, durbars, and important ceremonies. Made from locally grown cotton and dyed with natural indigo.",
    tags: ["fugu", "smock", "northern", "dagomba", "traditional", "men"]
  })

fugu_color =
  Seeds.create!(Emakola.Catalog.OptionType, :create, %{
    name: "Color",
    product_id: p5.id,
    store_id: store1.id
  })

fugu_variants =
  for {color, price, pos} <- [
        {"Indigo Blue", 35_000, 0},
        {"Natural White", 30_000, 1},
        {"Earth Brown", 32_000, 2}
      ] do
    ov =
      Seeds.create!(Emakola.Catalog.OptionValue, :create, %{
        value: color,
        option_type_id: fugu_color.id,
        store_id: store1.id,
        position: pos
      })

    v =
      Seeds.create!(Emakola.Catalog.Variant, :create, %{
        product_id: p5.id,
        store_id: store1.id,
        price: price,
        sku: "KK-FUGU-#{String.upcase(String.slice(color, 0..2))}",
        stock_quantity: 15,
        weight_grams: 600,
        position: pos
      })

    Seeds.create!(Emakola.Catalog.VariantOptionValue, :create, %{
      variant_id: v.id,
      option_value_id: ov.id,
      store_id: store1.id
    })

    v
  end

fugu_indigo = List.first(fugu_variants)

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: p5.id,
  store_id: store1.id,
  url: "/images/seed/kente-kingdom/fugu-smock-1.jpg",
  alt_text: "Dagomba Fugu smock in indigo blue",
  content_type: "image/jpeg",
  file_size_bytes: 410_000
})

p5 = Seeds.update!(p5, :activate, %{})

# Product 6: Draft product (not yet published)
_p6 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Kente Bow Tie Set",
    store_id: store1.id,
    category_id: cat_accessories.id,
    description: "Coming soon - matching bow tie and pocket square set in premium Kente silk.",
    tags: ["bow-tie", "pocket-square", "men", "wedding", "coming-soon"]
  })

# No variants yet - stays in draft

# -- Delivery Zones --
IO.puts("    Delivery zones...")

Seeds.create!(Emakola.Shipping.DeliveryZone, :create, %{
  name: "Kumasi Metro",
  fee: 1_500,
  estimated_days: 1,
  store_id: store1.id
})

Seeds.create!(Emakola.Shipping.DeliveryZone, :create, %{
  name: "Ashanti Region",
  fee: 3_000,
  estimated_days: 2,
  store_id: store1.id
})

Seeds.create!(Emakola.Shipping.DeliveryZone, :create, %{
  name: "Greater Accra",
  fee: 4_500,
  estimated_days: 2,
  store_id: store1.id
})

Seeds.create!(Emakola.Shipping.DeliveryZone, :create, %{
  name: "Northern Ghana",
  fee: 8_000,
  estimated_days: 4,
  store_id: store1.id
})

Seeds.create!(Emakola.Shipping.DeliveryZone, :create, %{
  name: "Nationwide (Other Regions)",
  fee: 6_000,
  estimated_days: 3,
  store_id: store1.id
})

# -- Customers --
IO.puts("    Customers...")

cust1 =
  Seeds.create!(Emakola.Customers.Customer, :create, %{
    email: "ama.mensah@gmail.com",
    name: "Ama Mensah",
    phone: "+233201234567",
    store_id: store1.id
  })

cust2 =
  Seeds.create!(Emakola.Customers.Customer, :create, %{
    email: "kofi.boateng@outlook.com",
    name: "Kofi Boateng",
    phone: "+233551234567",
    store_id: store1.id
  })

cust3 =
  Seeds.create!(Emakola.Customers.Customer, :create, %{
    email: "abena.osei@yahoo.com",
    name: "Abena Osei",
    phone: "+233271234567",
    store_id: store1.id
  })

cust4 =
  Seeds.create!(Emakola.Customers.Customer, :create, %{
    email: "yaw.frimpong@gmail.com",
    name: "Yaw Frimpong",
    phone: "+233241234567",
    store_id: store1.id
  })

cust5 =
  Seeds.create!(Emakola.Customers.Customer, :create, %{
    email: "efua.addo@gmail.com",
    name: "Efua Addo",
    phone: "+233501234567",
    store_id: store1.id
  })

# -- Orders --
IO.puts("    Orders & Payments...")

# Order 1: Delivered (Ama bought Royal Kente)
order1 =
  Emakola.Orders.CheckoutService.checkout!(
    store1.id,
    [
      %{variant_id: v1a.id, quantity: 1}
    ],
    customer_id: cust1.id,
    notes: "Please wrap in gift paper",
    delivery_fee: 4_500
  )

{:ok, order1} = order1

pay1 =
  Seeds.create!(Emakola.Payments.Payment, :create, %{
    store_id: store1.id,
    order_id: order1.id,
    amount: order1.total,
    currency: "GHS",
    gateway: :paystack,
    gateway_reference: "PSK_#{:crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower)}",
    customer_email: "ama.mensah@gmail.com"
  })

Seeds.update!(pay1, :mark_success, %{
  gateway_response: %{"status" => "success", "channel" => "mobile_money", "provider" => "mtn"}
})

Seeds.update!(order1, :confirm, %{})
order1 = Ash.get!(Emakola.Orders.Order, order1.id)
Seeds.update!(order1, :start_processing, %{})
order1 = Ash.get!(Emakola.Orders.Order, order1.id)
Seeds.update!(order1, :mark_shipped, %{})
order1 = Ash.get!(Emakola.Orders.Order, order1.id)
Seeds.update!(order1, :mark_delivered, %{})

# Order 2: Shipped (Kofi bought Fugu + Stole)
order2 =
  Emakola.Orders.CheckoutService.checkout!(
    store1.id,
    [
      %{variant_id: v2.id, quantity: 2},
      %{variant_id: fugu_indigo.id, quantity: 1}
    ],
    customer_id: cust2.id,
    delivery_fee: 3_000
  )

{:ok, order2} = order2

pay2 =
  Seeds.create!(Emakola.Payments.Payment, :create, %{
    store_id: store1.id,
    order_id: order2.id,
    amount: order2.total,
    currency: "GHS",
    gateway: :paystack,
    gateway_reference: "PSK_#{:crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower)}",
    customer_email: "kofi.boateng@outlook.com"
  })

Seeds.update!(pay2, :mark_success, %{
  gateway_response: %{
    "status" => "success",
    "channel" => "mobile_money",
    "provider" => "vodafone"
  }
})

Seeds.update!(order2, :confirm, %{})
order2 = Ash.get!(Emakola.Orders.Order, order2.id)
Seeds.update!(order2, :start_processing, %{})
order2 = Ash.get!(Emakola.Orders.Order, order2.id)
Seeds.update!(order2, :mark_shipped, %{})

# Order 3: Confirmed/Processing (Abena bought Fusion Dress)
order3 =
  Emakola.Orders.CheckoutService.checkout!(
    store1.id,
    [
      %{variant_id: fusion_m.id, quantity: 1},
      %{variant_id: v4.id, quantity: 1}
    ],
    customer_id: cust3.id,
    delivery_fee: 4_500
  )

{:ok, order3} = order3

pay3 =
  Seeds.create!(Emakola.Payments.Payment, :create, %{
    store_id: store1.id,
    order_id: order3.id,
    amount: order3.total,
    currency: "GHS",
    gateway: :hubtel,
    gateway_reference: "HBT_#{:crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower)}",
    customer_email: "abena.osei@yahoo.com"
  })

Seeds.update!(pay3, :mark_success, %{
  gateway_response: %{
    "status" => "success",
    "channel" => "mobile_money",
    "provider" => "airteltigo"
  }
})

Seeds.update!(order3, :confirm, %{})
order3 = Ash.get!(Emakola.Orders.Order, order3.id)
Seeds.update!(order3, :start_processing, %{})

# Order 4: Pending payment (Yaw's order)
order4 =
  Emakola.Orders.CheckoutService.checkout!(
    store1.id,
    [
      %{variant_id: v1b.id, quantity: 1}
    ],
    customer_id: cust4.id,
    notes: "For my wedding ceremony",
    delivery_fee: 1_500
  )

{:ok, order4} = order4

_pay4 =
  Seeds.create!(Emakola.Payments.Payment, :create, %{
    store_id: store1.id,
    order_id: order4.id,
    amount: order4.total,
    currency: "GHS",
    gateway: :paystack,
    gateway_reference: "PSK_#{:crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower)}",
    customer_email: "yaw.frimpong@gmail.com"
  })

# Payment stays pending (MoMo timeout)

# Order 5: Cancelled
order5 =
  Emakola.Orders.CheckoutService.checkout!(
    store1.id,
    [
      %{variant_id: v2.id, quantity: 3}
    ],
    customer_id: cust5.id,
    delivery_fee: 6_000
  )

{:ok, order5} = order5

Seeds.update!(order5, :cancel, %{})

# =============================================================================
# 4. MERCHANT 2: ACCRA FRESH MARKET (Food & Grocery)
# =============================================================================

IO.puts("  Creating Merchant 2: Accra Fresh Market...")

merchant2 =
  Seeds.create!(Emakola.Accounts.Merchant, :register_with_password, %{
    email: "adjoa@accrafresh.com",
    password: "Password123!",
    password_confirmation: "Password123!"
  })

merchant2 =
  Seeds.update!(merchant2, :update_profile, %{
    name: "Adjoa Turkson",
    phone: "+233302987654",
    business_name: "Accra Fresh Market"
  })

org2 =
  Seeds.create!(Emakola.Accounts.Organisation, :create, %{
    name: "Accra Fresh Market Co",
    billing_email: "billing@accrafresh.com"
  })

user2 =
  Seeds.create!(Emakola.Accounts.User, :register_with_password, %{
    email: "adjoa@accrafresh.com",
    password: "Password123!",
    password_confirmation: "Password123!"
  })

Seeds.create!(Emakola.Accounts.Membership, :create, %{
  user_id: user2.id,
  organisation_id: org2.id,
  role: :owner
})

store2 =
  Seeds.create!(Emakola.Accounts.Store, :create, %{
    name: "Accra Fresh Market",
    slug: "accra-fresh",
    currency: "GHS"
  })

store2 =
  Seeds.update!(store2, :update_settings, %{
    description:
      "Farm-fresh produce, spices, and Ghanaian groceries delivered to your door in Accra. From shito to groundnuts, we bring the market to you.",
    contact_email: "hello@accrafresh.com",
    contact_phone: "+233302987654",
    whatsapp_number: "+233302987654",
    city: "Accra",
    region: "Greater Accra"
  })

Seeds.create!(Emakola.Accounts.StoreMembership, :create, %{
  merchant_id: merchant2.id,
  store_id: store2.id,
  role: :owner
})

Seeds.create!(Emakola.Billing.Subscription, :create, %{
  stripe_subscription_id: "sub_accra_seed_001",
  stripe_customer_id: "cus_accra_seed_001",
  status: :active,
  current_period_start: DateTime.utc_now() |> DateTime.add(-10, :day),
  current_period_end: DateTime.utc_now() |> DateTime.add(20, :day),
  organisation_id: org2.id,
  plan_id: starter_plan.id
})

# -- Categories --
cat_spices =
  Seeds.create!(Emakola.Catalog.Category, :create, %{
    name: "Spices & Seasonings",
    store_id: store2.id,
    description: "Authentic Ghanaian spices, peppers, and seasonings",
    position: 0
  })

cat_grains =
  Seeds.create!(Emakola.Catalog.Category, :create, %{
    name: "Grains & Staples",
    store_id: store2.id,
    description: "Rice, millet, corn, and other staple grains",
    position: 1
  })

cat_sauces =
  Seeds.create!(Emakola.Catalog.Category, :create, %{
    name: "Sauces & Pastes",
    store_id: store2.id,
    description: "Ready-made sauces, shito, and cooking pastes",
    position: 2
  })

cat_snacks =
  Seeds.create!(Emakola.Catalog.Category, :create, %{
    name: "Snacks & Nuts",
    store_id: store2.id,
    description: "Roasted groundnuts, plantain chips, and more",
    position: 3
  })

# -- Products --
IO.puts("    Products & Variants...")

# Shito (Ghanaian hot pepper sauce)
ps1 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Homemade Shito (Hot Pepper Sauce)",
    store_id: store2.id,
    category_id: cat_sauces.id,
    description:
      "Award-winning homemade shito made with dried fish, shrimp, and scotch bonnet peppers. No preservatives, no artificial flavors. Made fresh weekly in small batches.",
    tags: ["shito", "pepper", "sauce", "homemade", "ghanaian"]
  })

shito_size =
  Seeds.create!(Emakola.Catalog.OptionType, :create, %{
    name: "Size",
    product_id: ps1.id,
    store_id: store2.id
  })

shito_variants =
  for {size, price, stock, pos} <- [
        {"250ml Jar", 2_500, 50, 0},
        {"500ml Jar", 4_500, 30, 1},
        {"1L Family Size", 8_000, 15, 2}
      ] do
    ov =
      Seeds.create!(Emakola.Catalog.OptionValue, :create, %{
        value: size,
        option_type_id: shito_size.id,
        store_id: store2.id,
        position: pos
      })

    v =
      Seeds.create!(Emakola.Catalog.Variant, :create, %{
        product_id: ps1.id,
        store_id: store2.id,
        price: price,
        sku: "AFM-SHITO-#{pos + 1}",
        stock_quantity: stock,
        weight_grams: (pos + 1) * 300,
        position: pos
      })

    Seeds.create!(Emakola.Catalog.VariantOptionValue, :create, %{
      variant_id: v.id,
      option_value_id: ov.id,
      store_id: store2.id
    })

    v
  end

shito_250 = Enum.at(shito_variants, 0)
shito_500 = Enum.at(shito_variants, 1)

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: ps1.id,
  store_id: store2.id,
  url: "/images/seed/accra-fresh/shito-1.jpg",
  alt_text: "Homemade shito in glass jar",
  content_type: "image/jpeg",
  file_size_bytes: 280_000
})

ps1 = Seeds.update!(ps1, :activate, %{})

# Jollof Rice Spice Mix
ps2 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Jollof Rice Spice Mix",
    store_id: store2.id,
    category_id: cat_spices.id,
    description:
      "The secret to perfect Ghana Jollof! Pre-mixed blend of tomato powder, onion, ginger, bay leaf, nutmeg, and our secret ingredient. Just add rice and protein.",
    tags: ["jollof", "spice", "rice", "seasoning", "cooking"]
  })

vs2 =
  Seeds.create!(Emakola.Catalog.Variant, :create, %{
    product_id: ps2.id,
    store_id: store2.id,
    price: 1_500,
    sku: "AFM-JOLLOF-MIX",
    stock_quantity: 100,
    weight_grams: 100
  })

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: ps2.id,
  store_id: store2.id,
  url: "/images/seed/accra-fresh/jollof-spice-1.jpg",
  alt_text: "Jollof rice spice mix packet",
  content_type: "image/jpeg",
  file_size_bytes: 200_000
})

ps2 = Seeds.update!(ps2, :activate, %{})

# Premium Basmati Rice
ps3 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Premium Basmati Rice",
    store_id: store2.id,
    category_id: cat_grains.id,
    description:
      "Long-grain basmati rice perfect for Jollof, fried rice, and plain rice. Imported from India, packed locally.",
    tags: ["rice", "basmati", "grain", "staple"]
  })

rice_size =
  Seeds.create!(Emakola.Catalog.OptionType, :create, %{
    name: "Weight",
    product_id: ps3.id,
    store_id: store2.id
  })

rice_variants =
  for {weight, price, stock, pos} <- [
        {"2kg", 3_500, 80, 0},
        {"5kg", 7_500, 40, 1},
        {"25kg Sack", 32_000, 10, 2}
      ] do
    ov =
      Seeds.create!(Emakola.Catalog.OptionValue, :create, %{
        value: weight,
        option_type_id: rice_size.id,
        store_id: store2.id,
        position: pos
      })

    v =
      Seeds.create!(Emakola.Catalog.Variant, :create, %{
        product_id: ps3.id,
        store_id: store2.id,
        price: price,
        sku: "AFM-RICE-#{weight}",
        stock_quantity: stock,
        weight_grams: if(pos == 2, do: 25_000, else: (pos + 1) * 2000),
        position: pos
      })

    Seeds.create!(Emakola.Catalog.VariantOptionValue, :create, %{
      variant_id: v.id,
      option_value_id: ov.id,
      store_id: store2.id
    })

    v
  end

rice_5kg = Enum.at(rice_variants, 1)

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: ps3.id,
  store_id: store2.id,
  url: "/images/seed/accra-fresh/rice-1.jpg",
  alt_text: "Premium basmati rice in burlap sack",
  content_type: "image/jpeg",
  file_size_bytes: 126_853
})

ps3 = Seeds.update!(ps3, :activate, %{})

# Roasted Groundnuts
ps4 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Nkatse (Roasted Groundnuts)",
    store_id: store2.id,
    category_id: cat_snacks.id,
    description:
      "Freshly roasted groundnuts (peanuts) from Tamale. Crunchy, salty, and addictive. Perfect with Kobi (ripe plantain) or as a standalone snack.",
    tags: ["groundnuts", "nkatse", "peanuts", "snack", "roasted"]
  })

vs4 =
  Seeds.create!(Emakola.Catalog.Variant, :create, %{
    product_id: ps4.id,
    store_id: store2.id,
    price: 1_200,
    sku: "AFM-NKATSE-500G",
    stock_quantity: 60,
    weight_grams: 500
  })

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: ps4.id,
  store_id: store2.id,
  url: "/images/seed/accra-fresh/groundnuts-1.jpg",
  alt_text: "Roasted groundnuts in a bowl",
  content_type: "image/jpeg",
  file_size_bytes: 63_399
})

ps4 = Seeds.update!(ps4, :activate, %{})

# Dawadawa (Locust Bean Seasoning)
ps5 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Dawadawa (Fermented Locust Beans)",
    store_id: store2.id,
    category_id: cat_spices.id,
    description:
      "Traditional fermented African locust beans. Essential seasoning for soups like groundnut soup, palm nut soup, and light soup. Adds umami depth.",
    tags: ["dawadawa", "locust-bean", "seasoning", "soup", "traditional"]
  })

vs5 =
  Seeds.create!(Emakola.Catalog.Variant, :create, %{
    product_id: ps5.id,
    store_id: store2.id,
    price: 800,
    sku: "AFM-DAWA-200G",
    stock_quantity: 45,
    weight_grams: 200
  })

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: ps5.id,
  store_id: store2.id,
  url: "/images/seed/accra-fresh/dawadawa-1.jpg",
  alt_text: "Dawadawa fermented locust beans in market bowl",
  content_type: "image/jpeg",
  file_size_bytes: 260_989
})

ps5 = Seeds.update!(ps5, :activate, %{})

# Plantain Chips
ps6 =
  Seeds.create!(Emakola.Catalog.Product, :create, %{
    title: "Kelewele-Style Plantain Chips",
    store_id: store2.id,
    category_id: cat_snacks.id,
    description:
      "Crispy plantain chips seasoned with ginger, chili, and cloves. Inspired by Accra's famous kelewele street food. Made with ripe plantain for that perfect sweet-spicy balance.",
    tags: ["plantain", "chips", "kelewele", "snack", "spicy"]
  })

vs6 =
  Seeds.create!(Emakola.Catalog.Variant, :create, %{
    product_id: ps6.id,
    store_id: store2.id,
    price: 1_500,
    sku: "AFM-CHIPS-150G",
    stock_quantity: 75,
    weight_grams: 150
  })

Seeds.create!(Emakola.Catalog.Image, :create, %{
  product_id: ps6.id,
  store_id: store2.id,
  url: "/images/seed/accra-fresh/plantain-chips-1.jpg",
  alt_text: "Kelewele-style plantain chips",
  content_type: "image/jpeg",
  file_size_bytes: 94_835
})

ps6 = Seeds.update!(ps6, :activate, %{})

# -- Delivery Zones (Accra) --
IO.puts("    Delivery zones...")

Seeds.create!(Emakola.Shipping.DeliveryZone, :create, %{
  name: "Accra Central (Osu, Cantonments, Airport Area)",
  fee: 1_000,
  estimated_days: 1,
  store_id: store2.id
})

Seeds.create!(Emakola.Shipping.DeliveryZone, :create, %{
  name: "Greater Accra (Tema, Madina, Kasoa)",
  fee: 2_000,
  estimated_days: 1,
  store_id: store2.id
})

Seeds.create!(Emakola.Shipping.DeliveryZone, :create, %{
  name: "Eastern Corridor (Koforidua, Akosombo)",
  fee: 5_000,
  estimated_days: 2,
  store_id: store2.id
})

# -- Customers --
IO.puts("    Customers...")

cust_a1 =
  Seeds.create!(Emakola.Customers.Customer, :create, %{
    email: "akosua.dufie@gmail.com",
    name: "Akosua Dufie",
    phone: "+233241111111",
    store_id: store2.id
  })

cust_a2 =
  Seeds.create!(Emakola.Customers.Customer, :create, %{
    email: "kweku.mensah@gmail.com",
    name: "Kweku Mensah",
    phone: "+233552222222",
    store_id: store2.id
  })

cust_a3 =
  Seeds.create!(Emakola.Customers.Customer, :create, %{
    email: "nana.aba@outlook.com",
    name: "Nana Aba",
    phone: "+233203333333",
    store_id: store2.id
  })

# -- Orders --
IO.puts("    Orders & Payments...")

# Order: Delivered (Akosua bought shito + rice)
ord_a1 =
  Emakola.Orders.CheckoutService.checkout!(
    store2.id,
    [
      %{variant_id: shito_500.id, quantity: 2},
      %{variant_id: rice_5kg.id, quantity: 1},
      %{variant_id: vs2.id, quantity: 3}
    ],
    customer_id: cust_a1.id,
    delivery_fee: 1_000
  )

{:ok, ord_a1} = ord_a1

pay_a1 =
  Seeds.create!(Emakola.Payments.Payment, :create, %{
    store_id: store2.id,
    order_id: ord_a1.id,
    amount: ord_a1.total,
    currency: "GHS",
    gateway: :paystack,
    gateway_reference: "PSK_#{:crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower)}",
    customer_email: "akosua.dufie@gmail.com"
  })

Seeds.update!(pay_a1, :mark_success, %{
  gateway_response: %{"status" => "success", "channel" => "mobile_money", "provider" => "mtn"}
})

Seeds.update!(ord_a1, :confirm, %{})
ord_a1 = Ash.get!(Emakola.Orders.Order, ord_a1.id)
Seeds.update!(ord_a1, :start_processing, %{})
ord_a1 = Ash.get!(Emakola.Orders.Order, ord_a1.id)
Seeds.update!(ord_a1, :mark_shipped, %{})
ord_a1 = Ash.get!(Emakola.Orders.Order, ord_a1.id)
Seeds.update!(ord_a1, :mark_delivered, %{})

# Order: Confirmed (Kweku bought snacks)
ord_a2 =
  Emakola.Orders.CheckoutService.checkout!(
    store2.id,
    [
      %{variant_id: vs4.id, quantity: 4},
      %{variant_id: vs6.id, quantity: 2},
      %{variant_id: shito_250.id, quantity: 1}
    ],
    customer_id: cust_a2.id,
    delivery_fee: 2_000
  )

{:ok, ord_a2} = ord_a2

pay_a2 =
  Seeds.create!(Emakola.Payments.Payment, :create, %{
    store_id: store2.id,
    order_id: ord_a2.id,
    amount: ord_a2.total,
    currency: "GHS",
    gateway: :hubtel,
    gateway_reference: "HBT_#{:crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower)}",
    customer_email: "kweku.mensah@gmail.com"
  })

Seeds.update!(pay_a2, :mark_success, %{
  gateway_response: %{
    "status" => "success",
    "channel" => "mobile_money",
    "provider" => "vodafone"
  }
})

Seeds.update!(ord_a2, :confirm, %{})

# Order: Pending (Nana Aba)
ord_a3 =
  Emakola.Orders.CheckoutService.checkout!(
    store2.id,
    [
      %{variant_id: vs5.id, quantity: 2},
      %{variant_id: vs2.id, quantity: 5}
    ],
    customer_id: cust_a3.id,
    delivery_fee: 1_000
  )

{:ok, _ord_a3} = ord_a3

# =============================================================================
# 5. NOTIFICATIONS (for merchant1)
# =============================================================================

IO.puts("  Creating notifications...")

Seeds.create!(Emakola.Notifications.Notification, :create, %{
  type: :system_announcement,
  title: "Welcome to Emakola!",
  body: "Your store is live. Start adding products and sharing your store link with customers.",
  user_id: user1.id
})

Seeds.create!(Emakola.Notifications.Notification, :create, %{
  type: :billing_updated,
  title: "Plan upgraded to Growth",
  body:
    "Your subscription has been upgraded to the Growth plan. You now have access to rider dispatch and API features.",
  user_id: user1.id
})

Seeds.create!(Emakola.Notifications.Notification, :create, %{
  type: :agent_completed,
  title: "New order received",
  body: "Ama Mensah placed an order for Royal Adweneasa Kente Cloth (GH₵ 850.00)",
  action_url: "/admin/orders",
  user_id: user1.id
})

# =============================================================================
# BLOG & CONTENT SEEDS
# =============================================================================

IO.puts("  Creating blog posts and recipes for Accra Fresh Market...")

# --- Blog Post 1: Jollof Rice Guide (Published) ---
blog1 = Seeds.create!(Emakola.Content.Post, :create, %{
  store_id: store2.id,
  author_id: merchant2.id,
  type: :blog_post,
  title: "The Ultimate Guide to Cooking Perfect Jollof Rice",
  body: """
  <p class="text-lg text-stone-600 mb-6">Jollof rice is more than just a dish — it's a cultural icon across West Africa. Whether you're Team Ghana or Team Nigeria, one thing is certain: the perfect jollof requires patience, quality ingredients, and the right technique.</p>

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">What Makes Ghanaian Jollof Special?</h2>
  <p>Ghanaian jollof stands apart with its smoky, slightly charred base — what we lovingly call "the bottom pot" or <em>kanzo</em>. This isn't a mistake; it's the signature. The rice is cooked entirely in a rich tomato base with aromatic spices until each grain absorbs every bit of flavor.</p>

  <img src="https://images.unsplash.com/photo-1604329760661-e71dc83f8f26?w=800&q=80" alt="A pot of golden Ghanaian jollof rice with tomato stew" class="w-full rounded-2xl my-8" />

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">The Essential Ingredients</h2>
  <ul class="list-disc pl-6 space-y-2 text-stone-700">
    <li><strong>Basmati or jasmine rice</strong> — long grain is key</li>
    <li><strong>Fresh tomatoes and tomato paste</strong> — the flavor foundation</li>
    <li><strong>Scotch bonnet pepper</strong> — for that authentic heat</li>
    <li><strong>Onions, garlic, and ginger</strong> — the holy trinity</li>
    <li><strong>Our Jollof Rice Spice Mix</strong> — the secret weapon</li>
    <li><strong>Bay leaves and dried thyme</strong> — aromatic depth</li>
  </ul>

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">Step-by-Step Method</h2>
  <ol class="list-decimal pl-6 space-y-3 text-stone-700">
    <li>Blend tomatoes, pepper, onions, garlic, and ginger into a smooth paste</li>
    <li>Fry the paste in vegetable oil on medium-high heat until the oil floats on top (about 30 minutes)</li>
    <li>Add tomato paste and our Jollof Spice Mix — stir well</li>
    <li>Pour in stock or water, add salt to taste, and bring to a boil</li>
    <li>Add washed rice, stir once, then reduce heat to the lowest setting</li>
    <li>Cover tightly with foil then the lid — do NOT open for 30 minutes</li>
    <li>Check after 30 minutes. If rice is cooked, fluff with a fork. The bottom should have a golden crust!</li>
  </ol>

  <div class="bg-amber-50 border border-amber-200 rounded-xl p-6 my-8">
    <p class="font-semibold text-amber-900 mb-2">Pro Tip: The Kanzo</p>
    <p class="text-amber-800">The smoky bottom layer is the best part. To get it right, use a thick-bottomed pot, keep the heat very low, and resist the urge to stir. When you hear a gentle crackling sound, it's forming.</p>
  </div>

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">Watch the Full Tutorial</h2>
  <div class="aspect-video rounded-2xl overflow-hidden my-6">
    <iframe width="100%" height="100%" src="https://www.youtube.com/embed/bsGbfpJRsE4" title="How to Cook Perfect Ghanaian Jollof Rice" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
  </div>

  <p class="mt-6">Ready to make your own? <a href="/s/accra-fresh/products/jollof-rice-spice-mix" class="text-amber-700 font-semibold hover:underline">Get our Jollof Rice Spice Mix</a> and <a href="/s/accra-fresh/products/premium-basmati-rice" class="text-amber-700 font-semibold hover:underline">Premium Basmati Rice</a> delivered to your door.</p>
  """,
  excerpt: "Master the art of Ghanaian jollof rice with our step-by-step guide. Learn the secrets to the perfect smoky kanzo bottom and rich tomato flavor.",
  featured_image_url: "https://images.unsplash.com/photo-1604329760661-e71dc83f8f26?w=1200&q=80",
  tags: ["recipes", "jollof", "cooking", "ghana"],
  seo_title: "How to Cook Perfect Ghanaian Jollof Rice | Accra Fresh Market",
  seo_description: "Step-by-step guide to making authentic Ghanaian jollof rice with smoky kanzo bottom. Includes video tutorial, ingredients list, and pro tips."
})

Seeds.update!(blog1, :publish, %{})

# --- Blog Post 2: Shito Guide (Published) ---
blog2 = Seeds.create!(Emakola.Content.Post, :create, %{
  store_id: store2.id,
  author_id: merchant2.id,
  type: :blog_post,
  title: "What is Shito? Ghana's Beloved Hot Pepper Sauce",
  body: """
  <p class="text-lg text-stone-600 mb-6">If you've ever eaten at a Ghanaian home or restaurant, you've probably seen a dark, oily, intensely flavored sauce sitting in a jar on the table. That's <strong>shito</strong> — and once you try it, you'll put it on everything.</p>

  <img src="https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800&q=80" alt="Dark chili sauce in a glass jar with a wooden spoon" class="w-full rounded-2xl my-8" />

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">What Exactly is Shito?</h2>
  <p>Shito (pronounced "SHEE-toh") is a Ghanaian hot pepper sauce made from a blend of dried chili peppers, dried fish or shrimp, onions, tomatoes, and ginger, all slow-cooked in oil until deeply caramelized. The result is a complex, umami-rich condiment that's spicy, smoky, and savory all at once.</p>

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">How to Use Shito</h2>
  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 my-6">
    <div class="bg-stone-50 rounded-xl p-5">
      <p class="font-semibold text-stone-900 mb-2">With Rice Dishes</p>
      <p class="text-sm text-stone-600">A spoonful alongside jollof, waakye, or plain rice transforms the meal.</p>
    </div>
    <div class="bg-stone-50 rounded-xl p-5">
      <p class="font-semibold text-stone-900 mb-2">With Bread</p>
      <p class="text-sm text-stone-600">Spread on toast or bread for a quick, flavorful snack.</p>
    </div>
    <div class="bg-stone-50 rounded-xl p-5">
      <p class="font-semibold text-stone-900 mb-2">As a Dip</p>
      <p class="text-sm text-stone-600">Perfect with kelewele, plantain chips, or fried yam.</p>
    </div>
    <div class="bg-stone-50 rounded-xl p-5">
      <p class="font-semibold text-stone-900 mb-2">In Stews</p>
      <p class="text-sm text-stone-600">Add a tablespoon to any stew for extra depth and heat.</p>
    </div>
  </div>

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">Our Homemade Shito</h2>
  <p>At Accra Fresh Market, our shito is made in small batches using a family recipe passed down through three generations. We use only the freshest dried shrimp from Elmina and locally-grown scotch bonnet peppers.</p>

  <p class="mt-4"><a href="/s/accra-fresh/products/homemade-shito-hot-pepper-sauce" class="inline-flex items-center gap-2 px-6 py-3 bg-amber-600 text-white rounded-xl font-semibold hover:bg-amber-700 transition-colors">Shop Our Shito</a></p>
  """,
  excerpt: "Discover Ghana's most iconic condiment. Learn what shito is, how it's made, and the many ways to enjoy this rich, spicy pepper sauce.",
  featured_image_url: "https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=1200&q=80",
  tags: ["shito", "ghanaian-food", "condiments", "spicy"],
  seo_title: "What is Shito? Guide to Ghana's Hot Pepper Sauce",
  seo_description: "Everything you need to know about shito — Ghana's beloved hot pepper sauce. History, how it's made, and delicious ways to use it."
})

Seeds.update!(blog2, :publish, %{})

# --- Blog Post 3: Healthy Snacking (Published) ---
blog3 = Seeds.create!(Emakola.Content.Post, :create, %{
  store_id: store2.id,
  author_id: merchant2.id,
  type: :blog_post,
  title: "5 Healthy Ghanaian Snacks You Should Be Eating",
  body: """
  <p class="text-lg text-stone-600 mb-6">Ghana has a rich tradition of snacking that goes far beyond the usual suspects. Many traditional Ghanaian snacks are naturally healthy, packed with protein, fiber, and essential nutrients. Here are five you should add to your rotation.</p>

  <img src="https://images.unsplash.com/photo-1536304929831-ee1ca9d44906?w=800&q=80" alt="Assorted nuts and dried fruits in market bowls" class="w-full rounded-2xl my-8" />

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">1. Roasted Groundnuts (Nkatse)</h2>
  <p>High in protein, healthy fats, and vitamin E. A handful of roasted groundnuts keeps you full for hours. Perfect with coconut or on their own.</p>

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">2. Plantain Chips (Kelewele-Style)</h2>
  <p>When made with ripe plantain and baked instead of fried, plantain chips are a fantastic source of potassium, fiber, and complex carbs. Our kelewele-style chips add ginger and spice for extra flavor without the guilt.</p>

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">3. Tiger Nuts</h2>
  <p>These aren't actually nuts — they're tubers! Rich in fiber, iron, and magnesium. In Ghana, we drink them as "atadwe milk" (tiger nut milk), a naturally sweet, dairy-free treat.</p>

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">4. Kulikuli (Groundnut Cake)</h2>
  <p>Made from groundnut paste pressed into shapes and fried, kulikuli is crunchy, savory, and surprisingly filling. A traditional snack that's stood the test of time.</p>

  <h2 class="text-2xl font-semibold text-stone-900 mt-8 mb-4">5. Dawadawa</h2>
  <p>Fermented locust beans might not sound like a snack, but many Ghanaians enjoy them as a savory nibble. They're rich in protein and probiotics — great for gut health.</p>

  <p class="mt-8"><a href="/s/accra-fresh/products" class="text-amber-700 font-semibold hover:underline">Browse all our healthy snacks at Accra Fresh Market</a></p>
  """,
  excerpt: "From roasted groundnuts to kelewele plantain chips, discover five traditional Ghanaian snacks that are naturally healthy and delicious.",
  featured_image_url: "https://images.unsplash.com/photo-1536304929831-ee1ca9d44906?w=1200&q=80",
  tags: ["snacks", "healthy-eating", "ghana", "nutrition"],
  seo_title: "5 Healthy Ghanaian Snacks | Accra Fresh Market Blog",
  seo_description: "Discover 5 traditional Ghanaian snacks that are naturally healthy. Groundnuts, plantain chips, tiger nuts, and more."
})

Seeds.update!(blog3, :publish, %{})

# --- Recipe 1: Jollof Rice (Published) ---
recipe1 = Seeds.create!(Emakola.Content.Post, :create, %{
  store_id: store2.id,
  author_id: merchant2.id,
  type: :recipe,
  title: "Classic Ghanaian Jollof Rice",
  body: """
  <p>The quintessential Ghanaian jollof rice — smoky, flavorful, and perfect for any occasion. This recipe uses our Jollof Rice Spice Mix for authentic flavor every time.</p>

  <img src="https://images.unsplash.com/photo-1604329760661-e71dc83f8f26?w=800&q=80" alt="Ghanaian jollof rice served with fried plantain" class="w-full rounded-2xl my-6" />

  <div class="aspect-video rounded-2xl overflow-hidden my-6">
    <iframe width="100%" height="100%" src="https://www.youtube.com/embed/bsGbfpJRsE4" title="Ghanaian Jollof Rice Recipe" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
  </div>
  """,
  excerpt: "The quintessential Ghanaian jollof rice with smoky kanzo bottom. Uses our Jollof Rice Spice Mix for authentic flavor.",
  featured_image_url: "https://images.unsplash.com/photo-1604329760661-e71dc83f8f26?w=1200&q=80",
  tags: ["jollof", "rice", "ghanaian", "main-dish"],
  seo_title: "Classic Ghanaian Jollof Rice Recipe | Accra Fresh Market",
  seo_description: "Authentic Ghanaian jollof rice recipe with smoky kanzo bottom. 45 minutes, serves 6. Includes video tutorial."
})

Seeds.update!(recipe1, :publish, %{})

Seeds.create!(Emakola.Content.RecipeMeta, :create, %{
  post_id: recipe1.id,
  prep_time: 15,
  cook_time: 45,
  servings: 6,
  difficulty: :medium,
  ingredients: [
    %{item: "Basmati rice", quantity: "3 cups"},
    %{item: "Fresh tomatoes", quantity: "6 large"},
    %{item: "Tomato paste", quantity: "3 tbsp"},
    %{item: "Scotch bonnet pepper", quantity: "2"},
    %{item: "Onions", quantity: "2 large"},
    %{item: "Garlic cloves", quantity: "4"},
    %{item: "Fresh ginger", quantity: "1 inch piece"},
    %{item: "Jollof Rice Spice Mix", quantity: "2 tbsp"},
    %{item: "Vegetable oil", quantity: "1/3 cup"},
    %{item: "Chicken stock", quantity: "4 cups"},
    %{item: "Bay leaves", quantity: "2"},
    %{item: "Salt", quantity: "to taste"}
  ],
  instructions: [
    "Wash rice in cold water until water runs clear. Soak for 30 minutes, then drain.",
    "Blend tomatoes, scotch bonnet, 1 onion, garlic, and ginger until smooth.",
    "Dice the remaining onion. Heat oil in a thick-bottomed pot over medium-high heat.",
    "Fry diced onion until translucent, about 3 minutes.",
    "Pour in the blended tomato mixture. Cook on medium-high heat, stirring occasionally, for 25-30 minutes until the oil rises to the top.",
    "Add tomato paste and Jollof Rice Spice Mix. Stir well and cook for 5 more minutes.",
    "Pour in chicken stock, add bay leaves, and season with salt. Bring to a rolling boil.",
    "Add the drained rice. Stir once to distribute evenly.",
    "Reduce heat to the lowest setting. Cover pot tightly with foil, then place the lid on top.",
    "Cook for 30 minutes without opening. Do not stir!",
    "After 30 minutes, check the rice. If cooked through, fluff gently with a fork.",
    "The golden crust at the bottom (kanzo) is the best part. Serve it up!"
  ]
})

# --- Recipe 2: Kelewele (Published) ---
recipe2 = Seeds.create!(Emakola.Content.Post, :create, %{
  store_id: store2.id,
  author_id: merchant2.id,
  type: :recipe,
  title: "Kelewele (Spiced Fried Plantain)",
  body: """
  <p>Kelewele is Ghana's most popular street food — ripe plantain cubed and fried with a spicy ginger-chili coating. Crunchy outside, sweet and soft inside. Perfect as a snack or side dish.</p>

  <img src="https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=800&q=80" alt="Fried plantain cubes on a plate" class="w-full rounded-2xl my-6" />

  <div class="bg-emerald-50 border border-emerald-200 rounded-xl p-6 my-6">
    <p class="font-semibold text-emerald-900 mb-2">Choosing the Right Plantain</p>
    <p class="text-emerald-800">Use ripe plantains with yellow-black skin. They should be soft but not mushy. Green plantains won't have the sweetness needed for kelewele.</p>
  </div>
  """,
  excerpt: "Ghana's favorite street food. Ripe plantain cubed and fried with spicy ginger and chili. Ready in 20 minutes.",
  featured_image_url: "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=1200&q=80",
  tags: ["kelewele", "plantain", "street-food", "snack"],
  seo_title: "Kelewele Recipe — Spiced Fried Plantain | Accra Fresh",
  seo_description: "Make authentic Ghanaian kelewele at home. Spiced fried plantain with ginger, chili, and cloves. Ready in 20 minutes."
})

Seeds.update!(recipe2, :publish, %{})

Seeds.create!(Emakola.Content.RecipeMeta, :create, %{
  post_id: recipe2.id,
  prep_time: 10,
  cook_time: 10,
  servings: 4,
  difficulty: :easy,
  ingredients: [
    %{item: "Ripe plantains", quantity: "4"},
    %{item: "Fresh ginger", quantity: "2 inch piece, grated"},
    %{item: "Scotch bonnet pepper", quantity: "1, minced"},
    %{item: "Ground cloves", quantity: "1/4 tsp"},
    %{item: "Salt", quantity: "1/2 tsp"},
    %{item: "Vegetable oil", quantity: "for frying"}
  ],
  instructions: [
    "Peel and cut plantains into 1-inch cubes.",
    "Mix grated ginger, minced scotch bonnet, ground cloves, and salt in a bowl.",
    "Add plantain cubes to the spice mix. Toss gently to coat all pieces.",
    "Let marinate for 10-15 minutes (longer = more flavor).",
    "Heat oil in a deep pan to 170C/340F.",
    "Fry plantain in batches until golden brown on all sides, about 3-4 minutes per batch.",
    "Drain on paper towels. Serve hot with groundnuts on the side."
  ]
})

# --- Page: About Us (Published) ---
about_page = Seeds.create!(Emakola.Content.Post, :create, %{
  store_id: store2.id,
  author_id: merchant2.id,
  type: :page,
  title: "About Accra Fresh Market",
  body: """
  <div class="space-y-8">
    <div>
      <h2 class="text-2xl font-semibold text-stone-900 mb-4">Our Story</h2>
      <p class="text-stone-600 leading-relaxed">Accra Fresh Market was born from a simple idea: every family in Accra deserves access to fresh, quality groceries without the hassle of navigating crowded markets in the heat. Founded in 2024 by Adjoa Mensah, we bridge the gap between local farmers, producers, and your kitchen table.</p>
    </div>

    <div>
      <h2 class="text-2xl font-semibold text-stone-900 mb-4">What We Stand For</h2>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
        <div class="text-center p-6 bg-stone-50 rounded-xl">
          <p class="text-3xl mb-3">&#127807;</p>
          <p class="font-semibold text-stone-900 mb-1">Fresh First</p>
          <p class="text-sm text-stone-600">Every product is sourced fresh from local farms and producers</p>
        </div>
        <div class="text-center p-6 bg-stone-50 rounded-xl">
          <p class="text-3xl mb-3">&#128666;</p>
          <p class="font-semibold text-stone-900 mb-1">Same Day Delivery</p>
          <p class="text-sm text-stone-600">Order by 2pm, get it delivered the same evening in Accra</p>
        </div>
        <div class="text-center p-6 bg-stone-50 rounded-xl">
          <p class="text-3xl mb-3">&#129309;</p>
          <p class="font-semibold text-stone-900 mb-1">Community First</p>
          <p class="text-sm text-stone-600">We support local farmers and artisan food producers</p>
        </div>
      </div>
    </div>
  </div>
  """,
  excerpt: "Fresh groceries delivered to your door in Accra. Learn about our mission to connect local farmers with families.",
  seo_title: "About Accra Fresh Market | Fresh Groceries in Accra",
  seo_description: "Accra Fresh Market delivers farm-fresh produce, spices, and Ghanaian groceries to your door. Same day delivery in Greater Accra."
})

Seeds.update!(about_page, :publish, %{})

# --- Media attachments for blog posts ---
Seeds.create!(Emakola.Content.MediaAttachment, :create, %{
  store_id: store2.id,
  post_id: blog1.id,
  type: :image,
  url: "https://images.unsplash.com/photo-1604329760661-e71dc83f8f26?w=1200&q=80",
  filename: "jollof-rice-hero.jpg",
  alt_text: "A pot of golden Ghanaian jollof rice",
  content_type: "image/jpeg",
  file_size: 185_000,
  position: 0
})

Seeds.create!(Emakola.Content.MediaAttachment, :create, %{
  store_id: store2.id,
  post_id: blog1.id,
  type: :video,
  url: "https://www.youtube.com/watch?v=bsGbfpJRsE4",
  filename: "jollof-rice-tutorial.mp4",
  alt_text: "How to cook perfect Ghanaian jollof rice video tutorial",
  caption: "Watch the full step-by-step jollof rice tutorial",
  content_type: "video/mp4",
  position: 1
})

Seeds.create!(Emakola.Content.MediaAttachment, :create, %{
  store_id: store2.id,
  post_id: blog2.id,
  type: :image,
  url: "https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=1200&q=80",
  filename: "shito-jar.jpg",
  alt_text: "Homemade Ghanaian shito in a glass jar",
  content_type: "image/jpeg",
  file_size: 142_000,
  position: 0
})

Seeds.create!(Emakola.Content.MediaAttachment, :create, %{
  store_id: store2.id,
  post_id: blog3.id,
  type: :image,
  url: "https://images.unsplash.com/photo-1536304929831-ee1ca9d44906?w=1200&q=80",
  filename: "healthy-snacks.jpg",
  alt_text: "Assorted Ghanaian nuts and snacks in market bowls",
  content_type: "image/jpeg",
  file_size: 167_000,
  position: 0
})

IO.puts("    3 blog posts, 2 recipes, 1 page, 4 media attachments created")

# =============================================================================
# DONE
# =============================================================================

IO.puts("")
IO.puts("Seeding complete!")
IO.puts("")
IO.puts("  Merchants:")
IO.puts("    kwame@kentekingdom.com / Password123!  (Kente Kingdom - Kumasi)")
IO.puts("    adjoa@accrafresh.com   / Password123!  (Accra Fresh Market)")
IO.puts("")
IO.puts("  Kente Kingdom: 6 products (5 active, 1 draft), 5 customers, 5 orders")
IO.puts("  Accra Fresh:   6 products (6 active), 3 customers, 3 orders")
IO.puts("  Content:       3 blog posts, 2 recipes, 1 about page (all published)")
IO.puts("  Plans: Free, Starter, Growth, Enterprise")
IO.puts("  Feature flags: #{length(feature_flags)} configured")
IO.puts("")
