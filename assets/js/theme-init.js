// Prevent Flash of Unstyled Content (FOUC) for theme.
// This script must run before the page renders to avoid a flash.
// It is loaded as a separate file to comply with Content-Security-Policy.
(function () {
  var theme = localStorage.getItem("theme");
  var isLight =
    theme === "light" ||
    (!theme && window.matchMedia("(prefers-color-scheme: light)").matches);
  if (isLight) {
    document.documentElement.classList.remove("dark");
    document.documentElement.setAttribute("data-theme", "light");
  } else {
    document.documentElement.classList.add("dark");
    document.documentElement.setAttribute("data-theme", "dark");
  }
})();
