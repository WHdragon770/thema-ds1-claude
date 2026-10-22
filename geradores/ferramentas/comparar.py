# Põe o meu sprite em cima e o quadro da referência embaixo, na mesma altura, pra comparar proporção e cor.
# uso: python3 comparar.py <spritesheet.png> <folha1.jpg> <saída.png>
import sys
from PIL import Image
f = Image.open(sys.argv[1]); W, H = 48, 67
ref = Image.open(sys.argv[2])
cel = [(0, 0), (2, 1), (1, 0), (5, 4)]                                             # (linha, coluna): frente, lado, costas, louvor
refs = [(91, 145, 180, 306), (245, 300, 340, 455), (245, 452, 339, 600), (221, 640, 364, 786)]   # mesmos quadros na folha1
Z = 4
out = Image.new('RGBA', (W * Z * 4 + 30, H * Z * 2), (255, 255, 255, 255))
for i, (l, c) in enumerate(cel):
    bg = Image.new('RGBA', (W, H), (225, 230, 236, 255)); bg.alpha_composite(f.crop((c * W, l * H, (c + 1) * W, (l + 1) * H)))
    out.alpha_composite(bg.resize((W * Z, H * Z), Image.NEAREST), (i * (W * Z + 10), 0))
    r = ref.crop(refs[i]).convert('RGBA'); k = H * Z / r.height
    r = r.resize((int(r.width * k), H * Z)); out.alpha_composite(r, (i * (W * Z + 10), H * Z))
out.save(sys.argv[3])
