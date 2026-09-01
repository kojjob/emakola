defmodule EmakolaWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Plug that sets Content-Security-Policy headers with per-request nonces.

  Generates a cryptographically random nonce for each request and sets it on
  `conn.assigns.csp_nonce`. This nonce is used by Phoenix LiveView for its
  inline scripts and can be referenced in templates via `@csp_nonce`.

  The CSP policy is enforced (not report-only) with a per-request nonce
  for LiveView inline scripts. See `build_policy/1` for the full directive list.

  ## `script-src` — hardened

  `script-src` is `'self' 'nonce-…'` with **no `'unsafe-inline'`**. This closes
  the high-severity vector: an injected `<script>` cannot execute without the
  per-request nonce.

  ## `style-src` — `'unsafe-inline'` retained (accepted P2 risk)

  `style-src` deliberately keeps `'unsafe-inline'`. Removing it is **not
  feasible** for this app, and the residual risk is low. Rationale:

  * **Attribute styles can't be nonced.** CSP nonces only cover `<style>`
    *elements*, never inline `style="…"` *attributes*. The app has ~760 inline
    `style=` attributes — many structurally required and dynamic per request:
    per-store theme CSS variables (`card_theme_vars/1`), progress-bar widths,
    live colour swatches. These cannot move to external CSS, so
    `style-src-attr 'unsafe-inline'` is **permanent**.
  * **`<style>` elements are a deferred target.** ~32 `<style>` blocks (mostly
    LiveView-rendered theme modules) could in principle be nonced, but doing so
    safely requires a nonce that stays stable across LiveView socket re-renders
    (the CSP header is sent once, on the initial HTTP response, and can't be
    updated by later DOM patches). Until that lands, `style-src-elem` keeps
    `'unsafe-inline'` and carries **no nonce** — adding a nonce would make
    browsers ignore `'unsafe-inline'` (per CSP) and silently block every
    un-nonced `<style>` block.
  * **Severity is low.** Style injection enables UI redressing / CSS-based
    exfiltration, not code execution — far less severe than script injection,
    which `script-src` already blocks.

  The directive is split into `style-src-attr` / `style-src-elem` (with
  `style-src` as the fallback for pre-CSP3 browsers) so a future hardening pass
  only needs to nonce the `<style>` blocks and drop `'unsafe-inline'` from
  `style-src-elem` — no other directive changes.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    nonce = generate_nonce()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", build_policy(nonce))
  end

  defp generate_nonce do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp build_policy(nonce) do
    directives = [
      "default-src 'self'",
      "script-src 'self' 'nonce-#{nonce}'",
      # See moduledoc. `style-src` is the pre-CSP3 fallback; modern browsers use
      # the split below. `-attr` is permanent (style="…" can't be nonced);
      # `-elem` keeps 'unsafe-inline' WITHOUT a nonce until the ~32 <style>
      # blocks are nonced — a nonce here would disable 'unsafe-inline' and block
      # them. Hardening `-elem` is the only future change needed.
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "style-src-attr 'unsafe-inline'",
      "style-src-elem 'self' 'unsafe-inline' https://fonts.googleapis.com",
      # blob: because every LiveView upload preview is a blob: object URL —
      # without it merchants stare at blank squares while photos upload.
      "img-src 'self' data: blob: https:",
      # blob: is required by the /how-it-works/tour scrub engine, which fetches
      # each clip and plays it from an in-memory object URL (always-seekable).
      # Only same-origin scripts (nonce-locked above) can mint blob URLs.
      "media-src 'self' blob:",
      "font-src 'self' https://fonts.gstatic.com https://fonts.googleapis.com",
      "connect-src 'self' wss: ws:",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'",
      "object-src 'none'"
    ]

    Enum.join(directives, "; ")
  end
end
