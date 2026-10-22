# Recorta os quadros do Solaire da folha de referência (JPEG com grade no fundo) e monta a spritesheet do pet.
# uso: python3 recortar.py ref/folha1.jpg saida/ [escala]
import sys, numpy as np
from PIL import Image
from scipy import ndimage as nd

src = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(int)
OUT = sys.argv[2]
ESC = float(sys.argv[3]) if len(sys.argv) > 3 else 0.7

# faixas (y0, y1, x mínimo) de cada linha da folha 1
FAIXAS = {
    'frente': (145, 306, 90),
    'lado':   (300, 455, 95),       # o rótulo SIDE fica à esquerda de x=95
    'costas': (452, 600, 200),
    'louvor': (640, 786, 200),
}

mx = src.max(2); mn = src.min(2)
fundo_claro = (mx > 175) & ((mx - mn) < 45)      # branco e linhas da grade

def quadros(nome):
    y0, y1, xmin = FAIXAS[nome]
    fg = ~fundo_claro[y0:y1]
    fg[:, :xmin] = False
    lab, n = nd.label(nd.binary_dilation(fg, iterations=3))
    objs = [(sl, i + 1) for i, sl in enumerate(nd.find_objects(lab)) if sl[0].stop - sl[0].start > 60]
    objs.sort(key=lambda o: o[0][1].start)
    res = []
    for sl, i in objs:
        ys, xs = sl
        pad = 4
        a0, a1 = max(0, ys.start - pad), min(y1 - y0, ys.stop + pad)
        b0, b1 = max(0, xs.start - pad), xs.stop + pad
        rgb = src[y0 + a0:y0 + a1, b0:b1]
        claro = fundo_claro[y0 + a0:y0 + a1, b0:b1]
        # fundo = claro e ligado à borda do recorte (o contorno preto do boneco segura o preenchimento)
        lb, _ = nd.label(claro)
        bordas = set(np.unique(np.concatenate([lb[0], lb[-1], lb[:, 0], lb[:, -1]]))) - {0}
        bg = np.isin(lb, list(bordas))
        # maior pedaço do boneco + o que encosta nele (pluma); tira restos de grade, texto e a pluma da linha de baixo
        corpo = ~bg & (lab[a0:a1, b0:b1] == i)
        if nome == 'louvor':       # a pluma do Solaire da linha de baixo encosta nos pés: tira o vermelho da parte de baixo
            verm = (rgb[:, :, 0] > 100) & (rgb[:, :, 0] > rgb[:, :, 1] * 1.8)
            corte = int(corpo.shape[0] * 0.72)
            verm_lab, _ = nd.label(nd.binary_dilation(verm, iterations=2))
            ruins = set(np.unique(verm_lab[corte:][verm[corte:]])) - {0}
            corpo &= ~(np.isin(verm_lab, list(ruins)) & nd.binary_dilation(verm, iterations=1))
        cl, cn = nd.label(corpo)
        if cn > 1:
            tam = nd.sum(corpo, cl, range(1, cn + 1))
            maior = cl == (int(np.argmax(tam)) + 1)
            perto = nd.binary_dilation(maior, iterations=2)
            pe = np.where(maior.any(1))[0][-1]
            manter = [k + 1 for k in range(cn) if tam[k] > 25 and (perto & (cl == k + 1)).any()
                      and np.where((cl == k + 1).any(1))[0][0] < pe - 10]
            corpo = maior | np.isin(cl, manter)
        if nome == 'louvor':       # nos pés, só as colunas por onde as pernas descem (o resto é da linha de baixo)
            baixo = int(corpo.shape[0] * 0.7)
            corpo[baixo:] &= ~((rgb[baixo:, :, 0] > 70) & (rgb[baixo:, :, 0] > rgb[baixo:, :, 1] * 1.35))
            ys_ = np.where(corpo.any(1))[0]; pe_ = ys_[-1]
            pernas = nd.binary_dilation(corpo[pe_ - 24:pe_ - 12].any(0), iterations=3)
            corpo[pe_ - 11:] &= pernas[None, :]
            for r in range(pe_ - 10, corpo.shape[0]):     # embaixo, só o que desce direto da linha de cima (sem espalhar pro lado)
                corpo[r] &= corpo[r - 1]
            cl, cn = nd.label(corpo)
            if cn > 1:
                tam = nd.sum(corpo, cl, range(1, cn + 1)); corpo = cl == (int(np.argmax(tam)) + 1)
        # come a auréola clara do JPEG em volta
        for _ in range(2):
            borda = corpo & ~nd.binary_erosion(corpo)
            corpo &= ~(borda & (rgb.max(2) > 160) & ((rgb.max(2) - rgb.min(2)) < 50))
        rgba = np.dstack([rgb, corpo * 255]).astype(np.uint8)
        res.append(Image.fromarray(rgba, 'RGBA'))
    return res

def ancora(img):
    """(x do centro da cabeça, y do pé) para alinhar os quadros"""
    a = np.asarray(img)[:, :, 3] > 0
    ys = np.where(a.any(1))[0]; top, bot = ys[0], ys[-1]
    h = bot - top
    faixa = a[top + int(h * 0.15): top + int(h * 0.35)]
    xs = np.where(faixa)[1]
    return xs.mean(), bot

linhas = {k: quadros(k) for k in FAIXAS}
for k, v in linhas.items(): print(k, len(v), [im.size for im in v])

COLS = 6
direita = linhas['lado']
esquerda = [im.transpose(Image.FLIP_LEFT_RIGHT) for im in direita]
costas = linhas['costas'] + linhas['costas'][:1]
louvor = [linhas['frente'][0]] + linhas['louvor']           # 0 = parado, 1-5 = braços para o sol
grade = [linhas['frente'][:COLS], costas[:COLS], direita[:COLS], esquerda[:COLS], louvor[:COLS]]

# tamanho da célula: cabe o maior quadro com a cabeça no centro e o pé no fundo
esq = dir_ = alto = 0
for linha in grade:
    for im in linha:
        cx, pe = ancora(im)
        esq = max(esq, cx); dir_ = max(dir_, im.width - cx); alto = max(alto, pe + 1)
CW = int(np.ceil(max(esq, dir_) * 2)) + 2; CH = int(alto) + 2
folha = Image.new('RGBA', (CW * COLS, CH * len(grade)), (0, 0, 0, 0))
for l, linha in enumerate(grade):
    for c, im in enumerate(linha):
        cx, pe = ancora(im)
        folha.alpha_composite(im, (int(round(c * CW + CW / 2 - cx)), int(l * CH + CH - 1 - pe)))
fw, fh = round(CW * ESC) * COLS, round(CH * ESC) * len(grade)
peq = folha.resize((fw, fh), Image.LANCZOS)
al = np.asarray(peq).copy(); al[:, :, 3] = np.where(al[:, :, 3] > 110, 255, 0)   # borda dura, sem semitransparência
Image.fromarray(al, 'RGBA').save(OUT + '/spritesheet.png')
print('célula', CW, CH, '-> folha', fw, fh)
prev = Image.new('RGBA', (fw, fh), (170, 190, 210, 255)); prev.alpha_composite(Image.fromarray(al, 'RGBA'))
prev.resize((fw * 2, fh * 2), Image.NEAREST).save(OUT + '/previa_folha.png')
