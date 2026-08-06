/* Burger navigation for narrow viewports.
 *
 * The menu is CSS-driven: .nav-open on the header is the only state, and the
 * media query decides whether that state means anything. Above the breakpoint
 * the links are laid out inline regardless, so a menu left open while a phone
 * rotates cannot strand the header in a broken state.
 */
(function () {
  var header = document.querySelector(".site-header");
  if (!header) return;

  var toggle = header.querySelector(".nav-toggle");
  var nav = header.querySelector(".nav-mini");
  if (!toggle || !nav) return;

  function setOpen(open) {
    header.classList.toggle("nav-open", open);
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
  }

  toggle.addEventListener("click", function (event) {
    // Without this the document listener below sees the same click and closes
    // the menu in the same tick it was opened.
    event.stopPropagation();
    setOpen(!header.classList.contains("nav-open"));
  });

  // Following a link navigates away, but a same-page anchor would otherwise
  // leave the panel hanging over the content.
  nav.addEventListener("click", function (event) {
    if (event.target.closest("a")) setOpen(false);
  });

  document.addEventListener("click", function (event) {
    if (!header.contains(event.target)) setOpen(false);
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape" && header.classList.contains("nav-open")) {
      setOpen(false);
      // The trigger is where focus came from; dropping it on <body> would send
      // a keyboard user back to the top of the document.
      toggle.focus();
    }
  });
})();
