// Finestre.cs - finestre di dialogo di Trascrivi Audio per Windows (Windows Forms).
//
// Caricato da TrascriviAudio.ps1 con Add-Type. Windows PowerShell 5.1 compila con C# 5:
// niente sintassi piu' recente ($"...", =>, ?.). Il file contiene solo caratteri ASCII:
// i testi in italiano arrivano da PowerShell.

using System;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class Finestre
{
    public static string Titolo = "Trascrivi Audio";
    public static string Icona = null;   // file .ico dell'app

    static float scala = 1f;             // DPI dello schermo / 96

    [DllImport("user32.dll")]
    static extern bool SetProcessDPIAware();

    public class Esito
    {
        public string Pulsante;   // pulsante premuto; null se annullato o finestra chiusa
        public string Voce;       // voce scelta nella lista
        public string Testo;      // testo scritto nel campo
    }

    // Da chiamare una volta prima di mostrare le finestre: testo nitido sugli schermi ad alta risoluzione
    public static void Prepara()
    {
        try { SetProcessDPIAware(); } catch (Exception) { }
        try { Application.EnableVisualStyles(); } catch (Exception) { }
        try
        {
            using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) { scala = g.DpiX / 96f; }
        }
        catch (Exception) { scala = 1f; }
        if (scala < 1f) scala = 1f;
    }

    static int S(int px) { return (int)Math.Round(px * scala); }

    // Finestra generica: testo, eventuale lista di scelte (pulsanti di opzione), eventuale campo
    // di testo e pulsanti in basso a destra (l'ultimo e' quello principale, attivato da Invio).
    public static Esito Mostra(string testo, string[] voci, bool conCampo, string[] pulsanti,
                               string annulla, bool errore)
    {
        Form f = new Form();
        f.Text = Titolo;
        f.Font = new Font("Segoe UI", 10f);
        f.BackColor = Color.White;
        f.FormBorderStyle = FormBorderStyle.FixedDialog;
        f.MaximizeBox = false;
        f.MinimizeBox = false;
        f.StartPosition = FormStartPosition.CenterScreen;
        f.TopMost = true;
        f.AutoScaleMode = AutoScaleMode.None;
        f.AutoSize = true;
        f.AutoSizeMode = AutoSizeMode.GrowAndShrink;
        f.Padding = new Padding(S(20), S(18), S(20), S(16));
        if (Icona != null && File.Exists(Icona))
        {
            try { f.Icon = new Icon(Icona); } catch (Exception) { }
        }

        TableLayoutPanel griglia = new TableLayoutPanel();
        griglia.AutoSize = true;
        griglia.AutoSizeMode = AutoSizeMode.GrowAndShrink;
        griglia.ColumnCount = 2;
        griglia.RowCount = 2;
        griglia.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        griglia.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        griglia.Margin = new Padding(0);

        // Icona a sinistra: quella dell'app, o quella di errore
        PictureBox immagine = new PictureBox();
        immagine.Size = new Size(S(48), S(48));
        immagine.SizeMode = PictureBoxSizeMode.Zoom;
        immagine.Margin = new Padding(0, 0, S(16), 0);
        try
        {
            if (errore) immagine.Image = SystemIcons.Error.ToBitmap();
            else if (Icona != null && File.Exists(Icona)) immagine.Image = new Icon(Icona, S(48), S(48)).ToBitmap();
        }
        catch (Exception) { }
        griglia.Controls.Add(immagine, 0, 0);

        FlowLayoutPanel contenuto = new FlowLayoutPanel();
        contenuto.FlowDirection = FlowDirection.TopDown;
        contenuto.WrapContents = false;
        contenuto.AutoSize = true;
        contenuto.AutoSizeMode = AutoSizeMode.GrowAndShrink;
        contenuto.Margin = new Padding(0);

        Label etichetta = new Label();
        etichetta.Text = testo;
        etichetta.AutoSize = true;
        etichetta.MaximumSize = new Size(S(520), 0);
        etichetta.Margin = new Padding(0, S(2), 0, S(10));
        contenuto.Controls.Add(etichetta);

        // Scelte: pulsanti di opzione; con molte voci, una lista che scorre
        RadioButton[] opzioni = new RadioButton[0];
        ListBox lista = null;
        int quante = voci == null ? 0 : voci.Length;
        if (quante > 10)
        {
            lista = new ListBox();
            lista.Items.AddRange(voci);
            lista.SelectedIndex = 0;
            lista.IntegralHeight = true;
            lista.Width = S(420);
            lista.Height = S(260);
            lista.Margin = new Padding(0, 0, 0, S(4));
            contenuto.Controls.Add(lista);
        }
        else if (quante > 0)
        {
            opzioni = new RadioButton[quante];
            for (int i = 0; i < quante; i++)
            {
                RadioButton r = new RadioButton();
                r.Text = voci[i];
                r.AutoSize = true;
                r.Margin = new Padding(S(6), S(3), 0, S(3));
                r.Checked = (i == 0);
                contenuto.Controls.Add(r);
                opzioni[i] = r;
            }
        }

        TextBox campo = null;
        if (conCampo)
        {
            campo = new TextBox();
            campo.Width = S(420);
            campo.Margin = new Padding(0, 0, 0, S(4));
            contenuto.Controls.Add(campo);
        }
        griglia.Controls.Add(contenuto, 1, 0);

        // Pulsanti in basso a destra (aggiunti da destra verso sinistra)
        FlowLayoutPanel barra = new FlowLayoutPanel();
        barra.FlowDirection = FlowDirection.RightToLeft;
        barra.WrapContents = false;
        barra.AutoSize = true;
        barra.AutoSizeMode = AutoSizeMode.GrowAndShrink;
        barra.Dock = DockStyle.Fill;
        barra.Margin = new Padding(0, S(18), 0, 0);
        for (int i = pulsanti.Length - 1; i >= 0; i--)
        {
            Button b = new Button();
            b.Text = pulsanti[i];
            b.AutoSize = true;
            b.AutoSizeMode = AutoSizeMode.GrowAndShrink;
            b.MinimumSize = new Size(S(96), S(32));
            b.Padding = new Padding(S(10), 0, S(10), 0);
            b.Margin = new Padding(S(8), 0, 0, 0);
            b.Click += delegate(object mittente, EventArgs e)
            {
                f.Tag = ((Button)mittente).Text;
                f.Close();
            };
            if (i == pulsanti.Length - 1) f.AcceptButton = b;
            if (annulla != null && pulsanti[i] == annulla) f.CancelButton = b;
            barra.Controls.Add(b);
        }
        griglia.Controls.Add(barra, 0, 1);
        griglia.SetColumnSpan(barra, 2);
        f.Controls.Add(griglia);

        f.Shown += delegate(object mittente, EventArgs e)
        {
            f.Activate();
            if (campo != null) campo.Focus();
        };
        f.ShowDialog();

        Esito esito = new Esito();
        esito.Pulsante = f.Tag as string;
        if (esito.Pulsante != null && annulla != null && esito.Pulsante == annulla) esito.Pulsante = null;
        foreach (RadioButton r in opzioni)
        {
            if (r.Checked) esito.Voce = r.Text;
        }
        if (lista != null && lista.SelectedItem != null) esito.Voce = lista.SelectedItem.ToString();
        if (campo != null) esito.Testo = campo.Text;
        f.Dispose();
        return esito;
    }

    // Finestra standard di Windows per scegliere un file; parte dalla cartella Download
    public static string ScegliFile(string titolo, string filtro)
    {
        Form proprietario = new Form();
        proprietario.TopMost = true;
        proprietario.ShowInTaskbar = false;
        proprietario.FormBorderStyle = FormBorderStyle.None;
        proprietario.StartPosition = FormStartPosition.CenterScreen;
        proprietario.Size = new Size(1, 1);
        proprietario.Opacity = 0;
        proprietario.Show();
        string scelto = null;
        using (OpenFileDialog d = new OpenFileDialog())
        {
            d.Title = titolo;
            d.Filter = filtro;
            d.Multiselect = false;
            d.CheckFileExists = true;
            string scaricati = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
            if (Directory.Exists(scaricati)) d.InitialDirectory = scaricati;
            if (d.ShowDialog(proprietario) == DialogResult.OK) scelto = d.FileName;
        }
        proprietario.Close();
        proprietario.Dispose();
        return scelto;
    }
}
