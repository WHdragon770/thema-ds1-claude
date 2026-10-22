import sys
from PIL import Image
f = Image.open(sys.argv[1]); W, H = 48, 64
cel = [tuple(map(int, c.split(','))) for c in sys.argv[3:]]
out = Image.new('RGBA', (W * 5 * len(cel), H * 5), (170, 190, 210, 255))
for i, (l, c) in enumerate(cel):
    q = f.crop((c * W, l * H, (c + 1) * W, (l + 1) * H)).resize((W * 5, H * 5), Image.NEAREST)
    out.alpha_composite(q, (i * W * 5, 0))
out.save(sys.argv[2])
