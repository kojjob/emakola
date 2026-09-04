// Generates the artboards for the "Add Products One Door" canvas.
// Run: node build.mjs   (writes *.dc.html + canvas.json beside this file)
//
// Consolidates the five ways into /admin/products/new (Take a photo, Choose
// photos, Type it in, Upload a file, and Add by photo on the Products page)
// into one page with one card model. Tokens are lifted from
// assets/css/app.css @theme and the live admin shell; the card, tile and
// control sizes are the ones the live AddProducts page ships
// (add_products_components.ex), which came from design/add-products.

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

// ── Tokens (app.css @theme) ─────────────────────────────────────────────
const T = {
  bg: '#F8FAFC', surface: '#FFFFFF', border: '#E2E8F0', line: '#F1F5F9',
  text: '#0F172A', muted: '#64748B', faint: '#94A3B8', ink2: '#334155',
  primary: '#059669', primaryHover: '#047857', soft: '#ECFDF5', softBorder: '#A7F3D0', mint: '#6EE7B7',
  warn: '#D97706', warnText: '#B45309', warnSoft: '#FEF3C7', warnRing: '#F59E0B',
  danger: '#DC2626',
};

// ── Icons: heroicons outline paths on a 24 grid ─────────────────────────
const P = {
  menu: '<path d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/>',
  search: '<path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>',
  bell: '<path d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0"/>',
  back: '<path d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"/>',
  camera: '<path d="M3 8.5A1.5 1.5 0 014.5 7h2.2l1.2-2h8.2l1.2 2h2.2A1.5 1.5 0 0121 8.5v9A1.5 1.5 0 0119.5 19h-15A1.5 1.5 0 013 17.5v-9z"/><circle cx="12" cy="12.5" r="3.4"/>',
  photo: '<path d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25z"/>',
  check: '<path d="M4.5 12.75l6 6 9-13.5"/>',
  plus: '<path d="M12 4.5v15m7.5-7.5h-15"/>',
  x: '<path d="M6 18L18 6M6 6l12 12"/>',
  bang: '<path d="M12 8v4.5m0 3.5h.01"/>',
  sparkles: '<path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456z"/>',
  upload: '<path d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>',
  pencil: '<path d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L6.832 19.82a4.5 4.5 0 01-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 011.13-1.897L16.863 4.487zm0 0L19.5 7.125"/>',
  cube: '<path d="M21 7.5l-9-5.25L3 7.5m18 0l-9 5.25m9-5.25v9l-9 5.25M3 7.5l9 5.25M3 7.5v9l9 5.25m0-9v9"/>',
  shop: '<path d="M13.5 21v-7.5a.75.75 0 01.75-.75h3a.75.75 0 01.75.75V21m-4.5 0H2.36m11.14 0H18m0 0h3.64m-1.39 0V9.349m-16.5 11.65V9.35m0 0a3.001 3.001 0 003.75-.615A2.993 2.993 0 009.75 9.75c.896 0 1.7-.393 2.25-1.016a2.993 2.993 0 002.25 1.016c.896 0 1.7-.393 2.25-1.016a3.001 3.001 0 003.75.614m-16.5 0a3.004 3.004 0 01-.621-4.72L4.318 3.44A1.5 1.5 0 015.378 3h13.243a1.5 1.5 0 011.06.44l1.19 1.189a3 3 0 01-.621 4.72m-13.5 8.65h3.75a.75.75 0 00.75-.75V13.5a.75.75 0 00-.75-.75H6.75a.75.75 0 00-.75.75v3.75c0 .415.336.75.75.75z"/>',
  chevronDown: '<path d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>',
  chevronUp: '<path d="M4.5 15.75l7.5-7.5 7.5 7.5"/>',
  bars: '<path d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25H12"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 2"/>',
};
const icon = (name, size = 20, color = 'currentColor', sw = 1.8) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${P[name]}</svg>`;

// ── Document shell ──────────────────────────────────────────────────────
const doc = (body, extraCss = '') => `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap">
  <style>
    body { margin: 0; font-family: 'Inter', system-ui, -apple-system, "Segoe UI", sans-serif; -webkit-font-smoothing: antialiased; }
    a { color: ${T.primary}; } a:hover { color: ${T.primaryHover}; }
    * { box-sizing: border-box; }
    input::placeholder, textarea::placeholder { color: ${T.faint}; font-weight: 500; }
    button { font-family: inherit; }
    ${extraCss}
  </style>
</helmet>
${body}
</x-dc>
</body>
</html>
`;

// The live admin top bar at phone width (sidebar_components.ex admin_topbar).
const topbar = () => `
  <div style="height: 72px; flex-shrink: 0; display: flex; align-items: center; gap: 12px; padding: 0 16px; background: rgba(255,255,255,0.8); border-bottom: 1px solid rgba(226,232,240,0.8); backdrop-filter: blur(24px);">
    <button aria-label="Open sidebar" style="width: 36px; height: 36px; margin-left: -8px; border: 0; background: none; border-radius: 12px; display: flex; align-items: center; justify-content: center; cursor: pointer;">${icon('menu', 20, T.muted, 2)}</button>
    <div style="flex: 1; position: relative;">
      <div style="position: absolute; left: 14px; top: 50%; transform: translateY(-50%); display: flex;">${icon('search', 16, T.faint, 2)}</div>
      <input type="search" placeholder="Search anything..." aria-label="Search" style="width: 100%; padding: 10px 16px 10px 40px; background: rgba(248,250,252,0.8); border: 1px solid ${T.border}; border-radius: 12px; font-size: 14px; color: ${T.ink2}; font-family: inherit; outline: none;" />
    </div>
    <button aria-label="Notifications" style="width: 36px; height: 36px; border: 0; background: none; border-radius: 12px; display: flex; align-items: center; justify-content: center; cursor: pointer;">${icon('bell', 20, T.muted, 1.8)}</button>
    <div style="width: 36px; height: 36px; border-radius: 999px; background: ${T.soft}; color: ${T.primaryHover}; font-size: 13px; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">A</div>
  </div>`;

const phone = (content, { height = 844, bottom = '' } = {}) => doc(`
<div style="width: 390px; height: ${height}px; background: ${T.bg}; color: ${T.text}; display: flex; flex-direction: column; overflow: hidden;">
  ${topbar()}
  <div style="flex: 1 1 auto; min-height: 0; overflow-y: auto; display: flex; flex-direction: column;">
${content}
  </div>
  ${bottom}
</div>`);

const stickyBar = (inner) => `
  <div style="flex-shrink: 0; padding: 12px 16px 16px; background: rgba(255,255,255,0.95); border-top: 1px solid ${T.border}; backdrop-filter: blur(8px); display: flex; flex-direction: column; gap: 10px;">
    ${inner}
  </div>`;

// The live page header at phone width: back arrow, 24px bold title, 14px subtitle.
const pageHeader = (title, sub) => `
    <div style="display: flex; align-items: center; gap: 12px; padding: 16px 16px 0;">
      <button aria-label="Back to products" style="width: 40px; height: 40px; margin-left: -8px; border: 0; background: none; border-radius: 8px; display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0;">${icon('back', 20, T.muted, 2)}</button>
      <div style="flex: 1; min-width: 0;">
        <h1 style="margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.2; color: ${T.text};">${title}</h1>
        ${sub ? `<p style="margin: 3px 0 0; font-size: 14px; color: ${T.muted};">${sub}</p>` : ''}
      </div>
    </div>`;

// ── Controls (sizes from add_products_components.ex) ────────────────────
const field = ({ placeholder = '', value = '', prefix = '', tone = 'idle', compact = false, decimal = false }) => {
  const border = tone === 'warn' ? T.warnRing : T.border;
  const h = compact ? 46 : 54;
  const fs = compact ? 15.5 : 17;
  const padL = prefix ? (compact ? 52 : 66) : compact ? 12 : 16;
  const radius = compact ? 11 : 13;
  return `<div style="position: relative;">
        ${prefix ? `<div style="position: absolute; left: ${compact ? 12 : 16}px; top: 0; height: ${h}px; display: flex; align-items: center; font-size: ${compact ? 14.5 : 17}px; font-weight: 700; color: ${T.muted}; pointer-events: none;">${prefix}</div>` : ''}
        <input type="text"${decimal ? ' inputmode="decimal"' : ''} placeholder="${placeholder}" value="${value}" style="width: 100%; height: ${h}px; border: 2px solid ${border}; border-radius: ${radius}px; padding: 0 ${compact ? 12 : 16}px 0 ${padL}px; font-size: ${fs}px; font-weight: 600; color: ${T.text}; background: ${tone === 'warn' ? '#FFFBEB' : T.surface}; font-family: inherit; outline: none;" />
      </div>`;
};

const textarea = ({ placeholder = '', value = '', compact = false }) =>
  `<textarea rows="3" placeholder="${placeholder}" style="width: 100%; min-height: ${compact ? 84 : 96}px; border: 2px solid ${T.border}; border-radius: ${compact ? 11 : 13}px; padding: 12px ${compact ? 12 : 15}px; font-size: ${compact ? 14.5 : 16}px; font-weight: 500; line-height: 1.4; color: ${T.text}; background: ${T.surface}; font-family: inherit; outline: none; resize: none; display: block;">${value}</textarea>`;

const cta = (label, ic = '', { width = '100%', height = 56 } = {}) =>
  `<button style="width: ${width}; height: ${height}px; border: 0; border-radius: 13px; background: ${T.primary}; color: #fff; padding: 0 24px; font-size: 16.5px; font-weight: 800; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 10px; box-shadow: 0 5px 14px rgba(5,150,105,0.28);">${ic ? icon(ic, 22, '#fff', 2) : ''}<span>${label}</span></button>`;

const secondary = (label, ic = '', { width = '100%', height = 54 } = {}) =>
  `<button style="width: ${width}; height: ${height}px; border: 2px solid ${T.border}; border-radius: 13px; background: ${T.surface}; color: ${T.text}; padding: 0 18px; font-size: 16px; font-weight: 700; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 9px;">${ic ? icon(ic, 20, T.muted, 2) : ''}<span>${label}</span></button>`;

// Live admin_button (px-4 py-2.5 text-sm font-semibold rounded-control).
const adminButton = (label, ic, variant = 'secondary') => variant === 'primary'
  ? `<button style="display: inline-flex; align-items: center; gap: 8px; padding: 10px 16px; font-size: 14px; font-weight: 600; border-radius: 12px; border: 0; background: ${T.primary}; color: #fff; cursor: pointer;">${icon(ic, 20, '#fff', 1.8)}<span>${label}</span></button>`
  : `<button style="display: inline-flex; align-items: center; gap: 8px; padding: 10px 16px; font-size: 14px; font-weight: 600; border-radius: 12px; border: 1px solid ${T.border}; background: ${T.surface}; color: ${T.text}; cursor: pointer;">${icon(ic, 20, T.text, 1.8)}<span>${label}</span></button>`;

const chip = (label, { on = false, size = 42 } = {}) =>
  `<button style="height: ${size}px; padding: 0 ${size < 40 ? 13 : 16}px; border-radius: 999px; border: 1.5px solid ${on ? T.primary : T.border}; background: ${on ? T.soft : T.surface}; color: ${on ? T.primaryHover : T.text}; font-size: ${size < 40 ? 13.5 : 14.5}px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 7px; white-space: nowrap;">${on ? icon('check', 15, T.primaryHover, 3) : ''}<span>${label}</span></button>`;

const eyebrow = (text, right = '') => `<div style="display: flex; align-items: center; justify-content: space-between; min-height: 22px;"><div style="font-size: 11.5px; font-weight: 800; letter-spacing: 0.1em; text-transform: uppercase; color: ${T.faint};">${text}</div>${right}</div>`;

const orRule = () => `<div style="display: flex; align-items: center; gap: 12px; padding: 2px 4px;"><div style="flex: 1; height: 1px; background: ${T.border};"></div><div style="font-size: 13px; font-weight: 600; color: ${T.faint};">or</div><div style="flex: 1; height: 1px; background: ${T.border};"></div></div>`;

const disc = (size, ic, { tone = 'primary', iconSize = 26 } = {}) => tone === 'primary'
  ? `<div style="width: ${size}px; height: ${size}px; border-radius: 999px; background: ${T.primary}; display: flex; align-items: center; justify-content: center; box-shadow: 0 6px 16px rgba(5,150,105,0.3); flex-shrink: 0;">${icon(ic, iconSize, '#fff', 1.8)}</div>`
  : `<div style="width: ${size}px; height: ${size}px; border-radius: 999px; background: ${T.line}; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">${icon(ic, iconSize, T.muted, 1.8)}</div>`;

// The gallery pill: the second hit area inside the one tile.
const galleryPill = (h = 40, pos = '') =>
  `<button aria-label="Choose from gallery" style="${pos ? `position: absolute; ${pos}` : ''} height: ${h}px; padding: 0 ${h < 40 ? 12 : 14}px 0 ${h < 40 ? 10 : 12}px; border: 1.5px solid ${T.border}; border-radius: 999px; background: ${T.surface}; color: ${T.text}; font-size: ${h < 40 ? 13 : 13.5}px; font-weight: 700; display: inline-flex; align-items: center; gap: 6px; cursor: pointer; box-shadow: 0 1px 2px rgba(0,0,0,0.06);">${icon('photo', h < 40 ? 16 : 18, T.muted, 2)}<span>Gallery</span></button>`;

// ── The one tile ────────────────────────────────────────────────────────
// Phone: the body opens the camera; the Gallery pill opens the photo library.
// Desktop: the body picks files and takes a drop; there is no camera.
const oneTile = ({ variant = 'phone' }) => {
  const dashed = `border: 2px dashed ${T.mint}; background: rgba(236,253,245,0.6); border-radius: 16px;`;
  if (variant === 'phone') {
    return `<div style="position: relative; width: 100%; height: 230px; ${dashed}">
        <button aria-label="Take a photo" style="width: 100%; height: 100%; border: 0; background: none; border-radius: 16px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10px; cursor: pointer; padding: 0 16px 24px;">
          ${disc(68, 'camera', { iconSize: 34 })}
          <div style="display: flex; flex-direction: column; align-items: center; gap: 3px;">
            <div style="font-size: 18px; font-weight: 800; color: ${T.text};">Add photos</div>
            <div style="font-size: 13.5px; color: ${T.muted};">Take one, or choose up to 30</div>
          </div>
        </button>
        ${galleryPill(40, 'right: 12px; bottom: 12px;')}
      </div>`;
  }
  if (variant === 'strip') {
    return `<div style="position: relative; width: 100%; height: 72px; ${dashed} display: flex; align-items: center; gap: 12px; padding: 0 12px 0 14px;">
        <button aria-label="Take a photo" style="flex: 1; height: 100%; border: 0; background: none; display: flex; align-items: center; gap: 12px; cursor: pointer; padding: 0; text-align: left;">
          ${disc(44, 'camera', { iconSize: 24 })}
          <div style="font-size: 16px; font-weight: 800; color: ${T.text};">Add more</div>
        </button>
        ${galleryPill(36)}
      </div>`;
  }
  // desktop
  return `<button style="width: 100%; height: 110px; ${dashed} display: flex; align-items: center; justify-content: center; gap: 16px; cursor: pointer; padding: 0 16px;">
        ${disc(52, 'camera', { iconSize: 26 })}
        <div style="display: flex; flex-direction: column; align-items: flex-start; gap: 3px;">
          <div style="font-size: 18px; font-weight: 800; color: ${T.text};">Add photos</div>
          <div style="font-size: 13.5px; color: ${T.muted};">Drop them here, or choose up to 30</div>
        </div>
      </button>`;
};

// Desktop only: typing a product is a card without a photo, on this page.
const typedTile = () => `<button style="width: 100%; height: 110px; border: 2px dashed #CBD5E1; background: ${T.surface}; border-radius: 16px; display: flex; align-items: center; justify-content: center; gap: 16px; cursor: pointer; padding: 0 16px;">
        ${disc(52, 'pencil', { tone: 'quiet' })}
        <div style="display: flex; flex-direction: column; align-items: flex-start; gap: 3px;">
          <div style="font-size: 16px; font-weight: 700; color: ${T.text};">Type it in</div>
          <div style="font-size: 13px; color: ${T.muted};">No photo yet</div>
        </div>
      </button>`;

// ── Card pieces ─────────────────────────────────────────────────────────
const badgeOk = () => `<div style="position: absolute; top: 10px; right: 10px; width: 30px; height: 30px; border-radius: 999px; background: ${T.primary}; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 6px rgba(0,0,0,0.25);">${icon('check', 16, '#fff', 2.8)}</div>`;
const badgeWarn = () => `<div style="position: absolute; top: 10px; right: 10px; width: 30px; height: 30px; border-radius: 999px; background: ${T.warnRing}; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 6px rgba(0,0,0,0.25);">${icon('bang', 18, '#fff', 3)}</div>`;
const badgeNum = (n) => `<div style="position: absolute; top: 10px; right: 10px; width: 30px; height: 30px; border-radius: 999px; background: rgba(15,23,42,0.6); color: #fff; font-size: 13px; font-weight: 800; display: flex; align-items: center; justify-content: center; font-variant-numeric: tabular-nums;">${n}</div>`;
const removeButton = () => `<button aria-label="Remove" style="position: absolute; top: 10px; left: 10px; width: 30px; height: 30px; border: 0; border-radius: 999px; background: rgba(0,0,0,0.55); display: flex; align-items: center; justify-content: center; cursor: pointer;">${icon('x', 14, '#fff', 2.6)}</button>`;
const img = (src) => `<img src="${src}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block;" />`;

// "Fill it in": the AI snap page, folded into the photo. Only when AI is on.
const fillPill = () => `<button style="position: absolute; left: 10px; bottom: 10px; height: 34px; padding: 0 12px 0 10px; border: 0; border-radius: 999px; background: rgba(255,255,255,0.94); color: ${T.primaryHover}; font-size: 13px; font-weight: 800; display: flex; align-items: center; gap: 6px; cursor: pointer; box-shadow: 0 2px 6px rgba(0,0,0,0.18);">${icon('sparkles', 16, T.primary, 2)}<span>Fill it in</span></button>`;

const wroteItLine = () => `<div style="display: flex; align-items: center; gap: 6px; font-size: 12.5px; font-weight: 600; color: ${T.warnText};">${icon('sparkles', 14, T.warn, 2)}<span>Makola wrote this. Change what is wrong.</span></div>`;

const CATS = ['Food', 'Beauty', 'Fashion', 'Home'];

// "More", inside the card: category and description, opening in place.
const moreRow = ({ open = false, compact = false, ai = false, category = '', description = '' }) => {
  const pad = compact ? 12 : 14;
  const head = `<button style="width: 100%; height: 44px; border: 0; border-top: 1px solid ${T.line}; background: none; padding: 0 ${pad}px; display: flex; align-items: center; justify-content: space-between; cursor: pointer;">
          <span style="display: flex; align-items: center; gap: 8px; font-size: 14.5px; font-weight: 700; color: ${open ? T.text : T.muted};">${icon('bars', 18, open ? T.text : T.faint, 2)}<span>More</span>${!open && category ? `<span style="margin-left: 2px; font-size: 12.5px; font-weight: 700; color: ${T.primaryHover}; background: ${T.soft}; padding: 3px 9px; border-radius: 999px;">${category}</span>` : ''}</span>
          ${icon(open ? 'chevronUp' : 'chevronDown', 18, T.faint, 2.2)}
        </button>`;
  if (!open) return head;
  const writeIt = ai
    ? `<button style="height: 30px; padding: 0 11px 0 9px; border: 1.5px solid ${T.softBorder}; border-radius: 999px; background: ${T.soft}; color: ${T.primaryHover}; font-size: 12.5px; font-weight: 800; display: inline-flex; align-items: center; gap: 5px; cursor: pointer;">${icon('sparkles', 14, T.primary, 2)}<span>Write it for me</span></button>`
    : '';
  return head + `<div style="padding: 2px ${pad}px ${pad + 2}px; display: flex; flex-direction: column; gap: 14px;">
          <div style="display: flex; flex-direction: column; gap: 8px;">
            ${eyebrow('Category')}
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">${CATS.map((c) => chip(c, { on: c === category, size: compact ? 36 : 42 })).join('')}</div>
          </div>
          <div style="display: flex; flex-direction: column; gap: 8px;">
            ${eyebrow('Description', writeIt)}
            ${textarea({ placeholder: 'Say more about it', value: description, compact })}
          </div>
        </div>`;
};

// One card per product. A photo is usual; a typed product is the same card
// with a dashed slot where the photo would be.
const photoCard = ({ src = '', name = '', price = '', state = 'todo', n = 1, photoH = 200, compact = false, more = 'closed', ai = false, wroteIt = false, category = '', description = '' }) => {
  const border = state === 'ok' ? T.primary : state === 'warn' ? T.warnRing : T.border;
  const badge = state === 'ok' ? badgeOk() : state === 'warn' ? badgeWarn() : badgeNum(n);
  const priceTone = state === 'warn' && !price ? 'warn' : 'idle';
  const nameTone = state === 'warn' && !name ? 'warn' : 'idle';
  const pad = compact ? 12 : 14;
  const photo = src
    ? `<div style="position: relative; height: ${photoH}px; background: ${T.line};">${img(src)}${removeButton()}${badge}${ai && state !== 'ok' ? fillPill() : ''}</div>`
    : `<div style="position: relative; height: ${compact ? 110 : 120}px; margin: ${pad}px ${pad}px 0; border: 2px dashed #CBD5E1; border-radius: 12px; background: ${T.bg}; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px;">${icon('camera', 26, T.faint, 1.8)}<span style="font-size: 13.5px; font-weight: 700; color: ${T.muted};">Add a photo</span>${removeButton()}${badge}</div>`;
  const fields = compact
    ? `<div style="padding: 12px 12px ${wroteIt ? 8 : 12}px; display: flex; gap: 8px;">
          <div style="flex: 1; min-width: 0;">${field({ placeholder: 'What is it?', value: name, tone: nameTone, compact: true })}</div>
          <div style="width: 126px; flex-shrink: 0;">${field({ placeholder: 'How much?', value: price, prefix: 'GH₵', tone: priceTone, decimal: true, compact: true })}</div>
        </div>${wroteIt ? `<div style="padding: 0 12px 12px;">${wroteItLine()}</div>` : ''}`
    : `<div style="padding: 14px 14px 16px; display: flex; flex-direction: column; gap: 10px;">
          ${field({ placeholder: 'What is it?', value: name, tone: nameTone })}
          ${wroteIt ? wroteItLine() : ''}
          ${field({ placeholder: 'How much?', value: price, prefix: 'GH₵', tone: priceTone, decimal: true })}
        </div>`;
  const moreBlock = more === 'none' ? '' : moreRow({ open: more === 'open', compact, ai, category, description });
  return `<div style="background: ${T.surface}; border: 1.5px solid ${border}; border-radius: 16px; overflow: hidden; box-shadow: 0 1px 2px rgba(0,0,0,0.05);">
        ${photo}
        ${fields}
        ${moreBlock}
      </div>`;
};

// A product exactly as the storefront shows it: photo, name, price.
const shopCard = ({ src, name, price, h = 128 }) =>
  `<div style="background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 14px; overflow: hidden;">
        <div style="height: ${h}px; background: ${T.line};">${img(src)}</div>
        <div style="padding: 9px 11px 11px;">
          <div style="font-size: 13.5px; font-weight: 700; color: ${T.text}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${name}</div>
          <div style="font-size: 15px; font-weight: 800; color: ${T.text}; margin-top: 2px; font-variant-numeric: tabular-nums;">GH₵ ${price}</div>
        </div>
      </div>`;

// ── Desktop shell: content area at 1440, as design/polish-pass draws it ──
const desktop = (content, { height = 900 } = {}) => doc(`
<div style="position: relative; width: 1440px; height: ${height}px; background: ${T.bg}; color: ${T.text}; padding: 32px 40px 0; overflow: hidden;">
${content}
</div>`);

const desktopHeader = (title, sub, right = '') => `
  <div style="display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; margin-bottom: 24px; padding-top: 8px;">
    <div style="display: flex; align-items: center; gap: 16px;">
      <div style="width: 56px; height: 56px; border-radius: 16px; background: ${T.primary}; display: flex; align-items: center; justify-content: center; box-shadow: 0 1px 2px rgba(0,0,0,0.05); flex-shrink: 0;">${icon('cube', 28, '#fff', 1.8)}</div>
      <div>
        <h1 style="margin: 0; font-size: 30px; font-weight: 700; color: ${T.text}; line-height: 1.15;">${title}</h1>
        <p style="margin: 4px 0 0; font-size: 14px; color: ${T.muted};">${sub}</p>
      </div>
    </div>
    <div style="display: flex; align-items: center; gap: 12px;">${right}</div>
  </div>`;

const desktopStickyBar = (left, right) => `
  <div style="position: absolute; left: 0; right: 0; bottom: 0; padding: 16px 40px; background: rgba(255,255,255,0.95); border-top: 1px solid ${T.border}; backdrop-filter: blur(8px); display: flex; align-items: center; justify-content: space-between; gap: 16px;">
    <div style="font-size: 15px; font-weight: 600; color: ${T.muted};">${left}</div>
    ${right}
  </div>`;

// ═════════════════════════════════════════════════════════════════════════
// ONE DOOR — the page, at phone width
// ═════════════════════════════════════════════════════════════════════════
const SUB = 'Photo, name, price. The rest can wait.';

const spreadsheetLink = () => `<div style="text-align: center; font-size: 13.5px; font-weight: 600; color: ${T.muted}; padding-top: 2px;">Have a spreadsheet? <a href="#" style="color: ${T.primaryHover}; text-decoration: underline; text-underline-offset: 3px;">Upload it</a></div>`;

const start = phone(`
${pageHeader('Add products', SUB)}
    <div style="padding: 20px 16px 16px; display: flex; flex-direction: column; gap: 14px;">
      ${oneTile({ variant: 'phone' })}
      ${orRule()}
      ${secondary('Type it in', 'pencil')}
      ${spreadsheetLink()}
    </div>`);

const filling = phone(`
${pageHeader('4 items', 'Give each a name and a price.')}
    <div style="padding: 16px; display: flex; flex-direction: column; gap: 14px;">
      ${oneTile({ variant: 'strip' })}
      ${photoCard({ src: 'eggs.jpg', name: 'Fresh eggs, crate', price: '45', state: 'ok', category: 'Food' })}
      ${photoCard({ src: 'melon.jpg', name: 'Watermelon', price: '', state: 'warn', ai: true })}
      ${photoCard({ src: 'makeup.jpg', name: 'Lip gloss set, 6 shades', price: '60', state: 'ok', wroteIt: true, category: 'Beauty' })}
      ${photoCard({ name: 'Hair braiding', price: '80', state: 'ok' })}
    </div>`, {
  bottom: stickyBar(`${cta('Put 3 in shop', 'shop')}<div style="text-align: center; font-size: 13.5px; color: ${T.muted};">1 more needs a name or price</div>`),
});

const more = phone(`
${pageHeader('4 items', 'Give each a name and a price.')}
    <div style="padding: 16px; display: flex; flex-direction: column; gap: 14px;">
      ${photoCard({ src: 'makeup.jpg', name: 'Lip gloss set, 6 shades', price: '60', state: 'ok', wroteIt: true, more: 'open', ai: true, category: 'Beauty', description: 'Six shades in one set. Light on the lips, lasts all day.' })}
      ${photoCard({ name: 'Hair braiding', price: '80', state: 'ok' })}
    </div>`, {
  height: 1000,
  bottom: stickyBar(`${cta('Put 3 in shop', 'shop')}<div style="text-align: center; font-size: 13.5px; color: ${T.muted};">1 more needs a name or price</div>`),
});

const done = phone(`
    <div style="flex: 1; padding: 24px 16px 16px; display: flex; flex-direction: column; align-items: center; gap: 16px;">
      <div style="width: 80px; height: 80px; border-radius: 999px; background: ${T.soft}; border: 3px solid ${T.softBorder}; display: flex; align-items: center; justify-content: center;">${icon('check', 40, T.primary, 2.6)}</div>
      <div style="text-align: center;">
        <div style="font-size: 26px; font-weight: 800; letter-spacing: -0.02em; color: ${T.text};">4 in your shop</div>
        <div style="font-size: 15px; color: ${T.muted}; margin-top: 4px;">Buyers can see them now.</div>
      </div>
      <div style="width: 100%; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; margin-top: 6px;">
        ${shopCard({ src: 'eggs.jpg', name: 'Fresh eggs, crate', price: '45' })}
        ${shopCard({ src: 'melon.jpg', name: 'Watermelon', price: '15' })}
        ${shopCard({ src: 'makeup.jpg', name: 'Lip gloss set, 6 shades', price: '60' })}
        ${shopCard({ src: 'sewing.jpg', name: 'Kaba and slit', price: '250' })}
      </div>
    </div>`, {
  bottom: stickyBar(`${cta('See my shop', 'shop')}${secondary('Add more', 'camera')}`),
});

// ═════════════════════════════════════════════════════════════════════════
// ONE DOOR — desktop
// ═════════════════════════════════════════════════════════════════════════
const desktopPage = desktop(`
${desktopHeader('Add products', SUB, adminButton('Upload a spreadsheet', 'upload'))}
  <div style="display: grid; grid-template-columns: 2fr 1fr; gap: 16px; margin-bottom: 20px;">
    ${oneTile({ variant: 'desktop' })}
    ${typedTile()}
  </div>
  <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; align-items: start;">
    ${photoCard({ src: 'eggs.jpg', name: 'Fresh eggs, crate', price: '45', state: 'ok', photoH: 170, compact: true, category: 'Food' })}
    ${photoCard({ src: 'melon.jpg', name: 'Watermelon', price: '', state: 'warn', photoH: 170, compact: true, ai: true })}
    ${photoCard({ src: 'makeup.jpg', name: 'Lip gloss set, 6 shades', price: '60', state: 'ok', photoH: 170, compact: true, wroteIt: true, more: 'open', ai: true, category: 'Beauty', description: 'Six shades in one set. Light on the lips, lasts all day.' })}
    ${photoCard({ name: 'Hair braiding', price: '80', state: 'ok', compact: true })}
    ${photoCard({ src: 'sewing.jpg', name: 'Kaba and slit', price: '250', state: 'ok', photoH: 170, compact: true, category: 'Fashion' })}
    ${photoCard({ src: 'citrus.jpg', state: 'todo', n: 6, photoH: 170, compact: true, ai: true })}
  </div>
${desktopStickyBar('4 ready · 2 need a name or price', cta('Put 4 in shop', 'shop', { width: '280px' }))}`, { height: 900 });

// ═════════════════════════════════════════════════════════════════════════
// MAPS — today's five doors beside the one door
// ═════════════════════════════════════════════════════════════════════════
const miniBtn = (label, ic, primary = false) => primary
  ? `<span style="display: inline-flex; align-items: center; gap: 6px; height: 30px; padding: 0 11px; border-radius: 9px; background: ${T.primary}; color: #fff; font-size: 12.5px; font-weight: 700; white-space: nowrap;">${icon(ic, 15, '#fff', 2)}<span>${label}</span></span>`
  : `<span style="display: inline-flex; align-items: center; gap: 6px; height: 30px; padding: 0 11px; border-radius: 9px; border: 1px solid ${T.border}; background: ${T.surface}; color: ${T.text}; font-size: 12.5px; font-weight: 700; white-space: nowrap;">${icon(ic, 15, T.muted, 2)}<span>${label}</span></span>`;

const mapBox = ({ x, y, w, h, title, inner, tone = 'plain' }) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px; background: ${tone === 'soft' ? T.soft : T.surface}; border: 1px solid ${tone === 'soft' ? T.softBorder : T.border}; border-radius: 14px; padding: 12px 14px; display: flex; flex-direction: column; gap: 10px; box-shadow: 0 1px 2px rgba(0,0,0,0.04);">
    <div style="font-size: 11.5px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; color: ${tone === 'soft' ? T.primaryHover : T.faint};">${title}</div>
    ${inner}
  </div>`;

const mapText = (text) => `<div style="font-size: 13.5px; line-height: 1.45; color: ${T.ink2};">${text}</div>`;

const mapFrame = ({ w, h, title, sub, boxes, lines }) => doc(`
<div style="position: relative; width: ${w}px; height: ${h}px; background: ${T.bg}; color: ${T.text}; overflow: hidden;">
  <div style="position: absolute; left: 24px; top: 20px;">
    <div style="font-size: 18px; font-weight: 800; letter-spacing: -0.01em;">${title}</div>
    <div style="font-size: 13px; color: ${T.muted}; margin-top: 3px;">${sub}</div>
  </div>
  <svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" style="position: absolute; inset: 0; pointer-events: none;" aria-hidden="true">
    <defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#94A3B8"/></marker></defs>
    ${lines.map(([x1, y1, x2, y2, dashed]) => `<path d="M${x1},${y1} C${x1},${(y1 + y2) / 2} ${x2},${(y1 + y2) / 2} ${x2},${y2}" fill="none" stroke="#94A3B8" stroke-width="1.5"${dashed ? ' stroke-dasharray="4 4"' : ''} marker-end="url(#arrow)"/>`).join('')}
  </svg>
  ${boxes.join('')}
</div>`);

const todayMap = mapFrame({
  w: 760, h: 560,
  title: 'Today: five doors, four pages',
  sub: 'Three of them look nothing like each other.',
  boxes: [
    mapBox({ x: 240, y: 74, w: 280, h: 84, title: 'Products page', inner: `<div style="display: flex; gap: 8px;">${miniBtn('Add by photo', 'sparkles')}${miniBtn('Add products', 'camera', true)}</div>` }),
    mapBox({ x: 180, y: 204, w: 400, h: 124, title: '/admin/products/new', inner: `<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">${miniBtn('Take a photo', 'camera', true)}${miniBtn('Choose photos', 'photo')}${miniBtn('Type it in', 'pencil')}${miniBtn('Upload a file', 'upload')}</div>` }),
    mapBox({ x: 24, y: 384, w: 228, h: 152, title: '/admin/products/new/form', inner: mapText('Nine fields. Title, description, category, product type, tags, price, SEO title, SEO description, images. Then Save as draft or Save and activate.') }),
    mapBox({ x: 266, y: 384, w: 228, h: 152, title: '/admin/products/snap', inner: mapText('From the Products page, only when AI is on. The AI fills five fields from the photo; you add the price.') }),
    mapBox({ x: 508, y: 384, w: 228, h: 152, title: 'CSV sheet, on Products', inner: mapText('Upload a file leaves this page for the Products list, which opens the upload sheet there.') }),
  ],
  lines: [
    [380, 158, 380, 202],
    [380, 328, 138, 382],
    [380, 328, 380, 382],
    [380, 328, 622, 382],
  ],
});

const miniCard = () => `<div style="display: flex; align-items: center; gap: 8px; border: 1px solid ${T.border}; border-radius: 12px; padding: 8px; background: ${T.surface};">
      <div style="position: relative; width: 54px; height: 44px; border-radius: 8px; overflow: hidden; background: ${T.line}; flex-shrink: 0;">${img('eggs.jpg')}<span style="position: absolute; left: 4px; bottom: 4px; height: 18px; padding: 0 6px; border-radius: 999px; background: rgba(255,255,255,0.94); color: ${T.primaryHover}; font-size: 10px; font-weight: 800; display: inline-flex; align-items: center; gap: 3px;">${icon('sparkles', 10, T.primary, 2.2)}Fill it in</span></div>
      <div style="flex: 1; height: 34px; border: 1.5px solid ${T.border}; border-radius: 9px; display: flex; align-items: center; padding: 0 10px; font-size: 12.5px; font-weight: 600; color: ${T.faint};">What is it?</div>
      <div style="width: 92px; height: 34px; border: 1.5px solid ${T.border}; border-radius: 9px; display: flex; align-items: center; padding: 0 10px; font-size: 12.5px; font-weight: 600; color: ${T.faint};">GH₵</div>
      <div style="height: 34px; padding: 0 10px; display: inline-flex; align-items: center; gap: 5px; font-size: 12.5px; font-weight: 700; color: ${T.muted};">${icon('bars', 14, T.faint, 2)}More ${icon('chevronDown', 12, T.faint, 2.2)}</div>
    </div>`;

const oneDoorMap = mapFrame({
  w: 760, h: 560,
  title: 'One door: one page, one card',
  sub: 'Everything a product needs, in the same place.',
  boxes: [
    mapBox({ x: 240, y: 74, w: 280, h: 72, title: 'Products page', inner: `<div>${miniBtn('Add products', 'camera', true)}</div>` }),
    mapBox({ x: 100, y: 192, w: 560, h: 258, title: '/admin/products/new', tone: 'soft', inner: `
      <div style="display: flex; align-items: center; gap: 10px; height: 48px; border: 2px dashed ${T.mint}; border-radius: 12px; background: rgba(255,255,255,0.7); padding: 0 10px 0 12px;">
        <div style="width: 30px; height: 30px; border-radius: 999px; background: ${T.primary}; display: flex; align-items: center; justify-content: center;">${icon('camera', 16, '#fff', 2)}</div>
        <div style="flex: 1; font-size: 13.5px; font-weight: 800; color: ${T.text};">Add photos <span style="font-weight: 500; color: ${T.muted};">· one tile, camera and gallery</span></div>
        ${galleryPill(28)}
      </div>
      <div style="font-size: 12.5px; font-weight: 700; color: ${T.primaryHover}; margin-top: 2px;">Every product is a card. A photo, a name, a price.</div>
      ${miniCard()}
      <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; font-size: 12.5px; line-height: 1.4; color: ${T.ink2};">
        <div><b>More</b>, inside the card: category and description, opening in place.</div>
        <div><b>Fill it in</b>: the AI reads the photo. Shown only when AI is on.</div>
        <div><b>Type it in</b>: a card without a photo, on this page.</div>
        <div><b>Upload a spreadsheet</b>: the same CSV sheet, opened here.</div>
      </div>` }),
    mapBox({ x: 100, y: 486, w: 560, h: 56, title: 'Later, on the product', inner: mapText('Product type, SEO, digital files, variants: the edit page keeps them, once the product exists.') }),
  ],
  lines: [
    [380, 146, 380, 190],
    [380, 450, 380, 484, true],
  ],
});

// ═════════════════════════════════════════════════════════════════════════
// ALTERNATE — grow the shelf (low-fi): no add page, the list takes photos
// ═════════════════════════════════════════════════════════════════════════
const greyBar = (w, h = 10) => `<div style="width: ${w}; height: ${h}px; border-radius: 5px; background: ${T.border};"></div>`;
const loFiProduct = () => `<div style="border: 1px solid ${T.border}; border-radius: 14px; overflow: hidden; background: ${T.surface};">
        <div style="height: 96px; background: ${T.line};"></div>
        <div style="padding: 10px; display: flex; flex-direction: column; gap: 7px;">${greyBar('80%')}${greyBar('40%')}</div>
      </div>`;
const loFiDraft = ({ name = '', price = '' }) => {
  const ok = name && price;
  return `<div style="position: relative; border: 1.5px solid ${ok ? T.primary : T.warnRing}; border-radius: 14px; overflow: hidden; background: ${T.surface};">
        <div style="position: relative; height: 96px; background: ${T.line}; display: flex; align-items: center; justify-content: center;">${icon('photo', 28, T.faint, 1.6)}${ok ? badgeOk() : badgeWarn()}</div>
        <div style="padding: 10px; display: flex; flex-direction: column; gap: 7px;">
          <div style="height: 40px; border: 2px solid ${name ? T.border : T.warnRing}; border-radius: 10px; background: ${name ? T.surface : '#FFFBEB'}; display: flex; align-items: center; padding: 0 10px; font-size: 13.5px; font-weight: 600; color: ${name ? T.text : T.faint};">${name || 'What is it?'}</div>
          <div style="height: 40px; border: 2px solid ${price ? T.border : T.warnRing}; border-radius: 10px; background: ${price ? T.surface : '#FFFBEB'}; display: flex; align-items: center; padding: 0 10px; font-size: 13.5px; font-weight: 700; color: ${price ? T.text : T.muted};">GH₵ ${price}</div>
        </div>
      </div>`;
};

const shelfAlt = phone(`
    <div style="display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 16px 16px 0;">
      <h1 style="margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.02em; color: ${T.text};">Products</h1>
      <div style="font-size: 13px; font-weight: 800; color: ${T.muted}; background: ${T.line}; padding: 6px 12px; border-radius: 999px;">12 in shop</div>
    </div>
    <div style="padding: 16px; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px;">
      <div style="position: relative; border: 2px dashed ${T.mint}; background: rgba(236,253,245,0.6); border-radius: 14px; min-height: 216px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10px;">
        ${disc(56, 'camera', { iconSize: 28 })}
        <div style="font-size: 16px; font-weight: 800; color: ${T.text};">Add</div>
        ${galleryPill(32, 'right: 8px; bottom: 8px;')}
      </div>
      ${loFiDraft({ name: 'Shea butter', price: '25' })}
      ${loFiDraft({})}
      ${loFiProduct()}
      ${loFiProduct()}
      ${loFiProduct()}
      ${loFiProduct()}
      ${loFiProduct()}
    </div>`, {
  bottom: stickyBar(`${cta('Put 1 in shop', 'shop')}<div style="text-align: center; font-size: 13.5px; color: ${T.muted};">1 more needs a name or price</div>`),
});

// ── Write everything ─────────────────────────────────────────────────────
const files = {
  'Main.dc.html': filling,
  'Start.dc.html': start,
  'More.dc.html': more,
  'Done.dc.html': done,
  'Desktop.dc.html': desktopPage,
  'TodayMap.dc.html': todayMap,
  'OneDoorMap.dc.html': oneDoorMap,
  'ShelfAlt.dc.html': shelfAlt,
};
for (const [name, html] of Object.entries(files)) writeFileSync(join(here, name), html);

const DOOR = 'page-one-door', ALT = 'page-alternate';
const row2 = 1140;
const canvas = {
  pages: [
    { id: DOOR, name: 'One door' },
    { id: ALT, name: 'Alternate' },
  ],
  artboards: [
    { file: 'Start.dc.html', x: 0, y: 0, w: 390, h: 844, title: 'One door — start', page: DOOR },
    { file: 'Main.dc.html', x: 470, y: 0, w: 390, h: 844, title: 'One door — filling', page: DOOR },
    { file: 'More.dc.html', x: 940, y: 0, w: 390, h: 1000, title: 'One door — More, opened', page: DOOR },
    { file: 'Done.dc.html', x: 1410, y: 0, w: 390, h: 844, title: 'One door — in the shop (unchanged)', page: DOOR },
    { file: 'Desktop.dc.html', x: 1880, y: 0, w: 1440, h: 900, title: 'One door — desktop', page: DOOR },
    { file: 'TodayMap.dc.html', x: 0, y: row2, w: 760, h: 560, title: 'Today — five doors', page: DOOR },
    { file: 'OneDoorMap.dc.html', x: 840, y: row2, w: 760, h: 560, title: 'One door — the map', page: DOOR },

    { file: 'ShelfAlt.dc.html', x: 0, y: 0, w: 390, h: 844, title: 'Alternate — grow the shelf (low-fi)', page: ALT },
  ],
  annotations: [
    { id: 'door-note', x: -500, y: 0, w: 440, page: DOOR, text:
      'ONE DOOR — what consolidates\n\nOne tile. On a phone the body opens the camera and the small Gallery pill opens the photo library; on a desktop the body picks files and takes a drop. Two tiles become one.\n\nOne card. A typed product is the same card without a photo, on this page. The separate nine-field form goes; product type, SEO and files stay on the edit page, where they already live.\n\nMore, inside the card: category chips and a description, opening in place. Two things, not nine. A filled category shows on the closed row.\n\nFill it in: the AI snap page becomes a pill on the photo, shown only when AI is on. It writes the name, category and description, and the amber line says so.\n\nUpload a spreadsheet opens the existing CSV sheet on this page, not on Products.\n\nProducts page: one button, Add products.' },
    { id: 'today-note', x: -500, y: row2, w: 440, page: DOOR, text:
      'TODAY\n\nTwo buttons on the Products page, four on this one. Three of the six lead to pages in the old style: the nine-field form, the AI snap page, the CSV sheet on the Products list. A merchant meets three different pages for one job, and the desktop page is two tiles and empty space.' },
    { id: 'alt-note', x: -500, y: 0, w: 440, page: ALT, text:
      'ALTERNATE — grow the shelf (low-fi)\n\nNo add page at all. The camera tile is the first tile on the Products page; new photos land as amber draft tiles at the top, get a name and a price where they stand, and turn into products in place.\n\nFor: the merchant never leaves the list, and the shop grows in front of them.\n\nAgainst: thirty photos flood the list, and the list page has to carry uploads, card states and a publish bar. Typed products and spreadsheets still need a home.' },
  ],
  launch: { view: 'canvas', page: DOOR },
};
writeFileSync(join(here, 'canvas.json'), JSON.stringify(canvas, null, 2) + '\n');
console.log(`wrote ${Object.keys(files).length} artboards + canvas.json`);
