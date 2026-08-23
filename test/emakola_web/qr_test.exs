defmodule EmakolaWeb.QRTest do
  @moduledoc """
  The single source of QR payloads and QR SVG markup.

  Two properties matter more than the rendering itself:

    * **Payloads are composed from config, never from a caller-supplied string.**
      A QR code is an opaque instruction a buyer's phone obeys without reading it,
      so a module that would encode an arbitrary string turns Makola into a
      phishing redirector. The guard is structural — there is no public arity that
      accepts a bare URL — and the tests below assert that shape, not just the
      happy path.

    * **Payloads are absolute and apex-pinned.** A printed poster outlives the
      session that rendered it, so the host has to come from config
      (`EmakolaWeb.SEO.Canonical`) rather than from whichever host served the
      LiveView.
  """
  use ExUnit.Case, async: false

  import Phoenix.HTML, only: [safe_to_string: 1]

  alias EmakolaWeb.QR
  alias EmakolaWeb.SEO.Canonical

  setup do
    previous = Application.get_env(:emakola, :store_subdomain_base)
    Application.delete_env(:emakola, :store_subdomain_base)

    on_exit(fn ->
      if previous, do: Application.put_env(:emakola, :store_subdomain_base, previous)
    end)

    {:ok,
     base: EmakolaWeb.Endpoint.url(),
     store: %{slug: "kente-shop"},
     pay_link: %{code: "PAY7X2K"},
     susu_plan: %{code: "SUSU4M9"},
     order: %{order_number: "1001"}}
  end

  describe "payload URLs" do
    test "pay_link_url points at the apex /pay/:code route", %{base: base, pay_link: link} do
      assert QR.pay_link_url(link) == base <> "/pay/PAY7X2K"
    end

    test "susu_url points at the apex /susu/:code route", %{base: base, susu_plan: plan} do
      assert QR.susu_url(plan) == base <> "/susu/SUSU4M9"
    end

    test "store_url is the store's canonical home", %{base: base, store: store} do
      assert QR.store_url(store) == base <> "/s/kente-shop"
    end

    test "order_tracking_url is store-scoped", %{base: base, store: store, order: order} do
      assert QR.order_tracking_url(store, order) == base <> "/s/kente-shop/track/1001"
    end

    test "store payloads follow Canonical onto subdomains once those go live", %{
      store: store,
      order: order
    } do
      Application.put_env(:emakola, :store_subdomain_base, "makola.io")
      on_exit(fn -> Application.delete_env(:emakola, :store_subdomain_base) end)

      assert QR.store_url(store) == Canonical.store_url(store)
      assert QR.order_tracking_url(store, order) == Canonical.path(store, "/track/1001")
    end

    test "pay and susu payloads stay on the apex even when a subdomain base is set", %{
      base: base,
      pay_link: link,
      susu_plan: plan
    } do
      Application.put_env(:emakola, :store_subdomain_base, "makola.io")
      on_exit(fn -> Application.delete_env(:emakola, :store_subdomain_base) end)

      # /pay/:code and /susu/:code are host: @apex_hosts scoped — a subdomain
      # cannot serve them, so the payload must not follow the store there.
      assert QR.pay_link_url(link) == base <> "/pay/PAY7X2K"
      assert QR.susu_url(plan) == base <> "/susu/SUSU4M9"
    end

    test "every payload is absolute", %{
      store: store,
      pay_link: link,
      susu_plan: plan,
      order: order
    } do
      for url <- [
            QR.pay_link_url(link),
            QR.susu_url(plan),
            QR.store_url(store),
            QR.order_tracking_url(store, order)
          ] do
        assert %URI{scheme: scheme, host: host} = URI.parse(url)
        assert scheme in ["http", "https"]
        assert is_binary(host)
      end
    end
  end

  describe "SVG rendering" do
    test "each renderer returns already-safe SVG markup", %{
      store: store,
      pay_link: link,
      susu_plan: plan,
      order: order
    } do
      for safe <- [
            QR.pay_link_svg(link),
            QR.susu_svg(plan),
            QR.store_svg(store),
            QR.order_tracking_svg(store, order)
          ] do
        # Safe HTML, not a bare string: templates interpolate it directly, so no
        # call site has to reach for raw/1 and thereby vouch for markup it did
        # not build.
        assert {:safe, _} = safe
        assert safe_to_string(safe) =~ "<svg"
      end
    end

    test "the root svg element is viewBox-scaled, carrying no fixed pixel size", %{store: store} do
      # Scoped to the opening <svg> tag: the module's own <rect> cells each carry
      # width="1" height="1" in matrix units, which is unrelated to how the code
      # sizes on screen.
      [root_tag] = Regex.run(~r/<svg [^>]*>/, safe_to_string(QR.store_svg(store)))

      # A QR has to render on a cheap phone screen and on a printed poster from
      # the same markup, so it sizes to its container via CSS rather than baking
      # in a pixel width.
      assert root_tag =~ "viewBox="
      refute root_tag =~ ~s(width=")
      refute root_tag =~ ~s(height=")
    end

    test "a CSS class can be applied for sizing at the call site", %{store: store} do
      assert safe_to_string(QR.store_svg(store, class: "w-40 h-40")) =~ ~s(class="w-40 h-40")
    end

    test "a class that could break out of the attribute is refused", %{store: store} do
      # EQRCode interpolates :id and :class into the markup without escaping
      # (EQRCode.SVG builds `key="val"` by hand), and this output is rendered
      # with raw/1. Rejecting outright beats sanitising: every legitimate value
      # is a CSS class list, so anything else is a caller bug worth surfacing.
      assert_raise ArgumentError, fn ->
        QR.store_svg(store, class: ~s|w-40" onload="steal()|)
      end

      assert_raise ArgumentError, fn -> QR.store_svg(store, id: ~s|x"><script>|) end
    end

    test "distinct payloads produce distinct markup", %{pay_link: link} do
      refute safe_to_string(QR.pay_link_svg(link)) ==
               safe_to_string(QR.pay_link_svg(%{code: "PAYOTHER"}))
    end
  end

  describe "structural guard against arbitrary payloads" do
    test "no public function accepts a bare URL string" do
      # The safety property is enforced by the module's shape, not by reviewer
      # discipline at each call site: every public entry point takes a resource
      # and builds the URL itself. A binary matches no clause.
      for {name, arity} <- QR.__info__(:functions) do
        args = List.duplicate("https://evil.example/phish", arity)

        assert_raise FunctionClauseError, fn -> apply(QR, name, args) end
      end
    end

    # There is deliberately no case here passing a *literal* string, e.g.
    # `QR.store_svg("https://evil.example")`. Under the type checker that is a
    # compile-time warning ("expected a map, got binary"), and CI compiles tests
    # with --warnings-as-errors — so such a call cannot reach runtime to be
    # asserted against. The compiler enforcing the guard is the stronger
    # outcome; the dynamic `apply/3` case above covers the rest.
  end
end
