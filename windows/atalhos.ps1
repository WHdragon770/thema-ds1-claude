# atalhos do tema DS1: "Claude DS1" na Área de Trabalho (Windows Terminal com o perfil DS1) e o Solaire + a fogueira
# abrindo junto com o Windows
$ws = New-Object -ComObject WScript.Shell
$wt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
$l = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Claude DS1.lnk'))
$l.TargetPath = $wt; $l.Arguments = '-p "Claude DS1"'; $l.Description = 'Claude Code no tema Dark Souls'; $l.Save()
$ini = [Environment]::GetFolderPath('Startup')
foreach ($par in @(@('PetSolaire', (Join-Path $env:LOCALAPPDATA 'PetSolaire\pet.ps1')), @('Fogueira DS1', '__THEMA_WIN__\Fogueira\fogueira.ps1'))) {
    $l = $ws.CreateShortcut((Join-Path $ini ($par[0] + '.lnk')))
    $l.TargetPath = 'powershell.exe'; $l.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $par[1] + '"'
    $l.WindowStyle = 7; $l.WorkingDirectory = Split-Path $par[1]; $l.Save()
}
'atalhos criados (Área de Trabalho: Claude DS1; Inicializar: PetSolaire e Fogueira DS1)'
