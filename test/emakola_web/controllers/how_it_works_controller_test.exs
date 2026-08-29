defmodule EmakolaWeb.HowItWorksControllerTest do
  use EmakolaWeb.ConnCase, async: true

  test "GET /how-it-works renders the visual market story", %{conn: conn} do
    html = conn |> get("/how-it-works") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert document |> LazyHTML.query("#how-it-works-page") |> Enum.any?()
    assert document |> LazyHTML.query("#market-flow") |> Enum.any?()
    assert document |> LazyHTML.query("#sale-journey") |> Enum.any?()
    assert document |> LazyHTML.query("#money-split") |> Enum.any?()
    assert document |> LazyHTML.query("#stakeholders") |> Enum.any?()
    assert document |> LazyHTML.query("#trust-machinery") |> Enum.any?()
    assert document |> LazyHTML.query("#how-it-works-cta") |> Enum.any?()

    assert document |> LazyHTML.query("[data-sale-step]") |> Enum.count() == 5
  end

  test "shows the exact GH₵85 example and its three-way settlement", %{conn: conn} do
    document =
      conn
      |> get("/how-it-works")
      |> html_response(200)
      |> LazyHTML.from_document()

    money_split = document |> LazyHTML.query("#money-split") |> LazyHTML.text()

    assert money_split =~ "GH₵85"
    assert money_split =~ "GH₵48"
    assert money_split =~ "GH₵36.56"
    assert money_split =~ "GH₵0.44"
    assert money_split =~ "Kumasi Textiles"
    assert money_split =~ "Adwoa's Boutique"
  end

  test "uses responsive imagery, icons, and motion with a reduced-motion fallback", %{
    conn: conn
  } do
    html = conn |> get("/how-it-works") |> html_response(200)
    document = LazyHTML.from_document(html)

    assert document
           |> LazyHTML.query(~s(link[rel="preload"][href*="hero-market-woman.jpg"]))
           |> Enum.any?()

    assert document |> LazyHTML.query(~s(img[loading="lazy"])) |> Enum.count() >= 4
    assert document |> LazyHTML.query(~s(span[class*="hero-"])) |> Enum.count() >= 12
    assert document |> LazyHTML.query("[data-scroll-reveal]") |> Enum.any?()
    assert document |> LazyHTML.query(".market-flow-dot") |> Enum.any?()
  end

  test "marketing navigation links to the full explainer", %{conn: conn} do
    document =
      conn
      |> get("/")
      |> html_response(200)
      |> LazyHTML.from_document()

    assert document |> LazyHTML.query(~s(a[href="/how-it-works"])) |> Enum.count() >= 2
  end

  describe "GET /how-it-works/tour" do
    test "renders the scroll film with its six scenes", %{conn: conn} do
      html = conn |> get("/how-it-works/tour") |> html_response(200)
      document = LazyHTML.from_document(html)

      assert document |> LazyHTML.query("#tour-world") |> Enum.any?()
      assert document |> LazyHTML.query(~s(script[src="/tour/scrub-engine.js"])) |> Enum.any?()
      assert document |> LazyHTML.query(~s(script[src="/tour/tour.js"])) |> Enum.any?()

      # The film config is a static asset; the six scenes and their posters live there.
      config = File.read!("priv/static/tour/tour.js")
      assert config =~ "mountScrollWorld"

      for scene <- ~w(workshop shop checkout delivery split finale) do
        assert config =~ "/tour/#{scene}.webp"
      end
    end

    test "serves the story as semantic HTML for agents and no-JS browsers", %{conn: conn} do
      document =
        conn
        |> get("/how-it-works/tour")
        |> html_response(200)
        |> LazyHTML.from_document()

      assert document |> LazyHTML.query("#tour-world h1") |> Enum.any?()
      assert document |> LazyHTML.query("#tour-world section h2") |> Enum.count() == 6
      assert document |> LazyHTML.query(~s(#tour-world a[href="/auth/register"])) |> Enum.any?()
    end

    test "marketing navigation links to the tour", %{conn: conn} do
      document =
        conn
        |> get("/")
        |> html_response(200)
        |> LazyHTML.from_document()

      assert document |> LazyHTML.query(~s(a[href="/how-it-works/tour"])) |> Enum.count() >= 2
    end

    test "the explainer hero points its watch button at the tour", %{conn: conn} do
      document =
        conn
        |> get("/how-it-works")
        |> html_response(200)
        |> LazyHTML.from_document()

      assert document |> LazyHTML.query(~s(a[href="/how-it-works/tour"])) |> Enum.any?()
      refute document |> LazyHTML.query(~s(a[href="#sale-journey"])) |> Enum.any?()
    end
  end
end
