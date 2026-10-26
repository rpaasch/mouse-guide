// Where Wider keeps its choices, and how a page decides whether it is wide.
// Loaded by both the content script and the popup.
const WiderSettings = (() => {
  const KEY = "wider";

  // A site is its hostname. A page is origin + path: query and hash are left
  // out, so a page turned off stays off when a tracking parameter changes.
  const siteKey = (url) => new URL(url).hostname;
  const pageKey = (url) => {
    const u = new URL(url);
    return u.origin + u.pathname;
  };

  async function load() {
    const stored = (await browser.storage.local.get(KEY))[KEY] || {};
    return { sites: stored.sites || {}, pagesOff: stored.pagesOff || {} };
  }

  async function update(change) {
    const s = await load();
    change(s);
    await browser.storage.local.set({ [KEY]: s });
  }

  // Sites start wide. Only the exceptions are stored: a site switched to
  // normal, and single pages turned off.
  const isSiteWide = (s, url) => s.sites[siteKey(url)] !== false;
  const isPageOff = (s, url) => s.pagesOff[pageKey(url)] === true;
  const isWide = (s, url) => isSiteWide(s, url) && !isPageOff(s, url);

  const setSiteWide = (url, wide) =>
    update((s) => {
      if (wide) delete s.sites[siteKey(url)];
      else s.sites[siteKey(url)] = false;
    });

  const setPageOff = (url, off) =>
    update((s) => {
      if (off) s.pagesOff[pageKey(url)] = true;
      else delete s.pagesOff[pageKey(url)];
    });

  return { KEY, load, isSiteWide, isPageOff, isWide, setSiteWide, setPageOff, siteKey };
})();
