// Renders scripts/icon.svg to every PNG the app and extension need.
// Run from Wider/: node scripts/render_icons.js
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const svg = fs.readFileSync(path.join(__dirname, "icon.svg"), "utf8");
const targets = [
  ["App/Assets.xcassets/AppIcon.appiconset/icon-1024.png", 1024],
  ...[48, 96, 128, 256, 512].map((s) => [`Extension/Resources/images/icon-${s}.png`, s]),
];

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const [out, size] of targets) {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(
      `<style>html,body{margin:0}svg{display:block;width:${size}px;height:${size}px}</style>${svg}`
    );
    await page.screenshot({ path: path.join(root, out), omitBackground: false });
    console.log(out);
  }
  await browser.close();
})();
