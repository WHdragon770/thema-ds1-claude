# Widget em cima da barra de tarefas: % do limite do Claude usado (5 h e semana) e quanto resta.
# Dados: ~/.claude/status/limites.json, gravado pela statusline (~/.claude/statusline.py) a cada segundo.
# Fica no 2º monitor (se houver), colado à esquerda do relógio; pinta o fundo com a cor da barra de tarefas.
# Arrasta pra mudar de lugar (distância da borda direita em %APPDATA%\limites_claude.json); clique direito fecha.
param([string]$Distro = "Ubuntu")
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W32 { [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f); }
"@

$arq = "\\wsl.localhost\$Distro__HOME_BS__\.claude\status\limites.json"
$cfg = Join-Path $env:APPDATA "limites_claude.json"

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$ttf = Join-Path $PSScriptRoot "fontes\Cinzel.ttf"
$fam = if (Test-Path $ttf) { $pfc.AddFontFile($ttf); $pfc.Families[0] } else { New-Object System.Drawing.FontFamily("Palatino Linotype") }
$fRotulo = New-Object System.Drawing.Font($fam, 7.5, [System.Drawing.FontStyle]::Bold)
$fNum = New-Object System.Drawing.Font($fam, 8.5, [System.Drawing.FontStyle]::Bold)
$fResta = New-Object System.Drawing.Font("Segoe UI", 7.5)

$tela = [System.Windows.Forms.Screen]::AllScreens | Where-Object { -not $_.Primary } | Select-Object -First 1
if (-not $tela) { $tela = [System.Windows.Forms.Screen]::PrimaryScreen }
$alturaBarra = [Math]::Max(30, $tela.Bounds.Bottom - $tela.WorkingArea.Bottom)
$larg = 340

$f = New-Object System.Windows.Forms.Form
$f.FormBorderStyle = "None"; $f.ShowInTaskbar = $false; $f.TopMost = $true
$f.StartPosition = "Manual"
$f.Size = New-Object System.Drawing.Size($larg, ($alturaBarra - 8))
$dx = 130
if (Test-Path $cfg) { try { $c = Get-Content $cfg -Raw | ConvertFrom-Json; if ($c.dx -ne $null) { $dx = [int]$c.dx } } catch {} }
$f.Location = New-Object System.Drawing.Point(($tela.Bounds.Right - $larg - $dx), ($tela.Bounds.Bottom - $alturaBarra + 4))
$p = $f.GetType().GetProperty("DoubleBuffered", [Reflection.BindingFlags]"NonPublic,Instance"); $p.SetValue($f, $true, $null)

$script:dados = $null
$script:erro = "lendo..."
$script:fundo = [System.Drawing.Color]::FromArgb(238, 238, 238)
$tip = New-Object System.Windows.Forms.ToolTip

function Ler {
    try {
        $j = Get-Content $arq -Raw -ErrorAction Stop | ConvertFrom-Json
        $script:dados = $j; $script:erro = $null; $script:falhaLeitura = $false
    } catch {
        # leitura falhou no meio da gravação: mantém o que tinha e pulsa "atualizando"
        if ($script:dados) { $script:falhaLeitura = $true } else { $script:erro = "sem dados (abra o Claude)" }
    }
}

# linha "atualizando": sem dado, leitura falhou ou o limite já zerou e o Claude ainda não mandou o novo
function Atualizando($lim) {
    if ($script:falhaLeitura -or -not $lim) { return $true }
    return [long]$lim.resets_at -le [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}

function Pulsando($g, $y, $rotulo, $escuro) {
    $corTxt = if ($escuro) { [System.Drawing.Color]::FromArgb(235, 228, 215) } else { [System.Drawing.Color]::FromArgb(60, 45, 30) }
    $g.DrawString($rotulo, $fRotulo, (New-Object System.Drawing.SolidBrush($corTxt)), 2, ($y - 1))
    $t = [Environment]::TickCount / 1400.0 * 2 * [Math]::PI
    $a = [int](40 + 215 * (0.5 + 0.5 * [Math]::Sin($t)))
    $bx = 64; $bw = 120; $bh = 7; $by = $y + 4
    $trilho = Pilula $bx $by $bw $bh
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]($a * 0.5), 55, 22, 18))), $trilho)
    $g.DrawPath((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($a, 176, 142, 78), 1)), $trilho)
    $g.DrawString("ATUALIZANDO", $fRotulo, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, 176, 142, 78))), ($bx + $bw + 6), ($y - 1))
}

# cor da barra de tarefas logo à esquerda do widget (acompanha tema claro/escuro)
function Amostra {
    try {
        $b = New-Object System.Drawing.Bitmap(1, 1)
        $g = [System.Drawing.Graphics]::FromImage($b)
        $g.CopyFromScreen(($f.Left - 6), ($f.Top + 4), 0, 0, $b.Size)
        $script:fundo = $b.GetPixel(0, 0); $g.Dispose(); $b.Dispose()
    } catch {}
}

function Hora($ts, [bool]$comDia) {
    $d = [DateTimeOffset]::FromUnixTimeSeconds([long]$ts).LocalDateTime
    if ($comDia) { return $d.ToString("ddd HH:mm", [Globalization.CultureInfo]::GetCultureInfo("pt-BR")) }
    return $d.ToString("HH:mm")
}

function Pilula($x, $y, $w, $h) {
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = $h
    if ($w -lt $r) { $r = [Math]::Max(1, $w) }
    $gp.AddArc($x, $y, $r, $h, 90, 180)
    $gp.AddArc(($x + $w - $r), $y, $r, $h, 270, 180)
    $gp.CloseFigure()
    return $gp
}

# referência a Dark Souls quando o limite aperta (conta pelo número mostrado, já arredondado)
function Fala($usado) {
    $u = [Math]::Round($usado)
    if ($u -ge 99) { return @("YOU DIED", [System.Drawing.Color]::FromArgb(200, 25, 20), $true) }
    if ($u -ge 95) { return @("DON'T GO HOLLOW", [System.Drawing.Color]::FromArgb(225, 60, 40), $false) }
    if ($u -ge 90) { return @("ESTUS: 1", [System.Drawing.Color]::FromArgb(230, 150, 40), $false) }
    return $null
}

function Linha($g, $y, $rotulo, $lim, [bool]$comDia, $escuro) {
    $usado = [double]$lim.used_percentage
    $resta = [Math]::Max([double]0, 100 - $usado)
    $corTxt = if ($escuro) { [System.Drawing.Color]::FromArgb(235, 228, 215) } else { [System.Drawing.Color]::FromArgb(60, 45, 30) }
    $corSec = if ($escuro) { [System.Drawing.Color]::FromArgb(170, 165, 155) } else { [System.Drawing.Color]::FromArgb(115, 110, 100) }
    $ouro = [System.Drawing.Color]::FromArgb(176, 142, 78)

    $g.DrawString($rotulo, $fRotulo, (New-Object System.Drawing.SolidBrush($corTxt)), 2, ($y - 1))

    # barra de vida: trilho escuro, vida vermelha, contorno dourado fino
    $bx = 64; $bw = 120; $bh = 7; $by = $y + 4
    $trilho = Pilula $bx $by $bw $bh
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 22, 18))), $trilho)
    $cheio = [int]($bw * [Math]::Min([double]1, $usado / 100))
    if ($cheio -gt 0) {
        $c1, $c2 = if ($usado -ge 90) { [System.Drawing.Color]::FromArgb(255, 70, 50), [System.Drawing.Color]::FromArgb(170, 20, 15) }
                   elseif ($usado -ge 70) { [System.Drawing.Color]::FromArgb(240, 195, 80), [System.Drawing.Color]::FromArgb(185, 120, 25) }
                   else { [System.Drawing.Color]::FromArgb(200, 45, 35), [System.Drawing.Color]::FromArgb(120, 15, 12) }
        $rect = New-Object System.Drawing.Rectangle($bx, $by, $bw, $bh)
        $gr = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
        $g.FillPath($gr, (Pilula $bx $by $cheio $bh))
    }
    $g.DrawPath((New-Object System.Drawing.Pen($ouro, 1)), $trilho)

    $num = "{0:0}%" -f $usado
    $g.DrawString($num, $fNum, (New-Object System.Drawing.SolidBrush($corTxt)), ($bx + $bw + 6), ($y - 2))
    $wNum = $g.MeasureString($num, $fNum).Width
    $fala = Fala $usado
    if ($fala) {
        # no lugar do "resta": a fala do Dark Souls; 99% pulsa em fade igual tela de morte
        $a = 255
        if ($fala[2]) { $a = [int](70 + 185 * (0.5 + 0.5 * [Math]::Sin([Environment]::TickCount / 1100.0 * 2 * [Math]::PI))); $script:pulsando = $true }
        $g.DrawString($fala[0], $fRotulo, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, $fala[1]))), ($bx + $bw + 5 + $wNum), ($y - 1))
    } else {
        $g.DrawString(("resta {0:0}%" -f $resta), $fResta, (New-Object System.Drawing.SolidBrush($corSec)), ($bx + $bw + 4 + $wNum), ($y - 1))
    }
    $extra = if ($fala) { " - $($fala[0])" } else { "" }
    return "$rotulo usado $([int]$usado)%, resta $([int]$resta)%, zera $(Hora $lim.resets_at $comDia)$extra"
}

$f.Add_Paint({
    $g = $_.Graphics
    $g.SmoothingMode = "AntiAlias"
    $g.TextRenderingHint = "ClearTypeGridFit"
    $g.Clear($script:fundo)
    $escuro = $script:fundo.GetBrightness() -lt 0.5
    if ($script:erro -or -not $script:dados) {
        $cor = if ($escuro) { [System.Drawing.Brushes]::Gainsboro } else { [System.Drawing.Brushes]::DimGray }
        $g.DrawString("Claude: $($script:erro)", $fRotulo, $cor, 2, 6); return
    }
    $rl = $script:dados.rate_limits
    $meio = [int]($f.Height / 2)
    $script:pulsando = $false
    if (Atualizando $rl.five_hour) { Pulsando $g 2 "5 HORAS" $escuro; $t1 = "5 HORAS atualizando..."; $script:pulsando = $true }
    else { $t1 = Linha $g 2 "5 HORAS" $rl.five_hour $false $escuro }
    if (Atualizando $rl.seven_day) { Pulsando $g ($meio + 1) "SEMANA" $escuro; $t2 = "SEMANA atualizando..."; $script:pulsando = $true }
    else { $t2 = Linha $g ($meio + 1) "SEMANA" $rl.seven_day $true $escuro }
    $idade = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$script:dados.lido_em
    $velho = if ($idade -gt 600) { "`n(atualizado ha $([int]($idade / 60)) min, atualiza quando o Claude roda)" } else { "" }
    $tip.SetToolTip($f, "$t1`n$t2$velho")
})

# arrastar na horizontal (fica sempre colado na barra)
$script:arrasto = $null
$f.Add_MouseDown({ if ($_.Button -eq "Left") { $script:arrasto = $_.X } })
$f.Add_MouseMove({ if ($script:arrasto -ne $null) { $f.Left = [System.Windows.Forms.Cursor]::Position.X - $script:arrasto } })
$f.Add_MouseUp({
    if ($script:arrasto -ne $null) {
        $script:arrasto = $null; Amostra; $f.Invalidate()
        @{ dx = ($tela.Bounds.Right - $f.Right) } | ConvertTo-Json | Set-Content $cfg
    }
    elseif ($_.Button -eq "Right") {
        if ([System.Windows.Forms.MessageBox]::Show("Fechar a barra de limites do Claude?", "Limites", "YesNo") -eq "Yes") { $f.Close() }
    }
})

$script:ticks = 0
$tm = New-Object System.Windows.Forms.Timer
$tm.Interval = 3000
$tm.Add_Tick({
    Ler
    $script:ticks++
    if ($script:ticks % 20 -eq 0) { Amostra }
    $f.Invalidate()
    # a barra de tarefas sobe por cima quando clicada: reafirma o "sempre por cima"
    [W32]::SetWindowPos($f.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x0013) | Out-Null
})
# animação do "atualizando" (só redesenha enquanto tem linha pulsando)
$script:pulsando = $false
$tmAnim = New-Object System.Windows.Forms.Timer
$tmAnim.Interval = 50
$tmAnim.Add_Tick({ if ($script:pulsando) { $f.Invalidate() } })
$f.Add_Shown({ Amostra; Ler; $f.Invalidate(); $tm.Start(); $tmAnim.Start() })
[System.Windows.Forms.Application]::Run($f)
