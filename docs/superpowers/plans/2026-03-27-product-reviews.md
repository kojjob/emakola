# Product Reviews & Ratings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add verified-purchase product reviews with star ratings, auto-publishing, and merchant moderation.

**Architecture:** New `Review` Ash resource in the Catalog domain with store-scoped multi-tenancy. Eligibility checked by querying delivered orders containing the product's variants. A shared `ReviewComponents` module renders the review UI across all themes. The product detail LiveView gains new event handlers for review submission. Admin gets a review management page.

**Tech Stack:** Elixir, Ash 3.x, Phoenix LiveView, PostgreSQL

---

### Task 1: Create Review Resource and Migration

**Files:**
- Create: `lib/emakola/catalog/resources/review.ex`
- Create: `priv/repo/migrations/TIMESTAMP_create_reviews.exs`
- Modify: `lib/emakola/catalog/catalog.ex`
- Modify: `lib/emakola/catalog/resources/product.ex`
- Create: `test/emakola/catalog/review_test.exs`

- [ ] **Step 1: Write failing tests**

Create `test/emakola/catalog/review_test.exs`:

```elixir
defmodule Emakola.Catalog.ReviewTest do
  use Emakola.DataCase, async: true

  alias Emakola.Factory

  setup do
    {_merchant, store} = Factory.create_merchant_with_store!()
    customer = Factory.create_customer!(store)
    product = Factory.create_product!(store, status: :active)
    variant = Factory.create_variant!(product, store, price: 5000, stock_quantity: 20)

    # Create a delivered order with this variant
    order =
      Factory.create_order!(store, %{
        customer_id: customer.id,
        total: 5000,
        subtotal: 5000,
        status: :delivered
      })

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!()

    %{store: store, customer: customer, product: product, order: order}
  end

  describe "review creation" do
    test "creates a review with valid data", %{store: store, customer: customer, product: product, order: order} do
      review =
        Emakola.Catalog.Review
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer.id,
          order_id: order.id,
          rating: 5,
          title: "Great product!",
          body: "Absolutely loved it. High quality and fast delivery."
        })
        |> Ash.create!()

      assert review.rating == 5
      assert review.title == "Great product!"
      assert review.status == :published
      assert review.verified_purchase == true
    end

    test "requires rating between 1 and 5", %{store: store, customer: customer, product: product, order: order} do
      assert {:error, _} =
        Emakola.Catalog.Review
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer.id,
          order_id: order.id,
          rating: 0,
          body: "Bad rating"
        })
        |> Ash.create()

      assert {:error, _} =
        Emakola.Catalog.Review
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer.id,
          order_id: order.id,
          rating: 6,
          body: "Bad rating"
        })
        |> Ash.create()
    end

    test "requires body", %{store: store, customer: customer, product: product, order: order} do
      assert {:error, _} =
        Emakola.Catalog.Review
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer.id,
          order_id: order.id,
          rating: 4
        })
        |> Ash.create()
    end

    test "prevents duplicate review per customer per product", %{store: store, customer: customer, product: product, order: order} do
      Emakola.Catalog.Review
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        product_id: product.id,
        customer_id: customer.id,
        order_id: order.id,
        rating: 5,
        body: "First review"
      })
      |> Ash.create!()

      assert {:error, _} =
        Emakola.Catalog.Review
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer.id,
          order_id: order.id,
          rating: 3,
          body: "Duplicate review"
        })
        |> Ash.create()
    end
  end

  describe "hide/unhide" do
    test "hides and unhides a review", %{store: store, customer: customer, product: product, order: order} do
      review =
        Emakola.Catalog.Review
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          product_id: product.id,
          customer_id: customer.id,
          order_id: order.id,
          rating: 4,
          body: "Good product"
        })
        |> Ash.create!()

      assert review.status == :published

      hidden = review |> Ash.Changeset.for_update(:hide, %{}) |> Ash.update!()
      assert hidden.status == :hidden

      unhidden = hidden |> Ash.Changeset.for_update(:unhide, %{}) |> Ash.update!()
      assert unhidden.status == :published
    end
  end

  describe "list_by_product" do
    test "returns only published reviews for a product", %{store: store, customer: customer, product: product, order: order} do
      # Create second customer with delivered order
      customer2 = Factory.create_customer!(store)
      order2 = Factory.create_order!(store, %{customer_id: customer2.id, total: 5000, subtotal: 5000, status: :delivered})
      variant = List.first(Ash.read!(Emakola.Catalog.Variant |> Ash.Query.filter(product_id == ^product.id), authorize?: false))
      Emakola.Orders.LineItem |> Ash.Changeset.for_create(:create, %{order_id: order2.id, store_id: store.id, variant_id: variant.id, quantity: 1}) |> Ash.create!()

      r1 = Emakola.Catalog.Review |> Ash.Changeset.for_create(:create, %{store_id: store.id, product_id: product.id, customer_id: customer.id, order_id: order.id, rating: 5, body: "Great"}) |> Ash.create!()
      r2 = Emakola.Catalog.Review |> Ash.Changeset.for_create(:create, %{store_id: store.id, product_id: product.id, customer_id: customer2.id, order_id: order2.id, rating: 3, body: "Ok"}) |> Ash.create!()

      # Hide one
      r1 |> Ash.Changeset.for_update(:hide, %{}) |> Ash.update!()

      reviews = Emakola.Catalog.Review |> Ash.Query.filter(product_id == ^product.id and status == :published) |> Ash.Query.sort(inserted_at: :desc) |> Ash.read!(authorize?: false)

      assert length(reviews) == 1
      assert List.first(reviews).id == r2.id
    end
  end

  describe "eligibility check" do
    test "eligible? returns order_id when customer has delivered order with product", %{store: store, customer: customer, product: product} do
      assert {:ok, _order_id} = Emakola.Catalog.Review.eligible?(store.id, product.id, customer.id)
    end

    test "eligible? returns error when customer has no delivered order", %{store: store, product: product} do
      other_customer = Factory.create_customer!(store)
      assert {:error, :not_eligible} = Emakola.Catalog.Review.eligible?(store.id, product.id, other_customer.id)
    end

    test "eligible? returns error when already reviewed", %{store: store, customer: customer, product: product, order: order} do
      Emakola.Catalog.Review |> Ash.Changeset.for_create(:create, %{store_id: store.id, product_id: product.id, customer_id: customer.id, order_id: order.id, rating: 5, body: "Done"}) |> Ash.create!()

      assert {:error, :already_reviewed} = Emakola.Catalog.Review.eligible?(store.id, product.id, customer.id)
    end
  end

  describe "product aggregates" do
    test "product has avg_rating and review_count", %{store: store, customer: customer, product: product, order: order} do
      Emakola.Catalog.Review |> Ash.Changeset.for_create(:create, %{store_id: store.id, product_id: product.id, customer_id: customer.id, order_id: order.id, rating: 4, body: "Good"}) |> Ash.create!()

      loaded = Ash.get!(Emakola.Catalog.Product, product.id, load: [:avg_rating, :review_count], authorize?: false)
      assert loaded.review_count == 1
      assert loaded.avg_rating == 4.0
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola/catalog/review_test.exs -v`
Expected: FAIL — module doesn't exist.

- [ ] **Step 3: Create the Review resource**

Create `lib/emakola/catalog/resources/review.ex`:

```elixir
defmodule Emakola.Catalog.Review do
  @moduledoc """
  Product review — verified-purchase reviews with star ratings.

  Only customers with a delivered order containing the product can review.
  One review per customer per product per store. Auto-published, merchants
  can hide inappropriate reviews.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

  postgres do
    table("reviews")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :product_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :customer_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :order_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :rating, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 1, max: 5)
    end

    attribute :title, :string do
      public?(true)
      constraints(max_length: 100)
    end

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 2000)
    end

    attribute :status, :atom do
      constraints(one_of: [:published, :hidden])
      default(:published)
      allow_nil?(false)
      public?(true)
    end

    attribute :verified_purchase, :boolean do
      default(true)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :product, Emakola.Catalog.Product do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :customer, Emakola.Customers.Customer do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :order, Emakola.Orders.Order do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_customer_product_review, [:store_id, :product_id, :customer_id])
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass always() do
      authorize_unless(actor_present())
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  validations do
    validate compare(:rating, greater_than_or_equal_to: 1), message: "must be at least 1"
    validate compare(:rating, less_than_or_equal_to: 5), message: "must be at most 5"
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :product_id, :customer_id, :order_id, :rating, :title, :body])

      change(set_attribute(:verified_purchase, true))
      change(set_attribute(:status, :published))
    end

    update :hide do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :hidden))
    end

    update :unhide do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :published))
    end
  end

  @doc """
  Checks if a customer is eligible to review a product.

  Returns `{:ok, order_id}` if eligible, or `{:error, reason}`.
  """
  def eligible?(store_id, product_id, customer_id) do
    # Check if already reviewed
    existing =
      __MODULE__
      |> Ash.Query.filter(
        store_id == ^store_id and
          product_id == ^product_id and
          customer_id == ^customer_id
      )
      |> Ash.count!(authorize?: false)

    if existing > 0 do
      {:error, :already_reviewed}
    else
      # Check for delivered order with this product's variant
      variant_ids =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(product_id == ^product_id and store_id == ^store_id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)

      if variant_ids == [] do
        {:error, :not_eligible}
      else
        delivered_order =
          Emakola.Orders.Order
          |> Ash.Query.filter(
            store_id == ^store_id and
              customer_id == ^customer_id and
              status == :delivered
          )
          |> Ash.read!(authorize?: false)
          |> Enum.find(fn order ->
            line_items =
              Emakola.Orders.LineItem
              |> Ash.Query.filter(order_id == ^order.id)
              |> Ash.read!(authorize?: false)

            Enum.any?(line_items, fn li -> li.variant_id in variant_ids end)
          end)

        case delivered_order do
          nil -> {:error, :not_eligible}
          order -> {:ok, order.id}
        end
      end
    end
  end
end
```

- [ ] **Step 4: Create migration**

Create migration file `priv/repo/migrations/TIMESTAMP_create_reviews.exs`:

```elixir
defmodule Emakola.Repo.Migrations.CreateReviews do
  use Ecto.Migration

  def change do
    create table(:reviews, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :uuid, on_delete: :delete_all), null: false
      add :customer_id, references(:customers, type: :uuid, on_delete: :delete_all), null: false
      add :order_id, references(:orders, type: :uuid, on_delete: :delete_all), null: false
      add :rating, :integer, null: false
      add :title, :string, size: 100
      add :body, :string, size: 2000, null: false
      add :status, :string, null: false, default: "published"
      add :verified_purchase, :boolean, null: false, default: true

      timestamps()
    end

    create unique_index(:reviews, [:store_id, :product_id, :customer_id])
    create index(:reviews, [:product_id, :status])
    create index(:reviews, [:store_id])
  end
end
```

- [ ] **Step 5: Register Review in Catalog domain**

In `lib/emakola/catalog/catalog.ex`, add inside `resources do`:

```elixir
    resource(Emakola.Catalog.Review)
```

- [ ] **Step 6: Add relationship and aggregates to Product**

In `lib/emakola/catalog/resources/product.ex`, add to `relationships do` block:

```elixir
    has_many :reviews, Emakola.Catalog.Review
```

Add to `aggregates do` block:

```elixir
    count :review_count, :reviews do
      filter expr(status == :published)
    end

    avg :avg_rating, :reviews, :rating do
      filter expr(status == :published)
    end
```

- [ ] **Step 7: Run migration and tests**

Run:
```bash
mix ecto.migrate
mix test test/emakola/catalog/review_test.exs -v
```
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/emakola/catalog/resources/review.ex lib/emakola/catalog/catalog.ex lib/emakola/catalog/resources/product.ex priv/repo/migrations/*create_reviews* test/emakola/catalog/review_test.exs
git commit -m "feat(catalog): add Review resource with eligibility check and product aggregates"
```

---

### Task 2: Create Review Components

**Files:**
- Create: `lib/emakola_web/components/review_components.ex`

- [ ] **Step 1: Create the shared review components module**

Create `lib/emakola_web/components/review_components.ex`:

```elixir
defmodule EmakolaWeb.ReviewComponents do
  @moduledoc """
  Shared review components used across all storefront themes.
  Renders star ratings, review forms, and review lists.
  """

  use Phoenix.Component

  attr :avg_rating, :float, default: nil
  attr :review_count, :integer, default: 0

  def review_summary(assigns) do
    ~H"""
    <div :if={@review_count > 0} class="flex items-center gap-2">
      <.star_display rating={@avg_rating || 0} />
      <span class="text-sm text-gray-600">
        {Float.round(@avg_rating || 0.0, 1)} out of 5
        <span class="text-gray-400">({@review_count} {if @review_count == 1, do: "review", else: "reviews"})</span>
      </span>
    </div>
    """
  end

  attr :store, :map, required: true
  attr :product, :map, required: true
  attr :reviews, :list, default: []
  attr :can_review, :boolean, default: false
  attr :already_reviewed, :boolean, default: false
  attr :review_form_rating, :integer, default: 0
  attr :review_form_title, :string, default: ""
  attr :review_form_body, :string, default: ""
  attr :review_submitting, :boolean, default: false
  attr :avg_rating, :float, default: nil
  attr :review_count, :integer, default: 0

  def review_section(assigns) do
    ~H"""
    <section class="py-10 border-t border-gray-200" id="reviews">
      <div class="max-w-3xl mx-auto px-4">
        <%!-- Header --%>
        <div class="flex items-center justify-between mb-8">
          <div>
            <h2 class="text-xl font-bold text-gray-900">Customer Reviews</h2>
            <div :if={@review_count > 0} class="flex items-center gap-2 mt-1">
              <.star_display rating={@avg_rating || 0} />
              <span class="text-sm text-gray-500">
                {Float.round(@avg_rating || 0.0, 1)} out of 5 ({@review_count} {if @review_count == 1, do: "review", else: "reviews"})
              </span>
            </div>
          </div>
        </div>

        <%!-- Review Form --%>
        <%= cond do %>
          <% @can_review -> %>
            <div class="bg-gray-50 rounded-2xl p-6 mb-8">
              <div class="flex items-center gap-2 mb-4">
                <span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-green-100 text-green-700">
                  <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>
                  Verified Purchase
                </span>
              </div>
              <h3 class="text-base font-semibold text-gray-900 mb-4">Write a Review</h3>
              <form phx-submit="submit_review" class="space-y-4">
                <%!-- Star selector --%>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Rating</label>
                  <div class="flex gap-1">
                    <button
                      :for={i <- 1..5}
                      type="button"
                      phx-click="set_review_rating"
                      phx-value-rating={i}
                      class="focus:outline-none cursor-pointer"
                      aria-label={"Rate #{i} stars"}
                    >
                      <svg class={"w-8 h-8 #{if i <= @review_form_rating, do: "text-amber-400", else: "text-gray-300"}"} fill="currentColor" viewBox="0 0 20 20">
                        <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                      </svg>
                    </button>
                  </div>
                </div>
                <%!-- Title --%>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Title (optional)</label>
                  <input
                    type="text"
                    name="title"
                    value={@review_form_title}
                    maxlength="100"
                    placeholder="Sum it up in a few words"
                    class="w-full px-4 py-2.5 rounded-xl border border-gray-300 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  />
                </div>
                <%!-- Body --%>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Your Review</label>
                  <textarea
                    name="body"
                    rows="4"
                    maxlength="2000"
                    placeholder="What did you like or dislike? How did you use the product?"
                    required
                    class="w-full px-4 py-2.5 rounded-xl border border-gray-300 text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
                  >{@review_form_body}</textarea>
                </div>
                <button
                  type="submit"
                  disabled={@review_form_rating == 0 || @review_submitting}
                  class={[
                    "px-6 py-3 rounded-xl text-sm font-semibold transition-all",
                    if(@review_form_rating == 0 || @review_submitting,
                      do: "bg-gray-200 text-gray-400 cursor-not-allowed",
                      else: "bg-gray-900 text-white hover:bg-gray-800 active:scale-[0.98] cursor-pointer"
                    )
                  ]}
                >
                  {if @review_submitting, do: "Submitting...", else: "Submit Review"}
                </button>
              </form>
            </div>
          <% @already_reviewed -> %>
            <div class="bg-green-50 border border-green-200 rounded-2xl p-6 mb-8 text-center">
              <p class="text-sm text-green-700 font-medium">You've already reviewed this product. Thank you!</p>
            </div>
          <% true -> %>
            <div class="bg-gray-50 rounded-2xl p-6 mb-8 text-center">
              <p class="text-sm text-gray-500">Purchase and receive this product to leave a review.</p>
            </div>
        <% end %>

        <%!-- Reviews List --%>
        <%= if @reviews == [] do %>
          <div class="text-center py-8">
            <p class="text-gray-400 text-sm">No reviews yet. Be the first to share your experience!</p>
          </div>
        <% else %>
          <div class="space-y-6">
            <div :for={review <- @reviews} class="border-b border-gray-100 pb-6 last:border-b-0">
              <div class="flex items-center gap-3 mb-2">
                <.star_display rating={review.rating} size="sm" />
                <span class="text-sm font-medium text-gray-900">{reviewer_name(review)}</span>
                <span class="text-xs text-gray-400">{relative_time(review.inserted_at)}</span>
              </div>
              <p :if={review.title} class="font-semibold text-gray-900 mb-1">{review.title}</p>
              <p class="text-sm text-gray-600 leading-relaxed">{review.body}</p>
              <span class="inline-flex items-center gap-1 mt-2 text-xs text-green-600">
                <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>
                Verified Purchase
              </span>
            </div>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  attr :rating, :any, required: true
  attr :size, :string, default: "md"

  def star_display(assigns) do
    assigns = assign(assigns, :rating_float, (assigns.rating || 0) / 1)

    ~H"""
    <div class="flex gap-0.5">
      <svg
        :for={i <- 1..5}
        class={[
          if(@size == "sm", do: "w-4 h-4", else: "w-5 h-5"),
          if(i <= round(@rating_float), do: "text-amber-400", else: "text-gray-200")
        ]}
        fill="currentColor"
        viewBox="0 0 20 20"
      >
        <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
      </svg>
    </div>
    """
  end

  defp reviewer_name(review) do
    case review do
      %{customer: %{name: name}} when is_binary(name) and name != "" ->
        name |> String.split() |> List.first()
      _ ->
        "Customer"
    end
  end

  defp relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604_800 -> "#{div(diff, 86400)} days ago"
      diff < 2_592_000 -> "#{div(diff, 604_800)} weeks ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end
end
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`

- [ ] **Step 3: Commit**

```bash
git add lib/emakola_web/components/review_components.ex
git commit -m "feat(web): add shared review components (stars, form, list)"
```

---

### Task 3: Wire Reviews into Product Detail LiveView

**Files:**
- Modify: `lib/emakola_web/live/storefront/product_detail_live.ex`
- Create: `test/emakola_web/live/storefront/product_review_test.exs`

- [ ] **Step 1: Write failing tests**

Create `test/emakola_web/live/storefront/product_review_test.exs`:

```elixir
defmodule EmakolaWeb.Storefront.ProductReviewTest do
  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  setup %{conn: conn} do
    {_merchant, store} = Factory.create_merchant_with_store!()
    product = Factory.create_product!(store, status: :active)
    variant = Factory.create_variant!(product, store, price: 5000, stock_quantity: 20)
    customer = Factory.create_customer!(store)

    # Create delivered order
    order = Factory.create_order!(store, %{customer_id: customer.id, total: 5000, subtotal: 5000, status: :delivered})
    Emakola.Orders.LineItem |> Ash.Changeset.for_create(:create, %{order_id: order.id, store_id: store.id, variant_id: variant.id, quantity: 1}) |> Ash.create!()

    %{conn: conn, store: store, product: product, customer: customer, order: order}
  end

  describe "reviews section on product detail" do
    test "renders reviews section", %{conn: conn, store: store, product: product} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ "Customer Reviews"
    end

    test "shows existing reviews", %{conn: conn, store: store, product: product, customer: customer, order: order} do
      Emakola.Catalog.Review
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        product_id: product.id,
        customer_id: customer.id,
        order_id: order.id,
        rating: 5,
        title: "Excellent product",
        body: "Really loved this. High quality."
      })
      |> Ash.create!()

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ "Excellent product"
      assert html =~ "Really loved this"
      assert html =~ "Verified Purchase"
    end

    test "shows empty state when no reviews", %{conn: conn, store: store, product: product} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ "No reviews yet"
    end
  end
end
```

- [ ] **Step 2: Add review assigns and events to ProductDetailLive**

In `lib/emakola_web/live/storefront/product_detail_live.ex`, modify the mount function to load reviews. After the line `|> assign(:cart_count, cart_count)` add:

```elixir
             |> assign(:reviews, load_reviews(product.id))
             |> assign(:review_form_rating, 0)
             |> assign(:review_form_title, "")
             |> assign(:review_form_body, "")
             |> assign(:review_submitting, false)
             |> assign_review_eligibility(store, product, session)
```

Add these event handlers before the `render/1` function:

```elixir
  @impl true
  def handle_event("set_review_rating", %{"rating" => rating_str}, socket) do
    {:noreply, assign(socket, :review_form_rating, String.to_integer(rating_str))}
  end

  @impl true
  def handle_event("submit_review", %{"body" => body} = params, socket) do
    title = Map.get(params, "title", "")
    rating = socket.assigns.review_form_rating
    store = socket.assigns.store
    product = socket.assigns.product

    case socket.assigns[:review_order_id] do
      nil ->
        {:noreply, put_flash(socket, :error, "You need a delivered order to review this product")}

      order_id ->
        case Emakola.Catalog.Review
             |> Ash.Changeset.for_create(:create, %{
               store_id: store.id,
               product_id: product.id,
               customer_id: socket.assigns.review_customer_id,
               order_id: order_id,
               rating: rating,
               title: if(title == "", do: nil, else: title),
               body: body
             })
             |> Ash.create() do
          {:ok, _review} ->
            {:noreply,
             socket
             |> assign(:reviews, load_reviews(product.id))
             |> assign(:can_review, false)
             |> assign(:already_reviewed, true)
             |> assign(:review_form_rating, 0)
             |> assign(:review_form_title, "")
             |> assign(:review_form_body, "")
             |> put_flash(:info, "Review submitted! Thank you.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not submit review. Please try again.")}
        end
    end
  end
```

Add these helper functions:

```elixir
  defp load_reviews(product_id) do
    Emakola.Catalog.Review
    |> Ash.Query.filter(product_id == ^product_id and status == :published)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load([:customer])
    |> Ash.read!(authorize?: false)
  end

  defp assign_review_eligibility(socket, store, product, session) do
    # Try to identify customer from checkout session
    customer_id = get_in(session, ["checkout_customer_id"])

    if customer_id do
      case Emakola.Catalog.Review.eligible?(store.id, product.id, customer_id) do
        {:ok, order_id} ->
          socket
          |> assign(:can_review, true)
          |> assign(:already_reviewed, false)
          |> assign(:review_customer_id, customer_id)
          |> assign(:review_order_id, order_id)

        {:error, :already_reviewed} ->
          socket
          |> assign(:can_review, false)
          |> assign(:already_reviewed, true)
          |> assign(:review_customer_id, customer_id)
          |> assign(:review_order_id, nil)

        {:error, _} ->
          assign_no_review(socket)
      end
    else
      assign_no_review(socket)
    end
  end

  defp assign_no_review(socket) do
    socket
    |> assign(:can_review, false)
    |> assign(:already_reviewed, false)
    |> assign(:review_customer_id, nil)
    |> assign(:review_order_id, nil)
  end
```

Also update `load_product` to load review aggregates:

```elixir
  defp load_product(store_id, product_slug) do
    Emakola.Catalog.Product
    |> Ash.Query.filter(store_id == ^store_id and slug == ^product_slug and status == :active)
    |> Ash.Query.load([:variants, :images, :min_price, :max_price, :avg_rating, :review_count])
    |> Ash.read_one!()
  end
```

- [ ] **Step 3: Add review section to all theme product detail pages**

Each theme's `product_detail.ex` needs a review section added at the bottom, before the closing `</div>`. Add this to all 6 themes (market, atelier, vibrant, starter, bold, fresh):

```heex
      <%!-- Reviews Section --%>
      <EmakolaWeb.ReviewComponents.review_section
        store={@store}
        product={@product}
        reviews={@reviews}
        can_review={@can_review}
        already_reviewed={@already_reviewed}
        review_form_rating={@review_form_rating}
        review_form_title={@review_form_title}
        review_form_body={@review_form_body}
        review_submitting={@review_submitting}
        avg_rating={@product.avg_rating}
        review_count={@product.review_count}
      />
```

- [ ] **Step 4: Run tests**

Run:
```bash
mix test test/emakola_web/live/storefront/product_review_test.exs -v
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web/live/storefront/product_detail_live.ex lib/emakola/themes/*/product_detail.ex test/emakola_web/live/storefront/product_review_test.exs
git commit -m "feat(web): wire product reviews into storefront product detail pages"
```

---

### Task 4: Admin Review Management

**Files:**
- Create: `lib/emakola_web/live/admin/review_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Create: `test/emakola_web/live/admin/review_live_test.exs`

- [ ] **Step 1: Write failing tests**

Create `test/emakola_web/live/admin/review_live_test.exs`:

```elixir
defmodule EmakolaWeb.Admin.ReviewLiveTest do
  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  setup %{conn: conn} do
    {conn, merchant, store} = setup_authenticated_merchant(conn)
    customer = Factory.create_customer!(store)
    product = Factory.create_product!(store, status: :active)
    variant = Factory.create_variant!(product, store, price: 5000, stock_quantity: 20)
    order = Factory.create_order!(store, %{customer_id: customer.id, total: 5000, subtotal: 5000, status: :delivered})
    Emakola.Orders.LineItem |> Ash.Changeset.for_create(:create, %{order_id: order.id, store_id: store.id, variant_id: variant.id, quantity: 1}) |> Ash.create!()

    review =
      Emakola.Catalog.Review
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        product_id: product.id,
        customer_id: customer.id,
        order_id: order.id,
        rating: 4,
        title: "Good quality",
        body: "Really enjoyed this product"
      })
      |> Ash.create!()

    %{conn: conn, merchant: merchant, store: store, review: review, product: product}
  end

  describe "admin review list" do
    test "renders reviews page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/reviews")

      assert html =~ "Reviews"
      assert html =~ "Good quality"
    end

    test "can hide a review", %{conn: conn, review: review} do
      {:ok, view, _html} = live(conn, ~p"/admin/reviews")

      html = view |> element("button[phx-value-id=\"#{review.id}\"]", "Hide") |> render_click()

      assert html =~ "hidden" || html =~ "Hidden"
    end
  end
end
```

- [ ] **Step 2: Create admin review LiveView**

Create `lib/emakola_web/live/admin/review_live.ex`:

```elixir
defmodule EmakolaWeb.Admin.ReviewLive do
  use EmakolaWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Reviews",
        active_nav: :reviews,
        store_id: store_id,
        status_filter: :all,
        reviews: []
      )
      |> load_reviews()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    filter = if status == "all", do: :all, else: String.to_existing_atom(status)
    {:noreply, socket |> assign(:status_filter, filter) |> load_reviews()}
  end

  @impl true
  def handle_event("hide_review", %{"id" => id}, socket) do
    review = Ash.get!(Emakola.Catalog.Review, id, authorize?: false)
    review |> Ash.Changeset.for_update(:hide, %{}) |> Ash.update!()
    {:noreply, socket |> load_reviews() |> put_flash(:info, "Review hidden")}
  end

  @impl true
  def handle_event("unhide_review", %{"id" => id}, socket) do
    review = Ash.get!(Emakola.Catalog.Review, id, authorize?: false)
    review |> Ash.Changeset.for_update(:unhide, %{}) |> Ash.update!()
    {:noreply, socket |> load_reviews() |> put_flash(:info, "Review restored")}
  end

  defp load_reviews(socket) do
    store_id = socket.assigns.store_id
    status_filter = socket.assigns.status_filter

    query =
      Emakola.Catalog.Review
      |> Ash.Query.filter(store_id == ^store_id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.load([:customer, :product])

    query =
      if status_filter != :all do
        Ash.Query.filter(query, status == ^status_filter)
      else
        query
      end

    reviews = Ash.read!(query, authorize?: false)
    assign(socket, :reviews, reviews)
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-slate-900">Reviews</h1>
          <p class="text-sm text-slate-500 mt-1">Manage customer reviews</p>
        </div>
        <div class="flex gap-1 bg-slate-100 rounded-lg p-1">
          <button
            :for={s <- [:all, :published, :hidden]}
            phx-click="filter_status"
            phx-value-status={s}
            class={[
              "px-3 py-1.5 rounded-md text-xs font-medium transition-all cursor-pointer",
              if(@status_filter == s, do: "bg-white text-slate-900 shadow-sm", else: "text-slate-500 hover:text-slate-700")
            ]}
          >
            {s |> to_string() |> String.capitalize()}
          </button>
        </div>
      </div>

      <%= if @reviews == [] do %>
        <div class="text-center py-16 bg-white rounded-xl border border-slate-200">
          <span class="material-symbols-outlined text-4xl text-slate-200 mb-2 block">rate_review</span>
          <p class="text-slate-400 text-sm">No reviews yet</p>
        </div>
      <% else %>
        <div class="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <table class="w-full">
            <thead>
              <tr class="bg-slate-50 border-b border-slate-200">
                <th class="text-left text-xs font-medium text-slate-400 uppercase tracking-wider px-6 py-3">Product</th>
                <th class="text-left text-xs font-medium text-slate-400 uppercase tracking-wider px-6 py-3">Customer</th>
                <th class="text-center text-xs font-medium text-slate-400 uppercase tracking-wider px-6 py-3">Rating</th>
                <th class="text-left text-xs font-medium text-slate-400 uppercase tracking-wider px-6 py-3">Review</th>
                <th class="text-center text-xs font-medium text-slate-400 uppercase tracking-wider px-6 py-3">Status</th>
                <th class="text-right text-xs font-medium text-slate-400 uppercase tracking-wider px-6 py-3">Action</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={review <- @reviews} class="border-b border-slate-100 hover:bg-slate-50/50">
                <td class="px-6 py-4 text-sm font-medium text-slate-900 max-w-[200px] truncate">
                  {review.product.title}
                </td>
                <td class="px-6 py-4 text-sm text-slate-600">
                  {if review.customer, do: review.customer.name || to_string(review.customer.email), else: "Unknown"}
                </td>
                <td class="px-6 py-4 text-center">
                  <div class="flex justify-center gap-0.5">
                    <svg :for={i <- 1..5} class={"w-4 h-4 #{if i <= review.rating, do: "text-amber-400", else: "text-slate-200"}"} fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  </div>
                </td>
                <td class="px-6 py-4 text-sm text-slate-600 max-w-[300px]">
                  <p :if={review.title} class="font-medium text-slate-900">{review.title}</p>
                  <p class="truncate">{review.body}</p>
                </td>
                <td class="px-6 py-4 text-center">
                  <span class={[
                    "inline-flex px-2 py-0.5 rounded-full text-xs font-semibold",
                    if(review.status == :published, do: "bg-green-100 text-green-700", else: "bg-red-100 text-red-700")
                  ]}>
                    {review.status |> to_string() |> String.capitalize()}
                  </span>
                </td>
                <td class="px-6 py-4 text-right">
                  <%= if review.status == :published do %>
                    <button
                      phx-click="hide_review"
                      phx-value-id={review.id}
                      class="text-xs font-medium text-red-600 hover:text-red-700 cursor-pointer"
                    >
                      Hide
                    </button>
                  <% else %>
                    <button
                      phx-click="unhide_review"
                      phx-value-id={review.id}
                      class="text-xs font-medium text-green-600 hover:text-green-700 cursor-pointer"
                    >
                      Show
                    </button>
                  <% end %>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end
end
```

- [ ] **Step 3: Add route**

In `lib/emakola_web/router.ex`, add inside the admin live_session (near the other admin routes):

```elixir
      live "/admin/reviews", Admin.ReviewLive
```

- [ ] **Step 4: Run tests**

Run:
```bash
mix test test/emakola_web/live/admin/review_live_test.exs -v
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web/live/admin/review_live.ex lib/emakola_web/router.ex test/emakola_web/live/admin/review_live_test.exs
git commit -m "feat(admin): add review management page with hide/unhide"
```

---

### Task 5: Final Verification

- [ ] **Step 1: Format**

Run: `mix format`

- [ ] **Step 2: Run full test suite**

Run: `mix test 2>&1 | tail -5`

- [ ] **Step 3: Commit any formatting changes**

```bash
git status
```
