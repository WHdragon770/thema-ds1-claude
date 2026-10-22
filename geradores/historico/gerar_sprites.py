# Gera spritesheet.png (Solaire) e sol.png para o PetSolaire. Python puro (zlib), sem PIL.
import math, struct, sys, zlib

W, H = 28, 32          # célula
COLS = 8
PAL = {
    'k': (22, 20, 26), 'h': (196, 198, 204), 'H': (146, 148, 158), 'd': (92, 94, 104), 'w': (240, 242, 246),
    'r': (176, 32, 30), 'R': (112, 16, 20), 'g': (54, 116, 52), 'G': (32, 74, 36),
    't': (226, 194, 134), 'T': (182, 146, 92), 'y': (252, 210, 40), 'o': (232, 122, 22),
    'a': (66, 66, 76), 'A': (112, 112, 124), 'b': (74, 48, 30), 'B': (110, 74, 44),
}

def nova():
    return [['.'] * W for _ in range(H)]

def put(c, x, y, ch):
    if 0 <= x < W and 0 <= y < H and ch != '.':
        c[y][x] = ch

def stamp(c, linhas, ox, oy):
    for j, l in enumerate(linhas):
        for i, ch in enumerate(l):
            put(c, ox + i, oy + j, ch)

def contorno(c, camada):
    """camada: set de (x,y) pintados; coloca k em volta onde está vazio"""
    for (x, y) in list(camada):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) not in camada and 0 <= nx < W and 0 <= ny < H and c[ny][nx] == '.':
                c[ny][nx] = 'k'

def braco(c, x0, y0, x1, y1, mao=True):
    """braço de 2 px de largura do ombro (x0,y0) até a mão (x1,y1), com contorno"""
    camada = set()
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n); y = round(y0 + (y1 - y0) * i / n)
        for px, py, ch in ((x, y, 'A'), (x + 1, y, 'a')):
            put(c, px, py, ch); camada.add((px, py))
    if mao:
        for px, py in ((x1, y1), (x1 + 1, y1), (x1, y1 + (1 if y1 > y0 else -1)), (x1 + 1, y1 + (1 if y1 > y0 else -1))):
            put(c, px, py, 'd'); camada.add((px, py))
    contorno(c, camada)

def perna(c, xq, yq, xp, yp):
    """perna do quadril (xq,yq) ao pé (xp,yp), 3 px de largura, bota marrom"""
    camada = set()
    n = max(abs(xp - xq), abs(yp - yq), 1)
    for i in range(n + 1):
        x = round(xq + (xp - xq) * i / n); y = round(yq + (yp - yq) * i / n)
        bota = y >= yp - 2
        for k, ch in enumerate(('A', 'a', 'a') if not bota else ('B', 'b', 'b')):
            put(c, x + k, y, ch); camada.add((x + k, y))
    contorno(c, camada)

# ---------- cabeças (20 de largura, coladas em x=4) ----------
CAB_FRENTE = [
    "...........rr.......",
    "..........rR........",
    "..........r.........",
    "......kkkkrkkk......",
    ".....khhwhhhhHk.....",
    ".....khwhhhhhHk.....",
    ".....khkkkkkkHk.....",
    ".....khhhkkhhHk.....",
    ".....khhhkkhhHk.....",
    ".....khhhhhhhHk.....",
    ".....kHHHHHHHdk.....",
    "......kddddddk......",
]
CAB_COSTAS = [
    "........rr..........",
    ".........Rr.........",
    ".........rR.........",
    "......kkkrRkkk......",
    ".....khhhhhhwhk.....",
    ".....kHhhhhhhwk.....",
    ".....kHhhhhhhhk.....",
    ".....kHhhhhhhhk.....",
    ".....kHhhhhhhhk.....",
    ".....kHHhhhhhhk.....",
    ".....kdHHHHHHHk.....",
    "......kddddddk......",
]
CAB_LADO = [
    ".........rrr........",
    "........rR..r.......",
    "........r...........",
    "......kkrkkkkk......",
    ".....khhwhhhhhk.....",
    ".....khwhhhhhhk.....",
    ".....kHhhhhkkkk.....",
    ".....kHhhhhhhkk.....",
    ".....kHhhhhhkhk.....",
    ".....kHhhhhhhhk.....",
    ".....kdHHHHHHHk.....",
    "......kddddddk......",
]

# ---------- troncos (linhas 12-22) ----------
TRONCO_FRENTE = [
    "....kGggggggggGk....",
    "...kggttttttttggk...",
    "...kggtytyytytggk...",
    "...kggttyooyttggk...",
    "...kggtyooooytggk...",
    "...kggttyooyttggk...",
    "...kggtytyytytggk...",
    "...kGgttttttttgGk...",
    "...kGgbbbbbbbbgGk...",
    "...kGGTttttttTGGk...",
    "....kkkTttttTkkk....",
]
TRONCO_COSTAS = [
    "....kGggggggggGk....",
    "...kggggggggggggk...",
    "...kgggggggggggGk...",
    "...kgggggggggggGk...",
    "...kGggggggggggGk...",
    "...kGggggggggggGk...",
    "...kGggggggggggGk...",
    "...kGgggggggggGGk...",
    "...kGGggggggggGGk...",
    "...kkGGGGGGGGGGkk...",
    "....kTttttttttTk....",
]
TRONCO_LADO = [
    ".....kGggggggk......",
    "....kgggggtttk......",
    "....kggggttttk......",
    "....kggggtttyk......",
    "....kggggttyok......",
    "....kggggttyok......",
    "....kGgggtttyk......",
    "....kGgggttttk......",
    "....kGggbbbbbk......",
    "....kGGGTttttk......",
    "....kGGkTttTk.......",
]

def balanca_pluma(cab, dx):
    """a pluma (linhas 0-2 da cabeça) balança dx px"""
    if dx == 0: return cab
    def mv(l): return ('.' * dx + l[:-dx]) if dx > 0 else (l[-dx:] + '.' * -dx)
    return [mv(l) for l in cab[:3]] + cab[3:]

def estrela(c, x, y, ch='y'):
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        put(c, x + dx, y + dy, 'w' if (dx, dy) == (0, 0) else ch)

def boneco(vista, quadro, louvor=None, modo=None):
    c = nova()
    ox = 4
    bob = 0
    if vista in ('frente', 'costas'):
        passo = [0, 1, 0, 0, 0, 1, 0, 0][quadro]          # leve sobe-desce
        bob = passo
        cab = CAB_FRENTE if vista == 'frente' else CAB_COSTAS
        tronco = TRONCO_FRENTE if vista == 'frente' else TRONCO_COSTAS
        # pernas: alterna qual levanta
        lev_e = [0, 1, 1, 0, 0, 0, 0, 0][quadro]; lev_d = [0, 0, 0, 0, 0, 1, 1, 0][quadro]
        bal = [0, 1, 1, 0, 0, -1, -1, 0][quadro]
        cab_dx = 0
        if modo == 'parado':                               # respira: tronco desce 1 px; pluma balança
            lev_e = lev_d = 0; bal = 0
            bob = [0, 0, 0, 1, 1, 1, 0, 0][quadro]
            cab = balanca_pluma(cab, [0, 0, 1, 1, 0, 0, -1, -1][quadro])
        if modo == 'tonto':                                # cabeça e braços cambaleando
            lev_e = [0, 0, 1, 0, 0, 0, 0, 0][quadro]; lev_d = [0, 0, 0, 0, 0, 0, 1, 0][quadro]
            cab_dx = [0, 1, 1, 1, 0, -1, -1, -1][quadro]
            bal = [1, 2, 2, 1, -1, -2, -2, -1][quadro]
            cab = balanca_pluma(cab, -cab_dx)
        if louvor is not None:
            lev_e = lev_d = 0
            bob = 1 if louvor == 1 else 0                  # 1 = agacha
            cab = balanca_pluma(cab, [0, 0, -1, 0, 1, 0, -1, 0][louvor])
        perna(c, ox + 6, 23, ox + 6, 31 - lev_e)
        perna(c, ox + 11, 23, ox + 11, 31 - lev_d)
        stamp(c, tronco, ox, 12 + bob)
        stamp(c, cab, ox + cab_dx, 0 + bob)
        if louvor is None:
            if vista != 'frente' and modo is None: bal = 0
            braco(c, ox + 1, 13 + bob, ox + 1 + bal, 20 + bob)
            braco(c, ox + 17, 13 + bob, ox + 17 - bal, 20 + bob)
        else:
            # louvor: 0 = parado, 1 = agacha abrindo os braços, 2 = pulo com os braços em V, 3-7 = em V no chão
            alvos = [(-1, 20), (-3, 16 + bob), (-4, 5), (-4, 5)]
            ax, ay = alvos[min(louvor, 3)]
            if louvor >= 3 and louvor % 2 == 0: ay -= 1      # tremidinha de alegria
            braco(c, ox + 2, 13 + bob, ox + 1 + ax, ay)
            braco(c, ox + 16, 13 + bob, ox + 16 - ax, ay)
            stamp(c, tronco[:2], ox, 12 + bob)    # ombros por cima dos braços
            if louvor == 2:                       # no ar: tudo 2 px para cima
                c = c[2:] + [['.'] * W for _ in range(2)]
        if modo == 'tonto':                       # duas estrelinhas girando em volta do elmo
            for k in (0, 1):
                a = quadro * math.pi / 4 + k * math.pi
                if abs(math.cos(a)) < 0.5: continue        # passando na frente/atrás do elmo
                estrela(c, round(ox + 9.5 + cab_dx + 9 * math.cos(a)), round(4 + 2 * math.sin(a)), 'y' if k == 0 else 'o')
    else:
        # lado (virado para a direita): ciclo de caminhada de 8 quadros
        f = quadro / COLS * 2 * math.pi
        bob = 1 if quadro in (2, 6) else 0
        pf = round(3 * math.sin(f)); pt = -pf
        lev_f = 1 if math.cos(f) > 0.3 else 0; lev_t = 1 if math.cos(f) < -0.3 else 0
        perna(c, ox + 7, 23, ox + 7 + pt, 31 - lev_t)        # perna de trás
        stamp(c, TRONCO_LADO, ox, 12 + bob)
        perna(c, ox + 8, 23, ox + 8 + pf, 31 - lev_f)        # perna da frente
        stamp(c, TRONCO_LADO[10:], ox, 22 + bob)             # barra da saia por cima
        stamp(c, CAB_LADO, ox, 0 + bob)
        bal = round(-3 * math.sin(f))
        braco(c, ox + 9, 13 + bob, ox + 9 + bal, 20 + bob)
    return c

def sol(quadro, S=26):
    c = [['.'] * S for _ in range(S)]
    cx = cy = (S - 1) / 2
    for y in range(S):
        for x in range(S):
            d = math.hypot(x - cx, y - cy)
            ang = math.atan2(y - cy, x - cx) + quadro * math.pi / 8
            if d <= 6.2: c[y][x] = 'y' if d < 4.8 else 'o'
            elif d <= 7.2: c[y][x] = 'k'
            elif d <= 12.5:
                raio = (math.cos(ang * 8) > 0.55) and d <= 12.5
                if raio: c[y][x] = 'y' if d < 10 else 'o'
    # carinha do sol (como no emblema)
    for x, y in ((10, 11), (15, 11)): c[y][x] = 'k'
    for x in range(10, 16): c[15][x] = 'k' if x in (10, 15) else c[15][x]
    for x in range(11, 15): c[16][x] = 'k'
    return c

def png(path, grade):
    h = len(grade); w = len(grade[0])
    raw = b''
    for l in grade:
        raw += b'\0' + b''.join(bytes(PAL[ch]) + b'\xff' if (ch != '.' or '.' in PAL) else b'\0\0\0\0' for ch in l)
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d))
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))

def espelho(c): return [l[::-1] for l in c]

if __name__ == '__main__':
    out = sys.argv[1]
    linhas = [
        [boneco('frente', q) for q in range(COLS)],
        [boneco('costas', q) for q in range(COLS)],
        [boneco('lado', q) for q in range(COLS)],
        [espelho(boneco('lado', q)) for q in range(COLS)],
        [boneco('frente', q, modo='parado') for q in range(COLS)],
        [boneco('frente', 0, louvor=q) for q in range(COLS)],
        [boneco('frente', q, modo='tonto') for q in range(COLS)],
    ]
    folha = []
    for linha in linhas:
        for y in range(H):
            folha.append(sum((cel[y] for cel in linha), []))
    png(out + '/spritesheet.png', folha)
    s = [sol(q) for q in range(4)]
    png(out + '/sol.png', [sum((q[y] for q in s), []) for y in range(len(s[0]))])
    # prévia ampliada 4x com fundo cinza
    K = 4
    def preview(grade, path):
        g = [[ch for ch in l for _ in range(K)] for l in grade for _ in range(K)]
        PAL['.'] = (170, 190, 210); png(path, g); del PAL['.']
    preview(folha, out + '/previa_folha.png')
    preview([sum((q[y] for q in s), []) for y in range(len(s[0]))], out + '/previa_sol.png')
    print('ok', len(folha[0]), 'x', len(folha))
