# Cursores DS1 v2: MESMO formato e tamanho dos cursores de Acessibilidade dele (*_eoa.cur, 144 e 216 px), só troca o
# preenchimento rosa por dourado do sol (degradê + borda interna + brilho). Ocupado = sol girando do tamanho da ampulheta.
# uso: python3 gerar_cursor2.py <pasta saída> [pasta dos _eoa.cur]
import io, math, struct, sys
import numpy as np
from PIL import Image, ImageDraw
from gerar_cursor import cur, ani

ORIG = sys.argv[2] if len(sys.argv) > 2 else '__LOCALAPPDATA_WSL__/Microsoft/Windows/Cursors'
CLARO, MEIO, ESCURO, BORDA = np.array((255, 244, 186)), np.array((246, 200, 80)), np.array((214, 138, 40)), np.array((150, 86, 24))

def ler(f):
    d = open(f, 'rb').read(); n = struct.unpack('<H', d[4:6])[0]; out = []
    for i in range(n):
        w, h, _, _, hx, hy, sz, off = struct.unpack('<BBBBHHII', d[6 + 16 * i:22 + 16 * i]); b = d[off:off + sz]
        if b[:4] == b'\x89PNG': px = np.array(Image.open(io.BytesIO(b)).convert('RGBA'))
        else:
            W = struct.unpack('<I', b[4:8])[0]; H = struct.unpack('<i', b[8:12])[0] // 2
            px = np.frombuffer(b[40:40 + W * H * 4], np.uint8).reshape(H, W, 4)[::-1][..., [2, 1, 0, 3]].copy()
        out.append((px, hx, hy))
    return out

def vizinho(m, r):
    v = m.copy()
    for _ in range(r):
        v[1:] |= v[:-1].copy(); v[:-1] |= v[1:].copy(); v[:, 1:] |= v[:, :-1].copy(); v[:, :-1] |= v[:, 1:].copy()
    return v

def dourar(px, borda=True):
    a = px[..., 3] > 0; mx = px[..., :3].max(2)
    preto = a & (mx < 90); fill = a & ~preto
    if not fill.any(): return px
    ys, xs = np.where(fill); y0, y1 = ys.min(), ys.max(); x0 = xs.min()
    n = px.shape[0]; rim = fill & vizinho(preto, max(1, n // 48))
    t = ((np.arange(n)[:, None] - y0) / max(1, y1 - y0)).clip(0, 1)
    cor = np.where(t[..., None] < 0.5, CLARO + (MEIO - CLARO) * (t[..., None] * 2), MEIO + (ESCURO - MEIO) * ((t[..., None] - 0.5) * 2))
    cor = np.broadcast_to(cor, (n, n, 3)).copy()
    brilho = fill & ~vizinho(~fill, max(2, n // 24)) & (np.arange(n)[None, :] < x0 + (np.arange(n)[:, None] - y0) * 0.35 + n * 0.06)
    cor[brilho] = cor[brilho] * 0.5 + np.array((255, 252, 230)) * 0.5        # faixa de brilho perto da borda esquerda
    if borda: cor[rim] = BORDA
    out = px.copy()
    k = (mx[fill] / 255.0)[:, None].clip(0.35, 1)                             # mantém o antialias/xadrez do original
    out[..., :3][fill] = (cor[fill] * k + (1 - k) * 20).astype(np.uint8)
    out[..., :3][preto] = (14, 10, 8)
    return out

def sol(n, q, r_ext=None):
    """sol do Solaire, liso (desenhado 4x maior e reduzido), q = quadro de 8"""
    S = 4; N = n * S; im = Image.new('RGBA', (N, N), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    c = N / 2; R = (r_ext or n * 0.46) * S; r = R * 0.5; a0 = q / 8 * math.pi / 6
    for k in range(12):
        a = a0 + k * math.pi / 6; comp = R if k % 2 == 0 else R * 0.8; w = math.pi / 24
        pts = [(c + r * 0.92 * math.cos(a - w * 1.6), c + r * 0.92 * math.sin(a - w * 1.6)), (c + comp * math.cos(a), c + comp * math.sin(a)),
               (c + r * 0.92 * math.cos(a + w * 1.6), c + r * 0.92 * math.sin(a + w * 1.6))]
        d.polygon(pts, fill=(222, 128, 34, 255) if k % 2 else (246, 192, 60, 255), outline=(14, 10, 8, 255), width=int(S * n / 48) or 2)
    d.ellipse((c - r, c - r, c + r, c + r), fill=(250, 206, 76, 255), outline=(14, 10, 8, 255), width=int(S * n / 36) or 3)
    d.ellipse((c - r * 0.72, c - r * 0.78, c + r * 0.5, c + r * 0.44), fill=(255, 238, 160, 255))
    for ex in (-0.32, 0.32): d.ellipse((c + ex * r - r * 0.08, c - r * 0.2, c + ex * r + r * 0.08, c - r * 0.02), fill=(150, 70, 24, 255))
    d.arc((c - r * 0.4, c - r * 0.25, c + r * 0.4, c + r * 0.45), 30, 150, fill=(150, 70, 24, 255), width=max(2, int(r * 0.08)))
    return np.array(im.resize((n, n), Image.LANCZOS))

if __name__ == '__main__':
    out = sys.argv[1]
    for nome, dest in (('arrow', 'seta'), ('link', 'link'), ('ibeam', 'texto')):
        f = ler(f'{ORIG}/{nome}_eoa.cur')
        imgs = [dourar(px, nome != 'ibeam') for px, _, _ in f]; hx, hy = f[0][1], f[0][2]
        open(f'{out}/{dest}.cur', 'wb').write(cur(imgs, (hx * 32 / imgs[0].shape[0], hy * 32 / imgs[0].shape[0])))
    # ocupado: sol do tamanho da ampulheta girando
    w = ler(f'{ORIG}/wait_eoa.cur'); tamanhos = [px.shape[0] for px, _, _ in w]
    quadros = [[sol(n, q, n * 0.42) for n in tamanhos] for q in range(8)]
    open(f'{out}/ocupado.ani', 'wb').write(ani(quadros, (16, 16)))
    # segundo plano: a seta dourada + solzinho girando onde ficava a ampulheta pequena
    b = ler(f'{ORIG}/busy_eoa.cur'); base = [dourar(px) for px, _, _ in b]
    quadros = []
    for q in range(8):
        fr = []
        for px, bs in zip([p for p, _, _ in b], base):
            n = px.shape[0]; c = bs.copy()
            col = (px[..., 3] > 0).any(0); x1 = int(n * 0.15) + int(np.argmin(col[int(n * 0.15):]))     # 1ª coluna vazia depois da seta
            m = px[..., 3] > 0; m[:, :x1] = False; c[m] = 0                                  # apaga a ampulheta pequena
            ys, xs = np.where(m); s = sol(int((ys.max() - ys.min()) * 1.05), q)
            y0 = max(0, (ys.min() + ys.max()) // 2 - s.shape[0] // 2); x0 = min(n - s.shape[1], (xs.min() + xs.max()) // 2 - s.shape[1] // 2)
            reg = c[y0:y0 + s.shape[0], x0:x0 + s.shape[1]]; al = s[..., 3:4] / 255.0
            reg[..., :3] = (s[..., :3] * al + reg[..., :3] * (1 - al)).astype(np.uint8); reg[..., 3] = np.maximum(reg[..., 3], s[..., 3])
            fr.append(c)
        quadros.append(fr)
    hx, hy = b[0][1], b[0][2]
    open(f'{out}/trabalhando.ani', 'wb').write(ani(quadros, (hx * 32 / b[0][0].shape[0], hy * 32 / b[0][0].shape[0])))
    pv = Image.new('RGBA', (144 * 5 + 40, 144), (60, 64, 70, 255))
    for i, im in enumerate([dourar(ler(f'{ORIG}/{n}_eoa.cur')[0][0]) for n in ('arrow', 'link')] + [dourar(ler(f'{ORIG}/ibeam_eoa.cur')[0][0], False)] + [quadros[0][0], sol(144, 0, 144 * 0.42)]):
        pv.alpha_composite(Image.fromarray(im, 'RGBA'), (i * 152, 0))
    pv.save(f'{out}/previa2.png')
