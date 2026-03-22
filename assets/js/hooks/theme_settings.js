const ThemeSettings = {
  mounted() {
    // Restore saved preferences on mount
    if (localStorage.getItem("compact_ui") === "true") {
      document.documentElement.classList.add("compact");
    }
    if (localStorage.getItem("high_contrast") === "true") {
      document.documentElement.classList.add("high-contrast");
    }

    this.handleEvent("set-theme", ({ theme }) => {
      if (theme === "dark") {
        document.documentElement.classList.add("dark");
        document.documentElement.setAttribute("data-theme", "dark");
        localStorage.setItem("theme", "dark");
      } else {
        document.documentElement.classList.remove("dark");
        document.documentElement.setAttribute("data-theme", "light");
        localStorage.setItem("theme", "light");
      }
    });

    this.handleEvent("set-ui-mode", ({ compact }) => {
      if (compact) {
        document.documentElement.classList.add("compact");
        localStorage.setItem("compact_ui", "true");
      } else {
        document.documentElement.classList.remove("compact");
        localStorage.setItem("compact_ui", "false");
      }
    });

    this.handleEvent("set-high-contrast", ({ enabled }) => {
      if (enabled) {
        document.documentElement.classList.add("high-contrast");
        localStorage.setItem("high_contrast", "true");
      } else {
        document.documentElement.classList.remove("high-contrast");
        localStorage.setItem("high_contrast", "false");
      }
    });
  }
};

export default ThemeSettings;
