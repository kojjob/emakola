// Makola "how it works" scroll film — config + theme.
// Renders via scrub-engine.js (self-contained vanilla JS, no app.js coupling).
(function () {
  var root = document.documentElement;
  root.style.setProperty('--sw-bg', '#7b7051');
  root.style.setProperty('--sw-ink', '#FAF3E3');
  root.style.setProperty('--sw-ink-soft', '#d9cfb4');
  root.style.setProperty('--sw-accent', '#F5B301');

  var world = document.getElementById('tour-world');
  world.innerHTML = ''; // drop the no-JS fallback; the film takes over

  var CFG = {
    brand: { name: 'Makola', href: '/' },
    cta: { label: 'Start your shop', href: '/auth/register' },
    hint: 'scroll to see how it works',
    diveScroll: 1.3,
    connScroll: 0.9,
    sections: [
      {
        id: 'maker', label: 'The Maker',
        still: '/tour/workshop.webp',
        clip: '/tour/vid/workshop.mp4',
        clipMobile: '/tour/vid/workshop-m.mp4',
        stillMobile: '/tour/workshop-m.webp',
        accent: '#C2410C',
        scroll: 1.5,
        eyebrow: 'How Makola works',
        title: 'It starts with a maker.',
        body: 'She lists her goods on Makola one time. That is all she does.',
        tags: ['List once'],
      },
      {
        id: 'shop', label: 'Your Shop',
        still: '/tour/shop.webp',
        clip: '/tour/vid/shop.mp4',
        clipMobile: '/tour/vid/shop-m.mp4',
        stillMobile: '/tour/shop-m.webp',
        accent: '#059669',
        eyebrow: 'Your shop',
        title: 'You stock it in one tap.',
        body: 'No buying stock first. You see your profit before you add it.',
        tags: ['No stock to buy', 'See your profit'],
      },
      {
        id: 'pay', label: 'The Buyer',
        still: '/tour/checkout.webp',
        clip: '/tour/vid/checkout.mp4',
        clipMobile: '/tour/vid/checkout-m.mp4',
        stillMobile: '/tour/checkout-m.webp',
        accent: '#CA8A04',
        eyebrow: 'The buyer',
        title: 'They pay like always.',
        body: 'One MoMo payment. One receipt. Money people already use.',
        tags: ['MTN MoMo', 'Telecel Cash'],
      },
      {
        id: 'ship', label: 'Delivery',
        still: '/tour/delivery.webp',
        clip: '/tour/vid/delivery.mp4',
        clipMobile: '/tour/vid/delivery-m.mp4',
        stillMobile: '/tour/delivery-m.webp',
        accent: '#C2410C',
        eyebrow: 'Delivery',
        title: 'It goes straight to them.',
        body: "The maker gets the order on her phone and sends it to your customer's door.",
        tags: ['WhatsApp', 'SMS'],
      },
      {
        id: 'split', label: 'The Money',
        still: '/tour/split.webp',
        clip: '/tour/vid/split.mp4',
        clipMobile: '/tour/vid/split-m.mp4',
        stillMobile: '/tour/split-m.webp',
        accent: '#CA8A04',
        scroll: 1.6, linger: 0.4,
        eyebrow: 'The money',
        title: 'The money shares itself.',
        body: 'Everyone’s part reaches them by itself. No chasing. No promises.',
        tags: ['Every pesewa counted'],
      },
      {
        id: 'finale', label: 'One Market',
        still: '/tour/finale.webp',
        clip: '/tour/vid/finale.mp4',
        clipMobile: '/tour/vid/finale-m.mp4',
        stillMobile: '/tour/finale-m.webp',
        accent: '#059669',
        scroll: 1.8, linger: 0.5,
        eyebrow: 'One market',
        title: 'Every stall connected.',
        body: 'Open your shop today. It is free to start.',
        tags: [],
        cta: { primary: { label: 'Start your shop — free', href: '/auth/register' },
               secondary: { label: 'Browse stores', href: '/stores' } },
      },
    ],
    connectors: [
      '/tour/vid/conn1.mp4',
      '/tour/vid/conn2.mp4',
      '/tour/vid/conn3.mp4',
      '/tour/vid/conn4.mp4',
      '/tour/vid/conn5.mp4',
    ],
    connectorsMobile: [
      '/tour/vid/conn1-m.mp4',
      '/tour/vid/conn2-m.mp4',
      '/tour/vid/conn3-m.mp4',
      '/tour/vid/conn4-m.mp4',
      '/tour/vid/conn5-m.mp4',
    ],
  };

  // Portrait assets are composed for portrait viewports. A landscape phone
  // (coarse pointer, but wide) must get the 16:9 clips — object-fit: cover
  // would show only the middle quarter of a 9:16 frame (Codex review, PR #356).
  if (!window.matchMedia('(orientation: portrait)').matches) {
    CFG.sections.forEach(function (s) { delete s.clipMobile; delete s.stillMobile; });
    delete CFG.connectorsMobile;
  }

  mountScrollWorld(world, CFG);
  // Use the real Makola logo in the film's topbar (engine default is a plain mark).
  // Center the scene tabs exactly: the engine's space-between topbar lets the
  // tab group drift toward the wider CTA side. Grid pins it to true center.
  var st = document.createElement('style');
  st.textContent = '.sw-topbar{display:grid;grid-template-columns:1fr auto 1fr}' +
    '.sw-brand{justify-self:start}.sw-topcta{justify-self:end}' +
    '@media (max-width:860px){.sw-topbar{display:flex}}' +
    // Desktop: the rail's dot centerline tracks the topbar's right padding, so
    // the dots sit exactly under the CTA's right edge (17px = rail padding 10 + half-dot 7).
    '@media (min-width:861px){.sw-route{right:calc(clamp(18px,5vw,64px) - 17px)}}' +
    // Uniform rail: inactive dots share one neutral tone; only the active dot
    // takes its scene accent (per-scene colors made the rail look scattered).
    '.sw-route__dot i{background:color-mix(in srgb,#FAF3E3 55%,transparent)}' +
    '.sw-route__dot:hover i{background:#FAF3E3}' +
    '.sw-route__dot.is-active i{background:var(--sw-accent)}';
  document.head.appendChild(st);

  // Accessible names for the engine's route-rail dots (one per scene).
  var dotLabels = ['The Maker', 'Your Shop', 'The Buyer', 'Delivery', 'The Money', 'One Market'];
  document.querySelectorAll('.sw-route__dot').forEach(function (dot, i) {
    dot.setAttribute('aria-label', 'Go to ' + (dotLabels[i] || 'scene ' + (i + 1)));
  });

  var mark = document.querySelector('.sw-brand__mark');
  if (mark) {
    var logo = document.createElement('img');
    logo.src = '/images/emakola-logo.svg';
    logo.alt = '';
    logo.style.cssText = 'width:28px;height:28px;display:block;';
    mark.replaceWith(logo);
  }
})();
