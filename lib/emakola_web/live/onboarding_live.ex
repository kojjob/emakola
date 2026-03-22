defmodule EmakolaWeb.OnboardingLive do
  @moduledoc """
  Onboarding flow for new Emakola merchants.

  3-step flow:
  1. Name Your Store — store name, currency, auto-generated slug
  2. Add Your First Product — optional, skippable
  3. You're Ready! — summary + go to dashboard
  """

  use EmakolaWeb, :live_view

  require Ash.Query

  @currencies [
    %{code: "GHS", label: "GHS — Ghana Cedi", flag: "\u{1F1EC}\u{1F1ED}"},
    %{code: "NGN", label: "NGN — Nigerian Naira", flag: "\u{1F1F3}\u{1F1EC}"},
    %{code: "USD", label: "USD — US Dollar", flag: "\u{1F1FA}\u{1F1F8}"}
  ]

  def mount(_params, session, socket) do
    current_user = resolve_user(session)

    if current_user && has_store_membership?(current_user) do
      {:ok,
       socket
       |> assign(current_user: current_user)
       |> put_flash(:info, "You've already completed onboarding")
       |> push_navigate(to: "/dashboard")}
    else
      {:ok,
       assign(socket,
         page_title: "Set Up Your Store",
         step: 1,
         total_steps: 3,
         current_user: current_user,
         user_type: user_type(current_user),
         store_name: "",
         store_slug: "",
         currency: "GHS",
         currencies: @currencies,
         product_name: "",
         product_price: "",
         error: nil,
         created_store: nil
       )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 p-4">
      <div class="w-full max-w-lg space-y-8">
        <%!-- Step indicator --%>
        <div class="text-center">
          <div class="flex items-center gap-2 mb-2">
            <div
              :for={i <- 1..@total_steps}
              class={[
                "h-1.5 flex-1 rounded-full transition-all duration-300",
                if(i <= @step, do: "bg-emerald-500", else: "bg-gray-200")
              ]}
            >
            </div>
          </div>
          <p class="text-xs font-medium text-gray-500">
            Step {@step} of {@total_steps}
          </p>
        </div>

        <%!-- Error display --%>
        <div
          :if={@error}
          class="flex items-center gap-2 bg-red-50 text-red-700 text-sm font-medium p-4 rounded-xl border border-red-200"
        >
          <svg
            class="w-5 h-5 flex-shrink-0"
            fill="currentColor"
            viewBox="0 0 20 20"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z"
              clip-rule="evenodd"
            />
          </svg>
          {@error}
        </div>

        <%!-- Step 1: Name Your Store --%>
        <div :if={@step == 1} class="space-y-6 text-center">
          <div class="w-16 h-16 rounded-2xl bg-emerald-50 flex items-center justify-center mx-auto">
            <svg
              class="w-8 h-8 text-emerald-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M13.5 21v-7.5a.75.75 0 0 1 .75-.75h3a.75.75 0 0 1 .75.75V21m-4.5 0H2.36m11.14 0H18m0 0h3.64m-1.39 0V9.349M3.75 21V9.349m0 0a3.001 3.001 0 0 0 3.75-.615A2.993 2.993 0 0 0 9.75 9.75c.896 0 1.7-.393 2.25-1.016a2.993 2.993 0 0 0 2.25 1.016c.896 0 1.7-.393 2.25-1.015a3.001 3.001 0 0 0 3.75.614m-16.5 0a3.004 3.004 0 0 1-.621-4.72l1.189-1.19A1.5 1.5 0 0 1 5.378 3h13.243a1.5 1.5 0 0 1 1.06.44l1.19 1.189a3 3 0 0 1-.621 4.72M6.75 18h3.75a.75.75 0 0 0 .75-.75V13.5a.75.75 0 0 0-.75-.75H6.75a.75.75 0 0 0-.75.75v3.75c0 .414.336.75.75.75Z"
              />
            </svg>
          </div>
          <h1 class="text-2xl sm:text-3xl font-extrabold text-gray-900">
            Name Your Store
          </h1>
          <p class="text-gray-500">
            What should we call your online store?
          </p>

          <div class="space-y-4 text-left">
            <div>
              <label for="store_name" class="block text-sm font-medium text-gray-700 mb-1">
                Store name
              </label>
              <input
                type="text"
                id="store_name"
                name="store_name"
                value={@store_name}
                placeholder="e.g. Kojo's Fashion"
                phx-change="update_store_name"
                phx-debounce="300"
                autofocus
                class="w-full bg-white border border-gray-300 rounded-lg px-4 py-3 text-sm text-gray-900 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
              <p :if={@store_slug != ""} class="mt-1.5 text-xs text-gray-400">
                Your store URL: <span class="font-mono text-emerald-600">{@store_slug}</span>.emakola.com
              </p>
            </div>

            <div>
              <label for="currency" class="block text-sm font-medium text-gray-700 mb-1">
                Currency
              </label>
              <select
                id="currency"
                name="currency"
                phx-change="update_currency"
                class="w-full bg-white border border-gray-300 rounded-lg px-4 py-3 text-sm text-gray-900 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              >
                <option
                  :for={c <- @currencies}
                  value={c.code}
                  selected={c.code == @currency}
                >
                  {c.flag} {c.label}
                </option>
              </select>
            </div>
          </div>
        </div>

        <%!-- Step 2: Add Your First Product --%>
        <div :if={@step == 2} class="space-y-6 text-center">
          <div class="w-16 h-16 rounded-2xl bg-emerald-50 flex items-center justify-center mx-auto">
            <svg
              class="w-8 h-8 text-emerald-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M20.25 7.5l-.625 10.632a2.25 2.25 0 0 1-2.247 2.118H6.622a2.25 2.25 0 0 1-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125Z"
              />
            </svg>
          </div>
          <h1 class="text-2xl sm:text-3xl font-extrabold text-gray-900">
            Add Your First Product
          </h1>
          <p class="text-gray-500">
            You can add products now or skip and do it later from your dashboard.
          </p>

          <div class="space-y-4 text-left">
            <div>
              <label for="product_name" class="block text-sm font-medium text-gray-700 mb-1">
                Product name
              </label>
              <input
                type="text"
                id="product_name"
                name="product_name"
                value={@product_name}
                placeholder="e.g. Ankara Dress"
                phx-change="update_product"
                phx-debounce="300"
                class="w-full bg-white border border-gray-300 rounded-lg px-4 py-3 text-sm text-gray-900 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
            </div>

            <div>
              <label for="product_price" class="block text-sm font-medium text-gray-700 mb-1">
                Price ({@currency})
              </label>
              <input
                type="number"
                id="product_price"
                name="product_price"
                value={@product_price}
                placeholder="e.g. 150"
                min="0"
                step="0.01"
                phx-change="update_product"
                phx-debounce="300"
                class="w-full bg-white border border-gray-300 rounded-lg px-4 py-3 text-sm text-gray-900 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
            </div>
          </div>

          <p class="text-xs text-gray-400">
            Don't worry — you can add unlimited products later.
          </p>
        </div>

        <%!-- Step 3: You're Ready! --%>
        <div :if={@step == 3} class="space-y-6 text-center">
          <div class="w-20 h-20 rounded-full bg-emerald-50 flex items-center justify-center mx-auto">
            <svg
              class="w-10 h-10 text-emerald-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
              />
            </svg>
          </div>
          <h1 class="text-2xl sm:text-3xl font-extrabold text-gray-900">
            You're Ready!
          </h1>
          <p class="text-gray-500">
            Your store is set up. Time to start selling!
          </p>

          <div class="bg-white rounded-xl p-5 space-y-3 text-sm text-left border border-gray-200 shadow-sm">
            <div class="flex items-center gap-3">
              <svg
                class="w-5 h-5 text-emerald-500 flex-shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
                  clip-rule="evenodd"
                />
              </svg>
              <div>
                <span class="font-medium text-gray-900">{@store_name}</span>
                <span class="text-gray-400 text-xs ml-2">{@currency}</span>
              </div>
            </div>
            <div :if={@product_name != ""} class="flex items-center gap-3">
              <svg
                class="w-5 h-5 text-emerald-500 flex-shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
                  clip-rule="evenodd"
                />
              </svg>
              <div>
                <span class="font-medium text-gray-900">{@product_name}</span>
                <span :if={@product_price != ""} class="text-gray-400 text-xs ml-2">
                  {format_price(@product_price, @currency)}
                </span>
              </div>
            </div>
            <div :if={@product_name == ""} class="flex items-center gap-3">
              <svg class="w-5 h-5 text-gray-300 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zM6.75 9.25a.75.75 0 000 1.5h6.5a.75.75 0 000-1.5h-6.5z"
                  clip-rule="evenodd"
                />
              </svg>
              <span class="text-gray-400">No products yet — you can add them later</span>
            </div>
          </div>
        </div>

        <%!-- Navigation --%>
        <div class="flex justify-between items-center">
          <button
            :if={@step > 1}
            phx-click="prev_step"
            class="flex items-center gap-1 px-4 py-2 text-sm font-medium text-gray-500 hover:text-gray-900 transition-colors"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
            </svg>
            Back
          </button>
          <div :if={@step == 1}></div>

          <div class="flex items-center gap-3">
            <button
              :if={@step == 2}
              phx-click="skip_step"
              class="px-4 py-2 text-sm font-medium text-gray-500 hover:text-gray-900 transition-colors"
            >
              Skip for now
            </button>
            <button
              phx-click={if @step < @total_steps, do: "next_step", else: "complete"}
              disabled={@step == 1 and String.trim(@store_name) == ""}
              class={[
                "font-semibold px-6 py-2.5 rounded-lg text-sm flex items-center gap-2 transition-all",
                if(@step == 1 and String.trim(@store_name) == "",
                  do: "bg-gray-100 text-gray-400 cursor-not-allowed",
                  else: "bg-emerald-600 text-white hover:bg-emerald-700 active:scale-95 shadow-sm"
                )
              ]}
            >
              {step_button_label(@step, @total_steps)}
              <svg
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="2"
                stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Events ──

  def handle_event("update_store_name", %{"store_name" => name}, socket) do
    slug = generate_slug(name)
    {:noreply, assign(socket, store_name: name, store_slug: slug, error: nil)}
  end

  def handle_event("update_currency", %{"currency" => currency}, socket) do
    {:noreply, assign(socket, currency: currency)}
  end

  def handle_event("update_product", params, socket) do
    product_name = params["product_name"] || socket.assigns.product_name
    product_price = params["product_price"] || socket.assigns.product_price

    {:noreply, assign(socket, product_name: product_name, product_price: product_price)}
  end

  def handle_event("next_step", _, socket) do
    case validate_step(socket.assigns.step, socket.assigns) do
      :ok ->
        next = min(socket.assigns.step + 1, socket.assigns.total_steps)

        if next == socket.assigns.total_steps do
          # Moving to final step — create the store
          case create_store(socket.assigns) do
            {:ok, store} ->
              {:noreply,
               socket
               |> assign(error: nil, step: next, created_store: store)}

            {:error, reason} ->
              {:noreply, assign(socket, error: "Setup failed: #{reason}")}
          end
        else
          {:noreply, socket |> assign(error: nil, step: next)}
        end

      {:error, msg} ->
        {:noreply, assign(socket, error: msg)}
    end
  end

  def handle_event("skip_step", _, socket) do
    # Skip clears product fields and advances
    socket = assign(socket, product_name: "", product_price: "")
    # Move to final step — create the store
    case create_store(socket.assigns) do
      {:ok, store} ->
        {:noreply,
         socket
         |> assign(error: nil, step: socket.assigns.total_steps, created_store: store)}

      {:error, reason} ->
        {:noreply, assign(socket, error: "Setup failed: #{reason}")}
    end
  end

  def handle_event("prev_step", _, socket) do
    {:noreply, update(socket, :step, &max(&1 - 1, 1))}
  end

  def handle_event("complete", _, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Welcome to Emakola! Your store is ready.")
     |> push_navigate(to: "/dashboard")}
  end

  # ── Private helpers ──

  defp resolve_user(session) do
    case session["user_token"] do
      nil ->
        nil

      token ->
        # Try Merchant first (primary auth for ecommerce), fall back to User
        case AshAuthentication.subject_to_user(token, Emakola.Accounts.Merchant) do
          {:ok, merchant} ->
            merchant

          _ ->
            case AshAuthentication.subject_to_user(token, Emakola.Accounts.User) do
              {:ok, user} -> user
              _ -> nil
            end
        end
    end
  end

  defp user_type(%Emakola.Accounts.Merchant{}), do: :merchant
  defp user_type(%Emakola.Accounts.User{}), do: :user
  defp user_type(_), do: nil

  defp has_store_membership?(user) do
    case user_type(user) do
      :merchant ->
        case Emakola.Accounts.StoreMembership
             |> Ash.Query.filter(merchant_id: user.id)
             |> Ash.Query.limit(1)
             |> Ash.read() do
          {:ok, [_ | _]} -> true
          _ -> false
        end

      :user ->
        case Emakola.Accounts.Membership
             |> Ash.Query.filter(user_id: user.id)
             |> Ash.Query.limit(1)
             |> Ash.read() do
          {:ok, [_ | _]} -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  defp validate_step(1, assigns) do
    if String.trim(assigns.store_name) == "",
      do: {:error, "Please enter a store name."},
      else: :ok
  end

  defp validate_step(_, _), do: :ok

  defp generate_slug(name) do
    name
    |> String.trim()
    |> Slug.slugify()
    |> case do
      nil -> ""
      slug -> slug
    end
  end

  defp create_store(assigns) do
    user = assigns.current_user

    if is_nil(user) do
      {:error, "You must be logged in to create a store."}
    else
      store_name = String.trim(assigns.store_name)
      slug = generate_slug(store_name)
      currency = assigns.currency

      with {:ok, store} <-
             Emakola.Accounts.Store
             |> Ash.Changeset.for_create(:create, %{
               name: store_name,
               slug: slug,
               currency: currency
             })
             |> Ash.create(),
           {:ok, _membership} <- create_membership_for_user(user, store) do
        maybe_create_product(assigns, store)
        {:ok, store}
      else
        {:error, %Ash.Error.Invalid{} = error} ->
          {:error, Exception.message(error)}

        {:error, error} when is_binary(error) ->
          {:error, error}

        {:error, error} ->
          {:error, inspect(error)}
      end
    end
  end

  defp create_membership_for_user(%Emakola.Accounts.Merchant{} = merchant, store) do
    Emakola.Accounts.StoreMembership
    |> Ash.Changeset.for_create(:create, %{
      role: :owner,
      merchant_id: merchant.id,
      store_id: store.id
    })
    |> Ash.create()
  end

  defp create_membership_for_user(%Emakola.Accounts.User{} = user, store) do
    # For legacy User accounts, create an Organisation membership
    # as the current system still uses Org-based membership for Users
    with {:ok, org} <-
           Emakola.Accounts.Organisation
           |> Ash.Changeset.for_create(:create, %{name: store.name})
           |> Ash.create(),
         {:ok, membership} <-
           Emakola.Accounts.Membership
           |> Ash.Changeset.for_create(:create, %{
             role: :owner,
             user_id: user.id,
             organisation_id: org.id
           })
           |> Ash.create() do
      {:ok, membership}
    end
  end

  defp maybe_create_product(assigns, store) do
    product_name = String.trim(assigns.product_name || "")

    if product_name != "" do
      price = parse_price(assigns.product_price)

      Emakola.Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        title: product_name,
        store_id: store.id
      })
      |> Ash.create()
      |> case do
        {:ok, product} when price > 0 ->
          # Create a default variant with the price
          Emakola.Catalog.Variant
          |> Ash.Changeset.for_create(:create, %{
            price: price,
            product_id: product.id,
            store_id: store.id
          })
          |> Ash.create()

        _ ->
          :ok
      end
    end
  end

  defp parse_price(price) when is_binary(price) do
    case Float.parse(price) do
      {amount, _} when amount > 0 -> round(amount * 100)
      _ -> 0
    end
  end

  defp parse_price(_), do: 0

  defp format_price(price_str, currency) do
    case Float.parse(price_str) do
      {amount, _} ->
        symbol =
          case currency do
            "GHS" -> "GH\u20B5"
            "NGN" -> "\u20A6"
            "USD" -> "$"
            _ -> currency
          end

        "#{symbol}#{:erlang.float_to_binary(amount, decimals: 2)}"

      _ ->
        ""
    end
  end

  defp step_button_label(step, total_steps) when step < total_steps, do: "Continue"
  defp step_button_label(_, _), do: "Go to Dashboard"
end
