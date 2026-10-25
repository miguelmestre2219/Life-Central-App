import sys
from PIL import Image, ImageDraw
from poses import M, render, lerp
from figure import fit_for
names = sys.argv[1:] or list(M)
cell = 200
cols = 4
rows = (len(names) * 2 + cols - 1) // cols
sheet = Image.new('RGB', (cols * cell, rows * (cell + 16)), (255, 255, 255))
g = ImageDraw.Draw(sheet)
i = 0
for n in names:
    m = M[n]
    frames = m['frames']
    picks = [frames[0], frames[len(frames) // 2]] if len(frames) > 2 else frames
    for j, f in enumerate(picks):
        img = render(f, m['props'], m['worked'], cell, fit_for(frames, m['props']))
        x, y = (i % cols) * cell, (i // cols) * (cell + 16)
        sheet.paste(img, (x, y + 16))
        g.text((x + 4, y + 2), f"{n} {j}", fill=(0, 0, 0))
        i += 1
sheet.save('sheet.png')
print(sheet.size, len(names))
