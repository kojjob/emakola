// Generates the artboards for the "Orders Redesign" canvas.
// Run: node build.mjs   (writes *.dc.html + canvas.json beside this file)
//
// /admin/orders as it ships (OrderLive.Index, after the Sell redesign #437
// and the polish pass): header with badge, Scan a parcel, four stat tiles,
// segmented tabs with counts, search, rows with an initials disc, name,
// number · date, total, and Send it on a waiting order. Three directions,
// each at phone width and in the desktop content area, drawn for merchants
// who do not read well: the product photo says what was bought, the icon
// says where the order is, the money is the largest thing on the row.
// Tokens from assets/css/app.css @theme and the admin shell; photos are
// crops of design/stores-variations (real Ghanaian trader photography).

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

const T = {
  bg: '#F8FAFC', surface: '#FFFFFF', border: '#E2E8F0', line: '#F1F5F9',
  text: '#0F172A', muted: '#64748B', faint: '#94A3B8', ink2: '#334155',
  primary: '#059669', primaryHover: '#047857', soft: '#ECFDF5', softBorder: '#A7F3D0',
  amber: '#D97706', amberSoft: '#FEF3C7', amberText: '#B45309', amberRing: '#F59E0B',
  blue: '#2563EB', blueSoft: '#DBEAFE', blueText: '#1D4ED8',
  violet: '#7C3AED', violetSoft: '#EDE9FE', violetText: '#6D28D9',
  red: '#DC2626', redSoft: '#FEE2E2',
  mtn: '#FFC107', telecel: '#E60000', at: '#004F9F',
  whatsapp: '#25D366',
};

const P = {
  menu: '<path d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/>',
  search: '<path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>',
  bell: '<path d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0"/>',
  bag: '<path d="M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"/>',
  qr: '<path d="M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 013.75 9.375v-4.5zM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 01-1.125-1.125v-4.5zM13.5 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0113.5 9.375v-4.5z"/><path d="M6.75 6.75h.75v.75h-.75v-.75zM6.75 16.5h.75v.75h-.75v-.75zM16.5 6.75h.75v.75h-.75v-.75zM13.5 13.5h.75v.75h-.75v-.75zM13.5 19.5h.75v.75h-.75v-.75zM19.5 13.5h.75v.75h-.75v-.75zM19.5 19.5h.75v.75h-.75v-.75zM16.5 16.5h.75v.75h-.75v-.75z"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 2"/>',
  box: '<path d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"/>',
  truck: '<path d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"/>',
  check: '<path d="M4.5 12.75l6 6 9-13.5"/>',
  checkCircle: '<path d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>',
  chat: '<path d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z"/>',
  banknotes: '<path d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z"/>',
  arrowRight: '<path d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>',
  x: '<path d="M6 18L18 6M6 6l12 12"/>',
  chevronRight: '<path d="M8.25 4.5l7.5 7.5-7.5 7.5"/>',
  phone: '<path d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 4.5v2.25z"/>',
};
const icon = (name, size = 20, color = 'currentColor', sw = 1.8) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${P[name]}</svg>`;

const doc = (body) => `<!doctype html>
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
    button { font-family: inherit; }
  </style>
</helmet>
${body}
</x-dc>
</body>
</html>
`;

// ── Shells (the live admin_topbar and content area) ─────────────────────
const topbar = () => `
  <div style="height: 72px; flex-shrink: 0; display: flex; align-items: center; gap: 12px; padding: 0 16px; background: rgba(255,255,255,0.8); border-bottom: 1px solid rgba(226,232,240,0.8);">
    <button aria-label="Open sidebar" style="width: 36px; height: 36px; margin-left: -8px; border: 0; background: none; border-radius: 12px; display: flex; align-items: center; justify-content: center;">${icon('menu', 20, T.muted, 2)}</button>
    <div style="flex: 1; position: relative;">
      <div style="position: absolute; left: 14px; top: 50%; transform: translateY(-50%); display: flex;">${icon('search', 16, T.faint, 2)}</div>
      <input type="search" placeholder="Search anything..." aria-label="Search" style="width: 100%; padding: 10px 16px 10px 40px; background: rgba(248,250,252,0.8); border: 1px solid ${T.border}; border-radius: 12px; font-size: 14px; color: ${T.ink2}; font-family: inherit; outline: none;" />
    </div>
    <button aria-label="Notifications" style="width: 36px; height: 36px; border: 0; background: none; border-radius: 12px; display: flex; align-items: center; justify-content: center;">${icon('bell', 20, T.muted, 1.8)}</button>
    <div style="width: 36px; height: 36px; border-radius: 999px; background: ${T.soft}; color: ${T.primaryHover}; font-size: 13px; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">KA</div>
  </div>`;

const desktopTopbar = () => `
  <div style="height: 72px; flex-shrink: 0; display: flex; align-items: center; gap: 16px; padding: 0 32px; background: rgba(255,255,255,0.8); border-bottom: 1px solid rgba(226,232,240,0.8);">
    <div style="width: 440px; position: relative;">
      <div style="position: absolute; left: 14px; top: 50%; transform: translateY(-50%); display: flex;">${icon('search', 16, T.faint, 2)}</div>
      <div style="padding: 10px 16px 10px 40px; background: rgba(248,250,252,0.8); border: 1px solid ${T.border}; border-radius: 12px; font-size: 14px; color: ${T.faint};">Search anything...</div>
    </div>
    <div style="flex: 1;"></div>
    <div style="display: inline-flex; align-items: center; gap: 8px; padding: 8px 16px; border-radius: 12px; background: ${T.primary}; color: #fff; font-size: 14px; font-weight: 600;">+ New</div>
    ${icon('bell', 20, T.muted, 1.8)}
    <div style="display: flex; align-items: center; gap: 8px;"><div style="width: 36px; height: 36px; border-radius: 999px; background: ${T.soft}; color: ${T.primaryHover}; font-size: 13px; font-weight: 800; display: flex; align-items: center; justify-content: center;">KA</div><span style="font-size: 14px; font-weight: 600; color: ${T.text};">Kwame</span></div>
  </div>`;

const phone = (content, height) => doc(`
<div style="width: 390px; height: ${height}px; background: ${T.bg}; color: ${T.text}; display: flex; flex-direction: column; overflow: hidden;">
  ${topbar()}
  <div style="padding: 16px; display: flex; flex-direction: column; gap: 16px;">
${content}
  </div>
</div>`);

const desktop = (content, height = 900) => doc(`
<div style="width: 1440px; height: ${height}px; background: ${T.bg}; color: ${T.text}; overflow: hidden; display: flex; flex-direction: column;">
  ${desktopTopbar()}
  <div style="padding: 24px 32px; display: flex; flex-direction: column; gap: 20px; max-width: 1600px;">
${content}
  </div>
</div>`);

// Live admin_page_header: 56px emerald badge, 30px title, 14px subtitle.
const pageHeader = (wide, sub = 'Manage and track all customer orders', right = '') => `
    <div style="display: flex; align-items: ${wide ? 'flex-end' : 'center'}; justify-content: space-between; gap: 12px; padding-top: ${wide ? 8 : 4}px;">
      <div style="display: flex; align-items: center; gap: ${wide ? 16 : 12}px;">
        <div style="width: ${wide ? 56 : 44}px; height: ${wide ? 56 : 44}px; border-radius: ${wide ? 16 : 13}px; background: ${T.primary}; display: flex; align-items: center; justify-content: center; box-shadow: 0 1px 2px rgba(0,0,0,0.05); flex-shrink: 0;">${icon('bag', wide ? 28 : 22, '#fff', 1.8)}</div>
        <div>
          <div style="font-size: ${wide ? 30 : 24}px; font-weight: 700; color: ${T.text}; line-height: 1.15; letter-spacing: -0.01em;">Orders</div>
          <div style="font-size: 14px; color: ${T.muted}; margin-top: 4px;">${sub}</div>
        </div>
      </div>
      ${right}
    </div>`;

const scanButton = (wide) => wide
  ? `<button style="display: inline-flex; align-items: center; gap: 8px; padding: 10px 16px; font-size: 14px; font-weight: 600; border-radius: 12px; border: 1px solid ${T.border}; background: ${T.surface}; color: ${T.text}; cursor: pointer;">${icon('qr', 18, T.text, 1.8)}Scan a parcel</button>`
  : `<button aria-label="Scan a parcel" style="width: 44px; height: 44px; border-radius: 12px; border: 1px solid ${T.border}; background: ${T.surface}; display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0;">${icon('qr', 22, T.text, 1.8)}</button>`;

// ── Sample orders (sample data, Ghanaian names, real trader photos) ─────
const ORDERS = [
  { name: 'Ama Mensah', photo: 'eggs.jpg', items: '2 crates of eggs', count: 2, amount: '90', status: 'waiting', pay: 'mtn', when: '20 min ago', num: 'ORD-2241' },
  { name: 'Kofi Boateng', photo: 'sewing.jpg', items: 'Kaba and slit', count: 1, amount: '250', status: 'waiting', pay: 'telecel', when: '1 hr ago', num: 'ORD-2240' },
  { name: 'Abena Owusu', photo: 'makeup.jpg', items: 'Lip gloss set', count: 1, amount: '60', status: 'waiting', pay: 'cod', when: '2 hr ago', num: 'ORD-2239' },
  { name: 'Yaw Darko', photo: 'melon.jpg', items: 'Watermelon, 3', count: 3, amount: '45', status: 'onway', pay: 'mtn', when: 'Today', num: 'ORD-2236' },
  { name: 'Efua Asante', photo: 'braids.jpg', items: 'Hair braiding', count: 1, amount: '80', status: 'onway', pay: 'at', when: 'Today', num: 'ORD-2234' },
  { name: 'Kwabena Osei', photo: 'citrus.jpg', items: 'Oranges, bowl', count: 1, amount: '30', status: 'done', pay: 'mtn', when: 'Yesterday', num: 'ORD-2231' },
  { name: 'Adwoa Frimpong', photo: 'eggs.jpg', items: '1 crate of eggs', count: 1, amount: '45', status: 'done', pay: 'mtn', when: 'Yesterday', num: 'ORD-2229' },
  { name: 'Nana Yeboah', photo: 'makeup.jpg', items: 'Lip gloss set, 2', count: 2, amount: '120', status: 'packing', pay: 'telecel', when: 'Today', num: 'ORD-2238' },
];

// Where the order is: one icon, one tint, one word, the same everywhere.
const STATUS = {
  waiting: { icon: 'clock', label: 'Waiting', color: T.amber, soft: T.amberSoft, text: T.amberText },
  packing: { icon: 'box', label: 'Packing', color: T.blue, soft: T.blueSoft, text: T.blueText },
  onway: { icon: 'truck', label: 'On the way', color: T.violet, soft: T.violetSoft, text: T.violetText },
  done: { icon: 'checkCircle', label: 'Done', color: T.primary, soft: T.soft, text: T.primaryHover },
};

// How it was paid: the rail's own colour (MTN yellow, Telecel red, AT blue),
// cash on delivery in slate. The colour is the word for a merchant who
// knows the wallet by its logo.
const PAY = {
  mtn: { label: 'MoMo paid', bg: T.mtn, fg: '#1F1300' },
  telecel: { label: 'Telecel paid', bg: T.telecel, fg: '#fff' },
  at: { label: 'AT paid', bg: T.at, fg: '#fff' },
  cod: { label: 'Cash on delivery', bg: T.line, fg: T.ink2 },
};

const img = (src, size, radius = 12) => `<img src="${src}" alt="" style="width: ${size}px; height: ${size}px; border-radius: ${radius}px; object-fit: cover; display: block; flex-shrink: 0; background: ${T.line};" />`;
const payChip = (pay, small = false) => `<span style="display: inline-flex; align-items: center; height: ${small ? 20 : 24}px; padding: 0 ${small ? 7 : 9}px; border-radius: 999px; background: ${PAY[pay].bg}; color: ${PAY[pay].fg}; font-size: ${small ? 10.5 : 11.5}px; font-weight: 800; white-space: nowrap;">${PAY[pay].label}</span>`;
const statusPill = (status, { iconOnly = false, size = 'md' } = {}) => {
  const s = STATUS[status];
  const h = size === 'sm' ? 26 : 30;
  return `<span title="${s.label}" style="display: inline-flex; align-items: center; gap: 6px; height: ${h}px; padding: 0 ${iconOnly ? 0 : 10}px 0 ${iconOnly ? 0 : 8}px; ${iconOnly ? `width: ${h}px; justify-content: center;` : ''} border-radius: 999px; background: ${s.soft}; color: ${s.text}; font-size: 12px; font-weight: 800; white-space: nowrap;">${icon(s.icon, 15, s.color, 2.2)}${iconOnly ? '' : s.label}</span>`;
};
const waDisc = (size = 44) => `<button aria-label="WhatsApp the customer" style="width: ${size}px; height: ${size}px; border: 0; border-radius: 999px; background: ${T.whatsapp}; color: #fff; display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0; box-shadow: 0 4px 10px rgba(37,211,102,0.3);">${icon('chat', Math.round(size * 0.5), '#fff', 2)}</button>`;
const sendButton = ({ width = '100%', height = 48, label = 'Send it' } = {}) => `<button style="width: ${width}; height: ${height}px; border: 0; border-radius: 13px; background: ${T.primary}; color: #fff; padding: 0 18px; font-size: ${height >= 48 ? 15.5 : 13}px; font-weight: 800; display: inline-flex; align-items: center; justify-content: center; gap: 8px; cursor: pointer; box-shadow: 0 4px 12px rgba(5,150,105,0.28); white-space: nowrap;">${label}${icon('arrowRight', height >= 48 ? 18 : 14, '#fff', 2.4)}</button>`;
const money = (amount, size = 16) => `<span style="font-size: ${size}px; font-weight: 800; color: ${T.text}; font-variant-numeric: tabular-nums; letter-spacing: -0.01em; white-space: nowrap;">GH₵ ${amount}</span>`;
const eyebrow = (text, right = '') => `<div style="display: flex; align-items: center; justify-content: space-between; padding: 0 2px;"><div style="font-size: 12px; font-weight: 800; letter-spacing: 0.12em; text-transform: uppercase; color: ${T.faint};">${text}</div>${right}</div>`;

// Live stat_card: 16px radius, hairline, label, big numeral, tinted icon tile.
const statTile = ({ label, value, tone, ic, big = false }) => {
  const tones = { info: ['#EFF6FF', T.blue], warning: ['#FFFBEB', T.amber], success: [T.soft, T.primary] };
  const [wash, fg] = tones[tone];
  return `<div style="flex: 1; min-width: 0; background: linear-gradient(160deg, ${wash} 0%, ${T.surface} 60%); border: 1px solid ${T.border}; border-radius: 16px; padding: ${big ? '18px 18px 16px' : '14px 14px 12px'}; display: flex; flex-direction: column; justify-content: space-between; gap: 10px; min-height: ${big ? 118 : 96}px;">
      <div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 8px;"><div style="font-size: 13px; font-weight: 500; color: ${T.muted};">${label}</div><div style="width: ${big ? 44 : 36}px; height: ${big ? 44 : 36}px; border-radius: 12px; background: ${fg}; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">${icon(ic, big ? 22 : 18, '#fff', 1.9)}</div></div>
      <div style="font-size: ${big ? 30 : 26}px; font-weight: 800; color: ${T.text}; letter-spacing: -0.02em; line-height: 1;">${value}</div>
    </div>`;
};

// Live filter_tabs: segmented, dark active pill with its count.
const tabs = (items, { icons = false } = {}) => `
    <div style="display: flex; gap: 6px; overflow: hidden; padding: 4px; background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 12px; width: fit-content; max-width: 100%;">
      ${items.map((t) => `<div style="display: inline-flex; align-items: center; gap: 7px; height: 34px; padding: 0 ${icons ? 10 : 12}px; border-radius: 9px; font-size: 13px; font-weight: 700; white-space: nowrap; ${t.on ? `background: ${T.text}; color: #fff;` : `color: ${T.muted};`}">${icons && t.icon ? icon(t.icon, 16, t.on ? '#fff' : (t.color || T.faint), 2.2) : ''}${t.label}${t.count != null ? `<span style="font-size: 11px; font-weight: 800; padding: 1px 7px; border-radius: 999px; background: ${t.on ? 'rgba(255,255,255,0.18)' : T.line}; color: ${t.on ? '#fff' : T.muted};">${t.count}</span>` : ''}</div>`).join('')}
    </div>`;

const searchBox = (width = '100%') => `<div style="position: relative; width: ${width};"><div style="position: absolute; left: 12px; top: 50%; transform: translateY(-50%); display: flex;">${icon('search', 16, T.faint, 2)}</div><div style="height: 42px; padding: 0 16px 0 36px; background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 12px; font-size: 14px; color: ${T.faint}; display: flex; align-items: center;">Search orders...</div></div>`;

// ═════════════════════════════════════════════════════════════════════════
// A — DO THESE NOW. The page leads with the work: waiting orders as big
// cards with the photo, the customer, WhatsApp and one Send it. The rest is
// a quiet picture list under On the way and Done.
// ═════════════════════════════════════════════════════════════════════════
const workCard = (o, { wide = false } = {}) => `
    <div style="background: ${T.surface}; border: 1.5px solid ${T.amberRing}; border-radius: 18px; padding: 14px; display: flex; flex-direction: column; gap: 12px; box-shadow: 0 1px 2px rgba(15,23,42,0.05), 0 10px 24px -18px rgba(217,119,6,0.5);">
      <div style="display: flex; align-items: center; gap: 12px;">
        ${img(o.photo, wide ? 72 : 84, 14)}
        <div style="flex: 1; min-width: 0;">
          <div style="font-size: 16px; font-weight: 800; color: ${T.text}; letter-spacing: -0.01em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o.name}</div>
          <div style="font-size: 13.5px; color: ${T.muted}; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o.items}</div>
          <div style="display: flex; align-items: center; gap: 8px; margin-top: 7px;">${payChip(o.pay)}<span style="font-size: 12px; color: ${T.faint};">${o.when}</span></div>
        </div>
        <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 8px; flex-shrink: 0;">
          ${money(o.amount, 22)}
          ${waDisc(40)}
        </div>
      </div>
      ${sendButton()}
    </div>`;

const pictureRow = (o, { wide = false, action = '' } = {}) => `
    <div style="display: flex; align-items: center; gap: ${wide ? 16 : 12}px; padding: ${wide ? '12px 20px' : '12px 14px'}; border-bottom: 1px solid ${T.line};">
      ${img(o.photo, wide ? 48 : 52, 12)}
      <div style="flex: 1; min-width: 0;">
        <div style="font-size: ${wide ? 14.5 : 15}px; font-weight: 700; color: ${T.text}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o.name}</div>
        <div style="font-size: 12.5px; color: ${T.muted}; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o.items} · ${o.when}</div>
      </div>
      ${wide ? payChip(o.pay, true) : ''}
      ${money(o.amount, wide ? 15 : 16)}
      ${action || statusPill(o.status, { iconOnly: !wide, size: 'sm' })}
    </div>`;

const listCard = (rows) => `<div style="background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 16px; overflow: hidden;">${rows.join('')}</div>`;

const by = (status) => ORDERS.filter((o) => o.status === status);

const aPhone = phone(`
    ${pageHeader(false, '3 waiting for you', scanButton(false))}
    <div style="display: flex; gap: 12px;">
      ${statTile({ label: 'Waiting', value: '3', tone: 'warning', ic: 'clock' })}
      ${statTile({ label: 'Money today', value: 'GH₵ 340', tone: 'success', ic: 'banknotes' })}
    </div>
    ${eyebrow('Do these now')}
    ${workCard(by('waiting')[0])}
    ${workCard(by('waiting')[1])}
    ${workCard(by('waiting')[2])}
    ${eyebrow('On the way', `<span style="font-size: 12px; font-weight: 700; color: ${T.muted};">2</span>`)}
    ${listCard(by('onway').map((o) => pictureRow(o)))}
    ${eyebrow('Done', `<span style="font-size: 12px; font-weight: 700; color: ${T.muted};">Yesterday</span>`)}
    ${listCard(by('done').map((o) => pictureRow(o)))}`, 1560);

const aDesktop = desktop(`
    ${pageHeader(true, '3 waiting for you', `<div style="display: flex; gap: 12px;">${scanButton(true)}${searchBox('280px')}</div>`)}
    <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px;">
      ${statTile({ label: 'Waiting', value: '3', tone: 'warning', ic: 'clock', big: true })}
      ${statTile({ label: 'On the way', value: '2', tone: 'info', ic: 'truck', big: true })}
      ${statTile({ label: 'Money today', value: 'GH₵ 340', tone: 'success', ic: 'banknotes', big: true })}
      ${statTile({ label: 'Done this week', value: '14', tone: 'success', ic: 'checkCircle', big: true })}
    </div>
    ${eyebrow('Do these now')}
    <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px;">
      ${by('waiting').map((o) => workCard(o, { wide: true })).join('')}
    </div>
    <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; align-items: start;">
      <div style="display: flex; flex-direction: column; gap: 10px;">${eyebrow('On the way')}${listCard(by('onway').concat(by('packing')).map((o) => pictureRow(o, { wide: true })))}</div>
      <div style="display: flex; flex-direction: column; gap: 10px;">${eyebrow('Done')}${listCard(by('done').map((o) => pictureRow(o, { wide: true })))}</div>
    </div>`, 1000);

// ═════════════════════════════════════════════════════════════════════════
// B — PICTURE ROWS. The page keeps its shape; every row leads with what was
// bought, the rail chip says how it was paid, the icon says where it is,
// WhatsApp is on every row, and the money is the largest thing.
// ═════════════════════════════════════════════════════════════════════════
const bRow = (o, { wide = false } = {}) => {
  const waiting = o.status === 'waiting';
  return `
    <div style="display: flex; align-items: center; gap: ${wide ? 16 : 12}px; padding: ${wide ? '13px 20px' : '12px 14px'}; border-bottom: 1px solid ${T.line}; ${waiting ? `box-shadow: inset 4px 0 0 ${T.amberRing};` : ''}">
      ${img(o.photo, wide ? 52 : 56, 12)}
      <div style="flex: 1; min-width: 0;">
        <div style="display: flex; align-items: center; gap: 8px;"><span style="font-size: ${wide ? 14.5 : 15}px; font-weight: 700; color: ${T.text}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o.name}</span></div>
        <div style="font-size: 12.5px; color: ${T.muted}; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o.items}${wide ? ` · <span style="font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 11px; color: ${T.faint};">${o.num}</span>` : ''} · ${o.when}</div>
        <div style="display: flex; align-items: center; gap: 8px; margin-top: 6px;">${payChip(o.pay, true)}${!wide ? statusPill(o.status, { size: 'sm' }) : ''}</div>
      </div>
      ${wide ? statusPill(o.status, { size: 'sm' }) : ''}
      <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 6px; flex-shrink: 0;">
        ${money(o.amount, wide ? 16 : 17)}
        <div style="display: flex; align-items: center; gap: 6px;">${waDisc(32)}${waiting ? sendButton({ width: 'auto', height: 32 }) : ''}</div>
      </div>
    </div>`;
};

const statusTabs = (on, { icons = true } = {}) => tabs([
  { label: 'All', count: 30, on: on === 'all' },
  { label: 'Waiting', count: 3, icon: 'clock', color: T.amber, on: on === 'waiting' },
  { label: 'Packing', count: 1, icon: 'box', color: T.blue, on: on === 'packing' },
  { label: 'On the way', count: 2, icon: 'truck', color: T.violet, on: on === 'onway' },
  { label: 'Done', count: 24, icon: 'checkCircle', color: T.primary, on: on === 'done' },
], { icons });

const bPhone = phone(`
    ${pageHeader(false, 'Manage and track all customer orders', scanButton(false))}
    <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px;">
      ${statTile({ label: 'Orders today', value: '4', tone: 'info', ic: 'bag' })}
      ${statTile({ label: 'Waiting', value: '3', tone: 'warning', ic: 'clock' })}
    </div>
    <div style="display: flex; gap: 6px; overflow: hidden;">
      ${[{ label: 'All', count: 30, on: true }, { label: '', count: 3, icon: 'clock', color: T.amber }, { label: '', count: 1, icon: 'box', color: T.blue }, { label: '', count: 2, icon: 'truck', color: T.violet }, { label: '', count: 24, icon: 'checkCircle', color: T.primary }].map((t) => `<div style="display: inline-flex; align-items: center; gap: 6px; height: 40px; padding: 0 12px; border-radius: 12px; border: 1px solid ${t.on ? T.text : T.border}; background: ${t.on ? T.text : T.surface}; color: ${t.on ? '#fff' : T.text}; font-size: 13px; font-weight: 700; white-space: nowrap;">${t.icon ? icon(t.icon, 18, t.on ? '#fff' : t.color, 2.2) : ''}${t.label}<span style="font-size: 11.5px; font-weight: 800; color: ${t.on ? '#fff' : T.muted};">${t.count}</span></div>`).join('')}
    </div>
    ${searchBox()}
    ${listCard([ORDERS[0], ORDERS[1], ORDERS[7], ORDERS[3], ORDERS[5]].map((o) => bRow(o)))}`, 1200);

const bDesktop = desktop(`
    ${pageHeader(true, 'Manage and track all customer orders', scanButton(true))}
    <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px;">
      ${statTile({ label: 'Orders today', value: '4', tone: 'info', ic: 'bag', big: true })}
      ${statTile({ label: 'Waiting', value: '3', tone: 'warning', ic: 'clock', big: true })}
      ${statTile({ label: 'Revenue (7 days)', value: 'GH₵ 1,240', tone: 'success', ic: 'banknotes', big: true })}
      ${statTile({ label: 'Delivered (30 days)', value: '24', tone: 'success', ic: 'checkCircle', big: true })}
    </div>
    <div style="display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap;">
      ${statusTabs('all')}
      ${searchBox('320px')}
    </div>
    ${listCard([ORDERS[0], ORDERS[1], ORDERS[2], ORDERS[7], ORDERS[3], ORDERS[4], ORDERS[5]].map((o) => bRow(o, { wide: true })))}`, 1000);

// ═════════════════════════════════════════════════════════════════════════
// C — THE BOARD. Where every order is, at a glance: four columns on a
// desktop, one column at a time on a phone with a status strip to switch.
// A card moves right when the merchant taps its one button.
// ═════════════════════════════════════════════════════════════════════════
const boardCard = (o, { action = '' } = {}) => `
    <div style="background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 14px; padding: 12px; display: flex; flex-direction: column; gap: 10px; box-shadow: 0 1px 2px rgba(15,23,42,0.05);">
      <div style="display: flex; align-items: center; gap: 10px;">
        ${img(o.photo, 52, 12)}
        <div style="flex: 1; min-width: 0;">
          <div style="font-size: 14.5px; font-weight: 700; color: ${T.text}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o.name}</div>
          <div style="font-size: 12.5px; color: ${T.muted}; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o.items}</div>
        </div>
        ${money(o.amount, 16)}
      </div>
      <div style="display: flex; align-items: center; justify-content: space-between; gap: 8px;">
        ${payChip(o.pay, true)}
        <div style="display: flex; align-items: center; gap: 6px;">${waDisc(32)}${action}</div>
      </div>
    </div>`;

const columnHeader = (status, count) => {
  const s = STATUS[status];
  return `<div style="display: flex; align-items: center; gap: 8px; padding: 2px 4px 10px;"><div style="width: 30px; height: 30px; border-radius: 999px; background: ${s.soft}; display: flex; align-items: center; justify-content: center;">${icon(s.icon, 16, s.color, 2.2)}</div><div style="font-size: 14px; font-weight: 800; color: ${T.text};">${s.label}</div><div style="font-size: 12px; font-weight: 800; color: ${T.muted}; background: ${T.line}; padding: 2px 8px; border-radius: 999px;">${count}</div></div>`;
};

const nextAction = { waiting: sendButton({ width: 'auto', height: 32 }), packing: sendButton({ width: 'auto', height: 32, label: 'Shipped' }), onway: sendButton({ width: 'auto', height: 32, label: 'Delivered' }), done: '' };

const cDesktop = desktop(`
    ${pageHeader(true, 'Every order, where it is', `<div style="display: flex; gap: 12px;">${scanButton(true)}${searchBox('280px')}</div>`)}
    <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; align-items: start;">
      ${['waiting', 'packing', 'onway', 'done'].map((st) => `<div style="background: ${st === 'waiting' ? T.amberSoft : T.line}; border-radius: 18px; padding: 12px; display: flex; flex-direction: column; gap: 10px; min-height: 620px;">
        ${columnHeader(st, by(st).length)}
        ${by(st).map((o) => boardCard(o, { action: nextAction[st] })).join('')}
      </div>`).join('')}
    </div>`, 1000);

const cPhone = phone(`
    ${pageHeader(false, 'Every order, where it is', scanButton(false))}
    <div style="display: flex; gap: 8px; overflow: hidden;">
      ${['waiting', 'packing', 'onway', 'done'].map((st, i) => { const s = STATUS[st]; const on = i === 0; return `<div style="display: inline-flex; align-items: center; gap: 6px; height: 44px; padding: 0 12px; border-radius: 13px; border: 1.5px solid ${on ? s.color : T.border}; background: ${on ? s.soft : T.surface}; color: ${on ? s.text : T.text}; font-size: 13.5px; font-weight: 800; white-space: nowrap;">${icon(s.icon, 18, on ? s.color : T.faint, 2.2)}${on ? s.label : ''}<span style="font-size: 12px; font-weight: 800; color: ${on ? s.text : T.muted};">${by(st).length}</span></div>`; }).join('')}
    </div>
    ${by('waiting').map((o) => boardCard(o, { action: nextAction.waiting })).join('')}
    <div style="display: flex; justify-content: center; gap: 6px; padding-top: 4px;">${[0, 1, 2, 3].map((i) => `<div style="width: ${i === 0 ? 18 : 6}px; height: 6px; border-radius: 999px; background: ${i === 0 ? T.text : T.border};"></div>`).join('')}</div>`, 844);

// ── Write everything ─────────────────────────────────────────────────────
const files = {
  'Main.dc.html': aPhone,
  'WorkDesktop.dc.html': aDesktop,
  'RowsPhone.dc.html': bPhone,
  'RowsDesktop.dc.html': bDesktop,
  'BoardPhone.dc.html': cPhone,
  'BoardDesktop.dc.html': cDesktop,
};
for (const [name, html] of Object.entries(files)) writeFileSync(join(here, name), html);

const rowB = 1700, rowC = 3040;
const canvas = {
  artboards: [
    { file: 'Main.dc.html', x: 0, y: 0, w: 390, h: 1560, title: 'A · Do these now — phone' },
    { file: 'WorkDesktop.dc.html', x: 470, y: 0, w: 1440, h: 1000, title: 'A · Do these now — desktop' },
    { file: 'RowsPhone.dc.html', x: 0, y: rowB, w: 390, h: 1200, title: 'B · Picture rows — phone' },
    { file: 'RowsDesktop.dc.html', x: 470, y: rowB, w: 1440, h: 1000, title: 'B · Picture rows — desktop' },
    { file: 'BoardPhone.dc.html', x: 0, y: rowC, w: 390, h: 844, title: 'C · The board — phone' },
    { file: 'BoardDesktop.dc.html', x: 470, y: rowC, w: 1440, h: 1000, title: 'C · The board — desktop' },
  ],
  annotations: [
    { id: 'a-note', x: -500, y: 0, w: 440, text:
      'A — DO THESE NOW (leading)\n\nThe page opens on the work. Waiting orders are big cards: the photo of what was bought, the customer, how they paid in the wallet\'s own colour, WhatsApp one tap away, the money largest, and one Send it. Everything else is a quiet picture list under On the way and Done, so the merchant never hunts for the three orders that matter.\n\nTwo tiles on a phone, four on a desktop; the subtitle counts the waiting.\n\nFor: a merchant who does not read well sees photos and a green button, not a table.\n\nAgainst: thirty waiting orders make thirty big cards; the list of everything else is two taps further than today.' },
    { id: 'b-note', x: -500, y: rowB, w: 440, text:
      'B — PICTURE ROWS\n\nThe page keeps its shape and every row learns to speak: the product photo replaces the initials disc, the rail chip says how it was paid (MTN yellow, Telecel red, AT blue, cash in slate), the status is an icon with a word, WhatsApp is on every row, the money is the largest thing. Tabs carry the same icons, icon-only on a phone.\n\nFor: the smallest change; every row is still one order, scanning forty is the same motion as today.\n\nAgainst: still a list; a waiting order is louder than the rest only by its amber edge and button.' },
    { id: 'c-note', x: -500, y: rowC, w: 440, text:
      'C — THE BOARD\n\nWhere every order is, at a glance: Waiting, Packing, On the way, Done as columns on a desktop, one column at a time on a phone with a status strip to switch. Each card carries the one button that moves it right.\n\nFor: the shape of the day is visible without reading a number; a stall with a packer and a rider can split the columns.\n\nAgainst: a phone shows one column; search and the parcel scanner sit above a board that is mostly empty for a one-order shop. The biggest build of the three.' },
  ],
  launch: { view: 'canvas' },
};
writeFileSync(join(here, 'canvas.json'), JSON.stringify(canvas, null, 2) + '\n');
console.log(`wrote ${Object.keys(files).length} artboards + canvas.json`);
