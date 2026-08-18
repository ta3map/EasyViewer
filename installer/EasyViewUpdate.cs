using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Principal;
using System.Windows.Forms;

internal static class Program
{
    const string DefaultDir = @"C:\Program Files\EasyView\application";

    [STAThread]
    static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        string targetDir = DefaultDir;
        bool skipPrompt = args.Length > 0 && args[0] == "/install";
        if (skipPrompt)
        {
            targetDir = args[1];
        }
        if (!skipPrompt)
        {
            targetDir = PickTargetDir();
            if (string.IsNullOrEmpty(targetDir))
            {
                return;
            }

            WindowsPrincipal principal = new WindowsPrincipal(WindowsIdentity.GetCurrent());
            if (!principal.IsInRole(WindowsBuiltInRole.Administrator))
            {
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = Assembly.GetExecutingAssembly().Location;
                psi.Arguments = "/install \"" + targetDir + "\"";
                psi.UseShellExecute = true;
                psi.Verb = "runas";
                Process.Start(psi).WaitForExit();
                return;
            }
        }

        Directory.CreateDirectory(targetDir);
        using (Stream zipStream = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))
        using (ZipArchive archive = new ZipArchive(zipStream, ZipArchiveMode.Read))
        {
            foreach (ZipArchiveEntry entry in archive.Entries)
            {
                string destPath = Path.Combine(targetDir, entry.FullName.Replace('/', Path.DirectorySeparatorChar));
                if (string.IsNullOrEmpty(entry.Name))
                {
                    Directory.CreateDirectory(destPath);
                    continue;
                }
                Directory.CreateDirectory(Path.GetDirectoryName(destPath));
                entry.ExtractToFile(destPath, true);
            }
        }

        MessageBox.Show("EasyView has been updated.", "EasyView", MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    static string PickTargetDir()
    {
        Form form = new Form();
        form.Text = "EasyView Update";
        form.Width = 580;
        form.Height = 170;
        form.FormBorderStyle = FormBorderStyle.FixedDialog;
        form.StartPosition = FormStartPosition.CenterScreen;
        form.MaximizeBox = false;
        form.MinimizeBox = false;

        Label label = new Label();
        label.Text = "Install folder:";
        label.Left = 12;
        label.Top = 15;
        label.Width = 540;

        TextBox box = new TextBox();
        box.Left = 12;
        box.Top = 40;
        box.Width = 430;
        box.Text = DefaultDir;

        Button browse = new Button();
        browse.Text = "Browse...";
        browse.Left = 450;
        browse.Top = 38;
        browse.Width = 100;
        browse.Click += delegate
        {
            FolderBrowserDialog dlg = new FolderBrowserDialog();
            dlg.Description = "Select EasyView application folder";
            dlg.SelectedPath = box.Text;
            dlg.ShowNewFolderButton = true;
            if (dlg.ShowDialog() == DialogResult.OK)
            {
                box.Text = dlg.SelectedPath;
            }
        };

        Button install = new Button();
        install.Text = "Install";
        install.DialogResult = DialogResult.OK;
        install.Left = 350;
        install.Top = 85;
        install.Width = 90;

        Button cancel = new Button();
        cancel.Text = "Cancel";
        cancel.DialogResult = DialogResult.Cancel;
        cancel.Left = 450;
        cancel.Top = 85;
        cancel.Width = 100;

        form.AcceptButton = install;
        form.CancelButton = cancel;
        form.Controls.Add(label);
        form.Controls.Add(box);
        form.Controls.Add(browse);
        form.Controls.Add(install);
        form.Controls.Add(cancel);

        if (form.ShowDialog() != DialogResult.OK)
        {
            return "";
        }
        return box.Text.Trim();
    }
}
