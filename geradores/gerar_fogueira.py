# Fogueira do DS1 em pixel art: monte de cinzas e ossos, espada espiralada cravada, fogo tremulando.
# Gera bonfire.png (8 quadros lado a lado, 40x48 cada). uso: python3 gerar_fogueira.py <pasta>
import math, random, sys
import numpy as np
from PIL import Image
W, H, Q = 40, 48, 8
K_ = (14, 10, 10)
CINZA = [(120, 112, 104), (92, 86, 80), (66, 60, 56), (44, 40, 38)]
OSSO = [(214, 204, 180), (170, 160, 138)]
ACO = [(200, 196, 188), (150, 146, 140), (104, 100, 96), (70, 66, 64)]
FOGO = [(255, 246, 200), (255, 216, 96), (250, 160, 40), (220, 92, 24), (150, 40, 16)]

def quadro(q):
    c = np.zeros((H, W, 4), np.uint8)
    def P(x, y, cor):
        if 0 <= x < W and 0 <= y < H: c[y, x] = tuple(cor) + (255,)
    rnd = random.Random(7)
    # monte de cinzas
    for y in range(38, 47):
        meia = int(15 * math.sqrt(max(0, 1 - ((46.5 - y) / 9.5) ** 2))) + 1
        for x in range(20 - meia, 20 + meia):
            i = 0 if y < 40 else 1 if y < 43 else 2
            if rnd.random() < 0.25: i = min(3, i + 1)
            P(x, y, CINZA[i])
    for x0, y0, dx in ((8, 43, 5), (26, 44, 6), (14, 41, -4)):                # ossos
        for k in range(abs(dx)):
            P(x0 + (k if dx > 0 else -k), y0 - k // 3, OSSO[k % 2])
    P(31, 40, OSSO[0]); P(32, 40, OSSO[1]); P(31, 41, OSSO[1])                 # caveirinha
    # fogo (atrás e na frente da espada)
    t = q / Q * 2 * math.pi
    pts = []
    for y in range(18, 42):
        h = (41 - y) / 23
        larg = 9 * (1 - h) ** 0.8 * (1 + 0.15 * math.sin(t * 2 + y * 0.6))
        cx = 20 + 2.2 * h * math.sin(t + y * 0.35)
        for x in range(int(cx - larg), int(cx + larg) + 1):
            d = abs(x - cx) / max(larg, 0.5)
            ruido = 0.5 + 0.5 * math.sin(x * 1.7 + y * 2.3 + t * 3)
            v = (1 - d) * (1 - h * 0.9) + 0.25 * ruido - 0.12
            if v < 0.12: continue
            i = 0 if v > 0.85 else 1 if v > 0.62 else 2 if v > 0.4 else 3 if v > 0.24 else 4
            pts.append((x, y, FOGO[i]))
    for x, y, cor in pts:
        if cor in (FOGO[3], FOGO[4]): P(x, y, cor)
    # espada espiralada cravada
    for y in range(9, 41):
        x = 20 + (1 if y < 20 else 0)
        torc = (y // 2) % 2
        P(x, y, ACO[1 + torc]); P(x + 1, y, ACO[2 + torc])
        if y % 4 == 0: P(x - 1, y, ACO[1]); P(x + 2, y, ACO[3])
    for x in range(16, 26): P(x, 12, ACO[0] if x < 21 else ACO[2])             # guarda
    for x in range(17, 25): P(x, 13, ACO[2])
    for y in range(6, 12): P(20, y, (98, 60, 40)); P(21, y, (72, 42, 30))       # cabo
    P(20, 5, ACO[1]); P(21, 5, ACO[2])
    for x, y, cor in pts:
        if cor in (FOGO[0], FOGO[1], FOGO[2]) and not (19 <= x <= 22 and y < 30): P(x, y, cor)
    # brasas subindo
    for k in range(4):
        f = (q / Q + k / 4) % 1
        P(round(14 + k * 4 + 3 * math.sin(f * 6 + k)), round(30 - f * 26), FOGO[1] if f < 0.5 else FOGO[3])
    a = c[:, :, 3] > 0                                                         # contorno no monte
    v = np.zeros_like(a); v[1:] |= a[:-1]; v[:-1] |= a[1:]; v[:, 1:] |= a[:, :-1]; v[:, :-1] |= a[:, 1:]
    m = v & ~a; m[:30] = False
    c[m] = K_ + (255,)
    return c

if __name__ == '__main__':
    folha = np.concatenate([quadro(q) for q in range(Q)], 1)
    Image.fromarray(folha, 'RGBA').save(f'{sys.argv[1]}/bonfire.png')
    p = Image.new('RGBA', (folha.shape[1], H), (20, 16, 14, 255)); p.alpha_composite(Image.fromarray(folha, 'RGBA'))
    p.resize((p.width * 4, H * 4), Image.NEAREST).save(f'{sys.argv[1]}/previa_bonfire.png')
