# Põe os cursores DS1 (espada, espada do sol, sol girando, barra) no Windows. Guarda os atuais em backup.json (só na 1ª vez).
# Voltar ao normal: restaurar.ps1
$p = $PSScriptRoot; $k = 'HKCU:\Control Panel\Cursors'
$bk = Join-Path $p 'backup.json'
$NOMES = 'Arrow', 'Hand', 'Wait', 'AppStarting', 'IBeam', '(default)'
if (-not (Test-Path $bk)) {
    $o = @{}; foreach ($n in $NOMES) { $o[$n] = (Get-ItemProperty $k -Name $n -ErrorAction SilentlyContinue).$n }
    $o | ConvertTo-Json | Set-Content $bk -Encoding UTF8
}
$novo = @{ Arrow = 'seta.cur'; Hand = 'link.cur'; Wait = 'ocupado.ani'; AppStarting = 'trabalhando.ani'; IBeam = 'texto.cur' }
foreach ($n in $novo.Keys) { Set-ItemProperty $k -Name $n -Value (Join-Path $p $novo[$n]) }
Set-ItemProperty $k -Name '(default)' -Value 'Dark Souls'
Add-Type -Namespace W -Name C -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(int a, int b, System.IntPtr c, int d);'
[void][W.C]::SystemParametersInfo(0x57, 0, [IntPtr]::Zero, 3)      # SPI_SETCURSORS: aplica na hora
'cursores DS1 aplicados'
