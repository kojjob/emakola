// Generates the artboards for the "Add Products Redesign" canvas.
// Run: node build.mjs   (writes *.dc.html + canvas.json beside this file)
//
// Tokens are lifted from assets/css/app.css @theme and the live admin shell
// (app.html.heex, sidebar_components.ex admin_topbar, admin_components.ex).
// Literacy-first control sizes (54px fields, 56px CTA, 13px radius) are the
// ones already used by design/onboarding (the chosen onboarding direction).

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

// ── Tokens (app.css @theme) ─────────────────────────────────────────────
const T = {
  bg: '#F8FAFC', surface: '#FFFFFF', border: '#E2E8F0', line: '#F1F5F9',
  text: '#0F172A', muted: '#64748B', faint: '#94A3B8', ink2: '#334155',
  primary: '#059669', primaryHover: '#047857', soft: '#ECFDF5', softBorder: '#A7F3D0', mint: '#6EE7B7',
  warn: '#D97706', warnSoft: '#FEF3C7', warnRing: '#F59E0B',
  danger: '#DC2626', dangerSoft: '#FEE2E2',
  sidebar: '#0C1F17',
};

// ── Icons: heroicons outline paths on a 24 grid ─────────────────────────
const P = {
  menu: '<path d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/>',
  search: '<path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>',
  bell: '<path d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0"/>',
  back: '<path d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"/>',
  camera: '<path d="M3 8.5A1.5 1.5 0 014.5 7h2.2l1.2-2h8.2l1.2 2h2.2A1.5 1.5 0 0121 8.5v9A1.5 1.5 0 0119.5 19h-15A1.5 1.5 0 013 17.5v-9z"/><circle cx="12" cy="12.5" r="3.4"/>',
  photo: '<path d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25z"/>',
  mic: '<path d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z"/>',
  check: '<path d="M4.5 12.75l6 6 9-13.5"/>',
  plus: '<path d="M12 4.5v15m7.5-7.5h-15"/>',
  x: '<path d="M6 18L18 6M6 6l12 12"/>',
  bang: '<path d="M12 8v4.5m0 3.5h.01"/>',
  arrowRight: '<path d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>',
  sparkles: '<path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 00-2.456 2.456z"/>',
  upload: '<path d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>',
  cloud: '<path d="M12 16.5V9.75m0 0l3 3m-3-3l-3 3M6.75 19.5a4.5 4.5 0 01-1.41-8.775 5.25 5.25 0 0110.233-2.33 3 3 0 013.758 3.848A3.752 3.752 0 0118 19.5H6.75z"/>',
  pencil: '<path d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L6.832 19.82a4.5 4.5 0 01-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 011.13-1.897L16.863 4.487zm0 0L19.5 7.125"/>',
  cube: '<path d="M21 7.5l-9-5.25L3 7.5m18 0l-9 5.25m9-5.25v9l-9 5.25M3 7.5l9 5.25M3 7.5v9l9 5.25m0-9v9"/>',
  shop: '<path d="M13.5 21v-7.5a.75.75 0 01.75-.75h3a.75.75 0 01.75.75V21m-4.5 0H2.36m11.14 0H18m0 0h3.64m-1.39 0V9.349m-16.5 11.65V9.35m0 0a3.001 3.001 0 003.75-.615A2.993 2.993 0 009.75 9.75c.896 0 1.7-.393 2.25-1.016a2.993 2.993 0 002.25 1.016c.896 0 1.7-.393 2.25-1.016a3.001 3.001 0 003.75.614m-16.5 0a3.004 3.004 0 01-.621-4.72L4.318 3.44A1.5 1.5 0 015.378 3h13.243a1.5 1.5 0 011.06.44l1.19 1.189a3 3 0 01-.621 4.72m-13.5 8.65h3.75a.75.75 0 00.75-.75V13.5a.75.75 0 00-.75-.75H6.75a.75.75 0 00-.75.75v3.75c0 .415.336.75.75.75z"/>',
  chevronDown: '<path d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>',
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
    @keyframes ring { 0% { transform: scale(1); opacity: .55; } 100% { transform: scale(2.1); opacity: 0; } }
    @keyframes shimmer { 0% { opacity: .35; } 50% { opacity: .7; } 100% { opacity: .35; } }
    ${extraCss}
  </style>
</helmet>
${body}
</x-dc>
</body>
</html>
`;

// The live admin top bar at phone width (sidebar_components.ex admin_topbar):
// 72px, white/80 + blur, hairline bottom, hamburger, search, bell, avatar.
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

// The live page header on /admin/products/new: back arrow, 24px bold title, 14px subtitle.
const pageHeader = (title, sub, { back = true, right = '' } = {}) => `
    <div style="display: flex; align-items: center; gap: 12px; padding: 16px 16px 0;">
      ${back ? `<button aria-label="Back to products" style="width: 40px; height: 40px; margin-left: -8px; border: 0; background: none; border-radius: 8px; display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0;">${icon('back', 20, T.muted, 2)}</button>` : ''}
      <div style="flex: 1; min-width: 0;">
        <h1 style="margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.2; color: ${T.text};">${title}</h1>
        ${sub ? `<p style="margin: 3px 0 0; font-size: 14px; color: ${T.muted};">${sub}</p>` : ''}
      </div>
      ${right}
    </div>`;

// Slim header used by the one-at-a-time flow: back, title, a "1 of 3" pill.
const slimHeader = (title, pill) => `
    <div style="display: flex; align-items: center; gap: 8px; padding: 10px 16px 0;">
      <button aria-label="Back" style="width: 40px; height: 40px; margin-left: -8px; border: 0; background: none; border-radius: 8px; display: flex; align-items: center; justify-content: center; cursor: pointer;">${icon('back', 20, T.muted, 2)}</button>
      <div style="flex: 1; font-size: 17px; font-weight: 700; color: ${T.text};">${title}</div>
      ${pill ? `<div style="font-size: 13px; font-weight: 800; color: ${T.muted}; background: ${T.line}; padding: 6px 12px; border-radius: 999px; font-variant-numeric: tabular-nums;">${pill}</div>` : ''}
    </div>`;

// ── Literacy-first controls (sizes from design/onboarding) ──────────────
const micButton = (h, s = 42) => `<button aria-label="Say it" style="position: absolute; right: ${s < 42 ? 5 : 6}px; top: ${(h - s) / 2}px; width: ${s}px; height: ${s}px; border: 0; border-radius: 999px; background: ${T.soft}; display: flex; align-items: center; justify-content: center; cursor: pointer;">${icon('mic', s < 42 ? 18 : 20, T.primaryHover, 1.9)}</button>`;

const field = ({ placeholder = '', value = '', mic = false, prefix = '', tone = 'idle', big = false, compact = false, decimal = false }) => {
  const border = tone === 'ok' ? T.primary : tone === 'warn' ? T.warnRing : T.border;
  const h = big ? 76 : compact ? 46 : 54;
  const fs = big ? 40 : compact ? 15.5 : 17;
  const padL = prefix ? (big ? 84 : compact ? 52 : 66) : compact ? 12 : 15;
  const padR = mic ? (compact ? 48 : 62) : compact ? 12 : 15;
  const radius = compact ? 11 : 13;
  return `<div style="position: relative;">
        ${prefix ? `<div style="position: absolute; left: ${compact ? 12 : 16}px; top: 0; height: ${h}px; display: flex; align-items: center; font-size: ${big ? 22 : compact ? 14.5 : 17}px; font-weight: 700; color: ${T.muted}; pointer-events: none;">${prefix}</div>` : ''}
        <input type="text"${decimal ? ' inputmode="decimal"' : ''} placeholder="${placeholder}" value="${value}" style="width: 100%; height: ${h}px; border: 2px solid ${border}; border-radius: ${radius}px; padding: 0 ${padR}px 0 ${padL}px; font-size: ${fs}px; font-weight: ${big ? 800 : 600}; color: ${T.text}; background: ${tone === 'warn' ? '#FFFBEB' : T.surface}; font-family: inherit; outline: none;${big ? ' font-variant-numeric: tabular-nums; letter-spacing: -0.02em;' : ''}" />
        ${mic ? micButton(h, compact ? 36 : 42) : ''}
      </div>`;
};

const cta = (label, ic = '', { width = '100%', height = 56 } = {}) =>
  `<button style="width: ${width}; height: ${height}px; border: 0; border-radius: 13px; background: ${T.primary}; color: #fff; padding: 0 24px; font-size: 16.5px; font-weight: 800; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 10px; box-shadow: 0 5px 14px rgba(5,150,105,0.28);">${ic ? icon(ic, 22, '#fff', 2) : ''}<span>${label}</span></button>`;

const secondary = (label, ic = '', { width = '100%', height = 54 } = {}) =>
  `<button style="width: ${width}; height: ${height}px; border: 2px solid ${T.border}; border-radius: 13px; background: ${T.surface}; color: ${T.text}; padding: 0 18px; font-size: 16px; font-weight: 700; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 9px;">${ic ? icon(ic, 20, T.muted, 2) : ''}<span>${label}</span></button>`;

// Live admin_button (px-4 py-2.5 text-sm font-semibold rounded-control) for desktop headers.
const adminButton = (label, ic, variant = 'secondary') => variant === 'primary'
  ? `<button style="display: inline-flex; align-items: center; gap: 8px; padding: 10px 16px; font-size: 14px; font-weight: 600; border-radius: 12px; border: 0; background: ${T.primary}; color: #fff; cursor: pointer;">${icon(ic, 20, '#fff', 1.8)}<span>${label}</span></button>`
  : `<button style="display: inline-flex; align-items: center; gap: 8px; padding: 10px 16px; font-size: 14px; font-weight: 600; border-radius: 12px; border: 1px solid ${T.border}; background: ${T.surface}; color: ${T.text}; cursor: pointer;">${icon(ic, 20, T.text, 1.8)}<span>${label}</span></button>`;

// Capture tiles. Primary = emerald dashed, big camera disc. Quiet = grey.
const tile = ({ ic, label, hint = '', tone = 'primary', height = 190, row = false }) => {
  const dir = row ? 'row' : 'column';
  if (tone === 'primary') {
    return `<button style="width: 100%; height: ${height}px; border: 2px dashed ${T.mint}; background: rgba(236,253,245,0.6); border-radius: 16px; display: flex; flex-direction: ${dir}; align-items: center; justify-content: center; gap: ${row ? 16 : 10}px; cursor: pointer; padding: 0 16px;">
          <div style="width: ${row ? 52 : 68}px; height: ${row ? 52 : 68}px; border-radius: 999px; background: ${T.primary}; display: flex; align-items: center; justify-content: center; box-shadow: 0 6px 16px rgba(5,150,105,0.3); flex-shrink: 0;">${icon('camera', row ? 26 : 34, '#fff', 1.8)}</div>
          <div style="display: flex; flex-direction: column; align-items: ${row ? 'flex-start' : 'center'}; gap: 3px;">
            <div style="font-size: 18px; font-weight: 800; color: ${T.text};">${label}</div>
            ${hint ? `<div style="font-size: 13.5px; color: ${T.muted};">${hint}</div>` : ''}
          </div>
        </button>`;
  }
  return `<button style="width: 100%; height: ${height}px; border: 2px dashed #CBD5E1; background: ${T.surface}; border-radius: 16px; display: flex; flex-direction: ${dir}; align-items: center; justify-content: center; gap: ${row ? 16 : 8}px; cursor: pointer; padding: 0 16px;">
          <div style="width: ${row ? 52 : 56}px; height: ${row ? 52 : 56}px; border-radius: 999px; background: ${T.line}; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">${icon(ic, 26, T.muted, 1.8)}</div>
          <div style="display: flex; flex-direction: column; align-items: ${row ? 'flex-start' : 'center'}; gap: 3px;">
            <div style="font-size: 16px; font-weight: 700; color: ${T.text};">${label}</div>
            ${hint ? `<div style="font-size: 13px; color: ${T.muted};">${hint}</div>` : ''}
          </div>
        </button>`;
};

const orRule = () => `<div style="display: flex; align-items: center; gap: 12px; padding: 2px 4px;"><div style="flex: 1; height: 1px; background: ${T.border};"></div><div style="font-size: 13px; font-weight: 600; color: ${T.faint};">or</div><div style="flex: 1; height: 1px; background: ${T.border};"></div></div>`;

// Badges that say "done", "needs something", or the card's number without words.
const badgeOk = (pos = 'top: 10px; right: 10px;') => `<div style="position: absolute; ${pos} width: 30px; height: 30px; border-radius: 999px; background: ${T.primary}; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 6px rgba(0,0,0,0.25);">${icon('check', 16, '#fff', 2.8)}</div>`;
const badgeWarn = (pos = 'top: 10px; right: 10px;') => `<div style="position: absolute; ${pos} width: 30px; height: 30px; border-radius: 999px; background: ${T.warnRing}; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 6px rgba(0,0,0,0.25);">${icon('bang', 18, '#fff', 3)}</div>`;
const badgeNum = (n, pos = 'top: 10px; right: 10px;') => `<div style="position: absolute; ${pos} width: 30px; height: 30px; border-radius: 999px; background: rgba(15,23,42,0.6); color: #fff; font-size: 13px; font-weight: 800; display: flex; align-items: center; justify-content: center; font-variant-numeric: tabular-nums;">${n}</div>`;
const removeButton = () => `<button aria-label="Remove photo" style="position: absolute; top: 10px; left: 10px; width: 30px; height: 30px; border: 0; border-radius: 999px; background: rgba(0,0,0,0.55); display: flex; align-items: center; justify-content: center; cursor: pointer;">${icon('x', 14, '#fff', 2.6)}</button>`;

const img = (src, style = '') => `<img src="${src}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block; ${style}" />`;

// One photo card: photo, then the only two things a product needs.
const photoCard = ({ src, name = '', price = '', state = 'todo', n = 1, photoH = 200, compact = false }) => {
  const border = state === 'ok' ? T.primary : state === 'warn' ? T.warnRing : T.border;
  const badge = state === 'ok' ? badgeOk() : state === 'warn' ? badgeWarn() : badgeNum(n);
  const priceTone = state === 'warn' && !price ? 'warn' : 'idle';
  const nameTone = state === 'warn' && !name ? 'warn' : 'idle';
  return `<div style="background: ${T.surface}; border: 1.5px solid ${border}; border-radius: 16px; overflow: hidden; box-shadow: 0 1px 2px rgba(0,0,0,0.05);">
        <div style="position: relative; height: ${photoH}px; background: ${T.line};">${img(src)}${removeButton()}${badge}</div>
        ${compact ? `<div style="padding: 12px; display: flex; gap: 8px;">
          <div style="flex: 1; min-width: 0;">${field({ placeholder: 'What is it?', value: name, tone: nameTone, compact: true })}</div>
          <div style="width: 126px; flex-shrink: 0;">${field({ placeholder: '0', value: price, prefix: 'GH₵', tone: priceTone, decimal: true, compact: true })}</div>
        </div>` : `<div style="padding: 14px 14px 16px; display: flex; flex-direction: column; gap: 10px;">
          ${field({ placeholder: 'What is it?', value: name, tone: nameTone })}
          ${field({ placeholder: 'How much?', value: price, prefix: 'GH₵', tone: priceTone, decimal: true })}
        </div>`}
      </div>`;
};

// A product exactly as the storefront shows it: photo, name, price.
const shopCard = ({ src, name, price, glow = false, h = 150, ghost = false }) => ghost
  ? `<div style="border: 2px dashed ${T.border}; border-radius: 14px; height: ${h + 58}px; display: flex; align-items: center; justify-content: center;">${icon('plus', 22, '#CBD5E1', 2)}</div>`
  : `<div style="background: ${T.surface}; border: 1.5px solid ${glow ? T.primary : T.border}; border-radius: 14px; overflow: hidden;${glow ? ` box-shadow: 0 0 0 4px rgba(5,150,105,0.16);` : ''}">
        <div style="position: relative; height: ${h}px; background: ${T.line};">${img(src)}${glow ? badgeOk('top: 8px; right: 8px;') : ''}</div>
        <div style="padding: 9px 11px 11px;">
          <div style="font-size: 13.5px; font-weight: 700; color: ${T.text}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${name}</div>
          <div style="font-size: 15px; font-weight: 800; color: ${T.text}; margin-top: 2px; font-variant-numeric: tabular-nums;">GH₵ ${price}</div>
        </div>
      </div>`;

// The picked photos, as a strip: this is the progress bar in direction B.
const thumbStrip = (items, size = 60) => `
    <div style="display: flex; align-items: center; gap: 10px; padding: 12px 16px 2px;">
      ${items.map((t) => {
        if (t.state === 'current') return `<div style="position: relative; width: ${size}px; height: ${size}px; border-radius: 14px; overflow: hidden; outline: 3px solid ${T.primary}; outline-offset: 2px; flex-shrink: 0;">${img(t.src)}</div>`;
        if (t.state === 'done') return `<div style="position: relative; width: ${size}px; height: ${size}px; border-radius: 14px; overflow: hidden; flex-shrink: 0;">${img(t.src)}<div style="position: absolute; right: 4px; bottom: 4px; width: 20px; height: 20px; border-radius: 999px; background: ${T.primary}; display: flex; align-items: center; justify-content: center;">${icon('check', 12, '#fff', 3)}</div></div>`;
        return `<div style="width: ${size}px; height: ${size}px; border-radius: 14px; overflow: hidden; opacity: 0.45; flex-shrink: 0;">${img(t.src)}</div>`;
      }).join('')}
      <div style="width: ${size}px; height: ${size}px; border-radius: 14px; border: 2px dashed #CBD5E1; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">${icon('plus', 22, T.faint, 2)}</div>
    </div>`;

const chip = (label, { on = false, ic = '' } = {}) =>
  `<button style="height: 42px; padding: 0 16px; border-radius: 999px; border: 1.5px solid ${on ? T.primary : T.border}; background: ${on ? T.soft : T.surface}; color: ${on ? T.primaryHover : T.text}; font-size: 14.5px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 7px; white-space: nowrap;">${on ? icon('check', 15, T.primaryHover, 3) : ic ? icon(ic, 16, T.muted, 2) : ''}<span>${label}</span></button>`;

const eyebrow = (text, right = '') => `<div style="display: flex; align-items: center; justify-content: space-between;"><div style="font-size: 11.5px; font-weight: 800; letter-spacing: 0.1em; text-transform: uppercase; color: ${T.faint};">${text}</div>${right}</div>`;

// Direction C's shelf: what is already in the shop today, growing as you go.
const shelfStrip = (items) => `
    <div style="display: flex; gap: 10px; overflow: hidden;">
      ${items.map((it) => it.ghost
        ? `<div style="width: 104px; flex-shrink: 0; border: 2px dashed ${T.border}; border-radius: 14px; display: flex; align-items: center; justify-content: center; min-height: 128px;">${icon('plus', 22, '#CBD5E1', 2)}</div>`
        : `<div style="width: 104px; flex-shrink: 0;">${shopCard({ src: it.src, name: it.name, price: it.price, glow: !!it.glow, h: 78 })}</div>`).join('')}
    </div>`;

// ── Desktop shell: content area at 1440, as design/polish-pass draws it ──
const desktop = (content, { height = 900 } = {}) => doc(`
<div style="position: relative; width: 1440px; height: ${height}px; background: ${T.bg}; color: ${T.text}; padding: 32px 40px 0; overflow: hidden;">
${content}
</div>`);

// Live admin_page_header with icon badge: 56px emerald tile, 30px bold title.
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
// TODAY — the page as it ships, at phone width, tall enough to see it all
// ═════════════════════════════════════════════════════════════════════════
const liveInput = (placeholder, { rows = 0, value = '' } = {}) => rows
  ? `<textarea rows="${rows}" placeholder="${placeholder}" style="width: 100%; padding: 10px 12px; font-size: 14px; border-radius: 8px; border: 1px solid ${T.border}; background: ${T.surface}; font-family: inherit; color: ${T.text}; resize: vertical;"></textarea>`
  : `<input type="text" placeholder="${placeholder}" value="${value}" style="width: 100%; padding: 10px 12px; font-size: 14px; border-radius: 8px; border: 1px solid ${T.border}; background: ${T.surface}; font-family: inherit; color: ${T.text}; outline: none;" />`;
const liveSelect = (text) => `<div style="position: relative;"><div style="width: 100%; padding: 10px 36px 10px 12px; font-size: 14px; border-radius: 8px; border: 1px solid ${T.border}; background: ${T.surface}; color: ${T.text};">${text}</div><div style="position: absolute; right: 12px; top: 50%; transform: translateY(-50%); display: flex;">${icon('chevronDown', 14, T.muted, 2)}</div></div>`;
const liveLabel = (text, req = false) => `<label style="display: block; font-size: 14px; font-weight: 500; margin-bottom: 6px; color: ${T.text};">${text}${req ? ` <span style="color: #EF4444;">*</span>` : ''}</label>`;
const liveHint = (text) => `<p style="margin: 4px 0 0; font-size: 12px; color: ${T.muted};">${text}</p>`;
const liveCard = (inner) => `<div style="background: ${T.surface}; border-radius: 8px; padding: 20px; display: flex; flex-direction: column; gap: 16px;">${inner}</div>`;

const today = phone(`
${pageHeader('New Product', 'Add a new product to your catalog')}
    <div style="padding: 16px; display: flex; flex-direction: column; gap: 24px;">
      ${liveCard(`
        <h2 style="margin: 0; font-size: 16px; font-weight: 600;">Basic Information</h2>
        <div>${liveLabel('Title', true)}${liveInput('e.g., Ankara Print Fabric')}</div>
        <div>${liveLabel('Description')}${liveInput('Describe your product...', { rows: 4 })}</div>
        <div>${liveLabel('Category')}${liveSelect('No category')}</div>
        <div>${liveLabel('Product type')}${liveSelect('Physical — you ship it')}${liveHint('Selling files instead? Turn on digital downloads in <u>settings</u>.')}</div>
        <div>${liveLabel('Tags')}${liveInput('e.g., ankara, fabric, fashion (comma-separated)')}${liveHint('Separate tags with commas')}</div>
        <div>${liveLabel('Price (GHS)')}${liveInput('e.g. 25.00')}${liveHint('Required to publish. You can add more pricing options later.')}</div>
      `)}
      ${liveCard(`
        <div><h2 style="margin: 0; font-size: 16px; font-weight: 600;">SEO</h2><p style="margin: 4px 0 0; font-size: 12px; color: ${T.muted};">Optimize how your product appears in search results</p></div>
        <div>${liveLabel('SEO Title')}${liveInput('Custom title for search engines')}${liveHint('0/70 characters')}</div>
        <div>${liveLabel('SEO Description')}${liveInput('Brief description for search results', { rows: 2 })}${liveHint('0/160 characters')}</div>
      `)}
      ${liveCard(`
        <div>
          <h3 style="margin: 0; font-size: 14px; font-weight: 600; color: ${T.muted}; text-transform: uppercase; letter-spacing: 0.05em;">Images</h3>
          <p style="margin: 4px 0 0; font-size: 12px; color: ${T.faint};">Upload up to 5 images (JPG, PNG, WebP, max 10MB each)</p>
        </div>
        <div style="border: 2px dashed #CBD5E1; border-radius: 8px; padding: 16px; text-align: center; display: flex; flex-direction: column; align-items: center; gap: 6px;">
          ${icon('cloud', 32, T.faint, 1.6)}
          <div style="font-size: 14px; font-weight: 500; color: #475569;">Drag &amp; drop images here</div>
          <div style="font-size: 12px; color: ${T.faint};">or</div>
          <div style="padding: 6px 12px; font-size: 12px; font-weight: 600; background: ${T.line}; color: ${T.ink2}; border-radius: 8px;">Browse files</div>
        </div>
      `)}
      <div style="display: flex; flex-direction: column; gap: 12px; padding-top: 8px;">
        <button style="width: 100%; padding: 10px 16px; border-radius: 8px; font-size: 14px; font-weight: 600; border: 2px solid ${T.primary}; color: ${T.primaryHover}; background: transparent; cursor: pointer;">Save as Draft</button>
        <button style="width: 100%; padding: 10px 16px; border-radius: 8px; font-size: 14px; font-weight: 600; border: 0; color: #fff; background: ${T.primary}; cursor: pointer; box-shadow: 0 1px 2px rgba(0,0,0,0.05);">Save &amp; Activate</button>
      </div>
    </div>`, { height: 1600 });

// ═════════════════════════════════════════════════════════════════════════
// A — PHOTO CARDS. One photo or thirty; every photo becomes a card.
// ═════════════════════════════════════════════════════════════════════════
const cardsStart = phone(`
${pageHeader('Add products', 'Photo first. Name and price after.')}
    <div style="padding: 20px 16px 16px; display: flex; flex-direction: column; gap: 14px;">
      ${tile({ ic: 'camera', label: 'Take a photo', hint: 'One item, one photo', height: 230 })}
      ${tile({ ic: 'photo', label: 'Choose photos', hint: 'Up to 30 at once', tone: 'quiet', height: 140 })}
      ${orRule()}
      <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px;">
        ${secondary('Type it in', 'pencil')}
        ${secondary('Upload a file', 'upload')}
      </div>
    </div>`);

const cardsFill = phone(`
${pageHeader('4 photos', 'Give each a name and a price.')}
    <div style="padding: 16px; display: flex; flex-direction: column; gap: 14px;">
      ${photoCard({ src: 'eggs.jpg', name: 'Fresh eggs, crate', price: '45', state: 'ok' })}
      ${photoCard({ src: 'melon.jpg', name: 'Watermelon', price: '', state: 'warn' })}
      ${photoCard({ src: 'citrus.jpg', state: 'todo', n: 3 })}
      ${photoCard({ src: 'braids.jpg', state: 'todo', n: 4 })}
    </div>`, {
  bottom: stickyBar(`${cta('Put 1 in shop', 'shop')}<div style="text-align: center; font-size: 13.5px; color: ${T.muted};">3 more need a name or price</div>`),
});

const cardsDone = phone(`
    <div style="flex: 1; padding: 24px 16px 16px; display: flex; flex-direction: column; align-items: center; gap: 16px;">
      <div style="width: 80px; height: 80px; border-radius: 999px; background: ${T.soft}; border: 3px solid ${T.softBorder}; display: flex; align-items: center; justify-content: center;">${icon('check', 40, T.primary, 2.6)}</div>
      <div style="text-align: center;">
        <div style="font-size: 26px; font-weight: 800; letter-spacing: -0.02em; color: ${T.text};">4 in your shop</div>
        <div style="font-size: 15px; color: ${T.muted}; margin-top: 4px;">Buyers can see them now.</div>
      </div>
      <div style="width: 100%; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; margin-top: 6px;">
        ${shopCard({ src: 'eggs.jpg', name: 'Fresh eggs, crate', price: '45', h: 128 })}
        ${shopCard({ src: 'melon.jpg', name: 'Watermelon', price: '15', h: 128 })}
        ${shopCard({ src: 'citrus.jpg', name: 'Oranges, bowl', price: '10', h: 128 })}
        ${shopCard({ src: 'braids.jpg', name: 'Hair braiding', price: '80', h: 128 })}
      </div>
    </div>`, {
  bottom: stickyBar(`${cta('See my shop', 'shop')}${secondary('Add more', 'camera')}`),
});

const cardsDesktop = desktop(`
${desktopHeader('Add products', 'Photo first. Name and price after.', `${adminButton('Type it in', 'pencil')}${adminButton('Upload a file', 'upload')}`)}
  <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; margin-bottom: 20px;">
    ${tile({ ic: 'camera', label: 'Take a photo', hint: 'One item, one photo', height: 110, row: true })}
    ${tile({ ic: 'photo', label: 'Choose photos', hint: 'Up to 30 at once', tone: 'quiet', height: 110, row: true })}
  </div>
  <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px;">
    ${photoCard({ src: 'eggs.jpg', name: 'Fresh eggs, crate', price: '45', state: 'ok', photoH: 170, compact: true })}
    ${photoCard({ src: 'melon.jpg', name: 'Watermelon', price: '', state: 'warn', photoH: 170, compact: true })}
    ${photoCard({ src: 'citrus.jpg', state: 'todo', n: 3, photoH: 170, compact: true })}
    ${photoCard({ src: 'braids.jpg', name: 'Hair braiding', price: '80', state: 'ok', photoH: 170, compact: true })}
    ${photoCard({ src: 'sewing.jpg', name: 'Kaba and slit', price: '250', state: 'ok', photoH: 170, compact: true })}
    ${photoCard({ src: 'makeup.jpg', state: 'todo', n: 6, photoH: 170, compact: true })}
  </div>
${desktopStickyBar('3 ready · 3 need a name or price', cta('Put 3 in shop', 'shop', { width: '280px' }))}`, { height: 900 });

// ═════════════════════════════════════════════════════════════════════════
// B — ONE AT A TIME. The photos are the progress bar; one question per screen.
// ═════════════════════════════════════════════════════════════════════════
const stepName = phone(`
${slimHeader('Add products', '1 of 3')}
${thumbStrip([{ src: 'eggs.jpg', state: 'current' }, { src: 'melon.jpg', state: 'todo' }, { src: 'citrus.jpg', state: 'todo' }])}
    <div style="padding: 12px 16px 0; display: flex; flex-direction: column; gap: 18px;">
      <div style="position: relative; height: 250px; border-radius: 20px; overflow: hidden; background: ${T.line}; box-shadow: 0 10px 30px rgba(15,23,42,0.12);">${img('eggs.jpg')}</div>
      <div>
        <h1 style="margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.02em; color: ${T.text};">What is it?</h1>
        <p style="margin: 5px 0 0; font-size: 15px; color: ${T.muted};">Say it or type it.</p>
      </div>
      ${field({ placeholder: 'Name', mic: true })}
      <div style="display: flex; flex-direction: column; gap: 8px;">
        <div style="display: flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 700; color: ${T.muted};">${icon('sparkles', 16, T.primary, 1.8)}<span>Tap one</span></div>
        <div style="display: flex; gap: 8px; flex-wrap: wrap;">${chip('Fresh eggs')}${chip('Egg crate')}${chip('Eggs, 30 pieces')}</div>
      </div>
    </div>`, {
  bottom: stickyBar(cta('Next', 'arrowRight')),
});

const stepPrice = phone(`
${slimHeader('Add products', '2 of 3')}
${thumbStrip([{ src: 'eggs.jpg', state: 'done' }, { src: 'melon.jpg', state: 'current' }, { src: 'citrus.jpg', state: 'todo' }])}
    <div style="padding: 12px 16px 0; display: flex; flex-direction: column; gap: 18px;">
      <div style="position: relative; height: 150px; border-radius: 20px; overflow: hidden; background: ${T.line}; box-shadow: 0 10px 30px rgba(15,23,42,0.12);">${img('melon.jpg')}
        <div style="position: absolute; left: 12px; bottom: 12px; padding: 7px 12px; border-radius: 999px; background: rgba(255,255,255,0.92); font-size: 14px; font-weight: 800; color: ${T.text};">Watermelon</div>
      </div>
      <div>
        <h1 style="margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.02em; color: ${T.text};">How much?</h1>
        <p style="margin: 5px 0 0; font-size: 15px; color: ${T.muted};">One price. Sizes later.</p>
      </div>
      ${field({ placeholder: '0', value: '15', prefix: 'GH₵', big: true, decimal: true })}
      <div style="display: flex; gap: 8px; flex-wrap: wrap;">${chip('Same as last: GH₵ 45', { ic: 'clock' })}</div>
    </div>`, {
  bottom: stickyBar(cta('Next photo', 'arrowRight')),
});

const stepReady = phone(`
${slimHeader('Add products', '3 of 3')}
${thumbStrip([{ src: 'eggs.jpg', state: 'done' }, { src: 'melon.jpg', state: 'done' }, { src: 'citrus.jpg', state: 'done' }])}
    <div style="padding: 18px 16px 16px; display: flex; flex-direction: column; gap: 16px;">
      <div>
        <h1 style="margin: 0; font-size: 26px; font-weight: 800; letter-spacing: -0.02em; color: ${T.text};">3 ready</h1>
        <p style="margin: 5px 0 0; font-size: 15px; color: ${T.muted};">This is what buyers see.</p>
      </div>
      <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px;">
        ${shopCard({ src: 'eggs.jpg', name: 'Fresh eggs, crate', price: '45' })}
        ${shopCard({ src: 'melon.jpg', name: 'Watermelon', price: '15' })}
        ${shopCard({ src: 'citrus.jpg', name: 'Oranges, bowl', price: '10' })}
        ${shopCard({ ghost: true })}
      </div>
    </div>`, {
  bottom: stickyBar(`${cta('Put 3 in shop', 'shop')}${secondary('Save for later', 'clock')}`),
});

const stepDesktop = desktop(`
${desktopHeader('Add products', 'One question at a time.', `<div style="font-size: 14px; font-weight: 800; color: ${T.muted}; background: ${T.line}; padding: 8px 14px; border-radius: 999px;">2 of 3</div>`)}
  <div style="display: grid; grid-template-columns: 520px minmax(0, 1fr); gap: 24px; align-items: start;">
    <div style="background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 16px; padding: 20px; box-shadow: 0 1px 2px rgba(0,0,0,0.05); display: flex; flex-direction: column; gap: 16px;">
      <div style="display: flex; align-items: center; gap: 10px;">
        <div style="position: relative; width: 72px; height: 72px; border-radius: 14px; overflow: hidden; flex-shrink: 0;">${img('eggs.jpg')}<div style="position: absolute; right: 5px; bottom: 5px; width: 22px; height: 22px; border-radius: 999px; background: ${T.primary}; display: flex; align-items: center; justify-content: center;">${icon('check', 13, '#fff', 3)}</div></div>
        <div style="width: 72px; height: 72px; border-radius: 14px; overflow: hidden; outline: 3px solid ${T.primary}; outline-offset: 2px; flex-shrink: 0;">${img('melon.jpg')}</div>
        <div style="width: 72px; height: 72px; border-radius: 14px; overflow: hidden; opacity: 0.45; flex-shrink: 0;">${img('citrus.jpg')}</div>
        <div style="width: 72px; height: 72px; border-radius: 14px; border: 2px dashed #CBD5E1; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">${icon('plus', 24, T.faint, 2)}</div>
      </div>
      <div style="position: relative; height: 380px; border-radius: 16px; overflow: hidden; background: ${T.line};">${img('melon.jpg')}
        <div style="position: absolute; left: 14px; bottom: 14px; padding: 8px 14px; border-radius: 999px; background: rgba(255,255,255,0.92); font-size: 15px; font-weight: 800; color: ${T.text};">Watermelon</div>
      </div>
    </div>
    <div style="background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 16px; padding: 32px; box-shadow: 0 1px 2px rgba(0,0,0,0.05); display: flex; flex-direction: column; gap: 22px; min-height: 508px;">
      <div>
        <h2 style="margin: 0; font-size: 30px; font-weight: 800; letter-spacing: -0.02em; color: ${T.text};">How much?</h2>
        <p style="margin: 6px 0 0; font-size: 16px; color: ${T.muted};">One price. Sizes later.</p>
      </div>
      <div style="max-width: 460px;">${field({ placeholder: '0', value: '15', prefix: 'GH₵', big: true, decimal: true })}</div>
      <div style="display: flex; gap: 8px; flex-wrap: wrap;">${chip('Same as last: GH₵ 45', { ic: 'clock' })}</div>
      <div style="flex: 1;"></div>
      <div style="display: flex; justify-content: space-between; align-items: center; gap: 12px;">
        ${secondary('Back', 'back', { width: '150px' })}
        ${cta('Next photo', 'arrowRight', { width: '260px' })}
      </div>
    </div>
  </div>`);

// ═════════════════════════════════════════════════════════════════════════
// C — SNAP AND SAY. No typing: the AI names it, you say the price.
// ═════════════════════════════════════════════════════════════════════════
const shelfToday = [
  { src: 'melon.jpg', name: 'Watermelon', price: '15' },
  { src: 'citrus.jpg', name: 'Oranges, bowl', price: '10' },
  { ghost: true },
];

const saySnap = phone(`
${pageHeader('Add products', 'Snap it. We fill it in.')}
    <div style="padding: 18px 16px 16px; display: flex; flex-direction: column; gap: 18px;">
      <div style="display: flex; flex-direction: column; gap: 10px;">
        ${eyebrow('Your shelf today', `<div style="font-size: 13px; font-weight: 800; color: ${T.text};">2</div>`)}
        ${shelfStrip(shelfToday)}
      </div>
      ${tile({ ic: 'camera', label: 'Take a photo', hint: 'We read the photo for you', height: 290 })}
      <button style="height: 48px; border: 0; background: none; display: flex; align-items: center; justify-content: center; gap: 8px; font-size: 15.5px; font-weight: 700; color: ${T.primaryHover}; cursor: pointer;">${icon('photo', 20, T.primaryHover, 1.9)}<span>Choose from gallery</span></button>
    </div>
    <div style="flex: 1;"></div>
    <div style="padding: 0 16px 18px; text-align: center; font-size: 13px; color: ${T.faint};">Have a file? <u>Upload it</u></div>`);

const micPanel = (h = 76) => `
      <div style="display: flex; align-items: center; gap: 18px;">
        <div style="position: relative; width: ${h}px; height: ${h}px; flex-shrink: 0;">
          <div style="position: absolute; inset: 0; border-radius: 999px; background: rgba(5,150,105,0.25); animation: ring 1.6s ease-out infinite;"></div>
          <div style="position: absolute; inset: 0; border-radius: 999px; background: rgba(5,150,105,0.25); animation: ring 1.6s ease-out 0.5s infinite;"></div>
          <button aria-label="Say the price" style="position: relative; width: ${h}px; height: ${h}px; border: 0; border-radius: 999px; background: ${T.primary}; display: flex; align-items: center; justify-content: center; cursor: pointer; box-shadow: 0 6px 16px rgba(5,150,105,0.35);">${icon('mic', Math.round(h * 0.45), '#fff', 1.9)}</button>
        </div>
        <div style="flex: 1; min-width: 0;">
          <div style="font-size: 14px; font-style: italic; color: ${T.muted};">“forty-five cedis”</div>
          <div style="font-size: 36px; font-weight: 800; letter-spacing: -0.02em; color: ${T.text}; font-variant-numeric: tabular-nums; line-height: 1.1; margin-top: 2px;"><span style="font-size: 20px; color: ${T.muted}; font-weight: 700;">GH₵</span> 45</div>
        </div>
      </div>`;

const sayFill = phone(`
${slimHeader('Add products', '')}
    <div style="padding: 8px 16px 0; display: flex; flex-direction: column; gap: 18px;">
      <div style="position: relative; height: 210px; border-radius: 20px; overflow: hidden; background: ${T.line}; box-shadow: 0 10px 30px rgba(15,23,42,0.12);">${img('eggs.jpg')}
        <div style="position: absolute; left: 12px; bottom: 12px; display: flex; align-items: center; gap: 6px; padding: 7px 12px; border-radius: 999px; background: rgba(255,255,255,0.92); font-size: 12.5px; font-weight: 800; color: ${T.primaryHover};">${icon('sparkles', 14, T.primary, 2)}<span>Read from your photo</span></div>
      </div>
      <div style="display: flex; flex-direction: column; gap: 10px;">
        ${eyebrow('Name')}
        <button style="height: 54px; border: 2px solid ${T.primary}; border-radius: 13px; background: ${T.soft}; display: flex; align-items: center; justify-content: space-between; padding: 0 16px; cursor: pointer;"><span style="font-size: 18px; font-weight: 800; color: ${T.text};">Fresh eggs, crate</span>${icon('check', 22, T.primary, 3)}</button>
        <div style="display: flex; gap: 8px; flex-wrap: wrap;">${chip('Egg crate')}${chip('Eggs, 30 pieces')}${chip('Type it', { ic: 'pencil' })}</div>
      </div>
      <div style="display: flex; flex-direction: column; gap: 12px;">
        ${eyebrow('Price', `<div style="font-size: 13px; color: ${T.faint};">or <u>type it</u></div>`)}
        ${micPanel()}
        <div style="font-size: 14px; color: ${T.muted};">Tap the mic and say the price.</div>
      </div>
    </div>`, {
  bottom: stickyBar(`${cta('Put in shop', 'shop')}<div style="text-align: center; font-size: 13.5px; color: ${T.muted};"><u>Save for later</u></div>`),
});

const miniShop = ({ items, cols = 3, h = 78 }) => `
      <div style="border-radius: 16px; overflow: hidden; border: 1px solid ${T.border}; background: ${T.surface};">
        <div style="background: ${T.sidebar}; padding: 12px 14px; display: flex; align-items: center; justify-content: space-between;">
          <div style="font-size: 14px; font-weight: 800; color: #fff; letter-spacing: -0.01em;">Ama's Fresh Foods</div>
          <div style="display: flex; gap: 5px;"><div style="width: 22px; height: 6px; border-radius: 3px; background: rgba(255,255,255,0.35);"></div><div style="width: 22px; height: 6px; border-radius: 3px; background: rgba(255,255,255,0.35);"></div></div>
        </div>
        <div style="display: grid; grid-template-columns: repeat(${cols}, minmax(0, 1fr)); gap: 10px; padding: 12px;">
          ${items.map((it) => shopCard({ ...it, h })).join('')}
        </div>
      </div>`;

const sayShelf = phone(`
${pageHeader('Add products', 'Snap it. We fill it in.')}
    <div style="padding: 18px 16px 16px; display: flex; flex-direction: column; gap: 18px;">
      <div style="display: flex; flex-direction: column; gap: 10px;">
        ${eyebrow('Your shelf today', `<div style="font-size: 13px; font-weight: 800; color: ${T.text};">3</div>`)}
        ${shelfStrip([{ src: 'eggs.jpg', name: 'Fresh eggs, crate', price: '45', glow: true }, ...shelfToday])}
      </div>
      <div style="display: flex; flex-direction: column; gap: 10px;">
        ${eyebrow('What buyers see')}
        ${miniShop({ items: [
          { src: 'eggs.jpg', name: 'Fresh eggs', price: '45', glow: true },
          { src: 'melon.jpg', name: 'Watermelon', price: '15' },
          { src: 'citrus.jpg', name: 'Oranges', price: '10' },
        ], cols: 3, h: 72 })}
      </div>
    </div>`, {
  bottom: stickyBar(`${cta('Add another', 'camera')}${secondary('Done', 'check')}`),
});

const sayDesktop = desktop(`
${desktopHeader('Add products', 'Snap it. We fill it in.', adminButton('Upload a file', 'upload'))}
  <div style="display: grid; grid-template-columns: 600px minmax(0, 1fr); gap: 24px; align-items: start;">
    <div style="background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 16px; padding: 24px; box-shadow: 0 1px 2px rgba(0,0,0,0.05); display: flex; flex-direction: column; gap: 20px;">
      <div style="position: relative; height: 280px; border-radius: 16px; overflow: hidden; background: ${T.line};">${img('eggs.jpg')}
        <div style="position: absolute; left: 14px; bottom: 14px; display: flex; align-items: center; gap: 6px; padding: 8px 14px; border-radius: 999px; background: rgba(255,255,255,0.92); font-size: 13px; font-weight: 800; color: ${T.primaryHover};">${icon('sparkles', 15, T.primary, 2)}<span>Read from your photo</span></div>
        <button aria-label="Retake" style="position: absolute; right: 14px; top: 14px; height: 40px; padding: 0 14px; border: 0; border-radius: 999px; background: rgba(0,0,0,0.55); color: #fff; font-size: 13px; font-weight: 700; display: flex; align-items: center; gap: 7px; cursor: pointer;">${icon('camera', 18, '#fff', 2)}<span>Retake</span></button>
      </div>
      <div style="display: flex; flex-direction: column; gap: 10px;">
        ${eyebrow('Name')}
        <button style="height: 54px; border: 2px solid ${T.primary}; border-radius: 13px; background: ${T.soft}; display: flex; align-items: center; justify-content: space-between; padding: 0 16px; cursor: pointer;"><span style="font-size: 18px; font-weight: 800; color: ${T.text};">Fresh eggs, crate</span>${icon('check', 22, T.primary, 3)}</button>
        <div style="display: flex; gap: 8px; flex-wrap: wrap;">${chip('Egg crate')}${chip('Eggs, 30 pieces')}${chip('Type it', { ic: 'pencil' })}</div>
      </div>
      <div style="display: flex; flex-direction: column; gap: 12px;">
        ${eyebrow('Price', `<div style="font-size: 13px; color: ${T.faint};">or <u>type it</u></div>`)}
        ${micPanel(72)}
      </div>
      <div style="display: flex; justify-content: flex-end; gap: 12px;">
        ${secondary('Save for later', 'clock', { width: '190px' })}
        ${cta('Put in shop', 'shop', { width: '240px' })}
      </div>
    </div>
    <div style="display: flex; flex-direction: column; gap: 12px;">
      ${eyebrow('What buyers see', `<div style="font-size: 13px; font-weight: 800; color: ${T.text};">3 on the shelf</div>`)}
      ${miniShop({ items: [
        { src: 'eggs.jpg', name: 'Fresh eggs, crate', price: '45', glow: true },
        { src: 'melon.jpg', name: 'Watermelon', price: '15' },
        { src: 'citrus.jpg', name: 'Oranges, bowl', price: '10' },
        { ghost: true }, { ghost: true }, { ghost: true },
      ], cols: 3, h: 150 })}
      <div style="display: flex; align-items: center; gap: 10px; padding: 14px 16px; border-radius: 14px; background: ${T.soft}; border: 1px solid ${T.softBorder};">
        <div style="width: 40px; height: 40px; border-radius: 999px; background: ${T.primary}; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">${icon('camera', 20, '#fff', 2)}</div>
        <div style="font-size: 15px; font-weight: 700; color: ${T.primaryHover};">Two taps and one sentence per item. Keep going.</div>
      </div>
    </div>
  </div>`);

// ── Write everything ─────────────────────────────────────────────────────
// Chosen 2026-09-02: A, Photo cards. Its filling screen is the page itself,
// so it is Main; Today, B and C are parked on a second canvas page.
const files = {
  'Main.dc.html': cardsFill,
  'Today.dc.html': today,
  'CardsStart.dc.html': cardsStart,
  'CardsDone.dc.html': cardsDone,
  'CardsDesktop.dc.html': cardsDesktop,
  'StepName.dc.html': stepName,
  'StepPrice.dc.html': stepPrice,
  'StepReady.dc.html': stepReady,
  'StepDesktop.dc.html': stepDesktop,
  'SaySnap.dc.html': saySnap,
  'SayFill.dc.html': sayFill,
  'SayShelf.dc.html': sayShelf,
  'SayDesktop.dc.html': sayDesktop,
};
for (const [name, html] of Object.entries(files)) writeFileSync(join(here, name), html);

const CHOSEN = 'page-chosen', PARKED = 'page-parked';
const rowB = 1760, rowC = 2820;
const canvas = {
  pages: [
    { id: CHOSEN, name: 'Photo cards' },
    { id: PARKED, name: 'Not chosen' },
  ],
  artboards: [
    { file: 'CardsStart.dc.html', x: 0, y: 0, w: 390, h: 844, title: 'Photo cards — start', page: CHOSEN },
    { file: 'Main.dc.html', x: 470, y: 0, w: 390, h: 844, title: 'Photo cards — filling', page: CHOSEN },
    { file: 'CardsDone.dc.html', x: 940, y: 0, w: 390, h: 844, title: 'Photo cards — in the shop', page: CHOSEN },
    { file: 'CardsDesktop.dc.html', x: 1410, y: 0, w: 1440, h: 900, title: 'Photo cards — desktop', page: CHOSEN },

    { file: 'Today.dc.html', x: 0, y: 0, w: 390, h: 1600, title: 'Today — what ships now', page: PARKED },

    { file: 'StepName.dc.html', x: 0, y: rowB, w: 390, h: 844, title: 'B · One at a time — what is it', page: PARKED },
    { file: 'StepPrice.dc.html', x: 470, y: rowB, w: 390, h: 844, title: 'B · One at a time — how much', page: PARKED },
    { file: 'StepReady.dc.html', x: 940, y: rowB, w: 390, h: 844, title: 'B · One at a time — ready', page: PARKED },
    { file: 'StepDesktop.dc.html', x: 1410, y: rowB, w: 1440, h: 900, title: 'B · One at a time — desktop', page: PARKED },

    { file: 'SaySnap.dc.html', x: 0, y: rowC, w: 390, h: 844, title: 'C · Snap and say — start', page: PARKED },
    { file: 'SayFill.dc.html', x: 470, y: rowC, w: 390, h: 844, title: 'C · Snap and say — filled', page: PARKED },
    { file: 'SayShelf.dc.html', x: 940, y: rowC, w: 390, h: 844, title: 'C · Snap and say — on the shelf', page: PARKED },
    { file: 'SayDesktop.dc.html', x: 1410, y: rowC, w: 1440, h: 900, title: 'C · Snap and say — desktop', page: PARKED },
  ],
  annotations: [
    { id: 'chosen-note', x: -500, y: 0, w: 440, page: CHOSEN, text:
      'CHOSEN 2 Sep — Photo cards.\n\nPick one photo or thirty; every photo becomes a card with the two things it needs. Single and bulk are the same screen: single is a stack of one.\n\nA done card gets a green tick, a half-done card an amber ring and an amber field, so the eye finds the gaps without reading. The button counts what is ready and only puts the finished cards in the shop; the rest stay on the page.\n\nThe typed form and the CSV upload stay reachable as the two quiet buttons under the camera.\n\nTo build: today\'s Add many page (ProductLive.BulkPhoto) with the camera put in front, the card states made visible, and this page taking over the /admin/products/new address.' },
    { id: 'today-note', x: 470, y: 0, w: 440, page: PARKED, text:
      'TODAY — /admin/products/new at phone width, shown at full length.\n\nNine labelled fields before the photo. SEO title and SEO description, which a market seller will never fill, sit above the images. Two buttons that need reading to tell apart.\n\nThe three other ways in (Add by photo, Add many, CSV upload) live on the Products page header, so a merchant who lands here from the top-bar "+" never sees them.\n\nAll three directions started from the same three facts: a photo, a name, a price. Everything else moves behind the product once it exists.' },
    { id: 'b-note', x: -500, y: rowB, w: 440, page: PARKED, text:
      'B — ONE AT A TIME\n\nThe photos across the top are the progress bar; the current one is ringed, done ones get a tick. Each screen asks exactly one question with one big control, and the button says what happens next. The price is the largest thing on the page.\n\nBest for: a merchant who does not read well. Every screen can be understood from the picture and the size of things, and there is never more than one field on screen.\n\nCost: two screens per product, so thirty products is sixty taps of Next. The "Same as last" chip softens it for stalls that price everything alike.\n\nTo build: the name suggestions already exist behind Add by photo (AiGate); the mic reuses the voice hook on the supply network page. The rest is a small state machine over today\'s bulk upload.' },
    { id: 'c-note', x: -500, y: rowC, w: 440, text:
      'C — SNAP AND SAY\n\nNo typing at all. Take the photo; the AI reads it and offers three names to tap; say the price into the mic. The shelf at the top grows as you go, and the shop preview shows the item exactly as buyers will see it.\n\nBulk is just repetition: two taps and one sentence per product.\n\nBest for: a merchant who cannot read or type. The most adventurous of the three.\n\nCost: needs AI switched on (ANTHROPIC_API_KEY) and speech recognition wired to the price field. A noisy market makes the mic miss, so "type it" stays one tap away on both name and price.\n\nTo build: the photo-to-name step is the live Add by photo page; the mic is the supply network voice hook pointed at a number.' },
  ],
  launch: { view: 'canvas' },
};
writeFileSync(join(here, 'canvas.json'), JSON.stringify(canvas, null, 2) + '\n');
console.log(`wrote ${Object.keys(files).length} artboards + canvas.json`);
