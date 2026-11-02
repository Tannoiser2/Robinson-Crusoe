#!/usr/bin/env python3
"""Cataloga gli oggetti del modulo TTS di Robinson Crusoe: carte (foglio, griglia, indice),
tessere, modelli, sacchetti. Uso: python3 -I catalogo.py MODS_DIR OUT.json"""
import json, os, re, sys, glob

MODS = sys.argv[1]
OUT = sys.argv[2]
files = {}
for p in glob.glob(os.path.join(MODS, "Images", "*")) + glob.glob(os.path.join(MODS, "Models", "*")):
    files[os.path.splitext(os.path.basename(p))[0]] = p


def local(url):
    if not url:
        return None
    k = re.sub(r"[^A-Za-z0-9]", "", url)
    if k in files:
        return files[k]
    # TTS toglie a volte l'estensione dal nome, o lo stesso file viene da un altro dominio Steam
    for kk, p in files.items():
        if kk.startswith(k) or k.startswith(kk):
            return p
    m = re.search(r"ugc/(\d+)/([0-9A-F]+)", url)
    if m:
        for kk, p in files.items():
            if m.group(1) + m.group(2) in kk:
                return p
    return "MANCA:" + url


d = json.load(open(glob.glob(os.path.join(MODS, "Workshop", "*.json"))[0]))
objs = []


def walk(lst, path):
    for o in lst:
        e = {"name": o.get("Name"), "nick": o.get("Nickname", ""), "guid": o.get("GUID"),
             "desc": o.get("Description", ""), "gm": o.get("GMNotes", ""), "path": path,
             "pos": [round(o["Transform"][k], 3) for k in ("posX", "posY", "posZ")],
             "rot": [round(o["Transform"][k], 2) for k in ("rotX", "rotY", "rotZ")],
             "scale": [round(o["Transform"][k], 3) for k in ("scaleX", "scaleY", "scaleZ")]}
        if "CustomDeck" in o:
            e["decks"] = {k: {"face": local(v["FaceURL"]), "back": local(v["BackURL"]), "w": v["NumWidth"],
                              "h": v["NumHeight"], "uniqueback": v.get("UniqueBack", False)}
                          for k, v in o["CustomDeck"].items()}
        if "CardID" in o:
            e["cardid"] = o["CardID"]
        if "CustomImage" in o:
            ci = o["CustomImage"]
            e["img"] = local(ci.get("ImageURL"))
            e["imgback"] = local(ci.get("ImageSecondaryURL"))
            if "CustomTile" in ci:
                e["tile"] = ci["CustomTile"]
            if "CustomDice" in ci:
                e["dice"] = ci["CustomDice"]
        if "CustomMesh" in o:
            m = o["CustomMesh"]
            e["mesh"] = local(m.get("MeshURL"))
            e["diffuse"] = local(m.get("DiffuseURL"))
            e["normal"] = local(m.get("NormalURL"))
            e["material"] = m.get("MaterialIndex")
            e["meshtype"] = m.get("TypeIndex")
        if "ColorDiffuse" in o:
            c = o["ColorDiffuse"]
            e["color"] = [round(c.get("r", 1), 3), round(c.get("g", 1), 3), round(c.get("b", 1), 3)]
        if o.get("States"):
            e["states"] = len(o["States"])
            walk(list(o["States"].values()), path + [e["nick"] + "#state"])
        objs.append(e)
        if o.get("ContainedObjects"):
            walk(o["ContainedObjects"], path + [e["nick"] or e["name"]])


walk(d["ObjectStates"], [])
json.dump({"table": local(d.get("TableURL")), "objs": objs}, open(OUT, "w"), indent=1, ensure_ascii=False)
print(len(objs), "oggetti")
missing = [o for o in objs for k in ("img", "mesh", "diffuse") if str(o.get(k, "")).startswith("MANCA")]
print("mancanti", len(missing))
