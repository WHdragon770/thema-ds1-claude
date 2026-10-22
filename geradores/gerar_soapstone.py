# Marca de orange soapstone no chão (DS1): rabisco laranja brilhando, 6 quadros pulsando. Gera soapstone.png (6 x 56x18).
# uso: python3 gerar_soapstone.py <pasta>
import math, sys
import numpy as np
from PIL import Image, ImageFilter
W, H, Q = 56, 18, 6
# rabisco em perspectiva (achatado, como escrito no chão): pontos de traços
TRACOS = [[(6, 11), (10, 6), (13, 12), (16, 7)], [(18, 12), (21, 6), (24, 12)], [(20, 9), (23, 9)],
          [(27, 6), (27, 12), (31, 12)], [(33, 12), (36, 6), (39, 12), (42, 6)], [(44, 7), (49, 7), (46, 12), (50, 12)]]

def seg(m, a, b):
    n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1])) * 3) + 1
    for i in range(n + 1):
        x = a[0] + (b[0] - a[0]) * i / n; y = a[1] + (b[1] - a[1]) * i / n
        m[int(round(y)), int(round(x))] = 1

def quadro(q):
    m = np.zeros((H, W), np.float32)
    for tr in TRACOS:
        for a, b in zip(tr[:-1], tr[1:]): seg(m, a, b)
    p = 0.65 + 0.35 * math.sin(q / Q * 2 * math.pi)
    glow = np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2)), np.float32) / 255
    glow = np.clip(glow * 3.2 * p, 0, 1)
    c = np.zeros((H, W, 4), np.uint8)
    c[..., 0] = 255; c[..., 1] = (120 + 60 * glow).astype(np.uint8); c[..., 2] = 30
    c[..., 3] = (glow * 170).astype(np.uint8)
    linha = m > 0
    c[linha] = (255, int(200 + 40 * p), int(120 + 60 * p), 255)
    return c

if __name__ == '__main__':
    f = np.concatenate([quadro(q) for q in range(Q)], 1)
    Image.fromarray(f, 'RGBA').save(f'{sys.argv[1]}/soapstone.png')
    pv = Image.new('RGBA', (f.shape[1], H), (40, 40, 44, 255)); pv.alpha_composite(Image.fromarray(f, 'RGBA'))
    pv.resize((pv.width * 5, H * 5), Image.NEAREST).save(f'{sys.argv[1]}/previa_soapstone.png')
