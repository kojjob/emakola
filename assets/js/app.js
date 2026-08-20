// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import ThemeToggle from "./hooks/theme_toggle"
import Analytics from "./hooks/analytics"
import ScrollReveal, {bindScrollReveal} from "./hooks/scroll_reveal"
import AutoDismiss from "./hooks/auto_dismiss"
import ThemeSettings from "./hooks/theme_settings"
import ScrollGlass, {bindScrollGlass} from "./hooks/scroll_glass"
import AddToBag from "./hooks/add_to_bag"
import AtelierNavScroll from "./hooks/atelier_nav_scroll"
import ChartHook from "./hooks/chart_hook"
import UnsavedChanges from "./hooks/unsaved_changes"
import SectionSortable from "./hooks/section_sortable"

// Scroll effects on dead pages (e.g. the landing page) and on the shared
// marketing nav: bind by data attribute since phx-hook needs a LiveView.
// Re-scan after live navigation; the data flag prevents double-binding.
const bindScrollEffects = () => {
  document.querySelectorAll("[data-scroll-glass]:not([data-scroll-bound])").forEach((el) => {
    el.dataset.scrollBound = "1"
    bindScrollGlass(el)
  })
  document.querySelectorAll("[data-scroll-reveal]:not([data-scroll-bound])").forEach((el) => {
    el.dataset.scrollBound = "1"
    bindScrollReveal(el)
  })
}
bindScrollEffects()
window.addEventListener("phx:page-loading-stop", bindScrollEffects)

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {ThemeToggle, Analytics, ScrollReveal, AutoDismiss, ThemeSettings, ScrollGlass, AddToBag, AtelierNavScroll, ChartHook, UnsavedChanges, SectionSortable},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Password visibility toggle (used by auth forms via JS.dispatch)
window.addEventListener("toggle-password", (e) => {
  const input = e.target
  const icon = e.target.closest(".relative")?.querySelector("button .material-symbols-outlined")
  if (input && input.type === "password") {
    input.type = "text"
    if (icon) icon.textContent = "visibility_off"
  } else if (input) {
    input.type = "password"
    if (icon) icon.textContent = "visibility"
  }
})

// Copy-to-clipboard: buttons dispatch this event with `detail: {text}` instead
// of a server round-trip (JS.dispatch("copy-to-clipboard", detail: %{text: ...})),
// used by the storefront share strip and the admin pay-links page. The event
// bubbles from whichever button dispatched it, so one window listener covers
// every caller.
window.addEventListener("copy-to-clipboard", (e) => {
  const text = e.detail && e.detail.text
  if (text && navigator.clipboard) {
    navigator.clipboard.writeText(text)
  }
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Server-driven modal close: runs the target element's phx-remove JS (hide_modal)
window.addEventListener("phx:close-modal", (e) => {
  const el = document.getElementById(e.detail.id)
  if (el) liveSocket.execJS(el, el.getAttribute("phx-remove"))
})

// Register service worker for PWA
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/sw.js").catch(() => {})
}

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}


// Merchant and platform sidebars, persisted in localStorage.
//
// This lives here rather than in an inline <script> in app.html.heex because
// the CSP sets `script-src 'self' 'nonce-…'` with no 'unsafe-inline': an
// un-nonced inline block is blocked outright, and an `onclick="…"` attribute
// is blocked even *with* a nonce (nonces don't cover event-handler
// attributes). Bundled assets are served from 'self', so they just work.
const sidebarConfigs = [
  {
    shellId: "admin-shell",
    storageKey: "sidebar-collapsed",
    toggleSelector: "[data-toggle-sidebar]",
  },
  {
    shellId: "platform-shell",
    storageKey: "platform-sidebar-collapsed",
    toggleSelector: "[data-toggle-platform-sidebar]",
  },
]

function storedSidebarValue(key) {
  try {
    return localStorage.getItem(key)
  } catch (_error) {
    return null
  }
}

function persistSidebarValue(key, collapsed) {
  try {
    localStorage.setItem(key, String(collapsed))
  } catch (_error) {
    // Storage may be unavailable in a hardened/private browser context. The
    // control should still work for the current page without a console error.
  }
}

function applySidebarState(config, collapsed) {
  const shell = document.getElementById(config.shellId)
  if (!shell) return

  shell.classList.toggle("collapsed", collapsed)
  document.querySelectorAll(config.toggleSelector).forEach(toggle => {
    toggle.setAttribute("aria-expanded", String(!collapsed))
  })
}

function applyStoredSidebarStates() {
  sidebarConfigs.forEach(config => {
    applySidebarState(config, storedSidebarValue(config.storageKey) === "true")
  })
}

document.addEventListener("click", e => {
  if (!(e.target instanceof Element)) return

  const config = sidebarConfigs.find(item => e.target.closest(item.toggleSelector))
  if (!config) return

  const shell = document.getElementById(config.shellId)
  if (!shell) return

  const collapsed = !shell.classList.contains("collapsed")
  applySidebarState(config, collapsed)
  persistSidebarValue(config.storageKey, collapsed)
})

// Backwards compatibility for any server-rendered JS.dispatch("toggle-sidebar")
// caller while click delegation remains the primary path.
window.addEventListener("toggle-sidebar", () => {
  const config = sidebarConfigs[0]
  const shell = document.getElementById(config.shellId)
  if (!shell) return

  const collapsed = !shell.classList.contains("collapsed")
  applySidebarState(config, collapsed)
  persistSidebarValue(config.storageKey, collapsed)
})

applyStoredSidebarStates()
// Re-apply after LiveView navigations, which can re-render either shell.
window.addEventListener("phx:page-loading-stop", applyStoredSidebarStates)

// ⌘K / Ctrl+K focuses the admin topbar search (marked data-global-search).
window.addEventListener("keydown", e => {
  if((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k"){
    const search = document.querySelector("[data-global-search]")
    if(search){
      e.preventDefault()
      search.focus()
      search.select()
    }
  }
})
