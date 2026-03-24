defmodule Emakola.Repo.Migrations.AddMissingIndexes do
  @moduledoc """
  Adds missing database indexes for foreign keys and frequently queried columns.

  Audit findings:
  - Many FK columns lack individual indexes (only covered by composite unique indexes)
  - Several tables have no indexes beyond the primary key
  - Common query patterns (status filtering, customer history) need composite indexes

  Composite unique indexes with the FK as the FIRST column already serve as an
  efficient index for single-column lookups (e.g., products.(store_id, slug) covers
  store_id lookups). We only add individual indexes for FK columns that are NOT
  the leading column in any existing index.
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # ── Products ──────────────────────────────────────────────────
    # products.category_id — category filtering, not in any existing index
    create_if_not_exists index(:products, [:category_id],
                           name: "products_category_id_index",
                           concurrently: true
                         )

    # products.status — frequently filtered (draft, active, archived)
    create_if_not_exists index(:products, [:status],
                           name: "products_status_index",
                           concurrently: true
                         )

    # Composite for common query: products by store + status
    create_if_not_exists index(:products, [:store_id, :status],
                           name: "products_store_id_status_index",
                           concurrently: true
                         )

    # ── Variants ──────────────────────────────────────────────────
    # variants.product_id — loading variants for a product, not leading in any index
    create_if_not_exists index(:variants, [:product_id],
                           name: "variants_product_id_index",
                           concurrently: true
                         )

    # Composite for low stock queries: track_inventory + stock_quantity
    create_if_not_exists index(:variants, [:track_inventory, :stock_quantity],
                           name: "variants_inventory_tracking_index",
                           concurrently: true
                         )

    # ── Option Types ──────────────────────────────────────────────
    # option_types.store_id — not leading in unique index (product_id, name)
    create_if_not_exists index(:option_types, [:store_id],
                           name: "option_types_store_id_index",
                           concurrently: true
                         )

    # ── Option Values ─────────────────────────────────────────────
    # option_values.store_id — not leading in unique index (option_type_id, value)
    create_if_not_exists index(:option_values, [:store_id],
                           name: "option_values_store_id_index",
                           concurrently: true
                         )

    # ── Images ────────────────────────────────────────────────────
    # images has NO indexes at all — add FK indexes
    create_if_not_exists index(:images, [:product_id],
                           name: "images_product_id_index",
                           concurrently: true
                         )

    create_if_not_exists index(:images, [:store_id],
                           name: "images_store_id_index",
                           concurrently: true
                         )

    # Composite: images by product + position (common display order query)
    create_if_not_exists index(:images, [:product_id, :position],
                           name: "images_product_id_position_index",
                           concurrently: true
                         )

    # ── Categories ────────────────────────────────────────────────
    # categories.parent_id — tree queries (find children of a category)
    create_if_not_exists index(:categories, [:parent_id],
                           name: "categories_parent_id_index",
                           concurrently: true
                         )

    # ── Orders ────────────────────────────────────────────────────
    # orders.customer_id — customer order history lookups
    create_if_not_exists index(:orders, [:customer_id],
                           name: "orders_customer_id_index",
                           concurrently: true
                         )

    # orders.status — status filtering
    create_if_not_exists index(:orders, [:status],
                           name: "orders_status_index",
                           concurrently: true
                         )

    # Composite for common query: orders by store + status
    create_if_not_exists index(:orders, [:store_id, :status],
                           name: "orders_store_id_status_index",
                           concurrently: true
                         )

    # Composite for date-range queries: orders by store + inserted_at
    create_if_not_exists index(:orders, [:store_id, :inserted_at],
                           name: "orders_store_id_inserted_at_index",
                           concurrently: true
                         )

    # ── Line Items ────────────────────────────────────────────────
    # line_items has NO individual indexes — add FK indexes
    create_if_not_exists index(:line_items, [:order_id],
                           name: "line_items_order_id_index",
                           concurrently: true
                         )

    create_if_not_exists index(:line_items, [:store_id],
                           name: "line_items_store_id_index",
                           concurrently: true
                         )

    create_if_not_exists index(:line_items, [:variant_id],
                           name: "line_items_variant_id_index",
                           concurrently: true
                         )

    # ── Payments ──────────────────────────────────────────────────
    # payments.order_id — loading payments for an order
    create_if_not_exists index(:payments, [:order_id],
                           name: "payments_order_id_index",
                           concurrently: true
                         )

    # payments.store_id — store-scoped payment listing
    create_if_not_exists index(:payments, [:store_id],
                           name: "payments_store_id_index",
                           concurrently: true
                         )

    # payments.status — status filtering
    create_if_not_exists index(:payments, [:status],
                           name: "payments_status_index",
                           concurrently: true
                         )

    # ── Variant Option Values ─────────────────────────────────────
    # variant_option_values.store_id — tenant scoping
    create_if_not_exists index(:variant_option_values, [:store_id],
                           name: "variant_option_values_store_id_index",
                           concurrently: true
                         )

    # variant_option_values.option_value_id — reverse lookup
    create_if_not_exists index(:variant_option_values, [:option_value_id],
                           name: "variant_option_values_option_value_id_index",
                           concurrently: true
                         )

    # ── Store Memberships ─────────────────────────────────────────
    # store_memberships.store_id — find all members of a store
    # (composite unique index leads with merchant_id, not store_id)
    create_if_not_exists index(:store_memberships, [:store_id],
                           name: "store_memberships_store_id_index",
                           concurrently: true
                         )

    # ── Notifications ─────────────────────────────────────────────
    # notifications.user_id — user notification listing
    create_if_not_exists index(:notifications, [:user_id],
                           name: "notifications_user_id_index",
                           concurrently: true
                         )

    # ── Email Logs ────────────────────────────────────────────────
    # email_logs.user_id — user email history
    create_if_not_exists index(:email_logs, [:user_id],
                           name: "email_logs_user_id_index",
                           concurrently: true
                         )

    # ── Subscriptions ─────────────────────────────────────────────
    # subscriptions.organisation_id — org subscription lookup
    create_if_not_exists index(:subscriptions, [:organisation_id],
                           name: "subscriptions_organisation_id_index",
                           concurrently: true
                         )

    # subscriptions.plan_id — plan subscriber count
    create_if_not_exists index(:subscriptions, [:plan_id],
                           name: "subscriptions_plan_id_index",
                           concurrently: true
                         )

    # ── Usage Records ─────────────────────────────────────────────
    # usage_records.organisation_id — org usage tracking
    create_if_not_exists index(:usage_records, [:organisation_id],
                           name: "usage_records_organisation_id_index",
                           concurrently: true
                         )

    # ── Invoices ──────────────────────────────────────────────────
    # invoices.organisation_id — org invoice listing
    create_if_not_exists index(:invoices, [:organisation_id],
                           name: "invoices_organisation_id_index",
                           concurrently: true
                         )

    # ── Webhook Deliveries ────────────────────────────────────────
    # webhook_deliveries.webhook_id — delivery history for a webhook
    create_if_not_exists index(:webhook_deliveries, [:webhook_id],
                           name: "webhook_deliveries_webhook_id_index",
                           concurrently: true
                         )

    # ── Outbound Webhooks ─────────────────────────────────────────
    # outbound_webhooks.organisation_id — org webhook listing
    create_if_not_exists index(:outbound_webhooks, [:organisation_id],
                           name: "outbound_webhooks_organisation_id_index",
                           concurrently: true
                         )

    # ── Conversations ─────────────────────────────────────────────
    create_if_not_exists index(:conversations, [:organisation_id],
                           name: "conversations_organisation_id_index",
                           concurrently: true
                         )

    create_if_not_exists index(:conversations, [:user_id],
                           name: "conversations_user_id_index",
                           concurrently: true
                         )

    create_if_not_exists index(:conversations, [:agent_id],
                           name: "conversations_agent_id_index",
                           concurrently: true
                         )

    # ── Messages ──────────────────────────────────────────────────
    create_if_not_exists index(:messages, [:conversation_id],
                           name: "messages_conversation_id_index",
                           concurrently: true
                         )

    # ── Tool Calls ────────────────────────────────────────────────
    create_if_not_exists index(:tool_calls, [:message_id],
                           name: "tool_calls_message_id_index",
                           concurrently: true
                         )

    # ── Agents ────────────────────────────────────────────────────
    create_if_not_exists index(:agents, [:organisation_id],
                           name: "agents_organisation_id_index",
                           concurrently: true
                         )
  end

  def down do
    # Ecommerce core
    drop_if_exists index(:products, [:category_id], name: "products_category_id_index")
    drop_if_exists index(:products, [:status], name: "products_status_index")
    drop_if_exists index(:products, [:store_id, :status], name: "products_store_id_status_index")
    drop_if_exists index(:variants, [:product_id], name: "variants_product_id_index")
    drop_if_exists index(:variants, [:track_inventory, :stock_quantity], name: "variants_inventory_tracking_index")
    drop_if_exists index(:option_types, [:store_id], name: "option_types_store_id_index")
    drop_if_exists index(:option_values, [:store_id], name: "option_values_store_id_index")
    drop_if_exists index(:images, [:product_id], name: "images_product_id_index")
    drop_if_exists index(:images, [:store_id], name: "images_store_id_index")
    drop_if_exists index(:images, [:product_id, :position], name: "images_product_id_position_index")
    drop_if_exists index(:categories, [:parent_id], name: "categories_parent_id_index")
    drop_if_exists index(:orders, [:customer_id], name: "orders_customer_id_index")
    drop_if_exists index(:orders, [:status], name: "orders_status_index")
    drop_if_exists index(:orders, [:store_id, :status], name: "orders_store_id_status_index")
    drop_if_exists index(:orders, [:store_id, :inserted_at], name: "orders_store_id_inserted_at_index")
    drop_if_exists index(:line_items, [:order_id], name: "line_items_order_id_index")
    drop_if_exists index(:line_items, [:store_id], name: "line_items_store_id_index")
    drop_if_exists index(:line_items, [:variant_id], name: "line_items_variant_id_index")
    drop_if_exists index(:payments, [:order_id], name: "payments_order_id_index")
    drop_if_exists index(:payments, [:store_id], name: "payments_store_id_index")
    drop_if_exists index(:payments, [:status], name: "payments_status_index")
    drop_if_exists index(:variant_option_values, [:store_id], name: "variant_option_values_store_id_index")
    drop_if_exists index(:variant_option_values, [:option_value_id], name: "variant_option_values_option_value_id_index")
    drop_if_exists index(:store_memberships, [:store_id], name: "store_memberships_store_id_index")

    # Notifications
    drop_if_exists index(:notifications, [:user_id], name: "notifications_user_id_index")
    drop_if_exists index(:email_logs, [:user_id], name: "email_logs_user_id_index")

    # Billing
    drop_if_exists index(:subscriptions, [:organisation_id], name: "subscriptions_organisation_id_index")
    drop_if_exists index(:subscriptions, [:plan_id], name: "subscriptions_plan_id_index")
    drop_if_exists index(:usage_records, [:organisation_id], name: "usage_records_organisation_id_index")
    drop_if_exists index(:invoices, [:organisation_id], name: "invoices_organisation_id_index")

    # Webhooks
    drop_if_exists index(:webhook_deliveries, [:webhook_id], name: "webhook_deliveries_webhook_id_index")
    drop_if_exists index(:outbound_webhooks, [:organisation_id], name: "outbound_webhooks_organisation_id_index")

    # AI
    drop_if_exists index(:conversations, [:organisation_id], name: "conversations_organisation_id_index")
    drop_if_exists index(:conversations, [:user_id], name: "conversations_user_id_index")
    drop_if_exists index(:conversations, [:agent_id], name: "conversations_agent_id_index")
    drop_if_exists index(:messages, [:conversation_id], name: "messages_conversation_id_index")
    drop_if_exists index(:tool_calls, [:message_id], name: "tool_calls_message_id_index")
    drop_if_exists index(:agents, [:organisation_id], name: "agents_organisation_id_index")
  end
end
