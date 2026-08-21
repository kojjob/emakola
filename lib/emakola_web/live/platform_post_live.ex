defmodule EmakolaWeb.PlatformPostLive do
  @moduledoc """
  A single Makola blog article at makola.io/blog/:post_slug. Renders the
  sanitized HTML body with editorial typography, BlogPosting JSON-LD, and
  a merchant-acquisition CTA band.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.CompanyComponents, only: [cta_band: 1]
  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]

  alias EmakolaWeb.Helpers.SEO

  @impl true
  def mount(%{"post_slug" => slug}, _session, socket) do
    case Emakola.Content.get_platform_post_by_slug(slug) do
      {:ok, post} ->
        canonical = url(~p"/blog/#{post.slug}")

        {:ok,
         assign(socket,
           post: post,
           video_path: video_path(post.slug),
           safe_body: Emakola.Content.HtmlSafe.sanitize(post.body),
           reading_time: reading_time(post.body),
           page_title: "#{post.seo_title || post.title} — Makola",
           meta_description: post.seo_description || post.excerpt,
           og_image: absolute_image_url(post.featured_image_url),
           canonical_url: canonical,
           json_ld: [
             article_json_ld(post, canonical),
             SEO.json_ld_breadcrumb([
               %{name: "Home", url: url(~p"/")},
               %{name: "Blog", url: url(~p"/blog")},
               %{name: post.title, url: canonical}
             ])
           ]
         ), layout: false}

      {:error, _} ->
        {:ok, push_navigate(socket, to: ~p"/blog")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant={:plain}>
      <div class="min-h-screen bg-white font-body antialiased">
        <.landing_nav />
        <main class="pt-16">
          <article class="py-16 px-4">
            <div class="max-w-3xl mx-auto">
              <.link
                navigate={~p"/blog"}
                class="text-sm text-[#2563eb] font-medium hover:underline"
              >
                <span aria-hidden="true">&larr;</span> All guides
              </.link>
              <h1 class="text-3xl lg:text-4xl font-headline font-bold text-[#0c1526] mt-6">
                {@post.title}
              </h1>
              <div class="flex items-center gap-3 mt-5 pb-5 border-b border-[#d4a843]/40 text-sm text-[#5f6b7a]">
                <span :if={@post.published_at}>
                  {Calendar.strftime(@post.published_at, "%d/%m/%Y")}
                </span>
                <span aria-hidden="true" class="text-[#d4a843]">&middot;</span>
                <span>{@reading_time} min read</span>
              </div>
            </div>
            <%!-- A shipped clip replaces the hero image: tap-to-play with the hero
            as poster, preload="none" so low-bandwidth readers pay nothing until
            they choose to watch. --%>
            <div :if={@video_path} class="max-w-4xl mx-auto mt-10">
              <video
                controls
                preload="none"
                playsinline
                poster={@post.featured_image_url}
                class="w-full rounded-2xl object-cover aspect-[16/9] bg-[#0c1526]"
              >
                <source src={@video_path} type="video/mp4" />
              </video>
            </div>
            <div :if={is_nil(@video_path) && @post.featured_image_url} class="max-w-4xl mx-auto mt-10">
              <img
                src={@post.featured_image_url}
                alt={@post.title}
                class="w-full rounded-2xl object-cover aspect-[16/9]"
              />
            </div>
            <div class={[
              "max-w-3xl mx-auto mt-10 text-[#374151] leading-relaxed",
              "[&_h2]:font-headline [&_h2]:font-bold [&_h2]:text-2xl [&_h2]:text-[#0c1526] [&_h2]:mt-12 [&_h2]:mb-4",
              "[&_h3]:font-headline [&_h3]:font-semibold [&_h3]:text-xl [&_h3]:text-[#0c1526] [&_h3]:mt-8 [&_h3]:mb-3",
              "[&_p]:my-4 [&_ul]:my-4 [&_ul]:list-disc [&_ul]:pl-6 [&_ol]:my-4 [&_ol]:list-decimal [&_ol]:pl-6 [&_li]:my-1.5",
              "[&_a]:text-[#2563eb] [&_a]:font-medium hover:[&_a]:underline",
              "[&_blockquote]:border-l-2 [&_blockquote]:border-[#d4a843] [&_blockquote]:pl-4 [&_blockquote]:italic [&_blockquote]:text-[#5f6b7a]",
              "[&_img]:rounded-xl [&_img]:my-8",
              "[&_table]:w-full [&_table]:my-8 [&_table]:text-sm [&_th]:text-left [&_th]:font-semibold [&_th]:text-[#0c1526] [&_th]:border-b [&_th]:border-[#0c1526]/20 [&_th]:py-2 [&_th]:pr-4 [&_td]:border-b [&_td]:border-[#e5e8ee] [&_td]:py-2 [&_td]:pr-4 [&_td]:align-top",
              "[&_hr]:my-10 [&_hr]:border-[#e5e8ee]"
            ]}>
              {@safe_body}
            </div>
          </article>
          <.cta_band
            title="Ready to sell online?"
            subtitle="Open your free Makola store — mobile money payments and WhatsApp order updates from day one."
            primary_label="Start selling free"
            primary_href="/auth/register"
            secondary_label="See pricing"
            secondary_href="/pricing"
          />
        </main>
        <.landing_footer />
      </div>
    </Layouts.app>
    """
  end

  # A post gets a hero clip by shipping priv/static/videos/blog/<slug>.mp4 —
  # convention over schema, so content and code stay decoupled.
  defp video_path(slug) do
    file = Path.join([:code.priv_dir(:emakola), "static", "videos", "blog", "#{slug}.mp4"])

    if File.exists?(file), do: "/videos/blog/#{slug}.mp4"
  end

  defp reading_time(nil), do: 1

  defp reading_time(body) do
    words = body |> String.split(~r/\s+/) |> length()
    max(1, div(words, 200))
  end

  defp absolute_image_url(nil), do: url(~p"/images/og-image.png")

  defp absolute_image_url("/" <> _ = path), do: EmakolaWeb.Endpoint.url() <> path

  defp absolute_image_url(absolute_url), do: absolute_url

  defp article_json_ld(post, canonical) do
    %{
      "@context" => "https://schema.org",
      "@type" => "BlogPosting",
      "headline" => post.title,
      "url" => canonical,
      "description" => post.seo_description || post.excerpt,
      "image" => absolute_image_url(post.featured_image_url),
      "author" => %{"@type" => "Organization", "name" => "Makola"},
      "publisher" => %{"@type" => "Organization", "name" => "Makola"}
    }
    |> then(fn json_ld ->
      case post.published_at do
        nil -> json_ld
        published_at -> Map.put(json_ld, "datePublished", DateTime.to_iso8601(published_at))
      end
    end)
  end
end
