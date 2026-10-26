// Reporting a site opens a mail with that site's URL and nothing else, so the
// person sees exactly what is shared before anything is sent.
const REPORT_ADDRESS = "support@getwider.app";

const $ = (id) => document.getElementById(id);
const t = (key) => browser.i18n.getMessage(key) || key;

document.querySelectorAll("[data-i18n]").forEach((el) => {
  el.textContent = t(el.dataset.i18n);
});

// No tabs permission: the content script in the page reports its own URL. If
// it does not answer, Wider has no access to this page (or it is a page no
// extension may touch).
async function pageUrl() {
  try {
    const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
    const reply = await browser.tabs.sendMessage(tab.id, { type: "wider:url" });
    return reply?.url ?? null;
  } catch {
    return null;
  }
}

function render(settings, url) {
  const siteWide = WiderSettings.isSiteWide(settings, url);
  const pageOff = WiderSettings.isPageOff(settings, url);
  $("toggle").setAttribute("aria-pressed", String(siteWide && !pageOff));
  $("toggle").disabled = pageOff;
  $("mode").textContent = t(siteWide && !pageOff ? "modeWide" : "modeNormal");
  $("pageOff").checked = pageOff;
  $("pageOff").disabled = !siteWide;
}

async function main() {
  const url = await pageUrl();
  if (!url) {
    $("unavailable").hidden = false;
    return;
  }

  $("host").textContent = WiderSettings.siteKey(url);
  $("report").href =
    `mailto:${REPORT_ADDRESS}` +
    `?subject=${encodeURIComponent(t("reportSubject"))}` +
    `&body=${encodeURIComponent(url)}`;

  const redraw = async () => render(await WiderSettings.load(), url);

  $("toggle").addEventListener("click", async () => {
    const settings = await WiderSettings.load();
    await WiderSettings.setSiteWide(url, !WiderSettings.isSiteWide(settings, url));
    redraw();
  });

  $("pageOff").addEventListener("change", async (event) => {
    await WiderSettings.setPageOff(url, event.target.checked);
    redraw();
  });

  await redraw();
  $("ready").hidden = false;
}

main();
