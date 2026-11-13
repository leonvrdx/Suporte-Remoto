# Build script para compilar o Instalador Suporte Remoto.exe
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (-not (Test-Path $csc)) {
    throw "Compilador csc.exe não encontrado em: $csc"
}

$outExe = Join-Path $scriptDir "Instalador Suporte Remoto.exe"
$src = Join-Path $scriptDir "src\Program.cs"
$manifest = Join-Path $scriptDir "src\app.manifest"
$resRust = (Join-Path $scriptDir "build\resources\RustDesk.exe") + ",RustDeskInstaller"
$resHop = (Join-Path $scriptDir "build\resources\HopToDesk.exe") + ",HopToDeskInstaller"

Write-Host "Compilando Instalador Suporte Remoto.exe..." -ForegroundColor Cyan
& $csc /target:winexe /platform:anycpu /optimize+ /win32manifest:$manifest /resource:$resRust /resource:$resHop /out:$outExe $src

if ($LASTEXITCODE -eq 0 -and (Test-Path $outExe)) {
    $sizeMb = [math]::Round(((Get-Item $outExe).Length / 1MB), 2)
    Write-Host "Compilação concluída com sucesso! Tamanho final: $sizeMb MB" -ForegroundColor Green
    Write-Host "Arquivo gerado: $outExe" -ForegroundColor Yellow
} else {
    Write-Host "Erro durante a compilação." -ForegroundColor Red
}
