# Painel das sessoes do Claude (estilo menu do Dark Souls), sempre por cima das outras janelas.
# Le o coletor do WSL (~/bin/claude_painel.py --loop): uma linha JSON por segundo com cada Claude aberto.
#  - botao  ▾/▴  alterna compacto (so nome + barra) / ampliado (detalhes de tudo)
#  - roda do mouse (ou Ctrl + / Ctrl - / Ctrl 0) aumenta e diminui o painel inteiro
#  - × no canto de uma sessao (aparece com o mouse em cima) encerra so aquele Claude, depois de confirmar
#  - clique numa sessao abre/fecha so ela; duplo clique no nome renomeia; arraste pra mover; – minimiza (volta pela barra de tarefas); × fecha
param([string]$Distro = "Ubuntu")
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic

# ---------- fontes (Cinzel como na barra de progresso)
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$ttf = Join-Path $PSScriptRoot "fontes\Cinzel.ttf"
$fam = if (Test-Path $ttf) { $pfc.AddFontFile($ttf); $pfc.Families[0] } else { New-Object System.Drawing.FontFamily("Palatino Linotype") }
$fTit  = New-Object System.Drawing.Font($fam, 11, [System.Drawing.FontStyle]::Regular)
$fNome = New-Object System.Drawing.Font($fam, 12.5, [System.Drawing.FontStyle]::Regular)
$fEst  = New-Object System.Drawing.Font("Palatino Linotype", 9, [System.Drawing.FontStyle]::Italic)
$fDet  = New-Object System.Drawing.Font("Palatino Linotype", 9.5, [System.Drawing.FontStyle]::Regular)
$fSym  = New-Object System.Drawing.Font("Segoe UI Symbol", 11, [System.Drawing.FontStyle]::Regular)
function Cor($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function Pincel($c) { New-Object System.Drawing.SolidBrush($c) }
$OURO = Cor 255 196 170 112; $BEGE = Cor 255 226 218 200; $CINZA = Cor 255 150 140 122; $APAG = Cor 255 96 88 76

# ---------- posicao salva
$cfgArq = Join-Path $env:APPDATA "painel_claude.json"
$cfg = @{ x = -1; y = 60; compacto = $true; zoom = 1.0 }
try { $j = Get-Content $cfgArq -Raw | ConvertFrom-Json; $cfg.x = $j.x; $cfg.y = $j.y; $cfg.compacto = $j.compacto; if ($j.zoom) { $cfg.zoom = [double]$j.zoom } } catch {}
function SalvaCfg { try { (@{ x = $f.Left; y = $f.Top; compacto = $st.compacto; zoom = $st.zoom } | ConvertTo-Json) | Set-Content $cfgArq } catch {} }

$W = 470
$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$Z0 = [Math]::Min([double]2.0, [Math]::Max([double]0.6, [double]$cfg.zoom))
$f = New-Object System.Windows.Forms.Form -Property @{
  Text = "Claude"; FormBorderStyle = "None"; Width = [int]($W * $Z0); KeyPreview = $true; Height = 120; StartPosition = "Manual"; TopMost = $true; ShowInTaskbar = $true
  BackColor = (Cor 255 10 9 8); Opacity = 0.95 }
$f.Left = if ($cfg.x -ge 0) { $cfg.x } else { $area.Right - [int]($W * $Z0) - 20 }; $f.Top = $cfg.y
$f.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"Instance,NonPublic").SetValue($f, $true)

$st = @{ vistos = @{}; flash = @{}; dados = $null; compacto = [bool]$cfg.compacto; abertos = @{}; linhas = @(); fase = 0.0; hover = ""; erro = "Despertando..."; zoom = $Z0; hLog = 120 }

# ---------- coletor no WSL (le linha a linha sem travar a janela)
$pi = New-Object System.Diagnostics.ProcessStartInfo -Property @{
  FileName = "wsl.exe"; Arguments = "-d $Distro -e python3 __HOME__/bin/claude_painel.py --loop"
  UseShellExecute = $false; RedirectStandardOutput = $true; CreateNoWindow = $true
  StandardOutputEncoding = [System.Text.Encoding]::UTF8 }
$proc = [System.Diagnostics.Process]::Start($pi)
$leitura = $proc.StandardOutput.ReadLineAsync()

function Tempo($s) {
  if ($s -lt 60) { return "$s s" }; if ($s -lt 3600) { return "{0} min" -f [int][Math]::Floor($s / 60) }
  return "{0}h{1:00}" -f [int][Math]::Floor($s / 3600), [int][Math]::Floor(($s % 3600) / 60)
}
function Tk($n) {
  $n = [double]$n
  if ($n -ge 1e6) { return ("{0:0.0}M" -f ($n / 1e6)).Replace(".", ",") }; if ($n -ge 1e3) { return "{0:0}k" -f ($n / 1e3) }
  return "{0:0}" -f $n
}
function Quebra($g, $txt, $font, $larg, $max) {
  $out = @(); $lin = ""
  foreach ($p in ($txt -split "\s+")) {
    $t = if ($lin) { "$lin $p" } else { $p }
    if ($g.MeasureString($t, $font).Width -gt $larg -and $lin) { $out += $lin; $lin = $p; if ($out.Count -ge $max) { break } } else { $lin = $t }
  }
  if ($lin -and $out.Count -lt $max) { $out += $lin }
  if ($out.Count -eq $max -and $lin -ne $out[-1]) { $out[-1] = $out[-1] + "…" }
  return $out
}

# ---------- desenho
$HEAD = 34
$f.Add_Paint({ param($s, $e)
  $g = $e.Graphics; $g.SmoothingMode = "AntiAlias"; $g.TextRenderingHint = "AntiAliasGridFit"
  $g.ScaleTransform([single]$st.zoom, [single]$st.zoom)    # desenha em coordenadas logicas (largura $W) e escala pelo zoom
  $H = $st.hLog
  # fundo: preto esverdeado com degrade + moldura dupla dourada (menu do DS1)
  $vr = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
  $g.FillRectangle((New-Object System.Drawing.Drawing2D.LinearGradientBrush($vr, (Cor 255 24 22 19), (Cor 255 7 7 6), 90)), $vr)
  $g.DrawRectangle((New-Object System.Drawing.Pen((Cor 255 70 60 44), 1)), 0, 0, $W - 1, $H - 1)
  $g.DrawRectangle((New-Object System.Drawing.Pen((Cor 140 150 128 84), 1)), 3, 3, $W - 7, $H - 7)
  # cabecalho
  $g.DrawString("SESSÕES DO CLAUDE", $fTit, (Pincel $OURO), 14, 9)
  $n = if ($st.dados) { @($st.dados.sessoes).Count } else { 0 }
  $g.DrawString("$n acesa" + $(if ($n -ne 1) { "s" } else { "" }), $fEst, (Pincel $CINZA), 200, 12)
  $bt = if ($st.compacto) { [string][char]0x25BE } else { [string][char]0x25B4 }
  $g.DrawString($bt, $fSym, (Pincel $(if ($st.hover -eq "modo") { $BEGE } else { $CINZA })), $W - 58, 8)
  $g.FillRectangle((Pincel $(if ($st.hover -eq "min") { $BEGE } else { $CINZA })), $W - 84, 19, 11, 2)
  $g.DrawString([string][char]0x00D7, $fNome, (Pincel $(if ($st.hover -eq "x") { $BEGE } else { $CINZA })), $W - 30, 5)
  $lp = New-Object System.Drawing.Drawing2D.LinearGradientBrush([System.Drawing.Rectangle]::new(10, $HEAD - 2, $W - 20, 1), (Cor 0 150 128 84), (Cor 255 150 128 84), [single]0)
  $lp.SetSigmaBellShape(0.5); $g.FillRectangle($lp, 10, $HEAD - 2, $W - 20, 1)

  if (-not $st.dados -or $n -eq 0) {
    $msg = if ($st.dados) { "Nenhuma fogueira acesa" } else { $st.erro }
    $g.DrawString($msg, $fEst, (Pincel $CINZA), 16, $HEAD + 12); return
  }
  $y = $HEAD + 6
  foreach ($r in $st.linhas) {
    $sx = $r.s; $y0 = $r.y; $hh = $r.h
    $emCima = ($st.hover -eq $sx.sid -or $st.hover -eq "fx|" + $sx.sid)
    if ($emCima) { $g.FillRectangle((Pincel (Cor 22 255 230 180)), 6, $y0, $W - 12, $hh) }
    # chama (estado): acesa executando / brasa pensando / branca piscando esperando voce / apagada pronto
    $cx = 22; $cy = $y0 + 15
    $pulso = 0.5 + 0.5 * [Math]::Sin($st.fase * 2)
    switch ($sx.estado) {
      "executando"      { $c1 = Cor 255 255 170 60;  $raio = 6 + 1.5 * $pulso }
      "pensando"        { $c1 = Cor 255 210 110 40;  $raio = 5 + 0.8 * $pulso }
      "esperando você"  { $c1 = Cor ([int](120 + 135 * $pulso)) 235 235 255; $raio = 6 }
      default           { $c1 = Cor 255 90 80 70;    $raio = 4 }
    }
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath; $gp.AddEllipse([float]($cx - $raio * 2.2), [float]($cy - $raio * 2.2), [float]($raio * 4.4), [float]($raio * 4.4))
    $pb = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp); $pb.CenterColor = (Cor 110 $c1.R $c1.G $c1.B); $pb.SurroundColors = @((Cor 0 $c1.R $c1.G $c1.B))
    $g.FillPath($pb, $gp); $g.FillEllipse((Pincel $c1), [float]($cx - $raio / 2), [float]($cy - $raio / 2), [float]$raio, [float]$raio)
    # nome + estado
    $g.DrawString($sx.nome, $fNome, (Pincel $BEGE), 38, $y0 + 3)
    $est = $sx.estado
    $ew = $g.MeasureString($est, $fEst).Width
    $fx = $emCima -and $sx.pid -gt 0          # × pra encerrar esta sessao (so com o mouse em cima; empurra o estado pra esquerda)
    if ($fx) { $g.DrawString([string][char]0x00D7, $fNome, (Pincel $(if ($st.hover -eq "fx|" + $sx.sid) { Cor 255 210 60 45 } else { $CINZA })), $W - 30, $y0 + 1) }
    $g.DrawString($est, $fEst, (Pincel $(if ($sx.estado -eq "esperando você") { $BEGE } else { $CINZA })), $W - 16 - $ew - $(if ($fx) { 22 } else { 0 }), $y0 + 7)
    # barra = o que esta fazendo AGORA: progresso da tarefa da acao atual (vida de chefe) / atividade (estamina) / esperando / parada
    $bx = 38; $by = $y0 + 30; $bl = $W - 38 - 18; $bh = 6
    $g.FillRectangle((Pincel (Cor 255 4 3 3)), $bx - 2, $by - 2, $bl + 4, $bh + 4)
    $g.DrawRectangle((New-Object System.Drawing.Pen((Cor 255 80 70 54), 1)), $bx - 2, $by - 2, $bl + 3, $bh + 3)
    $g.FillRectangle((Pincel (Cor 255 26 22 20)), $bx, $by, $bl, $bh)
    $tar = $r.frente
    if ($tar) {
      $p = [Math]::Min([double]1.0, [double]$tar.q / [Math]::Max([double]1.0, [double]$tar.total)); $wv = [float]($bl * $p)
      if ($wv -ge 1) { $rv = New-Object System.Drawing.RectangleF($bx, $by, $wv, $bh)
        $g.FillRectangle((New-Object System.Drawing.Drawing2D.LinearGradientBrush($rv, (Cor 255 176 32 22), (Cor 255 96 10 8), [single]90)), $rv) }
    } elseif ($sx.estado -eq "executando" -or $sx.estado -eq "pensando") {
      $cor = if ($sx.estado -eq "executando") { Cor 255 70 140 60 } else { Cor 255 150 110 50 }
      $g.FillRectangle((Pincel (Cor 110 $cor.R $cor.G $cor.B)), $bx, $by, $bl, $bh)
      $px = $bx + (($st.fase * 90) % ($bl + 120)) - 120
      $rs = New-Object System.Drawing.RectangleF([float]$px, $by, 120, $bh)
      $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rs, (Cor 0 230 255 200), (Cor 220 230 255 200), [single]0); $lg.SetSigmaBellShape(0.5)
      $g.SetClip((New-Object System.Drawing.RectangleF($bx, $by, $bl, $bh))); $g.FillRectangle($lg, $rs); $g.ResetClip()
    } elseif ($sx.estado -eq "esperando você") {
      $g.FillRectangle((Pincel (Cor ([int](90 + 120 * $pulso)) 214 182 96)), $bx, $by, $bl, $bh)
    }
    # texto da acao atual embaixo da barra + tempo (ou % da tarefa) a direita
    $dir = if ($tar) { "{0:0}%" -f (100 * [double]$tar.q / [Math]::Max([double]1.0, [double]$tar.total)) } else { Tempo $sx.seg_estado }
    $dw = $g.MeasureString($dir, $fEst).Width
    $g.DrawString($dir, $fEst, (Pincel $CINZA), $bx + $bl - $dw, $by + 8)
    $g.DrawString($r.atual, $fEst, (Pincel $(if ($sx.estado -eq "pronto") { $APAG } else { $BEGE })), $bx - 2, $by + 8)
    # tokens: total da sessao (com subagentes) e so desta conversa
    if ($r.tok) { $g.DrawString($r.tok, $fEst, (Pincel $APAG), $bx - 2, $by + 24) }
    # barrinhas das tarefas + detalhes (quando aberta)
    if ($r.det.Count) {
      $yy = $by + $(if ($r.tok) { 46 } else { 30 })
      foreach ($l in $r.det) {
        if ($l.Count -gt 2 -and $l[2] -ne $null) {
          $g.FillRectangle((Pincel (Cor 255 26 22 20)), $bx, $yy + 5, 110, 4)
          $g.FillRectangle((Pincel (Cor 255 150 26 18)), $bx, $yy + 5, [float](110 * $l[2]), 4)
          $g.DrawString($l[1], $fDet, (Pincel $l[0]), $bx + 118, $yy - 2)
        } else { $g.DrawString($l[1], $fDet, (Pincel $l[0]), $bx, $yy) }
        $yy += 17
      }
    }
    $fl = $st.flash[$sx.sid]
    if ($fl) {
      $dt = ((Get-Date) - $fl.t0).TotalSeconds
      if ($dt -gt 9) { $st.flash.Remove($sx.sid) } else {
        $a = [int](255 * [Math]::Min(1, [Math]::Min($dt / 0.8, (9 - $dt) / 1.5)))
        $txt = if ($fl.tipo -eq "FIM") { "INIMIGO ABATIDO" } else { "VOCÊ MORREU" }
        $cf = if ($fl.tipo -eq "FIM") { Cor $a 214 182 96 } else { Cor $a 165 22 18 }
        $g.FillRectangle((Pincel (Cor ([int]($a * 0.75)) 6 5 5)), 8, $y0 + 2, $W - 16, 58)
        $sf = New-Object System.Drawing.StringFormat -Property @{ Alignment = "Center"; LineAlignment = "Center" }
        $g.DrawString($txt, $fNome, (Pincel $cf), (New-Object System.Drawing.RectangleF(0, $y0 + 2, $W, 58)), $sf)
      }
    }
    if ($r -ne $st.linhas[-1]) { $g.FillRectangle((Pincel (Cor 60 150 128 84)), 30, $y0 + $hh + 1, $W - 60, 1) }
  }
})

# ---------- tarefa que acabou: aviso uma vez + brilho na linha (o 1o pacote so marca o que ja tinha acabado)
$primeira = @{ v = $true }
function Fins {
  foreach ($sx in @($st.dados.sessoes)) { foreach ($t in @($sx.tarefas)) {
    if (-not $t.fim) { continue }
    $k = $t.arquivo + "|" + $t.mtime
    if ($st.vistos.ContainsKey($k)) { continue }
    $st.vistos[$k] = $true
    if ($primeira.v) { continue }
    $st.flash[$sx.sid] = @{ tipo = $t.fim; t0 = (Get-Date) }
    $msg = $t.titulo + ": " + $(if ($t.texto) { $t.texto } else { if ($t.fim -eq "FIM") { "concluída" } else { "falhou" } })
    $tipo = if ($t.fim -eq "FIM") { "Information" } else { "Error" }
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "popup_claude.ps1"), "`"$msg`"", $tipo)
  } }
  $primeira.v = $false
}

# ---------- monta as linhas (alturas e textos dos detalhes)
function Layout {
  $g = $f.CreateGraphics(); $y = $HEAD + 6; $st.linhas = @()
  foreach ($sx in @($st.dados.sessoes)) {
    $aberto = if ($st.compacto) { [bool]$st.abertos[$sx.sid] } else { -not ($st.abertos[$sx.sid] -eq $false) }
    # acao atual (texto embaixo da barra) e tarefa da acao atual (barra aberta durante a ferramenta em curso)
    $atual = switch ($sx.estado) {
      "executando"     { $sx.ferramenta + ": " + $sx.detalhe }
      "pensando"       { "Pensando…" }
      "esperando você" { "Esperando você: " + $sx.msg_espera }
      default          { "Descansando na fogueira" }
    }
    $vivas = @($sx.tarefas | Where-Object { -not $_.fim })
    $frente = $null
    if ($sx.estado -eq "executando") { $frente = $vivas | Where-Object { [double]$_.desde -ge [double]$sx.t_ferr - 2 } | Select-Object -First 1 }
    $gm = $g; $Lt = $W - 38 - 18 - 60
    $q1 = @(Quebra $gm $atual $fEst $Lt 1); $atual = if ($q1.Count) { $q1[0] } else { "" }
    if ($atual -ne $null -and $q1.Count -and ($sx.ferramenta + ": " + $sx.detalhe).Length -gt $atual.Length -and -not $atual.EndsWith("…") -and $sx.estado -eq "executando") { $atual += "…" }
    # barrinhas das tarefas rodando: sempre aparecem (menos a que ja esta na barra principal)
    $det = @(); $L = $W - 38 - 18
    foreach ($t in $vivas) {             # todas, inclusive a da acao atual
      $ind = [double]$t.total -le 0       # sem porcentagem (comando em 2o plano): barra andando + tempo
      $pp = if ($ind) { [double](((Get-Date).Second % 10) + 1) / 10 } else { [Math]::Min([double]1.0, [double]$t.q / [Math]::Max([double]1.0, [double]$t.total)) }
      $eta = if ($t.texto -match "termina\s*~?\s*(\d{1,2}:\d{2})") { " · termina " + $Matches[1] } elseif ($t.texto -match "comeca as (\d{1,2}:\d{2})|começa às (\d{1,2}:\d{2})") { " · começa " + $(if ($Matches[1]) { $Matches[1] } else { $Matches[2] }) } else { "" }
      $tx = @(Quebra $g $(if ($ind) { $t.texto + " · " + $t.titulo } else { $t.titulo + " · " + ("{0:0}%" -f (100 * $pp)) + $eta }) $fDet ($L - 120) 1)[0]
      $det += ,@($CINZA, $tx, $pp)
    }
    if ($aberto) {                       # detalhes extras so quando a sessao esta aberta (clique)
      if ($sx.estado -eq "executando" -and $sx.detalhe) { foreach ($q in (Quebra $g $sx.detalhe $fDet $L 3)) { $det += ,@($CINZA, $q, $null) } }
      foreach ($t in @($sx.tarefas | Where-Object { $_.fim })) {
        $det += ,@($(if ($t.fim -eq "FIM") { $OURO } else { Cor 255 190 50 40 }), ("» " + $t.titulo + ": " + $(if ($t.fim -eq "FIM") { "concluída" } else { "falhou" })), $null)
      }
      foreach ($p in @($sx.processos)) { $det += ,@($CINZA, ("› " + $p.nome + " · " + (Tempo $p.seg)), $null) }
      if ($sx.ultimo_prompt) { foreach ($q in (Quebra $g ("Pediu: " + $sx.ultimo_prompt) $fDet $L 2)) { $det += ,@($APAG, $q, $null) } }
      if ($sx.tokens) { $det += ,@($APAG, ("Tokens: saída " + (Tk $sx.tokens.saida) + " · novos " + (Tk $sx.tokens.novos) + " · cache lido " + (Tk $sx.tokens.cache_lido)), $null) }
      $det += ,@($APAG, ($sx.cwd + "  ·  aberta há " + (Tempo $sx.seg_sessao)), $null)
    }
    $tok = if ($sx.tokens) { (Tk $sx.tokens.total) + " tokens no total  ·  " + (Tk $sx.tokens.conversa) + " desta conversa" + $(if ([double]$sx.tokens.subagentes -gt 0) { "  ·  " + (Tk $sx.tokens.subagentes) + " subagentes" } else { "" }) } else { "" }
    $h = 62 + $(if ($tok) { 16 } else { 0 }) + $(if ($det.Count) { 17 * $det.Count + 6 } else { 0 })
    $st.linhas += @{ s = $sx; y = $y; h = $h; aberto = $aberto; det = $det; atual = $atual; frente = $frente; tok = $tok }
    $y += $h + 3
  }
  $g.Dispose()
  $st.hLog = [Math]::Max($y + 8, $HEAD + 44)
  $alvo = [int][Math]::Ceiling($st.hLog * $st.zoom)
  if ($f.Height -ne $alvo) { $f.Height = $alvo }
}

# ---------- zoom: muda o tamanho de tudo mantendo a borda direita no lugar
function Zoom($z) {
  $z = [Math]::Round([Math]::Min([double]2.0, [Math]::Max([double]0.6, [double]$z)), 2)
  if ($z -eq $st.zoom) { return }
  $dir = $f.Right; $st.zoom = $z
  $f.Width = [int]($W * $z); $f.Left = $dir - $f.Width
  if ($st.dados) { Layout } else { $st.hLog = 120; $f.Height = [int](120 * $z) }
  SalvaCfg; $f.Invalidate()
}
$f.Add_MouseWheel({ param($s, $e) Zoom ($st.zoom + $(if ($e.Delta -gt 0) { 0.1 } else { -0.1 })) })
$f.Add_KeyDown({ param($s, $e)
  if (-not $e.Control) { return }
  switch ($e.KeyCode) {
    { $_ -in "Oemplus", "Add" }       { Zoom ($st.zoom + 0.1) }
    { $_ -in "OemMinus", "Subtract" } { Zoom ($st.zoom - 0.1) }
    { $_ -in "D0", "NumPad0" }        { Zoom 1.0 }
  } })

# ---------- mouse: arrastar, botoes, abrir/fechar sessao, renomear
$arr = @{ on = $false; p = $null; moveu = $false }
function Alvo($x, $y) {
  $x = $x / $st.zoom; $y = $y / $st.zoom
  if ($y -lt $HEAD) { if ($x -gt $W - 34) { return "x" }; if ($x -gt $W - 64) { return "modo" }; if ($x -gt $W - 92) { return "min" }; return "" }
  foreach ($r in $st.linhas) { if ($y -ge $r.y -and $y -lt $r.y + $r.h) {
    if ($x -gt $W - 34 -and $y -lt $r.y + 26 -and $r.s.pid -gt 0) { return "fx|" + $r.s.sid }
    return $r.s.sid } }
  return ""
}
$f.Add_MouseDown({ param($s, $e) $arr.on = $true; $arr.p = $e.Location; $arr.moveu = $false })
$f.Add_MouseMove({ param($s, $e)
  $h = Alvo $e.X $e.Y; if ($h -ne $st.hover) { $st.hover = $h; $f.Invalidate() }
  if ($arr.on -and ([Math]::Abs($e.X - $arr.p.X) + [Math]::Abs($e.Y - $arr.p.Y) -gt 3)) { $arr.moveu = $true; $f.Left += $e.X - $arr.p.X; $f.Top += $e.Y - $arr.p.Y } })
$f.Add_MouseUp({ param($s, $e)
  $arr.on = $false
  if ($arr.moveu) { SalvaCfg; return }
  $a = Alvo $e.X $e.Y
  if ($a -eq "x") { $f.Close(); return }
  if ($a -eq "min") { $st.hover = ""; $f.WindowState = "Minimized"; return }
  if ($a -eq "modo") { $st.compacto = -not $st.compacto; $st.abertos = @{}; SalvaCfg; Layout; $f.Invalidate(); return }
  if ($a.StartsWith("fx|")) {
    $r = $st.linhas | Where-Object { $_.s.sid -eq $a.Substring(3) }; if (-not $r) { return }
    $ok = [System.Windows.Forms.MessageBox]::Show($f, "Encerrar a sessão `"$($r.s.nome)`"?`n`nO Claude dela fecha na hora (o que estiver rodando para).", "Apagar fogueira", "YesNo", "Warning")
    if ($ok -ne "Yes") { return }
    $p = [int]$r.s.pid    # ~/bin/claude_fechar: TERM e, se nao sair em 3 s, KILL
    Start-Process wsl.exe -WindowStyle Hidden -ArgumentList "-d $Distro -e __HOME__/bin/claude_fechar $p"
    $st.hover = ""; return }
  if ($a) { $r = $st.linhas | Where-Object { $_.s.sid -eq $a }; $st.abertos[$a] = -not $r.aberto; Layout; $f.Invalidate() } })
$f.Add_MouseDoubleClick({ param($s, $e)
  $a = Alvo $e.X $e.Y; if (-not $a -or $a -eq "x" -or $a -eq "modo" -or $a -eq "min" -or $a.StartsWith("fx|")) { return }
  $r = $st.linhas | Where-Object { $_.s.sid -eq $a }
  $novo = [Microsoft.VisualBasic.Interaction]::InputBox("Nome desta sessão do Claude:", "Renomear", $r.s.nome)
  if ($novo) {
    $arq = "\\wsl.localhost\$Distro__HOME_BS__\.claude\status\nomes.json"
    $m = @{}; try { (Get-Content $arq -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $m[$_.Name] = $_.Value } } catch {}
    $m[$a] = $novo
    [System.IO.File]::WriteAllText($arq, ($m | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
  } })
$f.Add_MouseLeave({ $st.hover = ""; $f.Invalidate() })

# ---------- timers: dados (le o que o coletor mandou) e animacao
$tDados = New-Object System.Windows.Forms.Timer -Property @{ Interval = 250 }
$tDados.Add_Tick({
  if ($proc.HasExited) {                 # coletor caiu: avisa e religa (no maximo a cada 5 s)
    $st.erro = "Coletor do WSL parou, religando..."; $st.dados = $null; $f.Invalidate()
    if (-not $st.religa -or ((Get-Date) - $st.religa).TotalSeconds -gt 5) {
      $st.religa = Get-Date
      try { $script:proc = [System.Diagnostics.Process]::Start($pi); $script:leitura = $proc.StandardOutput.ReadLineAsync() } catch {}
    }
    return }
  $ult = $null
  while ($leitura.IsCompleted) { $ult = $leitura.Result; if ($null -eq $ult) { break }; $script:leitura = $proc.StandardOutput.ReadLineAsync() }
  if ($ult) { try { $d = $ult | ConvertFrom-Json; if ($d.sessoes -ne $null -or $d.t) { $st.dados = $d; Fins; Layout } } catch {} }
})
$tAn = New-Object System.Windows.Forms.Timer -Property @{ Interval = 40 }
$tAn.Add_Tick({ $st.fase += 0.04; $f.Invalidate() })
$f.Add_FormClosed({ try { $proc.Kill() } catch {}; SalvaCfg })
$tDados.Start(); $tAn.Start()
[void]$f.ShowDialog()
