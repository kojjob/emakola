defmodule EmakolaWeb.Api.ProductController do
  @moduledoc """
  Merchant product writes for the mobile app — create a product, add a variant,
  attach a photo.

  These are plain controllers rather than ash_json_api routes on purpose.
  Routes declared in a resource's `json_api` block are mounted by *every*
  router that includes the domain, and `EmakolaWeb.ShopApiRouter` mounts
  `Emakola.Catalog` on the public, unauthenticated storefront surface — a
  `post(:create)` there would route product creation on the public API and
  advertise it in the storefront's OpenAPI document. Policies would still
  refuse it, but it should not be reachable at all.

  `store_id` is always taken from the `X-Store-ID` tenant that
  `EmakolaWeb.Plugs.ApiTenant` resolved, never from the request body, so a
  merchant cannot write into a store they have no membership in.
  """
  use EmakolaWeb, :controller

  alias Emakola.Catalog

  # Mirrors Catalog.Image's own validation. Checked before the bytes are sent
  # to storage so a rejected upload never leaves an orphan object behind.
  # Content type is the single source of truth for both validation and the
  # stored object's extension — the client-supplied filename never reaches the
  # storage key, so it cannot shape the path.
  @extensions_by_content_type %{
    "image/jpeg" => ".jpg",
    "image/png" => ".png",
    "image/webp" => ".webp"
  }
  @accepted_content_types Map.keys(@extensions_by_content_type)
  @max_file_size_bytes 10_000_000

  @doc """
  Creates a product and, when a price is supplied, the default variant that
  makes it sellable — then activates it.

  One request, because the photo-first flow publishes a batch of products from
  a phone and should not need three round trips per product on a mobile
  network. Without a price the product is left as a draft: activation requires
  a variant to sell.
  """
  def create(conn, params) do
    actor = Ash.PlugHelpers.get_actor(conn)
    tenant = Ash.PlugHelpers.get_tenant(conn)
    title = params |> Map.get("title", "") |> to_string() |> String.trim()
    # store_id is the tenant ApiTenant resolved from X-Store-ID and verified
    # membership for — params are never consulted for it.

    with :ok <- validate_present(title, "title"),
         {:ok, price} <- optional_price(params["price"]),
         {:ok, product} <-
           Catalog.create_product(%{title: title, store_id: tenant},
             actor: actor,
             tenant: tenant
           ),
         {:ok, variant} <- maybe_default_variant(product, price, actor, tenant),
         {:ok, product} <- maybe_activate(product, variant, actor, tenant) do
      conn
      |> put_status(:created)
      |> json(%{data: render_product(product, variant)})
    else
      {:error, reason} -> render_error(conn, reason)
    end
  end

  @doc """
  Adds a variant to one of the merchant's own products.
  """
  def create_variant(conn, %{"id" => product_id} = params) do
    actor = Ash.PlugHelpers.get_actor(conn)
    tenant = Ash.PlugHelpers.get_tenant(conn)

    with {:ok, product} <- fetch_own_product(product_id, actor, tenant),
         {:ok, price} <- required_price(params["price"]),
         attrs = variant_attrs(product, price, params),
         {:ok, variant} <- Catalog.create_variant(attrs, actor: actor, tenant: tenant) do
      conn
      |> put_status(:created)
      |> json(%{data: render_variant(variant)})
    else
      {:error, reason} -> render_error(conn, reason)
    end
  end

  @doc """
  Uploads a photo to storage and records it against the product.

  Multipart through the app server rather than a presigned upload direct to
  object storage: `Emakola.Storage` swaps adapters and dev/test run the local
  one, so a presigned flow would need a parallel local implementation and would
  diverge dev from production. It is also one round trip rather than three,
  which matters more than the proxy hop on the connections this serves.
  """
  def create_image(conn, %{"id" => product_id, "file" => %Plug.Upload{} = upload}) do
    actor = Ash.PlugHelpers.get_actor(conn)
    tenant = Ash.PlugHelpers.get_tenant(conn)

    with {:ok, product} <- fetch_own_product(product_id, actor, tenant),
         {:ok, binary} <- read_upload(upload),
         :ok <- validate_content_type(upload.content_type),
         :ok <- validate_size(binary),
         {:ok, url} <- store_upload(binary, product, upload),
         {:ok, image} <-
           Catalog.create_image(
             %{
               url: url,
               content_type: upload.content_type,
               file_size_bytes: byte_size(binary),
               product_id: product.id,
               store_id: product.store_id
             },
             actor: actor,
             tenant: tenant
           ) do
      conn
      |> put_status(:created)
      |> json(%{data: render_image(image)})
    else
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def create_image(conn, _params),
    do: error(conn, 422, "missing_file", "a `file` part is required")

  # -- product creation steps ------------------------------------------------

  defp maybe_default_variant(_product, nil, _actor, _tenant), do: {:ok, nil}

  defp maybe_default_variant(product, price, actor, tenant) do
    attrs = %{
      product_id: product.id,
      store_id: product.store_id,
      price: price,
      # Sellable immediately: a merchant listing from their phone wants to sell,
      # not to count stock. Tracking is an opt-in they can turn on later.
      track_inventory: false,
      position: 0,
      sku: "SKU-" <> String.slice(Ecto.UUID.generate(), 0, 8)
    }

    case Catalog.create_variant(attrs, actor: actor, tenant: tenant) do
      {:ok, variant} -> {:ok, variant}
      {:error, reason} -> {:error, reason}
    end
  end

  # Activation requires something to sell, so a product created without a price
  # stays a draft rather than failing the whole request.
  defp maybe_activate(product, nil, _actor, _tenant), do: {:ok, product}

  defp maybe_activate(product, _variant, actor, tenant) do
    Catalog.activate_product(product, actor: actor, tenant: tenant)
  end

  # -- lookups ---------------------------------------------------------------

  # Reads through the tenant, so another store's product is simply not found —
  # the merchant learns nothing about whether that id exists.
  defp fetch_own_product(product_id, actor, tenant) do
    case Ash.get(Catalog.Product, product_id, actor: actor, tenant: tenant) do
      {:ok, product} -> {:ok, product}
      {:error, _} -> {:error, :not_found}
    end
  end

  # -- parsing and validation ------------------------------------------------

  defp validate_present("", field), do: {:error, {:blank, field}}
  defp validate_present(_value, _field), do: :ok

  defp optional_price(nil), do: {:ok, nil}
  defp optional_price(value), do: parse_price(value)

  defp required_price(nil), do: {:error, {:blank, "price"}}
  defp required_price(value), do: parse_price(value)

  defp parse_price(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_price(value) when is_binary(value) do
    case Integer.parse(value) do
      {price, ""} when price > 0 -> {:ok, price}
      _ -> {:error, {:invalid, "price"}}
    end
  end

  defp parse_price(_value), do: {:error, {:invalid, "price"}}

  defp validate_content_type(type) when type in @accepted_content_types, do: :ok
  defp validate_content_type(_type), do: {:error, :unsupported_content_type}

  defp validate_size(binary) when byte_size(binary) > @max_file_size_bytes,
    do: {:error, :file_too_large}

  defp validate_size(_binary), do: :ok

  # sobelow_skip ["Traversal.FileModule"]
  # False positive: `path` comes from a %Plug.Upload{} struct, which Plug's
  # parsers construct only for genuine multipart file parts — a JSON body
  # cannot forge a struct, so this is always Plug's own tmp-file path. The
  # action head additionally requires %Plug.Upload{} before calling here.
  defp read_upload(%Plug.Upload{path: path}) do
    case File.read(path) do
      {:ok, binary} -> {:ok, binary}
      {:error, _} -> {:error, :unreadable_file}
    end
  end

  defp store_upload(binary, product, %Plug.Upload{} = upload) do
    extension = Map.fetch!(@extensions_by_content_type, upload.content_type)

    key =
      Path.join([
        "stores",
        product.store_id,
        "products",
        product.id,
        Ecto.UUID.generate() <> extension
      ])

    Emakola.Storage.upload(binary, key, content_type: upload.content_type)
  end

  defp variant_attrs(product, price, params) do
    %{
      product_id: product.id,
      store_id: product.store_id,
      price: price,
      track_inventory: false,
      position: 0
    }
    |> put_optional(:sku, params["sku"])
    |> put_optional(:barcode, params["barcode"])
  end

  defp put_optional(attrs, _key, nil), do: attrs
  defp put_optional(attrs, _key, ""), do: attrs
  defp put_optional(attrs, key, value), do: Map.put(attrs, key, value)

  # -- rendering -------------------------------------------------------------

  defp render_product(product, variant) do
    %{
      id: product.id,
      title: product.title,
      slug: product.slug,
      status: to_string(product.status),
      default_variant: variant && render_variant(variant)
    }
  end

  defp render_variant(variant) do
    %{
      id: variant.id,
      price: variant.price,
      sku: variant.sku,
      track_inventory: variant.track_inventory
    }
  end

  defp render_image(image) do
    %{
      id: image.id,
      url: image.url,
      content_type: image.content_type,
      file_size_bytes: image.file_size_bytes
    }
  end

  defp render_error(conn, :not_found),
    do: error(conn, 404, "not_found", "no such product in this store")

  defp render_error(conn, :unsupported_content_type),
    do:
      error(
        conn,
        422,
        "unsupported_content_type",
        "images must be one of #{Enum.join(@accepted_content_types, ", ")}"
      )

  defp render_error(conn, :file_too_large),
    do: error(conn, 422, "file_too_large", "images must be under 10MB")

  defp render_error(conn, :unreadable_file),
    do: error(conn, 422, "unreadable_file", "the uploaded file could not be read")

  defp render_error(conn, {:blank, field}),
    do: error(conn, 422, "missing_params", "#{field} is required")

  defp render_error(conn, {:invalid, field}),
    do: error(conn, 422, "invalid_params", "#{field} is not valid")

  defp render_error(conn, %Ash.Error.Forbidden{}),
    do: error(conn, 403, "forbidden", "not permitted for this store")

  defp render_error(conn, %Ash.Error.Invalid{} = invalid),
    do: error(conn, 422, "invalid_params", Exception.message(invalid))

  defp render_error(conn, _other),
    do: error(conn, 422, "invalid_params", "the request could not be completed")

  defp error(conn, status, code, detail) do
    conn
    |> put_status(status)
    |> json(%{errors: [%{status: to_string(status), code: code, detail: detail}]})
  end
end
