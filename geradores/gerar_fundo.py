# Fundo do terminal no estilo do menu da fogueira do DS1: pedra escura manchada, vinheta, moldura dupla fina
# marrom-acinzentada com enfeites nos cantos. uso: python3 gerar_fundo.py <saída.png> [largura altura]
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def ruido(w, h, escala, seed):
    rng = np.random.default_rng(seed)
    p = rng.random((h // escala + 2, w // escala + 2)).astype(np.float32)
    return np.array(Image.fromarray((p * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255

def fundo(w=1920, h=1080):
    n = (0.45 * ruido(w, h, 180, 1) + 0.3 * ruido(w, h, 60, 2) + 0.17 * ruido(w, h, 14, 3) + 0.08 * ruido(w, h, 3, 4))
    base = np.array((26, 25, 24), np.float32); claro = np.array((48, 46, 43), np.float32)
    img = base + (claro - base) * ((n - 0.3) / 0.5).clip(0, 1)[..., None]
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    img *= (1 - 0.55 * (d / 1.42).clip(0, 1) ** 2.2)[..., None]                 # vinheta
    im = Image.fromarray(img.clip(0, 255).astype(np.uint8), 'RGB')
    dr = ImageDraw.Draw(im)
    ext, ouro, esc = (92, 84, 70), (120, 108, 86), (12, 11, 10)
    m1, m2 = 14, 22                                                            # moldura dupla
    for m, cor in ((m1, ext), (m2, ouro)):
        dr.rectangle((m, m, w - 1 - m, h - 1 - m), outline=esc, width=3)
        dr.rectangle((m, m, w - 1 - m, h - 1 - m), outline=cor, width=1)
    # enfeite de canto (desenhado no canto de cima à esquerda e espelhado nos outros): curva + voluta
    T = 150; S = 4
    t = Image.new('RGBA', (T * S, T * S), (0, 0, 0, 0)); td = ImageDraw.Draw(t)
    def arco(cx, cy, r, a0, a1, w):
        bb = (S * (cx - r), S * (cy - r), S * (cx + r), S * (cy + r))
        td.arc(bb, a0, a1, fill=esc + (255,), width=S * (w + 2)); td.arc(bb, a0, a1, fill=ouro + (255,), width=S * w)
    arco(m2 + 46, m2 + 46, 46, 180, 270, 1)                    # curva ligando as duas linhas
    arco(m2 + 22, m2 + 22, 13, 90, 360, 1)                     # voluta
    arco(m2 + 22, m2 + 22, 6, 180, 450, 1)
    t = t.resize((T, T), Image.LANCZOS)
    for fx, fy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        q = t.transpose(Image.FLIP_LEFT_RIGHT) if fx else t
        q = q.transpose(Image.FLIP_TOP_BOTTOM) if fy else q
        im.paste(q, (w - T if fx else 0, h - T if fy else 0), q)
    return im

if __name__ == '__main__':
    w, h = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (1920, 1080)
    fundo(w, h).save(sys.argv[1])
