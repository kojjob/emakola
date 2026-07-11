/**
 * ScrollReveal — reveals [data-reveal] / .reveal-up children as they enter
 * the viewport.
 *
 * Two entry points share bindScrollReveal:
 *  - LiveView hook:  <div phx-hook="ScrollReveal">
 *  - Dead pages:     <div data-scroll-reveal> (bound by app.js)
 */
export function bindScrollReveal(root) {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("revealed");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.1, rootMargin: "0px 0px -50px 0px" }
  );

  // Observe both data-reveal and .reveal-up elements
  root.querySelectorAll("[data-reveal]").forEach((el) => {
    el.classList.add("reveal-hidden");
    observer.observe(el);
  });

  root.querySelectorAll(".reveal-up").forEach((el) => {
    observer.observe(el);
  });
}

const ScrollReveal = {
  mounted() {
    bindScrollReveal(this.el);
  },
};

export default ScrollReveal;
