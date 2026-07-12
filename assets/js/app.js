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
  hooks: {ThemeToggle, Analytics, ScrollReveal, AutoDismiss, ThemeSettings, ScrollGlass, AddToBag, AtelierNavScroll, ChartHook, UnsavedChanges},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Sidebar collapse toggle with localStorage persistence
window.addEventListener("toggle-sidebar", () => {
  const shell = document.getElementById("admin-shell")
  if (shell) {
    shell.classList.toggle("collapsed")
    localStorage.setItem("sidebar-collapsed", shell.classList.contains("collapsed"))
  }
})

// Restore sidebar state on page load
if (localStorage.getItem("sidebar-collapsed") === "true") {
  const shell = document.getElementById("admin-shell")
  if (shell) shell.classList.add("collapsed")
}

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

