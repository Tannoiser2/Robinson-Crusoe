#!/usr/bin/env python3
"""Ritaglia le carte dai fogli del modulo TTS. Per ogni carta (CardID unico) salva:
  OUT/carte/<id>.webp  (per il gioco, larga 420 px)
  OUT/leggi/<mazzo>_<n>.jpg  (strisce di 3 carte a piena risoluzione, per la trascrizione)
e i dorsi in OUT/dorsi/<deckkey>.webp. Uso: python3 -I ritaglia.py cat.json OUT"""
import json, os, sys
from PIL import Image

cat = json.load(open(sys.argv[1]))
OUT = sys.argv[2]
for d in ("carte", "leggi", "dorsi"):
    os.makedirs(os.path.join(OUT, d), exist_ok=True)

decks = {}
cards = {}
for o in cat["objs"]:
    for k, v in o.get("decks", {}).items():
        decks[int(k)] = v
    if o["name"] == "Card":
        cid = o["cardid"]
        top = (o["path"][0] if o["path"] else "").replace("\n", " ")
        cards.setdefault(cid, {"id": cid, "nome": o["nick"], "gruppo": " > ".join(o["path"]).replace("\n", " ")})

sheets = {}


def sheet(path):
    if path not in sheets:
        sheets[path] = Image.open(path).convert("RGB")
    return sheets[path]


elenco = []
for cid in sorted(cards):
    dk, idx = divmod(cid, 100)
    d = decks.get(dk)
    if not d or not d["face"] or d["face"].startswith("MANCA"):
        print("manca foglio", cid)
        continue
    im = sheet(d["face"])
    W, H = im.size
    cw, ch = W / d["w"], H / d["h"]
    c, r = idx % d["w"], idx // d["w"]
    card = im.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch)))
    cards[cid]["w"], cards[cid]["h"] = card.size
    small = card.copy()
    small.thumbnail((420, 700), Image.LANCZOS)
    small.save(os.path.join(OUT, "carte", "%d.webp" % cid), quality=88)
    cards[cid]["img"] = card
    elenco.append(cid)
    if d["back"] and not d["back"].startswith("MANCA") and not os.path.exists(os.path.join(OUT, "dorsi", "%d.webp" % dk)):
        b = Image.open(d["back"]).convert("RGB")
        if d.get("uniqueback"):
            b = b.crop((round(c * b.size[0] / d["w"]), round(r * b.size[1] / d["h"]),
                        round((c + 1) * b.size[0] / d["w"]), round((r + 1) * b.size[1] / d["h"])))
        b.thumbnail((420, 700), Image.LANCZOS)
        b.save(os.path.join(OUT, "dorsi", "%d.webp" % dk), quality=88)

# strisce di lettura per mazzo (3 carte, larghezza massima 1500)
by = {}
for cid in elenco:
    by.setdefault(cid // 100, []).append(cid)
for dk, ids in by.items():
    for n in range(0, len(ids), 3):
        grp = ids[n:n + 3]
        imgs = [cards[i]["img"] for i in grp]
        h = max(i.size[1] for i in imgs)
        sc = min(1.0, 1500 / sum(i.size[0] for i in imgs), 900 / h)
        imgs = [i.resize((int(i.size[0] * sc), int(i.size[1] * sc)), Image.LANCZOS) for i in imgs]
        strip = Image.new("RGB", (sum(i.size[0] for i in imgs) + 10 * (len(imgs) - 1), max(i.size[1] for i in imgs)), "white")
        x = 0
        for i in imgs:
            strip.paste(i, (x, 0)); x += i.size[0] + 10
        strip.save(os.path.join(OUT, "leggi", "%d_%s.jpg" % (dk, "-".join(str(g) for g in grp))), quality=90)
json.dump([{k: v for k, v in cards[c].items() if k != "img"} for c in elenco], open(os.path.join(OUT, "elenco.json"), "w"),
          indent=1, ensure_ascii=False)
print(len(elenco), "carte")
