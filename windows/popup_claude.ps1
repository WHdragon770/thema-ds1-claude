param([string]$msg, [string]$tipo = "Information", [string]$titulo = "Claude")
# aviso que fica na frente de tudo e so fecha no OK (usado pelo painel do Claude quando uma tarefa termina)
Add-Type -AssemblyName System.Windows.Forms
$f = New-Object System.Windows.Forms.Form -Property @{TopMost = $true}
[System.Windows.Forms.MessageBox]::Show($f, $msg, $titulo, "OK", $tipo) | Out-Null
