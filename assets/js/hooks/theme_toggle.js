const ThemeToggle = {
  mounted() {
    this.el.addEventListener("click", () => {
      const isDark = document.documentElement.classList.contains("dark");
      const newTheme = isDark ? "light" : "dark";

      // Toggle dark class for TailwindCSS
      document.documentElement.classList.toggle("dark", newTheme === "dark");
      // Sync daisyUI data-theme attribute
      document.documentElement.setAttribute("data-theme", newTheme);
      // Persist preference
      localStorage.setItem("theme", newTheme);
      // Notify LiveView of theme change
      this.pushEvent("theme-changed", { theme: newTheme });
    });
  }
};

export default ThemeToggle;
