#!/usr/bin/env python3
"""Estrae dal modulo Tabletop Simulator (cartella Mods scompattata dal .ttsmod) le immagini e i modelli usati
dal gioco: carte, dorsi, tessere isola, tabellone, plance, schede scenario, pedine, segnalini, modelli 3D.

Uso: python3 -I tools/estrai_materiale.py CATALOGO.json CARTELLA_MODS REPO
(il catalogo si crea con tools/catalogo.py)."""
import json, os, re, shutil, sys
from PIL import Image, ImageDraw

cat = json.load(open(sys.argv[1]))
MODS = sys.argv[2]
REPO = sys.argv[3]
A = os.path.join(REPO, "assets")


def cartella(*p):
    d = os.path.join(A, *p)
    os.makedirs(d, exist_ok=True)
    return d


def salva(im, path, q=86, w=None):
    if w and im.size[0] > w:
        im = im.resize((w, int(im.size[1] * w / im.size[0])), Image.LANCZOS)
    if path.endswith(".webp"):
        im.save(path, quality=q, method=6)
    else:
        im.save(path, optimize=True)


objs = cat["objs"]


def per_nome(nome, campo="img", gruppo=None):
    for o in objs:
        if o["nick"] == nome and o.get(campo) and (gruppo is None or (o["path"][:1] == [gruppo])):
            return o[campo]
    return None


# ---------------------------------------------------------------- carte
decks = {}
cards = {}
for o in objs:
    for k, v in o.get("decks", {}).items():
        decks[int(k)] = v
    if o["name"] == "Card":
        cards.setdefault(o["cardid"], o)
fogli = {}
dc = cartella("carte")
dd = cartella("dorsi")
for cid in sorted(cards):
    dk, idx = divmod(cid, 100)
    d = decks.get(dk)
    if not d or dk > 12:
        continue
    if d["face"] not in fogli:
        fogli[d["face"]] = Image.open(d["face"]).convert("RGB")
    im = fogli[d["face"]]
    W, H = im.size
    cw, ch = W / d["w"], H / d["h"]
    c, r = idx % d["w"], idx // d["w"]
    card = im.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch)))
    card.thumbnail((460, 720), Image.LANCZOS)
    salva(card, os.path.join(dc, "%d.webp" % cid), 88)
    dorso = os.path.join(dd, "%d.webp" % dk)
    if not os.path.exists(dorso) and d["back"]:
        b = Image.open(d["back"]).convert("RGB")
        if d.get("uniqueback"):
            b = b.crop((round(c * b.size[0] / d["w"]), round(r * b.size[1] / d["h"]), round((c + 1) * b.size[0] / d["w"]), round((r + 1) * b.size[1] / d["h"])))
        b.thumbnail((460, 720), Image.LANCZOS)
        salva(b, dorso, 86)

# ---------------------------------------------------------------- tessere (esagoni con trasparenza)
dt = cartella("tessere")


def esagono(im):
    w, h = im.size
    m = Image.new("L", (w, h), 0)
    import math
    cx, cy, R = w / 2, h / 2, min(w / 2 / math.cos(math.radians(30)), h / 2) * 0.995
    pts = [(cx + R * math.cos(math.radians(a)), cy + R * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
    ImageDraw.Draw(m).polygon(pts, fill=255)
    im = im.convert("RGBA")
    im.putalpha(m)
    return im


tessere = {}
for o in objs:
    n = o["nick"]
    if (o["path"][:1] == ["Island Tiles"] and n.startswith("Island Tile")) or n == "Volcano Tile":
        tessere.setdefault(n, o["diffuse"])
for n, f in tessere.items():
    im = Image.open(f).convert("RGB")
    w, h = im.size
    fronte = im.crop((0, 0, w // 2, h))
    # il lato del file è quadrato con l'esagono dentro: taglio ai bordi orizzontali dell'esagono
    fw, fh = fronte.size
    import math
    lar = int(fh * math.cos(math.radians(30)))
    fronte = fronte.crop(((fw - lar) // 2, 0, (fw + lar) // 2, fh))
    nome = n.split()[-1] if n != "Volcano Tile" else "vulcano"
    salva(esagono(fronte.resize((443, 512), Image.LANCZOS)), os.path.join(dt, "%s.webp" % nome), 90)
    if nome == "8":
        retro = im.crop((w // 2, 0, w, h))
        retro = retro.crop(((fw - lar) // 2, 0, (fw + lar) // 2, fh))
        salva(esagono(retro.resize((443, 512), Image.LANCZOS)), os.path.join(dt, "retro.webp"), 90)

# ---------------------------------------------------------------- tabellone, schede, plance
dtav = cartella("tavolo")
salva(Image.open(cat["table"]).convert("RGB"), os.path.join(dtav, "tabellone.webp"), 88, 3200)
dsc = cartella("scenari")
for n, nome in [(1, "Castaways"), (2, "Cursed Island"), (3, "Jenny Needs Help"), (4, "Volcano Island"), (5, "Cannibal Island"), (6, "Family Robinson")]:
    f = per_nome(nome)
    salva(Image.open(f).convert("RGB"), os.path.join(dsc, "%d.webp" % n), 88, 1100)
dpl = cartella("plance")
PG = {"Carpenter": "carpentiere", "Cook": "cuoco", "Explorer": "esploratore", "Soldier": "soldato"}
for en, it in PG.items():
    for o in objs:
        if o["nick"] == en and o.get("img") and Image.open(o["img"]).size[0] > 1000:
            salva(Image.open(o["img"]).convert("RGB"), os.path.join(dpl, "%s.webp" % it), 88, 1600)
            break
for o in objs:
    if o["nick"] == "Extension" and o.get("img"):
        salva(Image.open(o["img"]).convert("RGB"), os.path.join(dpl, "aiuto.webp"), 86, 1500)
        break

# ---------------------------------------------------------------- pedine (gettoni rotondi)
dpe = cartella("pedine")


def cerchio(im, d=256):
    im = im.convert("RGBA").resize((d, d), Image.LANCZOS)
    m = Image.new("L", (d * 4, d * 4), 0)
    ImageDraw.Draw(m).ellipse((4, 4, d * 4 - 4, d * 4 - 4), fill=255)
    im.putalpha(m.resize((d, d), Image.LANCZOS))
    return im


for en, it in list(PG.items()) + [("Friday", "venerdi"), ("Dog", "cane"), ("Jenny", "jenny"), ("Neutral Builder", "neutra_costruire"),
                                    ("Neutral Gatherer", "neutra_raccogliere"), ("Neutral Explorer", "neutra_esplorare"), ("Neutral Hunter", "neutra_caccia")]:
    for o in objs:
        if o["nick"] == en and o["name"] == "Custom_Tile" and o.get("img") and Image.open(o["img"]).size[0] <= 260:
            salva(cerchio(Image.open(o["img"])), os.path.join(dpe, "%s.png" % it))
            break

# ---------------------------------------------------------------- segnalini (gettoni tondi: fronte nel quarto in basso a sinistra)
dse = cartella("segnalini")


def fronte_gettone(f):
    im = Image.open(f).convert("RGB")
    w, h = im.size
    return cerchio(im.crop((0, h // 2, w // 2, h)), 160)


SCOP = {"Treasure": "tesoro", "Nourishing Larvae": "larve", "Goat": "capra", "Fallen Tree": "albero_caduto", "Candles": "candele",
        "Vegetables": "verdure", "Tobacco": "tabacco", "Thorny Bushes": "rovi", "Poison": "veleno", "Large Leaves": "foglie",
        "Healing Herbs": "erbe_curative"}
for o in objs:
    if o["path"][:1] == ["Discoveries"] and o.get("diffuse"):
        k = SCOP.get(o["nick"])
        if o["nick"] == "Old Machete":
            k = "machete"
        if o["nick"] == "Herbs":
            k = "erbe"
        if k:
            salva(fronte_gettone(o["diffuse"]), os.path.join(dse, "%s.png" % k))
SPEC = {"Medallion with a Lady": "medaglione", "Pirate Sabre": "sciabola", "Oil": "olio", "Sacrificial Dagger": "pugnale",
        "Decorated Bell": "campana_decorata", "Mysterious Vials": "fiale", "Cultist's Candles": "candele_culto", "Vines": "liane",
        "Ruined Hut": "capanna", "Pistol": "pistola_j", "Old Canvas": "tela", "Torch": "torcia", "Indy's Diary": "diario_indy",
        "Old Map": "vecchia_mappa", "Map of the Island": "mappa_isola", "Healing Ointment": "unguento", "Blowpipe": "cerbottana",
        "Seeds": "semi", "Gunpowder": "polvere_sparo", "Plow": "aratro", "Old Tools": "attrezzi_vecchi"}
for o in objs:
    if len(o["path"]) == 2 and "discoveries" in o["path"][1] and o.get("diffuse"):
        k = SPEC.get(o["nick"])
        if o["nick"] == "Herbs":
            k = "erbe_c"
        if o["nick"] == "Old Machete":
            k = "machete_c"
        if k:
            salva(fronte_gettone(o["diffuse"]), os.path.join(dse, "%s.png" % k))
    if o["path"][:1] == ["Discoveries"] and o.get("diffuse") and o["nick"] == "Treasure":
        im = Image.open(o["diffuse"]).convert("RGB")
        w, h = im.size
        salva(cerchio(im.crop((w // 2, 0, w, h // 2)), 160), os.path.join(dse, "scoperta_retro.png"))
GETTONI = {"First Player": "primo", "Build Adventure": "avv_costruire", "Gather Adventure": "avv_raccogliere", "Explore Adventure": "avv_esplorare",
           "Basket": "cesto", "Sack": "sacco", "Shortcut": "scorciatoia", "Rain Cloud": "pioggia", "Winter Cloud": "neve", "Storm": "tempesta",
           "Additional Food": "cibo_extra", "Additional Wood": "legno_extra", "Time-consuming Action": "lento", "Greater Danger": "pericolo",
           "Reroll": "rilancio", "Determination": "det", "Build Special Wound": "ferita_costruire", "Gather Special Wound": "ferita_raccogliere",
           "Explore Special Wound": "ferita_esplorare", "Camp": "campo"}
for o in objs:
    k = GETTONI.get(o["nick"])
    if k and o.get("diffuse") and not os.path.exists(os.path.join(dse, "%s.png" % k)):
        salva(fronte_gettone(o["diffuse"]), os.path.join(dse, "%s.png" % k))
for o in objs:
    if o["path"][:1] == ["Totems"] and o.get("diffuse"):
        n = re.match(r"(\d)", o["nick"]).group(1)
        salva(fronte_gettone(o["diffuse"]), os.path.join(dse, "numero%s.png" % n))
# campo / rifugio: il gettone del campo è il primo modello senza nome con texture del campo
for o in objs:
    if o["nick"] == "" and o.get("diffuse") and "8DFDFF6658" in o["diffuse"]:
        im = Image.open(o["diffuse"]).convert("RGB")
        w, h = im.size
        salva(cerchio(im.crop((0, h // 2, w // 2, h)), 200), os.path.join(dse, "campo.png"))
        salva(cerchio(im.crop((w // 2, 0, w, h // 2)), 200), os.path.join(dse, "rifugio.png"))
        break

# ---------------------------------------------------------------- dadi (texture TTS) e risorse
ddi = cartella("dadi")
for o in objs:
    if o["name"] == "Custom_Dice" and o.get("img") and not o["path"]:
        x = round(o["pos"][0], 1)
        nomi = {-8.2: "costruire_ferita", -6.2: "costruire_avventura", -4.2: "costruire_successo", 0.6: "raccogliere_ferita",
                2.6: "raccogliere_avventura", 4.6: "raccogliere_successo", 9.4: "esplorare_ferita", 11.4: "esplorare_avventura",
                13.4: "esplorare_successo", 37.3: "meteo_pioggia", 39.3: "meteo_neve", 41.3: "meteo_belve"}
        if x in nomi:
            salva(Image.open(o["img"]).convert("RGB"), os.path.join(ddi, "%s.webp" % nomi[x]), 88, 1024)
dmo = cartella("modelli")
for nome, k in [("Wood", "legno"), ("Food", "cibo"), ("Non-perishable Food", "cibo_np"), ("Fur", "pelliccia"), ("Wound", "ferita"), ("White Marker", "segnalino"), ("Morale", "indicatore")]:
    for o in objs:
        if o["nick"] == nome and o.get("mesh"):
            shutil.copy(o["mesh"], os.path.join(dmo, "%s.obj" % k))
            if o.get("diffuse"):
                salva(Image.open(o["diffuse"]).convert("RGB"), os.path.join(dmo, "%s.webp" % k), 86, 512)
            break
print("materiale estratto")
