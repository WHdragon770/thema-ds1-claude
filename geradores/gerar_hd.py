# Solaire em pixel art "HD" (célula 48x64) para o PetSolaire, desenhado por formas com sombreamento e contorno.
# Gera spritesheet.png (8 colunas x 7 linhas: frente, costas, direita, esquerda, parado, louvor, tonto) e sol.png.
# uso: python3 gerar_hd.py <pasta saída>
import math, sys
import numpy as np
from PIL import Image

W, H = 48, 64
COLS = 8
CONTORNO = (26, 20, 30)

# materiais: tons do mais claro ao mais escuro
MAT = {
    'aco':    [(236, 238, 244), (196, 200, 210), (148, 153, 166), (100, 104, 120), (64, 66, 80)],
    'pluma':  [(232, 84, 70), (192, 40, 38), (150, 26, 30), (108, 16, 24), (74, 10, 18)],
    'verde':  [(112, 172, 92), (72, 136, 64), (52, 108, 52), (36, 80, 40), (24, 56, 30)],
    'tecido': [(250, 228, 178), (232, 202, 146), (212, 176, 118), (176, 138, 88), (134, 98, 60)],
    'malha':  [(170, 172, 182), (136, 138, 150), (106, 108, 120), (78, 80, 94), (54, 56, 68)],
    'couro':  [(176, 122, 72), (144, 96, 56), (116, 76, 44), (86, 54, 32), (60, 38, 24)],
    'bota':   [(132, 118, 112), (100, 88, 84), (76, 66, 64), (56, 48, 48), (38, 32, 34)],
    'ouro':   [(255, 236, 140), (240, 200, 80), (214, 160, 50), (170, 110, 30), (120, 70, 20)],
}
SOL_AM = (255, 216, 64); SOL_LA = (240, 140, 36); SOL_VE = (204, 72, 32); SOL_CL = (255, 246, 190)

class Tela:
    def __init__(s):
        s.c = np.zeros((H, W, 4), np.uint8)
    # ---------- máscaras ----------
    @staticmethod
    def vazia(): return np.zeros((H, W), bool)
    @staticmethod
    def poli(pts):
        m = Tela.vazia()
        ys = [p[1] for p in pts]
        for y in range(max(0, int(min(ys))), min(H, int(math.ceil(max(ys))) + 1)):
            yc = y + 0.5; xs = []
            for (x1, y1), (x2, y2) in zip(pts, pts[1:] + pts[:1]):
                if (y1 <= yc < y2) or (y2 <= yc < y1):
                    xs.append(x1 + (yc - y1) * (x2 - x1) / (y2 - y1))
            xs.sort()
            for a, b in zip(xs[::2], xs[1::2]):
                m[y, max(0, int(round(a))):min(W, int(round(b)))] = True
        return m
    @staticmethod
    def elipse(cx, cy, rx, ry):
        yy, xx = np.mgrid[0:H, 0:W]
        return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1
    @staticmethod
    def capsula(p0, p1, r):
        yy, xx = np.mgrid[0:H, 0:W]; px = xx + 0.5; py = yy + 0.5
        (x0, y0), (x1, y1) = p0, p1
        dx, dy = x1 - x0, y1 - y0; L = dx * dx + dy * dy or 1
        t = np.clip(((px - x0) * dx + (py - y0) * dy) / L, 0, 1)
        return (px - x0 - t * dx) ** 2 + (py - y0 - t * dy) ** 2 <= r * r
    @staticmethod
    def ret(x0, y0, x1, y1):
        m = Tela.vazia(); m[max(0, y0):max(0, y1 + 1), max(0, x0):max(0, x1 + 1)] = True; return m
    # ---------- pintura ----------
    def pintar(s, m, mat, luz='cil', borda=True, textura=None, escurecer=0):
        """luz 'cil' = cilindro iluminado da esquerda; 'pano' = menos contraste; 'cima' = claro em cima"""
        if not m.any(): return
        tons = MAT[mat]
        ys, xs = np.where(m)
        x0, x1 = xs.min(), xs.max(); y0, y1 = ys.min(), ys.max()
        wid = max(1, x1 - x0); hei = max(1, y1 - y0)
        for y, x in zip(ys, xs):
            t = (x - x0) / wid; v = (y - y0) / hei
            if luz == 'cil':
                i = 2 if t < 0.1 else 0 if t < 0.3 else 1 if t < 0.52 else 2 if t < 0.8 else 3
            elif luz == 'pano':
                i = 1 if t < 0.35 else 2 if t < 0.78 else 3
            elif luz == 'cima':
                i = 0 if v < 0.18 else 1 if v < 0.5 else 2 if v < 0.85 else 3
            else:
                i = 2
            if textura == 'malha' and (y % 2 == 0) and ((x + y // 2) % 2 == 0): i = min(4, i + 1)
            i = min(4, i + escurecer)
            s.c[y, x] = tons[i] + (255,)
        if borda:   # borda da peça um tom mais escuro (separa as peças por dentro)
            dentro = m.copy()
            ed = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
            for y, x in zip(*np.where(ed)):
                s.c[y, x] = tons[4] + (255,)
    def px(s, x, y, cor):
        if 0 <= x < W and 0 <= y < H: s.c[y, x] = tuple(cor) + (255,)
    def contorno(s):
        a = s.c[:, :, 3] > 0
        viz = np.zeros_like(a)                     # vizinhos sem dar a volta na borda
        viz[1:] |= a[:-1]; viz[:-1] |= a[1:]; viz[:, 1:] |= a[:, :-1]; viz[:, :-1] |= a[:, 1:]
        s.c[viz & ~a] = CONTORNO + (255,)
    def deslocar(s, dx=0, dy=0):
        s.c = np.roll(np.roll(s.c, dy, 0), dx, 1)

# ---------- peças ----------
def pluma(t, base, pontos):
    """pena vermelha: segue os pontos com espessura que afina na ponta"""
    m = Tela.vazia(); n = len(pontos)
    for i in range(n - 1):
        r = 1.9 - 1.0 * i / (n - 1)
        m |= Tela.capsula(pontos[i], pontos[i + 1], r)
    t.pintar(m, 'pluma', luz='cima')
    # nervura clara
    for (x0, y0), (x1, y1) in zip(pontos[:-2], pontos[1:-1]):
        t.px(int(x0), int(y0), MAT['pluma'][0])

def elmo_frente(t, cx, y0, olhando='frente'):
    l, r = cx - 8, cx + 8
    m = Tela.poli([(l + 2, y0), (r - 1, y0), (r + 1, y0 + 2), (r + 1, y0 + 13), (r + 2, y0 + 15),
                   (l - 2, y0 + 15), (l - 1, y0 + 13), (l - 1, y0 + 2)])
    t.pintar(m, 'aco', 'cil')
    # tampa de cima clara
    for x in range(l + 1, r): t.px(x, y0 + 1, MAT['aco'][0] if x < cx + 3 else MAT['aco'][1])
    # aba de baixo
    for x in range(l - 1, r + 2): t.px(x, y0 + 14, MAT['aco'][3])
    if olhando == 'frente':
        # fenda em T
        for x in range(l + 1, r): t.px(x, y0 + 7, MAT['aco'][4]); t.px(x, y0 + 8, CONTORNO)
        for x in range(l + 1, r): t.px(x, y0 + 6, MAT['aco'][0] if x < cx else MAT['aco'][1])
        for y in range(y0 + 9, y0 + 13):
            t.px(cx - 1, y, CONTORNO); t.px(cx, y, MAT['aco'][4])
            t.px(cx - 2, y, MAT['aco'][0]); t.px(cx + 1, y, MAT['aco'][3])
        # rebites
        for x in (l + 1, r - 1):
            t.px(x, y0 + 4, MAT['aco'][0]); t.px(x, y0 + 11, MAT['aco'][0])
    else:
        # nuca: só reflexo e rebites
        for y in range(y0 + 3, y0 + 12): t.px(cx - 4, y, MAT['aco'][0])
        for x in (l + 1, r - 1): t.px(x, y0 + 4, MAT['aco'][1]); t.px(x, y0 + 11, MAT['aco'][1])

def elmo_lado(t, cx, y0):
    l, r = cx - 7, cx + 7
    m = Tela.poli([(l + 1, y0), (r - 1, y0), (r + 1, y0 + 2), (r + 1, y0 + 13), (r + 2, y0 + 15),
                   (l - 1, y0 + 15), (l - 1, y0 + 2)])
    t.pintar(m, 'aco', 'cil')
    for x in range(l + 1, r): t.px(x, y0 + 1, MAT['aco'][0] if x < cx + 2 else MAT['aco'][1])
    for x in range(l - 1, r + 2): t.px(x, y0 + 14, MAT['aco'][3])
    # fenda dos olhos na frente e furos de respiro
    for x in range(cx + 1, r + 2): t.px(x, y0 + 7, MAT['aco'][4]); t.px(x, y0 + 8, CONTORNO)
    for x in range(cx + 1, r + 1): t.px(x, y0 + 6, MAT['aco'][0])
    for (x, y) in ((r - 1, y0 + 10), (r - 1, y0 + 12), (r - 3, y0 + 10), (r - 3, y0 + 12)): t.px(x, y, CONTORNO)
    t.px(l + 2, y0 + 4, MAT['aco'][0]); t.px(l + 2, y0 + 11, MAT['aco'][0])

def emblema(t, cx, cy, brilho=0, clip=None):
    """sol do tabardo: miolo amarelo, anel laranja, 8 raios (laranja e ponta vermelha)"""
    pts = []
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        pts += [(cx + 4 * dx, cy + 4 * dy, SOL_LA), (cx + 5 * dx, cy + 5 * dy, SOL_VE)]
    for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        pts += [(cx + 3 * dx, cy + 3 * dy, SOL_LA), (cx + 4 * dx, cy + 4 * dy, SOL_VE)]
    for y in range(-2, 3):
        for x in range(-2, 3):
            d = math.hypot(x, y)
            if d <= 2.3: pts.append((cx + x, cy + y, SOL_LA if d > 1.5 else (SOL_CL if brilho and d < 0.5 else SOL_AM)))
    for x, y, cor in pts:
        if clip is None or (0 <= y < H and 0 <= x < W and clip[y, x]): t.px(x, y, cor)

def mao(t, p, aberta=False, para_cima=False):
    x, y = p
    m = Tela.elipse(x, y, 2.2, 2.0)
    if aberta and para_cima:
        for dx in (-1.5, 0, 1.5): m |= Tela.capsula((x + dx, y), (x + dx * 1.3, y - 3), 0.7)
    t.pintar(m, 'couro', 'cima')

def braco(t, ombro, cotovelo, punho, escuro=0, aberta=False, para_cima=False):
    t.pintar(Tela.capsula(ombro, cotovelo, 2.4), 'malha', 'cil', textura='malha', escurecer=escuro)
    t.pintar(Tela.capsula(cotovelo, punho, 2.3), 'aco', 'cil', escurecer=1 + escuro)
    # cotoveleira
    t.pintar(Tela.elipse(cotovelo[0], cotovelo[1], 2.2, 1.8), 'aco', 'cima', escurecer=escuro)
    mao(t, punho, aberta, para_cima)

def perna(t, quadril, joelho, pe, lado=0, escuro=0):
    """lado: 0 = de frente; +1 = bota para a direita"""
    t.pintar(Tela.capsula(quadril, joelho, 2.8), 'malha', 'cil', textura='malha', escurecer=escuro)
    t.pintar(Tela.capsula(joelho, (pe[0], pe[1] - 4), 2.6), 'aco', 'cil', escurecer=1 + escuro)
    t.pintar(Tela.elipse(joelho[0], joelho[1], 2.4, 2.0), 'aco', 'cima', escurecer=escuro)
    x, y = pe
    if lado == 0: bota = Tela.poli([(x - 3, y - 5), (x + 3, y - 5), (x + 4, y), (x - 4, y)])
    else: bota = Tela.poli([(x - 3, y - 5), (x + 2, y - 5), (x + 3, y - 2), (x + 6, y - 1), (x + 6, y), (x - 3, y)])
    t.pintar(bota, 'bota', 'cima', escurecer=escuro)
    for xx in range(x - 4, x + (7 if lado else 5)):
        if bota[min(H - 1, y), max(0, min(W - 1, xx))]: t.px(xx, y, MAT['bota'][4])

# ---------- poses ----------
def frente(p):
    """p: dict com bob, pes (dy esq, dy dir), maos [(ombro, cotovelo, punho) esq/dir], cab_dx, pluma_dx,
    brilho, louvor, costas, estrelas"""
    t = Tela(); cx = 24; b = p.get('bob', 0); costas = p.get('costas', False)
    hx = cx + p.get('cab_dx', 0)
    # capa atrás (pontas que aparecem dos lados)
    if not costas:
        t.pintar(Tela.poli([(12, 25 + b), (16, 25 + b), (16, 41 + b), (11, 43 + b)]), 'verde', 'pano', escurecer=1)
        t.pintar(Tela.poli([(32, 25 + b), (36, 25 + b), (37, 43 + b), (32, 41 + b)]), 'verde', 'pano', escurecer=1)
    # pernas
    le, ld = p.get('pes', (0, 0))
    perna(t, (20, 45 + b), (20, 52 + b - le // 2), (20, 63 - le))
    perna(t, (28, 45 + b), (28, 52 + b - ld // 2), (28, 63 - ld))
    # saia do tabardo
    saia = Tela.poli([(16, 40 + b), (32, 40 + b), (34, 48 + b), (14, 48 + b)])
    t.pintar(saia, 'tecido', 'pano')
    for x in range(14, 35):
        if x % 3 == 0: t.px(x, 48 + b, (0, 0, 0)) if False else None
    for x in range(15, 34, 3): t.c[48 + b, x] = 0                        # barra recortada
    for x in (19, 24, 29):
        for y in range(42 + b, 48 + b): t.px(x, y, MAT['tecido'][3])
    # tronco (malha) e tabardo
    t.pintar(Tela.poli([(15, 23 + b), (33, 23 + b), (33, 38 + b), (15, 38 + b)]), 'malha', 'cil', textura='malha')
    if costas:
        capa = Tela.poli([(12, 23 + b), (36, 23 + b), (38, 45 + b), (10, 45 + b)])
        t.pintar(capa, 'verde', 'pano')
        for x, y0 in ((17, 29), (24, 27), (31, 29)):                       # dobras
            for y in range(y0 + b, 44 + b): t.px(x + (y - y0) // 8, y, MAT['verde'][3])
        for x in range(10, 39, 2): t.c[45 + b, x] = 0
    else:
        tab = Tela.poli([(18, 23 + b), (30, 23 + b), (31, 39 + b), (17, 39 + b)])
        t.pintar(tab, 'tecido', 'pano')
        emblema(t, 24, 31 + b, p.get('brilho', 0), clip=tab)
        # cinto com fivela
        t.pintar(Tela.ret(16, 38 + b, 32, 40 + b), 'couro', 'cima')
        t.pintar(Tela.ret(23, 38 + b, 25, 40 + b), 'ouro', 'cima', borda=False)
        t.px(24, 39 + b, MAT['couro'][3])
    # manto verde nos ombros
    manto = Tela.poli([(17, 21 + b), (31, 21 + b), (37, 24 + b), (38, 28 + b), (33, 29 + b), (24, 27 + b),
                       (15, 29 + b), (10, 28 + b), (11, 24 + b)])
    t.pintar(manto, 'verde', 'cima')
    if not costas:
        for x in range(20, 29): t.px(x, 27 + b if abs(x - 24) > 1 else 26 + b, MAT['verde'][3])
    # braços
    for (o, c_, pu), aberta in zip(p['maos'], (True, True)):
        braco(t, (o[0], o[1] + b), (c_[0], c_[1] + b), (pu[0], pu[1] + b), aberta=p.get('louvor', False),
              para_cima=p.get('louvor', False))
    if p.get('louvor'):  # ombreiras por cima dos braços erguidos
        t.pintar(Tela.elipse(13, 24 + b, 4, 3), 'verde', 'cima')
        t.pintar(Tela.elipse(35, 24 + b, 4, 3), 'verde', 'cima')
    # cabeça
    elmo_frente(t, hx, 7 + b, 'costas' if costas else 'frente')
    pdx = p.get('pluma_dx', 0)
    if costas:
        pluma(t, None, [(hx, 8 + b), (hx, 5 + b), (hx - 1, 2.5 + b), (hx - 3, 1 + b), (hx - 6, 0.5 + b), (hx - 9, 1.5 + b), (hx - 10, 3 + b)])
    else:
        pluma(t, None, [(hx - 1, 8 + b), (hx - 1, 5 + b), (hx, 2.5 + b), (hx + 2 + pdx * 0.5, 1 + b), (hx + 5 + pdx, 0.5 + b), (hx + 8 + pdx, 1.5 + b), (hx + 9 + pdx, 3 + b)])
    for (sx, sy, cor) in p.get('estrelas', []):
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            t.px(sx + dx, sy + dy, (255, 255, 230) if (dx, dy) == (0, 0) else cor)
    t.contorno()
    return t.c

def lado(f):
    """caminhada virado para a direita; f = fase 0..1"""
    t = Tela(); cx = 24
    a = f * 2 * math.pi
    b = -1 if abs(math.sin(a)) < 0.4 else 0           # sobe na passagem das pernas
    passo = 6 * math.sin(a)
    def pe_e_joelho(fase_x, lev):
        px_ = cx + fase_x; py = 63 - lev
        return (cx + fase_x * 0.5 + (2 if lev else 0), 53 + b - lev // 2), (int(round(px_)), py)
    lev_n = 3 if math.cos(a) > 0.3 else 0; lev_f = 3 if math.cos(a) < -0.3 else 0
    jf, pf = pe_e_joelho(-passo, lev_f); jn, pn = pe_e_joelho(passo, lev_n)
    bal = -5 * math.sin(a)
    # braço de trás (mais escuro)
    braco(t, (cx + 1, 25 + b), (cx + 1 - bal * 0.5, 31 + b), (cx + 1 - bal, 37 + b), escuro=1)
    perna(t, (cx, 45 + b), jf, pf, lado=1, escuro=1)
    # capa esvoaçando para trás
    onda = int(round(1.5 * math.sin(a * 2)))
    capa = Tela.poli([(cx - 3, 22 + b), (cx + 2, 22 + b), (cx - 1, 34 + b), (cx - 4 + onda, 44 + b),
                      (cx - 9 + onda, 43 + b), (cx - 7, 30 + b)])
    t.pintar(capa, 'verde', 'pano')
    # tronco, tabardo, cinto, saia
    perna(t, (cx + 1, 45 + b), jn, pn, lado=1)
    t.pintar(Tela.poli([(cx - 4, 22 + b), (cx + 5, 22 + b), (cx + 6, 38 + b), (cx - 4, 38 + b)]), 'malha', 'cil', textura='malha')
    tab = Tela.poli([(cx + 1, 23 + b), (cx + 6, 23 + b), (cx + 7, 39 + b), (cx + 1, 39 + b)])
    t.pintar(tab, 'tecido', 'pano')
    emblema(t, cx + 5, 31 + b, clip=tab & ~np.roll(~tab, -1, 1))
    t.pintar(Tela.ret(cx - 4, 38 + b, cx + 7, 40 + b), 'couro', 'cima')
    t.pintar(Tela.ret(cx + 5, 38 + b, cx + 7, 40 + b), 'ouro', 'cima', borda=False)
    saia = Tela.poli([(cx - 4, 40 + b), (cx + 7, 40 + b), (cx + 9 + passo * 0.2, 48 + b), (cx - 6, 48 + b)])
    t.pintar(saia, 'tecido', 'pano')
    for x in range(cx - 6, cx + 10, 3): t.c[48 + b, x] = 0
    # manto no ombro
    t.pintar(Tela.poli([(cx - 5, 21 + b), (cx + 4, 21 + b), (cx + 7, 25 + b), (cx + 5, 28 + b), (cx - 6, 29 + b)]), 'verde', 'cima')
    # braço da frente
    braco(t, (cx + 1, 25 + b), (cx + 1 + bal * 0.5, 31 + b), (cx + 2 + bal, 37 + b))
    elmo_lado(t, cx + 1, 7 + b)
    hx = cx + 1
    pluma(t, None, [(hx - 1, 8 + b), (hx - 2, 5 + b), (hx - 3, 2.5 + b), (hx - 5, 1 + b), (hx - 8, 0.5 + b), (hx - 11, 1.5 + b), (hx - 12, 3 + b)])
    t.contorno()
    return t.c

# braços de frente: (ombro, cotovelo, punho)
def maos_baixo(bal=0, abre=0):
    return [((13, 25), (11 - abre, 31), (12 + bal - abre * 2, 37)),
            ((35, 25), (37 + abre, 31), (36 - bal + abre * 2, 37))]
def maos_cima(alt=0, abre=0):
    return [((13, 24), (8 - abre, 17 - alt), (6 - abre, 10 - alt)),
            ((35, 24), (40 + abre, 17 - alt), (42 + abre, 10 - alt))]
def maos_meio():
    return [((13, 24), (8, 22), (4, 18)), ((35, 24), (40, 22), (44, 18))]

def linha_frente(costas=False):
    out = []
    for q in range(COLS):
        pes = [(0, 0), (2, 0), (3, 0), (1, 0), (0, 0), (0, 2), (0, 3), (0, 1)][q]
        bob = [0, -1, -1, 0, 0, -1, -1, 0][q]
        bal = [0, 1, 2, 1, 0, -1, -2, -1][q]
        out.append(frente({'bob': bob, 'pes': pes, 'maos': maos_baixo(0 if costas else bal), 'costas': costas}))
    return out

def linha_parado():
    out = []
    for q in range(COLS):
        b = [0, 0, 0, 1, 1, 1, 0, 0][q]
        out.append(frente({'bob': b, 'maos': maos_baixo(), 'pluma_dx': [0, 0, 1, 1, 0, 0, -1, -1][q]}))
    return out

def linha_louvor():
    out = [frente({'maos': maos_baixo()}),
           frente({'bob': 2, 'maos': maos_meio(), 'pluma_dx': -1})]       # agacha abrindo os braços
    c = frente({'maos': maos_cima(1, 1), 'louvor': True, 'brilho': 1, 'pluma_dx': -1, 'pes': (2, 2)})
    out.append(c)                                                          # pulo: sobe 3 px na hora de montar a folha
    for q in range(5):
        out.append(frente({'maos': maos_cima(q % 2, q % 2), 'louvor': True, 'brilho': q % 2,
                           'pluma_dx': [0, 1, 0, -1, 0][q]}))
    return out

def linha_tonto():
    out = []
    for q in range(COLS):
        a = q * math.pi / 4
        est = []
        for k, cor in ((0, (255, 216, 64)), (1, (150, 200, 255))):
            aa = a + k * math.pi
            if abs(math.cos(aa)) < 0.45: continue
            est.append((int(round(24 + 13 * math.cos(aa))), int(round(5 + 2 * math.sin(aa))), cor))
        out.append(frente({'cab_dx': [0, 1, 2, 1, 0, -1, -2, -1][q], 'pluma_dx': [0, -1, -1, 0, 0, 1, 1, 0][q],
                           'maos': maos_baixo([1, 2, 2, 1, -1, -2, -2, -1][q], 1),
                           'pes': [(0, 0), (0, 0), (2, 0), (0, 0), (0, 0), (0, 0), (0, 2), (0, 0)][q], 'estrelas': est}))
    return out

def sol(q, S=34):
    c = np.zeros((S, S, 4), np.uint8); cx = cy = (S - 1) / 2
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - cy); ang = math.atan2(y - cy, x - cx) + q * math.pi / 16
            if d <= 7.5: col = SOL_CL if d < 3 else SOL_AM if d < 6 else SOL_LA
            elif d <= 8.5: col = SOL_VE
            elif d <= 16 and math.cos(ang * 8) > 0.6 - (16 - d) * 0.02: col = SOL_AM if d < 11 else SOL_LA if d < 14 else SOL_VE
            elif d <= 12 and math.cos(ang * 8 + math.pi) > 0.85: col = SOL_LA
            else: continue
            c[y, x] = col + (255,)
    # carinha
    for x, y in ((13, 15), (20, 15), (13, 16), (20, 16)): c[y, x] = CONTORNO + (255,)
    for x in range(14, 20): c[20 if x in (14, 19) else 21, x] = CONTORNO + (255,)
    return c

if __name__ == '__main__':
    out = sys.argv[1]
    direita = [lado(q / COLS) for q in range(COLS)]
    linhas = [linha_frente(), linha_frente(costas=True), direita, [d[:, ::-1] for d in direita],
              linha_parado(), linha_louvor(), linha_tonto()]
    FOLGA = 3                                   # espaço em cima da célula para o pulo não cortar a pluma
    HC = H + FOLGA
    folha = np.zeros((HC * len(linhas), W * COLS, 4), np.uint8)
    for l, lin in enumerate(linhas):
        for c, q in enumerate(lin):
            y = l * HC + (0 if (l == 5 and c == 2) else FOLGA)       # louvor quadro 2 = pulo
            folha[y:y + H, c * W:(c + 1) * W] = q
    Image.fromarray(folha, 'RGBA').save(f'{out}/spritesheet.png')
    s = np.concatenate([sol(q) for q in range(4)], 1)
    Image.fromarray(s, 'RGBA').save(f'{out}/sol.png')
    for nome, img, k in (('previa_folha', folha, 2), ('previa_sol', s, 3)):
        p = Image.new('RGBA', (img.shape[1], img.shape[0]), (170, 190, 210, 255))
        p.alpha_composite(Image.fromarray(img, 'RGBA'))
        p.resize((p.width * k, p.height * k), Image.NEAREST).save(f'{out}/{nome}.png')
    print('folha', folha.shape[1], 'x', folha.shape[0])
