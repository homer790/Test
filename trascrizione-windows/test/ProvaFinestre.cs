// Prova delle finestre di Finestre.cs (senza Windows: con Mono su uno schermo virtuale Xvfb).
// Apre ogni tipo di finestra, la fotografa, simula i clic e controlla il risultato restituito.
// uso: test/prova-finestre.sh
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Windows.Forms;

public static class ProvaFinestre
{
    static int fallite = 0;
    static string cartella = ".";

    static Control Trova(Control radice, Type tipo, string testo)
    {
        foreach (Control c in radice.Controls)
        {
            if (c.GetType() == tipo && (testo == null || c.Text == testo)) return c;
            Control dentro = Trova(c, tipo, testo);
            if (dentro != null) return dentro;
        }
        return null;
    }

    // Programma un'azione da eseguire sulla finestra appena si apre (foto, poi clic)
    static void Dopo(string foto, Action<Form> azione)
    {
        Timer t = new Timer();
        t.Interval = 400;
        t.Tick += delegate(object s, EventArgs e)
        {
            t.Stop();
            Form f = Form.ActiveForm;
            if (f == null && Application.OpenForms.Count > 0) f = Application.OpenForms[Application.OpenForms.Count - 1];
            // Foto dello schermo virtuale ritagliata sulla finestra (ImageMagick «import»)
            f.Refresh();
            Application.DoEvents();
            Rectangle r = f.Bounds;
            string percorso = System.IO.Path.Combine(cartella, foto + ".png");
            System.Diagnostics.Process p = System.Diagnostics.Process.Start("import",
                "-window root -crop " + r.Width + "x" + r.Height + "+" + r.X + "+" + r.Y + " +repage \"" + percorso + "\"");
            p.WaitForExit();
            azione(f);
        };
        t.Start();
    }

    static void Clic(Form f, string pulsante)
    {
        Button b = (Button)Trova(f, typeof(Button), pulsante);
        if (b == null) throw new Exception("pulsante non trovato: " + pulsante);
        b.PerformClick();
    }

    static void Verifica(string descrizione, bool ok)
    {
        Console.WriteLine((ok ? "   OK  " : "   NO  ") + descrizione);
        if (!ok) fallite++;
    }

    public static int Main(string[] argomenti)
    {
        if (argomenti.Length > 0) cartella = argomenti[0];
        if (argomenti.Length > 1) Finestre.Icona = argomenti[1];
        Finestre.Prepara();

        // 1. Avviso con OK
        Dopo("w-avviso", delegate(Form f) { Clic(f, "OK"); });
        Finestre.Esito e = Finestre.Mostra("Installazione completata.\n\nOra si apre il menu principale.", null, false,
                                           new string[] { "OK" }, null, false);
        Verifica("avviso: «OK» restituito", e.Pulsante == "OK");

        // 2. Menu principale: pulsanti di opzione, si sceglie la seconda voce e «Avanti»
        string[] menu = { "Nuovo progetto", "Apri un progetto", "Guida rapida", "Disinstalla Trascrivi Audio" };
        Dopo("w-menu", delegate(Form f)
        {
            ((RadioButton)Trova(f, typeof(RadioButton), "Apri un progetto")).Checked = true;
            Clic(f, "Avanti");
        });
        e = Finestre.Mostra("Cosa vuoi fare?", menu, false, new string[] { "Esci", "Avanti" }, "Esci", false);
        Verifica("menu: «Apri un progetto» con «Avanti»", e.Pulsante == "Avanti" && e.Voce == "Apri un progetto");

        // 3. Menu: «Esci» = annullato (null)
        Dopo("w-menu-esci", delegate(Form f) { Clic(f, "Esci"); });
        e = Finestre.Mostra("Cosa vuoi fare?", menu, false, new string[] { "Esci", "Avanti" }, "Esci", false);
        Verifica("menu: «Esci» restituisce null", e.Pulsante == null);

        // 4. Nome del progetto: campo di testo
        Dopo("w-nome", delegate(Form f)
        {
            ((TextBox)Trova(f, typeof(TextBox), null)).Text = "Intervista Rossi";
            Clic(f, "Avanti");
        });
        e = Finestre.Mostra("Scrivi il nome del nuovo progetto:", null, true, new string[] { "Annulla", "Avanti" }, "Annulla", false);
        Verifica("nome: testo scritto restituito", e.Pulsante == "Avanti" && e.Testo == "Intervista Rossi");

        // 5. Tre pulsanti (cosa fare con il progetto)
        Dopo("w-cosa-fare", delegate(Form f) { Clic(f, "Analisi delle parole"); });
        e = Finestre.Mostra("Progetto «Intervista Rossi»: cosa vuoi fare?", null, false,
                            new string[] { "Annulla", "Rielabora la trascrizione", "Analisi delle parole" }, "Annulla", false);
        Verifica("tre pulsanti: «Analisi delle parole»", e.Pulsante == "Analisi delle parole");

        // 6. Molti progetti (più di 10): lista che scorre
        string[] tanti = new string[15];
        for (int i = 0; i < tanti.Length; i++) tanti[i] = "Progetto " + (i + 1);
        Dopo("w-lista-lunga", delegate(Form f)
        {
            ((ListBox)Trova(f, typeof(ListBox), null)).SelectedIndex = 12;
            Clic(f, "Avanti");
        });
        e = Finestre.Mostra("Scegli il progetto da aprire:", tanti, false, new string[] { "Annulla", "Avanti" }, "Annulla", false);
        Verifica("lista lunga: «Progetto 13»", e.Pulsante == "Avanti" && e.Voce == "Progetto 13");

        // 7. Errore con icona di errore
        Dopo("w-errore", delegate(Form f) { Clic(f, "OK"); });
        e = Finestre.Mostra("Download di Python non riuscito.\n\nDettagli nella finestra di PowerShell.", null, false,
                            new string[] { "OK" }, null, true);
        Verifica("errore: «OK» restituito", e.Pulsante == "OK");

        Console.WriteLine(fallite == 0 ? "FINESTRE: TUTTE LE VERIFICHE SUPERATE" : "FINESTRE: VERIFICHE FALLITE " + fallite);
        return fallite == 0 ? 0 : 1;
    }
}
