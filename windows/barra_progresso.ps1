# Barra de progresso estilo "vida de chefe" do Dark Souls para tarefas em segundo plano do WSL.
# Modo arquivo: barra_progresso.ps1 -Titulo "Exportando" -Arquivo "\\wsl.localhost\Ubuntu\...\progresso.txt"
#   o arquivo tem linhas "atual total texto"; ultima linha "FIM msg" ou "ERRO msg" encerra.
# Modo log do Blender: -Log "\\wsl...\render.log" -Total 749  (le "Append frame N"; "pronto"/"FALHOU" encerra)
# -SemPopup: nao abre o popup final (quando outro script ja avisa).
param([string]$Titulo = "Tarefa", [string]$Arquivo, [string]$Log, [int]$Total = 0, [switch]$SemPopup)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ---------- fonte serifada (Cinzel, parecida com a dos jogos); cai para Palatino se nao achar
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$ttf = Join-Path $PSScriptRoot "fontes\Cinzel.ttf"
$fam = if (Test-Path $ttf) { $pfc.AddFontFile($ttf); $pfc.Families[0] } else { New-Object System.Drawing.FontFamily("Palatino Linotype") }
$fNome = New-Object System.Drawing.Font($fam, 15, [System.Drawing.FontStyle]::Regular)
$fFim  = New-Object System.Drawing.Font($fam, 30, [System.Drawing.FontStyle]::Regular)
$fInfo = New-Object System.Drawing.Font("Palatino Linotype", 9, [System.Drawing.FontStyle]::Italic)

# ---------- janela sem borda, escura, embaixo no centro da tela
$W = 940; $H = 118
$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$f = New-Object System.Windows.Forms.Form -Property @{
  Text = $Titulo; FormBorderStyle = "None"; Width = $W; Height = $H; StartPosition = "Manual"
  Left = $area.Left + [int](($area.Width - $W) / 2); Top = $area.Bottom - $H - 40
  BackColor = [System.Drawing.Color]::FromArgb(10, 8, 8); Opacity = 0.97 }
$f.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"Instance,NonPublic").SetValue($f, $true)

$st = @{ vida = 1.0; rastro = 1.0; esperaRastro = 0; info = "Despertando..."; nome = $Titulo; fim = $null; fimMsg = ""; fimAlpha = 0.0; fimT = 0
         hist = (New-Object System.Collections.Queue); hover = $false }

# arrastar com o mouse; X no canto fecha
$arr = @{ on = $false; p = $null }
$f.Add_MouseDown({ param($s, $e)
  if ($e.X -gt $W - 30 -and $e.Y -lt 26) { $f.Close(); return }
  $arr.on = $true; $arr.p = $e.Location })
$f.Add_MouseMove({ param($s, $e)
  $h = ($e.X -gt $W - 30 -and $e.Y -lt 26); if ($h -ne $st.hover) { $st.hover = $h; $f.Invalidate() }
  if ($arr.on) { $f.Left += $e.X - $arr.p.X; $f.Top += $e.Y - $arr.p.Y } })
$f.Add_MouseUp({ $arr.on = $false })

function Cor($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

$f.Add_Paint({ param($s, $e)
  $g = $e.Graphics; $g.SmoothingMode = "AntiAlias"; $g.TextRenderingHint = "AntiAliasGridFit"
  # fundo com degrade e moldura fina
  $vr = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
  $vg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($vr, (Cor 255 22 18 16), (Cor 255 6 5 5), 90)
  $g.FillRectangle($vg, $vr)
  $g.DrawRectangle((New-Object System.Drawing.Pen((Cor 255 48 42 34), 1)), 0, 0, $W - 1, $H - 1)
  # X de fechar
  $cx = if ($st.hover) { Cor 255 220 200 160 } else { Cor 255 110 100 85 }
  $g.DrawString([string][char]0x00D7, $fNome, (New-Object System.Drawing.SolidBrush($cx)), $W - 27, 0)

  if ($st.fim) {
    # tela final: "INIMIGO ABATIDO" dourado ou "VOCE MORREU" vermelho
    $a = [int](255 * [Math]::Min(1, $st.fimAlpha))
    $c = if ($st.fim -eq "FIM") { Cor $a 214 182 96 } else { Cor $a 165 22 18 }
    $txt = if ($st.fim -eq "FIM") { "INIMIGO ABATIDO" } else { "VOCÊ MORREU" }
    $sf = New-Object System.Drawing.StringFormat -Property @{ Alignment = "Center"; LineAlignment = "Center" }
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((Cor ([int]($a * 0.55)) 0 0 0))), 0, 28, $W, 62)
    $g.DrawString($txt, $fFim, (New-Object System.Drawing.SolidBrush($c)), (New-Object System.Drawing.RectangleF(0, 22, $W, 70)), $sf)
    return
  }
  # nome do "chefe"
  $X0 = 40; $X1 = $W - 40; $BY = 58; $BH = 11; $L = $X1 - $X0
  $g.DrawString($st.nome, $fNome, (New-Object System.Drawing.SolidBrush((Cor 255 226 218 200))), $X0 - 2, 24)
  # moldura da barra
  $g.FillRectangle((New-Object System.Drawing.SolidBrush((Cor 255 4 3 3))), $X0 - 3, $BY - 3, $L + 6, $BH + 6)
  $g.DrawRectangle((New-Object System.Drawing.Pen((Cor 255 92 80 62), 1)), $X0 - 3, $BY - 3, $L + 5, $BH + 5)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush((Cor 255 26 20 18))), $X0, $BY, $L, $BH)
  # rastro amarelado (vida que acabou de ser perdida)
  if ($st.rastro -gt $st.vida) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((Cor 255 196 160 78))), $X0, $BY, [float]($L * $st.rastro), $BH)
  }
  # vida vermelha
  $wv = [float]($L * $st.vida)
  if ($wv -ge 1) {
    $rv = New-Object System.Drawing.RectangleF($X0, $BY, $wv, $BH)
    $bv = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rv, (Cor 255 168 28 20), (Cor 255 92 8 8), [single]90)
    $g.FillRectangle($bv, $rv)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush((Cor 70 255 150 120))), [float]$X0, [float]$BY, $wv, [float]2)   # brilho em cima
  }
  # info embaixo, alinhada a direita
  $sfR = New-Object System.Drawing.StringFormat -Property @{ Alignment = "Far" }
  $g.DrawString($st.info, $fInfo, (New-Object System.Drawing.SolidBrush((Cor 255 150 138 118))), (New-Object System.Drawing.RectangleF($X0, ($BY + $BH + 7), $L, 20)), $sfR)
})

function Atualiza($q, $tot, $txt) {
  $p = [Math]::Min(1.0, $q / [Math]::Max($tot, 1)); $pct = [Math]::Floor(100 * $p)
  $nova = 1.0 - $p
  if ($nova -lt $st.vida) { $st.esperaRastro = 25 }      # segura o rastro ~0,75 s antes de descer
  $st.vida = $nova
  if ($txt) { $st.nome = $txt }
  $f.Text = "$pct% - $Titulo"
  $st.hist.Enqueue(@((Get-Date), $q)); while ($st.hist.Count -gt 60) { [void]$st.hist.Dequeue() }
  $a = $st.hist.Peek(); $dt = ((Get-Date) - $a[0]).TotalSeconds; $dq = $q - $a[1]
  $resta = ""
  if ($dq -gt 0 -and $dt -gt 5) { $r = [TimeSpan]::FromSeconds(($tot - $q) * $dt / $dq); $resta = "  ·  cerca de {0}h {1:00}min restantes" -f [int][Math]::Floor($r.TotalHours), $r.Minutes }
  $st.info = "$pct%  ·  $q de $tot$resta"
}
function Termina($tipo, $msg) {
  if ($st.fim) { return }
  $st.vida = 0; $st.fim = $tipo; $st.fimMsg = $msg; $st.fimT = 0
}

# leitura do progresso (2 s)
$tLe = New-Object System.Windows.Forms.Timer -Property @{ Interval = 2000 }
$le = {
  try {
    if ($Log) {
      $txt = Get-Content $Log -Tail 40 -ErrorAction Stop
      $m = $txt | Select-String "Append frame (\d+)" | Select-Object -Last 1
      if ($m) { Atualiza ([int]$m.Matches[0].Groups[1].Value) $Total $null }
      $u = $txt | Where-Object { $_ -match "pronto|FALHOU" } | Select-Object -Last 1
      if ($u) { if ($u -match "pronto") { Termina "FIM" $u } else { Termina "ERRO" $u } }
    } else {
      $u = (Get-Content $Arquivo -Tail 1 -ErrorAction Stop).Trim()
      if ($u -match '^(FIM|ERRO)\s*(.*)$') { Termina $Matches[1] $Matches[2] }
      elseif ($u -match '^(\d+)\s+(\d+)\s*(.*)$') { Atualiza ([double]$Matches[1]) ([double]$Matches[2]) $Matches[3] }
    }
  } catch { $st.info = "Aguardando a tarefa..." }
}
$tLe.Add_Tick($le)
# animacao (30 ms): rastro descendo e texto final aparecendo
$tAn = New-Object System.Windows.Forms.Timer -Property @{ Interval = 30 }
$tAn.Add_Tick({
  if ($st.esperaRastro -gt 0) { $st.esperaRastro-- }
  elseif ($st.rastro -gt $st.vida) { $st.rastro = [Math]::Max($st.vida, $st.rastro - 0.004) }
  if ($st.fim) {
    $st.fimT++
    if ($st.fimT -gt 40) { $st.fimAlpha = [Math]::Min(1.0, $st.fimAlpha + 0.025) }   # espera a barra esvaziar
    if ($st.fimT -gt 260) {                                                          # ~8 s depois fecha
      $tAn.Stop(); $tLe.Stop(); $f.Hide()
      if (-not $SemPopup) {
        $ow = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }
        $tipo = if ($st.fim -eq "FIM") { "Information" } else { "Error" }
        [void][System.Windows.Forms.MessageBox]::Show($ow, $st.fimMsg, $Titulo, "OK", $tipo)
      }
      $f.Close()
    }
  }
  $f.Invalidate()
})
$tLe.Start(); $tAn.Start()
$f.Add_Shown({ $f.Activate(); & $le })
[void]$f.ShowDialog()
