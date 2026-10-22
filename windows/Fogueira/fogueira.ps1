# Fogueira do dia: ao ligar o PC escurece a tela, aparece "BONFIRE LIT" igual no Dark Souls e depois o resumo do dia
# (as mensagens de orange soapstone marcadas pra hoje, o resumo do seu dash se tiver e o limite do Claude).
# Clique fora do quadro ou Esc fecha. O seu dash entra pelo "fogueira" do meu_dash.json (ver README, "Ligar o seu dash").
param([switch]$SemAnimacao)

# ======== CONFIGURAÇÃO ========
$PASTA     = $PSScriptRoot
$LEMBRETES = Join-Path $env:LOCALAPPDATA 'PetSolaire\lembretes'                # ~/bin/lembrete (mensagens do Solaire)
$LIMITES   = '\\wsl.localhost\__DISTRO____HOME_BS__\.claude\status\limites.json'   # só lê se o WSL já estiver ligado
$MAX_HOJE  = 8                                                                  # mensagens (e itens por seção do dash) mostrados
$MEU_DASH  = '__THEMA_WIN__\meu_dash.json'                                       # opcional
# ==============================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\FogueiraDS1', [ref]$created)
if (-not $created) { exit }

# ---- dados: mensagens marcadas pra hoje (e as atrasadas) ----
$hojeTxt = (Get-Date).ToString('yyyy-MM-dd') + 'T23:59'
$msgs = @(Get-ChildItem $LEMBRETES -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object {
    try { [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch {}
} | Where-Object { $_ -and [string]$_.quando -le $hojeTxt } | Sort-Object quando)
# seu dash (opcional): "gerar" roda antes (até 20 s) e "resumo" é o JSON com as seções {secoes: [{titulo, resumo, vazio, itens: [{tag, cor, titulo, detalhe}]}]}
$dash = $null; $dashErro = $false; $cfg = $null
try { $cfg = ([System.IO.File]::ReadAllText($MEU_DASH, [System.Text.Encoding]::UTF8) | ConvertFrom-Json).fogueira } catch {}
if ($cfg -and $cfg.resumo) {
    if ($cfg.gerar) {
        $g = [string]$cfg.gerar
        try {
            $pr = if ($g -like '*.ps1') { Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$g`"" -WindowStyle Hidden -PassThru }
                  else { Start-Process $g -WindowStyle Hidden -PassThru }
            [void]$pr.WaitForExit(20000)
        } catch {}
    }
    try { $dash = [System.IO.File]::ReadAllText([string]$cfg.resumo, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $dashErro = $true }
}
$lim = $null
if (Get-Process -Name 'vmmem', 'vmmemWSL' -ErrorAction SilentlyContinue) {
    try { $lim = ([System.IO.File]::ReadAllText($LIMITES) | ConvertFrom-Json).rate_limits } catch {}
}

function Pincel($hex) { $p = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($hex)); $p.Freeze(); $p }
$FONTE_DS = New-Object System.Windows.Media.FontFamily('Cinzel, Palatino Linotype, Georgia')
$OURO = Pincel '#E8C060'; $BRANCO = Pincel '#F4F0E6'; $SUB = Pincel '#A8A090'; $APAGADO = Pincel '#706850'

function Texto($t, $tam, $cor, [switch]$Ds, [switch]$Negrito, $margem = '0') {
    $x = New-Object System.Windows.Controls.TextBlock
    $x.Text = $t; $x.FontSize = $tam; $x.Foreground = $cor; $x.TextWrapping = 'Wrap'; $x.Margin = $margem
    if ($Ds) { $x.FontFamily = $FONTE_DS }
    if ($Negrito) { $x.FontWeight = 'Bold' }
    $x
}

# ---- janela: cobre o monitor principal ----
$tela = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$win = New-Object System.Windows.Window
$win.WindowStyle = 'None'; $win.AllowsTransparency = $true; $win.Background = [System.Windows.Media.Brushes]::Transparent
$win.Topmost = $true; $win.ShowInTaskbar = $false; $win.ResizeMode = 'NoResize'; $win.Title = 'Fogueira'
$win.Left = $tela.Left; $win.Top = $tela.Top; $win.Width = $tela.Width; $win.Height = $tela.Height
$raiz = New-Object System.Windows.Controls.Grid
$fundo = New-Object System.Windows.Shapes.Rectangle
$fundo.Fill = [System.Windows.Media.Brushes]::Black; $fundo.Opacity = 0
[void]$raiz.Children.Add($fundo)

# faixa escura + "BONFIRE LIT"
$faixa = New-Object System.Windows.Shapes.Rectangle
$faixa.Height = 150; $faixa.VerticalAlignment = 'Center'; $faixa.Opacity = 0
$gr = New-Object System.Windows.Media.LinearGradientBrush; $gr.StartPoint = '0,0.5'; $gr.EndPoint = '1,0.5'
foreach ($par in @(@('#00000000', 0), @('#E0000000', 0.3), @('#E0000000', 0.7), @('#00000000', 1))) {
    $gr.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString($par[0]), $par[1])))
}
$faixa.Fill = $gr
[void]$raiz.Children.Add($faixa)
$lit = Texto 'BONFIRE LIT' 72 (Pincel '#F0C46A') -Ds
$lit.HorizontalAlignment = 'Center'; $lit.VerticalAlignment = 'Center'; $lit.Opacity = 0
$brilho = New-Object System.Windows.Media.Effects.DropShadowEffect
$brilho.Color = [System.Windows.Media.ColorConverter]::ConvertFromString('#FF8020'); $brilho.ShadowDepth = 0; $brilho.BlurRadius = 28; $brilho.Opacity = 0.9
$lit.Effect = $brilho
$escala = New-Object System.Windows.Media.ScaleTransform(1.15, 1.15); $lit.RenderTransformOrigin = '0.5,0.5'; $lit.RenderTransform = $escala
[void]$raiz.Children.Add($lit)

# ---- quadro do resumo ----
$quadro = New-Object System.Windows.Controls.Border
$quadro.Width = 660; $quadro.HorizontalAlignment = 'Center'; $quadro.VerticalAlignment = 'Center'; $quadro.Opacity = 0
$quadro.Background = Pincel '#F2100C0A'; $quadro.BorderBrush = Pincel '#8A6A30'; $quadro.BorderThickness = 2; $quadro.CornerRadius = 4
$quadro.Padding = '28,18,28,16'; $quadro.Visibility = 'Hidden'
$interno = New-Object System.Windows.Controls.Border
$interno.BorderBrush = Pincel '#4A3A1C'; $interno.BorderThickness = 1; $interno.Padding = '18,10,18,12'
$pilha = New-Object System.Windows.Controls.StackPanel
$interno.Child = $pilha; $quadro.Child = $interno

# fogueira animada (8 quadros de 40x48, ampliada 3x sem borrar)
$bfImg = New-Object System.Windows.Media.Imaging.BitmapImage
$bfImg.BeginInit(); $bfImg.CacheOption = 'OnLoad'; $bfImg.UriSource = [Uri](Join-Path $PASTA 'bonfire.png'); $bfImg.EndInit(); $bfImg.Freeze()
$BQ = 8; $BW = [int]($bfImg.PixelWidth / $BQ)
$FB = @(0..($BQ - 1) | ForEach-Object { $c = New-Object System.Windows.Media.Imaging.CroppedBitmap($bfImg, (New-Object System.Windows.Int32Rect(($_ * $BW), 0, $BW, $bfImg.PixelHeight))); $c.Freeze(); $c })
$bf = New-Object System.Windows.Controls.Image
$bf.Width = $BW * 3; $bf.Height = $bfImg.PixelHeight * 3; $bf.Source = $FB[0]; $bf.HorizontalAlignment = 'Center'
[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($bf, 'NearestNeighbor')
[void]$pilha.Children.Add($bf)

$cult = New-Object System.Globalization.CultureInfo('pt-BR')
$t = Texto 'FOGUEIRA ACESA' 26 $OURO -Ds -Negrito '0,4,0,0'; $t.HorizontalAlignment = 'Center'; [void]$pilha.Children.Add($t)
$dia = (Get-Date).ToString("dddd, d 'de' MMMM", $cult)
$t = Texto $dia 12 $SUB '' '0,0,0,6'; $t.HorizontalAlignment = 'Center'; [void]$pilha.Children.Add($t)

function Secao($titulo) {
    $r = New-Object System.Windows.Shapes.Rectangle; $r.Height = 1; $r.Fill = Pincel '#4A3A1C'; $r.Margin = '0,10,0,6'
    [void]$pilha.Children.Add($r)
    [void]$pilha.Children.Add((Texto $titulo 15 $OURO -Ds -Negrito '0,0,0,4'))
}
function Linha($tag, $cor, $titulo, $faz) {
    $dp = New-Object System.Windows.Controls.DockPanel; $dp.Margin = '0,3,0,3'
    if ($tag) {
        $b = New-Object System.Windows.Controls.Border
        $b.Background = Pincel $cor; $b.CornerRadius = 3; $b.Padding = '6,1,6,1'; $b.Margin = '0,1,10,0'; $b.VerticalAlignment = 'Top'
        $b.Width = 92; $b.Child = (Texto $tag 10.5 $BRANCO -Negrito); $b.Child.TextAlignment = 'Center'
        [System.Windows.Controls.DockPanel]::SetDock($b, 'Left'); [void]$dp.Children.Add($b)
    }
    $sp = New-Object System.Windows.Controls.StackPanel
    [void]$sp.Children.Add((Texto $titulo 13 $BRANCO -Negrito))
    if ($faz) { [void]$sp.Children.Add((Texto $faz 11.5 $SUB)) }
    [void]$dp.Children.Add($sp); [void]$pilha.Children.Add($dp)
}

Secao "MENSAGENS DE HOJE ($($msgs.Count))"
if (-not $msgs.Count) { [void]$pilha.Children.Add((Texto 'Nenhuma mensagem no chão hoje. Pode descansar na fogueira.' 12 $SUB)) }
foreach ($m in ($msgs | Select-Object -First $MAX_HOJE)) {
    $h = try { ([datetime]$m.quando).ToString('HH:mm') } catch { '' }
    if ([string]$m.quando -lt (Get-Date).ToString('yyyy-MM-dd')) { $h = 'atrasada' }
    Linha $h '#8A4A1C' ([string]$m.texto) ''
}
if ($msgs.Count -gt $MAX_HOJE) { [void]$pilha.Children.Add((Texto "+ $($msgs.Count - $MAX_HOJE)" 11 $APAGADO '102,2,0,0')) }

foreach ($sec in @($dash.secoes)) {
    if (-not $sec -or -not $sec.titulo) { continue }
    $itens = @($sec.itens | Where-Object { $_ -and $_.titulo })
    Secao $(if ($itens.Count) { "$($sec.titulo) ($($itens.Count))" } else { [string]$sec.titulo })
    if ($sec.resumo) { [void]$pilha.Children.Add((Texto ([string]$sec.resumo) 13 $BRANCO -Negrito)) }
    elseif (-not $itens.Count) { [void]$pilha.Children.Add((Texto $(if ($sec.vazio) { [string]$sec.vazio } else { 'Nada por aqui.' }) 12 $SUB)) }
    foreach ($x in ($itens | Select-Object -First $MAX_HOJE)) {
        $cor = if ([string]$x.cor -match '^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$') { [string]$x.cor } else { '#8A4A1C' }
        Linha ([string]$x.tag) $cor ([string]$x.titulo) ([string]$x.detalhe)
    }
    if ($itens.Count -gt $MAX_HOJE) { [void]$pilha.Children.Add((Texto "+ $($itens.Count - $MAX_HOJE) no dash" 11 $APAGADO '102,2,0,0')) }
}
if ($dashErro) {
    Secao 'SEU DASH'
    [void]$pilha.Children.Add((Texto 'Não consegui ler o resumo do seu dash. Confira o "resumo" no meu_dash.json.' 12 $SUB))
}

if ($lim) {
    Secao 'LIMITE DO CLAUDE'
    $p = @()
    if ($lim.five_hour) { $p += "5 horas: $([math]::Round($lim.five_hour.used_percentage))% usado" }
    if ($lim.seven_day) { $p += "semana: $([math]::Round($lim.seven_day.used_percentage))% usado" }
    [void]$pilha.Children.Add((Texto ($p -join ' · ') 13 $BRANCO -Negrito))
}

# botões
$bt = New-Object System.Windows.Controls.StackPanel; $bt.Orientation = 'Horizontal'; $bt.HorizontalAlignment = 'Center'; $bt.Margin = '0,16,0,0'
function Botao($txt, $acao) {
    $b = New-Object System.Windows.Controls.Border
    $b.BorderBrush = Pincel '#8A6A30'; $b.BorderThickness = 1; $b.CornerRadius = 3; $b.Padding = '16,5,16,5'; $b.Margin = '8,0,8,0'
    $b.Background = Pincel '#20E8C060'; $b.Cursor = [System.Windows.Input.Cursors]::Hand
    $b.Child = (Texto $txt 13 $OURO -Ds -Negrito); $b.Tag = $acao
    $b.Add_MouseEnter({ $this.Background = Pincel '#40E8C060' }); $b.Add_MouseLeave({ $this.Background = Pincel '#20E8C060' })
    $b.Add_MouseLeftButtonUp({ param($s, $e) $e.Handled = $true; & $this.Tag })
    [void]$bt.Children.Add($b)
}
if ($cfg -and $cfg.abrir) { Botao 'Abrir o dash' { try { Start-Process ([string]$cfg.abrir) } catch {}; Fechar } }
Botao 'Levantar' { Fechar }
[void]$pilha.Children.Add($bt)
$t = Texto 'clique fora do quadro ou Esc para levantar da fogueira' 10.5 $APAGADO '' '0,8,0,0'; $t.HorizontalAlignment = 'Center'; [void]$pilha.Children.Add($t)
[void]$raiz.Children.Add($quadro)
$win.Content = $raiz

# ---- animação ----
# 0-0,8 s escurece e acende o texto; segura até 2,6 s; 2,6-3,2 s apaga o texto e o quadro aparece. Fechar = 0,4 s de fade.
$script:t = 0.0; $script:fechando = -1.0
function Fechar { if ($script:fechando -lt 0) { $script:fechando = $script:t } }
if ($SemAnimacao) { $script:t = 3.2 }
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(33)
$LOG = Join-Path $PASTA 'fogueira.log'
$timer.Add_Tick({ try {
    $script:t += 0.033; $u = $script:t
    $bf.Source = $FB[[int][math]::Floor($u * 8) % $BQ]
    if ($script:fechando -ge 0) {
        $k = [math]::Max([double]0.0, 1 - ($u - $script:fechando) / 0.4)
        $win.Opacity = $k
        if ($k -le 0) { $timer.Stop(); $win.Close() }
        return
    }
    $fundo.Opacity = [math]::Min([double]0.82, $u / 0.8 * 0.82)
    if ($u -lt 2.6) {
        $a = [math]::Min([double]1.0, [math]::Max([double]0.0, ($u - 0.2) / 0.6))
        $lit.Opacity = $a; $faixa.Opacity = $a
        $s = 1.15 - 0.15 * $a + 0.03 * [math]::Max([double]0.0, $u - 0.8) / 1.8; $escala.ScaleX = $s; $escala.ScaleY = $s
        $brilho.BlurRadius = 22 + 8 * [math]::Sin($u * 5)
    } else {
        $a = [math]::Max([double]0.0, 1 - ($u - 2.6) / 0.6)
        $lit.Opacity = $a; $faixa.Opacity = $a
        if ($quadro.Visibility -ne 'Visible') { $quadro.Visibility = 'Visible' }
        $quadro.Opacity = 1 - $a
    }
} catch { Add-Content $LOG "$(Get-Date -f 'dd/MM HH:mm:ss') $($_.Exception.Message) @ $($_.InvocationInfo.ScriptLineNumber)"; $timer.Stop(); $win.Close() } })
$win.Add_MouseLeftButtonUp({ param($s, $e)
    if ($script:t -lt 2.6) { $script:t = 2.6; return }                         # clique na animação: pula pro resumo
    $p = $e.GetPosition($quadro)
    if ($p.X -lt 0 -or $p.Y -lt 0 -or $p.X -gt $quadro.ActualWidth -or $p.Y -gt $quadro.ActualHeight) { Fechar }
})
$win.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { Fechar } })
$win.Dispatcher.Add_UnhandledException({ param($s, $e) Add-Content $LOG "$(Get-Date -f 'dd/MM HH:mm:ss') $($e.Exception.Message)" })
$win.Add_Closed({ [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() })
$win.Show(); [void]$win.Activate()
$timer.Start()
[System.Windows.Threading.Dispatcher]::Run()
