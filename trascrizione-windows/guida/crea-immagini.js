// Crea le illustrazioni della guida per Windows (guida/immagini/<id>.png), una per ogni
// <section class="scena"> di guida/illustrazioni.html.
// uso: node guida/crea-immagini.js   (meglio: guida/crea-immagini.sh)
const path = require('path');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined });
  const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 2 });
  await page.goto('file://' + path.join(__dirname, 'illustrazioni.html'));
  await page.evaluate(() => document.fonts.ready);
  const scene = await page.locator('section.scena').evaluateAll((els) => els.map((e) => e.id));
  for (const id of scene) {
    await page.locator('#' + id).screenshot({ path: path.join(__dirname, 'immagini', id + '.png') });
    console.log('  ' + id + '.png');
  }
  await browser.close();
})();
