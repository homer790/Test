// Prova automatica della schermata di controllo in un vero browser (Playwright + Chromium).
// uso:
//   1. avvia la schermata senza aprire il browser:
//      NON_APRIRE_BROWSER=1 python schermata_controllo.py CARTELLA/NOME_controllo.txt
//   2. node test/prova-schermata.js "INDIRIZZO_STAMPATO" CARTELLA/NOME_controllo.txt
// Variabili: PLAYWRIGHT (modulo playwright), CHROME (eseguibile Chromium), USCITA (cartella delle schermate).
// Controlla: accesso con token, 10 righe per pagina, audio con Range (Safari), conferma che blocca il campo,
// Annulla, Salva (file aggiornato e ricaricato), parole confermate bloccate dopo il ricaricamento.
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const fs = require('fs');
const URL = process.argv[2], FILE = process.argv[3];
const out = (process.env.USCITA || '.') + '/';
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined });
  const page = await browser.newPage({ viewport: { width: 1200, height: 900 } });
  page.on('dialog', d => d.accept());
  const errori = []; page.on('pageerror', e => errori.push(e.message));
  // 0. accesso senza token rifiutato
  const r = await page.request.get(URL.split('?')[0]); console.log('senza token:', r.status());
  await page.goto(URL); await page.waitForSelector('.voce');
  console.log('righe pagina 1:', await page.locator('.voce').count(), '| pagine:', await page.locator('button.pagina').count());
  console.log('conteggi:', await page.locator('.conteggi').innerText());
  // audio: il ritaglio si scarica (con Range come Safari)
  const src = await page.locator('audio').first().getAttribute('src');
  const a = await page.request.get(new globalThis.URL(src, URL).href, { headers: { Range: 'bytes=0-1' } });
  console.log('audio Range:', a.status(), a.headers()['content-range']);
  await page.screenshot({ path: out + '1-iniziale.png', fullPage: true });
  // 1. correggo la voce 1 e confermo; confermo la voce 2 così com'è
  const v1 = page.locator('.voce').nth(0), v2 = page.locator('.voce').nth(1);
  const n1 = await v1.getAttribute('data-numero'), n2 = await v2.getAttribute('data-numero');
  const orig2 = await v2.locator('input[type=text]').inputValue();
  await v1.locator('input[type=text]').fill('CORRETTA');
  await v1.locator('input[type=checkbox]').check();
  await v2.locator('input[type=checkbox]').check();
  console.log('voce', n2, 'prima:', orig2, '→ dopo spunta:', await v2.locator('input[type=text]').inputValue(),
              '| readonly:', await v2.locator('input[type=text]').getAttribute('readonly') !== null);
  // modifica non confermata sulla voce 3, poi la tolgo con Annulla
  await page.locator('.voce').nth(2).locator('input[type=text]').fill('bozza');
  console.log('stato:', await page.locator('#stato').innerText());
  // cambio pagina: le modifiche restano
  await page.locator('button.pagina', { hasText: '2' }).click();
  console.log('pagina 2, prima voce:', await page.locator('.voce').first().getAttribute('data-numero'));
  await page.locator('button.pagina', { hasText: /^1/ }).click();
  console.log('ritorno a pagina 1, voce 1 ancora modificata:', await page.locator('.voce').nth(0).locator('input[type=text]').inputValue());
  await page.screenshot({ path: out + '2-modifiche.png', fullPage: true });
  // 2. Annulla → tutto come nel file
  await page.click('#annulla');
  await page.waitForFunction(() => document.querySelector('#salva').disabled);
  console.log('dopo Annulla voce 1:', await page.locator('.voce').nth(0).locator('input[type=text]').inputValue());
  // 3. rifaccio le modifiche e salvo
  await page.locator('.voce').nth(0).locator('input[type=text]').fill('CORRETTA');
  await page.locator('.voce').nth(0).locator('input[type=checkbox]').check();
  await page.locator('.voce').nth(1).locator('input[type=checkbox]').check();
  await page.locator('.voce').nth(2).locator('input[type=text]').fill('bozza');
  await page.click('#salva');
  await page.waitForSelector('#stato.ok, #stato.errore');
  console.log('dopo Salva:', await page.locator('#stato').innerText());
  console.log('conteggi:', await page.locator('.conteggi').innerText());
  const c1 = page.locator(`.voce[data-numero="${n1}"]`);
  console.log('voce', n1, 'casella disabilitata:', await c1.locator('input[type=checkbox]').isDisabled(),
              '| campo readonly:', await c1.locator('input[type=text]').getAttribute('readonly') !== null,
              '| nota:', await c1.locator('.nota').innerText());
  await page.screenshot({ path: out + '3-salvato.png', fullPage: true });
  console.log('righe PAROLA nel file:\n' + fs.readFileSync(FILE, 'utf8').split('\n').filter(l => /^PAROLA 00[1-4]/.test(l)).join('\n'));
  // 4. ricarico la pagina da zero: lo stato viene dal file
  await page.reload(); await page.waitForSelector('.voce');
  console.log('dopo ricarica, voce', n1, ':', await page.locator(`.voce[data-numero="${n1}"] input[type=text]`).inputValue(),
              '| bloccata:', await page.locator(`.voce[data-numero="${n1}"] input[type=checkbox]`).isDisabled());
  // 5. telefono
  await page.setViewportSize({ width: 390, height: 800 });
  await page.screenshot({ path: out + '4-stretto.png' });
  console.log('errori JS:', errori.length ? errori : 'nessuno');
  await browser.close();
})();
