// QR decoding fallback for browsers without the native BarcodeDetector API.
//
// This is a SEPARATE esbuild entry point, not a dynamic import, and that is
// deliberate. Our esbuild invocation has neither --splitting nor --format=esm
// (see config/config.exs), and without those a dynamic import() is inlined
// straight into app.js — so a "lazy" decoder would in fact ship to every
// merchant. Most of them are on Android, where BarcodeDetector is native and
// this file is never fetched at all. Bandwidth is scarce on this market's
// phones; making them download an iOS shim would be a real cost.
//
// Loaded on demand by assets/js/hooks/qr_scanner.js, which injects a <script>
// tag pointing here. Served from our own origin, so it satisfies the CSP's
// script-src 'self' with no nonce plumbing.
import jsQR from "jsqr"

window.MakolaQRDecode = (imageData, width, height) => {
  // dontInvert: our codes are always dark-on-light. Skipping the inverted pass
  // roughly halves the per-frame cost, which matters on a low-end phone doing
  // this several times a second.
  const found = jsQR(imageData, width, height, { inversionAttempts: "dontInvert" })
  return found ? found.data : null
}

window.dispatchEvent(new Event("makola:qr-decoder-ready"))
