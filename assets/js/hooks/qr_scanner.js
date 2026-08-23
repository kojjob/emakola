// Camera QR scanning for the merchant admin.
//
// Reads frames from the rear camera and pushes whatever it decodes to the
// LiveView as a plain string. It deliberately does nothing with that string
// itself — no navigation, no URL parsing. The server decides what a scan means
// (see EmakolaWeb.QRScan), because a code on a parcel is written by whoever
// printed the sticker.
//
// Two decoders, picked at runtime:
//
//   * BarcodeDetector, native in Chrome/Android — costs zero bytes.
//   * jsQR, loaded from /assets/js/qr_decoder.js only when the native API is
//     missing. That is every browser on iOS: they all use WebKit, and WebKit
//     has never shipped BarcodeDetector. Without this fallback the scanner
//     would simply not exist on iPhone.

// ~8 fps. Fast enough to feel instant when a code is held up, slow enough to
// leave a cheap phone responsive — decoding every animation frame pins the CPU
// and heats the device for no gain.
const SCAN_INTERVAL_MS = 120

// How long to wait for a camera before telling the merchant there isn't one.
// Generous enough that a merchant reading a permission prompt is not cut off.
const CAMERA_TIMEOUT_MS = 10000

export default {
  mounted() {
    this.video = this.el.querySelector("video")
    this.canvas = document.createElement("canvas")
    this.ctx = this.canvas.getContext("2d", { willReadFrequently: true })
    this.running = false

    // The panel is only in the DOM while the scanner is open, so mounting IS
    // the signal to start. No server round-trip to begin, and the camera is
    // released the moment LiveView removes the element.
    this.start()
  },

  destroyed() {
    this.stop()
  },

  // The LiveView can navigate away mid-scan; releasing the camera is not
  // optional, or the phone keeps its indicator lit.
  disconnected() {
    this.stop()
  },

  async start() {
    if (this.running) return
    this.running = true

    try {
      // Racing a timeout, not just catching a rejection. A denial rejects, but
      // a device that is simply absent can leave getUserMedia pending forever —
      // observed in a headless browser, and the same shape a merchant hits when
      // a permission prompt is dismissed by the OS rather than answered. Either
      // way the honest outcome is to say so, not to show a black rectangle that
      // never becomes a picture.
      this.stream = await Promise.race([
        navigator.mediaDevices.getUserMedia({
          video: { facingMode: "environment" },
          audio: false,
        }),
        new Promise((_res, rej) => {
          this.watchdog = setTimeout(() => rej(new Error("camera-timeout")), CAMERA_TIMEOUT_MS)
        }),
      ])
      clearTimeout(this.watchdog)
    } catch (_err) {
      clearTimeout(this.watchdog)
      this.running = false
      this.pushEvent("scan_camera_unavailable", {})
      return
    }

    this.video.srcObject = this.stream
    this.video.setAttribute("playsinline", true) // iOS: do not go fullscreen
    await this.video.play().catch(() => {})

    this.decode = await this.pickDecoder()
    this.timer = setInterval(() => this.tick(), SCAN_INTERVAL_MS)
  },

  stop() {
    this.running = false
    clearTimeout(this.watchdog)
    if (this.timer) clearInterval(this.timer)
    this.timer = null
    if (this.stream) this.stream.getTracks().forEach((t) => t.stop())
    this.stream = null
    if (this.video) this.video.srcObject = null
  },

  async pickDecoder() {
    if ("BarcodeDetector" in window) {
      try {
        const detector = new window.BarcodeDetector({ formats: ["qr_code"] })
        return async () => {
          const codes = await detector.detect(this.canvas)
          return codes.length ? codes[0].rawValue : null
        }
      } catch (_err) {
        // Constructed but unusable (some builds advertise the API without the
        // QR format). Fall through to the shim rather than scanning forever.
      }
    }

    await this.loadFallbackDecoder()
    return async () => {
      const { width, height } = this.canvas
      if (!width || !height) return null
      const frame = this.ctx.getImageData(0, 0, width, height)
      return window.MakolaQRDecode(frame.data, width, height)
    }
  },

  loadFallbackDecoder() {
    if (window.MakolaQRDecode) return Promise.resolve()

    return new Promise((resolve) => {
      const script = document.createElement("script")
      // Digest-aware path handed down from the template via ~p, so the file
      // cache-busts on deploy instead of a stale copy sticking around.
      script.src = this.el.dataset.decoderUrl
      script.onload = () => resolve()
      // Resolve on error too: tick() guards on the decoder existing, so a
      // failed fetch degrades to "no code found" instead of an unhandled
      // rejection that would leave the camera running.
      script.onerror = () => resolve()
      document.head.appendChild(script)
    })
  },

  async tick() {
    if (!this.running || !this.decode) return
    if (this.video.readyState !== this.video.HAVE_ENOUGH_DATA) return

    this.canvas.width = this.video.videoWidth
    this.canvas.height = this.video.videoHeight
    this.ctx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height)

    let value = null
    try {
      value = await this.decode()
    } catch (_err) {
      return
    }

    if (!value) return

    // One scan per opening. Stopping first means a code held in frame cannot
    // fire the same event several times while the server is still responding.
    this.stop()
    this.pushEvent("qr_scanned", { value })
  },
}
