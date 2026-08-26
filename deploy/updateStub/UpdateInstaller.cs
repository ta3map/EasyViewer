using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Principal;
using System.Windows.Forms;
using Microsoft.Win32;

internal static class Program
{
    const string DefaultDir = @"C:\Program Files\EasyView\application";

    [STAThread]
    static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        string targetDir = DefaultDir;
        Version targetVersion = ReadTargetVersion();
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

            Version installedVersion = ReadInstalledVersion(targetDir);
            if (!ConfirmUpdate(installedVersion, targetVersion))
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

        UpdateProgramsAndFeaturesVersion(targetVersion);

        MessageBox.Show("EasyView has been updated to version " + FormatVersion(targetVersion) + ".", "EasyView", MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    static Version ReadTargetVersion()
    {
        using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("UpdateVersion"))
        using (StreamReader reader = new StreamReader(stream))
        {
            return Version.Parse(reader.ReadToEnd().Trim());
        }
    }

    static Version ReadInstalledVersion(string targetDir)
    {
        string exePath = Path.Combine(targetDir, "EasyView.exe");
        if (!File.Exists(exePath))
        {
            return null;
        }

        FileVersionInfo info = FileVersionInfo.GetVersionInfo(exePath);
        string text = info.FileVersion;
        if (string.IsNullOrEmpty(text))
        {
            text = info.ProductVersion;
        }
        if (string.IsNullOrEmpty(text))
        {
            return null;
        }

        text = text.Trim();
        int dash = text.IndexOf('-');
        if (dash >= 0)
        {
            text = text.Substring(0, dash);
        }
        return Version.Parse(text);
    }

    static bool ConfirmUpdate(Version installed, Version target)
    {
        if (installed == null)
        {
            DialogResult answer = MessageBox.Show(
                "EasyView was not found in the selected folder.\n\nInstall version " + FormatVersion(target) + "?",
                "EasyView Update",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question,
                MessageBoxDefaultButton.Button1);
            return answer == DialogResult.Yes;
        }

        int cmp = CompareVersion(installed, target);
        if (cmp == 0)
        {
            DialogResult answer = MessageBox.Show(
                "EasyView version " + FormatVersion(installed) + " is already installed.\n\nUpdate anyway?",
                "EasyView Update",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information,
                MessageBoxDefaultButton.Button2);
            return answer == DialogResult.Yes;
        }

        if (cmp > 0)
        {
            DialogResult answer = MessageBox.Show(
                "You are installing an older version (" + FormatVersion(target) + ") over the current version (" + FormatVersion(installed) + ").\n\nThis is useful if you need to return to a stable release.\n\nContinue?",
                "EasyView Update",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning,
                MessageBoxDefaultButton.Button1);
            return answer == DialogResult.Yes;
        }

        DialogResult upgrade = MessageBox.Show(
            "Update EasyView from version " + FormatVersion(installed) + " to " + FormatVersion(target) + "?",
            "EasyView Update",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question,
            MessageBoxDefaultButton.Button1);
        return upgrade == DialogResult.Yes;
    }

    static int CompareVersion(Version left, Version right)
    {
        int cmp = left.Major.CompareTo(right.Major);
        if (cmp != 0)
        {
            return cmp;
        }
        cmp = left.Minor.CompareTo(right.Minor);
        if (cmp != 0)
        {
            return cmp;
        }
        return left.Build.CompareTo(right.Build);
    }

    static string FormatVersion(Version version)
    {
        return version.Major + "." + version.Minor + "." + version.Build;
    }

    static void UpdateProgramsAndFeaturesVersion(Version version)
    {
        string versionText = FormatVersion(version);
        string[] uninstallRoots = {
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        };

        foreach (string uninstallRoot in uninstallRoots)
        {
            using (RegistryKey rootKey = Registry.LocalMachine.OpenSubKey(uninstallRoot, false))
            {
                if (rootKey == null)
                {
                    continue;
                }

                foreach (string subKeyName in rootKey.GetSubKeyNames())
                {
                    using (RegistryKey subKey = rootKey.OpenSubKey(subKeyName, true))
                    {
                        if (subKey == null)
                        {
                            continue;
                        }

                        string displayName = subKey.GetValue("DisplayName") as string;
                        if (displayName == null)
                        {
                            continue;
                        }

                        if (displayName.IndexOf("EasyView", StringComparison.OrdinalIgnoreCase) < 0)
                        {
                            continue;
                        }

                        subKey.SetValue("DisplayVersion", versionText, RegistryValueKind.String);
                        subKey.SetValue("DisplayName", "EasyView", RegistryValueKind.String);
                    }
                }
            }
        }
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
        label.Text = "Application folder:";
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

        Button update = new Button();
        update.Text = "Update";
        update.DialogResult = DialogResult.OK;
        update.Left = 350;
        update.Top = 85;
        update.Width = 90;

        Button cancel = new Button();
        cancel.Text = "Cancel";
        cancel.DialogResult = DialogResult.Cancel;
        cancel.Left = 450;
        cancel.Top = 85;
        cancel.Width = 100;

        form.AcceptButton = update;
        form.CancelButton = cancel;
        form.Controls.Add(label);
        form.Controls.Add(box);
        form.Controls.Add(browse);
        form.Controls.Add(update);
        form.Controls.Add(cancel);

        if (form.ShowDialog() != DialogResult.OK)
        {
            return "";
        }
        return box.Text.Trim();
    }
}
