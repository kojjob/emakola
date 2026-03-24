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
IO.puts("  Plans: Free, Starter, Growth, Enterprise")
IO.puts("  Feature flags: #{length(feature_flags)} configured")
IO.puts("")
