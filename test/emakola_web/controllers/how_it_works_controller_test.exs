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
end
