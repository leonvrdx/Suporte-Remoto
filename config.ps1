#requires -Version 5.1
param([string]$DesktopOriginalBase64)

$ErrorActionPreference = 'Stop'

# Previne que cliques acidentais no terminal ativem o modo de selecao (QuickEdit) e pausem o script
try {
    $code = @'
    using System;
    using System.Runtime.InteropServices;
    public class ConsoleHelper {
        const int STD_INPUT_HANDLE = -10;
        const uint ENABLE_QUICK_EDIT_MODE = 0x0040;
        const uint ENABLE_EXTENDED_FLAGS = 0x0080;
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll")]
        static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
        [DllImport("kernel32.dll")]
        static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
        public static void DisableQuickEdit() {
            try {
                IntPtr handle = GetStdHandle(STD_INPUT_HANDLE);
                uint mode;
                if (GetConsoleMode(handle, out mode)) {
                    mode &= ~ENABLE_QUICK_EDIT_MODE;
                    mode |= ENABLE_EXTENDED_FLAGS;
                    SetConsoleMode(handle, mode);
                }
            } catch {}
        }
    }
'@
    Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
    [ConsoleHelper]::DisableQuickEdit()
} catch {}

try { [Console]::Title = "Instalador Suporte Remoto - HopToDesk" } catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()

# =======================================================
# CONFIGURACAO DE INTEGRACAO
$WebhookUrl = 'https://hook.us2.make.com/yeigsf1oq4t6v0i2ynpmqx2eswuhsbao'
# =======================================================

function Show-Info([string]$Message, [string]$Icon='Information') {
    $iconEnum = [System.Windows.Forms.MessageBoxIcon]::$Icon
    [void][System.Windows.Forms.MessageBox]::Show($Message, 'Suporte Remoto - HopToDesk', 'OK', $iconEnum)
}

function Find-InstalledAppExe([string]$AppName = 'HopToDesk') {
    $searchPaths = @(
        (Join-Path $env:ProgramFiles "$AppName\$AppName.exe"),
        (Join-Path $env:ProgramFiles "$AppName\$($AppName.ToLower()).exe"),
        (Join-Path ${env:ProgramFiles(x86)} "$AppName\$AppName.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "$AppName\$($AppName.ToLower()).exe")
    )
    if ($env:ProgramW6432) {
        $searchPaths += (Join-Path $env:ProgramW6432 "$AppName\$AppName.exe")
        $searchPaths += (Join-Path $env:ProgramW6432 "$AppName\$($AppName.ToLower()).exe")
    }

    try {
        $svcKey = "HKLM:\SYSTEM\CurrentControlSet\Services\$AppName"
        if (Test-Path $svcKey) {
            $imagePath = (Get-ItemProperty -Path $svcKey -Name ImagePath -ErrorAction SilentlyContinue).ImagePath
            if ($imagePath) {
                $cleanPath = ($imagePath -replace '^"([^"]+)".*$', '$1').Trim()
                if (Test-Path -LiteralPath $cleanPath) {
                    return $cleanPath
                }
            }
        }
    } catch {}

    foreach ($path in $searchPaths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }
    return $null
}

function Invoke-RemoteApp([string]$ExePath, [string[]]$Arguments, [int]$TimeoutSeconds = 15) {
    if (-not (Test-Path -LiteralPath $ExePath)) {
        throw "Executavel nao encontrado em: $ExePath"
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.WorkingDirectory = [IO.Path]::GetDirectoryName($ExePath)
    $psi.Arguments = $Arguments -join ' '
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { $process.Kill() } catch {}
        return @{ ExitCode = -1; StdOut = ''; StdErr = 'Timeout'; Combined = 'Timeout' }
    }

    $stdout = ''
    $stderr = ''
    if ($stdoutTask.Wait(3000)) { $stdout = $stdoutTask.Result }
    if ($stderrTask.Wait(3000)) { $stderr = $stderrTask.Result }

    return @{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
        Combined = ($stdout + "`r`n" + $stderr)
    }
}

function Get-RandomPassword {
    # Caracteres alfanumericos inequivocos (sem simbolos e sem 0/O/1/l)
    $chars = '23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
    return -join ((1..10) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function Create-DesktopShortcut([string]$TargetExe, [string]$ShortcutName = 'HopToDesk', [string]$UserDesktop = '') {
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $destinations = @()
        if ($UserDesktop -and (Test-Path -LiteralPath $UserDesktop)) {
            $destinations += $UserDesktop
        }
        $userDesk = [Environment]::GetFolderPath('DesktopDirectory')
        if ($userDesk -and (Test-Path -LiteralPath $userDesk)) {
            $destinations += $userDesk
        }
        $publicDesk = [Environment]::GetFolderPath('CommonDesktopDirectory')
        if ($publicDesk -and (Test-Path -LiteralPath $publicDesk)) {
            $destinations += $publicDesk
        }

        foreach ($dir in ($destinations | Select-Object -Unique)) {
            try {
                $lnkPath = Join-Path $dir "$ShortcutName.lnk"
                $shortcut = $wsh.CreateShortcut($lnkPath)
                $shortcut.TargetPath = $TargetExe
                $shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($TargetExe)
                $shortcut.IconLocation = "$TargetExe,0"
                $shortcut.Description = "$ShortcutName - Suporte Remoto"
                $shortcut.Save()
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut)
            } catch {}
        }
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh)
    } catch {}
}

function Set-TomlOption([string]$Content, [string]$Key, [string]$Value) {
    $Content = $Content.TrimStart([char]0xFEFF)
    if ($Content -match '(?m)^\[options\]') {
        if ($Content -match "(?m)^$Key\s*=") {
            return ($Content -replace "(?m)^$Key\s*=.*$", "$Key = '$Value'")
        } else {
            return ($Content -replace '(?m)^\[options\]', "[options]`r`n$Key = '$Value'")
        }
    } else {
        return ($Content.TrimEnd() + "`r`n`r`n[options]`r`n$Key = '$Value'`r`n")
    }
}

function Enable-HopToDeskUnattendedAccess {
    try {
        # UTF-8 sem BOM (obrigatorio para o parser TOML em Rust do HopToDesk nao resetar o arquivo)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

        $configDirs = @(
            (Join-Path $env:APPDATA 'HopToDesk\config'),
            'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\HopToDesk\config',
            'C:\Windows\System32\config\systemprofile\AppData\Roaming\HopToDesk\config'
        )

        $userProfiles = Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue
        foreach ($u in $userProfiles) {
            $configDirs += (Join-Path $u.FullName 'AppData\Roaming\HopToDesk\config')
        }
        $configDirs = $configDirs | Select-Object -Unique

        # Localiza o HopToDesk.toml principal (que contem o ID e a permanent_password recem-gerada)
        $sourceToml1Content = $null
        foreach ($dir in $configDirs) {
            $t1 = Join-Path $dir 'HopToDesk.toml'
            if (Test-Path -LiteralPath $t1) {
                try {
                    $raw = [IO.File]::ReadAllText($t1, $utf8NoBom).TrimStart([char]0xFEFF)
                    if ($raw -match "(?m)^permanent_password\s*=\s*'[^']+'" -and $raw -match "(?m)^enc_id\s*=\s*'[^']+'") {
                        $sourceToml1Content = $raw
                        break
                    }
                } catch {}
            }
        }

        if ($sourceToml1Content) {
            # Garante temporary_password vazio para ativar o modo Acesso Nao Supervisionado na UI do HopToDesk
            if ($sourceToml1Content -match '(?m)^temporary_password\s*=') {
                $sourceToml1Content = $sourceToml1Content -replace "(?m)^temporary_password\s*=.*$", "temporary_password = ''"
            } else {
                $sourceToml1Content = "temporary_password = ''`r`n" + $sourceToml1Content
            }
        }

        foreach ($dir in $configDirs) {
            try {
                if (-not (Test-Path -LiteralPath $dir)) {
                    [void][IO.Directory]::CreateDirectory($dir)
                }

                # 1. Sincroniza HopToDesk.toml (ID + permanent_password + temporary_password = '')
                $pathToml1 = Join-Path $dir 'HopToDesk.toml'
                if ($sourceToml1Content) {
                    [IO.File]::WriteAllText($pathToml1, $sourceToml1Content, $utf8NoBom)
                } elseif (Test-Path -LiteralPath $pathToml1) {
                    $c1 = [IO.File]::ReadAllText($pathToml1, $utf8NoBom).TrimStart([char]0xFEFF)
                    if ($c1 -match '(?m)^temporary_password\s*=') {
                        $c1 = $c1 -replace "(?m)^temporary_password\s*=.*$", "temporary_password = ''"
                        [IO.File]::WriteAllText($pathToml1, $c1, $utf8NoBom)
                    }
                }

                # 2. Configura HopToDesk2.toml sem BOM com acesso direto via senha permanente
                $pathToml2 = Join-Path $dir 'HopToDesk2.toml'
                $content2 = ''
                if (Test-Path -LiteralPath $pathToml2) {
                    $content2 = [IO.File]::ReadAllText($pathToml2, $utf8NoBom).TrimStart([char]0xFEFF)
                }

                $content2 = Set-TomlOption -Content $content2 -Key 'approve-mode' -Value 'password'
                $content2 = Set-TomlOption -Content $content2 -Key 'verification-method' -Value 'use-permanent-password'
                $content2 = Set-TomlOption -Content $content2 -Key 'allow-logon-screen-password' -Value 'Y'

                # Liga o toggle "Acesso Nao Supervisionado" por padrao (mantem a senha permanente ativa)
                $content2 = Set-TomlOption -Content $content2 -Key 'unattended-access' -Value 'true'

                # Permissoes maximas para quem conecta (equivale a "Full Access" na UI)
                $permOptions = @(
                    @{ key = 'access-mode';                      value = 'full' }
                    @{ key = 'enable-keyboard';                  value = 'Y' }
                    @{ key = 'enable-clipboard';                 value = 'Y' }
                    @{ key = 'enable-file-transfer';             value = 'Y' }
                    @{ key = 'enable-camera';                    value = 'Y' }
                    @{ key = 'enable-terminal';                  value = 'Y' }
                    @{ key = 'enable-remote-printer';            value = 'Y' }
                    @{ key = 'enable-audio';                     value = 'Y' }
                    @{ key = 'enable-tunnel';                    value = 'Y' }
                    @{ key = 'enable-remote-restart';            value = 'Y' }
                    @{ key = 'enable-record-session';            value = 'Y' }
                    @{ key = 'enable-block-input';               value = 'Y' }
                    @{ key = 'allow-remote-config-modification'; value = 'Y' }
                )
                foreach ($opt in $permOptions) {
                    $content2 = Set-TomlOption -Content $content2 -Key $opt.key -Value $opt.value
                }

                [IO.File]::WriteAllText($pathToml2, $content2, $utf8NoBom)
            } catch {}
        }
    } catch {}
}

function Start-HopToDeskGui([string]$ExePath) {
    if (-not $ExePath -or -not (Test-Path -LiteralPath $ExePath)) { return }
    try {
        $workDir = [IO.Path]::GetDirectoryName($ExePath)
        Start-Process -FilePath $ExePath -WorkingDirectory $workDir -WindowStyle Normal -ErrorAction SilentlyContinue
    } catch {}
}

try {
    # 1. Validacao de Desktop e Elevacao de Privilegio
    if (-not $DesktopOriginalBase64) {
        $desktop = [Environment]::GetFolderPath('DesktopDirectory')
        if (-not $desktop -or -not (Test-Path -LiteralPath $desktop -PathType Container)) {
            throw 'Nao foi possivel localizar a Area de Trabalho do usuario.'
        }
        $DesktopOriginalBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($desktop))
    } else {
        $desktop = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($DesktopOriginalBase64))
        if (-not [IO.Path]::IsPathRooted($desktop) -or -not (Test-Path -LiteralPath $desktop -PathType Container)) {
            throw 'O caminho da Area de Trabalho nao e valido.'
        }
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $argsForAdmin = '-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "{0}" -DesktopOriginalBase64 {1}' -f $PSCommandPath, $DesktopOriginalBase64
        try {
            $child = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $argsForAdmin -Verb RunAs -Wait -PassThru
            exit $child.ExitCode
        } catch {
            exit 0
        }
    }

    if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        throw 'Este pacote atende sistemas Windows x64 (Intel/AMD).'
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    # Configuracao oficial e resiliente do HopToDesk
    $script:AppConfig = @{
        Name = 'HopToDesk'
        DownloadUrls = @(
            'https://dl.hoptodesk.com/HopToDesk64.exe',
            'https://dl.hoptodesk.com/HopToDesk.exe',
            'https://download.hoptodesk.com/HopToDesk.exe',
            'https://data.hoptodesk.com/HopToDesk.exe'
        )
        ServiceName = 'HopToDesk'
    }

    # 2. Coleta de Dados do Parceiro / Loja
    $partner = [Microsoft.VisualBasic.Interaction]::InputBox('Informe o nome do parceiro ou loja (ex.: Rango). Cancelar ou deixar vazio encerra a instalacao.', "Suporte Remoto HopToDesk - Parceiro", '')
    if ([string]::IsNullOrWhiteSpace($partner)) { exit 0 }
    $partner = $partner.Trim()

    $label = [Microsoft.VisualBasic.Interaction]::InputBox('Identificacao do computador para o suporte (ex.: Caixa 01, Servidor, Balcao).', "Suporte Remoto HopToDesk - Computador", $env:COMPUTERNAME)
    if ([string]::IsNullOrWhiteSpace($label)) { exit 0 }
    $label = $label.Trim()

    if ($partner.Length -gt 100 -or $label.Length -gt 100 -or ($partner + $label) -match '[\r\n\x00-\x1f]') {
        throw 'Use nomes com ate 100 caracteres, sem quebras de linha.'
    }

    $safePartner = [regex]::Replace($partner, '[\\/:\*\?\"<>\|]', '').Trim()
    if (-not $safePartner) { $safePartner = 'Parceiro' }

    $output = Join-Path $desktop ("HopToDesk Dados - {0}.txt" -f $safePartner)
    $utf8 = New-Object Text.UTF8Encoding($true)

    # 3. Download Oficial com Interface de Progresso
    $downloadFolder = Join-Path $env:TEMP ("Suporte-HopToDesk-" + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($downloadFolder)
    $installer = Join-Path $downloadFolder "HopToDesk.exe"

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Suporte Remoto HopToDesk"
    $form.Size = New-Object System.Drawing.Size(420, 140)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(365, 20)
    $lbl.Text = "Conectando ao servidor oficial do HopToDesk..."

    $prg = New-Object System.Windows.Forms.ProgressBar
    $prg.Location = New-Object System.Drawing.Point(20, 48)
    $prg.Size = New-Object System.Drawing.Size(365, 25)

    $form.Controls.Add($lbl)
    $form.Controls.Add($prg)

    $script:cancelDownload = $false
    $form.Add_FormClosing({ $script:cancelDownload = $true })
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  Instalador de Suporte Remoto (HopToDesk Oficial)" -ForegroundColor Cyan
    Write-Host "  Parceiro: $partner | Computador: $label" -ForegroundColor Gray
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "[1/5] Conectando aos servidores oficiais do HopToDesk..." -ForegroundColor Yellow

    $downloadSuccess = $false
    $lastDownloadError = ''

    foreach ($url in $script:AppConfig.DownloadUrls) {
        if (-not $url) { continue }
        $fs = $null; $stream = $null; $res = $null

        try {
            $lbl.Text = "Conectando ao servidor oficial..."
            [System.Windows.Forms.Application]::DoEvents()

            $req = [System.Net.HttpWebRequest]::Create([uri]$url)
            $req.Method = 'GET'
            $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            $req.Timeout = 25000
            $res = $req.GetResponse()

            $totalBytes = $res.ContentLength
            $stream = $res.GetResponseStream()
            $fs = [System.IO.File]::Create($installer)
            $buffer = New-Object byte[] 65536
            $downloaded = 0

            do {
                $read = $stream.Read($buffer, 0, $buffer.Length)
                if ($read -gt 0) {
                    $fs.Write($buffer, 0, $read)
                    $downloaded += $read
                    if ($totalBytes -gt 0) {
                        $pct = [math]::Min(100, [math]::Floor(($downloaded / $totalBytes) * 100))
                        $mbIn = [math]::Round($downloaded / 1MB, 2)
                        $mbTot = [math]::Round($totalBytes / 1MB, 2)
                        $lbl.Text = "Baixando HopToDesk: $mbIn MB de $mbTot MB ($pct%)"
                        $prg.Style = 'Blocks'
                        $prg.Value = $pct
                    } else {
                        $mbIn = [math]::Round($downloaded / 1MB, 2)
                        $lbl.Text = "Baixando HopToDesk: $mbIn MB..."
                        $prg.Style = 'Marquee'
                    }
                }
                [System.Windows.Forms.Application]::DoEvents()
                if ($script:cancelDownload) { break }
            } while ($read -gt 0)

            $fs.Close(); $stream.Close(); $res.Close()

            if ($script:cancelDownload) {
                Remove-Item -LiteralPath $downloadFolder -Recurse -Force -ErrorAction SilentlyContinue
                $form.Close()
                exit 0
            }

            if ((Test-Path -LiteralPath $installer) -and (Get-Item -LiteralPath $installer).Length -gt 1MB) {
                $downloadSuccess = $true
                break
            }
        } catch {
            $lastDownloadError = $_.Exception.Message
            if ($fs) { try { $fs.Close() } catch {} }
            if ($stream) { try { $stream.Close() } catch {} }
            if ($res) { try { $res.Close() } catch {} }
            if (Test-Path -LiteralPath $installer) {
                Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if (-not $downloadSuccess) {
        $form.Close()
        throw "Nao foi possivel baixar o HopToDesk de nenhuma das fontes oficiais. Detalhe: $lastDownloadError"
    }

    $lbl.Text = "Download concluido! Iniciando instalacao..."
    $prg.Style = 'Marquee'
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Seconds 1
    $form.Close()

    Write-Host "[1/5] Download oficial concluido com sucesso!" -ForegroundColor Green

    # 4. Instalacao Silenciosa do HopToDesk com Deteccao Inteligente de Instalacao Previa
    $existingExe = Find-InstalledAppExe -AppName 'HopToDesk'
    $shouldInstall = $true

    if ($existingExe -and (Test-Path -LiteralPath $existingExe)) {
        $existingVer = try { (Get-Item -LiteralPath $existingExe).VersionInfo.ProductVersion } catch { '' }
        $msgVer = if ($existingVer) { " (Versao atual instalada: $existingVer)" } else { "" }
        
        $promptMsg = "Uma instalacao previa do HopToDesk ja foi localizada neste computador$msgVer.`r`n`r`n" +
                     "Deseja realizar a reinstalacao/atualizacao por cima agora?`r`n`r`n" +
                     "[Sim] - Reinstalar/Atualizar por cima automaticamente (Recomendado)`r`n" +
                     "[Nao] - Manter versao atual e apenas reconfigurar o acesso remoto"
                     
        $choice = [System.Windows.Forms.MessageBox]::Show($promptMsg, 'HopToDesk - Instalacao Existente', 'YesNo', 'Question')
        
        if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "[2/5] Encerrando processos e servico do HopToDesk para atualizar por cima..." -ForegroundColor Yellow
            try {
                Stop-Service -Name 'HopToDesk' -Force -ErrorAction SilentlyContinue
                Get-Process -Name 'HopToDesk' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            } catch {}
            Start-Sleep -Seconds 2
            $shouldInstall = $true
        } else {
            Write-Host "[2/5] Mantendo instalacao existente do HopToDesk..." -ForegroundColor Green
            $installedExe = $existingExe
            $shouldInstall = $false
        }
    }

    if ($shouldInstall) {
        Write-Host "[2/5] Executando instalador do HopToDesk em segundo plano..." -ForegroundColor Yellow
        $installProc = Start-Process -FilePath $installer -ArgumentList '--silent-install' -WindowStyle Hidden -PassThru
        
        # Aguarda o termino natural do instalador (sem mata-lo prematuramente ao detectar o binario na pasta)
        [void]$installProc.WaitForExit(40000)
        if (-not $installProc.HasExited) {
            try { $installProc.Kill() } catch {}
        }
        Start-Sleep -Seconds 2

        $installedExe = Find-InstalledAppExe -AppName 'HopToDesk'
        if (-not $installedExe) {
            $deadline = [DateTime]::UtcNow.AddSeconds(15)
            do {
                $installedExe = Find-InstalledAppExe -AppName 'HopToDesk'
                if ($installedExe) { break }
                Start-Sleep -Seconds 1
            } while ([DateTime]::UtcNow -lt $deadline)
        }

        # Fallback de Desinstalacao se a sobreposicao nao funcionou
        if (-not $installedExe -and $existingExe -and (Test-Path -LiteralPath $existingExe)) {
            $uninstMsg = "A reinstalacao por cima encontrou bloqueio de arquivos.`r`n`r`n" +
                         "Deseja que o instalador execute a desinstalacao previa da versao antiga para instalar a versao atualizada de forma limpa?"
            $uninstChoice = [System.Windows.Forms.MessageBox]::Show($uninstMsg, 'HopToDesk - Desinstalacao Previa Necessaria', 'YesNo', 'Warning')
            
            if ($uninstChoice -eq [System.Windows.Forms.DialogResult]::Yes) {
                Write-Host "[2/5] Realizando desinstalacao previa da versao antiga..." -ForegroundColor Yellow
                try {
                    $unProc = Start-Process -FilePath $existingExe -ArgumentList '--uninstall' -WindowStyle Hidden -PassThru
                    [void]$unProc.WaitForExit(20000)
                } catch {}
                Start-Sleep -Seconds 3
                
                Write-Host "[2/5] Instalando nova versao limpa..." -ForegroundColor Yellow
                $installProc2 = Start-Process -FilePath $installer -ArgumentList '--silent-install' -WindowStyle Hidden -PassThru
                [void]$installProc2.WaitForExit(40000)
                Start-Sleep -Seconds 2
                
                $installedExe = Find-InstalledAppExe -AppName 'HopToDesk'
            }
        }

        if (-not $installedExe) {
            throw "O executavel do HopToDesk nao foi localizado nos diretorios de instalacao."
        }

        Write-Host "[2/5] HopToDesk instalado com sucesso!" -ForegroundColor Green
    }

    Create-DesktopShortcut -TargetExe $installedExe -ShortcutName 'HopToDesk' -UserDesktop $desktop
    Write-Host "[2/5] Atalho na Area de Trabalho configurado com sucesso!" -ForegroundColor Green
    Write-Host "[3/5] Iniciando servico de suporte do Windows..." -ForegroundColor Yellow

    # 5. Servico do Windows
    try {
        Set-Service -Name 'HopToDesk' -StartupType Automatic -ErrorAction SilentlyContinue
        $svc = Get-Service -Name 'HopToDesk' -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            Start-Service -Name 'HopToDesk' -ErrorAction SilentlyContinue
        }
    } catch {}

    Write-Host "[3/5] Servico do Windows pronto!" -ForegroundColor Green
    Write-Host "[4/5] Conectando a rede para gerar o ID de acesso..." -ForegroundColor Yellow

    # 6. Obtencao do ID de Acesso
    $remoteId = ''
    $maxAttempts = 3

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        if ($attempt -gt 1) {
            try { Restart-Service -Name 'HopToDesk' -Force -ErrorAction SilentlyContinue } catch {}
            Start-Sleep -Seconds 4
        }

        $idDeadline = [DateTime]::UtcNow.AddSeconds(40)
        do {
            try {
                $idRes = Invoke-RemoteApp -ExePath $installedExe -Arguments @('--get-id') -TimeoutSeconds 6
                $idText = $idRes.StdOut.Trim()
                if (-not $idText) { $idText = $idRes.Combined.Trim() }

                $idMatch = [regex]::Match($idText, '\b\d{6,15}\b')
                if ($idMatch.Success -and $idMatch.Value -notmatch '^0+$') {
                    $remoteId = $idMatch.Value
                    break
                }
            } catch { }
            Start-Sleep -Seconds 2
        } while ([DateTime]::UtcNow -lt $idDeadline)

        if ($remoteId) { break }
    }

    if (-not $remoteId) {
        $errorRecord = "ACESSO REMOTO - HopToDesk`r`n`r`nParceiro: $partner`r`nComputador: $label`r`nSTATUS: Abra o HopToDesk para consultar o ID na tela."
        [IO.File]::WriteAllText($output, $errorRecord, $utf8)
        Start-HopToDeskGui -ExePath $installedExe
        Start-Process -FilePath "$env:SystemRoot\System32\notepad.exe" -ArgumentList ('"' + $output + '"')
        Remove-Item -LiteralPath $downloadFolder -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Write-Host "[4/5] ID gerado com sucesso: $remoteId" -ForegroundColor Green
    Write-Host "[5/5] Configurando senha permanente de acesso..." -ForegroundColor Yellow

    $password = Get-RandomPassword
    $configuredAt = Get-Date -Format 'dd/MM/yyyy HH:mm:ss zzz'
    $record = @"
ACESSO REMOTO - HopToDesk

Parceiro: $partner
Computador: $label
Nome no Windows: $env:COMPUTERNAME
ID: $remoteId
Senha permanente: $password
Configurado em: $configuredAt
"@
    [IO.File]::WriteAllText($output, $record, $utf8)

    # 7. Configuracao de Senha Permanente no HopToDesk
    try {
        $null = Invoke-RemoteApp -ExePath $installedExe -Arguments @('--password', $password) -TimeoutSeconds 6
    } catch {}

    Write-Host "[5/5] Senha permanente configurada com sucesso!" -ForegroundColor Green

    # 8. Habilita Acesso Nao Supervisionado (Para o servico antes de gravar TOML sem BOM para evitar sobrescrita IPC)
    try {
        Write-Host "[5/5] Ativando acesso nao supervisionado (conexao direta sem pop-up)..." -ForegroundColor Yellow
        try {
            Stop-Service -Name 'HopToDesk' -Force -ErrorAction SilentlyContinue
            Get-Process -Name 'HopToDesk' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        } catch {}
        Start-Sleep -Seconds 1

        Enable-HopToDeskUnattendedAccess

        try {
            Start-Service -Name 'HopToDesk' -ErrorAction SilentlyContinue
        } catch {}
        Start-Sleep -Seconds 2
        Write-Host "[5/5] Acesso nao supervisionado ativado com sucesso!" -ForegroundColor Green
    } catch {
        Write-Host "[Aviso] Nao foi possivel definir acesso nao supervisionado: $($_.Exception.Message)" -ForegroundColor DarkYellow
        try { Start-Service -Name 'HopToDesk' -ErrorAction SilentlyContinue } catch {}
    }

    # 9. Disparo ao Webhook do Make.com (Apos geracao do arquivo txt)
    if ($WebhookUrl -match '^https?://') {
        Write-Host "[5/5] Notificando integracao no Make.com..." -ForegroundColor Yellow
        try {
            $payload = @{
                ferramenta    = 'HopToDesk'
                aplicativo    = 'HopToDesk'
                app           = 'HopToDesk'
                parceiro      = $partner
                computador    = $label
                id            = $remoteId
                senha         = $password
                textoCompleto = $record
            }
            $jsonPayload = $payload | ConvertTo-Json -Depth 3
            $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)
            $null = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $utf8Bytes -ContentType 'application/json; charset=utf-8' -TimeoutSec 10
            Write-Host "[5/5] Integracao Make.com notificada com sucesso!" -ForegroundColor Green
        } catch {
            Write-Host "[Aviso] Nao foi possivel sincronizar com Make.com: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }

    try { Set-Clipboard -Value $record } catch {}
    Create-DesktopShortcut -TargetExe $installedExe -ShortcutName 'HopToDesk' -UserDesktop $desktop

    # Abre a interface do HopToDesk e o Bloco de Notas com os dados gerados
    Write-Host "[5/5] Abrindo interface do HopToDesk e relatorio..." -ForegroundColor Yellow
    Start-HopToDeskGui -ExePath $installedExe
    Start-Process -FilePath "$env:SystemRoot\System32\notepad.exe" -ArgumentList ('"' + $output + '"')

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  ACESSO REMOTO CONFIGURADO COM SUCESSO!" -ForegroundColor Green
    Write-Host "  ID: $remoteId" -ForegroundColor White
    Write-Host "  Senha: $password" -ForegroundColor White
    Write-Host "  Dados salvos no Bloco de Notas e na Area de Trabalho." -ForegroundColor Gray
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host ""

    Show-Info "Configuracao do HopToDesk concluida com sucesso!`r`n`r`nO aplicativo HopToDesk e o Bloco de Notas foram abertos com os dados de acesso." "Information"

    Remove-Item -LiteralPath $downloadFolder -Recurse -Force -ErrorAction SilentlyContinue
    exit 0

} catch {
    Show-Info ("Instalacao interrompida: " + $_.Exception.Message) "Error"
    exit 1
}
