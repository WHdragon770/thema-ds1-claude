# Gera os GIFs e prévias da documentação (docs/bonecos/anim) a partir das imagens que o tema instala.
# uso (na raiz do repo): python3 geradores/ferramentas/previas_docs.py
import os
from PIL import Image

OUT = 'docs/bonecos/anim'
FUNDO = (24, 20, 22, 255)
LIN = ['frente', 'costas', 'direita', 'esquerda', 'parado', 'louvor', 'tonto', 'escalar', 'escalar_e', 'combate']
os.makedirs(OUT, exist_ok=True)

folha = Image.open('windows/PetSolaire/spritesheet.png')
CW, CH = folha.width // 8, folha.height // len(LIN)
sol = Image.open('windows/PetSolaire/sol.png'); SW = sol.width // 4

def q(l, i):
    r = LIN.index(l); return folha.crop((i * CW, r * CH, (i + 1) * CW, (r + 1) * CH))

def gif(nome, quadros, ms=125, z=3):
    fr = [Image.alpha_composite(Image.new('RGBA', f.size, FUNDO), f).resize((f.width * z, f.height * z), Image.NEAREST) for f in quadros]
    fr[0].save(f'{OUT}/{nome}.gif', save_all=True, append_images=fr[1:], duration=ms, loop=0, disposal=2)

for l in ('frente', 'costas', 'direita', 'parado', 'tonto', 'escalar', 'combate'):
    gif(l, [q(l, i) for i in range(8)])

# louvor como o pet faz: agacha, sobe os braços e fica em V com o sol girando em cima
lv = []
for t in range(40):
    i = 0 if t < 2 else 1 if t < 3 else 2 if t < 4 else 3 + (t - 4) % 5
    c = Image.new('RGBA', (CW, CH + 30), (0, 0, 0, 0)); c.alpha_composite(q('louvor', i), (0, 30))
    if i >= 3: c.alpha_composite(sol.crop(((t % 4) * SW, 0, (t % 4 + 1) * SW, sol.height)), ((CW - SW) // 2, 0))
    lv.append(c)
gif('louvor', lv, 110)

gif('sol', [sol.crop((i * SW, 0, (i + 1) * SW, sol.height)) for i in range(4)], 150, 4)
ss = Image.open('windows/PetSolaire/soapstone.png'); n = ss.width // 56
gif('soapstone', [ss.crop((i * 56, 0, (i + 1) * 56, ss.height)) for i in range(n)], 160, 4)
bf = Image.open('windows/Fogueira/bonfire.png'); n = bf.width // 40
gif('fogueira', [bf.crop((i * 40, 0, (i + 1) * 40, bf.height)) for i in range(n)], 110, 4)
print('ok', sorted(os.listdir(OUT)))
