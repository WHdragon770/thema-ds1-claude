# Solaire em pixel art (célula 48x64) desenhado o mais parecido possível com a folha de referência (ref/folha1.jpg):
# elmo grande e arredondado com brilho em Γ e fenda escura, pluma fina na diagonal, capinha verde larga nos ombros,
# tabardo com sol em blocos laranja, cinto marrom, saia clara recortada, braços de malha escura com mãos de pele,
# pernas curtas escuras. Cores tiradas da referência.
# Gera spritesheet.png (8 colunas x 7 linhas: frente, costas, direita, esquerda, parado, louvor, tonto) e sol.png.
# uso: python3 gerar_ref.py <pasta saída>
import math, sys
import numpy as np
from PIL import Image
from gerar_hd import Tela, sol, W, H, COLS

K_ = (16, 14, 18)                                                    # contorno
ACO = [(236, 236, 234), (180, 180, 178), (136, 136, 134), (98, 98, 96), (62, 62, 62)]
VERDE = [(84, 142, 92), (52, 112, 70), (40, 92, 60), (30, 74, 48), (18, 52, 32)]
PLUMA = [(184, 70, 56), (150, 44, 40), (122, 32, 32), (90, 22, 24)]
TAN = [(246, 214, 170), (232, 192, 146), (214, 172, 126), (184, 140, 98), (150, 106, 70)]
LAR, LAR_E, AMA, AMA_C = (216, 146, 62), (186, 82, 40), (244, 204, 70), (255, 236, 150)
MARROM = [(126, 70, 48), (98, 52, 36), (72, 38, 26)]
MALHA = [(118, 118, 116), (84, 84, 84), (60, 60, 62), (44, 44, 46)]
PELE = [(232, 196, 160), (216, 176, 138), (184, 138, 102)]

def P(t, x, y, c):
    if 0 <= x < W and 0 <= y < H: t.c[y, x] = tuple(c) + (255,)

def pinta(t, m, cor_fn):
    for y, x in zip(*np.where(m)): P(t, x, y, cor_fn(x, y))

def borda(m):
    e = m.copy()
    e[1:-1, 1:-1] = m[1:-1, 1:-1] & ~(m[:-2, 1:-1] & m[2:, 1:-1] & m[1:-1, :-2] & m[1:-1, 2:])
    return e

# ---------------- peças ----------------
def pluma(t, pts, larg=1.5):
    m = Tela.vazia(); n = len(pts)
    for i in range(n - 1):
        m |= Tela.capsula(pts[i], pts[i + 1], larg - 0.7 * i / (n - 1))
    ys, xs = np.where(m); y0 = ys.min()
    pinta(t, m, lambda x, y: PLUMA[1])
    for y, x in zip(*np.where(borda(m))): P(t, x, y, PLUMA[3] if (y < H - 1 and not m[y + 1, x]) else PLUMA[1])
    for (x0, y0_), (x1, y1) in zip(pts[:-1], pts[1:]):           # brilho por cima
        P(t, int(round((x0 + x1) / 2)), int(round((y0_ + y1) / 2)) - 0, PLUMA[0])

# meia-largura do elmo por linha (domo arredondado em cima)
HW = [3, 5, 6, 7, 8] + [8] * 13
R = 8

def elmo(t, cx, y0, vista):
    """vista: frente | costas | lado (virado para a direita)"""
    m = Tela.vazia()
    for i, hw in enumerate(HW):
        a, b = cx - hw, cx + hw
        if vista == 'lado': a, b = cx - hw, cx + hw + (1 if 7 <= i <= 16 else 0)
        m[y0 + i, max(0, a):min(W, b)] = True
    def cor(x, y):
        i = y - y0; d = x - cx
        if vista == 'lado':
            if d <= -7: c = ACO[3]
            elif d <= -5: c = ACO[2]
            elif d <= -3: c = ACO[1]
            elif d <= -2: c = ACO[0]
            elif d <= 3: c = ACO[2]
            else: c = ACO[3]
        else:
            if d <= -7: c = ACO[3]
            elif d <= -5: c = ACO[2]
            elif d <= -3: c = ACO[1]
            elif d <= -2: c = ACO[0] if (vista == 'costas' or i < 8) else ACO[1]
            elif d <= 2: c = ACO[2]
            elif d <= 5: c = ACO[2] if i % 4 else ACO[3]
            else: c = ACO[3]
        if i <= 1: c = ACO[0] if d < 1 else ACO[1]
        if i == 17: c = ACO[4]
        return c
    pinta(t, m, cor)
    for y, x in zip(*np.where(borda(m))): P(t, x, y, ACO[4])
    if vista == 'frente':
        for x in range(cx - 2, cx + 4): P(t, x, y0 + 5, ACO[0])                 # Γ de brilho
        for x in range(cx - 1, cx + 4): P(t, x, y0 + 6, ACO[1])
        for x in range(cx - 7, cx + 7): P(t, x, y0 + 8, K_); P(t, x, y0 + 9, ACO[4])   # fenda dos olhos
        for x in range(cx - 7, cx + 7): P(t, x, y0 + 7, ACO[1] if x < cx + 2 else ACO[2])
        for y in range(y0 + 10, y0 + 17):                                        # vinco do meio da viseira
            P(t, cx - 1, y, ACO[0]); P(t, cx, y, ACO[1]); P(t, cx + 1, y, ACO[3])
        for y in range(y0 + 11, y0 + 16, 2):                                     # furinhos de respiro
            P(t, cx - 4, y, ACO[4]); P(t, cx + 3, y, ACO[4])
    elif vista == 'costas':
        for y in range(y0 + 9, y0 + 17): P(t, cx - 5, y, ACO[3])
        for x in range(cx - 7, cx + 7): P(t, x, y0 + 13, ACO[3])
    else:
        r = cx + R
        for x in range(cx + 2, r + 1): P(t, x, y0 + 8, K_); P(t, x, y0 + 9, ACO[4])
        for x in range(cx + 2, r): P(t, x, y0 + 7, ACO[1])
        for y in range(y0 + 10, y0 + 17): P(t, r - 1, y, ACO[1]); P(t, r, y, ACO[3])
        for y in range(y0 + 11, y0 + 16, 2): P(t, r - 4, y, ACO[4])

def capa_frente(t, b, costas=False):
    pts = [(17, 27), (31, 27), (36, 29), (40, 33), (40, 36), (35, 38), (30, 37), (24, 36 + (1 if costas else 0)),
           (18, 37), (13, 38), (8, 36), (8, 33), (12, 29)]
    m = Tela.poli([(x, y + b) for x, y in pts])
    def cor(x, y):
        v = y - (27 + b)
        if v <= 2: return VERDE[0] if 12 < x < 36 else VERDE[1]
        if v <= 5: return VERDE[1] if (x < 22 or costas) else VERDE[2]
        return VERDE[2] if x < 30 else VERDE[3]
    def cor_tex(x, y):
        c = cor(x, y); h = (x * 7 + y * 13) % 11
        if h == 0: return VERDE[max(0, VERDE.index(c) - 1)]
        if h == 5: return VERDE[min(4, VERDE.index(c) + 1)]
        return c
    pinta(t, m, cor_tex)
    for y, x in zip(*np.where(borda(m))): P(t, x, y, VERDE[4])
    for x0 in (14, 20, 28, 34):                                                  # dobras
        for k in range(4): P(t, x0 + (k if x0 > 24 else -k) // 2, 32 + b + k, VERDE[3])

def tronco_frente(t, b, brilho=0):
    m = Tela.poli([(15, 35 + b), (33, 35 + b), (34, 43 + b), (14, 43 + b)])
    pinta(t, m, lambda x, y: TAN[1] if x < 30 else TAN[2])
    for y, x in zip(*np.where(borda(m))): P(t, x, y, TAN[3])
    # sol em blocos (como na referência)
    S = ["..o.o.o..",
         ".oOoOoOo.",
         "oOOyYyOOo",
         "OOyYCYyOO",
         "oOOyYyOOo",
         ".oOoOoOo.",
         "..o.o.o.."]
    cores = {'o': LAR_E, 'O': LAR, 'y': AMA, 'Y': AMA, 'C': AMA_C if brilho else AMA}
    for j, l in enumerate(S):
        for i, ch in enumerate(l):
            if ch != '.': P(t, 20 + i, 36 + b + j, cores[ch])

def tronco_costas(t, b):
    m = Tela.poli([(15, 35 + b), (33, 35 + b), (34, 43 + b), (14, 43 + b)])
    pinta(t, m, lambda x, y: TAN[1] if x < 28 else TAN[2])
    for y, x in zip(*np.where(borda(m))): P(t, x, y, TAN[3])
    for x in range(16, 33): P(t, x, 38 + b, TAN[0] if x < 24 else TAN[1])

def cinto_saia(t, b, x0=14, x1=33, fenda=False):
    for y in (43, 44):
        for x in range(x0, x1 + 1): P(t, x, y + b, MARROM[1] if y == 43 else MARROM[2])
    P(t, x0, 43 + b, MARROM[2])
    m = Tela.poli([(x0, 45 + b), (x1 + 1, 45 + b), (x1 + 2, 51 + b), (x0 - 1, 51 + b)])
    pinta(t, m, lambda x, y: TAN[0] if y < 47 + b and x < 26 else TAN[1] if x < 30 else TAN[2])
    for y, x in zip(*np.where(borda(m))): P(t, x, y, TAN[3])
    for x in range(x0 - 1, x1 + 3):                                              # barra recortada
        if (x - x0) % 4 in (1, 2): t.c[51 + b, x] = 0; P(t, x, 50 + b, TAN[3])
    for x in ((24,) if fenda else (19, 24, 29)):
        for y in range(46 + b, 50 + b): P(t, x, y, TAN[3])

def braco(t, ombro, punho, escuro=0, mao_aberta=False, para_cima=False):
    m = Tela.capsula(ombro, punho, 2.6)
    def cor(x, y):
        i = 1 + escuro
        if (x + y) % 2 == 0 and y % 2 == 0: i += 1
        if x < (ombro[0] + punho[0]) / 2 - 1: i -= 1
        return MALHA[max(0, min(3, i))]
    pinta(t, m, cor)
    for y, x in zip(*np.where(borda(m))): P(t, x, y, MALHA[3])
    # bracelete
    bx = ombro[0] + (punho[0] - ombro[0]) * 0.72; by = ombro[1] + (punho[1] - ombro[1]) * 0.72
    pinta(t, Tela.elipse(bx, by, 2.8, 2.0), lambda x, y: ACO[2] if x < bx else ACO[3])
    # mão de pele
    hx, hy = punho
    mm = Tela.elipse(hx, hy + (0 if para_cima else 1.5), 2.2, 2.0)
    if mao_aberta:
        for dx in (-1.6, 0, 1.6): mm |= Tela.capsula((hx + dx, hy), (hx + dx * 1.4, hy - 3.2), 0.7)
    pinta(t, mm, lambda x, y: PELE[1] if x < hx + 1 else PELE[2])
    for y, x in zip(*np.where(borda(mm))): P(t, x, y, PELE[2])

def perna(t, x, lev=0, b=0, lado=False, escuro=0, dx=0):
    """perna escura com placas; x = meio da perna; lev = pé levantado"""
    top = 49 + b; fim = 63 - lev
    m = Tela.poli([(x - 3, top), (x + 3, top), (x + 3 + dx, fim - 4), (x - 3 + dx, fim - 4)])
    pinta(t, m, lambda xx, y: MALHA[1 + escuro] if xx < x + dx * (y - top) / 12 else MALHA[2 + escuro // 2])
    for y, xx in zip(*np.where(borda(m))): P(t, xx, y, MALHA[3])
    ky = top + 5
    for yy in (top + 9, top + 10):                                              # placa da canela
        for xx in range(x - 2, x + 2): P(t, xx + round(dx * (yy - top) / 12), yy, MALHA[0] if yy == top + 9 else MALHA[1])
    for xx in range(x - 2, x + 2): P(t, xx + round(dx * 0.35), ky, ACO[1 + escuro]); P(t, xx + round(dx * 0.35), ky + 1, ACO[2 + escuro])
    # bota
    bx = x + dx
    bm = Tela.poli([(bx - 3, fim - 4), (bx + 3, fim - 4), (bx + 3 + (2 if lado else 0), fim), (bx - 4, fim)])
    pinta(t, bm, lambda xx, y: ACO[3 + escuro // 1] if y > fim - 2 else ACO[2 + escuro])
    for y, xx in zip(*np.where(borda(bm))): P(t, xx, y, ACO[4])

def contorno(t):
    a = t.c[:, :, 3] > 0
    v = np.zeros_like(a)
    v[1:] |= a[:-1]; v[:-1] |= a[1:]; v[:, 1:] |= a[:, :-1]; v[:, :-1] |= a[:, 1:]
    t.c[v & ~a] = K_ + (255,)

# ---------------- poses ----------------
def espada_escudo(t, b, q):
    # espada reta erguida na diagonal, brilho correndo pela lâmina (q = quadro)
    px, py = 6, 38 + b; tx, ty = 1, 9 + b
    lam = Tela.capsula((px, py - 3), (tx, ty), 1.1)
    pinta(t, lam, lambda x, y: ACO[0] if x <= px - (py - y) * (px - tx) / (py - ty) else ACO[2])
    k = (q % 8) / 7; gx, gy = px + (tx - px) * (0.25 + 0.7 * k), py - 3 + (ty - py + 3) * (0.25 + 0.7 * k)
    for d in (-1, 0, 1): P(t, round(gx), round(gy) + d, (255, 255, 240) if d == 0 else ACO[0])
    pinta(t, Tela.capsula((px - 4, py - 3), (px + 3, py - 1), 0.9), lambda x, y: MARROM[0] if y < py - 2 else MARROM[1])
    pinta(t, Tela.elipse(px, py, 2.2, 2.0), lambda x, y: PELE[1] if x < px + 1 else PELE[2])
    pinta(t, Tela.capsula((px + 0.5, py + 2), (px + 1.5, py + 4), 0.8), lambda x, y: MARROM[2])
    # escudo do sol (heater) na frente do braço esquerdo
    cx, cy = 39, 39 + b
    esc = Tela.poli([(cx - 6, cy - 7), (cx + 6, cy - 7), (cx + 6, cy + 1), (cx + 3, cy + 6), (cx, cy + 8), (cx - 3, cy + 6), (cx - 6, cy + 1)])
    pinta(t, esc, lambda x, y: TAN[1] if x < cx + 2 else TAN[2])
    for y, x in zip(*np.where(borda(esc))): P(t, x, y, ACO[2])
    for j, l in enumerate(["..y..", ".oYo.", "yYAYy", ".oYo.", "..y.."]):
        for i, ch in enumerate(l):
            if ch != '.': P(t, cx - 2 + i, cy - 4 + j, {'o': LAR_E, 'y': LAR, 'Y': AMA, 'A': AMA_C}[ch])

def frente(bob=0, pes=(0, 0), bal=(0, 0), maos='baixo', cab_dx=0, pluma_dx=0, brilho=0, costas=False, estrelas=()):
    t = Tela(); b = bob
    perna(t, 19, pes[0], b); perna(t, 29, pes[1], b)
    cinto_saia(t, b, fenda=costas)
    (tronco_costas if costas else tronco_frente)(t, b, *([] if costas else [brilho]))
    if maos == 'baixo':
        braco(t, (11, 33 + b), (11 + bal[0], 43 + b)); braco(t, (37, 33 + b), (37 - bal[1], 43 + b))
    elif maos == 'meio':
        braco(t, (12, 33 + b), (5, 28 + b), mao_aberta=True, para_cima=True)
        braco(t, (36, 33 + b), (43, 28 + b), mao_aberta=True, para_cima=True)
    elif maos == 'combate':   # espada na mão direita (lado esquerdo da tela), escudo na esquerda
        braco(t, (12, 33 + b), (6, 39 + b)); braco(t, (36, 33 + b), (39, 39 + b))
    else:   # 'cima' (Praise the Sun); maos pode ser ('cima', alt)
        alt = maos[1] if isinstance(maos, tuple) else 0
        braco(t, (13, 33 + b), (3, 20 - alt + b), mao_aberta=True, para_cima=True)
        braco(t, (35, 33 + b), (45, 20 - alt + b), mao_aberta=True, para_cima=True)
    capa_frente(t, b, costas)
    hx = 24 + cab_dx
    if costas:
        pluma(t, [(hx, 12 + b), (hx - 1, 8 + b), (hx - 4, 4 + b), (hx - 8, 2.5 + b), (hx - 12, 3 + b), (hx - 14, 6 + b)])
    elmo(t, hx, 11 + b, 'costas' if costas else 'frente')
    if not costas:
        pluma(t, [(hx + 1, 12 + b), (hx + 2, 8 + b), (hx + 3, 5 + b), (hx + 5 + pluma_dx, 2 + b), (hx + 8 + pluma_dx, 0.5 + b)])
    if maos == 'combate': espada_escudo(t, b, brilho)
    for sx, sy, cor in estrelas:
        for ddx, ddy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            P(t, sx + ddx, sy + ddy, (255, 255, 230) if (ddx, ddy) == (0, 0) else cor)
    contorno(t)
    return t.c

def lado(f):
    """andando virado para a direita, fase f 0..1"""
    t = Tela(); a = f * 2 * math.pi
    b = -1 if abs(math.sin(a)) < 0.4 else 0
    passo = round(6 * math.sin(a))
    lev_n = 2 if math.cos(a) > 0.3 else 0; lev_f = 2 if math.cos(a) < -0.3 else 0
    bal = round(-5 * math.sin(a))
    braco(t, (23, 33 + b), (23 - bal, 43 + b), escuro=1)                     # braço de trás
    perna(t, 23, lev_f, b, lado=True, escuro=1, dx=-passo)
    perna(t, 25, lev_n, b, lado=True, dx=passo)
    # túnica marrom por baixo + tabardo na frente
    m = Tela.poli([(17, 33 + b), (31, 33 + b), (32, 43 + b), (16, 43 + b)])
    pinta(t, m, lambda x, y: MARROM[0] if x < 25 else TAN[1])
    for y, x in zip(*np.where(borda(m))): P(t, x, y, MARROM[2] if x < 25 else TAN[3])
    for j, l in enumerate(["..oO", ".oOy", "oOyY", ".oOy", "..oO"]):
        for i, ch in enumerate(l):
            if ch != '.': P(t, 27 + i, 36 + b + j, {'o': LAR_E, 'O': LAR, 'y': AMA, 'Y': AMA}[ch])
    cinto_saia(t, b, 16, 32)
    # capa caída no ombro, para trás
    onda = round(1.2 * math.sin(2 * a))
    capa = Tela.poli([(18, 26 + b), (30, 26 + b), (32, 29 + b), (29, 33 + b), (23, 37 + b), (15 + onda, 40 + b),
                      (11 + onda, 39 + b), (13, 32 + b)])
    pinta(t, capa, lambda x, y: VERDE[0] if y < 29 + b else VERDE[1] if x > 22 else VERDE[2])
    for y, x in zip(*np.where(borda(capa))): P(t, x, y, VERDE[4])
    for k in range(5): P(t, 21 - k, 31 + b + k, VERDE[3])
    braco(t, (25, 33 + b), (25 + bal, 43 + b))                             # braço da frente
    elmo(t, 22, 11 + b, 'lado')
    pluma(t, [(20, 12 + b), (19, 8 + b), (16, 4 + b), (12, 2.5 + b), (8, 3 + b), (5, 6 + b)])
    contorno(t)
    return t.c

def escalar(q):
    """agarrado numa parede à direita (mãos encostam em x=34), subindo: braços e pernas alternando"""
    t = Tela(); a = q / COLS * 2 * math.pi; sn = math.sin(a)
    b = round(-1.5 * sn)
    braco(t, (22, 33 + b), (32, 20 + round(4 * sn) + b), escuro=1, mao_aberta=True, para_cima=True)      # braço de trás
    perna(t, 22, max(0, round(2 - 2 * sn)), b, lado=True, escuro=1, dx=7)
    perna(t, 24, max(0, round(2 + 2 * sn)), b, lado=True, dx=8)
    m = Tela.poli([(16, 33 + b), (29, 33 + b), (30, 43 + b), (15, 43 + b)])
    pinta(t, m, lambda x, y: MARROM[0] if x < 24 else TAN[1])
    for y, x in zip(*np.where(borda(m))): P(t, x, y, MARROM[2] if x < 24 else TAN[3])
    cinto_saia(t, b, 15, 30)
    capa = Tela.poli([(16, 26 + b), (28, 26 + b), (30, 29 + b), (27, 33 + b), (21, 37 + b), (13, 41 + b), (9, 40 + b), (11, 32 + b)])
    pinta(t, capa, lambda x, y: VERDE[0] if y < 29 + b else VERDE[1] if x > 20 else VERDE[2])
    for y, x in zip(*np.where(borda(capa))): P(t, x, y, VERDE[4])
    elmo(t, 19, 11 + b, 'lado')
    pluma(t, [(17, 12 + b), (16, 8 + b), (13, 4 + b), (9, 2.5 + b), (5, 3 + b), (2, 6 + b)])
    braco(t, (24, 33 + b), (33, 20 - round(4 * sn) + b), mao_aberta=True, para_cima=True)               # braço da frente, por cima
    contorno(t)
    return t.c

def linha_frente(costas=False):
    out = []
    for q in range(COLS):
        pes = [(0, 0), (2, 0), (3, 0), (1, 0), (0, 0), (0, 2), (0, 3), (0, 1)][q]
        bob = [0, -1, -1, 0, 0, -1, -1, 0][q]
        bal = [0, 1, 1, 0, 0, -1, -1, 0][q]
        out.append(frente(bob, pes, (bal, bal) if not costas else (0, 0), costas=costas))
    return out

def linha_parado():
    return [frente([0, 0, 0, 1, 1, 1, 0, 0][q], pluma_dx=[0, 0, 1, 1, 0, 0, -1, -1][q]) for q in range(COLS)]

def linha_louvor():
    out = [frente(), frente(2, maos='meio', pluma_dx=-1), frente(0, (2, 2), maos=('cima', 1), brilho=1, pluma_dx=-1)]
    for q in range(5):
        out.append(frente(maos=('cima', q % 2), brilho=q % 2, pluma_dx=[0, 1, 0, -1, 0][q]))
    return out

def linha_combate():
    return [frente([0, 0, 1, 1, 1, 1, 0, 0][q], maos='combate', brilho=q, pluma_dx=[0, 0, 1, 1, 0, 0, -1, -1][q]) for q in range(COLS)]

def linha_tonto():
    out = []
    for q in range(COLS):
        a = q * math.pi / 4; est = []
        for k, cor in ((0, (255, 216, 64)), (1, (150, 200, 255))):
            aa = a + k * math.pi
            if abs(math.cos(aa)) < 0.45: continue
            est.append((int(round(24 + 14 * math.cos(aa))), int(round(10 + 2 * math.sin(aa))), cor))
        bl = [1, 2, 2, 1, -1, -2, -2, -1][q]
        out.append(frente(0, [(0, 0), (0, 0), (2, 0), (0, 0), (0, 0), (0, 0), (0, 2), (0, 0)][q], (bl, -bl),
                          cab_dx=[0, 1, 2, 1, 0, -1, -2, -1][q], pluma_dx=[0, -1, -1, 0, 0, 1, 1, 0][q], estrelas=est))
    return out

if __name__ == '__main__':
    out = sys.argv[1]
    direita = [lado(q / COLS) for q in range(COLS)]
    linhas = [linha_frente(), linha_frente(costas=True), direita, [d[:, ::-1] for d in direita],
              linha_parado(), linha_louvor(), linha_tonto()]
    sobe = [escalar(q) for q in range(COLS)]
    linhas += [sobe, [d[:, ::-1] for d in sobe], linha_combate()]
    FOLGA = 3
    HC = H + FOLGA
    folha = np.zeros((HC * len(linhas), W * COLS, 4), np.uint8)
    for l, lin in enumerate(linhas):
        for c, q in enumerate(lin):
            y = l * HC + (0 if (l == 5 and c == 2) else FOLGA)       # louvor quadro 2 = pulo
            folha[y:y + H, c * W:(c + 1) * W] = q
    Image.fromarray(folha, 'RGBA').save(f'{out}/spritesheet.png')
    s = np.concatenate([sol(q) for q in range(4)], 1)
    Image.fromarray(s, 'RGBA').save(f'{out}/sol.png')
    p = Image.new('RGBA', (folha.shape[1], folha.shape[0]), (170, 190, 210, 255))
    p.alpha_composite(Image.fromarray(folha, 'RGBA'))
    p.resize((p.width * 2, p.height * 2), Image.NEAREST).save(f'{out}/previa_folha.png')
    print('folha', folha.shape[1], 'x', folha.shape[0])
