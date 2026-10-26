"""Make the shop's dealer still (shop redesign PR A2, HANDOFF_SPEC §4).

Takes the Smiles front render and applies the boss_toon lift used in the
mock (make_mockup.py smiles()): a warm shadow ambient #3A3732 at 0.40 that
never darkens a lit pixel, greys raised by 0.08, and no glow. The black
background becomes transparent so the still sits on the shop's band.

    python3 art/ui/shop/src/make_dealer_still.py [smiles_front.png]
"""
import sys
from PIL import Image, ImageChops, ImageFilter

SRC = sys.argv[1] if len(sys.argv) > 1 else "/workspace/dice/art/renders/smiles/smiles_front.png"
OUT = "art/ui/shop/dealer_smiles.png"
AMBIENT, AMBIENT_ENERGY, GREY_STEP = (0x3A, 0x37, 0x32), 0.40, 0.08

sm = Image.open(SRC).convert("RGB")
sm = sm.crop((0, 0, sm.width, int(sm.height * 0.69)))  # Head and chest: the band is wide.
amb = Image.new("RGB", sm.size, AMBIENT)
lifted = ImageChops.lighter(sm, Image.blend(sm, amb, AMBIENT_ENERGY))  # Never below the lit value.
lifted = lifted.point(lambda v: min(255, int(v + GREY_STEP * 255 * (1 - v / 255))))
mask = sm.convert("L").point(lambda v: 255 if v > 10 else 0).filter(ImageFilter.GaussianBlur(1))
lifted.putalpha(mask)
lifted.resize((lifted.width // 2, lifted.height // 2), Image.LANCZOS).save(OUT, optimize=True)
print("wrote", OUT, lifted.width // 2, lifted.height // 2)
