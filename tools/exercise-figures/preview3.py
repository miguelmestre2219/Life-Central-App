import sys
from PIL import Image, ImageDraw
from poses import M
from figure import render, lerp, fit_for
names = sys.argv[1:]
cell = 150
cols = 5
sheet = Image.new('RGB', (cols * cell, len(names) * (cell + 14)), (255, 255, 255))
g = ImageDraw.Draw(sheet)
for r, n in enumerate(names):
    m = M[n]; fr = m['frames']; fit = fit_for(fr, m['props'])
    picks = fr if len(fr) > 2 else [lerp(fr[0], fr[1], t) for t in (0, 0.25, 0.5, 0.75, 1)]
    for c, f in enumerate(picks[:5]):
        sheet.paste(render(f, m['props'], m['worked'], cell, fit), (c * cell, r * (cell + 14) + 14))
    g.text((4, r * (cell + 14)), n, fill=(0, 0, 0))
sheet.save('sheet3.png')
