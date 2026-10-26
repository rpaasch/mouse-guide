// Wider's whole effect on a page: add viewport-fit=cover to the viewport meta
// tag, so the page is laid out across the full screen instead of stopping at
// the safe area beside Safari's controls. Turning it off puts back exactly what
// the page had.
(() => {
  const ORIGINAL = "data-wider-original";
  const CREATED = "data-wider-created";
  const SELECTOR = 'meta[name="viewport" i]';

  let wide = false;
  let observer = null;

  // "width=device-width, initial-scale=1" <-> Map, keeping the page's order.
  function parse(content) {
    const map = new Map();
    for (const part of (content || "").split(/[,;]/)) {
      const [key, ...rest] = part.split("=");
      if (key.trim()) map.set(key.trim().toLowerCase(), rest.join("=").trim());
    }
    return map;
  }

  const serialize = (map) =>
    [...map].map(([k, v]) => (v ? `${k}=${v}` : k)).join(", ");

  function widenMeta(meta) {
    const current = meta.getAttribute("content") || "";
    const map = parse(current);
    // Already ours: nothing to do. This is also what stops the observer from
    // reacting to its own write.
    if (meta.hasAttribute(ORIGINAL) && map.get("viewport-fit") === "cover") return;
    // Either first sight, or the page rewrote the tag (SPAs do): what the page
    // set now is what to restore later.
    meta.setAttribute(ORIGINAL, current);
    if (map.get("viewport-fit") === "cover") return;
    map.set("viewport-fit", "cover");
    meta.setAttribute("content", serialize(map));
  }

  function widenAll() {
    document.querySelectorAll(SELECTOR).forEach(widenMeta);
  }

  // A page with no viewport tag gets one that only sets viewport-fit. Adding
  // width=device-width would turn a desktop layout into a mobile one, which is
  // a different app.
  function ensureMeta() {
    if (!wide || document.querySelector(SELECTOR)) return;
    const meta = document.createElement("meta");
    meta.setAttribute("name", "viewport");
    meta.setAttribute(CREATED, "");
    meta.setAttribute(ORIGINAL, "");
    meta.setAttribute("content", "viewport-fit=cover");
    (document.head || document.documentElement).appendChild(meta);
  }

  function widen() {
    wide = true;
    widenAll();
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", ensureMeta, { once: true });
    } else {
      ensureMeta();
    }
    // Runs from document_start, so the page's own tag usually arrives after
    // this; the observer catches it, and any later rewrite. It watches the
    // document itself because <html> may not exist yet.
    if (!observer) {
      observer = new MutationObserver(widenAll);
      observer.observe(document, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["content", "name"],
      });
    }
  }

  function restore() {
    wide = false;
    observer?.disconnect();
    observer = null;
    document.querySelectorAll(`meta[${ORIGINAL}]`).forEach((meta) => {
      if (meta.hasAttribute(CREATED)) {
        meta.remove();
        return;
      }
      meta.setAttribute("content", meta.getAttribute(ORIGINAL));
      meta.removeAttribute(ORIGINAL);
    });
  }

  async function refresh() {
    const settings = await WiderSettings.load();
    const shouldBeWide = WiderSettings.isWide(settings, location.href);
    if (shouldBeWide && !wide) widen();
    else if (!shouldBeWide && wide) restore();
  }

  browser.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && WiderSettings.KEY in changes) refresh();
  });

  // The popup has no tabs permission, so it asks the page where it is.
  browser.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type === "wider:url") sendResponse({ url: location.href });
  });

  // Pages can be turned off one by one, and single-page apps change path
  // without loading a new document, so notice when the address changes.
  let lastHref = location.href;
  const checkHref = () => {
    if (location.href === lastHref) return;
    lastHref = location.href;
    refresh();
  };
  window.addEventListener("popstate", checkHref);
  setInterval(checkHref, 1000);

  refresh();
})();
