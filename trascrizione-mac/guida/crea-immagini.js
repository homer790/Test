// Crea le immagini della guida (guida/immagini/*.png):
//  - le illustrazioni disegnate in guida/illustrazioni.html (una per ogni <section class="scena">);
//  - le immagini reali della schermata di controllo, dal programma vero avviato su un progetto
//    dimostrativo (indirizzo passato come argomento), con i passi numerati.
// uso: node guida/crea-immagini.js URL_SCHERMATA   (meglio: guida/crea-immagini.sh)
const path = require('path');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');

const CARTELLA = path.join(__dirname, 'immagini');
const URL_SCHERMATA = process.argv[2];

// Aggiunge sulla pagina i cerchi rossi numerati sopra gli elementi indicati
async function segna(page, segni) {
  await page.evaluate((segni) => {
    for (const s of segni) {
      const el = document.querySelector(s.sel);
      if (!el) continue;
      const r = el.getBoundingClientRect();
      const anello = document.createElement('div');
      Object.assign(anello.style, {
        position: 'fixed', left: (r.left - 5) + 'px', top: (r.top - 5) + 'px', width: (r.width + 10) + 'px',
        height: (r.height + 10) + 'px', border: '3px solid #e3262c', borderRadius: '10px', zIndex: 50,
        pointerEvents: 'none', boxSizing: 'border-box',
      });
      const etichetta = document.createElement('div');
      etichetta.textContent = s.testo;
      Object.assign(etichetta.style, {
        position: 'fixed', zIndex: 51, background: '#e3262c', color: '#fff', font: '700 13px Inter, sans-serif',
        padding: '4px 10px', borderRadius: '13px', whiteSpace: 'nowrap', boxShadow: '0 3px 8px rgba(0,0,0,.25)',
      });
      document.body.append(anello, etichetta);
      const e = etichetta.getBoundingClientRect();
      const pos = {
        sotto: [r.left + r.width / 2 - e.width / 2, r.bottom + 12],
        sopra: [r.left + r.width / 2 - e.width / 2, r.top - e.height - 12],
        sinistra: [r.left - e.width - 14, r.top + r.height / 2 - e.height / 2],
        destra: [r.right + 14, r.top + r.height / 2 - e.height / 2],
      }[s.dove];
      // l'etichetta resta sempre dentro l'immagine
      etichetta.style.left = Math.min(Math.max(pos[0], 8), window.innerWidth - e.width - 8) + 'px';
      etichetta.style.top = Math.min(Math.max(pos[1], 8), window.innerHeight - e.height - 8) + 'px';
    }
  }, segni);
}

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined });

  // 1. Illustrazioni
  const page = await browser.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 2 });
  await page.goto('file://' + path.join(__dirname, 'illustrazioni.html'));
  await page.evaluate(() => document.fonts.ready);
  const scene = await page.locator('section.scena').evaluateAll((els) => els.map((e) => e.id));
  for (const id of scene) {
    await page.locator('#' + id).screenshot({ path: path.join(CARTELLA, id + '.png') });
    console.log('  ' + id + '.png');
  }

  // 2. Schermata di controllo reale (progetto dimostrativo)
  if (URL_SCHERMATA) {
    const s = await browser.newPage({ viewport: { width: 1180, height: 860 }, deviceScaleFactor: 2 });
    await s.goto(URL_SCHERMATA);
    await s.waitForSelector('.voce');
    await s.evaluate(() => document.fonts.ready);
    // La voce 003 è in corso di correzione: parola scritta e «Confermata» spuntata, non ancora salvata
    const v3 = s.locator('.voce[data-numero="003"]');
    await v3.locator('input[type=text]').fill('raku');
    await v3.locator('input[type=checkbox]').check();
    await segna(s, [
      { sel: '.voce[data-numero="004"] audio', testo: '1. Ascolta il ritaglio', dove: 'sopra' },
      { sel: '.voce[data-numero="004"] input[type=text]', testo: '2. Correggi la parola', dove: 'sotto' },
      { sel: '.voce[data-numero="004"] label', testo: '3. Spunta «Confermata»', dove: 'sotto' },
      { sel: '#salva', testo: '4. Alla fine: «Salva»', dove: 'sopra' },
    ]);
    await s.screenshot({ path: path.join(CARTELLA, 'p06-schermata.png') });
    console.log('  p06-schermata.png');

    // Stessa schermata, senza segni: le parti dello schermo
    const s2 = await browser.newPage({ viewport: { width: 1180, height: 1640 }, deviceScaleFactor: 2 });
    await s2.goto(URL_SCHERMATA);
    await s2.waitForSelector('.voce');
    await s2.evaluate(() => document.fonts.ready);
    await segna(s2, [
      { sel: '.conteggi', testo: 'Quante parole mancano', dove: 'sotto' },
      { sel: '.voce[data-numero="001"] .correzione', testo: 'Confermata e salvata: bloccata', dove: 'sopra' },
      { sel: '#paginazione', testo: '10 parole per pagina', dove: 'sopra' },
      { sel: '#annulla', testo: 'Scarta le modifiche', dove: 'sopra' },
    ]);
    await s2.screenshot({ path: path.join(CARTELLA, 'p08-schermata-parti.png') });
    console.log('  p08-schermata-parti.png');
  }
  await browser.close();
})();
