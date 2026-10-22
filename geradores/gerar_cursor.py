# Cursores do Windows no tema DS1, em pixel art: espada de Astora (seta), espada do sol (link), sol girando (ocupado),
# barra prateada (texto). Grava .cur (BMP 32 bits + máscara, 32 e 48 px) e .ani. uso: python3 gerar_cursor.py <pasta>
import math, struct, sys
import numpy as np
from PIL import Image

K = (12, 10, 10); ACO = [(240, 240, 236), (196, 196, 192), (150, 150, 146), (104, 104, 100)]
OURO = [(255, 240, 160), (244, 204, 70), (216, 150, 50), (150, 92, 30)]
MARROM = [(126, 70, 48), (86, 46, 32)]; SOL = [(255, 236, 150), (250, 196, 60), (226, 130, 40), (186, 82, 40)]

def tela(n=32): return np.zeros((n, n, 4), np.uint8)
def P(c, x, y, cor):
    if 0 <= x < c.shape[1] and 0 <= y < c.shape[0]: c[y, x] = tuple(cor) + (255,)
def contorno(c):
    a = c[..., 3] > 0; v = np.zeros_like(a)
    v[1:] |= a[:-1]; v[:-1] |= a[1:]; v[:, 1:] |= a[:, :-1]; v[:, :-1] |= a[:, 1:]
    c[v & ~a] = K + (255,)

def espada(dourada=False):
    """espada reta na diagonal, ponta no canto (1,1) = ponto do clique"""
    c = tela(); L = OURO if dourada else ACO
    for i in range(1, 19):                                   # lâmina: 2 px de largura + fio claro
        P(c, i, i, L[0]); P(c, i + 1, i, L[1]); P(c, i, i + 1, L[2])
        if i > 2: P(c, i + 1, i + 1, L[1 if i % 3 else 0])
    P(c, 1, 1, L[0])
    for k in range(-4, 5):                                   # guarda atravessada
        x, y = 20 + k, 20 - k
        P(c, x, y, OURO[1] if abs(k) < 4 else OURO[2]); P(c, x + 1, y, OURO[2])
    for i in range(21, 26): P(c, i, i, MARROM[0]); P(c, i + 1, i, MARROM[1])   # cabo
    for dx, dy in ((26, 26), (27, 26), (26, 27), (27, 27)): P(c, dx, dy, OURO[1])  # pomo
    P(c, 26, 26, OURO[0])
    if dourada:                                              # brilho do sol em volta da ponta
        for x, y in ((5, 1), (1, 5), (7, 4), (4, 7), (9, 2), (2, 9)): P(c, x, y, SOL[0])
    contorno(c)
    return c

def sol(q, n=32):
    """sol do Solaire (rosto + raios) girando; q = quadro 0..7"""
    c = tela(n); cx = cy = n / 2 - 0.5; a0 = q / 8 * math.pi / 4 * 2
    for k in range(12):
        a = a0 + k * math.pi / 6
        comp = 14.5 if k % 2 == 0 else 11.5
        for r in np.arange(7.5, comp, 0.5):
            for w in (-0.6, 0, 0.6):
                x = cx + r * math.cos(a) - w * math.sin(a); y = cy + r * math.sin(a) + w * math.cos(a)
                P(c, int(round(x)), int(round(y)), SOL[1] if r < comp - 2 else SOL[2])
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - cx, y - cy)
            if d <= 7.5: P(c, x, y, SOL[0] if d < 4 and x < cx + 1 else SOL[1] if d < 6.3 else SOL[2])
    for x, y in ((13, 14), (18, 14)): P(c, x, y, SOL[3])       # rostinho
    for x in range(14, 18): P(c, x, 18, SOL[3])
    contorno(c)
    return c

def texto():
    c = tela()
    for y in range(6, 26): P(c, 15, y, ACO[0]); P(c, 16, y, ACO[2])
    for x in range(12, 20): P(c, x, 5, OURO[1]); P(c, x, 26, OURO[1])
    P(c, 12, 5, OURO[2]); P(c, 19, 5, OURO[2]); P(c, 12, 26, OURO[2]); P(c, 19, 26, OURO[2])
    contorno(c)
    return c

def dib(img):
    """BITMAPINFOHEADER + BGRA de baixo pra cima + máscara AND (1 bpp)"""
    h, w = img.shape[:2]
    cab = struct.pack('<IiiHHIIiiII', 40, w, h * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    bgra = img[::-1][..., [2, 1, 0, 3]].tobytes()
    lin = ((w + 31) // 32) * 4; mask = bytearray()
    for row in img[::-1]:
        bits = bytearray(lin)
        for x in range(w):
            if row[x, 3] == 0: bits[x // 8] |= 0x80 >> (x % 8)
        mask += bits
    return cab + bgra + bytes(mask)

def cur(imgs, hot):
    """imgs: lista de arrays (tamanhos diferentes); hot: ponto do clique no tamanho 32"""
    dados = [dib(i) for i in imgs]
    out = struct.pack('<HHH', 0, 2, len(imgs)); off = 6 + 16 * len(imgs)
    for i, d in zip(imgs, dados):
        n = i.shape[0]; hx, hy = round(hot[0] * n / 32), round(hot[1] * n / 32)
        out += struct.pack('<BBBBHHII', n % 256, n % 256, 0, 0, hx, hy, len(d), off); off += len(d)
    return out + b''.join(dados)

def ani(quadros, hot, jiffies=6):
    ch = lambda tag, d: tag + struct.pack('<I', len(d)) + d + (b'\0' if len(d) % 2 else b'')
    anih = struct.pack('<9I', 36, len(quadros), len(quadros), 0, 0, 0, 0, jiffies, 1)
    fram = b'fram' + b''.join(ch(b'icon', cur(q, hot)) for q in quadros)
    corpo = b'ACON' + ch(b'anih', anih) + ch(b'LIST', fram)
    return b'RIFF' + struct.pack('<I', len(corpo)) + corpo

def tam(img, n):                                             # 48 px: amplia sem borrar (1,5x vizinho mais próximo)
    return np.array(Image.fromarray(img, 'RGBA').resize((n, n), Image.NEAREST))

if __name__ == '__main__':
    out = sys.argv[1]
    for nome, img, hot in (('seta', espada(), (1, 1)), ('link', espada(True), (1, 1)), ('texto', texto(), (15, 16))):
        open(f'{out}/{nome}.cur', 'wb').write(cur([img, tam(img, 48)], hot))
    sois = [sol(q) for q in range(8)]
    open(f'{out}/ocupado.ani', 'wb').write(ani([[s, tam(s, 48)] for s in sois], (15, 15)))
    # segundo plano: espada + solzinho girando no canto
    meio = []
    for s in sois:
        c = espada().copy(); m = np.array(Image.fromarray(s, 'RGBA').resize((16, 16), Image.NEAREST))
        reg = c[16:32, 16:32]; a = m[..., 3:4] > 0; reg[:] = np.where(a, m, reg); meio.append([c, tam(c, 48)])
    open(f'{out}/trabalhando.ani', 'wb').write(ani(meio, (1, 1)))
    pv = Image.new('RGBA', (32 * 4 * 4 + 40, 32 * 4), (60, 64, 70, 255))
    for i, im in enumerate((espada(), espada(True), sol(0), texto())):
        pv.alpha_composite(Image.fromarray(im, 'RGBA').resize((128, 128), Image.NEAREST), (i * 138, 0))
    pv.save(f'{out}/previa.png')
