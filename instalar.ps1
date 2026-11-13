# Script de instalacao direta de Suporte Remoto via Web
# Uso rapido: irm https://raw.githubusercontent.com/<usuario>/Suporte-Remoto/main/instalar.ps1 | iex

$ErrorActionPreference = 'Stop'
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
    [void][System.Windows.Forms.MessageBox]::Show($Message, 'Suporte Remoto', 'OK', $iconEnum)
}

function Find-InstalledAppExe([string]$AppName) {
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

    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    return @{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
        Combined = ($stdout + "`r`n" + $stderr)
    }
}

function Get-RandomPassword {
    $chars = '23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
    return -join ((1..10) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

try {
    # Validacao de Elevacao
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Show-Info "Por favor, abra o PowerShell como Administrador para executar este comando." "Warning"
        exit 1
    }

    $desktop = [Environment]::GetFolderPath('DesktopDirectory')
    if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE 'Desktop' }

    # 1. ESCOLHA DO SISTEMA DE SUPORTE
    $choiceForm = New-Object System.Windows.Forms.Form
    $choiceForm.Text = "Escolha a Ferramenta"
    $choiceForm.Size = New-Object System.Drawing.Size(350, 170)
    $choiceForm.StartPosition = "CenterScreen"
    $choiceForm.FormBorderStyle = "FixedDialog"
    $choiceForm.MaximizeBox = $false
    $choiceForm.MinimizeBox = $false
    $choiceForm.TopMost = $true

    $lblQuestion = New-Object System.Windows.Forms.Label
    $lblQuestion.Location = New-Object System.Drawing.Point(15, 15)
    $lblQuestion.Size = New-Object System.Drawing.Size(305, 20)
    $lblQuestion.Text = "Qual ferramenta de suporte remoto deseja instalar?"

    $script:selectedApp = $null

    $btnRustDesk = New-Object System.Windows.Forms.Button
    $btnRustDesk.Location = New-Object System.Drawing.Point(15, 42)
    $btnRustDesk.Size = New-Object System.Drawing.Size(305, 32)
    $btnRustDesk.Text = "RustDesk (Recomendado)"
    $btnRustDesk.Add_Click({
        $script:selectedApp = 'RustDesk'
        $choiceForm.Close()
    })

    $btnHopToDesk = New-Object System.Windows.Forms.Button
    $btnHopToDesk.Location = New-Object System.Drawing.Point(15, 80)
    $btnHopToDesk.Size = New-Object System.Drawing.Size(305, 32)
    $btnHopToDesk.Text = "HopToDesk (Alternativo Open-Source)"
    $btnHopToDesk.Add_Click({
        $script:selectedApp = 'HopToDesk'
        $choiceForm.Close()
    })

    $choiceForm.Controls.Add($lblQuestion)
    $choiceForm.Controls.Add($btnRustDesk)
    $choiceForm.Controls.Add($btnHopToDesk)

    $choiceForm.ShowDialog() | Out-Null
    $choiceForm.Dispose()

    if (-not $script:selectedApp) { exit 0 }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

    if ($script:selectedApp -eq 'RustDesk') {
        $rustUrls = [System.Collections.Generic.List[string]]::new()
        try {
            $apiHeaders = @{
                'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                'Accept' = 'application/vnd.github+json'
            }
            $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' -Headers $apiHeaders -TimeoutSec 10 -ErrorAction Stop
            $assets = @($rel.assets | Where-Object { $_.name -match '(?i)rustdesk-.*-x86_64\.exe$' })
            if ($assets.Count -gt 0) {
                $rustUrls.Add($assets[0].browser_download_url)
            }
        } catch { }

        $rustUrls.Add('https://github.com/rustdesk/rustdesk/releases/download/1.5.3/rustdesk-1.5.3-x86_64.exe')
        
        $script:AppConfig = @{
            Name = 'RustDesk'
            DownloadUrls = $rustUrls
            ServiceName = 'RustDesk'
        }
    } else {
        $script:AppConfig = @{
            Name = 'HopToDesk'
            DownloadUrls = @(
                'https://dl.hoptodesk.com/HopToDesk64.exe',
                'https://dl.hoptodesk.com/HopToDesk.exe',
                'https://download.hoptodesk.com/HopToDesk.exe'
            )
            ServiceName = 'HopToDesk'
        }
    }

    # 2. Coleta de Dados do Parceiro
    $partner = [Microsoft.VisualBasic.Interaction]::InputBox('Informe o nome do parceiro (ex.: Rango). Cancelar ou deixar vazio encerra a instalacao.', "Suporte Remoto $($script:AppConfig.Name) - Parceiro", '')
    if ([string]::IsNullOrWhiteSpace($partner)) { exit 0 }
    $partner = $partner.Trim()

    $label = [Microsoft.VisualBasic.Interaction]::InputBox('Identificacao do computador para o suporte.', "Suporte Remoto $($script:AppConfig.Name) - Computador", $env:COMPUTERNAME)
    if ([string]::IsNullOrWhiteSpace($label)) { exit 0 }
    $label = $label.Trim()

    $safePartner = [regex]::Replace($partner, '[\\/:\*\?\"<>\|]', '').Trim()
    if (-not $safePartner) { $safePartner = 'Parceiro' }

    $output = Join-Path $desktop ("$($script:AppConfig.Name) Dados - {0}.txt" -f $safePartner)
    $utf8 = New-Object Text.UTF8Encoding($true)

    # 3. Download com Progresso
    $downloadFolder = Join-Path $env:TEMP ("Suporte-$($script:AppConfig.Name)-" + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($downloadFolder)
    $installer = Join-Path $downloadFolder "$($script:AppConfig.Name).exe"

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Suporte Remoto $($script:AppConfig.Name)"
    $form.Size = New-Object System.Drawing.Size(420, 140)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(365, 20)
    $lbl.Text = "Conectando ao servidor oficial..."

    $prg = New-Object System.Windows.Forms.ProgressBar
    $prg.Location = New-Object System.Drawing.Point(20, 48)
    $prg.Size = New-Object System.Drawing.Size(365, 25)

    $form.Controls.Add($lbl)
    $form.Controls.Add($prg)

    $script:cancelDownload = $false
    $form.Add_FormClosing({ $script:cancelDownload = $true })
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()

    $downloadSuccess = $false
    $lastDownloadError = ''

    foreach ($url in $script:AppConfig.DownloadUrls) {
        if (-not $url) { continue }
        $fs = $null; $stream = $null; $res = $null

        try {
            $lbl.Text = "Conectando ao servidor..."
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
                        $lbl.Text = "Baixando instalador: $mbIn MB de $mbTot MB ($pct%)"
                        $prg.Style = 'Blocks'
                        $prg.Value = $pct
                    } else {
                        $mbIn = [math]::Round($downloaded / 1MB, 2)
                        $lbl.Text = "Baixando instalador: $mbIn MB..."
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
        throw "Nao foi possivel baixar o instalador de nenhuma das fontes disponiveis. Detalhe: $lastDownloadError"
    }

    $lbl.Text = "Download concluido! Iniciando instalacao..."
    $prg.Style = 'Marquee'
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Seconds 1
    $form.Close()

    # 4. Instalacao Silenciosa
    $installProc = Start-Process -FilePath $installer -ArgumentList '--silent-install' -WindowStyle Hidden -PassThru
    if (-not $installProc.WaitForExit(90000)) {
        try { $installProc.Kill() } catch {}
        throw 'A instalacao demorou mais que o esperado.'
    }

    Start-Sleep -Seconds 3

    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    $installedExe = $null
    do {
        $installedExe = Find-InstalledAppExe -AppName $script:AppConfig.Name
        if ($installedExe) { break }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)

    if (-not $installedExe) {
        throw "O executavel do $($script:AppConfig.Name) nao foi localizado nos diretorios esperados de instalacao."
    }

    try {
        Set-Service -Name $script:AppConfig.ServiceName -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name $script:AppConfig.ServiceName -ErrorAction SilentlyContinue
    } catch {}

    # 5. Obtencao do ID
    $remoteId = ''
    $maxAttempts = 3

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        if ($attempt -gt 1) {
            try { Restart-Service -Name $script:AppConfig.ServiceName -Force -ErrorAction SilentlyContinue } catch {}
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
        $errorRecord = "ACESSO REMOTO - $($script:AppConfig.Name)`r`n`r`nParceiro: $partner`r`nComputador: $label`r`nSTATUS: Abra o $($script:AppConfig.Name) para consultar o ID."
        [IO.File]::WriteAllText($output, $errorRecord, $utf8)
        Start-Process -FilePath "$env:SystemRoot\System32\notepad.exe" -ArgumentList ('"' + $output + '"')
        Remove-Item -LiteralPath $downloadFolder -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    $password = Get-RandomPassword
    $configuredAt = Get-Date -Format 'dd/MM/yyyy HH:mm:ss zzz'
    $record = @"
ACESSO REMOTO - $($script:AppConfig.Name)

Parceiro: $partner
Computador: $label
Nome no Windows: $env:COMPUTERNAME
ID: $remoteId
Senha permanente: $password
Configurado em: $configuredAt
"@
    [IO.File]::WriteAllText($output, $record, $utf8)

    # Configuracao de opcoes e senha
    try {
        $null = Invoke-RemoteApp -ExePath $installedExe -Arguments @('--option', 'verification-method', 'both') -TimeoutSeconds 5
        $null = Invoke-RemoteApp -ExePath $installedExe -Arguments @('--option', 'allow-remote-config-modification', 'Y') -TimeoutSeconds 5
        $null = Invoke-RemoteApp -ExePath $installedExe -Arguments @('--password', $password) -TimeoutSeconds 5
    } catch {}

    # Disparo assincrono ao Make.com
    if ($WebhookUrl -match '^https://') {
        try {
            $payload = @{
                ferramenta = $script:AppConfig.Name
                aplicativo = $script:AppConfig.Name
                app = $script:AppConfig.Name
                parceiro = $partner
                computador = $label
                id = $remoteId
                senha = $password
                textoCompleto = $record
            }
            $jsonPayload = $payload | ConvertTo-Json -Depth 3
            $null = [System.Threading.ThreadPool]::QueueUserWorkItem({
                param($info)
                try {
                    Invoke-RestMethod -Uri $info.Url -Method Post -Body $info.Body -ContentType 'application/json' -TimeoutSec 5 -ErrorAction SilentlyContinue
                } catch {}
            }, @{ Url = $WebhookUrl; Body = $jsonPayload })
        } catch { }
    }

    try { Set-Clipboard -Value $record } catch {}
    Start-Process -FilePath "$env:SystemRoot\System32\notepad.exe" -ArgumentList ('"' + $output + '"')
    Show-Info "Configuracao concluida com sucesso!`r`n`r`nOs dados foram copiados para a Area de Transferencia e abertos no Bloco de Notas." "Information"

    Remove-Item -LiteralPath $downloadFolder -Recurse -Force -ErrorAction SilentlyContinue
    exit 0

} catch {
    Show-Info ("Instalacao interrompida: " + $_.Exception.Message) "Error"
    exit 1
}
