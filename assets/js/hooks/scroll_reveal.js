const ScrollReveal = {
  mounted() {
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

    this.el.querySelectorAll("[data-reveal]").forEach((el) => {
      el.classList.add("reveal-hidden");
      observer.observe(el);
    });
  },
};

export default ScrollReveal;
