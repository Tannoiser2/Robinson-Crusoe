#!/usr/bin/env python3
"""Compila i dati del gioco in data/*.json partendo dalle trascrizioni delle carte (tools/trascrizioni/*.json)
e dagli effetti programmati (tools/effetti.py).

Uso: python3 tools/compila_dati.py
"""
import json, os, re, sys

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.dirname(QUI)
sys.path.insert(0, QUI)
import effetti as EF  # noqa: E402

TR = os.path.join(QUI, "trascrizioni")


def leggi(nome):
    return json.load(open(os.path.join(TR, nome), encoding="utf-8"))


PAROLE = {
    "legno": "legno", "cibo": "cibo", "cibo_np": "cibo non deperibile", "pelliccia": "pelliccia",
    "legno_extra": "gettone legno extra", "cibo_extra": "gettone cibo extra", "det": "Determinazione",
    "morale+": "+1 morale", "morale-": "-1 morale", "ferita": "ferita", "cuore": "vita",
    "ferita_testa": "ferita alla testa", "ferita_braccio": "ferita al braccio", "ferita_pancia": "ferita alla pancia",
    "ferita_gamba": "ferita alla gamba", "ferita_costruire": "ferita speciale", "ferita_raccogliere": "ferita speciale",
    "ferita_esplorare": "ferita speciale", "pioggia": "nuvola di pioggia", "neve": "nuvola di neve", "tempesta": "tempesta",
    "dado_belve": "dado delle belve", "dado_pioggia": "dado della pioggia", "dado_neve": "dado dell'inverno",
    "rifugio": "Rifugio", "tetto": "Tetto", "palizzata": "Palizzata", "arma": "Arma", "campo": "campo",
    "costruire": "Costruire", "raccogliere": "Raccogliere", "esplorare": "Esplorare", "caccia": "Caccia",
    "sistemare": "Sistemare il campo", "riposo": "Riposo", "avv_costruire": "segnalino Avventura (Costruire)",
    "avv_raccogliere": "segnalino Avventura (Raccogliere)", "avv_esplorare": "segnalino Avventura (Esplorare)",
    "rilancio": "gettone rilancio", "scorciatoia": "Scorciatoia", "lento": "gettone azione lenta",
    "pericolo": "gettone pericolo", "segno_bianco": "segnalino bianco", "segno_nero": "segnalino nero",
    "successo_negato": "gettone «rilancia il successo»", "scoperta": "segnalino Scoperta", "totem": "totem",
    "succ": "successo", "fer": "ferita", "avv": "?", "pedina": "pedina", "pedina_neutra": "pedina neutrale",
    "carta_mistero": "carta Mistero", "carta_belva": "carta Belva", "carta_evento": "carta Evento",
    "carta_avventura": "carta Avventura", "libro": "libro", "fiume": "fiume", "spiaggia": "spiaggia",
    "collina": "colline", "montagna": "montagne", "pianura": "pianura", "foresta": "foresta",
    "carpentiere": "Carpentiere", "cuoco": "Cuoco", "esploratore": "Esploratrice", "soldato": "Soldatessa",
    "venerdi": "Venerdì", "cane": "Cane",
}


def testo(s):
    if not s:
        return ""

    def sost(mm):
        k = mm.group(1)
        if k.startswith("inv:"):
            return k[4:]
        if k.startswith("?:"):
            d = k[2:]
            if "fonte di cibo" in d:
                return "fonte di cibo"
            if "fonte di legno" in d:
                return "fonte di legno"
            if "scrigno" in d or "tesoro" in d:
                return "tesori"
            if "trappola" in d:
                return "trappole"
            if "creatura" in d:
                return "creature"
            if "teschio forza" in d:
                return " di forza"
            if "pedina" in d:
                return "pedina aggiuntiva"
            return d
        return PAROLE.get(k, k)
    r = re.sub(r"\{([^}]*)\}", sost, s)
    r = r.replace("▼", "→").replace("▶", "→").replace("—", "-").replace("–", "-").replace("’", "'")
    r = r.replace("→", "->")
    r = re.sub(r"\s+", " ", r).strip()
    return r


def nome_it(c):
    return (c.get("titolo_it") or c.get("titolo_en") or "").strip()


NOMI_PERSONALIZZATI = {
    # nomi italiani delle invenzioni (chiavi del motore)
}

carte = []

# --- eventi
ev_simboli = {}
for f in ["eventi_3.json", "eventi_4.json"]:
    for c in leggi(f):
        cid = c["id"]
        e = EF.EVENTI[cid]
        p2 = c.get("parte2", {})
        sim = c.get("segnalino_avventura", "")
        carte.append({
            "id": cid, "tipo": "evento", "nome": nome_it(c), "nome_en": c["titolo_en"], "simbolo": sim,
            "flavor": testo(c.get("flavor_it")), "testo": testo(c.get("testo_it")),
            "tr_nome": testo(p2.get("titolo_it")), "tr_testo": testo(p2.get("testo_it")), "tr_req": testo(p2.get("richiede_en")),
            "mn_testo": testo(c.get("minaccia_it")),
            "ev": e["ev"], "req": e["req"], "tr": e["tr"], "mn": e["mn"],
            "doppia": cid in (306, 330),
        })

# --- relitti
for c in leggi("varie.json"):
    if 200 <= c["id"] <= 202:
        p2 = c.get("parte2", {})
        carte.append({"id": c["id"], "tipo": "relitto", "nome": nome_it(c), "nome_en": c["titolo_en"],
                      "tr_nome": testo(p2.get("titolo_it")), "tr_testo": testo(p2.get("testo_it")),
                      "varianti": EF.RELITTI[c["id"]]})

# --- avventure
AZ = {8: "costruire", 9: "raccogliere", 10: "esplorare"}
for f in ["avventure_8_9.json", "avventure_10.json"]:
    for c in leggi(f):
        cid = c["id"]
        e = EF.AVVENTURE[cid]
        p2 = c.get("parte2", {}) or {}
        carte.append({
            "id": cid, "tipo": "avventura", "azione": AZ[cid // 100], "nome": nome_it(c), "nome_en": c["titolo_en"],
            "flavor": testo(c.get("flavor_it")), "testo": testo(c.get("testo_it")),
            "ev_nome": testo(p2.get("titolo_it")), "ev_testo": testo(p2.get("testo_it")),
            "top": e["top"], "ev": e.get("ev", []),
        })

# --- misteri
for c in leggi("misteri.json"):
    cid = c["id"]
    e = EF.MISTERI[cid]
    p2 = c.get("parte2", {}) or {}
    d = c.get("dati", {})
    carte.append({
        "id": cid, "tipo": "mistero", "sottotipo": d.get("tipo", "tesoro"), "nome": nome_it(c), "nome_en": c["titolo_en"],
        "flavor": testo(c.get("flavor_it")), "testo": testo(c.get("testo_it")),
        "ev_nome": testo(p2.get("titolo_it")), "ev_testo": testo(p2.get("testo_it")),
        "top": e["top"], "ev": e.get("ev", []), "usi": d.get("usi", 0),
    })

# --- invenzioni
for c in leggi("invenzioni.json"):
    cid = c["id"]
    e = EF.INVENZIONI[cid]
    d = c.get("dati", {})
    carte.append({
        "id": cid, "tipo": "invenzione", "k": e["k"], "nome": nome_it(c), "nome_en": c["titolo_en"],
        "testo": testo(c.get("testo_it")), "ter": e.get("ter", []), "inv": e.get("inv", []),
        "costo": e.get("costo", [{}]), "eff": e.get("eff", []), "base": e.get("base", False),
        "scen": e.get("scen", 0), "ripeti": e.get("ripeti", False),
    })

# --- oggetti iniziali, belve
for c in leggi("varie.json"):
    cid = c["id"]
    d = c.get("dati") or {}
    if 600 <= cid <= 607:
        carte.append({"id": cid, "tipo": "oggetto", "k": EF.OGGETTI[cid], "nome": nome_it(c), "nome_en": c["titolo_en"],
                      "testo": testo(c.get("testo_it")), "usi": 2})
    elif 700 <= cid <= 715:
        carte.append({"id": cid, "tipo": "belva", "nome": nome_it(c), "nome_en": c["titolo_en"],
                      "testo": testo(c.get("testo_it")), "forza": d.get("forza", 0), "perdita_arma": d.get("arma", 0),
                      "cibo": d.get("cibo", 0), "pelliccia": d.get("pelliccia", 0), "extra": EF.BELVE_EXTRA.get(cid, [])})
    elif cid in (100, 101):
        carte.append({"id": cid, "tipo": "compagno", "nome": nome_it(c), "nome_en": c["titolo_en"], "testo": testo(c.get("testo_it"))})

# controllo: tutte le carte con un effetto
ids = {c["id"] for c in carte}
for tab in (EF.EVENTI, EF.AVVENTURE, EF.MISTERI, EF.INVENZIONI):
    for k in tab:
        assert k in ids, "manca la trascrizione della carta %d" % k
carte.sort(key=lambda c: c["id"])

# --- tessere isola (lette dalle immagini del modulo TTS)
TESSERE = [
    dict(n=1, terreno="pianura", legno=True, cibo="", belva=True, totem=False, scoperte=2, rifugio=False),
    dict(n=2, terreno="montagna", legno=False, cibo="pappagallo", belva=True, totem=True, scoperte=1, rifugio=True),
    dict(n=3, terreno="fiume", legno=False, cibo="pesce", belva=True, totem=False, scoperte=3, rifugio=False),
    dict(n=4, terreno="collina", legno=True, cibo="pesce", belva=False, totem=True, scoperte=1, rifugio=False),
    dict(n=5, terreno="montagna", legno=True, cibo="pappagallo", belva=False, totem=True, scoperte=1, rifugio=False),
    dict(n=6, terreno="pianura", legno=True, cibo="pappagallo", belva=False, totem=True, scoperte=1, rifugio=False),
    dict(n=7, terreno="collina", legno=True, cibo="", belva=True, totem=True, scoperte=2, rifugio=False),
    dict(n=8, terreno="spiaggia", legno=True, cibo="pesce", belva=False, totem=False, scoperte=0, rifugio=False),
    dict(n=9, terreno="pianura", legno=False, cibo="pappagallo", belva=True, totem=False, scoperte=3, rifugio=False),
    dict(n=10, terreno="fiume", legno=True, cibo="pesce", belva=False, totem=True, scoperte=1, rifugio=False),
    dict(n=11, terreno="montagna", legno=True, cibo="", belva=True, totem=False, scoperte=1, rifugio=True),
]

PERSONAGGI = [
    dict(id="carpentiere", nome="Carpentiere", tipo="pg", segmenti=[4, 3, 2, 3], invenzione=1127, colore=[0.55, 0.36, 0.2],
         abilita=[["Costruzione economica", "2 Det.: 1 legno in meno per un'azione"], ["Maestria", "2 Det.: rilancia un dado marrone"],
                  ["Una nuova idea", "3 Det.: pesca 5 invenzioni, tienine 1"], ["Tuttofare", "3 Det.: una pedina in più per Costruire"]]),
    dict(id="cuoco", nome="Cuoca", tipo="pg", segmenti=[3, 3, 2, 2, 2], invenzione=1112, colore=[0.92, 0.9, 0.85],
         abilita=[["Ricetta della nonna", "2 Det. e 1 cibo: guarisci 2 ferite"], ["Arrangiarsi", "2 Det.: rilancia un dado grigio"],
                  ["Zuppa di sassi", "3 Det.: prendi 1 cibo"], ["Grappa", "3 Det.: ignora 1 pioggia o trasforma 1 neve in pioggia"]]),
    dict(id="esploratore", nome="Esploratrice", tipo="pg", segmenti=[5, 5, 1], invenzione=1124, colore=[0.35, 0.6, 0.3],
         abilita=[["Figlia della fortuna", "2 Det.: rilancia un dado verde"], ["Ricognizione", "2 Det.: guarda 3 tessere, una in cima"],
                  ["Discorso motivazionale", "3 Det.: +1 morale"], ["In avanscoperta", "3 Det.: pesca 2 segnalini Scoperta, tienine 1"]]),
    dict(id="soldato", nome="Soldatessa", tipo="pg", segmenti=[4, 4, 3], invenzione=1128, colore=[0.75, 0.2, 0.15],
         abilita=[["Seguire le tracce", "2 Det.: guarda la prima belva della Caccia"], ["Piano di difesa", "3 Det.: +1 palizzata o +1 arma"],
                  ["Frenesia", "3 Det.: +3 arma nella propria azione"], ["La caccia", "4 Det.: una belva in cima al mazzo Caccia"]]),
    dict(id="venerdi", nome="Venerdì", tipo="venerdi", segmenti=[3], pedine=1, invenzione=0, colore=[0.95, 0.95, 0.95],
         abilita=[["Rilancio", "2 Det.: rilancia un dado d'azione"]]),
]

SCOPERTE = {
    "base": [
        dict(k="tesoro", quanti=2), dict(k="larve", quanti=2), dict(k="capra", quanti=2), dict(k="albero_caduto", quanti=2),
        dict(k="candele", quanti=2), dict(k="verdure"), dict(k="tabacco"), dict(k="rovi"), dict(k="veleno"),
        dict(k="machete"), dict(k="foglie"), dict(k="erbe"), dict(k="erbe_curative"),
    ],
    "scenari": {
        "1": [dict(k="medaglione"), dict(k="sciabola"), dict(k="olio"), dict(k="erbe_c")],
        "2": [dict(k="pugnale"), dict(k="campana_decorata"), dict(k="fiale"), dict(k="candele_culto")],
        "3": [dict(k="liane"), dict(k="capanna"), dict(k="pistola_j"), dict(k="erbe_c")],
        "4": [dict(k="tela"), dict(k="torcia"), dict(k="diario_indy"), dict(k="vecchia_mappa")],
        "5": [dict(k="machete_c"), dict(k="mappa_isola"), dict(k="unguento"), dict(k="cerbottana")],
        "6": [dict(k="semi"), dict(k="polvere_sparo"), dict(k="aratro"), dict(k="attrezzi_vecchi")],
    },
    "nomi": {
        "tesoro": "Tesoro", "larve": "Larve nutrienti", "capra": "Capra", "albero_caduto": "Albero caduto", "candele": "Candele",
        "verdure": "Verdure", "tabacco": "Tabacco", "rovi": "Rovi spinosi", "veleno": "Veleno", "machete": "Vecchio machete",
        "foglie": "Foglie larghe", "erbe": "Erbe", "erbe_curative": "Erbe curative",
        "medaglione": "Medaglione con dama", "sciabola": "Sciabola del pirata", "olio": "Olio", "erbe_c": "Erbe medicinali",
        "pugnale": "Pugnale sacrificale", "campana_decorata": "Campana decorata", "fiale": "Fiale misteriose", "candele_culto": "Candele dei cultisti",
        "liane": "Liane", "capanna": "Capanna in rovina", "pistola_j": "Pistola",
        "tela": "Vecchia tela", "torcia": "Torcia", "diario_indy": "Diario di Indy", "vecchia_mappa": "Vecchia mappa",
        "machete_c": "Vecchio machete", "mappa_isola": "Mappa dell'isola", "unguento": "Unguento curativo", "cerbottana": "Cerbottana",
        "semi": "Semi", "polvere_sparo": "Polvere da sparo", "aratro": "Aratro", "attrezzi_vecchi": "Vecchi attrezzi",
    },
    "testi": {
        "tesoro": "il primo giocatore pesca un tesoro dal mazzo Misteri", "larve": "+2 cibo (subito)", "capra": "con arma 1 o più: +1 pelliccia e +1 cibo",
        "albero_caduto": "+1 legno (subito)", "candele": "una pedina in più per Costruire, una volta", "verdure": "con la Pentola, di notte: guarisci 2 ferite",
        "tabacco": "+1 morale", "rovi": "con il rifugio: +1 palizzata", "veleno": "con la Pentola: +2 arma", "machete": "+1 arma",
        "foglie": "ignora 1 nuvola di pioggia", "erbe": "con la Pentola: +1 morale", "erbe_curative": "con la Pentola: costruisci la Medicina",
        "medaglione": "+3 Determinazione divise come volete", "sciabola": "+1 arma", "olio": "2 legno sulla pira", "erbe_c": "guarisci 1 ferita",
        "pugnale": "+3 arma in combattimento, ma 1 ferita (si tiene)", "campana_decorata": "togli 2 segnalini nebbia", "fiale": "costruisci la Medicina",
        "candele_culto": "una pedina in più per Costruire, una volta", "liane": "+1 palizzata", "capanna": "+2 legno", "pistola_j": "+3 arma in un combattimento",
        "tela": "ignora 1 nuvola", "torcia": "ignora una creatura", "diario_indy": "ignora una trappola", "vecchia_mappa": "una carta Mistero in meno da pescare",
        "machete_c": "+1 arma", "mappa_isola": "guarda le prime 3 tessere e riordinale", "unguento": "guarisci 1 ferita", "cerbottana": "+2 arma in un combattimento",
        "semi": "+1 cibo non deperibile", "polvere_sparo": "rilancia una volta il dado delle belve", "aratro": "togli un segnalino nero da una tessera",
        "attrezzi_vecchi": "costruisci gratis Corda, Pentola o Coltello",
    },
}

SCENARI = [
    dict(n=1, nome="Naufraghi", round=12, meteo={"4-6": ["pioggia"], "7-12": ["pioggia", "neve", "belve"]}, pira=[1, 2, 3, 4, 5],
         obiettivo="Costruite il Fuoco e completate la pira di legna (1+2+3+4+5): se la nave passa (round 10, 11 o 12) vi salvate.",
         libro="Nessun effetto.", totem="Nessun effetto."),
    dict(n=2, nome="L'isola maledetta", round=10, meteo={"6-10": ["neve"]},
         obiettivo="Costruite la Croce su cinque tessere diverse e sopravvivete fino alla fine del round.",
         libro="Nebbia misteriosa: 2 segnalini nebbia su caselle diverse.",
         totem="1: Tempio oscuro (esplorazione speciale). 2: Altare della morte (2 ferite). 3 e oltre: Nascondigli dei cultisti (nebbia)."),
    dict(n=3, nome="Jenny ha bisogno d'aiuto", round=8, meteo={"5-8": ["belve"]}, jenny_vita=11,
         obiettivo="Costruite la Zattera, salvate Jenny con un'esplorazione e poi costruite la Scialuppa.",
         libro="Tempesta: -1 palizzata.",
         totem="1: Rocce scivolose (2 ferite). 2: Cimitero (-2 morale). 3: Resti di alberi (Corda gratis). 4: Relitto del pallone (2 pellicce)."),
    dict(n=4, nome="L'isola del vulcano", round=8, meteo={"1-8": ["pioggia"]}, casella_vulcano=4, casella_partenza=5,
         lava={"4": [5], "5": [2, 9], "6": [1, 8], "7": [3], "8": [0, 7]}, esplora={"1": 6, "2": 6, "3": 7, "4": 8}, totem_obiettivo={"1": 3, "2": 3, "3": 4, "4": 4},
         obiettivo="Esplorate abbastanza caselle e luoghi speciali dei totem, poi costruite la Lancia di bordo.",
         libro="Eruzione: 2 segnalini cenere su caselle diverse.",
         totem="Luoghi speciali: Piccolo tempio (3 Misteri), Villaggio in rovina (4), Grotta nascosta (4, +1 pedina), Tempio sotterraneo (5, +1 pedina)."),
    dict(n=5, nome="L'isola dei cannibali", round=10, meteo={}, oggetti=[603, 605],
         obiettivo="Bruciate i villaggi e distruggete la Città dei cannibali (forza 21 meno 3 per villaggio bruciato).",
         libro="Attacco dei cannibali: ogni personaggio subisce 3 ferite meno i villaggi bruciati; il campo va spostato.",
         totem="Villaggi dei cannibali (forza 4 + totem visibili): bruciateli con un'azione di Caccia."),
    dict(n=6, nome="La famiglia Robinson", round=12,
         meteo={"3-4": ["pioggia"], "5-6": ["neve"], "7-8": ["pioggia", "belve"], "9-10": ["neve", "belve"], "11-12": ["pioggia", "belve"]},
         figli={"7": 1, "8": 1, "9": 2, "10": 2, "11": 3, "12": 3},
         obiettivo="Costruite le 9 invenzioni pescate, il rifugio, almeno 1 di tetto, palizzata e arma, e sfamate i figli.",
         libro="Raccolto scarso: in questo round la produzione si dimezza.",
         totem="Terra desolata: il primo terreno di un tipo resta inesplorato."),
]

out = os.path.join(RADICE, "data")
os.makedirs(out, exist_ok=True)
json.dump(carte, open(os.path.join(out, "carte.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
json.dump(TESSERE, open(os.path.join(out, "tessere.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
json.dump(PERSONAGGI, open(os.path.join(out, "personaggi.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
json.dump(SCOPERTE, open(os.path.join(out, "scoperte.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
json.dump(SCENARI, open(os.path.join(out, "scenari.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(carte), "carte;", len(TESSERE), "tessere;", len(SCENARI), "scenari")
