# Volta os cursores que estavam antes do aplicar.ps1 (backup.json)
$p = $PSScriptRoot; $k = 'HKCU:\Control Panel\Cursors'
$o = Get-Content (Join-Path $p 'backup.json') -Raw | ConvertFrom-Json
foreach ($n in $o.PSObject.Properties) { Set-ItemProperty $k -Name $n.Name -Value ([string]$n.Value) }
Add-Type -Namespace W -Name C -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(int a, int b, System.IntPtr c, int d);'
[void][W.C]::SystemParametersInfo(0x57, 0, [IntPtr]::Zero, 3)
'cursores antigos de volta'
