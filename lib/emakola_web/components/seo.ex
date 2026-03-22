defmodule EmakolaWeb.SEO do
  use Phoenix.Component

  @default_meta %{
    title: "Emakola — Ship Your SaaS in Days, Not Months",
    description:
      "Production-ready Phoenix SaaS boilerplate with AI agents, Stripe billing, team management, and beautiful dark/light UI. Built on Elixir, Ash Framework, and LiveView.",
    image: "/images/og-image.png",
    url: "https://founderpad.io",
    type: "website",
    twitter_card: "summary_large_image",
    twitter_site: "@founderpad"
  }

  def meta_tags(assigns) do
    meta = Map.merge(@default_meta, Map.new(assigns))

    json_ld =
      Jason.encode!(%{
        "@context" => "https://schema.org",
        "@type" => "SoftwareApplication",
        "name" => "Emakola",
        "description" => meta.description,
        "applicationCategory" => "DeveloperApplication",
        "operatingSystem" => "Web",
        "offers" => %{
          "@type" => "AggregateOffer",
          "lowPrice" => "0",
          "highPrice" => "199",
          "priceCurrency" => "USD",
          "offerCount" => "4"
        }
      })

    assigns = assign(assigns, meta: meta, json_ld: json_ld)

    ~H"""
    <meta name="description" content={@meta.description} />
    <meta name="robots" content="index, follow" />
    <link rel="canonical" href={@meta.url} />

    <meta property="og:type" content={@meta.type} />
    <meta property="og:title" content={@meta.title} />
    <meta property="og:description" content={@meta.description} />
    <meta property="og:image" content={@meta.image} />
    <meta property="og:url" content={@meta.url} />
    <meta property="og:site_name" content="Emakola" />

    <meta name="twitter:card" content={@meta.twitter_card} />
    <meta name="twitter:site" content={@meta.twitter_site} />
    <meta name="twitter:title" content={@meta.title} />
    <meta name="twitter:description" content={@meta.description} />
    <meta name="twitter:image" content={@meta.image} />

    <script type="application/ld+json">
      {raw(@json_ld)}
    </script>
    """
  end
end
