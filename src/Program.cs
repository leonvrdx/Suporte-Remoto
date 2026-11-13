using System;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using System.Reflection;
using System.Security.Principal;
using System.Runtime.InteropServices;
using System.Collections.Generic;

namespace SuporteRemoto
{
    static class Program
    {
        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [STAThread]
        static void Main()
        {
            try { SetProcessDPIAware(); } catch { }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Garante protocolos modernos TLS 1.2 e TLS 1.3
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072 | (SecurityProtocolType)12288 | SecurityProtocolType.Tls;

            Application.Run(new MainForm());
        }
    }

    public class MainForm : Form
    {
        private const string WebhookUrl = "https://hook.us2.make.com/yeigsf1oq4t6v0i2ynpmqx2eswuhsbao";

        private RadioButton rbRustDesk;
        private RadioButton rbHopToDesk;
        private TextBox txtPartner;
        private TextBox txtComputer;
        private CheckBox chkOnlineUpdate;
        private Button btnInstall;
        private Button btnCancel;
        private ProgressBar progressBar;
        private Label lblStatus;
        private Panel panelHeader;

        public MainForm()
        {
            InitializeComponent();
        }

        private void InitializeComponent()
        {
            this.Text = "Suporte Remoto - Instalador & Configurador";
            this.Size = new Size(500, 540);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point, ((byte)(0)));
            this.BackColor = Color.FromArgb(248, 249, 250);

            // Header Panel
            panelHeader = new Panel();
            panelHeader.Dock = DockStyle.Top;
            panelHeader.Height = 70;
            panelHeader.BackColor = Color.FromArgb(16, 110, 190);

            Label lblTitle = new Label();
            lblTitle.Text = "Instalação de Suporte Remoto";
            lblTitle.Font = new Font("Segoe UI", 12F, FontStyle.Bold);
            lblTitle.ForeColor = Color.White;
            lblTitle.Location = new Point(20, 12);
            lblTitle.AutoSize = true;

            Label lblSubTitle = new Label();
            lblSubTitle.Text = "Configuração automatizada para atendimento assistido";
            lblSubTitle.Font = new Font("Segoe UI", 8.5F);
            lblSubTitle.ForeColor = Color.FromArgb(220, 235, 252);
            lblSubTitle.Location = new Point(21, 38);
            lblSubTitle.AutoSize = true;

            panelHeader.Controls.Add(lblTitle);
            panelHeader.Controls.Add(lblSubTitle);

            // Group Ferramenta
            GroupBox grpTool = new GroupBox();
            grpTool.Text = " 1. Selecione a Ferramenta ";
            grpTool.Location = new Point(20, 85);
            grpTool.Size = new Size(445, 95);

            rbRustDesk = new RadioButton();
            rbRustDesk.Text = "RustDesk (Recomendado - Mais rápido e estável)";
            rbRustDesk.Location = new Point(16, 25);
            rbRustDesk.Size = new Size(410, 24);
            rbRustDesk.Checked = true;
            rbRustDesk.Font = new Font("Segoe UI", 9F, FontStyle.Bold);

            rbHopToDesk = new RadioButton();
            rbHopToDesk.Text = "HopToDesk (Alternativo Open-Source)";
            rbHopToDesk.Location = new Point(16, 56);
            rbHopToDesk.Size = new Size(410, 24);

            grpTool.Controls.Add(rbRustDesk);
            grpTool.Controls.Add(rbHopToDesk);

            // Group Dados
            GroupBox grpData = new GroupBox();
            grpData.Text = " 2. Identificação do Acesso ";
            grpData.Location = new Point(20, 190);
            grpData.Size = new Size(445, 140);

            Label lblPartner = new Label();
            lblPartner.Text = "Nome do Parceiro / Cliente (ex.: Rango):";
            lblPartner.Location = new Point(16, 25);
            lblPartner.AutoSize = true;

            txtPartner = new TextBox();
            txtPartner.Location = new Point(16, 45);
            txtPartner.Size = new Size(410, 23);

            Label lblComputer = new Label();
            lblComputer.Text = "Identificação do Computador:";
            lblComputer.Location = new Point(16, 78);
            lblComputer.AutoSize = true;

            txtComputer = new TextBox();
            txtComputer.Location = new Point(16, 98);
            txtComputer.Size = new Size(410, 23);
            txtComputer.Text = Environment.MachineName;

            grpData.Controls.Add(lblPartner);
            grpData.Controls.Add(txtPartner);
            grpData.Controls.Add(lblComputer);
            grpData.Controls.Add(txtComputer);

            // Group Opções
            GroupBox grpOptions = new GroupBox();
            grpOptions.Text = " 3. Opções de Download ";
            grpOptions.Location = new Point(20, 340);
            grpOptions.Size = new Size(445, 60);

            chkOnlineUpdate = new CheckBox();
            chkOnlineUpdate.Text = "Tentar baixar versão mais recente da internet (Opcional)";
            chkOnlineUpdate.Location = new Point(16, 22);
            chkOnlineUpdate.Size = new Size(410, 24);
            chkOnlineUpdate.Checked = false; // Por padrão falso: usa pacote offline embutido

            grpOptions.Controls.Add(chkOnlineUpdate);

            // Progress & Status
            lblStatus = new Label();
            lblStatus.Text = "Pronto para iniciar.";
            lblStatus.Location = new Point(20, 410);
            lblStatus.Size = new Size(445, 20);
            lblStatus.ForeColor = Color.FromArgb(70, 70, 70);

            progressBar = new ProgressBar();
            progressBar.Location = new Point(20, 432);
            progressBar.Size = new Size(445, 18);
            progressBar.Style = ProgressBarStyle.Continuous;
            progressBar.Visible = false;

            // Buttons
            btnInstall = new Button();
            btnInstall.Text = "Instalar e Configurar";
            btnInstall.Location = new Point(235, 460);
            btnInstall.Size = new Size(140, 32);
            btnInstall.BackColor = Color.FromArgb(16, 110, 190);
            btnInstall.ForeColor = Color.White;
            btnInstall.FlatStyle = FlatStyle.Flat;
            btnInstall.FlatAppearance.BorderSize = 0;
            btnInstall.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            btnInstall.Click += BtnInstall_Click;

            btnCancel = new Button();
            btnCancel.Text = "Cancelar";
            btnCancel.Location = new Point(385, 460);
            btnCancel.Size = new Size(80, 32);
            btnCancel.Click += (s, e) => { this.Close(); };

            this.Controls.Add(panelHeader);
            this.Controls.Add(grpTool);
            this.Controls.Add(grpData);
            this.Controls.Add(grpOptions);
            this.Controls.Add(lblStatus);
            this.Controls.Add(progressBar);
            this.Controls.Add(btnInstall);
            this.Controls.Add(btnCancel);
        }

        private void SetStatus(string text, bool isMarquee = true)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => SetStatus(text, isMarquee)));
                return;
            }
            lblStatus.Text = text;
            if (isMarquee)
            {
                progressBar.Visible = true;
                progressBar.Style = ProgressBarStyle.Marquee;
            }
        }

        private void BtnInstall_Click(object sender, EventArgs e)
        {
            string partner = txtPartner.Text.Trim();
            if (string.IsNullOrEmpty(partner))
            {
                MessageBox.Show(this, "Informe o nome do parceiro antes de prosseguir.", "Campo Obrigatório", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                txtPartner.Focus();
                return;
            }

            string computer = txtComputer.Text.Trim();
            if (string.IsNullOrEmpty(computer))
            {
                MessageBox.Show(this, "Informe a identificação do computador.", "Campo Obrigatório", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                txtComputer.Focus();
                return;
            }

            DialogResult confirm = MessageBox.Show(this, 
                string.Format("Instalar o suporte remoto para {0} ({1})?\n\nO suporte será configurado com uma senha permanente gerada automaticamente.", partner, computer),
                "Confirmar Instalação",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);

            if (confirm != DialogResult.Yes) return;

            // Bloqueia a UI para evitar cliques duplicados
            btnInstall.Enabled = false;
            btnCancel.Enabled = false;
            txtPartner.Enabled = false;
            txtComputer.Enabled = false;
            rbRustDesk.Enabled = false;
            rbHopToDesk.Enabled = false;
            chkOnlineUpdate.Enabled = false;

            bool isRustDesk = rbRustDesk.Checked;
            bool tryOnline = chkOnlineUpdate.Checked;

            Thread worker = new Thread(() =>
            {
                try
                {
                    ExecuteInstallation(isRustDesk, partner, computer, tryOnline);
                }
                catch (Exception ex)
                {
                    this.Invoke(new Action(() =>
                    {
                        MessageBox.Show(this, "Instalação interrompida: " + ex.Message, "Erro na Instalação", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        btnInstall.Enabled = true;
                        btnCancel.Enabled = true;
                        txtPartner.Enabled = true;
                        txtComputer.Enabled = true;
                        rbRustDesk.Enabled = true;
                        rbHopToDesk.Enabled = true;
                        chkOnlineUpdate.Enabled = true;
                        progressBar.Visible = false;
                        lblStatus.Text = "Erro durante o processo.";
                    }));
                }
            });
            worker.IsBackground = true;
            worker.Start();
        }

        private void ExecuteInstallation(bool isRustDesk, string partner, string computer, bool tryOnline)
        {
            string toolName = isRustDesk ? "RustDesk" : "HopToDesk";
            string serviceName = isRustDesk ? "RustDesk" : "HopToDesk";
            string resourceName = isRustDesk ? "RustDeskInstaller" : "HopToDeskInstaller";

            string tempDir = Path.Combine(Path.GetTempPath(), "SuporteRemoto-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempDir);
            string installerPath = Path.Combine(tempDir, toolName + ".exe");

            bool installerAcquired = false;

            // 1. Se o usuário marcou para tentar baixar da internet, tenta download online com fallbacks
            if (tryOnline)
            {
                SetStatus(string.Format("Buscando instalador atualizado do {0} na internet...", toolName));
                List<string> downloadUrls = new List<string>();

                if (isRustDesk)
                {
                    try
                    {
                        HttpWebRequest apiReq = (HttpWebRequest)WebRequest.Create("https://api.github.com/repos/rustdesk/rustdesk/releases/latest");
                        apiReq.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
                        apiReq.Accept = "application/vnd.github+json";
                        apiReq.Timeout = 10000;
                        using (HttpWebResponse apiRes = (HttpWebResponse)apiReq.GetResponse())
                        using (StreamReader reader = new StreamReader(apiRes.GetResponseStream()))
                        {
                            string json = reader.ReadToEnd();
                            Match m = Regex.Match(json, "\"browser_download_url\":\\s*\"([^\"]+x86_64\\.exe)\"", RegexOptions.IgnoreCase);
                            if (m.Success)
                            {
                                downloadUrls.Add(m.Groups[1].Value);
                            }
                        }
                    }
                    catch { }

                    downloadUrls.Add("https://github.com/rustdesk/rustdesk/releases/download/1.5.3/rustdesk-1.5.3-x86_64.exe");
                }
                else
                {
                    downloadUrls.Add("https://dl.hoptodesk.com/HopToDesk64.exe");
                    downloadUrls.Add("https://dl.hoptodesk.com/HopToDesk.exe");
                    downloadUrls.Add("https://download.hoptodesk.com/HopToDesk.exe");
                }

                foreach (string url in downloadUrls)
                {
                    try
                    {
                        SetStatus(string.Format("Baixando {0}...", toolName));
                        HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url);
                        req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
                        req.Timeout = 25000;
                        using (HttpWebResponse res = (HttpWebResponse)req.GetResponse())
                        using (Stream sIn = res.GetResponseStream())
                        using (FileStream sOut = new FileStream(installerPath, FileMode.Create, FileAccess.Write))
                        {
                            byte[] buf = new byte[65536];
                            int read;
                            while ((read = sIn.Read(buf, 0, buf.Length)) > 0)
                            {
                                sOut.Write(buf, 0, read);
                            }
                        }

                        if (File.Exists(installerPath) && new FileInfo(installerPath).Length > 1024 * 1024)
                        {
                            installerAcquired = true;
                            break;
                        }
                    }
                    catch { }
                }
            }

            // 2. Se não marcou ou se o download online falhou, usa o pacote offline embutido garantido!
            if (!installerAcquired)
            {
                SetStatus(string.Format("Extraindo pacote oficial embutido do {0} (Modo Offline)...", toolName));
                using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName))
                {
                    if (stream == null)
                    {
                        throw new Exception(string.Format("Recurso de instalador embutido '{0}' não foi encontrado no executável.", resourceName));
                    }
                    using (FileStream fs = new FileStream(installerPath, FileMode.Create, FileAccess.Write))
                    {
                        stream.CopyTo(fs);
                    }
                }
            }

            // 3. Execução da instalação silenciosa única
            SetStatus(string.Format("Instalando {0}... Aguarde alguns instantes.", toolName));
            ProcessStartInfo psiInstall = new ProcessStartInfo
            {
                FileName = installerPath,
                Arguments = "--silent-install",
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using (Process proc = Process.Start(psiInstall))
            {
                if (!proc.WaitForExit(90000))
                {
                    try { proc.Kill(); } catch { }
                    throw new Exception("A instalação demorou mais tempo do que o esperado.");
                }
            }

            Thread.Sleep(3000);

            // 4. Localização do executável instalado (suporta 64-bit e 32-bit em Program Files e Program Files (x86))
            SetStatus("Verificando arquivos instalados...");
            string installedExe = FindInstalledExecutable(toolName);
            DateTime deadline = DateTime.UtcNow.AddSeconds(45);
            while (string.IsNullOrEmpty(installedExe) && DateTime.UtcNow < deadline)
            {
                Thread.Sleep(2000);
                installedExe = FindInstalledExecutable(toolName);
            }

            if (string.IsNullOrEmpty(installedExe))
            {
                throw new Exception(string.Format("O executável do {0} não foi localizado nos diretórios padrão de instalação.", toolName));
            }

            // 5. Inicia o serviço do Windows
            SetStatus("Iniciando serviço de suporte...");
            try
            {
                RunCommandLine("sc.exe", string.Format("config \"{0}\" start= auto", serviceName), 5);
                RunCommandLine("sc.exe", string.Format("start \"{0}\"", serviceName), 5);
            }
            catch { }

            // 6. Obtenção do ID de Suporte
            SetStatus("Conectando à rede para gerar o ID de suporte...");
            string remoteId = "";
            int maxAttempts = 3;

            for (int attempt = 1; attempt <= maxAttempts; attempt++)
            {
                if (attempt > 1)
                {
                    try
                    {
                        RunCommandLine("sc.exe", string.Format("stop \"{0}\"", serviceName), 5);
                        Thread.Sleep(1500);
                        RunCommandLine("sc.exe", string.Format("start \"{0}\"", serviceName), 5);
                    }
                    catch { }
                    Thread.Sleep(3000);
                }

                DateTime idDeadline = DateTime.UtcNow.AddSeconds(35);
                while (DateTime.UtcNow < idDeadline)
                {
                    try
                    {
                        string idOutput = RunAppCommand(installedExe, "--get-id", 6);
                        Match match = Regex.Match(idOutput, @"\b\d{6,15}\b");
                        if (match.Success && !Regex.IsMatch(match.Value, "^0+$"))
                        {
                            remoteId = match.Value;
                            break;
                        }
                    }
                    catch { }
                    Thread.Sleep(2000);
                }

                if (!string.IsNullOrEmpty(remoteId)) break;

                if (attempt < maxAttempts)
                {
                    DialogResult ans = DialogResult.None;
                    this.Invoke(new Action(() =>
                    {
                        ans = MessageBox.Show(this,
                            string.Format("O {0} está sincronizando com a rede para obter o ID.\n\nClique em OK para continuar aguardando a sincronização.", toolName),
                            "Sincronizando...",
                            MessageBoxButtons.OKCancel,
                            MessageBoxIcon.Information);
                    }));
                    if (ans == DialogResult.Cancel) break;
                }
            }

            // Tratamento caso a rede do cliente não retorne o ID
            string desktopDir = GetUserDesktopDirectory();
            string safePartner = Regex.Replace(partner, @"[\\/:*?""<>|]", "").Trim();
            if (string.IsNullOrEmpty(safePartner)) safePartner = "Parceiro";
            string outputTxt = Path.Combine(desktopDir, string.Format("{0} Dados - {1}.txt", toolName, safePartner));

            if (string.IsNullOrEmpty(remoteId))
            {
                string errorRecord = string.Format("ACESSO REMOTO - {0}\r\n\r\nParceiro: {1}\r\nComputador: {2}\r\nSTATUS: INSTALACAO CONCLUIDA, MAS A REDE DEMOROU PARA GERAR O ID.\r\n\r\nAbra o {0} manualmente para consultar o ID.", toolName, partner, computer);
                File.WriteAllText(outputTxt, errorRecord, Encoding.UTF8);
                Process.Start("notepad.exe", "\"" + outputTxt + "\"");
                try { Directory.Delete(tempDir, true); } catch { }
                throw new Exception("Falha ao sincronizar o ID pela rede. O aplicativo foi instalado; abra-o na área de trabalho para consultar o ID.");
            }

            // 7. Geração e Configuração de Senha Permanente
            SetStatus("Configurando senha permanente...");
            string password = GenerateRandomPassword();

            // Configura opções para aceitar senha permanente
            try
            {
                RunAppCommand(installedExe, "--option verification-method both", 5);
                RunAppCommand(installedExe, "--option allow-remote-config-modification Y", 5);
                RunAppCommand(installedExe, "--password " + password, 5);
            }
            catch { }

            // Reforço direto nos arquivos de configuração do RustDesk
            if (isRustDesk)
            {
                ConfigureRustDeskSecurity(password);
            }

            string configuredAt = DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss zzz");
            string fullRecord = string.Format("ACESSO REMOTO - {0}\r\n\r\nParceiro: {1}\r\nComputador: {2}\r\nNome no Windows: {3}\r\nID: {4}\r\nSenha permanente: {5}\r\nConfigurado em: {6}\r\n",
                toolName, partner, computer, Environment.MachineName, remoteId, password, configuredAt);

            // 8. Salva arquivo TXT imediatamente na Área de Trabalho
            File.WriteAllText(outputTxt, fullRecord, Encoding.UTF8);

            // 9. Envio do Webhook de forma totalmente assíncrona (Fire-and-Forget: não trava nem espera resposta)
            SendWebhookAsync(toolName, partner, computer, remoteId, password, fullRecord);

            // 10. Cópia para Clipboard e Finalização Imediata
            this.Invoke(new Action(() =>
            {
                try { Clipboard.SetText(fullRecord); } catch { }
                Process.Start("notepad.exe", "\"" + outputTxt + "\"");

                MessageBox.Show(this,
                    "Configuração concluída com sucesso!\n\nOs dados de acesso foram salvos na sua Área de Trabalho e copiados para a Área de Transferência.",
                    "Suporte Remoto Configurado",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);

                try { Directory.Delete(tempDir, true); } catch { }
                Application.Exit();
            }));
        }

        private static string FindInstalledExecutable(string toolName)
        {
            List<string> paths = new List<string>();
            string pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            string pfw64 = Environment.GetEnvironmentVariable("ProgramW6432");

            paths.Add(Path.Combine(pf, toolName, toolName + ".exe"));
            paths.Add(Path.Combine(pf, toolName, toolName.ToLower() + ".exe"));
            if (!string.IsNullOrEmpty(pf86))
            {
                paths.Add(Path.Combine(pf86, toolName, toolName + ".exe"));
                paths.Add(Path.Combine(pf86, toolName, toolName.ToLower() + ".exe"));
            }
            if (!string.IsNullOrEmpty(pfw64))
            {
                paths.Add(Path.Combine(pfw64, toolName, toolName + ".exe"));
                paths.Add(Path.Combine(pfw64, toolName, toolName.ToLower() + ".exe"));
            }

            // Checa caminho do serviço no Registro
            try
            {
                using (var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\" + toolName))
                {
                    if (key != null)
                    {
                        object val = key.GetValue("ImagePath");
                        if (val != null)
                        {
                            string img = val.ToString().Trim();
                            if (img.StartsWith("\""))
                            {
                                int idx = img.IndexOf('"', 1);
                                if (idx > 1) img = img.Substring(1, idx - 1);
                            }
                            if (File.Exists(img)) return img;
                        }
                    }
                }
            }
            catch { }

            foreach (string p in paths)
            {
                if (File.Exists(p)) return p;
            }
            return null;
        }

        private static string RunAppCommand(string exePath, string args, int timeoutSec)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = exePath,
                    Arguments = args,
                    WorkingDirectory = Path.GetDirectoryName(exePath),
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };

                using (Process p = new Process())
                {
                    p.StartInfo = psi;
                    StringBuilder output = new StringBuilder();

                    p.OutputDataReceived += (s, e) => { if (e.Data != null) output.AppendLine(e.Data); };
                    p.ErrorDataReceived += (s, e) => { if (e.Data != null) output.AppendLine(e.Data); };

                    p.Start();
                    p.BeginOutputReadLine();
                    p.BeginErrorReadLine();

                    if (!p.WaitForExit(timeoutSec * 1000))
                    {
                        try { p.Kill(); } catch { }
                    }
                    return output.ToString();
                }
            }
            catch
            {
                return "";
            }
        }

        private static void RunCommandLine(string fileName, string args, int timeoutSec)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = fileName,
                    Arguments = args,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };
                using (Process p = Process.Start(psi))
                {
                    if (!p.WaitForExit(timeoutSec * 1000))
                    {
                        try { p.Kill(); } catch { }
                    }
                }
            }
            catch { }
        }

        private static string GenerateRandomPassword()
        {
            // Caracteres alfanuméricos inequívocos (sem caracteres especiais que quebrem comandos e sem 0/O/1/l)
            const string chars = "23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";
            Random rnd = new Random();
            char[] pass = new char[10];
            for (int i = 0; i < pass.Length; i++)
            {
                pass[i] = chars[rnd.Next(chars.Length)];
            }
            return new string(pass);
        }

        private static void ConfigureRustDeskSecurity(string password)
        {
            List<string> configDirs = new List<string>();
            configDirs.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "RustDesk", "config"));

            string winDir = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            configDirs.Add(Path.Combine(winDir, "ServiceProfiles", "LocalService", "AppData", "Roaming", "RustDesk", "config"));
            configDirs.Add(Path.Combine(winDir, "System32", "config", "systemprofile", "AppData", "Roaming", "RustDesk", "config"));

            foreach (string dir in configDirs)
            {
                try
                {
                    if (!Directory.Exists(dir)) continue;

                    string toml2 = Path.Combine(dir, "RustDesk2.toml");
                    if (File.Exists(toml2))
                    {
                        string content = File.ReadAllText(toml2, Encoding.UTF8);

                        if (content.Contains("verification-method"))
                        {
                            content = Regex.Replace(content, @"verification-method\s*=\s*'[^']*'", "verification-method = 'both'");
                        }
                        else if (content.Contains("[options]"))
                        {
                            content = content.Replace("[options]", "[options]\r\nverification-method = 'both'");
                        }
                        else
                        {
                            content += "\r\n[options]\r\nverification-method = 'both'\r\n";
                        }

                        content = Regex.Replace(content, @"stop-service\s*=\s*'Y'", "stop-service = ''");
                        File.WriteAllText(toml2, content, Encoding.UTF8);
                    }
                }
                catch { }
            }
        }

        private static string GetUserDesktopDirectory()
        {
            string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            if (!string.IsNullOrEmpty(desktop) && Directory.Exists(desktop)) return desktop;

            string pub = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);
            if (!string.IsNullOrEmpty(pub) && Directory.Exists(pub)) return pub;

            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Desktop");
        }

        private static void SendWebhookAsync(string tool, string partner, string computer, string id, string pass, string fullText)
        {
            // Executado em threadpool desacoplada: nunca atrasa o instalador e nunca trava se a rede demorar
            ThreadPool.QueueUserWorkItem(_ =>
            {
                try
                {
                    HttpWebRequest req = (HttpWebRequest)WebRequest.Create(WebhookUrl);
                    req.Method = "POST";
                    req.ContentType = "application/json";
                    req.Timeout = 5000;
                    req.ReadWriteTimeout = 5000;

                    string json = string.Format("{{\"ferramenta\":\"{0}\",\"aplicativo\":\"{0}\",\"app\":\"{0}\",\"parceiro\":\"{1}\",\"computador\":\"{2}\",\"id\":\"{3}\",\"senha\":\"{4}\",\"textoCompleto\":\"{5}\"}}",
                        EscapeJson(tool),
                        EscapeJson(partner),
                        EscapeJson(computer),
                        EscapeJson(id),
                        EscapeJson(pass),
                        EscapeJson(fullText));

                    byte[] data = Encoding.UTF8.GetBytes(json);
                    req.ContentLength = data.Length;
                    using (Stream stream = req.GetRequestStream())
                    {
                        stream.Write(data, 0, data.Length);
                    }
                    using (WebResponse resp = req.GetResponse()) { }
                }
                catch { }
            });
        }

        private static string EscapeJson(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            return s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n").Replace("\t", "\\t");
        }
    }
}
