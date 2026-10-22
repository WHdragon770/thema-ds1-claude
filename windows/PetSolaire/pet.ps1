# Pet de tela: o Solaire anda em cima da barra de tarefas de cada monitor, para, olha para você, fica de costas, vira ao
# mudar de direção, escala a borda de fora da tela e as janelas abertas (sobe na lateral, anda em cima, pula de volta;
# se a janela mexer ele vai junto, se fechar ele cai) e de vez em quando some uns minutos e volta.
# Arrastar com o botão esquerdo (ao soltar, volta planando até a borda mais próxima); botão direito abre o menu
# (fogueira, painel, Claude novo, escrever mensagem, dispensar). Arquivo arrastado em cima dele abre um Claude com o arquivo.
# Fala frases do jogo num balão; quando chega um aviso de tarefa concluída (pasta $AVISOS) o sol aparece com o nome da
# tarefa e ele faz Praise the Sun; o aviso fica até fechar no ×. Aviso tipo 'invasao' (solaire_aviso ... invasao <link>) abre a faixa vermelha
# "VOCÊ FOI INVADIDO" e ele fica em guarda com espada e escudo até você abrir (clique) ou fechar cada caso.
# Sprites: UMA imagem (spritesheet.png) em grade de $COLUNAS x $LINHAS.Count, na ordem de $LINHAS (ver LEIA-ME).

# ======== CONFIGURAÇÃO ========
$SHEET      = 'spritesheet.png'                              # na mesma pasta deste script
$COLUNAS    = 8                                              # colunas da grade (o máximo de quadros de uma linha)
$LINHAS     = 'frente', 'costas', 'direita', 'esquerda', 'parado', 'louvor', 'tonto', 'escalar', 'escalar_e', 'combate'   # o que cada linha mostra, de cima para baixo
$QUADROS    = @{ frente = 8; costas = 8; direita = 8; esquerda = 8; parado = 8; louvor = 8; tonto = 8; escalar = 8; escalar_e = 8; combate = 8 }   # quadros usados de cada linha
$SOL        = 'sol.png'                                      # o sol que aparece no Praise the Sun (quadros lado a lado, quadrados)
$LOUVOR     = 0.3                                            # chance de fazer Praise the Sun quando termina uma caminhada
$ANIM_FPS   = 8                                              # velocidade da animação (quadros por segundo)
$K          = 2                                              # ampliação (2 = cada pixel vira 2x2, sem borrar)
$K_SOL      = 2                                              # ampliação do sol
$VELOCIDADE = 70                                             # px/s andando
$ESCALADA   = 45                                             # px/s escalando
$SUBIR_JANELA = 0.22                                         # chance de ir escalar uma janela aberta quando para de andar
$SUBIR_TELA = 0.12                                           # chance de ir escalar a borda de fora da tela
$SUMIR      = $false                                         # some de vez em quando (10-25 min) e volta 3-10 min depois
$FALA_CADA  = 40, 120                                        # fala uma frase a cada 40-120 s (balão por cima dele)
$FALAS = @(                                                  # o que o Solaire diz no jogo
    'Louvado seja o Sol! \[T]/'
    'Ah, olá! Você não parece Oco. Muito pelo contrário!'
    'Eu sou Solaire de Astora, seguidor do Senhor da Luz Solar.'
    'Agora que sou Morto-Vivo, vim à terra de Lorde Gwyn para encontrar o meu próprio sol!'
    'O sol é um corpo maravilhoso. Como um pai magnífico!'
    'Se ao menos eu pudesse ser tão grandiosamente incandescente!'
    'Vamos ajudar um ao outro. Uma cooperação animada!'
    'Nossos destinos parecem entrelaçados. Numa terra cheia de Ocos, será que é só acaso?'
    'O próprio fluxo do tempo é confuso: heróis de séculos atrás aparecem e somem.'
    'Eu consegui... Encontrei... Encontrei o meu próprio sol!'
    'Hahahaha!'
)
# avisos de tarefa concluída: arquivos .json {titulo, texto, tipo} nesta pasta (ver ~/bin/solaire_aviso no WSL)
$AVISOS     = Join-Path $env:LOCALAPPDATA 'PetSolaire\avisos'
# ==============================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\PetSolaire', [ref]$created)
if (-not $created) { exit }
$FPS = 30
$rnd = New-Object System.Random

# ---- quadros: recorta a grade da spritesheet ----
$sheetImg = New-Object System.Windows.Media.Imaging.BitmapImage
$sheetImg.BeginInit(); $sheetImg.CacheOption = 'OnLoad'; $sheetImg.UriSource = [Uri](Join-Path $PSScriptRoot $SHEET); $sheetImg.EndInit(); $sheetImg.Freeze()
$CW = [int][math]::Floor($sheetImg.PixelWidth / $COLUNAS); $CH = [int][math]::Floor($sheetImg.PixelHeight / $LINHAS.Count)
$F = @{}
for ($l = 0; $l -lt $LINHAS.Count; $l++) {
    $n = if ($QUADROS.ContainsKey($LINHAS[$l])) { $QUADROS[$LINHAS[$l]] } else { $COLUNAS }
    $F[$LINHAS[$l]] = @(0..($n - 1) | ForEach-Object {
        $c = New-Object System.Windows.Media.Imaging.CroppedBitmap($sheetImg, (New-Object System.Windows.Int32Rect(($_ * $CW), ($l * $CH), $CW, $CH)))
        $c.Freeze(); $c
    })
}
$PW = $CW * $K; $PH = $CH * $K          # tamanho do bicho na tela

$win = New-Object System.Windows.Window
$win.WindowStyle = 'None'; $win.AllowsTransparency = $true; $win.Background = [System.Windows.Media.Brushes]::Transparent
$win.Topmost = $true; $win.ShowInTaskbar = $false; $win.ShowActivated = $false; $win.ResizeMode = 'NoResize'
$win.Width = $PW; $win.Height = $PH
$win.Title = 'PetSolaire'
$img = New-Object System.Windows.Controls.Image
$img.Width = $PW; $img.Height = $PH; $img.Stretch = 'Fill'
[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($img, 'NearestNeighbor')
$win.Content = $img

# ---- o sol (janela própria, aparece acima dele no Praise the Sun) ----
$solImg = New-Object System.Windows.Media.Imaging.BitmapImage
$solImg.BeginInit(); $solImg.CacheOption = 'OnLoad'; $solImg.UriSource = [Uri](Join-Path $PSScriptRoot $SOL); $solImg.EndInit(); $solImg.Freeze()
$SL = $solImg.PixelHeight; $SQ = [int][math]::Floor($solImg.PixelWidth / $SL)
$FS = @(0..($SQ - 1) | ForEach-Object { $c = New-Object System.Windows.Media.Imaging.CroppedBitmap($solImg, (New-Object System.Windows.Int32Rect(($_ * $SL), 0, $SL, $SL))); $c.Freeze(); $c })
$SW = $SL * $K_SOL
$sunWin = New-Object System.Windows.Window
$sunWin.WindowStyle = 'None'; $sunWin.AllowsTransparency = $true; $sunWin.Background = [System.Windows.Media.Brushes]::Transparent
$sunWin.Topmost = $true; $sunWin.ShowInTaskbar = $false; $sunWin.ShowActivated = $false; $sunWin.ResizeMode = 'NoResize'
$sunWin.Width = $SW; $sunWin.Height = $SW; $sunWin.Title = 'PetSolaire sol'; $sunWin.IsHitTestVisible = $false
$solView = New-Object System.Windows.Controls.Image
$solView.Width = $SW; $solView.Height = $SW; $solView.Stretch = 'Fill'; $solView.Source = $FS[0]
[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($solView, 'NearestNeighbor')
$sunWin.Content = $solView

$FONTE_DS = New-Object System.Windows.Media.FontFamily('Cinzel, Palatino Linotype, Georgia')
function Pincel($hex) { $p = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($hex)); $p.Freeze(); $p }
function Janela-Flutuante {
    $w = New-Object System.Windows.Window
    $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Background = [System.Windows.Media.Brushes]::Transparent
    $w.Topmost = $true; $w.ShowInTaskbar = $false; $w.ShowActivated = $false; $w.ResizeMode = 'NoResize'; $w.SizeToContent = 'WidthAndHeight'
    $w
}

# ---- aviso de tarefa concluída: o sol + o nome de cada tarefa, cada uma com o seu × (fica até você fechar) ----
$avisoWin = Janela-Flutuante; $avisoWin.Title = 'PetSolaire aviso'
$avBorda = New-Object System.Windows.Controls.Border
$avBorda.Background = Pincel '#F0141210'; $avBorda.BorderBrush = Pincel '#C8A04A'; $avBorda.BorderThickness = 2
$avBorda.CornerRadius = 4; $avBorda.Padding = '12,6,12,10'
$avPilha = New-Object System.Windows.Controls.StackPanel
$avSol = New-Object System.Windows.Controls.Image
$avSol.Width = $SW; $avSol.Height = $SW; $avSol.Stretch = 'Fill'; $avSol.Source = $FS[0]; $avSol.HorizontalAlignment = 'Center'
[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($avSol, 'NearestNeighbor')
$avTitulo = New-Object System.Windows.Controls.TextBlock
$avTitulo.Text = 'TAREFA CONCLUÍDA'; $avTitulo.FontFamily = $FONTE_DS; $avTitulo.FontSize = 17; $avTitulo.FontWeight = 'Bold'
$avTitulo.Foreground = Pincel '#E8C060'; $avTitulo.HorizontalAlignment = 'Center'; $avTitulo.Margin = '0,2,0,6'
$avLista = New-Object System.Windows.Controls.StackPanel
[void]$avPilha.Children.Add($avSol); [void]$avPilha.Children.Add($avTitulo); [void]$avPilha.Children.Add($avLista)
$avBorda.Child = $avPilha; $avisoWin.Content = $avBorda
$script:avisoPos = $false

function Posicionar-Aviso {
    $avisoWin.UpdateLayout()
    $w = $avisoWin.ActualWidth; $h = $avisoWin.ActualHeight
    $tela = $telas[-1]; foreach ($tt in $telas) { if ($script:x -lt $tt.Bounds.Right) { $tela = $tt; break } }
    $wa = $tela.WorkingArea
    $ax = $script:x - $w / 2; $ay = $script:y - $PH - $h - 48                 # deixa espaço para o balão de fala
    if ($ay -lt $wa.Top) { $ay = $script:y + 8 }                               # no topo da tela: embaixo dele
    $avisoWin.Left = [math]::Max($wa.Left, [math]::Min($wa.Right - $w, $ax))
    $avisoWin.Top = [math]::Max($wa.Top, [math]::Min($wa.Bottom - $h, $ay))
}

function Novo-Aviso($titulo, $texto, $tipo) {
    $linha = New-Object System.Windows.Controls.DockPanel; $linha.Margin = '0,3,0,3'; $linha.LastChildFill = $true
    $x = New-Object System.Windows.Controls.TextBlock
    $x.Text = [string][char]0x2715; $x.FontSize = 15; $x.Foreground = Pincel '#B0A890'; $x.Margin = '12,0,0,0'
    $x.Cursor = [System.Windows.Input.Cursors]::Hand; $x.VerticalAlignment = 'Top'; $x.Padding = '4,0,2,0'
    $x.ToolTip = 'Fechar'
    [System.Windows.Controls.DockPanel]::SetDock($x, 'Right')
    $x.Add_MouseEnter({ $this.Foreground = Pincel '#FF6040' }); $x.Add_MouseLeave({ $this.Foreground = Pincel '#B0A890' })
    $x.Add_MouseLeftButtonUp({
        $avLista.Children.Remove($this.Parent)
        if ($avLista.Children.Count -eq 0) { $avisoWin.Hide(); $script:avisoPos = $false } else { $avisoWin.UpdateLayout() }
    })
    $txt = New-Object System.Windows.Controls.StackPanel; $txt.MaxWidth = 300
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = $(if ($tipo -eq 'erro') { 'ERRO: ' } else { '' }) + $titulo
    $t1.FontFamily = $FONTE_DS; $t1.FontSize = 14; $t1.FontWeight = 'Bold'; $t1.TextWrapping = 'Wrap'
    $t1.Foreground = Pincel $(if ($tipo -eq 'erro') { '#FF5A4A' } else { '#FFFFFF' })
    [void]$txt.Children.Add($t1)
    if ($texto) {
        $t2 = New-Object System.Windows.Controls.TextBlock
        $t2.Text = $texto; $t2.FontSize = 11; $t2.Foreground = Pincel '#A8A090'; $t2.TextWrapping = 'Wrap'; $t2.Margin = '0,1,0,0'
        [void]$txt.Children.Add($t2)
    }
    $hora = New-Object System.Windows.Controls.TextBlock
    $hora.Text = (Get-Date).ToString('HH:mm'); $hora.FontSize = 10; $hora.Foreground = Pincel '#807860'
    [void]$txt.Children.Add($hora)
    [void]$linha.Children.Add($x); [void]$linha.Children.Add($txt)
    [void]$avLista.Children.Add($linha)
    while ($avLista.Children.Count -gt 6) { $avLista.Children.RemoveAt(0) }   # no máximo 6 na lista
    $avisoWin.Show()
    if (-not $script:avisoPos) { Posicionar-Aviso; $script:avisoPos = $true } else { $avisoWin.UpdateLayout() }
}

# ---- invasão (algo urgente chegou, ex.: reclamação nova): faixa vermelha, ele fica em guarda até você abrir o caso ----
$invWin = Janela-Flutuante; $invWin.Title = 'PetSolaire invasao'
$invBorda = New-Object System.Windows.Controls.Border
$invBorda.Background = Pincel '#F0180606'; $invBorda.BorderBrush = Pincel '#B0281C'; $invBorda.BorderThickness = 2
$invBorda.CornerRadius = 4; $invBorda.Padding = '14,8,12,10'
$invPilha = New-Object System.Windows.Controls.StackPanel
$invTitulo = New-Object System.Windows.Controls.TextBlock
$invTitulo.Text = 'VOCÊ FOI INVADIDO'; $invTitulo.FontFamily = $FONTE_DS; $invTitulo.FontSize = 19; $invTitulo.FontWeight = 'Bold'
$invTitulo.Foreground = Pincel '#E0402C'; $invTitulo.HorizontalAlignment = 'Center'; $invTitulo.Margin = '0,0,0,1'
$invSub = New-Object System.Windows.Controls.TextBlock
$invSub.Text = 'clique no caso para abrir'; $invSub.FontSize = 10; $invSub.Foreground = Pincel '#A07060'
$invSub.HorizontalAlignment = 'Center'; $invSub.Margin = '0,0,0,6'
$invLista = New-Object System.Windows.Controls.StackPanel
[void]$invPilha.Children.Add($invTitulo); [void]$invPilha.Children.Add($invSub); [void]$invPilha.Children.Add($invLista)
$invBorda.Child = $invPilha; $invWin.Content = $invBorda
$script:invPos = $false

function Tirar-Invasao($linha) {
    $invLista.Children.Remove($linha)
    if ($invLista.Children.Count -eq 0) { $invWin.Hide(); $script:invPos = $false; Falar 'O invasor foi derrotado! Louvado seja o Sol!' 4 } else { $invWin.UpdateLayout() }
}

function Posicionar-Invasao {
    $invWin.UpdateLayout()
    $w = $invWin.ActualWidth; $h = $invWin.ActualHeight
    $wa = (TelaEm $script:x).WorkingArea
    $ax = $script:x - $w / 2; $ay = $script:y - $PH - $h - 48
    if ($avisoWin.IsVisible) { $ax = $avisoWin.Left - $w - 10; if ($ax -lt $wa.Left) { $ax = $avisoWin.Left + $avisoWin.ActualWidth + 10 } }
    if ($ay -lt $wa.Top) { $ay = $script:y + 8 }
    $invWin.Left = [math]::Max($wa.Left, [math]::Min($wa.Right - $w, $ax))
    $invWin.Top = [math]::Max($wa.Top, [math]::Min($wa.Bottom - $h, $ay))
}

function Nova-Invasao($titulo, $texto, $link) {
    $linha = New-Object System.Windows.Controls.DockPanel; $linha.Margin = '0,3,0,3'; $linha.LastChildFill = $true
    $x = New-Object System.Windows.Controls.TextBlock
    $x.Text = [string][char]0x2715; $x.FontSize = 15; $x.Foreground = Pincel '#B08070'; $x.Margin = '12,0,0,0'
    $x.Cursor = [System.Windows.Input.Cursors]::Hand; $x.VerticalAlignment = 'Top'; $x.Padding = '4,0,2,0'; $x.ToolTip = 'Fechar'
    [System.Windows.Controls.DockPanel]::SetDock($x, 'Right')
    $x.Add_MouseEnter({ $this.Foreground = Pincel '#FF6040' }); $x.Add_MouseLeave({ $this.Foreground = Pincel '#B08070' })
    $x.Add_MouseLeftButtonUp({ Tirar-Invasao $this.Parent })
    $txt = New-Object System.Windows.Controls.StackPanel; $txt.MaxWidth = 320; $txt.Tag = $link
    if ($link) { $txt.Cursor = [System.Windows.Input.Cursors]::Hand; $txt.ToolTip = 'Abrir' }
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = $titulo; $t1.FontFamily = $FONTE_DS; $t1.FontSize = 14; $t1.FontWeight = 'Bold'; $t1.TextWrapping = 'Wrap'
    $t1.Foreground = Pincel '#FFFFFF'
    [void]$txt.Children.Add($t1)
    if ($texto) {
        $t2 = New-Object System.Windows.Controls.TextBlock
        $t2.Text = $texto; $t2.FontSize = 11; $t2.Foreground = Pincel '#C0A090'; $t2.TextWrapping = 'Wrap'; $t2.Margin = '0,1,0,0'
        [void]$txt.Children.Add($t2)
    }
    $hora = New-Object System.Windows.Controls.TextBlock
    $hora.Text = (Get-Date).ToString('HH:mm'); $hora.FontSize = 10; $hora.Foreground = Pincel '#806050'
    [void]$txt.Children.Add($hora)
    $txt.Add_MouseEnter({ $this.Children[0].Foreground = Pincel '#FFD080' }); $txt.Add_MouseLeave({ $this.Children[0].Foreground = Pincel '#FFFFFF' })
    $txt.Add_MouseLeftButtonUp({
        if ($this.Tag) { try { Start-Process ([string]$this.Tag) } catch {} }
        Tirar-Invasao $this.Parent
    })
    [void]$linha.Children.Add($x); [void]$linha.Children.Add($txt)
    [void]$invLista.Children.Add($linha)
    while ($invLista.Children.Count -gt 6) { $invLista.Children.RemoveAt(0) }
    $invWin.Show()
    if (-not $script:invPos) { Posicionar-Invasao; $script:invPos = $true } else { $invWin.UpdateLayout() }
}

# ---- mensagens de orange soapstone (lembretes): marca laranja no chão + a mensagem; ~/bin/lembrete no WSL grava ----
$LEMBRETES = Join-Path $env:LOCALAPPDATA 'PetSolaire\lembretes'
New-Item -ItemType Directory -Force -Path $LEMBRETES | Out-Null
$ssImg = New-Object System.Windows.Media.Imaging.BitmapImage
$ssImg.BeginInit(); $ssImg.CacheOption = 'OnLoad'; $ssImg.UriSource = [Uri](Join-Path $PSScriptRoot 'soapstone.png'); $ssImg.EndInit(); $ssImg.Freeze()
$SSQ = 6; $SSW = [int]($ssImg.PixelWidth / $SSQ); $SSH = $ssImg.PixelHeight
$FSS = @(0..($SSQ - 1) | ForEach-Object { $c = New-Object System.Windows.Media.Imaging.CroppedBitmap($ssImg, (New-Object System.Windows.Int32Rect(($_ * $SSW), 0, $SSW, $SSH))); $c.Freeze(); $c })
$marcaWin = Janela-Flutuante; $marcaWin.Title = 'PetSolaire marca'; $marcaWin.SizeToContent = 'Manual'
$marcaWin.Width = $SSW * 2; $marcaWin.Height = $SSH * 2
$marcaImg = New-Object System.Windows.Controls.Image; $marcaImg.Width = $SSW * 2; $marcaImg.Height = $SSH * 2; $marcaImg.Stretch = 'Fill'; $marcaImg.Source = $FSS[0]
[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($marcaImg, 'NearestNeighbor')
$marcaWin.Content = $marcaImg; $marcaWin.Cursor = [System.Windows.Input.Cursors]::Hand; $marcaWin.ToolTip = 'Ler a mensagem'
$marcaWin.Add_MouseLeftButtonUp({ if ($msgLista.Children.Count) { $msgWin.Show(); Posicionar-Msg } })
$script:marcaX = 0; $script:mostrando = @{}

$msgWin = Janela-Flutuante; $msgWin.Title = 'PetSolaire mensagem'
$msgBorda = New-Object System.Windows.Controls.Border
$msgBorda.Background = Pincel '#F2100A06'; $msgBorda.BorderBrush = Pincel '#D07A28'; $msgBorda.BorderThickness = 2; $msgBorda.CornerRadius = 4
$msgBorda.Padding = '16,8,12,10'; $msgBorda.Margin = '14'
$msgBrilho = New-Object System.Windows.Media.Effects.DropShadowEffect
$msgBrilho.Color = [System.Windows.Media.ColorConverter]::ConvertFromString('#FF8A30'); $msgBrilho.ShadowDepth = 0; $msgBrilho.BlurRadius = 18; $msgBrilho.Opacity = 0.8
$msgBorda.Effect = $msgBrilho
$msgLista = New-Object System.Windows.Controls.StackPanel
$msgBorda.Child = $msgLista; $msgWin.Content = $msgBorda

function Posicionar-Msg {
    $msgWin.UpdateLayout()
    $w = $msgWin.ActualWidth; $h = $msgWin.ActualHeight
    $wa = (TelaEm $script:marcaX).WorkingArea
    $ax = $script:marcaX - $w / 2; $ay = $wa.Bottom - $PH - $h - 40
    if ($invWin.IsVisible) { $ay = [math]::Min($ay, $invWin.Top - $h - 6) }
    $msgWin.Left = [math]::Max($wa.Left, [math]::Min($wa.Right - $w, $ax)); $msgWin.Top = [math]::Max($wa.Top, $ay)
}
function Tirar-Msg($linha) {
    $script:mostrando.Remove($linha.Tag); $msgLista.Children.Remove($linha)
    if ($msgLista.Children.Count -eq 0) { $msgWin.Hide(); $marcaWin.Hide() } else { Posicionar-Msg }
}
function Botao-Msg($txt, $acao) {
    $b = New-Object System.Windows.Controls.Border
    $b.BorderBrush = Pincel '#8A5A28'; $b.BorderThickness = 1; $b.CornerRadius = 3; $b.Padding = '10,2,10,2'; $b.Margin = '0,0,8,0'
    $b.Background = Pincel '#20FF8A30'; $b.Cursor = [System.Windows.Input.Cursors]::Hand; $b.Tag = $acao
    $t = New-Object System.Windows.Controls.TextBlock; $t.Text = $txt; $t.FontFamily = $FONTE_DS; $t.FontSize = 12; $t.FontWeight = 'Bold'; $t.Foreground = Pincel '#FFB060'
    $b.Child = $t
    $b.Add_MouseEnter({ $this.Background = Pincel '#40FF8A30' }); $b.Add_MouseLeave({ $this.Background = Pincel '#20FF8A30' })
    $b.Add_MouseLeftButtonUp({ & $this.Tag $this })
    $b
}
function Adiar($bt, $min) {
    $linha = $bt.Parent.Parent; $arq = Join-Path $LEMBRETES ($linha.Tag + '.json')
    try {
        $j = [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $j.quando = (Get-Date).AddMinutes($min).ToString('yyyy-MM-ddTHH:mm')
        [System.IO.File]::WriteAllText($arq, ($j | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false)))
    } catch {}
    Tirar-Msg $linha
}
function Nova-Msg($j) {
    $linha = New-Object System.Windows.Controls.StackPanel; $linha.Margin = '0,4,0,6'; $linha.Tag = [string]$j.id; $linha.MaxWidth = 340
    if ($msgLista.Children.Count) { $r = New-Object System.Windows.Shapes.Rectangle; $r.Height = 1; $r.Fill = Pincel '#4A2E14'; $r.Margin = '0,0,0,6'; [void]$linha.Children.Add($r) }
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = [string]$j.texto; $t1.FontFamily = $FONTE_DS; $t1.FontSize = 16; $t1.FontWeight = 'Bold'; $t1.TextWrapping = 'Wrap'; $t1.Foreground = Pincel '#F6E8CC'
    [void]$linha.Children.Add($t1)
    $hq = try { ([datetime]$j.quando).ToString('dd/MM HH:mm') } catch { [string]$j.quando }
    $t2 = New-Object System.Windows.Controls.TextBlock; $t2.Text = "mensagem marcada pra $hq"; $t2.FontSize = 10.5; $t2.Foreground = Pincel '#C08040'; $t2.Margin = '0,1,0,5'
    [void]$linha.Children.Add($t2)
    $bts = New-Object System.Windows.Controls.StackPanel; $bts.Orientation = 'Horizontal'
    [void]$bts.Children.Add((Botao-Msg 'Feito' { param($b) $l = $b.Parent.Parent; Remove-Item (Join-Path $LEMBRETES ($l.Tag + '.json')) -ErrorAction SilentlyContinue; Tirar-Msg $l; Falar 'Muito bem! Louvado seja o Sol!' 3 }))
    [void]$bts.Children.Add((Botao-Msg '+10 min' { param($b) Adiar $b 10 }))
    [void]$bts.Children.Add((Botao-Msg '+1 h' { param($b) Adiar $b 60 }))
    [void]$linha.Children.Add($bts)
    $script:mostrando[[string]$j.id] = $true
    $primeira = -not $marcaWin.IsVisible
    [void]$msgLista.Children.Add($linha)
    if ($primeira) {                                                            # marca no chão do lado dele
        $wa = (TelaEm $script:x).WorkingArea
        $script:marcaX = if ($script:x + 120 -lt $wa.Right - 60) { $script:x + 120 } else { $script:x - 120 }
        $marcaWin.Left = [math]::Round($script:marcaX - $marcaWin.Width / 2); $marcaWin.Top = [math]::Round($wa.Bottom - $marcaWin.Height + 6)
        $marcaWin.Show()
    }
    $msgWin.Show(); Posicionar-Msg
    Falar 'Olha, uma mensagem escrita no chão!' 4
}
function Checar-Lembretes {
    $agora = (Get-Date).ToString('yyyy-MM-ddTHH:mm')
    foreach ($arq in @(Get-ChildItem $LEMBRETES -Filter *.json -ErrorAction SilentlyContinue)) {
        if ($script:mostrando.ContainsKey($arq.BaseName)) { continue }
        try {
            $j = [System.IO.File]::ReadAllText($arq.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            if ([string]$j.quando -le $agora) { Nova-Msg $j }
        } catch {}
    }
}
# escrever uma mensagem pelo menu: texto + quando (o mesmo formato do ~/bin/lembrete)
function Escrever-Msg {
    $e = New-Object System.Windows.Window
    $e.WindowStyle = 'None'; $e.AllowsTransparency = $true; $e.Background = [System.Windows.Media.Brushes]::Transparent
    $e.Topmost = $true; $e.ShowInTaskbar = $false; $e.ResizeMode = 'NoResize'; $e.SizeToContent = 'WidthAndHeight'; $e.Title = 'PetSolaire escrever'
    $bo = New-Object System.Windows.Controls.Border; $bo.Background = Pincel '#F4100A06'; $bo.BorderBrush = Pincel '#D07A28'; $bo.BorderThickness = 2
    $bo.CornerRadius = 4; $bo.Padding = '16,10,16,12'; $bo.Width = 380
    $sp = New-Object System.Windows.Controls.StackPanel
    function Rot($t) { $x = New-Object System.Windows.Controls.TextBlock; $x.Text = $t; $x.FontFamily = $FONTE_DS; $x.FontSize = 12; $x.Foreground = Pincel '#FFB060'; $x.Margin = '0,6,0,2'; $x }
    function Caixa($t) { $x = New-Object System.Windows.Controls.TextBox; $x.Text = $t; $x.FontSize = 14; $x.Background = Pincel '#2A1C10'; $x.Foreground = Pincel '#F6E8CC'
        $x.BorderBrush = Pincel '#8A5A28'; $x.CaretBrush = Pincel '#FFB060'; $x.Padding = '4,3,4,3'; $x }
    $ti = New-Object System.Windows.Controls.TextBlock; $ti.Text = 'ESCREVER MENSAGEM'; $ti.FontFamily = $FONTE_DS; $ti.FontSize = 15; $ti.FontWeight = 'Bold'; $ti.Foreground = Pincel '#F6E8CC'
    [void]$sp.Children.Add($ti)
    $script:escWin = $e
    [void]$sp.Children.Add((Rot 'Mensagem')); $cx = Caixa ''; $script:escCx = $cx; $cx.TextWrapping = 'Wrap'; [void]$sp.Children.Add($cx)
    [void]$sp.Children.Add((Rot 'Quando (15h, 15:30, amanhã 9h, 24/10 10h, +30m)')); $cq = Caixa '+30m'; $script:escCq = $cq; [void]$sp.Children.Add($cq)
    $st = New-Object System.Windows.Controls.TextBlock; $st.FontSize = 11; $st.Foreground = Pincel '#C08040'; $st.Margin = '0,6,0,0'; $st.TextWrapping = 'Wrap'
    [void]$sp.Children.Add($st); $script:escSt = $st
    $bts = New-Object System.Windows.Controls.StackPanel; $bts.Orientation = 'Horizontal'; $bts.Margin = '0,10,0,0'
    [void]$bts.Children.Add((Botao-Msg 'Gravar' { Gravar-Msg }))
    [void]$bts.Children.Add((Botao-Msg 'Cancelar' { $script:escWin.Close() }))
    [void]$sp.Children.Add($bts)
    $bo.Child = $sp; $e.Content = $bo
    $e.Add_KeyDown({ param($snd, $k) if ($k.Key -eq 'Escape') { $this.Close() } elseif ($k.Key -eq 'Return') { Gravar-Msg } })
    $pos = [System.Windows.Forms.Cursor]::Position; $wa = (TelaEm $pos.X).WorkingArea
    $e.Left = [math]::Max($wa.Left, [math]::Min($wa.Right - 400, $pos.X - 190)); $e.Top = [math]::Max($wa.Top, $wa.Bottom - $PH - 260)
    $e.Show(); [void]$e.Activate(); [void]$cx.Focus()
}
function Gravar-Msg {
    $cx = $script:escCx; $cq = $script:escCq; $st = $script:escSt; $e = $script:escWin
    if (1) {
        $txt = ($cx.Text -replace '["\r\n]', ' ').Trim(); $q = ($cq.Text -replace '"', '').Trim()
        if (-not $txt) { $st.Text = 'Escreva a mensagem.'; return }
        $out = Join-Path $env:TEMP 'lembrete_saida.txt'
        try {
            Start-Process wsl.exe -ArgumentList "-e __HOME__/bin/lembrete `"$q`" `"$txt`"" -WindowStyle Hidden -Wait -RedirectStandardOutput $out -RedirectStandardError "$out.err"
            $r = (Get-Content $out -Encoding UTF8 -Raw) + (Get-Content "$out.err" -Encoding UTF8 -Raw)
        } catch { $r = 'não consegui chamar o WSL' }
        if ($r -match '^lembrete') { $e.Close(); Falar ('Mensagem escrita! ' + ($r -replace '^lembrete \d+ marcado pra ([^:]+:\d+).*', 'Pra $1.')) 4 }
        else { $st.Text = ($r -replace '\s+$', '') }
    }
}

# ---- menu do clique direito (estilo menu do Dark Souls) ----
$LISTA = Join-Path $env:LOCALAPPDATA 'PetSolaire\arrastar.txt'
function Claude-Novo($modo, $lista) {
    $a = "-e __HOME__/bin/solaire_claude $modo"; if ($lista) { $a += " $lista" }
    try { Start-Process wsl.exe -ArgumentList $a -WindowStyle Hidden } catch {}
    Falar 'Vou chamar ajuda! Uma cooperação animada!' 3
}
$MENU = @(
    ,@('Fogueira do dia', { try { Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "__THEMA_WIN__\Fogueira\fogueira.ps1" -SemAnimacao' } catch {} })
    ,@('Painel do Claude', { try { Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "__THEMA_WIN__\painel_claude.ps1" -Distro __DISTRO__' } catch {} })
    ,@('Novo Claude', { Claude-Novo 'novo' })
    ,@('Escrever mensagem', { Escrever-Msg })
    '-'
    ,@('Louvar o Sol', { Louvar })
    ,@('Dispensar o Solaire', { $win.Close() })
)
$menuWin = $null
function Menu-DS($titulo, $itens) {
    if ($menuWin) { try { $menuWin.Close() } catch {} }
    $m = New-Object System.Windows.Window
    $m.WindowStyle = 'None'; $m.AllowsTransparency = $true; $m.Background = [System.Windows.Media.Brushes]::Transparent
    $m.Topmost = $true; $m.ShowInTaskbar = $false; $m.ResizeMode = 'NoResize'; $m.SizeToContent = 'WidthAndHeight'; $m.Title = 'PetSolaire menu'
    $bo = New-Object System.Windows.Controls.Border
    $bo.Background = Pincel '#F4100C0A'; $bo.BorderBrush = Pincel '#8A6A30'; $bo.BorderThickness = 2; $bo.CornerRadius = 3; $bo.Padding = '3'
    $in = New-Object System.Windows.Controls.Border; $in.BorderBrush = Pincel '#4A3A1C'; $in.BorderThickness = 1; $in.Padding = '4,6,4,6'
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.MinWidth = 210
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $titulo; $t.FontFamily = $FONTE_DS; $t.FontSize = 13; $t.FontWeight = 'Bold'; $t.Foreground = Pincel '#E8C060'
    $t.Margin = '10,0,10,4'; $t.MaxWidth = 280; $t.TextTrimming = 'CharacterEllipsis'
    [void]$sp.Children.Add($t)
    $r = New-Object System.Windows.Shapes.Rectangle; $r.Height = 1; $r.Fill = Pincel '#4A3A1C'; $r.Margin = '6,0,6,4'; [void]$sp.Children.Add($r)
    foreach ($it in $itens) {
        if ($it -eq '-') { $r = New-Object System.Windows.Shapes.Rectangle; $r.Height = 1; $r.Fill = Pincel '#3A2E18'; $r.Margin = '10,4,10,4'; [void]$sp.Children.Add($r); continue }
        $b = New-Object System.Windows.Controls.Border; $b.Padding = '10,4,14,4'; $b.Background = [System.Windows.Media.Brushes]::Transparent
        $b.Cursor = [System.Windows.Input.Cursors]::Hand; $b.Tag = $it[1]
        $tx = New-Object System.Windows.Controls.TextBlock
        $tx.Text = '   ' + $it[0]; $tx.FontFamily = $FONTE_DS; $tx.FontSize = 14; $tx.Foreground = Pincel '#E6E0D0'
        $b.Child = $tx
        $b.Add_MouseEnter({ $this.Background = Pincel '#30E8C060'; $this.Child.Text = [string][char]0x25B8 + '  ' + $this.Child.Text.TrimStart(); $this.Child.Foreground = Pincel '#FFE6A0' })
        $b.Add_MouseLeave({ $this.Background = [System.Windows.Media.Brushes]::Transparent; $this.Child.Text = '   ' + $this.Child.Text.Substring(1).TrimStart(); $this.Child.Foreground = Pincel '#E6E0D0' })
        $b.Add_MouseLeftButtonUp({ $acao = $this.Tag; $script:menuWin.Close(); $script:menuWin = $null; & $acao })
        [void]$sp.Children.Add($b)
    }
    $in.Child = $sp; $bo.Child = $in; $m.Content = $bo
    $m.Add_Deactivated({ try { $this.Close() } catch {} })
    $m.Add_KeyDown({ param($snd, $e) if ($e.Key -eq 'Escape') { $this.Close() } })
    $script:menuWin = $m
    $pos = [System.Windows.Forms.Cursor]::Position
    $m.Left = $pos.X; $m.Top = $pos.Y; $m.Show(); [void]$m.Activate(); $m.UpdateLayout()
    $wa = (TelaEm $pos.X).WorkingArea                                          # não deixa sair da tela
    if ($m.Left + $m.ActualWidth -gt $wa.Right) { $m.Left = $pos.X - $m.ActualWidth }
    if ($m.Top + $m.ActualHeight -gt $wa.Bottom) { $m.Top = $pos.Y - $m.ActualHeight }
}

# ---- balão de fala (segue a cabeça dele) ----
$falaWin = Janela-Flutuante; $falaWin.Title = 'PetSolaire fala'; $falaWin.IsHitTestVisible = $false
$falaPilha = New-Object System.Windows.Controls.StackPanel
$falaBorda = New-Object System.Windows.Controls.Border
$falaBorda.Background = Pincel '#FFFFFBEF'; $falaBorda.BorderBrush = Pincel '#FF181418'; $falaBorda.BorderThickness = 2
$falaBorda.CornerRadius = 7; $falaBorda.Padding = '9,5,9,6'
$falaTxt = New-Object System.Windows.Controls.TextBlock
$falaTxt.MaxWidth = 230; $falaTxt.TextWrapping = 'Wrap'; $falaTxt.FontSize = 13; $falaTxt.FontWeight = 'SemiBold'
$falaTxt.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe UI'); $falaTxt.Foreground = Pincel '#FF201A14'
$falaBorda.Child = $falaTxt
$falaRabo = New-Object System.Windows.Shapes.Polygon
$falaRabo.Points = [System.Windows.Media.PointCollection]::Parse('0,0 16,0 8,9'); $falaRabo.Fill = Pincel '#FFFFFBEF'
$falaRabo.Stroke = Pincel '#FF181418'; $falaRabo.StrokeThickness = 2; $falaRabo.HorizontalAlignment = 'Center'; $falaRabo.Margin = '0,-2,0,0'
[void]$falaPilha.Children.Add($falaBorda); [void]$falaPilha.Children.Add($falaRabo)
$falaWin.Content = $falaPilha
$script:falaAte = 0.0; $script:proxFala = 15 + $rnd.NextDouble() * 30

function Falar($texto, $seg) {
    $falaTxt.Text = $texto
    $script:falaAte = $script:t + $(if ($seg) { $seg } else { 3 + $texto.Length * 0.06 })
    $script:proxFala = $script:t + $FALA_CADA[0] + $rnd.NextDouble() * ($FALA_CADA[1] - $FALA_CADA[0])
    $falaWin.Show(); $falaWin.UpdateLayout()
}
function Posicionar-Fala {
    $w = $falaWin.ActualWidth; $h = $falaWin.ActualHeight
    $tela = $telas[-1]; foreach ($tt in $telas) { if ($script:x -lt $tt.Bounds.Right) { $tela = $tt; break } }
    $wa = $tela.WorkingArea
    $fy = $script:y - $PH - $h + 6
    if ($fy -lt $wa.Top) { $fy = $script:y + 2; $falaRabo.Visibility = 'Collapsed' } else { $falaRabo.Visibility = 'Visible' }
    $falaWin.Left = [math]::Round([math]::Max($wa.Left, [math]::Min($wa.Right - $w, $script:x - $w / 2)))
    $falaWin.Top = [math]::Round($fy)
}

# ---- janelas abertas (para ele escalar): lista e retângulo de cada uma, pelo DWM (sem a sombra) ----
Add-Type @"
using System; using System.Collections.Generic; using System.Runtime.InteropServices;
public class JanelasPet {
    delegate bool CB(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] static extern bool EnumWindows(CB cb, IntPtr p);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsZoomed(IntPtr h);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int a, out int v, int s);
    public struct RECT { public int L, T, R, B; }
    // [esq, topo, dir, baixo, maximizada] ou null se a janela sumiu, minimizou ou está escondida
    public static int[] Ret(long hl) {
        IntPtr h = new IntPtr(hl);
        if (!IsWindowVisible(h) || IsIconic(h)) return null;
        int cl; if (DwmGetWindowAttribute(h, 14, out cl, 4) == 0 && cl != 0) return null;
        RECT r; if (DwmGetWindowAttribute(h, 9, out r, 16) != 0) GetWindowRect(h, out r);
        return new int[] { r.L, r.T, r.R, r.B, IsZoomed(h) ? 1 : 0 };
    }
    public static List<long> Lista() {
        var o = new List<long>(); uint eu = (uint)System.Diagnostics.Process.GetCurrentProcess().Id;
        EnumWindows((h, p) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid != eu && GetWindowTextLength(h) > 0 && (GetWindowLong(h, -20) & 0x80) == 0 && Ret(h.ToInt64()) != null) o.Add(h.ToInt64());
            return true; }, IntPtr.Zero);
        return o;
    }
}
"@

$win.Add_MouseLeftButtonDown({ param($snd, $e)
    if ($e.ClickCount -ge 2) { Louvar; return }          # duplo clique: Praise the Sun na hora
    $sunWin.Hide(); $falaWin.Hide(); $win.Opacity = 1; $script:arrastando = $true; try { $win.DragMove() } catch {}; $script:arrastando = $false
    # solto: volta planando até a barra de tarefas
    $script:x = $win.Left + $PW / 2; $script:y = $win.Top + $PH
    $script:sup = 'chao'; $script:jan = 0; $script:proximo = $null; Mudar 'voltar' 99 })
$win.Add_MouseRightButtonUp({ Menu-DS 'SOLAIRE DE ASTORA' $MENU })
# arrastar arquivo em cima dele: pergunta o que fazer e abre um Claude novo com o arquivo
$win.Background = Pincel '#01000000'                  # quase invisível, mas o quadrado todo recebe o arquivo
$win.AllowDrop = $true
$win.Add_DragEnter({ param($snd, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) { $e.Effects = 'Copy'; if (-not $falaWin.IsVisible) { Falar 'Hm? Trouxe algo pra mim?' 2 } }
    else { $e.Effects = 'None' }
    $e.Handled = $true })
$win.Add_Drop({ param($snd, $e)
    $arqs = @($e.Data.GetData([System.Windows.DataFormats]::FileDrop))
    if (-not $arqs.Count) { return }
    [System.IO.File]::WriteAllLines($LISTA, [string[]]$arqs, (New-Object System.Text.UTF8Encoding($false)))
    $nome = [System.IO.Path]::GetFileName($arqs[0]) + $(if ($arqs.Count -gt 1) { " + $($arqs.Count - 1)" } else { '' })
    Menu-DS $nome @(
        ,@('Resumir', { Claude-Novo 'resumir' $LISTA })
        ,@('Só olhar e me dizer', { Claude-Novo 'olhar' $LISTA })
        '-'
        ,@('Cancelar', {})
    ) })

# ---- onde ele pode estar ----
# chao: em cima da barra de tarefas de cada tela | parede: escalando a borda de fora da tela ou a lateral de uma janela
# janela: andando em cima de uma janela aberta. (x, y) é o meio da base do bicho.
$telas = @([System.Windows.Forms.Screen]::AllScreens | Sort-Object { $_.Bounds.Left })
$M = [math]::Ceiling($PW / 2) + 2                  # distância da borda até o meio do bicho
$X0 = $telas[0].WorkingArea.Left + $M; $X1 = $telas[-1].WorkingArea.Right - $M
$PAREDE = [int](11 * $K)                           # do meio do bicho até as mãos, escalando
$MAO = [int]($PH * 0.68)                           # altura das mãos acima do pé, escalando
function TelaEm($x) { foreach ($t in $telas) { if ($x -lt $t.Bounds.Right) { return $t } }; return $telas[-1] }
function BaseEm($x) { (TelaEm $x).WorkingArea.Bottom - 4 }
function NoChao($x) { [math]::Max($X0, [math]::Min($X1, $x)) }
function Novo-Alvo {
    if ($script:sup -eq 'janela') { $script:alvoX = $script:jr[0] + $M + $rnd.NextDouble() * [math]::Max(1, $script:jr[2] - $script:jr[0] - 2 * $M) }
    else { $script:alvoX = NoChao ($script:x + ($rnd.NextDouble() - 0.5) * ($X1 - $X0) * 0.6) }
}

# escolhe uma janela aberta que dê para escalar: cabe ele em cima, não está maximizada, tem espaço do lado
function Escolher-Janela {
    $ops = @()
    foreach ($h in [JanelasPet]::Lista()) {
        $r = [JanelasPet]::Ret($h); if (-not $r -or $r[4]) { continue }
        $w = $r[2] - $r[0]; $hh = $r[3] - $r[1]
        if ($w -lt 260 -or $hh -lt 140) { continue }
        $wa = (TelaEm (($r[0] + $r[2]) / 2)).WorkingArea
        if ($r[1] -gt $wa.Bottom - 150 -or $r[3] -gt $wa.Bottom + 2 -or $r[3] -lt $wa.Top + $PH + 150) { continue }
        $montar = $r[1] -ge $wa.Top + $PH + 10                                    # cabe ele em pé em cima da janela?
        if ($r[0] - $PAREDE - $M -ge $wa.Left -and $r[0] - $PAREDE -ge $X0) { $ops += , @($h, 1, $montar) }       # lado esquerdo
        if ($r[2] + $PAREDE + $M -le $wa.Right -and $r[2] + $PAREDE -le $X1) { $ops += , @($h, -1, $montar) }     # lado direito
    }
    if ($ops.Count -eq 0) { return $null }
    return $ops[$rnd.Next($ops.Count)]
}
function Plano-Janela {
    $c = Escolher-Janela; if (-not $c) { return $false }
    $script:jan = $c[0]; $script:jr = [JanelasPet]::Ret($c[0]); $script:paredeLado = $c[1]; $script:montar = $c[2]
    $script:paredeX = if ($c[1] -gt 0) { $script:jr[0] } else { $script:jr[2] }
    $script:alvoX = $script:paredeX - $script:paredeLado * $PAREDE; $script:proximo = 'pular_janela'
    return $true
}
function Plano-Tela {
    # a borda de fora mais perto (entre as telas não tem parede)
    if ($script:x - $X0 -lt $X1 - $script:x) { $script:paredeX = $telas[0].WorkingArea.Left; $script:paredeLado = -1 }
    else { $script:paredeX = $telas[-1].WorkingArea.Right; $script:paredeLado = 1 }
    $script:jan = 0; $script:alvoX = $script:paredeX - $script:paredeLado * $PAREDE; $script:proximo = 'subir_tela'
}
function Pular($x1, $y1, $depois, $altura) {
    $script:p0 = @($script:x, $script:y); $script:p1 = @($x1, $y1); $script:aposPulo = $depois
    $d = [math]::Sqrt(($x1 - $script:x) * ($x1 - $script:x) + ($y1 - $script:y) * ($y1 - $script:y))
    $script:pDur = [math]::Max(0.35, [math]::Min(1.0, $d / 600)); $script:pAlt = $altura; $script:pIni = $script:t
    Mudar 'pulo' 99
}
function Cair { $script:sup = 'ar'; $script:jan = 0; $script:vy = 0.0; $script:proximo = $null; $script:vista = 'tonto'; Mudar 'cair' 99 }

$script:sup = 'chao'; $script:jan = 0; $script:jr = $null; $script:proximo = $null; $script:paredeLado = 1; $script:paredeX = 0
$script:x = NoChao ($X0 + ($X1 - $X0) * 0.3); $script:y = BaseEm $script:x; $script:alvoX = $script:x
$script:passosJanela = 0; $script:yAlvo = 0; $script:vy = 0.0; $script:montar = $true

# modo: vagar | parado | virando | costas | louvor | tonto | voltar (depois de arrastar) | pulo | aterrissar | subir | pendurado
#       | descer | cair | sumindo | sumido | surgindo
$script:modo = 'parado'; $script:modoAte = 2; $script:vista = 'frente'; $script:olhaDir = $true
$script:virarPara = $null
$script:t = 0.0; $script:quadro = 0; $script:arrastando = $false
function Mudar($m, $seg) { $script:modo = $m; $script:modoAte = $script:t + $seg }

# ---- Praise the Sun ----
# o sol nasce acima dele (ou do lado, se não couber em cima), ele ergue os braços, segura a pose e o sol se apaga.
$script:louvorIni = 0.0; $script:louvorQ = 0
function Louvar {
    if ($script:modo -in 'sumindo', 'sumido', 'louvor', 'pulo', 'subir', 'descer', 'pendurado', 'cair', 'voltar') { return }
    if ($script:sup -notin 'chao', 'janela') { return }
    if ($invWin.IsVisible) { Mudar 'combate' 99; return }
    $win.Opacity = 1; $script:vista = 'louvor'; $script:louvorIni = $script:t; $script:louvorQ = 0
    $script:semSol = $avisoWin.IsVisible
    $wa = (TelaEm $script:x).WorkingArea
    $script:solX = $script:x - $SW / 2; $script:solY = $script:y - $PH - $SW - 6
    if ($script:solY -lt $wa.Top) {
        $script:solY = $script:y - $PH
        $script:solX = if ($script:x + $PW / 2 + 8 + $SW -le $wa.Right) { $script:x + $PW / 2 + 8 } else { $script:x - $PW / 2 - 8 - $SW }
    }
    $script:solX = [math]::Max($wa.Left, [math]::Min($wa.Right - $SW, $script:solX))
    $sunWin.Left = [math]::Round($script:solX); $sunWin.Top = [math]::Round($script:solY + 30)
    $sunWin.Opacity = 0
    if (-not $avisoWin.IsVisible) { $sunWin.Show() }
    Mudar 'louvor' 99
}

# ---- sumidas (só some quando está na barra) ----
$script:proxSumida = 600 + $rnd.NextDouble() * 900
function Aparecer {
    $script:sup = 'chao'; $script:jan = 0; $script:proximo = $null
    $script:x = NoChao ($X0 + $rnd.NextDouble() * ($X1 - $X0)); $script:y = BaseEm $script:x; $script:alvoX = $script:x
    $script:proxSumida = $script:t + 600 + $rnd.NextDouble() * 900
    $win.Opacity = 0; $win.Show(); $script:vista = 'frente'; Mudar 'surgindo' 99
}

# chegou ao alvo andando (na barra ou em cima de uma janela): decide o que fazer
function Chegou {
    if ($script:proximo) {
        $acao = $script:proximo; $script:proximo = $null
        switch ($acao) {
            'pular_janela' {
                $r = [JanelasPet]::Ret($script:jan)
                if (-not $r -or $r[4]) { $script:jan = 0; Novo-Alvo; return }
                $script:jr = $r; $script:paredeX = if ($script:paredeLado -gt 0) { $r[0] } else { $r[2] }
                $script:x = $script:paredeX - $script:paredeLado * $PAREDE
                $wa = (TelaEm $script:x).WorkingArea
                if ($script:montar) { $script:yAlvo = $r[1] + $MAO }
                else {                                                        # sem espaço em cima: sobe até uma altura e volta
                    $alto = [math]::Max($r[1] + $MAO, $wa.Top + $PH + 20)
                    $script:yAlvo = $alto + $rnd.NextDouble() * [math]::Max(0, ($r[3] + $MAO - 60) - $alto) * 0.6
                }
                $yAgarra = $r[3] + $MAO - 20                                  # mãos logo acima do canto de baixo da janela
                if ($yAgarra -ge $script:y - 10) { $script:sup = 'parede'; Mudar 'subir' 99 }   # a janela chega na barra: só subir
                else { Pular $script:x $yAgarra 'agarrar' 40 }
                $script:olhaDir = $script:paredeLado -gt 0
                return
            }
            'subir_tela' {
                $wa = (TelaEm $script:x).WorkingArea
                $script:sup = 'parede'; $script:olhaDir = $script:paredeLado -gt 0
                $script:yAlvo = $wa.Top + $PH + 20 + $rnd.NextDouble() * [math]::Max(0, ($wa.Bottom - $wa.Top) * 0.6 - $PH)
                Mudar 'subir' 99; return
            }
            'pular_chao' {
                $xc = NoChao ($script:x + $(if ($script:olhaDir) { $PW } else { -$PW }))
                $script:jan = 0; Pular $xc (BaseEm $xc) 'chao' 50; return
            }
        }
    }
    if ($avisoWin.IsVisible) { Louvar; return }                               # embaixo do sol do aviso
    $r = $rnd.NextDouble()
    if ($script:sup -eq 'janela') {
        $script:passosJanela--
        if ($script:passosJanela -le 0) {                                       # hora de descer: vai até a beirada e pula
            $esq = $script:x - $script:jr[0] -lt $script:jr[2] - $script:x
            $script:alvoX = if ($esq) { $script:jr[0] + $M } else { $script:jr[2] - $M }
            $script:proximo = 'pular_chao'; $script:olhaDir = -not $esq; return
        }
    } else {
        if ($r -lt $SUBIR_JANELA -and (Plano-Janela)) { return }
        if ($r -gt 1 - $SUBIR_TELA) { Plano-Tela; return }
    }
    if ($rnd.NextDouble() -lt $LOUVOR) { Novo-Alvo; Louvar; if ($rnd.NextDouble() -lt 0.5 -and -not $falaWin.IsVisible) { Falar 'Louvado seja o Sol!' 3 }; return }
    $r = $rnd.NextDouble()
    if ($r -lt 0.5) { $script:vista = 'frente'; Mudar 'parado' (2 + $rnd.NextDouble() * 5) }
    elseif ($r -lt 0.65) { $script:vista = 'costas'; Mudar 'costas' (2 + $rnd.NextDouble() * 3) }
    Novo-Alvo
}

# ---- laço ----
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(1000 / $FPS)
$script:tick = 0
$timer.Add_Tick({
    $script:tick++; $dt = 1.0 / $FPS; $script:t += $dt
    # avisos de tarefa concluída (1 vez por segundo)
    if ($script:tick % $FPS -eq 0) {
        foreach ($arq in @(Get-ChildItem $AVISOS -Filter *.json -ErrorAction SilentlyContinue | Sort-Object Name)) {
            try {
                $av = [System.IO.File]::ReadAllText($arq.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
                Remove-Item $arq.FullName -ErrorAction SilentlyContinue
                if ($av.tipo -eq 'acao') {                                    # comando: solaire_aviso janela|tela "" acao
                    if ($script:sup -eq 'chao' -and $script:modo -in 'vagar', 'parado', 'costas') {
                        if ($av.titulo -eq 'janela') { [void](Plano-Janela) } else { Plano-Tela }
                        Mudar 'vagar' 0
                    }
                    continue
                }
                if ($script:modo -in 'sumido', 'sumindo') { Aparecer; $win.Opacity = 1; Mudar 'parado' 0.5 }
                if ($av.tipo -eq 'invasao') {
                    Nova-Invasao $av.titulo $av.texto $av.link
                    if ($script:modo -eq 'louvor') { $sunWin.Hide() }
                    Falar 'Um espírito sombrio invadiu o seu mundo! Em guarda!' 5
                    continue
                }
                Novo-Aviso $av.titulo $av.texto $av.tipo
                if (-not $script:arrastando) { Louvar }
                Falar $(if ($av.tipo -eq 'erro') { 'Hmm... essa não deu certo. Mas não desista!' } else { 'Tarefa concluída! Louvado seja o Sol!' }) 4
            } catch { Remove-Item $arq.FullName -ErrorAction SilentlyContinue }
        }
    }
    if ($script:tick % ($FPS * 5) -eq 3) { Checar-Lembretes }
    if ($marcaWin.IsVisible) { $marcaImg.Source = $FSS[[int][math]::Floor($script:t * 5) % $SSQ] }
    if ($avisoWin.IsVisible) { $avSol.Source = $FS[[int][math]::Floor($script:t * 6) % $SQ] }
    if ($script:modo -eq 'sumido') { if ($script:t -gt $script:modoAte) { Aparecer }; return }
    if ($script:tick % ($FPS * 2) -eq 0) {        # a barra de tarefas passa na frente
        foreach ($jw in $marcaWin, $win, $sunWin, $avisoWin, $invWin, $msgWin, $falaWin) { if ($jw.IsVisible) { $jw.Topmost = $false; $jw.Topmost = $true } }
    }
    # falas: de vez em quando
    if ($falaWin.IsVisible) { if ($script:t -gt $script:falaAte -or $script:modo -in 'sumindo', 'sumido') { $falaWin.Hide() } }
    elseif ($script:t -gt $script:proxFala -and $script:modo -in 'vagar', 'parado', 'costas', 'louvor', 'pendurado' -and -not $script:arrastando) {
        Falar $FALAS[$rnd.Next($FALAS.Count)]
    }
    if ($script:arrastando) { return }

    # em cima ou agarrado numa janela: acompanha se ela mexer; cai se ela fechar, minimizar ou maximizar
    if ($script:jan -and $script:modo -ne 'pulo') {
        $r = [JanelasPet]::Ret($script:jan)
        if (-not $r -or $r[4] -or ($script:sup -eq 'janela' -and $r[2] - $r[0] -lt $PW)) {
            if ($script:sup -in 'janela', 'parede') { Cair } else { $script:jan = 0; $script:proximo = $null }
        } elseif ($script:sup -in 'janela', 'parede') {
            $ddx = $r[0] - $script:jr[0]; $ddy = $r[1] - $script:jr[1]
            if ($script:sup -eq 'parede') {
                $script:paredeX = if ($script:paredeLado -gt 0) { $r[0] } else { $r[2] }
                $script:x = $script:paredeX - $script:paredeLado * $PAREDE; $script:yAlvo += $ddy
                $script:y += $ddy
            } else {
                $script:x = [math]::Max($r[0] + $M, [math]::Min($r[2] - $M, $script:x + $ddx)); $script:y = $r[1]
                $script:alvoX = [math]::Max($r[0] + $M, [math]::Min($r[2] - $M, $script:alvoX + $ddx))
                if ($ddx -or $ddy) { $sunWin.Hide() }
            }
            $script:jr = $r
        } else { $script:jr = $r }
    }

    if ($SUMIR -and $script:sup -eq 'chao' -and $script:modo -in 'vagar', 'parado' -and $script:t -gt $script:proxSumida -and -not $avisoWin.IsVisible) { Mudar 'sumindo' 99 }
    if ($invWin.IsVisible -and $script:sup -in 'chao', 'janela' -and $script:modo -in 'vagar', 'parado', 'costas', 'virando', 'louvor', 'tonto') {
        if ($script:modo -eq 'louvor') { $sunWin.Hide() }
        $script:proximo = $null; Mudar 'combate' 99
    }
    switch ($script:modo) {
        'combate' { if (-not $invWin.IsVisible) { $script:vista = 'frente'; Mudar 'parado' 1.5 } }
        'sumindo' {
            $win.Opacity = [math]::Max([double]0.0, $win.Opacity - 1.5 * $dt)    # [double]: com 0 inteiro o PowerShell arredonda
            if ($win.Opacity -le 0) { $win.Hide(); Mudar 'sumido' (180 + $rnd.NextDouble() * 420) }
        }
        'surgindo' {
            $win.Opacity = [math]::Min([double]1.0, $win.Opacity + 1.5 * $dt)
            if ($win.Opacity -ge 1) { Louvar }
        }
        'louvor' {
            # 0-1 s: sol nasce subindo; 0,6 s: ergue os braços; segura até 4,5 s; 4,5-5,5 s: sol some e baixa os braços
            $u = $script:t - $script:louvorIni
            if ($avisoWin.IsVisible) {                                     # aviso aberto: continua louvando o sol do aviso
                $script:semSol = $true
                if ($u -gt 4.0) { $script:louvorIni = $script:t - 0.8; $u = 0.8 }
            } elseif ($script:semSol -and $u -lt 4.75) { $script:louvorIni = $script:t - 4.75; $u = 4.75 }   # fechou: abaixa os braços já
            if ($script:semSol) { if ($sunWin.IsVisible) { $sunWin.Hide() } }                          # sem o sol solto
            elseif (-not $sunWin.IsVisible -and $u -lt 4.5) { $sunWin.Show() }
            $sunWin.Opacity = if ($u -lt 1) { $u } elseif ($u -lt 4.5) { 1.0 } else { [math]::Max([double]0.0, 5.5 - $u) }
            $sunWin.Top = [math]::Round($script:solY + 30 * [math]::Max([double]0.0, 1 - $u))
            $sunWin.Left = [math]::Round($script:solX)
            $solView.Source = $FS[[int][math]::Floor($u * 6) % $SQ]
            # quadros: 0 parado, 1 agacha, 2 pulo com os braços para o alto, 3-7 em loop no chão; no fim agacha e volta
            if ($u -lt 0.45 -or $u -ge 4.95) { $script:louvorQ = 0 }
            elseif ($u -lt 0.6) { $script:louvorQ = 1 }
            elseif ($u -lt 0.8) { $script:louvorQ = 2 }
            elseif ($u -lt 4.75) { $script:louvorQ = 3 + [int][math]::Floor(($u - 0.8) * 6) % 5 }
            else { $script:louvorQ = 1 }
            if ($u -ge 5.5) { $sunWin.Hide(); $script:vista = 'frente'; Mudar 'parado' 1.5 }
        }
        'vagar' {
            if ($avisoWin.IsVisible -and $script:sup -eq 'chao' -and -not $script:proximo) {
                $script:alvoX = NoChao ($avisoWin.Left + $avisoWin.ActualWidth / 2)
            } elseif ($marcaWin.IsVisible -and $script:sup -eq 'chao' -and -not $script:proximo -and [math]::Abs($script:alvoX - $script:marcaX) -gt 80) {
                $script:alvoX = NoChao ($script:marcaX - 50)                        # fica do lado da mensagem
            }
            $ds = $script:alvoX - $script:x
            if ([math]::Abs($ds) -lt 2) { $script:x = $script:alvoX; Chegou; break }
            $quer = $ds -gt 0
            if ($quer -ne $script:olhaDir) { $script:virarPara = $quer; $script:vista = 'frente'; Mudar 'virando' 0.35; break }
            $script:vista = if ($script:olhaDir) { 'direita' } else { 'esquerda' }
            $script:x += [math]::Sign($ds) * [math]::Min([math]::Abs($ds), $VELOCIDADE * $dt)
            $script:y = if ($script:sup -eq 'janela') { $script:jr[1] } else { BaseEm $script:x }
        }
        'subir' {
            $script:y -= $ESCALADA * $dt
            if ($script:jan -eq 0 -and ($avisoWin.IsVisible -or $invWin.IsVisible)) { Mudar 'descer' 99; break }       # aviso: desce para louvar
            if ($script:y -le $script:yAlvo) {
                $script:y = $script:yAlvo
                if ($script:jan -and $script:montar) {                          # chegou no topo da janela: sobe nela
                    $r = $script:jr
                    $xt = if ($script:paredeLado -gt 0) { $r[0] + $M } else { $r[2] - $M }
                    $script:passosJanela = 1 + $rnd.Next(3)
                    Pular $xt $r[1] 'janela' 28
                } else { Mudar 'pendurado' (2 + $rnd.NextDouble() * 4) }
            }
        }
        'pendurado' { if ($script:t -gt $script:modoAte -or $avisoWin.IsVisible -or $invWin.IsVisible) { Mudar 'descer' 99 } }
        'descer' {
            $script:y += $ESCALADA * 1.3 * $dt
            if ($script:jan -and $script:y -gt $script:jr[3] + $MAO - 20) {         # acabou a janela antes da barra: pula
                $xc = NoChao ($script:x - $script:paredeLado * $PW * 0.6); $script:olhaDir = $script:paredeLado -lt 0
                $script:sup = 'ar'; $script:jan = 0; Pular $xc (BaseEm $xc) 'chao' 25; break
            }
            $yb = BaseEm $script:x
            if ($script:y -ge $yb) {
                $script:y = $yb; $script:sup = 'chao'; $script:jan = 0
                $script:x = NoChao ($script:x - $script:paredeLado * 6); $script:olhaDir = $script:paredeLado -lt 0
                $script:vista = 'frente'; Mudar 'parado' 1; Novo-Alvo
            }
        }
        'pulo' {
            $u = [math]::Min([double]1.0, ($script:t - $script:pIni) / $script:pDur)
            if ($script:aposPulo -eq 'janela' -or $script:aposPulo -eq 'agarrar') {     # alvo numa janela que pode ter mexido
                $r = if ($script:jan) { [JanelasPet]::Ret($script:jan) } else { $null }
                if (-not $r -or $r[4]) { Cair; break }
                $ddx = $r[0] - $script:jr[0]; $ddy = $r[1] - $script:jr[1]
                $script:p1 = @(($script:p1[0] + $ddx), ($script:p1[1] + $ddy)); $script:jr = $r
            }
            $script:x = $script:p0[0] + ($script:p1[0] - $script:p0[0]) * $u
            $script:y = $script:p0[1] + ($script:p1[1] - $script:p0[1]) * $u - $script:pAlt * 4 * $u * (1 - $u)
            if ($u -ge 1) {
                switch ($script:aposPulo) {
                    'agarrar' { $script:sup = 'parede'; Mudar 'subir' 99 }
                    'janela' { $script:sup = 'janela'; $script:vista = 'frente'; Mudar 'aterrissar' 0.18; Novo-Alvo }
                    default { $script:sup = 'chao'; $script:y = BaseEm $script:x; $script:vista = 'frente'; Mudar 'aterrissar' 0.18; Novo-Alvo }
                }
            }
        }
        'cair' {
            $script:vy += 1800 * $dt; $script:y += $script:vy * $dt
            $script:x = NoChao $script:x
            $yb = BaseEm $script:x
            if ($script:y -ge $yb) { $script:y = $yb; $script:sup = 'chao'; Novo-Alvo; $script:vista = 'tonto'; Mudar 'tonto' 2.2; Falar 'Ai!' 1.5 }
        }
        'voltar' {
            $xv = NoChao $script:x; $yv = BaseEm $xv
            $dx = $xv - $script:x; $dy = $yv - $script:y; $d = [math]::Sqrt($dx * $dx + $dy * $dy)
            $vel = 260 * $dt
            # volta planando tonto e, no chão, ainda fica tonto um pouco
            if ($d -le $vel) { $script:x = $xv; $script:y = $yv; Novo-Alvo; $script:vista = 'tonto'; Mudar 'tonto' 1.8 }
            else { $script:x += $dx / $d * $vel; $script:y += $dy / $d * $vel; $script:vista = 'tonto' }
        }
        'virando' { if ($script:t -gt $script:modoAte) { $script:olhaDir = $script:virarPara; Mudar 'vagar' 0 } }
        default { if ($script:t -gt $script:modoAte) { Mudar 'vagar' 0 } }
    }

    # animação e posição
    if ($script:tick % [math]::Max(1, [int]($FPS / $ANIM_FPS)) -eq 0) { $script:quadro = ($script:quadro + 1) % 840 }
    $v = $script:vista
    if ($v -eq 'frente' -and $script:modo -in 'parado', 'surgindo', 'sumindo', 'virando') { $v = 'parado' }
    $esc = if ($script:paredeLado -gt 0) { 'escalar' } else { 'escalar_e' }
    $src = if ($script:modo -eq 'combate') { $F['combate'][$script:quadro % $F['combate'].Count] }
           elseif ($script:modo -eq 'louvor') { $F['louvor'][$script:louvorQ] }
           elseif ($script:modo -eq 'pulo') { $F['louvor'][2] }                                                     # braços para cima no ar
           elseif ($script:modo -eq 'aterrissar') { $F['louvor'][1] }                                               # agacha ao cair em pé
           elseif ($script:modo -eq 'subir') { $F[$esc][$script:quadro % $F[$esc].Count] }
           elseif ($script:modo -eq 'descer') { $F[$esc][($F[$esc].Count - 1) - $script:quadro % $F[$esc].Count] }
           elseif ($script:modo -eq 'pendurado') { $F[$esc][0] }
           elseif ($script:modo -eq 'cair') { $F['tonto'][$script:quadro % $F['tonto'].Count] }
           elseif ($v -eq 'parado') { $F['parado'][[int][math]::Floor($script:quadro / 2) % $F['parado'].Count] }   # respira devagar
           elseif ($script:modo -eq 'costas') { $F['costas'][0] }                                                   # de costas parado
           else { $F[$v][$script:quadro % $F[$v].Count] }
    if ($img.Source -ne $src) { $img.Source = $src }
    $win.Left = [math]::Round($script:x - $PW / 2)
    $win.Top = [math]::Round($script:y - $PH)
    if ($falaWin.IsVisible) { Posicionar-Fala }
})

$win.Add_Closed({ [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() })
New-Item -ItemType Directory -Force -Path $AVISOS | Out-Null
Get-ChildItem $AVISOS -Filter *.json -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddMinutes(-30) } | Remove-Item -ErrorAction SilentlyContinue
$win.Show()
$timer.Start()
[System.Windows.Threading.Dispatcher]::Run()
