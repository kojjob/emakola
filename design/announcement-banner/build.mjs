// Generates the artboards for the "Announcement Banner" canvas.
// Run: node build.mjs   (writes *.dc.html + canvas.json beside this file)
//
// The platform announcement banner as merchants see it on their Dashboard
// (app.html.heex renders it above the top bar today: a flat tinted strip
// with a text "Dismiss" link). Three directions, each at phone width and in
// the desktop content area, plus the composer with a live preview.
// Tokens from assets/css/app.css @theme and the admin shell; control sizes
// from design/add-products-one-door (54px fields, 56px CTA, 13px radius).

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

const T = {
  bg: '#F8FAFC', surface: '#FFFFFF', border: '#E2E8F0', line: '#F1F5F9',
  text: '#0F172A', muted: '#64748B', faint: '#94A3B8', ink2: '#334155',
  primary: '#059669', primaryHover: '#047857', soft: '#ECFDF5', softBorder: '#A7F3D0', mint: '#6EE7B7',
  amber: '#D97706', amberText: '#92400E', amberSoft: '#FFFBEB', amberBorder: '#FCD34D',
  red: '#DC2626', redText: '#991B1B', redSoft: '#FEF2F2', redBorder: '#FCA5A5',
  blue: '#2563EB', blueSoft: '#EFF6FF', blueText: '#1E40AF', blueBorder: '#BFDBFE',
};

const P = {
  menu: '<path d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/>',
  search: '<path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"/>',
  bell: '<path d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0"/>',
  megaphone: '<path d="M10.34 15.84c-.688-.06-1.386-.09-2.09-.09H7.5a4.5 4.5 0 110-9h.75c.704 0 1.402-.03 2.09-.09m0 9.18c.253.962.584 1.892.985 2.783.247.55.06 1.21-.463 1.511l-.657.38c-.551.318-1.26.117-1.527-.461a20.845 20.845 0 01-1.44-4.282m3.102.069a18.03 18.03 0 01-.59-4.59c0-1.586.205-3.124.59-4.59m0 9.18a23.848 23.848 0 018.835 2.535M10.34 6.66a23.847 23.847 0 008.835-2.535m0 0A23.74 23.74 0 0018.795 3m.38 1.125a23.91 23.91 0 011.014 5.395m-1.014 8.855c-.118.38-.245.754-.38 1.125m.38-1.125a23.91 23.91 0 001.014-5.395m0-3.46c.495.413.811 1.035.811 1.73 0 .695-.316 1.317-.811 1.73m0-3.46a24.347 24.347 0 010 3.46"/>',
  warning: '<path d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"/>',
  alert: '<path d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0M3.124 7.5A8.969 8.969 0 015.292 3m13.416 0a8.969 8.969 0 012.168 4.5"/>',
  check: '<path d="M4.5 12.75l6 6 9-13.5"/>',
  x: '<path d="M6 18L18 6M6 6l12 12"/>',
  arrowRight: '<path d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"/>',
  refresh: '<path d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99"/>',
  send: '<path d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5"/>',
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

// ── Shells ──────────────────────────────────────────────────────────────
const topbar = () => `
  <div style="height: 72px; flex-shrink: 0; display: flex; align-items: center; gap: 12px; padding: 0 16px; background: rgba(255,255,255,0.8); border-bottom: 1px solid rgba(226,232,240,0.8);">
    <button aria-label="Open sidebar" style="width: 36px; height: 36px; margin-left: -8px; border: 0; background: none; border-radius: 12px; display: flex; align-items: center; justify-content: center;">${icon('menu', 20, T.muted, 2)}</button>
    <div style="flex: 1; position: relative;">
      <div style="position: absolute; left: 14px; top: 50%; transform: translateY(-50%); display: flex;">${icon('search', 16, T.faint, 2)}</div>
      <input type="search" placeholder="Search anything..." aria-label="Search" style="width: 100%; padding: 10px 16px 10px 40px; background: rgba(248,250,252,0.8); border: 1px solid ${T.border}; border-radius: 12px; font-size: 14px; color: ${T.ink2}; font-family: inherit; outline: none;" />
    </div>
    <button aria-label="Notifications" style="width: 36px; height: 36px; border: 0; background: none; border-radius: 12px; display: flex; align-items: center; justify-content: center;">${icon('bell', 20, T.muted, 1.8)}</button>
    <div style="width: 36px; height: 36px; border-radius: 999px; background: ${T.soft}; color: ${T.primaryHover}; font-size: 13px; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">P</div>
  </div>`;

// The live dashboard header (dashboard_components.ex dashboard_header).
const dashHeader = (wide = false) => `
    <div style="display: flex; ${wide ? 'flex-direction: row; align-items: flex-end; justify-content: space-between;' : 'flex-direction: column;'} gap: 16px; padding-top: 8px;">
      <div>
        <div style="font-size: ${wide ? 30 : 24}px; font-weight: 700; color: ${T.text}; letter-spacing: -0.01em;">Good morning, Philomena</div>
        <div style="font-size: 14px; color: ${T.muted}; margin-top: 4px;">Your store at a glance</div>
      </div>
      <div style="display: flex; align-items: center; gap: 8px;">
        <div style="display: flex; align-items: center; background: ${T.surface}; border-radius: 12px; box-shadow: 0 1px 2px rgba(0,0,0,0.06); padding: 4px;">
          ${['Today', 'This week', 'This month', 'All time'].map((p, i) => `<div style="padding: 6px 12px; font-size: 14px; font-weight: 500; border-radius: 8px; ${i === 0 ? `background: ${T.primary}; color: #fff;` : `color: ${T.muted};`} white-space: nowrap;">${p}</div>`).join('')}
        </div>
        <div style="width: 36px; height: 36px; display: flex; align-items: center; justify-content: center;">${icon('refresh', 20, T.faint, 1.8)}</div>
      </div>
    </div>`;

// Grey stand-ins for the dashboard's tiles: context, not content.
const tiles = (cols) => `
    <div style="display: grid; grid-template-columns: repeat(${cols}, minmax(0, 1fr)); gap: 16px;">
      ${Array.from({ length: cols }, () => `<div style="height: 118px; background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 16px; padding: 18px; display: flex; flex-direction: column; justify-content: space-between;"><div style="width: 40%; height: 10px; border-radius: 5px; background: ${T.line};"></div><div style="width: 55%; height: 22px; border-radius: 6px; background: ${T.line};"></div></div>`).join('')}
    </div>`;

const phone = (content, { height = 844 } = {}) => doc(`
<div style="width: 390px; height: ${height}px; background: ${T.bg}; color: ${T.text}; display: flex; flex-direction: column; overflow: hidden;">
${content}
</div>`);

const desktop = (content, { height = 620 } = {}) => doc(`
<div style="position: relative; width: 1440px; height: ${height}px; background: ${T.bg}; color: ${T.text}; overflow: hidden; display: flex; flex-direction: column;">
${content}
</div>`);

const desktopTopbar = () => `
  <div style="height: 72px; flex-shrink: 0; display: flex; align-items: center; gap: 16px; padding: 0 32px; background: rgba(255,255,255,0.8); border-bottom: 1px solid rgba(226,232,240,0.8);">
    <div style="width: 440px; position: relative;">
      <div style="position: absolute; left: 14px; top: 50%; transform: translateY(-50%); display: flex;">${icon('search', 16, T.faint, 2)}</div>
      <div style="padding: 10px 16px 10px 40px; background: rgba(248,250,252,0.8); border: 1px solid ${T.border}; border-radius: 12px; font-size: 14px; color: ${T.faint};">Search anything...</div>
    </div>
    <div style="flex: 1;"></div>
    <div style="display: inline-flex; align-items: center; gap: 8px; padding: 8px 16px; border-radius: 12px; background: ${T.primary}; color: #fff; font-size: 14px; font-weight: 600;">+ New</div>
    ${icon('bell', 20, T.muted, 1.8)}
    <div style="display: flex; align-items: center; gap: 8px;"><div style="width: 36px; height: 36px; border-radius: 999px; background: ${T.soft}; color: ${T.primaryHover}; font-size: 13px; font-weight: 800; display: flex; align-items: center; justify-content: center;">PA</div><span style="font-size: 14px; font-weight: 600; color: ${T.text};">Philomena</span></div>
  </div>`;

// ── Severity vocabulary ─────────────────────────────────────────────────
// Info is emerald (the brand), not the blue the strip uses today: to a
// merchant, blue reads as "somebody else's system".
const SEV = {
  info: { icon: 'megaphone', disc: `linear-gradient(135deg, ${T.primary}, ${T.primaryHover})`, discShadow: 'rgba(5,150,105,0.32)', border: T.softBorder, soft: T.soft, text: T.primaryHover, bar: T.primary, cta: T.primary },
  warning: { icon: 'warning', disc: `linear-gradient(135deg, #F59E0B, ${T.amber})`, discShadow: 'rgba(217,119,6,0.32)', border: T.amberBorder, soft: T.amberSoft, text: T.amberText, bar: T.amber, cta: T.amber },
  critical: { icon: 'alert', disc: `linear-gradient(135deg, #EF4444, ${T.red})`, discShadow: 'rgba(220,38,38,0.32)', border: T.redBorder, soft: T.redSoft, text: T.redText, bar: T.red, cta: T.red },
};

const disc = (sev, size = 48) => `<div style="width: ${size}px; height: ${size}px; border-radius: 999px; background: ${SEV[sev].disc}; box-shadow: 0 6px 14px ${SEV[sev].discShadow}; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">${icon(SEV[sev].icon, Math.round(size * 0.5), '#fff', 1.9)}</div>`;

const cta = (label, sev = 'info', { width = '100%', height = 48, ic = 'check' } = {}) =>
  `<button style="width: ${width}; height: ${height}px; border: 0; border-radius: 13px; background: ${SEV[sev].cta}; color: #fff; padding: 0 20px; font-size: 15.5px; font-weight: 800; display: inline-flex; align-items: center; justify-content: center; gap: 8px; cursor: pointer; box-shadow: 0 4px 12px ${SEV[sev].discShadow}; white-space: nowrap;">${ic ? icon(ic, 20, '#fff', 2.4) : ''}<span>${label}</span></button>`;

const quiet = (label, { width = '100%', height = 48, ic = '' } = {}) =>
  `<button style="width: ${width}; height: ${height}px; border: 2px solid ${T.border}; border-radius: 13px; background: ${T.surface}; color: ${T.text}; padding: 0 18px; font-size: 15px; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; gap: 8px; cursor: pointer; white-space: nowrap;">${ic ? icon(ic, 18, T.muted, 2.2) : ''}<span>${label}</span></button>`;

const xButton = (size = 36, color = T.muted) => `<button aria-label="Dismiss" style="width: ${size}px; height: ${size}px; border: 0; border-radius: 999px; background: rgba(15,23,42,0.06); display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0;">${icon('x', Math.round(size * 0.5), color, 2.4)}</button>`;

// ═════════════════════════════════════════════════════════════════════════
// A — CARD. Sits in the content, first thing under the greeting: a white
// card with a tinted hairline, a gradient icon disc, and one big button.
// ═════════════════════════════════════════════════════════════════════════
const cardBanner = ({ sev = 'info', title, body, action = '', wide = false }) => `
    <div style="background: ${T.surface}; border: 1.5px solid ${SEV[sev].border}; border-radius: 18px; box-shadow: 0 1px 2px rgba(15,23,42,0.05), 0 10px 24px -18px ${SEV[sev].discShadow}; padding: ${wide ? '18px 22px' : '18px 16px 16px'}; display: flex; ${wide ? 'flex-direction: row; align-items: center; gap: 18px;' : 'flex-direction: column; gap: 14px;'} position: relative; overflow: hidden;">
      <div style="position: absolute; left: 0; top: 0; bottom: 0; width: 5px; background: ${SEV[sev].bar};"></div>
      <div style="display: flex; align-items: ${wide ? 'center' : 'flex-start'}; gap: 14px; flex: 1; min-width: 0; padding-left: 6px;">
        ${disc(sev, wide ? 52 : 48)}
        <div style="min-width: 0;">
          <div style="font-size: ${wide ? 17 : 16.5}px; font-weight: 800; color: ${T.text}; letter-spacing: -0.01em; line-height: 1.25;">${title}</div>
          <div style="font-size: ${wide ? 14.5 : 14.5}px; color: ${T.muted}; margin-top: 4px; line-height: 1.45;">${body}</div>
        </div>
      </div>
      <div style="display: flex; gap: 10px; ${wide ? 'flex-shrink: 0;' : 'padding-left: 6px;'}">
        ${action ? cta(action, sev, { width: wide ? 'auto' : '100%', ic: 'arrowRight' }) : ''}
        ${action ? quiet('Got it', { width: wide ? 'auto' : '100%', ic: 'check' }) : cta('Got it', sev, { width: wide ? '150px' : '100%' })}
      </div>
    </div>`;

const aPhone = phone(`
  ${topbar()}
  <div style="padding: 16px; display: flex; flex-direction: column; gap: 16px;">
    ${dashHeader()}
    ${cardBanner({ sev: 'info', title: 'Akwaaba! Welcome to Makola', body: 'Add your first product to open your shop.' })}
    ${tiles(2)}
    ${tiles(2)}
  </div>`);

const aPhoneCritical = phone(`
  ${topbar()}
  <div style="padding: 16px; display: flex; flex-direction: column; gap: 16px;">
    ${dashHeader()}
    ${cardBanner({ sev: 'critical', title: 'Check your payout number', body: 'One payout bounced. Fix it in Payouts.', action: 'Open Payouts' })}
    ${cardBanner({ sev: 'warning', title: 'Payouts pause on Friday', body: 'MTN MoMo maintenance, 10pm to 2am.' })}
    ${tiles(2)}
  </div>`);

const aDesktop = desktop(`
  ${desktopTopbar()}
  <div style="padding: 24px 32px; display: flex; flex-direction: column; gap: 20px; max-width: 1600px;">
    ${dashHeader(true)}
    ${cardBanner({ sev: 'info', title: 'Akwaaba! Welcome to Makola', body: 'Add your first product to open your shop.', wide: true })}
    ${cardBanner({ sev: 'critical', title: 'Check your payout number', body: 'One payout bounced. Fix it in Payouts.', action: 'Open Payouts', wide: true })}
    ${tiles(4)}
  </div>`, { height: 640 });

// ═════════════════════════════════════════════════════════════════════════
// B — RIBBON. Keeps today's place above the top bar, made handsome: a
// tinted band with a left accent, an icon disc, and a round X.
// ═════════════════════════════════════════════════════════════════════════
const ribbon = ({ sev = 'info', title, body, action = '', wide = false }) => `
    <div style="display: flex; align-items: center; gap: 14px; padding: ${wide ? '12px 32px' : '12px 16px'}; background: ${SEV[sev].soft}; border-bottom: 1px solid ${SEV[sev].border}; position: relative;">
      <div style="position: absolute; left: 0; top: 0; bottom: 0; width: 4px; background: ${SEV[sev].bar};"></div>
      ${disc(sev, 40)}
      <div style="flex: 1; min-width: 0; ${wide ? 'display: flex; align-items: baseline; gap: 10px;' : ''}">
        <div style="font-size: 15px; font-weight: 800; color: ${SEV[sev].text}; line-height: 1.3;">${title}</div>
        <div style="font-size: 14px; color: ${SEV[sev].text}; opacity: 0.85; ${wide ? '' : 'margin-top: 2px;'} line-height: 1.4;">${body}</div>
      </div>
      ${action ? `<button style="height: 38px; padding: 0 14px; border: 0; border-radius: 10px; background: ${SEV[sev].cta}; color: #fff; font-size: 13.5px; font-weight: 800; display: inline-flex; align-items: center; gap: 6px; white-space: nowrap; flex-shrink: 0;">${action}${icon('arrowRight', 16, '#fff', 2.4)}</button>` : ''}
      ${xButton(36, SEV[sev].text)}
    </div>`;

const bPhone = phone(`
  ${ribbon({ sev: 'info', title: 'Akwaaba! Welcome to Makola', body: 'Add your first product to open your shop.' })}
  ${topbar()}
  <div style="padding: 16px; display: flex; flex-direction: column; gap: 16px;">
    ${dashHeader()}
    ${tiles(2)}
    ${tiles(2)}
  </div>`);

const bPhoneCritical = phone(`
  ${ribbon({ sev: 'critical', title: 'Check your payout number', body: 'One payout bounced. Fix it in Payouts.', action: 'Open' })}
  ${topbar()}
  <div style="padding: 16px; display: flex; flex-direction: column; gap: 16px;">
    ${dashHeader()}
    ${tiles(2)}
    ${tiles(2)}
  </div>`);

const bDesktop = desktop(`
  ${ribbon({ sev: 'info', title: 'Akwaaba! Welcome to Makola', body: 'Add your first product to open your shop.', wide: true })}
  ${desktopTopbar()}
  <div style="padding: 24px 32px; display: flex; flex-direction: column; gap: 20px; max-width: 1600px;">
    ${dashHeader(true)}
    ${tiles(4)}
    ${tiles(4)}
  </div>`, { height: 640 });

// ═════════════════════════════════════════════════════════════════════════
// C — SHEET. The first time only: a bottom sheet on the phone, a centred
// card on the desktop, one pictogram, one line, one button. Critical
// announcements would always open this way; info ones fall back to A.
// ═════════════════════════════════════════════════════════════════════════
const sheet = ({ sev = 'info', title, body, action = '' }) => `
    <div style="position: absolute; inset: 0; background: rgba(15,23,42,0.45); backdrop-filter: blur(2px);"></div>
    <div style="position: absolute; left: 0; right: 0; bottom: 0; background: ${T.surface}; border-radius: 24px 24px 0 0; padding: 12px 20px 24px; display: flex; flex-direction: column; align-items: center; gap: 16px; box-shadow: 0 -12px 40px rgba(15,23,42,0.18);">
      <div style="width: 40px; height: 5px; border-radius: 999px; background: ${T.border};"></div>
      <div style="width: 84px; height: 84px; border-radius: 999px; background: ${SEV[sev].soft}; border: 3px solid ${SEV[sev].border}; display: flex; align-items: center; justify-content: center; margin-top: 6px;">${disc(sev, 60)}</div>
      <div style="text-align: center;">
        <div style="font-size: 22px; font-weight: 800; color: ${T.text}; letter-spacing: -0.02em; line-height: 1.2;">${title}</div>
        <div style="font-size: 16px; color: ${T.muted}; margin-top: 8px; line-height: 1.45;">${body}</div>
      </div>
      <div style="width: 100%; display: flex; flex-direction: column; gap: 10px; margin-top: 4px;">
        ${action ? cta(action, sev, { height: 56, ic: 'arrowRight' }) : ''}
        ${action ? quiet('Got it', { height: 54, ic: 'check' }) : cta('Got it', sev, { height: 56 })}
      </div>
    </div>`;

const cPhone = doc(`
<div style="position: relative; width: 390px; height: 844px; background: ${T.bg}; color: ${T.text}; overflow: hidden;">
  ${topbar()}
  <div style="padding: 16px; display: flex; flex-direction: column; gap: 16px;">
    ${dashHeader()}
    ${tiles(2)}
    ${tiles(2)}
    ${tiles(2)}
  </div>
  ${sheet({ sev: 'critical', title: 'Check your payout number', body: 'One payout bounced. Fix it in Payouts.', action: 'Open Payouts' })}
</div>`);

const cDesktop = doc(`
<div style="position: relative; width: 1440px; height: 640px; background: ${T.bg}; color: ${T.text}; overflow: hidden; display: flex; flex-direction: column;">
  ${desktopTopbar()}
  <div style="padding: 24px 32px; display: flex; flex-direction: column; gap: 20px; max-width: 1600px;">
    ${dashHeader(true)}
    ${tiles(4)}
    ${tiles(4)}
  </div>
  <div style="position: absolute; inset: 0; background: rgba(15,23,42,0.45); backdrop-filter: blur(2px);"></div>
  <div style="position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); width: 480px; background: ${T.surface}; border-radius: 24px; padding: 28px 28px 24px; display: flex; flex-direction: column; align-items: center; gap: 16px; box-shadow: 0 24px 60px rgba(15,23,42,0.28);">
    <div style="width: 84px; height: 84px; border-radius: 999px; background: ${SEV.critical.soft}; border: 3px solid ${SEV.critical.border}; display: flex; align-items: center; justify-content: center;">${disc('critical', 60)}</div>
    <div style="text-align: center;">
      <div style="font-size: 22px; font-weight: 800; color: ${T.text}; letter-spacing: -0.02em;">Check your payout number</div>
      <div style="font-size: 16px; color: ${T.muted}; margin-top: 8px;">One payout bounced. Fix it in Payouts.</div>
    </div>
    <div style="width: 100%; display: flex; gap: 10px; margin-top: 4px;">
      ${quiet('Got it', { height: 52, ic: 'check' })}
      ${cta('Open Payouts', 'critical', { height: 52, ic: 'arrowRight' })}
    </div>
  </div>
</div>`);

// ═════════════════════════════════════════════════════════════════════════
// COMPOSER — the platform page with a live preview of the card, so staff
// see what a merchant will see before they press Send.
// ═════════════════════════════════════════════════════════════════════════
const field = (label, value, { rows = 0, placeholder = '' } = {}) => `
      <div>
        <div style="font-size: 13px; font-weight: 500; color: #374151;">${label}</div>
        ${rows
          ? `<div style="margin-top: 4px; min-height: ${rows * 22 + 16}px; border: 1px solid ${T.border}; background: ${T.bg}; border-radius: 10px; padding: 8px 12px; font-size: 13px; color: ${value ? T.text : T.faint}; line-height: 1.5;">${value || placeholder}</div>`
          : `<div style="margin-top: 4px; height: 36px; border: 1px solid ${T.border}; background: ${T.bg}; border-radius: 10px; padding: 0 12px; font-size: 13px; color: ${value ? T.text : T.faint}; display: flex; align-items: center;">${value || placeholder}</div>`}
      </div>`;
const chip = (label, on = false) => `<div style="display: inline-flex; align-items: center; gap: 6px; padding: 6px 10px; border-radius: 9px; font-size: 12px; font-weight: 500; color: ${on ? T.primaryHover : '#475569'}; background: ${on ? T.soft : T.bg}; box-shadow: inset 0 0 0 1px ${on ? T.softBorder : T.border};"><div style="width: 14px; height: 14px; border-radius: 4px; border: 1px solid ${on ? T.primary : '#CBD5E1'}; background: ${on ? T.primary : '#fff'}; display: flex; align-items: center; justify-content: center;">${on ? icon('check', 10, '#fff', 3.5) : ''}</div>${label}</div>`;
const sevChip = (label, sev, on) => `<div style="display: inline-flex; align-items: center; gap: 7px; padding: 7px 12px; border-radius: 10px; font-size: 12.5px; font-weight: 700; color: ${on ? SEV[sev].text : '#475569'}; background: ${on ? SEV[sev].soft : T.bg}; box-shadow: inset 0 0 0 1.5px ${on ? SEV[sev].border : T.border};">${icon(SEV[sev].icon, 15, on ? SEV[sev].bar : T.faint, 2)}${label}</div>`;

const composer = doc(`
<div style="width: 1280px; height: 760px; background: ${T.bg}; color: ${T.text}; padding: 24px 32px; overflow: hidden;">
  <div style="display: flex; align-items: flex-end; justify-content: space-between; margin-bottom: 24px;">
    <div>
      <div style="font-size: 24px; font-weight: 700; color: #111827; letter-spacing: -0.01em;">Announcements</div>
      <div style="font-size: 14px; color: #6B7280; margin-top: 4px;">Broadcast to merchants via banner, email, SMS, WhatsApp</div>
    </div>
    <div style="display: flex; gap: 8px;">
      <div style="padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; color: ${T.amberText}; background: ${T.amberSoft}; box-shadow: inset 0 0 0 1px ${T.amberBorder};">0 scheduled</div>
      <div style="padding: 4px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; color: ${T.primaryHover}; background: ${T.soft}; box-shadow: inset 0 0 0 1px ${T.softBorder};">1 live</div>
    </div>
  </div>
  <div style="display: flex; gap: 20px; align-items: flex-start;">
    <div style="width: 430px; flex-shrink: 0; background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 16px; box-shadow: 0 1px 2px rgba(0,0,0,0.04); padding: 20px; display: flex; flex-direction: column; gap: 14px;">
      <div style="font-size: 11px; font-weight: 600; color: #6B7280; text-transform: uppercase; letter-spacing: 0.06em;">New announcement</div>
      ${field('Title', 'Payouts pause on Friday')}
      ${field('Message', 'MTN MoMo maintenance, 10pm to 2am.', { rows: 3 })}
      <div style="font-size: 11px; font-weight: 600; color: #6B7280; text-transform: uppercase; letter-spacing: 0.06em; margin-top: 4px;">Channels</div>
      <div style="display: flex; gap: 6px; flex-wrap: wrap;">${chip('Banner', true)}${chip('Email')}${chip('Sms')}${chip('Whatsapp')}</div>
      <div style="font-size: 11px; font-weight: 600; color: #6B7280; text-transform: uppercase; letter-spacing: 0.06em; margin-top: 4px;">Severity</div>
      <div style="display: flex; gap: 8px;">${sevChip('Info', 'info', false)}${sevChip('Warning', 'warning', true)}${sevChip('Critical', 'critical', false)}</div>
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
        ${field('Publish at (UTC)', '', { placeholder: 'dd/mm/yyyy, --:--' })}
        ${field('Expires at (UTC)', '', { placeholder: 'dd/mm/yyyy, --:--' })}
      </div>
      <div style="display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-top: 4px;">
        <div style="font-size: 11px; color: #9CA3AF; line-height: 1.4;">Leave publish time blank to send now. Banner shows until it expires.</div>
        <div style="display: inline-flex; align-items: center; gap: 6px; padding: 10px 16px; border-radius: 10px; background: #0F172A; color: #fff; font-size: 13px; font-weight: 600; flex-shrink: 0;">${icon('send', 14, '#fff', 2)}Send</div>
      </div>
    </div>
    <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 20px;">
      <div>
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px;">
          <div style="font-size: 11px; font-weight: 600; color: #6B7280; text-transform: uppercase; letter-spacing: 0.06em;">What merchants see</div>
          <div style="display: flex; gap: 6px;">${['Phone', 'Desktop'].map((l, i) => `<div style="padding: 4px 10px; border-radius: 8px; font-size: 12px; font-weight: 600; ${i === 0 ? `background: #0F172A; color: #fff;` : `background: ${T.surface}; color: ${T.muted}; box-shadow: inset 0 0 0 1px ${T.border};`}">${l}</div>`).join('')}</div>
        </div>
        <div style="background: ${T.bg}; border: 1px solid ${T.border}; border-radius: 16px; padding: 20px; display: flex; justify-content: center;">
          <div style="width: 358px;">${cardBanner({ sev: 'warning', title: 'Payouts pause on Friday', body: 'MTN MoMo maintenance, 10pm to 2am.' })}</div>
        </div>
        <div style="font-size: 12px; color: ${T.faint}; margin-top: 8px;">Updates as you type. Title under eight words reads best.</div>
      </div>
      <div>
        <div style="font-size: 11px; font-weight: 600; color: #6B7280; text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 10px;">Recent broadcasts</div>
        <div style="background: ${T.surface}; border: 1px solid ${T.border}; border-radius: 14px; padding: 16px 20px; display: flex; align-items: center; gap: 14px;">
          ${disc('info', 36)}
          <div style="flex: 1; min-width: 0;">
            <div style="display: flex; align-items: center; gap: 8px;"><div style="font-size: 13.5px; font-weight: 700; color: #111827;">Akwaaba! Welcome to Makola</div><div style="padding: 2px 8px; border-radius: 999px; font-size: 11px; font-weight: 600; color: ${T.primaryHover}; background: ${T.soft};">Live</div></div>
            <div style="font-size: 13px; color: #6B7280; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">Add your first product to open your shop.</div>
          </div>
          <div style="font-size: 12px; color: ${T.faint}; white-space: nowrap;">Banner · Email · All stores</div>
        </div>
      </div>
    </div>
  </div>
</div>`);

// ── Write everything ─────────────────────────────────────────────────────
const files = {
  'Main.dc.html': aPhone,
  'CardSeverities.dc.html': aPhoneCritical,
  'CardDesktop.dc.html': aDesktop,
  'RibbonPhone.dc.html': bPhone,
  'RibbonSeverities.dc.html': bPhoneCritical,
  'RibbonDesktop.dc.html': bDesktop,
  'SheetPhone.dc.html': cPhone,
  'SheetDesktop.dc.html': cDesktop,
  'Composer.dc.html': composer,
};
for (const [name, html] of Object.entries(files)) writeFileSync(join(here, name), html);

const rowB = 1000, rowC = 2000, rowD = 3000;
const canvas = {
  artboards: [
    { file: 'Main.dc.html', x: 0, y: 0, w: 390, h: 844, title: 'A · Card — welcome' },
    { file: 'CardSeverities.dc.html', x: 470, y: 0, w: 390, h: 844, title: 'A · Card — critical and warning' },
    { file: 'CardDesktop.dc.html', x: 940, y: 0, w: 1440, h: 640, title: 'A · Card — desktop' },

    { file: 'RibbonPhone.dc.html', x: 0, y: rowB, w: 390, h: 844, title: 'B · Ribbon — welcome' },
    { file: 'RibbonSeverities.dc.html', x: 470, y: rowB, w: 390, h: 844, title: 'B · Ribbon — critical' },
    { file: 'RibbonDesktop.dc.html', x: 940, y: rowB, w: 1440, h: 640, title: 'B · Ribbon — desktop' },

    { file: 'SheetPhone.dc.html', x: 0, y: rowC, w: 390, h: 844, title: 'C · Sheet — critical, first open' },
    { file: 'SheetDesktop.dc.html', x: 940, y: rowC, w: 1440, h: 640, title: 'C · Sheet — desktop' },

    { file: 'Composer.dc.html', x: 0, y: rowD, w: 1280, h: 760, title: 'Composer — with a live preview' },
  ],
  annotations: [
    { id: 'a-note', x: -500, y: 0, w: 440, text:
      'A — CARD (leading)\n\nMoves the banner out of the chrome and into the page, first thing under the greeting, where a merchant is already looking. A white card with a tinted hairline, a gradient icon disc that says what kind of news this is, one big Got it. A critical one adds one action button and a quiet Got it.\n\nInfo is emerald, not blue: blue reads as somebody else\'s system.\n\nFor: reads as part of the dashboard, not a warning strip; the button is a real tap target; stacks cleanly when two are live.\n\nAgainst: only on the Dashboard, like today; a merchant who lands elsewhere first still misses it until they come home.' },
    { id: 'b-note', x: -500, y: rowB, w: 440, text:
      'B — RIBBON\n\nKeeps today\'s place, above the top bar, and makes it handsome: tinted band, left accent, icon disc, round X. Smallest change.\n\nFor: always the first pixel on screen; costs no page space.\n\nAgainst: still chrome, still a strip; the X is the only control, so a critical notice cannot carry an action without crowding the band.' },
    { id: 'c-note', x: -500, y: rowC, w: 440, text:
      'C — SHEET, for critical only\n\nThe first open after a critical announcement raises a sheet (phone) or a centred card (desktop): one pictogram, one line, one button. Nothing else on the page until it is answered. Info and warning fall back to A.\n\nFor: the one time a merchant must not miss something, they cannot.\n\nAgainst: interruptive; earns its place only for critical. Two components to build, not one.' },
    { id: 'd-note', x: -500, y: rowD, w: 440, text:
      'COMPOSER\n\nThe platform page gains a live preview of the card as staff type, phone or desktop, and severity becomes three chips with the same icons merchants will see. Recent broadcasts pick up the disc too.\n\nBuilds on whichever banner is chosen; the preview is the same component.' },
  ],
  launch: { view: 'canvas' },
};
writeFileSync(join(here, 'canvas.json'), JSON.stringify(canvas, null, 2) + '\n');
console.log(`wrote ${Object.keys(files).length} artboards + canvas.json`);
