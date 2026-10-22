# Monta a spritesheet do PetSolaire a partir das folhas de referência (JPEG com grade no fundo):
# recorta cada quadro, tira o fundo, alinha pelo capacete (sem tremer), ordena o passo no ciclo mais suave e cria
# animações novas em cima dos quadros recortados (parado respirando, Praise the Sun com impulso, tonto).
# uso: python3 montar.py <pasta ref> <pasta saída> [escala]
import itertools, sys, numpy as np
from PIL import Image
from scipy import ndimage as nd

REF, OUT = sys.argv[1], sys.argv[2]
ESC = float(sys.argv[3]) if len(sys.argv) > 3 else 0.7
COLS = 8

# (y0, y1, [x0, x1 de cada quadro]) — posições nas folhas
CAIXAS = {
    'frente': ('folha1', 145, 306, [(91, 180), (250, 339), (409, 498), (562, 652), (721, 810), (879, 968)]),
    'lado':   ('folha1', 300, 455, [(95, 183), (245, 340), (405, 491), (560, 656), (718, 802), (874, 962)]),
    'costas': ('folha1', 452, 600, [(245, 339), (404, 498), (558, 654), (716, 810), (872, 968)]),
    'louvor': ('folha1', 640, 786, [(221, 364), (378, 523), (537, 679), (693, 837), (851, 994)]),
    'tonto':  ('folha2', 148, 306, [(553, 666), (711, 817), (869, 973)]),
}
folhas = {k: np.asarray(Image.open(f'{REF}/{k}.jpg').convert('RGB')).astype(int) for k in ('folha1', 'folha2')}

def claro(rgb):
    mx = rgb.max(2); mn = rgb.min(2)
    return (mx > 175) & ((mx - mn) < 45)

def recorta(nome, folha, y0, y1, x0, x1):
    rgb = folhas[folha][y0:y1, x0:x1].copy()
    if nome == 'tonto' and x0 < 560:
        # o texto FRONT encosta no capacete: apaga o que é escuro e não vermelho naquele canto
        r = rgb[:181 - y0, :616 - x0]
        texto = ~((r[:, :, 0] > 90) & (r[:, :, 0] > r[:, :, 1] * 1.6))
        r[texto] = 255
    cl_ = claro(rgb)
    lb, _ = nd.label(cl_)
    bordas = set(np.unique(np.concatenate([lb[0], lb[-1], lb[:, 0], lb[:, -1]]))) - {0}
    bg = np.isin(lb, list(bordas))
    fg = ~bg
    cl, cn = nd.label(fg)
    tam = nd.sum(fg, cl, range(1, cn + 1))
    maior = cl == (int(np.argmax(tam)) + 1)
    perto = nd.binary_dilation(maior, iterations=2)
    pe = np.where(maior.any(1))[0][-1]
    manter = []
    for k in range(cn):
        pk = cl == k + 1
        if tam[k] <= 4 or (pk & maior).all(): continue
        ys, xs = np.where(pk)
        toca_borda = ys.min() == 0 or xs.min() == 0 or xs.max() == pk.shape[1] - 1 or ys.max() == pk.shape[0] - 1
        if tam[k] > 25 and (perto & pk).any() and ys.min() < pe - 10: manter.append(k + 1)
        # estrelinhas do tonto: pedacinhos soltos em volta da cabeça
        elif nome == 'tonto' and not toca_borda and tam[k] < 60 and ys.max() < rgb.shape[0] * 0.4: manter.append(k + 1)
    corpo = maior | np.isin(cl, manter)
    if nome == 'louvor':
        # a pluma e o capacete do Solaire da linha de baixo encostam nos pés
        baixo = int(corpo.shape[0] * 0.7)
        corpo[baixo:] &= ~((rgb[baixo:, :, 0] > 70) & (rgb[baixo:, :, 0] > rgb[baixo:, :, 1] * 1.35))
        ys_ = np.where(corpo.any(1))[0]; pe_ = ys_[-1]
        pernas = nd.binary_dilation(corpo[pe_ - 24:pe_ - 12].any(0), iterations=3)
        corpo[pe_ - 11:] &= pernas[None, :]
        for r in range(pe_ - 10, corpo.shape[0]):
            corpo[r] &= corpo[r - 1]
        cl, cn = nd.label(corpo)
        if cn > 1:
            tam = nd.sum(corpo, cl, range(1, cn + 1)); corpo = cl == (int(np.argmax(tam)) + 1)
    for _ in range(2):      # auréola clara do JPEG
        borda = corpo & ~nd.binary_erosion(corpo)
        corpo &= ~(borda & (rgb.max(2) > 160) & ((rgb.max(2) - rgb.min(2)) < 50))
    im = Image.fromarray(np.dstack([rgb, corpo * 255]).astype(np.uint8), 'RGBA')
    # escala final + borda dura
    w, h = round(im.width * ESC), round(im.height * ESC)
    # pré-multiplica para o LANCZOS não puxar a cor do fundo para dentro
    a = np.asarray(im).astype(float); a[:, :, :3] *= a[:, :, 3:4] / 255
    p = np.asarray(Image.fromarray(a.astype(np.uint8), 'RGBA').resize((w, h), Image.LANCZOS)).astype(float)
    al = p[:, :, 3:4]
    p[:, :, :3] = np.where(al > 0, np.clip(p[:, :, :3] * 255 / np.maximum(al, 1), 0, 255), 0)
    p[:, :, 3] = np.where(p[:, :, 3] > 110, 255, 0)
    # borda: o que sobrou claro/acinzentado do JPEG vira contorno escuro (some no fundo escuro do Windows)
    m = p[:, :, 3] > 0
    borda = m & ~nd.binary_erosion(m)
    br = p[:, :, :3].max(2); sat = br - p[:, :, :3].min(2)
    clara = borda & (br > 120) & (sat < 60)
    p[clara, :3] = (24, 22, 28)
    return cortar(p.astype(np.uint8))

def cortar(a):
    m = a[:, :, 3] > 0
    ys = np.where(m.any(1))[0]; xs = np.where(m.any(0))[0]
    return a[ys[0]:ys[-1] + 1, xs[0]:xs[-1] + 1].copy()

def capacete(a):
    """centro x do capacete: cinza sem saturação no terço de cima"""
    rgb = a[:, :, :3].astype(int); m = a[:, :, 3] > 0
    sat = rgb.max(2) - rgb.min(2); br = rgb.max(2)
    h = a.shape[0]
    cap = m & (sat < 28) & (br > 70)
    cap[int(h * 0.42):] = False
    ys, xs = np.where(cap)
    if len(xs) < 10: xs = np.where(m[:int(h * 0.4)])[1]
    return float(np.median(xs))

quadros = {k: [recorta(k, f, y0, y1, *x) for x in xs] for k, (f, y0, y1, xs) in CAIXAS.items()}

# ---------- ciclo de passo mais suave: ordem que menos muda de um quadro para o outro ----------
def tela(a, cx, W=160, H=130):
    c = np.zeros((H, W, 4), np.uint8)
    x = int(round(W / 2 - cx)); y = H - a.shape[0]
    c[y:, x:x + a.shape[1]] = a
    return c

def ordem_suave(fr):
    cs = [tela(a, capacete(a)) for a in fr]
    n = len(cs)
    d = [[np.abs(cs[i].astype(int) - cs[j].astype(int)).sum() for j in range(n)] for i in range(n)]
    melhor = min((list((0,) + p) for p in itertools.permutations(range(1, n))),
                 key=lambda o: sum(d[o[i]][o[(i + 1) % n]] for i in range(n)))
    return [fr[i] for i in melhor]

for k in ('frente', 'lado', 'costas'):
    quadros[k] = ordem_suave(quadros[k])

# ---------- operações em cima dos quadros ----------
def mover_parte(a, y_corte, dy):
    """desce (dy>0) ou sobe tudo acima de y_corte; o corpo 'encolhe/estica' na cintura"""
    b = a.copy()
    if dy > 0:
        b[dy:y_corte + dy] = a[0:y_corte]; b[:dy] = 0
    elif dy < 0:
        b = np.vstack([np.zeros((-dy,) + a.shape[1:], np.uint8), a])
        b[0:y_corte] = a[0:y_corte]
        b[y_corte:y_corte - dy] = a[y_corte - 1:y_corte][np.zeros(-dy, int)]
        b[y_corte - dy:] = a[y_corte:]
    return b

def pluma(a, dx):
    """balança a pluma vermelha acima do capacete"""
    rgb = a[:, :, :3].astype(int); m = a[:, :, 3] > 0
    verm = m & (rgb[:, :, 0] > 90) & (rgb[:, :, 0] > rgb[:, :, 1] * 1.6)
    ys = np.where(verm.any(1))[0]
    if len(ys) == 0 or dx == 0: return a
    cap = m & ~verm
    topo_cap = np.where(cap.any(1))[0][0]
    b = a.copy()
    for y in range(ys[0], topo_cap + 1):
        lin = verm[y]
        if not lin.any(): continue
        src = a[y].copy()
        b[y][lin] = 0
        for x in np.where(lin)[0]:
            if 0 <= x + dx < a.shape[1]: b[y][x + dx] = src[x]
    return b

def contorno_cintura(a):
    """linha da cintura (onde começa a saia/pernas): ~62% da altura"""
    return int(a.shape[0] * 0.62)

base = min(quadros['frente'], key=lambda a: a.shape[1])        # o quadro de frente mais fechado (pernas juntas)
cint = contorno_cintura(base)

# parado: respira (tronco desce 1 px) e a pluma balança
resp = [0, 0, 0, 1, 1, 1, 0, 0]
balanco = [0, 0, 1, 1, 0, 0, -1, -1]
parado = [pluma(mover_parte(base, cint, r), b) for r, b in zip(resp, balanco)]
parado = [x[:base.shape[0]] if x.shape[0] > base.shape[0] else x for x in parado]

# Praise the Sun: parado, agacha, pulo com os braços para o alto, e o loop dos 5 quadros no chão
P = quadros['louvor']
agacha = mover_parte(base, cint, 2)
def no_ar(a, dy): return np.vstack([a, np.zeros((dy,) + a.shape[1:], np.uint8)])   # sobra embaixo = sobe dy
louvor = [base, agacha, no_ar(P[0], 5), no_ar(P[1], 2), P[2], P[3], P[4], P[0]]

# tonto: 0 1 2 1 (balançando a cabeça), repetido
T = quadros['tonto']
tonto = [T[0], T[1], T[2], T[1]] * 2

# passo de lado/frente: sobe 1 px nos quadros de passagem (pernas mais juntas)
def com_bob(fr):
    larg = [a.shape[1] for a in fr]
    lim = np.median(larg)
    return [no_ar(a, 1) if w < lim else a for a, w in zip(fr, larg)]

direita = com_bob(quadros['lado'])
LINHAS = {
    'frente': com_bob(quadros['frente']),
    'costas': com_bob(quadros['costas']),
    'direita': direita,
    'esquerda': [a[:, ::-1] for a in direita],
    'parado': parado,
    'louvor': louvor,
    'tonto': tonto,
}

# ---------- célula comum: capacete no centro, pé no fundo ----------
ancoras = {k: [capacete(a) for a in v] for k, v in LINHAS.items()}
# o pulo/respirar não podem mexer o centro: usa o centro do quadro de origem
ancoras['parado'] = [capacete(base)] * len(parado)
ancoras['esquerda'] = [a.shape[1] - 1 - c for a, c in zip(LINHAS['esquerda'], ancoras['direita'])]
meia = max(max(c, a.shape[1] - c) for k in LINHAS for a, c in zip(LINHAS[k], ancoras[k]))
CW = int(np.ceil(meia * 2)) + 2
CH = max(a.shape[0] for v in LINHAS.values() for a in v) + 1
ordem = list(LINHAS)
folha = np.zeros((CH * len(ordem), CW * COLS, 4), np.uint8)
for l, k in enumerate(ordem):
    for c, (a, cx) in enumerate(zip(LINHAS[k], ancoras[k])):
        x = int(round(c * CW + CW / 2 - cx)); y = l * CH + CH - a.shape[0]
        reg = folha[y:y + a.shape[0], x:x + a.shape[1]]
        m = a[:, :, 3] > 0
        reg[m] = a[m]
Image.fromarray(folha, 'RGBA').save(f'{OUT}/spritesheet.png')
print('linhas', ordem, 'quadros', [len(LINHAS[k]) for k in ordem], 'célula', CW, CH, 'folha', folha.shape[1], folha.shape[0])
prev = Image.new('RGBA', (folha.shape[1], folha.shape[0]), (170, 190, 210, 255))
prev.alpha_composite(Image.fromarray(folha, 'RGBA'))
prev.resize((prev.width * 2, prev.height * 2), Image.NEAREST).save(f'{OUT}/previa_folha.png')
