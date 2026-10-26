// Runs Wider's content script and popup in Chromium against real pages.
// Run from Wider/: node tests/run.js
const { chromium } = require("playwright");
const http = require("http");
const fs = require("fs");
const path = require("path");

const res = path.join(__dirname, "..", "Extension", "Resources");
const read = (f) => fs.readFileSync(f, "utf8");
const shim = read(path.join(__dirname, "fake-browser.js"));
const contentScripts = shim + read(path.join(res, "settings.js")) + read(path.join(res, "content.js")) +
  // Init scripts run in their own scope; let the tests reach the settings.
  ";window.WiderSettings = WiderSettings;";

const pages = {
  "/with-meta": `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body>hi</body></html>`,
  "/already-cover": `<!doctype html><html><head><meta name="viewport" content="width=device-width,viewport-fit=cover"></head><body>hi</body></html>`,
  "/no-meta": `<!doctype html><html><head></head><body>hi</body></html>`,
  "/spa": `<!doctype html><html><head><meta name="viewport" content="width=device-width"></head><body>
    <script>setTimeout(() => document.querySelector('meta[name=viewport]').setAttribute('content', 'width=device-width, maximum-scale=1'), 300)</script></body></html>`,
};

const server = http.createServer((req, resp) => {
  const p = req.url.split("?")[0];
  if (p === "/popup.html") return resp.end(read(path.join(res, "popup.html")));
  if (p.endsWith(".js") || p.endsWith(".css")) {
    const file = path.join(res, path.basename(p));
    if (fs.existsSync(file)) return resp.end(read(file));
  }
  resp.setHeader("content-type", "text/html");
  resp.end(pages[p] ?? pages["/with-meta"]);
});

let failures = 0;
function check(name, actual, expected) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (!ok) failures++;
  console.log(`${ok ? "ok  " : "FAIL"} ${name}${ok ? "" : `\n     got      ${JSON.stringify(actual)}\n     expected ${JSON.stringify(expected)}`}`);
}

const metas = (page) =>
  page.evaluate(() => [...document.querySelectorAll('meta[name="viewport" i]')].map((m) => m.getAttribute("content")));
const settle = (page) => page.waitForTimeout(150);
const setStore = (page, fn, ...args) =>
  page.evaluate(([src, a]) => new Function("return " + src)()(...a), [fn.toString(), args]);

(async () => {
  await new Promise((r) => server.listen(0, r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch();

  async function open(url, store = {}) {
    const page = await browser.newPage();
    await page.addInitScript(`window.__store = ${JSON.stringify(store)};` + contentScripts);
    await page.goto(base + url);
    await settle(page);
    return page;
  }

  // Widening
  let page = await open("/with-meta");
  check("adds viewport-fit=cover", await metas(page), ["width=device-width, initial-scale=1, viewport-fit=cover"]);

  await setStore(page, (u) => WiderSettings.setSiteWide(u, false), base + "/with-meta");
  await settle(page);
  check("switching the site to normal restores the exact tag", await metas(page), ["width=device-width, initial-scale=1"]);
  check("and leaves no marker behind", await page.evaluate(() => document.querySelector("[data-wider-original]")), null);

  await setStore(page, (u) => WiderSettings.setSiteWide(u, true), base + "/with-meta");
  await settle(page);
  check("switching back widens again", await metas(page), ["width=device-width, initial-scale=1, viewport-fit=cover"]);

  await setStore(page, (u) => WiderSettings.setPageOff(u, true), base + "/with-meta?x=1#y");
  await settle(page);
  check("turning the page off ignores query and hash", await metas(page), ["width=device-width, initial-scale=1"]);
  await page.close();

  page = await open("/other-page", { wider: { sites: {}, pagesOff: { [base + "/with-meta"]: true } } });
  check("another page on the same site stays wide", await metas(page), ["width=device-width, initial-scale=1, viewport-fit=cover"]);
  await page.evaluate(() => history.pushState({}, "", "/with-meta"));
  await page.waitForTimeout(1300);
  check("an SPA navigating to a turned-off page narrows", await metas(page), ["width=device-width, initial-scale=1"]);
  await page.close();

  page = await open("/with-meta", { wider: { sites: { "127.0.0.1": false }, pagesOff: {} } });
  check("a site saved as normal is left alone on load", await metas(page), ["width=device-width, initial-scale=1"]);
  await page.close();

  page = await open("/already-cover");
  check("a page that already covers is unchanged", await metas(page), ["width=device-width,viewport-fit=cover"]);
  await setStore(page, (u) => WiderSettings.setSiteWide(u, false), base);
  await settle(page);
  check("and still unchanged when narrowed", await metas(page), ["width=device-width,viewport-fit=cover"]);
  await page.close();

  page = await open("/no-meta");
  check("a page without a tag gets one that only sets viewport-fit", await metas(page), ["viewport-fit=cover"]);
  await setStore(page, (u) => WiderSettings.setSiteWide(u, false), base);
  await settle(page);
  check("which is removed again when narrowed", await metas(page), []);
  await page.close();

  page = await open("/spa");
  await page.waitForTimeout(400);
  check("a page rewriting its tag gets widened again", await metas(page), ["width=device-width, maximum-scale=1, viewport-fit=cover"]);
  await setStore(page, (u) => WiderSettings.setSiteWide(u, false), base);
  await settle(page);
  check("and narrowing restores the rewritten tag", await metas(page), ["width=device-width, maximum-scale=1"]);
  await page.close();

  page = await open("/with-meta");
  check("answers the popup with its URL", await page.evaluate(() => browser.runtime.__send({ type: "wider:url" })), { url: base + "/with-meta" });
  await page.close();

  // Popup
  async function popup(pageUrl, store = {}) {
    const p = await browser.newPage({ viewport: { width: 280, height: 360 } });
    await p.addInitScript(`window.__store = ${JSON.stringify(store)}; window.__pageUrl = ${JSON.stringify(pageUrl)};` + shim);
    await p.goto(base + "/popup.html");
    await settle(p);
    return p;
  }
  const state = (p) =>
    p.evaluate(() => ({
      host: document.getElementById("host").textContent,
      pressed: document.getElementById("toggle").getAttribute("aria-pressed"),
      mode: document.getElementById("mode").textContent,
      pageOff: document.getElementById("pageOff").checked,
      store: window.__store.wider ?? null,
    }));

  page = await popup("https://news.example.com/a/b?q=1");
  check("popup starts wide", await state(page), { host: "news.example.com", pressed: "true", mode: "modeWide", pageOff: false, store: null });
  check("report link carries only the URL", await page.getAttribute("#report", "href"),
    "mailto:support@getwider.app?subject=reportSubject&body=" + encodeURIComponent("https://news.example.com/a/b?q=1"));
  await page.click("#toggle");
  await settle(page);
  check("tapping saves the site as normal", await state(page),
    { host: "news.example.com", pressed: "false", mode: "modeNormal", pageOff: false, store: { sites: { "news.example.com": false }, pagesOff: {} } });
  await page.click("#toggle");
  await page.check("#pageOff");
  await settle(page);
  check("turning one page off", await state(page),
    { host: "news.example.com", pressed: "false", mode: "modeNormal", pageOff: true, store: { sites: {}, pagesOff: { "https://news.example.com/a/b": true } } });
  await page.close();

  page = await popup(null);
  check("popup explains when it has no access", await page.evaluate(() => [document.getElementById("ready").hidden, document.getElementById("unavailable").hidden]), [true, false]);
  await page.close();

  await browser.close();
  server.close();
  console.log(failures ? `\n${failures} failed` : "\nall passed");
  process.exit(failures ? 1 : 0);
})();
