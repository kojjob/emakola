# Block URL Sanitization at the Render Boundary — Design

**Date:** 2026-07-12 · **Status:** authorized as the PR #296 security follow-up ("continue to complete all the tasks"); gates the section-editor UI PR
**Owner item:** TODO.md security follow-up (added in PR #296)

## Problem

Page-builder block content renders merchant-controlled URLs straight into
`href`/`src` attributes with no scheme validation. Two write paths feed the
same sink: the existing page editor (stores block content verbatim — the
pre-existing hole) and the new section block-bridge (`block/<type>` entries,
whose settings are exempt from `HomeSections`' URL scoping because
`BlockSection.settings_schema/0` is `[]`). A `javascript:alert(1)` value in
`hero_banner.cta_url` renders as a live link on the storefront (verified
during PR #296's final review). Today neither write path is
merchant-reachable for sections (the editor UI doesn't exist yet), but the
page editor is live, and the section editor arms the second path — hence
this fix must land before or with the editor PR.

## Fix (render boundary)

One helper, applied at every sink:

- `Emakola.PageBuilder.SafeUrl.safe_url/1`:
  - binary matching `^https?://` (case-insensitive, after trim) → returned trimmed
  - binary starting with `/` (site-relative, after trim) → returned trimmed
  - anything else → `nil`: other schemes, non-binaries, bare-relative, and
    ALL protocol-relative spellings — browsers treat `\` as `/` in http(s)
    parsing, so `//`, `/\`, `\/`, `\\` prefixes are all foreign-host
    references (reviewer-caught 2026-07-12, browser-verified) and all reject
- Call sites (`safe_url(...)` wrapping, block fallbacks preserved):
  | Block | Sinks |
  |---|---|
  | hero_banner | `image_url` (src), `cta_url`, `secondary_cta_url` (hrefs, `\|\| "/products"` fallbacks preserved) |
  | image_banner | `link_url` (href), `image_url` (src) |
  | split | `image_url` (src), `cta_url` (href, fallback preserved) |
  | audio | `audio_url` (src) |
  | video | `poster_url` (poster attr) + `video_embed/1`'s direct-file branch routed through `safe_url/1` (its hand-rolled http(s)-or-`/` check shares the backslash gap; YouTube/Vimeo id-extraction branches unchanged) |

`nil` in HEEx omits the attribute entirely — an invalid URL degrades to a
dead link/empty media slot, never an executable one.

### Why render-side, not write-side

- Protects **both** write paths (page editor + section bridge) and all
  **already-stored** data in one move — the final review's recommendation.
- Generalizes proven in-repo precedent: the video block's `video_embed/1`
  already implements exactly this allowlist (`https?://` or leading `/`).
- Write-side validation can be layered later in the page editor without
  changing this boundary.

### Scheme policy

http/https + site-relative only — consistent with `HomeSections`'
write-side rule for `:image_url`/`:link` settings and with `video_embed/1`.
`mailto:`/`tel:` deliberately excluded in v1 (no current block offers such
CTAs; add per-scheme when a merchant need appears). Protocol-relative
(`//evil.com`) is rejected: it is neither scheme-explicit nor site-relative.

## Testing

- `SafeUrl` unit tests: https/http/relative pass; `javascript:`, `data:`,
  `vbscript:`, `//`, ` javascript:` (leading whitespace), uppercase
  `JAVASCRIPT:`, nil, non-binary → nil.
- Per-block render tests (one per sink, 9 total): render the block with a
  `javascript:alert(1)` value in that field, assert the attribute is absent
  or the fallback URL rendered — and one positive case per block (https and
  relative values render unchanged).
- Existing block/page/storefront suites unchanged (legit URLs unaffected).

## Out of scope

- Page-editor write-side validation (follow-up polish, not the boundary).
- Section-settings write-side rules (already shipped in PR #296).

(Amended 2026-07-12: `video_embed/1` was originally listed here as "already
safe"; Task-1 review proved its direct-file branch shares the backslash
protocol-relative gap, so its file-URL path is now in scope via `safe_url/1`.)
