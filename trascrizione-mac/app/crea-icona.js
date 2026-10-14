// Crea l'icona dell'app dal disegno icona.svg:
//   app/icona.png (1024×1024, sfondo trasparente) → poi crea-installatore.sh la converte in AppIcon.icns.
// uso: node app/crea-icona.js   (variabili: PLAYWRIGHT = modulo playwright, CHROME = Chromium)
const path = require('path');
const fs = require('fs');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');

(async () => {
  const svg = fs.readFileSync(path.join(__dirname, 'icona.svg'), 'utf8');
  const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined });
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
  await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
  await page.locator('svg').screenshot({ path: path.join(__dirname, 'icona.png'), omitBackground: true });
  await browser.close();
  console.log('Creata app/icona.png');
})();
