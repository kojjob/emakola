# Block URL Sanitization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Neutralize merchant-controlled URLs at the block-render boundary so `javascript:`/`data:` values can never reach `href`/`src` on a storefront — closing both the pre-existing page-editor path and the section block-bridge path (the security gate for the editor PR).

**Architecture:** One pure helper (`Emakola.PageBuilder.SafeUrl.safe_url/1` — http(s) or site-relative passes, everything else becomes `nil`) applied at the nine URL sinks across five block modules. `nil` makes HEEx omit the attribute; block CTA fallbacks (`|| "/products"`) are preserved.

**Tech Stack:** Elixir/Phoenix 1.8, existing `Emakola.PageBuilder` block library. No deps, no migration.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-12-block-url-sanitization-design.md`.
- Scheme policy (exact): binary matching `~r{^https?://}i` after trim → pass unchanged; trimmed leading `//` → nil; trimmed leading `/` → pass; everything else (incl. non-binaries, "", bare-relative like `products`, `mailto:`, `tel:`) → nil.
- `video_embed/1`'s YouTube/Vimeo id-extraction branches are safe — do NOT touch them. Its direct-file branch (the `^https?://` / leading-`/` cond clauses) shares the backslash protocol-relative gap and MUST be routed through `SafeUrl.safe_url/1` (amended 2026-07-12 after Task-1 review).
- Legitimate URLs must render byte-identically (existing block/page/storefront suites unchanged).
- Gates before each commit: `mix format` (changed files), `mix compile --warnings-as-errors` clean for your files, `mix credo --strict` clean on your files, listed tests green — read the `Result:` line, never piped exit codes.
- Branch: `fix/block-url-sanitization` (exists, carries the spec).

---

### Task 1: SafeUrl helper

**Files:**
- Create: `lib/emakola/page_builder/safe_url.ex`
- Test: `test/emakola/page_builder/safe_url_test.exs`

**Interfaces:**
- Produces: `Emakola.PageBuilder.SafeUrl.safe_url(term()) :: String.t() | nil` (Task 2 wraps every sink with it).
- Consumes: nothing.

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Emakola.PageBuilder.SafeUrlTest do
  use ExUnit.Case, async: true

  import Emakola.PageBuilder.SafeUrl

  test "passes absolute http(s) and site-relative urls unchanged" do
    assert safe_url("https://wa.me/233201234567") == "https://wa.me/233201234567"
    assert safe_url("http://example.com/a?b=1") == "http://example.com/a?b=1"
    assert safe_url("HTTPS://EXAMPLE.COM/X") == "HTTPS://EXAMPLE.COM/X"
    assert safe_url("/products") == "/products"
    assert safe_url("/s/tiny-stitches/products/kente-tote") ==
             "/s/tiny-stitches/products/kente-tote"
  end

  test "rejects executable and non-http schemes" do
    assert safe_url("javascript:alert(1)") == nil
    assert safe_url("JAVASCRIPT:alert(1)") == nil
    assert safe_url("data:text/html;base64,PHNjcmlwdD4=") == nil
    assert safe_url("vbscript:msgbox") == nil
    assert safe_url("file:///etc/passwd") == nil
    assert safe_url("mailto:x@y.com") == nil
    assert safe_url("tel:+233200000000") == nil
  end

  test "rejects smuggling shapes" do
    assert safe_url("  javascript:alert(1)") == nil
    assert safe_url("jav\tascript:alert(1)") == nil
    assert safe_url("//evil.example.com") == nil
    assert safe_url("products") == nil
  end

  test "rejects non-binaries and blanks" do
    assert safe_url(nil) == nil
    assert safe_url(123) == nil
    assert safe_url(%{}) == nil
    assert safe_url("") == nil
    assert safe_url("   ") == nil
  end
end
```

- [ ] **Step 2: Run to verify it fails** — `mix test test/emakola/page_builder/safe_url_test.exs` → FAIL (module undefined).

- [ ] **Step 3: Implement**

```elixir
defmodule Emakola.PageBuilder.SafeUrl do
  @moduledoc """
  Render-boundary URL allowlist for merchant-controlled block content.

  Block content is stored verbatim by both the page editor and the section
  block-bridge, so the render boundary is the one chokepoint covering every
  write path and all already-stored data (spec:
  docs/superpowers/specs/2026-07-12-block-url-sanitization-design.md).

  Mirrors the allowlist the Video block proved out in `video_embed/1`:
  absolute http(s) or site-relative. Everything else — javascript:, data:,
  protocol-relative //host, bare-relative, non-binaries — becomes `nil`,
  which HEEx renders as an omitted attribute.
  """

  @doc "Returns the URL when it is http(s) or site-relative; otherwise nil."
  def safe_url(url) when is_binary(url) do
    trimmed = String.trim(url)

    cond do
      trimmed =~ ~r{^https?://}i -> url
      String.starts_with?(trimmed, "//") -> nil
      String.starts_with?(trimmed, "/") -> url
      true -> nil
    end
  end

  def safe_url(_other), do: nil
end
```

- [ ] **Step 4: Run to verify PASS**, then gates.
- [ ] **Step 5: Commit** — `git commit -m "feat(web): render-boundary URL allowlist for block content"`

---

### Task 2: Apply at the nine sinks + render tests

**Files:**
- Modify: `lib/emakola/page_builder/blocks/hero_banner.ex` (~58, ~118, ~126), `image_banner.ex` (~53, ~92), `split.ex` (~65, ~92), `audio.ex` (~58), `video.ex` (poster attr only)
- Modify: `TODO.md` (mark the security follow-up item DONE with date)
- Test: `test/emakola/page_builder/block_url_render_test.exs`

**Interfaces:**
- Consumes: `Emakola.PageBuilder.SafeUrl.safe_url/1` (Task 1); `Emakola.PageBuilder.render_block/2` (existing — `%{"type" => t, "content" => map}` + assigns with `:store/:products/:categories`; string content keys are atomized internally).
- Produces: nothing downstream; this is the leaf.

- [ ] **Step 1: Write the failing render tests** (read each block's `render/1` first — a CTA/link may render only when its label/flag content key is set; include those keys so the sink branch executes. Adjust content keys to each block's real schema, keeping the assertion intent.)

```elixir
defmodule Emakola.PageBuilder.BlockUrlRenderTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  @evil "javascript:alert(1)"

  defp render_block(type, content) do
    Emakola.PageBuilder.render_block(
      %{"type" => type, "content" => content},
      %{
        __changed__: nil,
        store: %{id: Ash.UUID.generate(), name: "Test Store", slug: "test-store"},
        products: [],
        categories: []
      }
    )
    |> rendered_to_string()
  end

  test "hero_banner neutralizes all three URL sinks, fallbacks preserved" do
    html =
      render_block("hero_banner", %{
        "title" => "T",
        "image_url" => @evil,
        "cta_label" => "Shop",
        "cta_url" => @evil,
        "secondary_cta_label" => "More",
        "secondary_cta_url" => "data:text/html,x"
      })

    refute html =~ "javascript:"
    refute html =~ "data:text/html"
    assert html =~ ~s(href="/products")
  end

  test "image_banner neutralizes link and image URLs" do
    html =
      render_block("image_banner", %{"image_url" => @evil, "link_url" => @evil})

    refute html =~ "javascript:"
  end

  test "split neutralizes image and CTA URLs, fallback preserved" do
    html =
      render_block("split", %{
        "image_url" => @evil,
        "cta_label" => "Go",
        "cta_url" => @evil
      })

    refute html =~ "javascript:"
    assert html =~ ~s(href="/products")
  end

  test "audio neutralizes the src" do
    html = render_block("audio", %{"audio_url" => @evil, "title" => "Track"})
    refute html =~ "javascript:"
  end

  test "video neutralizes the poster" do
    html =
      render_block("video", %{
        "video_url" => "https://youtube.com/watch?v=abc123",
        "poster_url" => @evil
      })

    refute html =~ "javascript:"
  end

  test "video rejects backslash protocol-relative direct-file URLs" do
    # /\evil.com parses protocol-relative in browsers; the block must not
    # render a <video src> for it (video_embed returns :invalid → no section).
    html = render_block("video", %{"video_url" => "/\\evil.com/x.mp4"})
    refute html =~ "evil.com"
  end

  test "legitimate URLs render unchanged" do
    html =
      render_block("hero_banner", %{
        "title" => "T",
        "image_url" => "https://cdn.example.com/hero.jpg",
        "cta_label" => "Shop",
        "cta_url" => "/s/test-store/products"
      })

    assert html =~ ~s(src="https://cdn.example.com/hero.jpg")
    assert html =~ ~s(href="/s/test-store/products")
  end
end
```

- [ ] **Step 2: Run to verify FAIL** — the `refute html =~ "javascript:"` assertions fail against current blocks.

- [ ] **Step 3: Wrap the sinks.** In each listed block module add `alias Emakola.PageBuilder.SafeUrl`, then:

```
hero_banner.ex  ~58:  src={SafeUrl.safe_url(@content[:image_url])}
hero_banner.ex ~118:  href={SafeUrl.safe_url(@content[:cta_url]) || "/products"}
hero_banner.ex ~126:  href={SafeUrl.safe_url(@content[:secondary_cta_url]) || "/products"}
image_banner.ex ~53:  <a href={SafeUrl.safe_url(@content[:link_url])} class="block">
image_banner.ex ~92:  src={SafeUrl.safe_url(@content[:image_url])}
split.ex        ~65:  src={SafeUrl.safe_url(@content[:image_url])}
split.ex        ~92:  href={SafeUrl.safe_url(@content[:cta_url]) || "/products"}
audio.ex        ~58:  <audio src={SafeUrl.safe_url(@content[:audio_url])} controls ...>
video.ex     poster:  poster={SafeUrl.safe_url(@content[:poster_url])}
```

Additionally in `video.ex`, replace `video_embed/1`'s two direct-file cond clauses:

```elixir
# BEFORE (two clauses):
#   String.match?(url, ~r/^https?:\/\//) -> {:file, url}
#   String.starts_with?(url, "/") -> {:file, url}
# AFTER (one clause, unified policy):
      safe = SafeUrl.safe_url(url) ->
        {:file, safe}
```

(keep the youtube/vimeo clauses above it and the `true -> :invalid` fallback; `cond` binds `safe` only when non-nil, so `:invalid` still wins for rejected URLs. Update video.ex's `@doc` for `video_embed/1` to say "http(s)/site-relative per `SafeUrl`".)

Change nothing else in the templates. If a listed line has drifted, locate the same attribute and apply the same wrap.

- [ ] **Step 4: Run** the new file + the existing surrounding suites: `mix test test/emakola/page_builder/ test/emakola/themes/ test/emakola_web/live/storefront/` — all green, pre-existing tests unchanged.
- [ ] **Step 5: TODO.md** — mark the "sanitize URL-position block content" security item `[x]` DONE 2026-07-12 (render-boundary SafeUrl; page-editor path and block-bridge path both covered).
- [ ] **Step 6: Full gates** — `mix format --check-formatted` · `mix credo --strict` · full `mix test` (read `Result:`).
- [ ] **Step 7: Commit + PR** — `git commit -m "fix(web): sanitize merchant block URLs at the render boundary"`; push; PR titled `fix(web): sanitize merchant block URLs at the render boundary` body: closes the PR #296 security follow-up, unblocks the section-editor PR, spec linked.

---

## Self-review notes

- Spec coverage: helper (§Fix) → Task 1; all nine sinks + table (§Fix) → Task 2 Step 3; testing section → Tasks 1-2 tests; TODO update → Task 2 Step 5. Out-of-scope items untouched.
- Sink count check: 3+2+2+1+1 = 9 ✓. `video_embed/1` untouched ✓.
- Type consistency: `safe_url/1` returns `String.t() | nil` everywhere; fallbacks rely on `nil || "/products"` ✓.
