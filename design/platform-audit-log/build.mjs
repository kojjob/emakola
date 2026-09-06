// Generates the three audit-log direction artboards from one shared shell.
// Shell values are lifted from lib/emakola_web/components/layouts/platform.html.heex
// and assets/css/app.css (.sidebar-link); page tokens from platform_components.ex,
// admin_components.ex (stat_card) and audit_log_components.ex.
import { writeFileSync } from 'node:fs';

// ── tokens ────────────────────────────────────────────────────────────
const C = {
  g900:'#111827', g700:'#374151', g600:'#4b5563', g500:'#6b7280', g400:'#9ca3af', g300:'#d1d5db', g200:'#e5e7eb', g100:'#f3f4f6', g50:'#f9fafb',
  s900:'#0f172a', s700:'#334155', s600:'#475569', s500:'#64748b', s400:'#94a3b8', s300:'#cbd5e1', s200:'#e2e8f0', s100:'#f1f5f9', s50:'#f8fafc',
  b50:'#eff6ff', b100:'#dbeafe', b500:'#3b82f6', b600:'#2563eb', b700:'#1d4ed8',
  sidebar:'#0C1F17',
};
const SEV = {
  red:     { dot:'#ef4444', bg:'#fef2f2', fg:'#b91c1c', ring:'rgba(220,38,38,0.2)',  soft:'#FEE2E2', tile:'#DC2626' },
  amber:   { dot:'#f59e0b', bg:'#fffbeb', fg:'#b45309', ring:'rgba(217,119,6,0.2)',  soft:'#FEF3C7', tile:'#D97706' },
  green:   { dot:'#10b981', bg:'#f0fdf4', fg:'#15803d', ring:'rgba(22,163,74,0.2)',  soft:'#ECFDF5', tile:'#10b981' },
  neutral: { dot:'#d1d5db', bg:'#f1f5f9', fg:'#475569', ring:'rgba(100,116,139,0.2)', soft:'#f1f5f9', tile:'#64748b' },
};
const TINT = {
  blue:   { bg:'#dbeafe', fg:'#2563eb' },
  amber:  { bg:'#fef3c7', fg:'#d97706' },
  violet: { bg:'#ede9fe', fg:'#7c3aed' },
  rose:   { bg:'#ffe4e6', fg:'#e11d48' },
  emerald:{ bg:'#d1fae5', fg:'#059669' },
  sky:    { bg:'#e0f2fe', fg:'#0284c7' },
};

// ── icons (heroicons outline, 24 grid) ────────────────────────────────
const P = {
  grid:'M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z',
  package:'M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z',
  shield:'M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z',
  megaphone:'M10.34 15.84c-.688-.06-1.386-.09-2.09-.09H7.5a4.5 4.5 0 110-9h.75c.704 0 1.402-.03 2.09-.09m0 9.18c.253.962.584 1.892.985 2.783.247.55.06 1.21-.463 1.511l-.657.38c-.551.318-1.26.117-1.527-.461a20.845 20.845 0 01-1.44-4.282m3.102.069a18.03 18.03 0 01-.59-4.59c0-1.586.205-3.124.59-4.59m0 9.18a23.848 23.848 0 018.835 2.535M10.34 6.66a23.847 23.847 0 008.835-2.535m0 0A23.74 23.74 0 0018.795 3m.38 1.125a23.91 23.91 0 011.014 5.395m-1.014 8.855c-.118.38-.245.754-.38 1.125m.38-1.125a23.91 23.91 0 001.014-5.395m0-3.46c.495.413.811 1.035.811 1.73 0 .695-.316 1.317-.811 1.73m0-3.46a24.347 24.347 0 010 3.46',
  chat:'M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z',
  users:'M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z',
  check:'M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  pencil:'M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10',
  currency:'M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z',
  chart:'M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z',
  payments:'M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z',
  search:'M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z',
  download:'M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3',
  chevD:'M19.5 8.25l-7.5 7.5-7.5-7.5',
  chevR:'M8.25 4.5l7.5 7.5-7.5 7.5',
  chevUD:'M8.25 15L12 18.75 15.75 15m-7.5-6L12 5.25 15.75 9',
  calendar:'M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5',
  store:'M13.5 21v-7.5a.75.75 0 01.75-.75h3a.75.75 0 01.75.75V21m-4.5 0H2.36m11.14 0H18m0 0h3.64m-1.39 0V9.349m-16.5 11.65V9.35m0 0a3.001 3.001 0 003.75-.615A2.993 2.993 0 009.75 9.75c.896 0 1.7-.393 2.25-1.016a2.993 2.993 0 002.25 1.016c.896 0 1.7-.393 2.25-1.016a3.001 3.001 0 003.75.614m-16.5 0a3.004 3.004 0 01-.621-4.72L4.318 3.44A1.5 1.5 0 015.378 3h13.243a1.5 1.5 0 011.06.44l1.19 1.189a3 3 0 01-.621 4.72m-13.5 8.65h3.75a.75.75 0 00.75-.75V13.5a.75.75 0 00-.75-.75H6.75a.75.75 0 00-.75.75v3.75c0 .415.336.75.75.75z',
  user:'M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z',
  cube:'M21 7.5l-9-5.25L3 7.5m18 0l-9 5.25m9-5.25v9l-9 5.25M3 7.5l9 5.25M3 7.5v9l9 5.25m0-9v9',
  external:'M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25',
  copy:'M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 011.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25m12 6.625v-1.875a3.375 3.375 0 00-3.375-3.375h-1.5a1.125 1.125 0 01-1.125-1.125v-1.5a3.375 3.375 0 00-3.375-3.375H9.75',
  funnel:'M12 3c2.755 0 5.455.232 8.083.678.533.09.917.556.917 1.096v1.044a2.25 2.25 0 01-.659 1.591l-5.432 5.432a2.25 2.25 0 00-.659 1.591v2.927a2.25 2.25 0 01-1.244 2.013L9.75 21v-6.568a2.25 2.25 0 00-.659-1.591L3.659 7.409A2.25 2.25 0 013 5.818V4.774c0-.54.384-1.006.917-1.096A48.32 48.32 0 0112 3z',
  bell:'M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0',
  finger:'M7.864 4.243A7.5 7.5 0 0119.5 10.5c0 2.92-.556 5.709-1.568 8.268M5.742 6.364A7.465 7.465 0 004.5 10.5a7.464 7.464 0 01-1.15 3.993m1.989 3.559A11.209 11.209 0 008.25 10.5a3.75 3.75 0 117.5 0c0 .527-.021 1.049-.064 1.565M12 10.5a14.94 14.94 0 01-3.6 9.75m6.633-4.596a18.666 18.666 0 01-2.485 5.33',
  warn:'M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z',
  clock:'M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z',
  list:'M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zM3.75 12h.007v.008H3.75V12zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm-.375 5.25h.007v.008H3.75v-.008zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z',
  cog:'M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z M15 12a3 3 0 11-6 0 3 3 0 016 0z',
  megaphone2:'M10.34 15.84c-.688-.06-1.386-.09-2.09-.09H7.5a4.5 4.5 0 110-9h.75c.704 0 1.402-.03 2.09-.09m0 9.18c.253.962.584 1.892.985 2.783.247.55.06 1.21-.463 1.511l-.657.38c-.551.318-1.26.117-1.527-.461a20.845 20.845 0 01-1.44-4.282m3.102.069a18.03 18.03 0 01-.59-4.59c0-1.586.205-3.124.59-4.59m0 9.18a23.848 23.848 0 018.835 2.535M10.34 6.66a23.847 23.847 0 008.835-2.535',
  x:'M6 18L18 6M6 6l12 12',
};
const ico = (name, size=20, color='currentColor', sw=1.8, extra='') =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink: 0; ${extra}"><path d="${P[name]}"></path></svg>`;

// ── shared shell ──────────────────────────────────────────────────────
const navLink = (label, icon, active=false, badge=null) => `
      <div style="position: relative; display: flex; align-items: center; gap: 12px; padding: 9px 12px; margin-bottom: 2px; border-radius: 10px; font-size: 13.5px; font-weight: 500; color: ${active ? '#ffffff' : 'rgba(255,255,255,0.5)'}; background: ${active ? 'rgba(59,130,246,0.12)' : 'transparent'};">
        ${active ? '<div style="position: absolute; left: -12px; top: 6px; bottom: 6px; width: 3px; border-radius: 0 3px 3px 0; background: #3B82F6;"></div>' : ''}
        ${ico(icon, 20)}
        <span>${label}</span>
        ${badge ? `<span style="margin-left: auto; font-size: 10px; font-weight: 700; padding: 1px 7px; border-radius: 999px; background: #D97706; color: #ffffff;">${badge}</span>` : ''}
      </div>`;
const sectionLabel = (t, first=false) =>
  `<div style="padding: 0 12px; margin: ${first ? '0' : '24px'} 0 6px; font-size: 10px; font-weight: 600; color: rgba(255,255,255,0.25); text-transform: uppercase; letter-spacing: 0.12em;">${t}</div>`;

const shellOpen = (title, subtitle, actionsHtml='') => `<!doctype html>
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
    body { margin: 0; font-family: 'Inter', system-ui, -apple-system, sans-serif; -webkit-font-smoothing: antialiased; }
    a { color: #2563eb; text-decoration: none; } a:hover { color: #1d4ed8; }
    ::-webkit-scrollbar { display: none; }
    .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
    .tnum { font-variant-numeric: tabular-nums; }
  </style>
</helmet>
<div style="display: flex; width: 1440px; height: 900px; background: #f8fafc; color: #1e293b; overflow: hidden;">

  <!-- Sidebar (platform.html.heex) -->
  <div style="display: flex; flex-direction: column; width: 260px; height: 900px; background: ${C.sidebar}; flex-shrink: 0; overflow: hidden;">
    <div style="display: flex; align-items: center; gap: 12px; height: 72px; padding: 0 20px; border-bottom: 1px solid rgba(255,255,255,0.06); flex-shrink: 0;">
      <div style="display: flex; align-items: center; justify-content: center; width: 36px; height: 36px; border-radius: 12px; background: linear-gradient(135deg, #60a5fa, #2563eb); box-shadow: 0 10px 15px -3px rgba(59,130,246,0.2); flex-shrink: 0;">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20l5-8 5 4 6-11"></path></svg>
      </div>
      <div style="min-width: 0; flex: 1;">
        <div style="font-size: 15px; font-weight: 700; color: #ffffff; letter-spacing: -0.01em; line-height: 1.2;">Makola</div>
        <div style="font-size: 10px; font-weight: 500; color: rgba(96,165,250,0.6); line-height: 1.2;">Platform Admin</div>
      </div>
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.4)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15.75 19.5L8.25 12l7.5-7.5"></path></svg>
    </div>
    <div style="flex: 1; padding: 12px; overflow: hidden; display: flex; flex-direction: column;">
      ${sectionLabel('Platform', true)}
      ${navLink('Dashboard','grid')}
      ${navLink('Stores','package')}
      ${navLink('Moderation','shield')}
      ${navLink('Announcements','megaphone')}
      ${navLink('Messages','chat')}
      ${navLink('Merchants','users')}
      ${navLink('Onboarding','check')}
      ${navLink('Verifications','shield')}
      ${navLink('Team','users')}
      ${navLink('Security','shield')}
      ${navLink('Audit log','pencil', true)}
      ${navLink('Security events','shield')}
      ${sectionLabel('Finance')}
      ${navLink('Billing','currency')}
      ${navLink('Finance','chart')}
      ${navLink('Payments','payments')}
    </div>
    <div style="padding: 12px; border-top: 1px solid rgba(255,255,255,0.06); flex-shrink: 0;">
      <div style="display: flex; align-items: center; gap: 12px; padding: 10px 12px; background: rgba(255,255,255,0.04); border-radius: 12px;">
        <div style="display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; border-radius: 999px; background: linear-gradient(135deg, #60a5fa, #2563eb); box-shadow: 0 0 0 2px rgba(59,130,246,0.2); color: #ffffff; font-size: 11px; font-weight: 700; flex-shrink: 0;">KO</div>
        <div style="min-width: 0; flex: 1;">
          <div style="font-size: 13px; font-weight: 600; color: #ffffff; line-height: 1.2;">Kojo</div>
          <div style="font-size: 10px; color: rgba(255,255,255,0.3); line-height: 1.3;">owner@makola.io</div>
        </div>
        ${ico('chevUD', 16, 'rgba(255,255,255,0.2)', 2)}
      </div>
    </div>
  </div>

  <!-- Main column -->
  <div style="flex: 1; display: flex; flex-direction: column; min-width: 0; height: 900px;">
    <!-- Topbar -->
    <div style="display: flex; align-items: center; gap: 16px; height: 72px; padding: 0 32px; background: rgba(255,255,255,0.8); border-bottom: 1px solid rgba(226,232,240,0.8); flex-shrink: 0;">
      <div style="position: relative; flex: 1; max-width: 512px;">
        ${ico('search', 16, '#94a3b8', 2, 'position: absolute; left: 14px; top: 13px;')}
        <div style="width: 100%; padding: 10px 16px 10px 40px; background: rgba(248,250,252,0.8); border: 1px solid #e2e8f0; border-radius: 12px; font-size: 14px; color: #94a3b8; box-sizing: border-box;">Search stores, merchants...</div>
        <div class="mono" style="position: absolute; right: 12px; top: 11px; font-size: 10px; color: #94a3b8; background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 6px; padding: 2px 6px;">⌘K</div>
      </div>
      <div style="flex: 1;"></div>
      <div style="display: flex; align-items: center; gap: 8px;">
        <div style="display: flex; align-items: center; gap: 6px; background: #eff6ff; color: #1d4ed8; font-size: 12px; font-weight: 600; padding: 6px 12px; border-radius: 12px; border: 1px solid #dbeafe;">
          <div style="width: 6px; height: 6px; border-radius: 999px; background: #3b82f6;"></div>
          <span>Platform Admin</span>
        </div>
        <div style="width: 1px; height: 32px; background: rgba(226,232,240,0.6);"></div>
        <div style="padding: 10px; border-radius: 12px;">${ico('bell', 20, '#64748b')}</div>
        <div style="display: flex; align-items: center; gap: 8px; padding: 6px 8px 6px 6px; border-radius: 12px;">
          <div style="display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; border-radius: 999px; background: linear-gradient(135deg, #60a5fa, #2563eb); box-shadow: 0 0 0 2px rgba(59,130,246,0.2); color: #ffffff; font-size: 12px; font-weight: 700;">KO</div>
          <span style="font-size: 14px; font-weight: 500; color: #334155;">Kojo</span>
          ${ico('chevD', 16, '#94a3b8', 2)}
        </div>
      </div>
    </div>

    <!-- Page -->
    <div style="flex: 1; min-height: 0; padding: 32px; overflow: hidden; display: flex; flex-direction: column;">
      <div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; margin-bottom: 24px; flex-shrink: 0;">
        <div>
          <h1 style="margin: 0; font-size: 24px; font-weight: 700; color: #111827; line-height: 32px;">${title}</h1>
          <p style="margin: 4px 0 0; font-size: 14px; color: #6b7280; line-height: 20px;">${subtitle}</p>
        </div>
        ${actionsHtml}
      </div>`;

const shellClose = `
    </div>
  </div>
</div>
</x-dc>
</body>
</html>
`;

// ── page primitives ───────────────────────────────────────────────────
const pill = (label, sev) => {
  const s = SEV[sev];
  return `<span style="display: inline-flex; align-items: center; padding: 4px 10px; border-radius: 999px; font-size: 11px; font-weight: 600; line-height: 14px; background: ${s.bg}; color: ${s.fg}; box-shadow: inset 0 0 0 1px ${s.ring}; white-space: nowrap;">${label}</span>`;
};
const dot = (sev, size=10) => `<span style="display: inline-block; width: ${size}px; height: ${size}px; border-radius: 999px; background: ${SEV[sev].dot}; box-shadow: 0 0 0 4px #ffffff; flex-shrink: 0;"></span>`;
const avatar = (p, size=24, fs=10) => p.system
  ? `<div style="display: flex; align-items: center; justify-content: center; width: ${size}px; height: ${size}px; border-radius: 999px; background: #f1f5f9; color: #64748b; flex-shrink: 0;">${ico('cog', Math.round(size*0.58), '#64748b', 1.8)}</div>`
  : `<div style="display: flex; align-items: center; justify-content: center; width: ${size}px; height: ${size}px; border-radius: 999px; background: ${TINT[p.tint].bg}; color: ${TINT[p.tint].fg}; font-size: ${fs}px; font-weight: 700; flex-shrink: 0;">${p.initials}</div>`;
const btn = (label, icon=null, primary=false) =>
  `<div style="display: inline-flex; align-items: center; gap: 8px; padding: 8px 16px; border-radius: 12px; font-size: 14px; font-weight: 500; line-height: 20px; ${primary ? 'background: #2563eb; color: #ffffff; border: 1px solid #2563eb;' : 'background: #ffffff; color: #374151; border: 1px solid #e5e7eb;'} box-shadow: 0 1px 2px rgba(0,0,0,0.05);">${icon ? ico(icon, 16, primary ? '#ffffff' : '#6b7280', 2) : ''}<span>${label}</span></div>`;
const card = (inner, extra='') => `<div style="background: #ffffff; border-radius: 16px; border: 1px solid #e5e7eb; box-shadow: 0 1px 2px rgba(0,0,0,0.05); ${extra}">${inner}</div>`;
const statTile = (label, value, icon, sev) => {
  const s = SEV[sev];
  return `<div style="display: flex; flex-direction: column; min-height: 192px; padding: 20px; border-radius: 16px; border: 1px solid #E2E8F0; box-shadow: 0 1px 2px rgba(0,0,0,0.05); background: linear-gradient(to bottom right, ${s.soft}, #ffffff); box-sizing: border-box;">
      <div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 12px;">
        <span style="font-size: 14px; font-weight: 500; color: #64748b;">${label}</span>
        <div style="display: flex; align-items: center; justify-content: center; width: 56px; height: 56px; border-radius: 12px; background: ${s.tile}; flex-shrink: 0;">${ico(icon, 28, '#ffffff', 1.6)}</div>
      </div>
      <p class="tnum" style="margin: auto 0 0; font-size: 30px; font-weight: 700; color: #0f172a; line-height: 36px;">${value}</p>
    </div>`;
};

// ── sample data ───────────────────────────────────────────────────────
const STAFF = {
  kojo:   { name:'Kojo',       initials:'KO', email:'owner@makola.io',    role:'Owner', tint:'blue' },
  ama:    { name:'Ama Owusu',  initials:'AO', email:'ama@makola.io',      role:'Staff', tint:'amber' },
  yaw:    { name:'Yaw Mensah', initials:'YM', email:'y.mensah@makola.io', role:'Staff', tint:'violet' },
  system: { name:'System',     initials:'',   email:'',                   role:'Scheduled job', system:true },
};
const label = (a) => (a.charAt(0).toUpperCase() + a.slice(1)).replace(/_/g, ' ');
const E = [
  { day:'today', t:'14:32:08', a:'store_suspended', sev:'amber', who:'ama', tk:'store', tn:'Osu Sneaker Loft', ts:'osu-sneaker-loft', meta:[['reason','Counterfeit listings reported twice'],['store_slug','osu-sneaker-loft'],['store_id','8f3a2c1e-…-c21e']], ip:'41.215.160.12', verb:'suspended' },
  { day:'today', t:'14:05:41', a:'product_taken_down', sev:'red', who:'ama', tk:'product', tn:'Air Max 97 (replica)', ts:'Osu Sneaker Loft', meta:[['reason','Counterfeit'],['product_title','Air Max 97 (replica)'],['store_id','8f3a2c1e-…-c21e']], ip:'41.215.160.12', verb:'took down' },
  { day:'today', t:'13:48:19', a:'sign_in_failed', sev:'red', who:'system', tk:'email', tn:'y.mensah@makola.io', ts:'', meta:[['email','y.mensah@makola.io'],['reason','bad_password']], ip:'154.160.22.71', verb:'Failed sign-in for' },
  { day:'today', t:'12:10:03', a:'permissions_changed', sev:'neutral', who:'kojo', tk:'user', tn:'Yaw Mensah', ts:'y.mensah@makola.io', meta:[['permissions','manage_stores, view_audit_log'],['email','y.mensah@makola.io']], ip:'41.66.201.9', verb:'changed permissions for' },
  { day:'today', t:'11:56:47', a:'store_featured', sev:'green', who:'kojo', tk:'store', tn:'Adwoa Threads', ts:'adwoa-threads', meta:[['reason','Launch week'],['store_slug','adwoa-threads']], ip:'41.66.201.9', verb:'featured' },
  { day:'today', t:'11:20:15', a:'sign_in_succeeded', sev:'green', who:'yaw', tk:null, tn:'', ts:'', meta:[], ip:'154.160.22.71', verb:'signed in' },
  { day:'today', t:'10:44:30', a:'verification_approved', sev:'green', who:'ama', tk:'store', tn:'Kumasi Spice Co', ts:'kumasi-spice-co', meta:[['store_slug','kumasi-spice-co']], ip:'41.215.160.12', verb:'approved verification for' },
  { day:'today', t:'09:31:48', a:'impersonation_ended', sev:'green', who:'kojo', tk:'merchant', tn:'Efua Boateng', ts:'[merchant email]', meta:[['merchant_name','Efua Boateng'],['merchant_email','[merchant email]']], ip:'41.66.201.9', verb:'stopped acting as' },
  { day:'today', t:'09:15:02', a:'impersonation_started', sev:'amber', who:'kojo', tk:'merchant', tn:'Efua Boateng', ts:'[merchant email]', meta:[['merchant_name','Efua Boateng'],['merchant_email','[merchant email]']], ip:'41.66.201.9', verb:'started acting as' },
  { day:'yesterday', t:'18:02:11', a:'sessions_force_revoked', sev:'red', who:'kojo', tk:'user', tn:'Yaw Mensah', ts:'3 sessions', meta:[['count','3'],['user_id','2b91d4f0-…-77aa']], ip:'41.66.201.9', verb:'revoked all sessions for' },
  { day:'yesterday', t:'17:40:55', a:'totp_failed', sev:'red', who:'yaw', tk:null, tn:'', ts:'', meta:[], ip:'41.66.201.9', verb:'failed a 2FA code' },
  { day:'yesterday', t:'16:12:37', a:'announcement_published', sev:'green', who:'kojo', tk:'announcement', tn:'MoMo payouts move to Fridays', ts:'', meta:[['title','MoMo payouts move to Fridays']], ip:'41.66.201.9', verb:'published' },
  { day:'yesterday', t:'15:05:20', a:'payout_approved', sev:'neutral', who:'kojo', tk:'store', tn:'Kumasi Spice Co', ts:'GH₵ 1,250', meta:[['amount','GH₵ 1,250'],['basis','standard'],['payout_id','c04e…91b2']], ip:'41.66.201.9', verb:'approved a payout to' },
  { day:'yesterday', t:'09:00:00', a:'directory_override_expired', sev:'neutral', who:'system', tk:'store', tn:'Adwoa Threads', ts:'adwoa-threads', meta:[['store_slug','adwoa-threads']], ip:null, verb:'Featured slot expired for' },
];
const DAYS = { today:'Today · Fri 5 Sep', yesterday:'Yesterday · Thu 4 Sep' };
const targetIcon = { store:'store', product:'cube', user:'user', merchant:'user', email:'finger', announcement:'megaphone2' };

// ═══════════════════════════════════════════════════════════════════════
// OPTION A — Ledger (Main.dc.html)
// ═══════════════════════════════════════════════════════════════════════
const chip = (label, count, active=false) =>
  `<div style="display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 999px; font-size: 13px; font-weight: 500; line-height: 16px; white-space: nowrap; ${active ? 'background: #0f172a; color: #ffffff;' : 'background: #ffffff; color: #374151; border: 1px solid #e5e7eb;'}"><span>${label}</span>${count ? `<span class="tnum" style="font-size: 11px; font-weight: 600; color: ${active ? 'rgba(255,255,255,0.6)' : '#9ca3af'};">${count}</span>` : ''}</div>`;
const select = (label, icon=null, w='auto') =>
  `<div style="display: inline-flex; align-items: center; gap: 8px; padding: 8px 12px; border-radius: 12px; background: #ffffff; border: 1px solid #e5e7eb; font-size: 13px; font-weight: 500; color: #374151; width: ${w}; box-sizing: border-box; white-space: nowrap;">${icon ? ico(icon, 16, '#6b7280', 2) : ''}<span style="flex: 1;">${label}</span>${ico('chevD', 14, '#9ca3af', 2)}</div>`;

const GRID_A = 'grid-template-columns: 76px 200px 150px 200px minmax(0, 1fr) 108px;';
const ledgerHead = `
        <div style="display: grid; ${GRID_A} gap: 16px; align-items: center; padding: 12px 24px; background: #f9fafb; border-bottom: 1px solid #f3f4f6; font-size: 12px; font-weight: 500; color: #6b7280; text-transform: uppercase; letter-spacing: 0.05em; border-radius: 16px 16px 0 0;">
          <span>Time</span><span>Event</span><span>Actor</span><span>Target</span><span>Details</span><span>IP</span>
        </div>`;
const dayBand = (t, n) => `
        <div style="display: flex; align-items: center; gap: 12px; padding: 8px 24px; background: #f8fafc; border-bottom: 1px solid #f3f4f6; border-top: 1px solid #f3f4f6;">
          <span style="font-size: 12px; font-weight: 600; color: #334155;">${t}</span>
          <span class="tnum" style="font-size: 11px; font-weight: 500; color: #94a3b8;">${n} events</span>
        </div>`;
const target = (e) => {
  if (!e.tk) return `<span style="font-size: 13px; color: #9ca3af;">—</span>`;
  return `<div style="display: flex; align-items: center; gap: 8px; min-width: 0;">
            <div style="display: flex; align-items: center; justify-content: center; width: 24px; height: 24px; border-radius: 6px; background: #f1f5f9; flex-shrink: 0;">${ico(targetIcon[e.tk], 14, '#64748b', 1.8)}</div>
            <div style="min-width: 0;">
              <div style="font-size: 13px; font-weight: 500; color: #111827; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${e.tn}</div>
              ${e.ts ? `<div class="mono" style="font-size: 11px; color: #9ca3af; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${e.ts}</div>` : ''}
            </div>
          </div>`;
};
const details = (e) => {
  const r = e.meta.find(([k]) => k === 'reason' || k === 'permissions' || k === 'amount' || k === 'count' || k === 'title');
  if (!r) return `<span style="font-size: 13px; color: #9ca3af;">—</span>`;
  const more = e.meta.length - 1;
  return `<div style="display: flex; align-items: center; gap: 8px; min-width: 0;">
            <span style="font-size: 13px; color: #4b5563; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;"><span style="color: #9ca3af;">${r[0]}:</span> ${r[1]}</span>
            ${more > 0 ? `<span class="tnum" style="flex-shrink: 0; padding: 1px 6px; border-radius: 6px; background: #f3f4f6; border: 1px solid #e5e7eb; font-size: 11px; color: #6b7280;">+${more}</span>` : ''}
          </div>`;
};
const ledgerRow = (e) => {
  const p = STAFF[e.who];
  return `
        <div style="display: grid; ${GRID_A} gap: 16px; align-items: center; padding: 11px 24px; border-bottom: 1px solid #f3f4f6; min-height: 52px; box-sizing: border-box;">
          <span class="mono tnum" style="font-size: 12px; color: #6b7280;">${e.t}</span>
          <div style="display: flex; align-items: center; gap: 10px; min-width: 0;">${dot(e.sev)}${pill(label(e.a), e.sev)}</div>
          <div style="display: flex; align-items: center; gap: 8px; min-width: 0;">${avatar(p)}<span style="font-size: 13px; font-weight: ${p.system ? '500' : '600'}; color: ${p.system ? '#6b7280' : '#111827'}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${p.name}</span></div>
          ${target(e)}
          ${details(e)}
          <span class="mono" style="font-size: 11px; color: #9ca3af;">${e.ip || '—'}</span>
        </div>`;
};
const optionA = () => {
  const today = E.filter(e => e.day === 'today');
  const yest = E.filter(e => e.day === 'yesterday');
  const actions = `<div style="display: flex; align-items: center; gap: 8px; flex-shrink: 0;">
          <div style="display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 999px; background: #ecfdf5; color: #047857; font-size: 12px; font-weight: 600;"><span style="width: 6px; height: 6px; border-radius: 999px; background: #10b981;"></span><span>Live</span></div>
          ${select('Any severity', 'funnel')}
          ${select('Last 7 days', 'calendar')}
          ${btn('Export CSV', 'download')}
        </div>`;
  return shellOpen('Audit log', 'Every action platform staff take. Append-only, kept forever.', actions) + `
      <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 16px; flex-shrink: 0;">
        <div style="position: relative; width: 280px;">
          ${ico('search', 16, '#9ca3af', 2, 'position: absolute; left: 12px; top: 11px;')}
          <div style="padding: 9px 12px 9px 36px; background: #ffffff; border: 1px solid #e5e7eb; border-radius: 12px; font-size: 13px; color: #9ca3af;">Actor, store, email or IP</div>
        </div>
        <div style="display: flex; align-items: center; gap: 6px; flex: 1;">
          ${chip('All', '1,284', true)}${chip('Sign-ins', '412')}${chip('Staff', '38')}${chip('Stores', '267')}${chip('Moderation', '91')}${chip('Directory', '154')}${chip('Finance', '322')}
        </div>
      </div>
      ${card(ledgerHead + dayBand(DAYS.today, 9) + today.map(ledgerRow).join('') + dayBand(DAYS.yesterday, 5) + yest.map(ledgerRow).join('') + `
        <div style="display: flex; align-items: center; justify-content: space-between; padding: 14px 24px;">
          <span class="tnum" style="font-size: 13px; color: #6b7280;">Showing 14 of 1,284</span>
          ${btn('Load 50 more')}
        </div>`, 'flex: 1; min-height: 0; overflow: hidden; display: flex; flex-direction: column;')}` + shellClose;
};

// ═══════════════════════════════════════════════════════════════════════
// OPTION B — Journal (OptionB.dc.html)
// ═══════════════════════════════════════════════════════════════════════
const sentence = (e) => {
  const p = STAFF[e.who];
  const who = p.system ? '' : `<strong style="font-weight: 600; color: #111827;">${p.name}</strong> `;
  const tgt = e.tk ? ` <strong style="font-weight: 600; color: #111827;">${e.tn}</strong>` : '';
  return `${who}<span style="color: #374151;">${e.verb}</span>${tgt}`;
};
const journalRow = (e, last=false) => {
  const p = STAFF[e.who];
  const reason = e.meta.find(([k]) => k === 'reason');
  return `
          <div style="display: flex; gap: 16px; padding-bottom: ${last ? '0' : '20px'};">
            <div style="display: flex; flex-direction: column; align-items: center; width: 32px; flex-shrink: 0;">
              <div style="position: relative;">${avatar(p, 32, 12)}<span style="position: absolute; right: -2px; bottom: -2px; width: 12px; height: 12px; border-radius: 999px; background: ${SEV[e.sev].dot}; box-shadow: 0 0 0 2px #ffffff;"></span></div>
              ${last ? '' : '<span style="width: 1px; flex: 1; margin-top: 6px; background: #f3f4f6;"></span>'}
            </div>
            <div style="flex: 1; min-width: 0; padding-top: 2px;">
              <div style="display: flex; align-items: baseline; justify-content: space-between; gap: 16px;">
                <p style="margin: 0; font-size: 14px; line-height: 20px; color: #374151;">${sentence(e)}</p>
                <span class="mono tnum" style="font-size: 12px; color: #9ca3af; flex-shrink: 0;">${e.t}</span>
              </div>
              <div style="display: flex; align-items: center; gap: 10px; margin-top: 6px; flex-wrap: wrap;">
                ${pill(label(e.a), e.sev)}
                ${reason ? `<span style="font-size: 13px; color: #6b7280; font-style: italic;">“${reason[1]}”</span>` : ''}
                ${e.ip ? `<span class="mono" style="font-size: 11px; color: #9ca3af;">${e.ip}</span>` : ''}
              </div>
            </div>
          </div>`;
};
const dayHead = (t, n) => `
          <div style="display: flex; align-items: center; gap: 12px; padding-bottom: 14px;">
            <span style="font-size: 13px; font-weight: 600; color: #111827;">${t}</span>
            <span class="tnum" style="font-size: 12px; color: #94a3b8;">${n} events</span>
            <span style="flex: 1; height: 1px; background: #f3f4f6;"></span>
          </div>`;
const barRow = (labelTxt, n, pct, sev='green') => `
          <div style="display: flex; align-items: center; gap: 12px;">
            <span style="width: 96px; flex-shrink: 0; font-size: 13px; color: #4b5563;">${labelTxt}</span>
            <div style="flex: 1; height: 10px; border-radius: 999px; background: #f3f4f6; overflow: hidden;"><div style="height: 10px; width: ${pct}%; border-radius: 999px; background: linear-gradient(to right, ${sev === 'red' ? '#f87171, #dc2626' : sev === 'amber' ? '#fbbf24, #d97706' : '#34d399, #10b981'});"></div></div>
            <span class="tnum" style="width: 32px; text-align: right; font-size: 14px; font-weight: 600; color: #374151;">${n}</span>
          </div>`;
const staffRow = (p, n, pct) => `
          <div style="display: flex; align-items: center; gap: 12px;">
            ${avatar(p, 28, 11)}
            <div style="flex: 1; min-width: 0;">
              <div style="display: flex; align-items: baseline; justify-content: space-between; gap: 8px;">
                <span style="font-size: 13px; font-weight: 600; color: #111827;">${p.name}</span>
                <span class="tnum" style="font-size: 13px; font-weight: 600; color: #374151;">${n}</span>
              </div>
              <div style="margin-top: 6px; height: 6px; border-radius: 999px; background: #f3f4f6; overflow: hidden;"><div style="height: 6px; width: ${pct}%; border-radius: 999px; background: linear-gradient(to right, #60a5fa, #2563eb);"></div></div>
            </div>
          </div>`;
const optionB = () => {
  const today = E.filter(e => e.day === 'today').slice(0, 7);
  const actions = `<div style="display: flex; align-items: center; gap: 8px; flex-shrink: 0;">${select('Last 24 hours', 'calendar')}${btn('Export CSV', 'download')}</div>`;
  return shellOpen('Audit log', 'Who did what, in plain words. Last 24 hours at a glance.', actions) + `
      <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; margin-bottom: 24px; flex-shrink: 0;">
        ${statTile('Events (24h)', '38', 'list', 'neutral')}
        ${statTile('Needs a look', '4', 'warn', 'red')}
        ${statTile('Store actions', '14', 'store', 'amber')}
        ${statTile('Sign-ins', '11', 'finger', 'green')}
      </div>
      <div style="display: grid; grid-template-columns: minmax(0, 1fr) 300px; gap: 24px; flex: 1; min-height: 0;">
        ${card(`<div style="padding: 24px; overflow: hidden; height: 100%; box-sizing: border-box;">${dayHead(DAYS.today, 9)}${today.map((e, i) => journalRow(e, i === today.length - 1)).join('')}</div>`, 'min-height: 0; overflow: hidden;')}
        <div style="display: flex; flex-direction: column; gap: 24px; min-height: 0;">
          ${card(`<div style="padding: 24px;">
            <h2 style="margin: 0 0 16px; font-size: 14px; font-weight: 600; color: #374151;">Most active today</h2>
            <div style="display: flex; flex-direction: column; gap: 14px;">
              ${staffRow(STAFF.kojo, 17, 100)}${staffRow(STAFF.ama, 12, 70)}${staffRow(STAFF.yaw, 6, 35)}
            </div>
          </div>`)}
          ${card(`<div style="padding: 24px;">
            <h2 style="margin: 0 0 16px; font-size: 14px; font-weight: 600; color: #374151;">By area</h2>
            <div style="display: flex; flex-direction: column; gap: 12px;">
              ${barRow('Stores', 14, 100)}${barRow('Sign-ins', 11, 78)}${barRow('Staff', 6, 43)}${barRow('Moderation', 4, 28, 'red')}${barRow('Finance', 3, 21)}
            </div>
          </div>`)}
        </div>
      </div>` + shellClose;
};

// ═══════════════════════════════════════════════════════════════════════
// OPTION C — Inspector (OptionC.dc.html)
// ═══════════════════════════════════════════════════════════════════════
const listRow = (e, selected=false) => {
  const p = STAFF[e.who];
  return `
          <div style="position: relative; display: flex; align-items: center; gap: 12px; padding: 12px 16px 12px 20px; border-bottom: 1px solid #f3f4f6; background: ${selected ? '#eff6ff' : '#ffffff'};">
            ${selected ? '<div style="position: absolute; left: 0; top: 8px; bottom: 8px; width: 3px; border-radius: 0 3px 3px 0; background: #3b82f6;"></div>' : ''}
            ${dot(e.sev, 8)}
            <div style="flex: 1; min-width: 0;">
              <div style="display: flex; align-items: center; justify-content: space-between; gap: 8px;">
                <span style="font-size: 13px; font-weight: 600; color: #111827; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${label(e.a)}</span>
                <span class="mono tnum" style="font-size: 11px; color: #9ca3af; flex-shrink: 0;">${e.t}</span>
              </div>
              <div style="display: flex; align-items: center; gap: 6px; margin-top: 3px; min-width: 0;">
                ${avatar(p, 16, 7)}
                <span style="font-size: 12px; color: #6b7280; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${p.name}${e.tk ? ` · ${e.tn}` : ''}</span>
              </div>
            </div>
          </div>`;
};
const kv = (k, v, mono=false) => `
            <div style="display: grid; grid-template-columns: 140px minmax(0, 1fr); gap: 16px; padding: 10px 0; border-bottom: 1px solid #f3f4f6;">
              <span class="mono" style="font-size: 12px; color: #6b7280; padding-top: 1px;">${k}</span>
              <span class="${mono ? 'mono' : ''}" style="font-size: 13px; color: #111827; word-break: break-all;">${v}</span>
            </div>`;
const miniCard = (title, inner) => `<div style="flex: 1; min-width: 0; padding: 14px 16px; border-radius: 12px; border: 1px solid #e5e7eb; background: #f9fafb;"><div style="font-size: 11px; font-weight: 600; color: #9ca3af; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 10px;">${title}</div>${inner}</div>`;
const relatedRow = (e) => `
            <div style="display: flex; align-items: center; gap: 10px; padding: 8px 0; border-bottom: 1px solid #f3f4f6;">
              ${dot(e.sev, 8)}${pill(label(e.a), e.sev)}
              <span style="font-size: 13px; color: #374151; flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${STAFF[e.who].name}</span>
              <span class="mono tnum" style="font-size: 11px; color: #9ca3af;">${e.day === 'today' ? 'Today' : 'Thu'} ${e.t.slice(0,5)}</span>
            </div>`;
const optionC = () => {
  const sel = E[0];
  const listItems = [...E.filter(e => e.day === 'today'), ...E.filter(e => e.day === 'yesterday')].slice(0, 12);
  const actions = `<div style="display: flex; align-items: center; gap: 8px; flex-shrink: 0;">${btn('Export CSV', 'download')}</div>`;
  const segs = ['All','Sign-ins','Staff','Stores','Moderation','Finance'];
  return shellOpen('Audit log', 'Pick an event to see the full record: who, what, on which store, and why.', actions) + `
      ${card(`<div style="display: grid; grid-template-columns: 420px minmax(0, 1fr); height: 100%;">
        <!-- list -->
        <div style="display: flex; flex-direction: column; border-right: 1px solid #f3f4f6; min-height: 0;">
          <div style="padding: 16px 16px 12px; border-bottom: 1px solid #f3f4f6; display: flex; flex-direction: column; gap: 10px;">
            <div style="position: relative;">
              ${ico('search', 16, '#9ca3af', 2, 'position: absolute; left: 12px; top: 10px;')}
              <div style="padding: 8px 12px 8px 36px; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 10px; font-size: 13px; color: #9ca3af;">Search events</div>
            </div>
            <div style="display: flex; gap: 2px; padding: 3px; background: #f3f4f6; border-radius: 10px;">
              ${segs.map((s, i) => `<span style="flex: 1; text-align: center; padding: 5px 0; border-radius: 8px; font-size: 12px; font-weight: 500; color: ${i === 0 ? '#111827' : '#6b7280'}; background: ${i === 0 ? '#ffffff' : 'transparent'}; box-shadow: ${i === 0 ? '0 1px 2px rgba(0,0,0,0.06)' : 'none'};">${s}</span>`).join('')}
            </div>
          </div>
          <div style="flex: 1; min-height: 0; overflow: hidden;">
            <div style="padding: 8px 20px; font-size: 11px; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; background: #fafafa; border-bottom: 1px solid #f3f4f6;">${DAYS.today}</div>
            ${listItems.filter(e => e.day === 'today').map((e, i) => listRow(e, i === 0)).join('')}
            <div style="padding: 8px 20px; font-size: 11px; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; background: #fafafa; border-bottom: 1px solid #f3f4f6;">${DAYS.yesterday}</div>
            ${listItems.filter(e => e.day === 'yesterday').map(e => listRow(e)).join('')}
          </div>
        </div>
        <!-- detail -->
        <div style="display: flex; flex-direction: column; min-height: 0; overflow: hidden; padding: 24px 28px;">
          <div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; padding-bottom: 20px; border-bottom: 1px solid #f3f4f6;">
            <div>
              <div style="display: flex; align-items: center; gap: 10px;">${dot(sel.sev)}<h2 style="margin: 0; font-size: 18px; font-weight: 700; color: #111827; line-height: 24px;">${label(sel.a)}</h2>${pill('Amber', 'amber')}</div>
              <p class="mono" style="margin: 8px 0 0; font-size: 12px; color: #6b7280;">Fri 5 Sep 2026 · 14:32:08 UTC · from ${sel.ip}</p>
            </div>
            <div style="display: flex; align-items: center; gap: 8px;">${btn('Copy link', 'copy')}${btn('Open store', 'external')}</div>
          </div>
          <div style="display: flex; gap: 16px; padding: 20px 0;">
            ${miniCard('Actor', `<div style="display: flex; align-items: center; gap: 10px;">${avatar(STAFF.ama, 36, 13)}<div style="min-width: 0;"><div style="font-size: 14px; font-weight: 600; color: #111827;">Ama Owusu</div><div style="font-size: 12px; color: #6b7280;">ama@makola.io · Staff</div></div></div>`)}
            ${miniCard('Target', `<div style="display: flex; align-items: center; gap: 10px;"><div style="display: flex; align-items: center; justify-content: center; width: 36px; height: 36px; border-radius: 10px; background: #ffe4e6; color: #e11d48; font-size: 14px; font-weight: 700;">O</div><div style="min-width: 0;"><div style="font-size: 14px; font-weight: 600; color: #111827;">Osu Sneaker Loft</div><div class="mono" style="font-size: 12px; color: #6b7280;">osu-sneaker-loft · suspended</div></div></div>`)}
          </div>
          <div style="padding-bottom: 8px;">
            <div style="font-size: 11px; font-weight: 600; color: #9ca3af; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 4px;">Details</div>
            ${kv('reason', 'Counterfeit listings reported twice')}
            ${kv('store_slug', 'osu-sneaker-loft', true)}
            ${kv('store_id', '8f3a2c1e-4b7d-4e01-9a6f-1d2e3f40c21e', true)}
            ${kv('session', 'ps_7f21…a9c0 · Chrome on macOS', true)}
          </div>
          <div style="padding-top: 16px;">
            <div style="display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 4px;">
              <div style="font-size: 11px; font-weight: 600; color: #9ca3af; text-transform: uppercase; letter-spacing: 0.05em;">Same store, last 7 days</div>
              <span style="font-size: 12px; color: #2563eb; font-weight: 500;">Filter to this store</span>
            </div>
            ${relatedRow(E[1])}${relatedRow({ ...E[6], tn:'Osu Sneaker Loft', a:'verification_approved', sev:'green', who:'ama', day:'yesterday', t:'10:02:44' })}${relatedRow({ ...E[3], a:'store_verified_badge_granted', sev:'green', who:'kojo', day:'yesterday', t:'10:05:10' })}
          </div>
          <div style="margin-top: auto; display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; border-radius: 12px; border: 1px solid #e5e7eb; background: #f9fafb;">
            <span class="mono" style="font-size: 12px; color: #6b7280;">Raw record (JSON)</span>${ico('chevD', 16, '#9ca3af', 2)}
          </div>
        </div>
      </div>`, 'flex: 1; min-height: 0; overflow: hidden;')}` + shellClose;
};

// ── write ─────────────────────────────────────────────────────────────
const dir = new URL('.', import.meta.url).pathname;
writeFileSync(dir + 'Main.dc.html', optionA());
writeFileSync(dir + 'OptionB.dc.html', optionB());
writeFileSync(dir + 'OptionC.dc.html', optionC());
console.log('wrote Main.dc.html, OptionB.dc.html, OptionC.dc.html');
