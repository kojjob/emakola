// Makola "how it works" scroll film — config + theme.
// Renders via scrub-engine.js (self-contained vanilla JS, no app.js coupling).
(function () {
  var root = document.documentElement;
  root.style.setProperty('--sw-bg', '#7b7051');
  root.style.setProperty('--sw-ink', '#FAF3E3');
  root.style.setProperty('--sw-ink-soft', '#d9cfb4');
  root.style.setProperty('--sw-accent', '#F5B301');

  mountScrollWorld(document.getElementById('tour-world'), {
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
  });
})();
