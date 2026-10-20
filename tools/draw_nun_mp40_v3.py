#!/usr/bin/env python3
"""IGLESIA: ORIGINAL 2.5D hand-painted MP40 / demonic nun sprite renderer.

New original drawing, not colorizing the old military hand sprites.
Transparent independent poses, scene-consistent sight anchors and named
mechanical reload phases. All imagery is algorithmically inked here so the
original source remains editable/reproducible directly in GitHub.
"""
from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw

W, H, SS = 960, 720, 2
INK = (12, 12, 19, 255)
BLACK = (23, 23, 32, 255)
CLOTH = (36, 34, 45, 255)
CLOTH_LIGHT = (68, 62, 75, 255)
CUFF = (176, 164, 151, 255)
SKIN = (217, 185, 178, 255)
SKIN_SHADE = (139, 94, 100, 255)
SKIN_LIGHT = (251, 211, 195, 255)
NAIL = (57, 25, 35, 255)
METAL = (54, 61, 67, 255)
METAL_HI = (129, 143, 151, 255)
STEEL_BLACK = (29, 34, 39, 255)
STEEL_EDGE = (193, 181, 161, 255)

FRAMES = (
    "idle_hip_01", "fire_hip_01", "ads_idle", "ads_fire_01",
    "sprint_01", "reload_01", "reload_02", "reload_03", "reload_04",
    "reload_empty_01", "reload_empty_02", "reload_empty_03", "reload_empty_04",
)
OPTICS = {"hip": (480, 207), "ads": (480, 213)}
PALETTE = {
    "habito_oscuro": list(CLOTH[:3]), "piel_monja": list(SKIN[:3]),
    "unas_oscuras": list(NAIL[:3]), "metal_mp40": list(METAL[:3]),
}


class Painter:
    def __init__(self):
        self.im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im, "RGBA")

    @staticmethod
    def xy(pts):
        return [(round(x * SS), round(y * SS)) for x, y in pts]

    def poly(self, pts, fill, stroke=INK, width=3):
        v = self.xy(pts)
        self.d.polygon(v, fill=fill)
        if stroke:
            self.d.line(v + v[:1], fill=stroke, width=width * SS, joint="curve")

    def line(self, pts, fill, width=3, joint="curve"):
        self.d.line(self.xy(pts), fill=fill, width=max(1, round(width * SS)), joint=joint)

    def ellipse(self, box, fill, stroke=INK, width=2):
        self.d.ellipse(tuple(round(v * SS) for v in box), fill=fill, outline=stroke, width=width * SS)

    def rect(self, box, fill, stroke=INK, width=2, rad=0):
        r = tuple(round(v * SS) for v in box)
        if rad:
            self.d.rounded_rectangle(r, radius=rad * SS, fill=fill, outline=stroke, width=width * SS)
        else:
            self.d.rectangle(r, fill=fill, outline=stroke, width=width * SS)

    def outline_folds(self, pts, light=False):
        for a, b in pts:
            self.line([a, b], CLOTH_LIGHT if light else INK, 3 if light else 5)

    def final(self, output: Path):
        out = self.im.resize((W, H), Image.Resampling.LANCZOS)
        assert out.getpixel((0, 0))[3] == 0, "transparent sprite contaminated"
        assert out.getbbox(), "sprite is blank"
        output.parent.mkdir(parents=True, exist_ok=True)
        out.save(output, optimize=True)
        return out


def habit_arms(p: Painter, ads: bool = False, sprint: bool = False):
    """Two separate long black cloth sleeves of the playable demonic nun."""
    if ads:
        left = [(126, 745), (240, 710), (330, 605), (360, 537), (425, 540),
                (463, 640), (412, 729)]
        right = [(823, 741), (728, 672), (637, 545), (580, 546),
                 (554, 627), (591, 742)]
        left_cuff = [(351, 527), (424, 526), (442, 565), (371, 576)]
        right_cuff = [(562, 555), (624, 535), (642, 567), (581, 590)]
    else:
        left = [(130, 741), (243, 704), (317, 579), (380, 517), (433, 536),
                (468, 585), (393, 744)]
        right = [(850, 745), (801, 655), (754, 548), (708, 517),
                 (655, 563), (652, 638), (684, 739)]
        left_cuff = [(372, 513), (439, 524), (462, 554), (408, 576)]
        right_cuff = [(704, 518), (764, 547), (770, 583), (689, 574)]
    p.poly(left, CLOTH)
    p.poly(right, CLOTH)
    if ads:
        p.outline_folds([((205, 732), (353, 566)), ((288, 719), (399, 558)),
                         ((741, 722), (606, 569)), ((683, 721), (578, 577))], True)
    else:
        p.outline_folds([((222, 724), (364, 558)), ((306, 736), (414, 565)),
                         ((813, 710), (734, 572)), ((703, 726), (690, 590))], True)
    p.poly(left_cuff, CUFF)
    p.poly(right_cuff, CUFF)
    p.line(left_cuff[0:2], (245, 223, 205, 255), 4)
    p.line(right_cuff[0:2], (245, 223, 205, 255), 4)
    # Shaded seams/cuff details: not military gloves.
    p.line([left_cuff[3], left_cuff[2]], INK, 3)
    p.line([right_cuff[3], right_cuff[2]], INK, 3)


def pale_hands_hip(p: Painter, stage: int = 0):
    """Exposed pale hands, elongated fingers and dark nails (no green gloves)."""
    pull = stage * 13
    # Left hand supports the fore-end, right hand wraps the pistol grip.
    p.poly([(400, 529 - pull), (423, 474 - pull), (452, 438 - pull),
            (486, 458 - pull), (496, 513 - pull), (449, 554 - pull)], SKIN_SHADE)
    p.poly([(410, 522 - pull), (436, 474 - pull), (455, 459 - pull),
            (470, 473 - pull), (452, 515 - pull), (444, 542 - pull)], SKIN)
    for i, step in enumerate([0, 12, 24]):
        p.poly([(448 + step, 480 - pull + i * 3), (462 + step, 451 - pull + i * 3),
                (478 + step, 450 - pull + i * 3), (477 + step, 471 - pull + i * 3),
                (462 + step, 497 - pull + i * 3)], SKIN if i != 2 else SKIN_LIGHT, width=2)
        p.ellipse((470 + step, 446 - pull + i * 3,
                   479 + step, 454 - pull + i * 3), NAIL, stroke=None)
    p.poly([(696, 553), (748, 544), (766, 574), (744, 635),
            (717, 641), (674, 599)], SKIN_SHADE)
    p.poly([(704, 557), (750, 554), (759, 575), (735, 624),
            (715, 614), (695, 585)], SKIN)
    for i in range(3):
        x = 705 + i * 13
        p.poly([(x, 561), (x + 15, 558), (x + 18, 590),
                (x + 3, 601), (x - 2, 581)], SKIN_LIGHT, width=2)
        p.line([(x + 2, 561), (x + 10, 561)], NAIL, 3)


def pale_hands_ads(p: Painter):
    p.poly([(362, 545), (389, 497), (422, 463), (457, 468),
            (473, 506), (443, 566), (400, 594)], SKIN_SHADE)
    p.poly([(382, 540), (411, 487), (428, 476), (455, 486),
            (436, 543), (413, 562)], SKIN)
    p.poly([(593, 484), (631, 467), (651, 482), (685, 548),
            (637, 593), (602, 568)], SKIN_SHADE)
    p.poly([(597, 498), (622, 484), (647, 507), (666, 547),
            (636, 571), (606, 540)], SKIN)
    for i in range(3):
        p.line([(416 + i * 11, 496), (430 + i * 8, 521)], SKIN_LIGHT, 8)
        p.line([(604 + i * 10, 500), (608 + i * 10, 522)], SKIN_LIGHT, 7)
        p.line([(431 + i * 8, 520), (436 + i * 8, 525)], NAIL, 3)
        p.line([(609 + i * 10, 521), (615 + i * 10, 525)], NAIL, 3)


def metal_scratch(p: Painter, x: int, y: int, rng: random.Random):
    dx = rng.randint(5, 16)
    dy = rng.choice([1, 2, 3])
    p.line([(x, y), (x + dx, y + dy)], (160, 157, 139, 160), 1)


def mp40_hip_body(p: Painter, reload_phase: int = 0):
    """Original illustrated 3/4 perspective: barrel converges on crosshair."""
    # Rear folding stock and frame behind receiver.
    p.poly([(705, 568), (781, 603), (882, 690), (873, 703),
            (768, 635), (707, 605)], METAL, width=4)
    p.line([(731, 593), (840, 680)], METAL_HI, 5)
    p.ellipse((847, 670, 888, 714), STEEL_BLACK, width=4)
    # Pistol grip with serration.
    p.poly([(679, 574), (731, 566), (762, 721), (710, 739)], STEEL_BLACK, width=5)
    for i in range(7):
        y = 604 + i * 15
        p.line([(711 + i * 2, y), (741 + i * 2, y - 9)], (79, 82, 81, 255), 3)
    # Long 2.5D black barrel with perspective highlights and handguard.
    p.poly([(467, 228), (490, 225), (613, 421), (592, 456),
            (572, 440), (450, 243)], STEEL_BLACK, width=5)
    p.poly([(464, 232), (482, 229), (601, 420), (590, 431)],
           (85, 95, 99, 255), stroke=None)
    p.line([(476, 229), (603, 430)], METAL_HI, 3)
    p.line([(456, 240), (581, 435)], INK, 4)
    # Stamped shroud ribbing along tapered barrel.
    for i in range(6):
        t = i / 6.0
        x = 492 + 105 * t
        y = 260 + 159 * t
        p.line([(x - 8 - t * 3, y + 7), (x + 13 + t * 4, y - 6)],
               INK, 4)
        p.line([(x - 7, y + 4), (x + 10, y - 7)], METAL_HI, 2)
    # Full receiver side walls, plate, steel corner highlights.
    p.poly([(573, 432), (626, 420), (754, 574), (702, 623),
            (610, 571), (585, 501)], METAL, width=6)
    p.poly([(587, 441), (625, 435), (727, 553), (690, 589),
            (606, 545)], (72, 82, 88, 255), width=3)
    p.line([(605, 442), (715, 567)], STEEL_EDGE, 5)
    p.line([(598, 539), (697, 608)], STEEL_BLACK, 8)
    p.poly([(630, 475), (651, 483), (727, 565), (708, 587),
            (651, 535)], STEEL_BLACK)
    p.line([(650, 484), (711, 568)], (151, 153, 149, 255), 3)
    # Ejection port and charging-handle assembly.
    p.rect((660, 505, 701, 523), STEEL_BLACK, stroke=METAL_HI, width=3, rad=3)
    p.ellipse((688, 499, 711, 522), (133, 144, 146, 255), width=3)
    p.ellipse((682, 558, 698, 574), METAL_HI)
    p.ellipse((622, 510, 637, 526), METAL_HI)
    p.line([(620, 525), (693, 604)], INK, 2)
    # Distinct detachable long magazine (in the receiver, not ghost geometry).
    if reload_phase in [1, 2]:
        mx = 624 - reload_phase * 39
        my = 554 + reload_phase * 74
    else:
        mx, my = 624, 554
    p.poly([(mx, my), (mx + 48, my + 7), (mx + 65, my + 175),
            (mx + 26, my + 187)], STEEL_BLACK, width=5)
    p.poly([(mx + 8, my + 15), (mx + 35, my + 18),
            (mx + 53, my + 153), (mx + 34, my + 166)],
           (82, 88, 91, 255), stroke=None)
    p.line([(mx + 12, my + 12), (mx + 35, my + 162)], METAL_HI, 3)
    p.line([(mx + 45, my + 25), (mx + 60, my + 170)], INK, 5)
    # Trigger guard and curved finger housing.
    p.line([(692, 606), (728, 643), (700, 661), (674, 624)], INK, 7)
    p.ellipse((683, 594, 701, 609), METAL_HI)
    # Flash suppressor, front post physically at HIP optical anchor (480,207).
    p.poly([(448, 227), (494, 221), (500, 238), (457, 246)],
           (81, 89, 90, 255), width=4)
    p.ellipse((466, 208, 494, 229), (0, 0, 0, 0), stroke=STEEL_EDGE, width=5)
    p.line([(480, 213), (480, 239)], INK, 6)
    p.line([(481, 216), (481, 237)], METAL_HI, 2)
    rng = random.Random(402)
    for i in range(34):
        x, y = rng.randint(603, 705), rng.randint(455, 581)
        if 605 < x < 695:
            metal_scratch(p, x, y, rng)


def mp40_ads_body(p: Painter, flash=False):
    # Converging first-person gun body; front/rear irons share x=480.
    p.poly([(469, 238), (491, 238), (555, 536), (405, 536)],
           STEEL_BLACK, width=6)
    p.poly([(475, 236), (484, 236), (530, 517), (458, 518)],
           (75, 84, 91, 255), stroke=None)
    for i in range(8):
        t = i / 8.0
        y = 263 + t * 216
        half = 18 + t * 57
        p.line([(480 - half, y), (480 + half, y)],
               INK, 5 if i % 2 else 7)
        p.line([(480 - half + 4, y - 5), (480 + half - 4, y - 5)],
               (115, 123, 127, 255), 2)
    p.poly([(403, 491), (555, 491), (663, 740), (305, 740)],
           METAL, width=8)
    p.poly([(415, 517), (545, 517), (603, 718), (357, 718)],
           STEEL_BLACK, width=4)
    p.line([(420, 521), (375, 697)], METAL_HI, 4)
    p.line([(540, 521), (582, 697)], METAL_HI, 4)
    p.line([(434, 558), (526, 558)], STEEL_EDGE, 3)
    for x in [355, 603]:
        p.ellipse((x - 10, 622, x + 10, 642), METAL_HI)
    # Boxy rear bridge and rear sight: notch centered directly under front ring.
    p.poly([(417, 420), (455, 420), (455, 453), (468, 454),
            (470, 425), (490, 425), (493, 455), (506, 454),
            (506, 420), (545, 420), (551, 483), (412, 483)],
           (40, 42, 46, 255), width=5)
    p.line([(420, 425), (451, 425)], METAL_HI, 4)
    p.line([(508, 425), (541, 425)], METAL_HI, 4)
    p.line([(478, 430), (478, 456)], (210, 193, 168, 255), 2)
    # Front sight visible clearly, true iron alignment, no barrel blocking.
    p.ellipse((462, 194, 498, 232), (0, 0, 0, 0), stroke=STEEL_EDGE, width=6)
    p.ellipse((471, 203, 489, 223), (0, 0, 0, 0), stroke=INK, width=3)
    p.line([(480, 213), (480, 243)], STEEL_BLACK, 7)
    p.line([(480, 212), (480, 235)], METAL_HI, 2)
    if flash:
        muzzle_flash(p, 480, 198)


def pale_fingers_on_top(p: Painter, ads=False, reload_phase=0):
    if ads:
        for i in range(3):
            x = 405 + i * 12
            p.poly([(x, 541), (x + 16, 530), (x + 26, 546),
                    (x + 17, 579), (x, 569)], SKIN)
            p.line([(x + 13, 539), (x + 22, 544)], SKIN_LIGHT, 3)
            x2 = 530 + i * 10
            p.poly([(x2, 529), (x2 + 22, 536),
                    (x2 + 26, 568), (x2 + 4, 566)], SKIN)
            p.line([(x2 + 17, 541), (x2 + 20, 557)], SKIN_LIGHT, 3)
        return
    for i in range(3):
        x = 448 + i * 13
        y = 480 + i * 2 - reload_phase * 8
        p.poly([(x - 4, y), (x + 10, y - 25), (x + 23, y - 17),
                (x + 15, y + 5)], SKIN)
        p.line([(x + 6, y - 15), (x + 12, y - 19)], NAIL, 2)
    for i in range(3):
        x, y = 692 + i * 13, 577 + i * 10
        p.poly([(x, y), (x + 11, y - 6), (x + 21, y + 22),
                (x + 9, y + 33)], SKIN)
        p.line([(x + 5, y), (x + 10, y - 2)], NAIL, 2)


def muzzle_flash(p: Painter, x: int, y: int):
    # Original painted orange/ivory frame; no stock glowing square.
    outer = [(x - 13, y + 4), (x - 34, y - 57), (x - 6, y - 40),
             (x - 7, y - 111), (x + 9, y - 56), (x + 41, y - 92),
             (x + 24, y - 31), (x + 47, y - 19), (x + 13, y + 8)]
    inner = [(x - 9, y + 2), (x - 16, y - 43), (x - 2, y - 37),
             (x + 6, y - 76), (x + 12, y - 31), (x + 25, y - 41),
             (x + 13, y - 5)]
    p.poly(outer, (241, 98, 52, 240), stroke=None)
    p.poly(inner, (255, 216, 137, 255), stroke=None)
    p.ellipse((x - 10, y - 28, x + 11, y + 6), (255, 243, 201, 245), stroke=None)


def render(name: str, output: Path):
    if name not in FRAMES:
        raise ValueError(f"unknown frame: {name}")
    p = Painter()
    ads = name.startswith("ads_")
    fire = name in ("fire_hip_01", "ads_fire_01")
    reload_phase = int(name[-2:]) if name.startswith("reload_") and name[-2:].isdigit() else 0
    if reload_phase and "empty" in name:
        reload_phase = int(name[-2:])
    sprint = name.startswith("sprint")
    habit_arms(p, ads=ads, sprint=sprint)
    if ads:
        pale_hands_ads(p)
        mp40_ads_body(p, flash=fire)
        pale_fingers_on_top(p, ads=True)
    else:
        pale_hands_hip(p, stage=reload_phase if reload_phase else 0)
        mp40_hip_body(p, reload_phase)
        pale_fingers_on_top(p, reload_phase=reload_phase)
        if fire:
            muzzle_flash(p, 480, 203)
        if sprint:
            # Motion-streak hatched lines remain within dark sleeve boundaries.
            for i in range(5):
                p.line([(260 + i * 12, 710), (350 + i * 12, 596)],
                       (143, 129, 131, 180), 2)
    result = p.final(output)
    # Validate pose stays transparent and actually contains the front sight.
    assert result.getbbox() is not None
    assert result.getpixel((480, 214))[3] > 50, (name, "missing optical silhouette")
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for frame in FRAMES:
        im = render(frame, args.out / f"{frame}.png")
        print("NUN_MP40_V3_FRAME", frame, im.size, im.getbbox())
    manifest = {
        "style": "Iglesia original illustrated gothic 2.5D v3",
        "character": "hostile nun protagonist: charcoal habit, pale exposed hands, black nails",
        "authorship": "procedural original drawing; no legacy military hands",
        "format": "RGBA",
        "resolution": [W, H],
        "hip_optical_anchor_px": list(OPTICS["hip"]),
        "ads_optical_anchor_px": list(OPTICS["ads"]),
        "frames": list(FRAMES),
        "palette": PALETTE,
        "visual_review": "pending actual Android screenshots",
    }
    (args.out / "nun_mp40_v3_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print("NUN_MP40_V3_GREEN frames=", len(FRAMES))


if __name__ == "__main__":
    main()
