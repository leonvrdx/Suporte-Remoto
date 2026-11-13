#requires -Version 5.1
param([string]$DesktopOriginalBase64)

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

    # Verifica tambem o servico do Windows
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
    # Caracteres alfanumericos inequívocos (sem simbolos e sem 0/O/1/l)
    $chars = '23456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
    return -join ((1..10) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
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

    # 2. ESCOLHA DO SISTEMA DE SUPORTE VIA INTERFACE
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

    # Configuracao de fontes resilientes de download
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

        # Fallbacks diretos oficiais
        $rustUrls.Add('https://github.com/rustdesk/rustdesk/releases/download/1.5.3/rustdesk-1.5.3-x86_64.exe')
        
        $script:AppConfig = @{
            Name = 'RustDesk'
            DownloadUrls = $rustUrls
            ServiceName = 'RustDesk'
        }
    } else {
        # HopToDesk: Prioriza a versao nativa 64-bit da CDN atual (dl.), com fallbacks
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

    # 3. Coleta de Dados do Parceiro
    $partner = [Microsoft.VisualBasic.Interaction]::InputBox('Informe o nome do parceiro (ex.: Rango). Cancelar ou deixar vazio encerra a instalacao.', "Suporte Remoto $($script:AppConfig.Name) - Parceiro", '')
    if ([string]::IsNullOrWhiteSpace($partner)) { exit 0 }
    $partner = $partner.Trim()

    $label = [Microsoft.VisualBasic.Interaction]::InputBox('Identificacao do computador para o suporte.', "Suporte Remoto $($script:AppConfig.Name) - Computador", $env:COMPUTERNAME)
    if ([string]::IsNullOrWhiteSpace($label)) { exit 0 }
    $label = $label.Trim()

    if ($partner.Length -gt 100 -or $label.Length -gt 100 -or ($partner + $label) -match '[\r\n\x00-\x1f]') {
        throw 'Use nomes com ate 100 caracteres, sem quebras de linha.'
    }

    $consent = [System.Windows.Forms.MessageBox]::Show("Instalar o $($script:AppConfig.Name) para o suporte remoto?`r`n`r`nO suporte podera conectar por senha permanente configurada automaticamente.", "Instalar $($script:AppConfig.Name)", 'YesNo', 'Question')
    if ($consent -ne [System.Windows.Forms.DialogResult]::Yes) { exit 0 }

    $safePartner = [regex]::Replace($partner, '[\\/:\*\?\"<>\|]', '').Trim()
    if (-not $safePartner) { $safePartner = 'Parceiro' }

    $output = Join-Path $desktop ("$($script:AppConfig.Name) Dados - {0}.txt" -f $safePartner)
    $utf8 = New-Object Text.UTF8Encoding($true)
    [IO.File]::WriteAllText($output, "ACESSO REMOTO - $($script:AppConfig.Name)`r`nStatus: instalacao em andamento; nao usar como cadastro de acesso.`r`n", $utf8)

    # 4. Interface de Download com Progresso
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

    # Executa o download testando as URLs em cascata
    $downloadSuccess = $false
    $lastDownloadError = ''

    foreach ($url in $script:AppConfig.DownloadUrls) {
        if (-not $url) { continue }
        $fs = $null
        $stream = $null
        $res = $null

        try {
            $lbl.Text = "Conectando ao servidor oficial..."
            [System.Windows.Forms.Application]::DoEvents()

            $req = [System.Net.HttpWebRequest]::Create([uri]$url)
            $req.Method = 'GET'
            $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            $req.Timeout = 25000
            $req.ReadWriteTimeout = 35000
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

            $fs.Close()
            $stream.Close()
            $res.Close()

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

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  Iniciando configuracao do $($script:AppConfig.Name)" -ForegroundColor Cyan
    Write-Host "  Parceiro: $partner | Computador: $label" -ForegroundColor Gray
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "[1/5] Download oficial concluido com sucesso!" -ForegroundColor Green
    Write-Host "[2/5] Instalando silenciosamente em segundo plano..." -ForegroundColor Yellow

    # 5. Instalacao Silenciosa Unica
    $installProc = Start-Process -FilePath $installer -ArgumentList '--silent-install' -WindowStyle Hidden -PassThru
    if (-not $installProc.WaitForExit(90000)) {
        try { $installProc.Kill() } catch {}
        throw 'A instalacao demorou mais que o esperado.'
    }

    Start-Sleep -Seconds 3

    # Localizacao do executavel instalado (suporta 64-bit e 32-bit em Program Files e Program Files (x86))
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
    $script:AppExe = $installedExe

    Write-Host "[2/5] Aplicativo instalado com sucesso!" -ForegroundColor Green
    Write-Host "[3/5] Iniciando servico do Windows..." -ForegroundColor Yellow

    # Garante inicializacao do servico do Windows
    try {
        Set-Service -Name $script:AppConfig.ServiceName -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name $script:AppConfig.ServiceName -ErrorAction SilentlyContinue
    } catch {}

    Write-Host "[3/5] Servico do Windows pronto!" -ForegroundColor Green
    Write-Host "[4/5] Conectando a rede para gerar o ID de acesso..." -ForegroundColor Yellow

    # 6. Obtencao do ID e Configuracao de Senha
    $remoteId = ''
    $maxAttempts = 3

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        if ($attempt -gt 1) {
            try {
                Restart-Service -Name $script:AppConfig.ServiceName -Force -ErrorAction SilentlyContinue
            } catch {}
            Start-Sleep -Seconds 4
        }

        $idDeadline = [DateTime]::UtcNow.AddSeconds(40)
        do {
            try {
                $idRes = Invoke-RemoteApp -ExePath $script:AppExe -Arguments @('--get-id') -TimeoutSeconds 6
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

        if ($attempt -lt $maxAttempts) {
            $retryMsg = "O computador esta sincronizando com a rede de suporte para gerar o ID.`r`n`r`nClique em OK para continuar aguardando a sincronizacao."
            $ans = [System.Windows.Forms.MessageBox]::Show($retryMsg, 'Suporte Remoto - Conectando...', 'OKCancel', 'Warning')
            if ($ans -eq [System.Windows.Forms.DialogResult]::Cancel) { break }
        }
    }

    if (-not $remoteId) {
        $finalMsg = "Falha ao resgatar o numero de ID pela rede.`r`n`r`nAbra o $($script:AppConfig.Name) manualmente e informe o ID e a Senha para o suporte."
        [System.Windows.Forms.MessageBox]::Show($finalMsg, 'Erro de Rede', 'OK', 'Error')

        $errorRecord = @"
ACESSO REMOTO - $($script:AppConfig.Name)

Parceiro: $partner
Computador: $label
STATUS: INSTALACAO CONCLUIDA, MAS A REDE DEMOROU PARA GERAR O ID.
"@
        [IO.File]::WriteAllText($output, $errorRecord, $utf8)
        Start-Process -FilePath "$env:SystemRoot\System32\notepad.exe" -ArgumentList ('"' + $output + '"')
        Remove-Item -LiteralPath $downloadFolder -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Write-Host "[4/5] ID gerado com sucesso: $remoteId" -ForegroundColor Green
    Write-Host "[5/5] Configurando senha permanente e permissoes de seguranca..." -ForegroundColor Yellow

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

    # Configura opcoes de seguranca e senha permanente
    try {
        $null = Invoke-RemoteApp -ExePath $script:AppExe -Arguments @('--option', 'verification-method', 'both') -TimeoutSeconds 5
        $null = Invoke-RemoteApp -ExePath $script:AppExe -Arguments @('--option', 'allow-remote-config-modification', 'Y') -TimeoutSeconds 5
        $null = Invoke-RemoteApp -ExePath $script:AppExe -Arguments @('--password', $password) -TimeoutSeconds 5
    } catch {}

    Write-Host "[5/5] Senha permanente configurada com sucesso!" -ForegroundColor Green

    # Dispara dados para o Webhook do Make.com de forma assincrona/rapida
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
            # Dispara sem travar
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

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  ACESSO REMOTO CONFIGURADO COM SUCESSO!" -ForegroundColor Green
    Write-Host "  ID: $remoteId" -ForegroundColor White
    Write-Host "  Senha: $password" -ForegroundColor White
    Write-Host "  Dados salvos no Bloco de Notas e na Area de Trabalho." -ForegroundColor Gray
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host ""

    Show-Info "Configuracao concluida com sucesso!`r`n`r`nOs dados foram copiados para a Area de Transferencia e abertos no Bloco de Notas." "Information"

    Remove-Item -LiteralPath $downloadFolder -Recurse -Force -ErrorAction SilentlyContinue
    exit 0

} catch {
    if ($_.Exception.Message -match '(?i)cancelado pelo usu[aá]rio|operation was canceled') {
        exit 0
    }
    Show-Info ("Instalacao interrompida: " + $_.Exception.Message) "Error"
    exit 1
}
