class_name Azioni
extends RefCounted
## Fase Azione: pianificazione (piazzare le pedine, con requisiti e risorse impegnate) e risoluzione
## nell'ordine del tabellone (minacce, caccia, costruire, raccogliere, esplorare, sistemare il campo, riposo).

var m: Motore
var E: Effetti
var pool: Array = []            # pedine neutre del round: [{tipo, fonte, una_volta}]
var _id := 0


func _init(motore: Motore, eff: Effetti) -> void:
	m = motore
	E = eff


func _log(t: String) -> void:
	m._log(t)


# =====================================================================================
# PEDINE NEUTRE
# =====================================================================================

func _prepara_pool() -> Array:
	var r := []
	if m.ha("lanterna"):
		r.append({"tipo": "costruire", "fonte": "Lanterna"})
	if m.ha("cinture"):
		r.append({"tipo": "raccogliere", "fonte": "Cinture"})
	if m.ha("mappa"):
		r.append({"tipo": "esplorare", "fonte": "Mappa"})
	if m.ha("scudo"):
		r.append({"tipo": "caccia", "fonte": "Scudo"})
	if m.ha("zattera"):
		r.append({"tipo": "raccogliere_esplorare", "fonte": "Zattera"})
	if m.ha("scala_corda"):
		r.append({"tipo": "esplorare_totem", "fonte": "Scala di corda"})
	if m.ha_tesoro(538):
		r.append({"tipo": "esplorare", "fonte": "Bussola"})
	if m.cane:
		r.append({"tipo": "caccia_esplorare", "fonte": "Cane"})
	for k in int(m.neutre.get("costruire", 0)):
		r.append({"tipo": "costruire", "fonte": "Pedina extra"})
	for k in int(m.neutre.get("costruire_carpentiere", 0)):
		r.append({"tipo": "costruire", "fonte": "Tuttofare", "solo": "carpentiere"})
	for k in int(m.neutre_perm.get("costruire", 0)):
		r.append({"tipo": "costruire", "fonte": "Candele", "una_volta": "costruire"})
	return r


func _neutra_ok(n: Dictionary, tipo: String, a: Dictionary) -> bool:
	if n.get("usata", false):
		return false
	if n.has("solo") and m.pg[a["pg"][0]]["id"] != n["solo"]:
		return false
	match n["tipo"]:
		"raccogliere_esplorare":
			return tipo in ["raccogliere", "esplorare"]
		"caccia_esplorare":
			return tipo in ["caccia", "esplorare"]
		"esplorare_totem":
			return tipo == "esplorare" and a.get("speciale", "") != ""
	return n["tipo"] == tipo


# =====================================================================================
# REQUISITI E COSTI
# =====================================================================================

func costo_rifugio() -> Array:
	var n: int = max(2, min(4, m.n_giocatori()))
	var legno := n
	var pell := n - 1
	if "legno_extra" in m.gettoni["rifugio_costo"]:
		legno += 1
	return [{"legno": legno}, {"pelliccia": pell}]


func _primo_tipo(tipo: String) -> bool:
	for a in m.piano:
		if a["tipo"] == tipo:
			return false
	return true


## Pedine minime (con dadi) di un'azione; per costruire/raccogliere/esplorare con una in più si riesce sicuri.
func pedine_minime(tipo: String, bers, extra := {}) -> int:
	var n := 1
	match tipo:
		"minaccia":
			n = int(extra.get("pedine", 1))
		"caccia":
			n = 2
		"raccogliere", "esplorare":
			var k := int(bers)
			n = max(1, m.distanza(k))
			if extra.get("speciale", "") != "" and k == m.campo:
				n = 1
			n += _extra_casella(k)
			if tipo == "raccogliere" and Scenari.villaggio_attivo(m, k):
				n += 1
		"costruire":
			n = 1
			if extra.get("casella", -1) is int and int(extra.get("casella", -1)) >= 0:
				var k2 := int(extra["casella"])
				n = max(1, m.distanza(k2))
				n += _extra_casella(k2)
			else:
				n += _extra_casella(m.campo, true)
		"sistemare", "riposo":
			n = 1 + _extra_casella(m.campo, true)
	if tipo in ["costruire", "raccogliere", "esplorare", "caccia", "sistemare"]:
		if "lento" in m.gettoni.get(tipo, []) and extra.get("primo_tipo", false):
			n += 1
	if tipo == "esplorare" and "lento_fisso" in m.gettoni["esplorare"]:
		n += 1
	if tipo == "esplorare" and extra.get("speciale", "") == "vulcano_ultimi":
		n += 1
	return n


func _extra_casella(k: int, campo := false) -> int:
	if k < 0:
		return 0
	var c: Dictionary = m.isola[k]
	var n := 0
	if "lento" in c["gettoni"]:
		n += 1
	if c["nebbia"]:
		n += 1
	if c.get("cenere", false):
		n += 1
	return n


func ha_inv_req(ks: Array) -> bool:
	for k in ks:
		if not m.ha(k):
			return false
	return true


## Requisiti della minaccia sulla carta id. Restituisce le varianti di risorse possibili ([] = impossibile).
func varianti_minaccia(id: int) -> Array:
	var c: Dictionary = m.C[id]
	if c["tipo"] == "relitto":
		return [{"pedine": 1, "ris": {}, "var": 0}, {"pedine": 2, "ris": {}, "var": 1}]
	var req: Dictionary = c.get("req", {})
	if int(req.get("arma", 0)) > m.arma:
		return []
	if not ha_inv_req(req.get("inv", [])):
		return []
	var alts: Array = req.get("alt", [])
	if alts.is_empty():
		alts = [{}]
	var r := []
	for alt in alts:
		var risorse: Dictionary = req.get("ris", {}).duplicate()
		for t in alt.get("ris", {}):
			risorse[t] = int(risorse.get(t, 0)) + int(alt["ris"][t])
		if not ha_inv_req(alt.get("inv", [])):
			continue
		if not _ris_ok(risorse):
			continue
		r.append({"pedine": int(req.get("pedine", 1)), "ris": risorse})
	return r


func _ris_ok(r: Dictionary) -> bool:
	for t in r:
		if t == "cibo":
			if m.cibo_totale() < int(r[t]):
				return false
		elif m.disponibili(t) < int(r[t]):
			return false
	return true


func _testo_ris(r: Dictionary) -> String:
	var t := []
	for k in r:
		if int(r[k]) > 0:
			t.append("%d %s" % [r[k], m.nome_risorsa(k, int(r[k]))])
	return ", ".join(t)


## Costi possibili per costruire il bersaglio (gia_ legno extra compresi). [] = non costruibile.
func costi_costruzione(bers, i: int) -> Array:
	var base := []
	match str(bers):
		"rifugio":
			if m.rifugio or m.gia_costruiti_round.has("rifugio"):
				return []
			base = costo_rifugio()
		"tetto", "palizzata":
			if not m.rifugio_presente() or (m.rifugio and m.rifugio_round == m.round and not m.tessera(m.campo).get("rifugio", false)):
				return []
			base = costo_rifugio()
		"arma":
			var l := 1
			if "legno_extra" in m.gettoni["arma_costo"]:
				l += 1
			base = [{"legno": l}]
		_:
			var id := int(bers)
			var c: Dictionary = m.C[id]
			if m.costruite.has(id) and not c.get("ripeti", false):
				return []
			if m.gia_costruiti_round.has(id) and not c.get("ripeti", false):
				return []
			if m.vincoli.get("oggetti_via", false):
				return []
			var ter := m.terreni_esplorati()
			for t in c.get("ter", []):
				if not ter.has(t):
					return []
			if not ha_inv_req(c.get("inv", [])):
				return []
			if not Scenari.costruibile(m, id):
				return []
			# invenzione personale: solo il proprietario
			for p in m.pg:
				if int(p.get("inv", 0)) == id and m.pg[i]["id"] != p["id"]:
					return []
			base = c.get("costo", [{}])
	var r := []
	for cst in base:
		var cc: Dictionary = cst.duplicate()
		if cc.has("legno") and "legno_extra" in m.gettoni["costruire"] and _primo_legno():
			cc["legno"] = int(cc["legno"]) + 1
		if _ris_ok(cc):
			r.append(cc)
	return r


func _primo_legno() -> bool:
	for a in m.piano:
		if a["tipo"] == "costruire" and int(a.get("ris", {}).get("legno", 0)) > 0:
			return false
	return true


func nome_bersaglio(tipo: String, bers, extra := {}) -> String:
	match tipo:
		"minaccia":
			var id := int(bers)
			var c: Dictionary = m.C[id]
			return "%s: %s" % ["Relitto" if c["tipo"] == "relitto" else "Minaccia", c.get("tr_nome", c["nome"])]
		"caccia":
			return "Caccia"
		"costruire":
			match str(bers):
				"rifugio": return "Costruire il rifugio"
				"tetto": return "Alzare il tetto"
				"palizzata": return "Alzare la palizzata"
				"arma": return "Migliorare l'arma"
			var s := "Costruire: %s" % m.nome_carta(int(bers))
			if extra.has("casella") and int(extra["casella"]) >= 0 and m.C[int(bers)].get("k", "") == "croce":
				s += " (tessera %d)" % int(m.isola[int(extra["casella"])]["tessera"])
			return s
		"raccogliere":
			return "Raccogliere %s sulla tessera %d" % [extra.get("risorsa", ""), int(m.isola[int(bers)]["tessera"])]
		"esplorare":
			if extra.get("speciale", "") != "":
				return "Esplorare: %s" % Scenari.nome_luogo(m, extra["speciale"], int(bers))
			return "Esplorare la casella %d" % (int(bers) + 1)
		"sistemare":
			return "Sistemare il campo"
		"riposo":
			return "Riposare"
	return tipo


# =====================================================================================
# PIANIFICAZIONE
# =====================================================================================

func pedine_libere(i: int) -> int:
	var n := m.pedine_di(i)
	for a in m.piano:
		n -= a["pg"].count(i)
	return n


func azione_ammessa(i: int, tipo: String) -> bool:
	var solo: Array = m.pg[i]["vincoli"].get("solo", [])
	if not solo.is_empty() and not tipo in solo:
		return false
	return true


## Tutte le azioni nuove che il personaggio i può aprire come risolutore.
func azioni_possibili(i: int) -> Array:
	var r := []
	var ven: bool = m.pg[i]["tipo"] == "venerdi"
	# minacce
	if azione_ammessa(i, "minaccia"):
		for slot in 2:
			var id: int = m.minacce[slot]
			if id < 0 or _pianificata("minaccia", id):
				continue
			for v in varianti_minaccia(id):
				var a := {"tipo": "minaccia", "bers": id, "min": int(v["pedine"]), "auto": int(v["pedine"]), "ris": v["ris"], "var": int(v.get("var", 0)), "carta": id}
				if m.C[id].get("req", {}).get("diversi", false):
					a["diversi"] = true
				r.append(a)
	# caccia
	if azione_ammessa(i, "caccia"):
		var cacce := 0
		for a in m.piano:
			if a["tipo"] == "caccia":
				cacce += 1
		if cacce < m.mazzo_caccia.size():
			var n := pedine_minime("caccia", 0, {"primo_tipo": _primo_tipo("caccia")})
			r.append({"tipo": "caccia", "bers": 0, "min": n, "auto": n, "ris": {}})
		for x in Scenari.cacce_speciali(m):
			if not _pianificata("caccia", x["bers"]):
				var n2 := pedine_minime("caccia", 0, {"primo_tipo": _primo_tipo("caccia")})
				r.append({"tipo": "caccia", "bers": x["bers"], "min": n2, "auto": n2, "ris": {}, "speciale": x["speciale"]})
	# costruire
	if azione_ammessa(i, "costruire"):
		var bersagli := ["rifugio", "tetto", "palizzata", "arma"]
		for id in m.invenzioni:
			bersagli.append(id)
		for p in m.pg:
			if int(p.get("inv", 0)) > 0:
				bersagli.append(int(p["inv"]))
		for b in bersagli:
			if not str(b) in ["tetto", "palizzata", "arma"] and _pianificata("costruire", b) and not (str(b) != "rifugio" and m.C[int(b)].get("ripeti", false)):
				continue
			for cst in costi_costruzione(b, i):
				var caselle := [-1]
				if not str(b) in ["rifugio", "tetto", "palizzata", "arma"]:
					caselle = Scenari.caselle_costruzione(m, int(b))
				for k in caselle:
					var ex := {"primo_tipo": _primo_tipo("costruire"), "casella": k}
					var n := pedine_minime("costruire", b, ex)
					r.append({"tipo": "costruire", "bers": b, "min": n, "auto": n + 1, "ris": cst, "casella": k if k >= 0 else m.campo})
					# risparmio del carpentiere
					if m.pg[i]["id"] == "carpentiere" and int(m.pg[i]["det"]) >= 2 and not m.pg[i]["usate"].has("risparmio") and int(cst.get("legno", 0)) > 0 and not m.pg[i]["vincoli"].get("no_abilita", false):
						var c2: Dictionary = cst.duplicate()
						c2["legno"] = int(c2["legno"]) - 1
						r.append({"tipo": "costruire", "bers": b, "min": n, "auto": n + 1, "ris": c2, "risparmio": true, "casella": k if k >= 0 else m.campo})
	# raccogliere
	if azione_ammessa(i, "raccogliere"):
		for k in m.isola.size():
			if k == m.campo or not m.esplorata(k) or m.distanza(k) < 1:
				continue
			for f in ["legno", "cibo"]:
				if not E._fonte_tipo(k, f):
					continue
				if m.raccolti_round.has("%d_%s" % [k, f]) or _pianificata_racc(k, f):
					continue
				var n := pedine_minime("raccogliere", k, {"primo_tipo": _primo_tipo("raccogliere")})
				r.append({"tipo": "raccogliere", "bers": k, "risorsa": f, "min": n, "auto": n + 1, "ris": {}, "casella": k})
	# esplorare
	if azione_ammessa(i, "esplorare"):
		for k in m.isola.size():
			if m.isola[k]["tessera"] >= 0 or m.esplorati_round.has(k) or _pianificata("esplorare", k):
				continue
			if k == 10 and m.scenario != 5:
				continue
			var d := m.distanza(k)
			if d < 1:
				continue
			var n := pedine_minime("esplorare", k, {"primo_tipo": _primo_tipo("esplorare")})
			r.append({"tipo": "esplorare", "bers": k, "min": n, "auto": n + 1, "ris": {}, "casella": k})
		for x in Scenari.luoghi_esplorabili(m):
			if _pianificata("esplorare", x["k"], x["speciale"]):
				continue
			var n2 := pedine_minime("esplorare", x["k"], {"primo_tipo": _primo_tipo("esplorare"), "speciale": x["speciale"]})
			var a2 := {"tipo": "esplorare", "bers": x["k"], "speciale": x["speciale"], "min": n2, "auto": n2 + 1, "ris": {}, "casella": x["k"]}
			if x.has("esatte"):
				a2["min"] = int(x["esatte"])
				a2["auto"] = int(x["esatte"])
			r.append(a2)
	# sistemare e riposo
	if not ven:
		for t in ["sistemare", "riposo"]:
			if azione_ammessa(i, t):
				var n := pedine_minime(t, m.campo, {"primo_tipo": _primo_tipo(t)})
				r.append({"tipo": t, "bers": 0, "min": n, "auto": n, "ris": {}})
	elif azione_ammessa(i, "riposo"):
		r.append({"tipo": "riposo", "bers": 0, "min": 1, "auto": 1, "ris": {}})
	return r


func _pianificata(tipo: String, bers, speciale := "") -> bool:
	for a in m.piano:
		if a["tipo"] == tipo and str(a["bers"]) == str(bers) and a.get("speciale", "") == speciale:
			return true
	return false


func _pianificata_racc(k: int, f: String) -> bool:
	for a in m.piano:
		if a["tipo"] == "raccogliere" and int(a["bers"]) == k and a.get("risorsa", "") == f:
			return true
	return false


func pedine_totali(a: Dictionary) -> int:
	return a["pg"].size() + a.get("neutre", []).size()


## Opzioni di piazzamento per il personaggio i (che ha almeno una pedina libera).
func opzioni_piazzamento(i: int) -> Array:
	var opz := []
	var libere := pedine_libere(i)
	var ven: bool = m.pg[i]["tipo"] == "venerdi"
	for a in azioni_possibili(i):
		var neutre := _neutre_per(a, i)
		var desc := nome_bersaglio(a["tipo"], a["bers"], a)
		if a.has("ris") and not a["ris"].is_empty():
			desc += " — %s" % _testo_ris(a["ris"])
		if a.get("risparmio", false):
			desc += " (Risparmio, 2 Det.)"
		if a["tipo"] == "minaccia" and m.C[int(a["bers"])]["tipo"] == "relitto":
			desc += " (%d %s)" % [a["min"], "pedina" if a["min"] == 1 else "pedine"]
		var varianti := []
		if a["min"] == a["auto"]:
			varianti.append(a["min"])
		else:
			varianti.append(a["min"])
			varianti.append(a["auto"])
		for tot in varianti:
			var nn: int = min(neutre.size(), tot - 1)
			var mie: int = tot - nn
			if a.get("diversi", false):
				mie = 1
				nn = 0
			if mie > libere:
				# può iniziare e chiedere aiuto agli altri
				if libere >= 1 and not ven and not m.vincoli.get("no_insieme", false):
					var d2 := desc + (" — %d pedine (serve aiuto)" % tot)
					opz.append(_opz(a, d2, libere, nn, neutre, tot))
				continue
			var t2 := desc
			if a["tipo"] in ["costruire", "raccogliere", "esplorare"]:
				t2 += " — %s" % ("sicuro" if tot == a["auto"] else "con i dadi")
			if a.get("diversi", false):
				t2 += " (serve la pedina di un altro giocatore)"
			if nn > 0:
				var nomi := []
				for k in nn:
					nomi.append(neutre[k]["fonte"])
				t2 += " (+ %s)" % ", ".join(nomi)
			if mie > 1:
				t2 += " [%d tue pedine]" % mie
			opz.append(_opz(a, t2, mie, nn, neutre, tot))
	# aiutare un'azione già pianificata
	if not ven or true:
		for a in m.piano:
			if a["pg"].has(i) and a["tipo"] != "minaccia":
				pass
			if m.vincoli.get("no_insieme", false) and not a.get("diversi", false):
				if not a["pg"].is_empty() and posto_pg(a["pg"][0]) != posto_pg(i):
					continue
			var tot2 := pedine_totali(a)
			if tot2 >= int(a["auto"]):
				continue
			if a.get("diversi", false) and a["pg"].has(i):
				continue
			if a.get("diversi", false) and m.pg[i]["tipo"] == "venerdi" and false:
				continue
			opz.append({"testo": "Aiuta: %s (%s, %d/%d pedine)" % [nome_bersaglio(a["tipo"], a["bers"], a), m.pg[a["pg"][0]]["nome"], tot2, a["auto"]],
				"op": "aiuta", "piano": a["id"], "casella": a.get("casella", -1), "azione": a["tipo"]})
	# togliere un'azione propria
	for a in m.piano:
		if not a["pg"].is_empty() and a["pg"][0] == i:
			opz.append({"testo": "Annulla: %s" % nome_bersaglio(a["tipo"], a["bers"], a), "op": "annulla", "piano": a["id"], "azione": a["tipo"]})
	if ven:
		opz.append({"testo": "Venerdì resta al campo in questo round", "op": "riposa_venerdi"})
	return opz


func posto_pg(i: int) -> int:
	if m.pg[i]["tipo"] == "venerdi":
		return -100
	return m.posto_di(i) * 10 + i


func _opz(a: Dictionary, testo: String, mie: int, nn: int, neutre: Array, tot: int) -> Dictionary:
	var o := a.duplicate()
	o["testo"] = testo
	o["op"] = "nuova"
	o["mie"] = mie
	o["nn"] = nn
	o["tot"] = tot
	o["azione"] = a["tipo"]
	return o


func _neutre_per(a: Dictionary, i: int) -> Array:
	var r := []
	if a["tipo"] in ["minaccia", "sistemare", "riposo"]:
		return r
	var finta := {"pg": [i], "speciale": a.get("speciale", "")}
	for n in pool:
		if _neutra_ok(n, a["tipo"], finta):
			r.append(n)
	return r


func applica_opzione(i: int, o: Dictionary) -> void:
	match o["op"]:
		"nuova":
			_id += 1
			var a := {"id": _id, "tipo": o["tipo"], "bers": o["bers"], "pg": [], "neutre": [], "ris": o.get("ris", {}).duplicate(),
				"min": int(o["min"]), "auto": int(o["auto"])}
			for k in ["risorsa", "speciale", "casella", "var", "diversi", "risparmio", "carta"]:
				if o.has(k):
					a[k] = o[k]
			for k in int(o["mie"]):
				a["pg"].append(i)
			var usate := 0
			for n in pool:
				if usate >= int(o["nn"]):
					break
				if _neutra_ok(n, a["tipo"], a):
					n["usata"] = true
					a["neutre"].append(n)
					usate += 1
			if a.get("risparmio", false):
				m.pg[i]["det"] -= 2
				m.pg[i]["usate"]["risparmio"] = true
			if a["tipo"] in ["costruire", "raccogliere", "esplorare", "caccia", "sistemare"] and "lento" in m.gettoni.get(a["tipo"], []) and _primo_tipo(a["tipo"]):
				a["lento"] = true
			m.piano.append(a)
			if a["tipo"] in ["raccogliere", "esplorare", "costruire"]:
				var k := int(a.get("casella", -1))
				if k >= 0 and "pericolo" in m.isola[k]["gettoni"] and m.arma < 1:
					m.ferisci(i, 1, "pericolo")
		"aiuta":
			for a in m.piano:
				if a["id"] == int(o["piano"]):
					a["pg"].append(i)
		"annulla":
			for a in m.piano:
				if a["id"] == int(o["piano"]):
					for n in a.get("neutre", []):
						n["usata"] = false
					if a.get("risparmio", false):
						m.pg[i]["det"] += 2
						m.pg[i]["usate"].erase("risparmio")
					m.piano.erase(a)
					break
		"riposa_venerdi":
			m.pg[i]["fermo"] = true


func pianifica() -> void:
	m.piano = []
	pool = _prepara_pool()
	for p in m.pg:
		p["fermo"] = false
	var giri := 0
	while m.esito == "" and giri < 200:
		giri += 1
		var chi := _prossimo_da_piazzare()
		if chi >= 0:
			var opz := opzioni_piazzamento(chi)
			if opz.is_empty():
				m.pg[chi]["fermo"] = true
				continue
			var r = await m.chiedi_pg(chi, {"tipo": "piazza", "titolo": "Pianificazione: %s" % m.pg[chi]["nome"],
				"testo": "%s ha %d %s da piazzare." % [m.pg[chi]["nome"], pedine_libere(chi), "pedina" if pedine_libere(chi) == 1 else "pedine"],
				"opzioni": opz})
			applica_opzione(chi, opz[r])
			m.cambiato.emit()
			continue
		# azioni incomplete
		var incomplete := []
		for a in m.piano:
			if pedine_totali(a) < int(a["min"]) or (a.get("diversi", false) and _giocatori_diversi(a) < 2):
				incomplete.append(a)
		if not incomplete.is_empty():
			var opz2 := []
			for a in incomplete:
				opz2.append({"testo": "Annulla: %s (%d/%d pedine)" % [nome_bersaglio(a["tipo"], a["bers"], a), pedine_totali(a), a["min"]], "id": a["id"]})
			var r2 = await m.chiedi(m.capo(), {"tipo": "piano", "titolo": "Azioni senza pedine sufficienti", "testo": "Queste azioni non hanno abbastanza pedine: vanno annullate e le pedine ripiazzate.", "opzioni": opz2})
			for a in m.piano:
				if a["id"] == int(opz2[r2]["id"]):
					for n in a.get("neutre", []):
						n["usata"] = false
					m.piano.erase(a)
					break
			continue
		# conferma
		var opz3 := [{"testo": "Conferma il piano e risolvi le azioni", "op": "ok"}]
		for a in m.piano:
			if not a["pg"].is_empty():
				opz3.append({"testo": "Annulla: %s (%s)" % [nome_bersaglio(a["tipo"], a["bers"], a), m.pg[a["pg"][0]]["nome"]], "op": "annulla", "id": a["id"]})
		var r3 = await m.chiedi(m.capo(), {"tipo": "conferma_piano", "titolo": "Piano del round", "testo": "Tutte le pedine sono piazzate.", "opzioni": opz3, "conferma": true})
		if opz3[r3]["op"] == "ok":
			break
		for a in m.piano:
			if a["id"] == int(opz3[r3]["id"]):
				for n in a.get("neutre", []):
					n["usata"] = false
				m.piano.erase(a)
				break
		for p in m.pg:
			p["fermo"] = false


func _giocatori_diversi(a: Dictionary) -> int:
	var s := {}
	for i in a["pg"]:
		s[i] = true
	return s.size()


func _prossimo_da_piazzare() -> int:
	var ordine := []
	var gg := m.giocanti()
	var start := gg.find(m.primo)
	for k in gg.size():
		ordine.append(gg[(start + k) % gg.size()] if start >= 0 else gg[k])
	for i in ordine:
		if pedine_libere(i) > 0 and not m.pg[i].get("fermo", false):
			return i
	var v := m.indice_venerdi()
	if v >= 0 and not m.pg[v]["morto"] and pedine_libere(v) > 0 and not m.pg[v].get("fermo", false):
		return v
	return -1


# =====================================================================================
# RISOLUZIONE
# =====================================================================================

func risolvi() -> void:
	m.fase = "azione"
	_log("Risoluzione delle azioni.")
	var lento_usato := {}
	for tipo in Motore.AZIONI:
		var lista := []
		for a in m.piano:
			if a["tipo"] == tipo:
				lista.append(a)
		for a in lista:
			if m.esito != "":
				return
			if a.get("lento", false):
				lento_usato[tipo] = true
			await risolvi_azione(a)
			m.piano.erase(a)
			m.cambiato.emit()
		if lento_usato.has(tipo):
			m.gettoni[tipo].erase("lento")
		if tipo == "costruire" and m.vincoli.has("costruzione_extra"):
			await _costruzione_extra(int(m.vincoli["costruzione_extra"]))
			m.vincoli.erase("costruzione_extra")
	# le pedine neutre usate una volta si consumano
	for n in pool:
		if n.get("usata", false) and n.has("una_volta"):
			m.neutre_perm[n["una_volta"]] = max(0, int(m.neutre_perm.get(n["una_volta"], 0)) - 1)


func _costruzione_extra(i: int) -> void:
	var opz := [{"testo": "Nessuna costruzione", "a": {}}]
	for a in azioni_possibili(i):
		if a["tipo"] == "costruire" and int(a["min"]) <= 1 and not a.get("risparmio", false):
			opz.append({"testo": "%s — %s" % [nome_bersaglio("costruire", a["bers"], a), _testo_ris(a["ris"])], "a": a})
	if opz.size() == 1:
		return
	var r = await m.chiedi_pg(i, {"tipo": "costruzione_extra", "titolo": "Lavoro veloce", "testo": "Un'altra azione Costruire (con i dadi).", "opzioni": opz})
	var a: Dictionary = opz[r]["a"]
	if a.is_empty():
		return
	a = a.duplicate()
	a["pg"] = [i]
	a["neutre"] = []
	a["forza_dadi"] = true
	await risolvi_azione(a)


func risolvi_azione(a: Dictionary) -> void:
	var i: int = a["pg"][0] if not a["pg"].is_empty() else m.primo
	var tipo: String = a["tipo"]
	var ctx := {"chi": i, "azione": a, "casella": int(a.get("casella", -1))}
	m.evento.emit("azione", {"tipo": tipo, "pg": i, "bers": a["bers"], "casella": int(a.get("casella", -1))})
	match tipo:
		"minaccia":
			await _risolvi_minaccia(a, i)
		"caccia":
			await _risolvi_caccia(a, i)
		"costruire", "raccogliere", "esplorare":
			await _risolvi_con_dadi(a, i, ctx)
		"sistemare":
			await _risolvi_sistemare(a, i)
		"riposo":
			_risolvi_riposo(a, i)


func _paga(a: Dictionary) -> void:
	for t in a.get("ris", {}):
		var n := int(a["ris"][t])
		if n <= 0:
			continue
		if t == "cibo":
			m.scarta_ris("cibo", n, -1, true)
		else:
			m.ris[t] = max(0, int(m.ris[t]) - n)


func _risolvi_minaccia(a: Dictionary, i: int) -> void:
	var id := int(a["bers"])
	var slot: int = m.minacce.find(id)
	if slot < 0:
		return
	var c: Dictionary = m.C[id]
	_log("%s affronta la minaccia: %s." % [m.pg[i]["nome"], c.get("tr_nome", c["nome"])])
	_paga(a)
	m.minacce[slot] = -1
	if c["tipo"] == "relitto":
		var v := int(a.get("var", 0))
		await E.esegui(c["varianti"][v], {"chi": i, "carta": id})
	else:
		await E.esegui(c.get("tr", []), {"chi": i, "carta": id})


func _risolvi_caccia(a: Dictionary, i: int) -> void:
	if a.get("speciale", "") != "":
		await Scenari.caccia_speciale(m, E, a, i)
		return
	if m.mazzo_caccia.is_empty():
		return
	var b: int = m.mazzo_caccia.pop_back()
	var pericolo: bool = "pericolo" in m.gettoni["caccia"]
	m.gettoni["caccia"].erase("pericolo")
	_log("%s va a caccia e incontra: %s." % [m.pg[i]["nome"], m.nome_carta(b)])
	m.evento.emit("carta", {"id": b, "lato": "belva"})
	await E.mostra(b, "belva", "Caccia")
	await E.combatti(i, E.belva_dati(b), {"chi": i, "pericolo": pericolo})


## Costruire, raccogliere, esplorare: riuscita sicura con abbastanza pedine, altrimenti i tre dadi.
func _risolvi_con_dadi(a: Dictionary, i: int, ctx: Dictionary) -> void:
	var tipo: String = a["tipo"]
	var colore := tipo
	var ven: bool = m.pg[i]["tipo"] == "venerdi"
	var k := int(a.get("casella", -1))
	if k >= 0 and "pericolo" in m.isola[k]["gettoni"] and m.arma < 1 and tipo != "costruire":
		pass
	var dadi: bool = pedine_totali(a) < int(a["auto"]) or a.get("forza_dadi", false)
	var succ_negato: String = m.pg[i]["succ_negato"]
	var forza_succ: bool = succ_negato == "prossimo" and not dadi
	var riuscita := true
	var avventura: bool = m.gettoni_avv[colore]
	var ferita := false
	if dadi or forza_succ:
		var facce: Dictionary = Motore.DADI[colore]
		var esiti := {"ferita": m.dado(facce["ferita"]), "avventura": m.dado(facce["avventura"]), "successo": m.dado(facce["successo"])}
		if forza_succ:
			esiti["ferita"] = ""
			esiti["avventura"] = ""
		# gettone «rilancia un successo» sullo spazio azione
		if esiti["successo"] == "s" and "rilancio" in m.gettoni[colore]:
			m.gettoni[colore].erase("rilancio")
			esiti["successo"] = m.dado(facce["successo"])
			_log("Il successo va rilanciato: %s." % ("successo" if esiti["successo"] == "s" else "fallimento"))
		if esiti["successo"] == "s" and succ_negato != "":
			esiti["successo"] = m.dado(facce["successo"])
			_log("Il successo va rilanciato (carta Mistero): %s." % ("successo" if esiti["successo"] == "s" else "fallimento"))
		m.evento.emit("dadi", {"tipo": colore, "esiti": esiti, "pg": i})
		esiti = await _rilanci(i, colore, esiti)
		riuscita = esiti["successo"] == "s"
		ferita = esiti["ferita"] == "f"
		if esiti["avventura"] == "?":
			avventura = true
		_log("%s tira i dadi: %s, %s, %s." % [m.pg[i]["nome"], "successo" if riuscita else "fallimento", "ferita" if ferita else "nessuna ferita", "avventura" if esiti["avventura"] == "?" else "nessuna avventura"])
	if ferita:
		m.ferisci(i, 1, "dado")
		if m.esito != "":
			return
	if riuscita:
		match tipo:
			"costruire":
				await _costruito(a, i)
			"raccogliere":
				await _raccolto(a, i)
			"esplorare":
				await _esplorato(a, i, ctx)
	else:
		_log("%s non riesce: %s. Ottiene 2 Determinazione." % [m.pg[i]["nome"], nome_bersaglio(tipo, a["bers"], a)])
		m.dai_det(i, 2)
		if tipo == "costruire" and m.costruite.has(-1):
			pass
		if tipo == "costruire" and not str(a["bers"]) in ["tetto", "palizzata", "arma"]:
			m.gia_costruiti_round[a["bers"] if str(a["bers"]) != "rifugio" else "rifugio"] = true
		if tipo == "esplorare":
			m.esplorati_round[int(a["bers"])] = true
	if m.esito != "":
		return
	if avventura:
		m.gettoni_avv[colore] = false
		if a.get("speciale", "") == "jenny" and dadi:
			_log("Sulla zattera: niente avventura, ma una ferita.")
			m.ferisci(i, 1, "zattera")
		elif ven:
			_log("Venerdì si ferisce invece di vivere un'avventura.")
			m.ferisci(i, 1, "avventura")
		else:
			await pesca_avventura(colore, i, ctx)


func _rilanci(i: int, colore: String, esiti: Dictionary) -> Dictionary:
	var p: Dictionary = m.pg[i]
	var abil := {"costruire": ["carpentiere", "maestria"], "raccogliere": ["cuoco", "arrangiarsi"], "esplorare": ["esploratore", "fortuna"]}
	var giri := 0
	while giri < 4:
		giri += 1
		var opz := [{"testo": "Accetta il risultato", "d": ""}]
		var puo := false
		if p["vincoli"].get("no_abilita", false):
			pass
		elif p["id"] == abil[colore][0] and int(p["det"]) >= 2 and not p["usate"].has(abil[colore][1]):
			puo = true
		elif p["tipo"] == "venerdi" and int(p["det"]) >= 2 and not p["usate"].has("rilancio"):
			puo = true
		if not puo:
			return esiti
		if esiti["successo"] != "s":
			opz.append({"testo": "Rilancia il dado del successo (2 Det.)", "d": "successo"})
		if esiti["ferita"] == "f":
			opz.append({"testo": "Rilancia il dado della ferita (2 Det.)", "d": "ferita"})
		if esiti["avventura"] == "?":
			opz.append({"testo": "Rilancia il dado dell'avventura (2 Det.)", "d": "avventura"})
		if opz.size() == 1:
			return esiti
		var r = await m.chiedi_pg(i, {"tipo": "rilancio", "titolo": "Dadi", "testo": "Risultato: %s, %s, %s." % [
			"successo" if esiti["successo"] == "s" else "fallimento", "ferita" if esiti["ferita"] == "f" else "nessuna ferita", "avventura" if esiti["avventura"] == "?" else "nessuna avventura"],
			"opzioni": opz, "dadi": esiti, "colore": colore})
		var d: String = opz[r]["d"]
		if d == "":
			return esiti
		p["det"] -= 2
		p["usate"][abil[colore][1] if p["tipo"] != "venerdi" else "rilancio"] = true
		esiti[d] = m.dado(Motore.DADI[colore][d])
		m.evento.emit("dadi", {"tipo": colore, "esiti": esiti, "pg": i})
	return esiti


func pesca_avventura(colore: String, i: int, ctx: Dictionary) -> void:
	if m.mazzi_avv[colore].is_empty():
		return
	var id: int = m.mazzi_avv[colore].pop_back()
	var c: Dictionary = m.C[id]
	_log("%s vive un'avventura: %s." % [m.pg[i]["nome"], c["nome"]])
	m.evento.emit("carta", {"id": id, "lato": "avventura"})
	await E.mostra(id, "avventura", "Avventura")
	var ctx2 := ctx.duplicate()
	ctx2["carta"] = id
	ctx2["chi"] = i
	ctx2["vittima"] = i
	E._rimescolata = false
	await E.esegui(c.get("top", []), ctx2)
	E._rimescolata = false


func _costruito(a: Dictionary, i: int) -> void:
	_paga(a)
	var b = a["bers"]
	if int(a.get("ris", {}).get("legno", 0)) > 0 and "legno_extra" in m.gettoni["costruire"]:
		m.gettoni["costruire"].erase("legno_extra")
	match str(b):
		"rifugio":
			m.rifugio = true
			m.rifugio_round = m.round
			m.gia_costruiti_round["rifugio"] = true
			_log("%s costruisce il rifugio." % m.pg[i]["nome"])
			m.evento.emit("costruito", {"cosa": "rifugio"})
		"tetto", "palizzata", "arma":
			m.cambia_livello(str(b), 1)
			m.evento.emit("costruito", {"cosa": str(b)})
		_:
			var id := int(b)
			m.gia_costruiti_round[id] = true
			_log("%s costruisce: %s." % [m.pg[i]["nome"], m.nome_carta(id)])
			if int(m.pg[i].get("inv", 0)) == id:
				m.dai_det(i, 2)
			if await Scenari.costruito_subito(m, E, id, a, i):
				return
			m.inv_fut.append(id)
			m.evento.emit("costruito", {"cosa": "invenzione", "id": id})


func _raccolto(a: Dictionary, i: int) -> void:
	var k := int(a["bers"])
	var f: String = a["risorsa"]
	var n := 1
	if (f + "_extra") in m.isola[k]["gettoni"]:
		n += 1
	if m.ha("cesto") and not m.vincoli.get("cesto_usato", false):
		n += 1
		m.vincoli["cesto_usato"] = true
	if m.ha("sacco") and not m.vincoli.get("sacco_usato", false):
		n += 1
		m.vincoli["sacco_usato"] = true
	m.raccolti_round["%d_%s" % [k, f]] = true
	_log("%s raccoglie %d %s sulla tessera %d." % [m.pg[i]["nome"], n, f, int(m.isola[k]["tessera"])])
	m.guadagna(f, n, i)


func _esplorato(a: Dictionary, i: int, ctx: Dictionary) -> void:
	var k := int(a["bers"])
	m.esplorati_round[k] = true
	if a.get("speciale", "") != "":
		await Scenari.esplora_luogo(m, E, a, i)
		return
	if m.pila_tessere.is_empty():
		_log("Non ci sono più tessere isola.")
		return
	var n: int = m.pila_tessere.pop_back()
	if m.ha("canoa") and not m.pila_tessere.is_empty():
		var n2: int = m.pila_tessere.pop_back()
		var r = await m.chiedi_pg(i, {"tipo": "tessera", "titolo": "Canoa", "testo": "Quale tessera piazzi?", "opzioni": [
			{"testo": "Tessera %d: %s" % [n, E.descrivi_tessera(n)], "tessera": n}, {"testo": "Tessera %d: %s" % [n2, E.descrivi_tessera(n2)], "tessera": n2}]})
		if r == 1:
			var t := n
			n = n2
			n2 = t
		m.pila_tessere.insert(m.rng.randi_range(0, m.pila_tessere.size()), n2)
	await piazza_tessera(k, n, i)


func piazza_tessera(k: int, n: int, i: int) -> void:
	var c: Dictionary = m.isola[k]
	c["tessera"] = n
	c["giu"] = false
	var t: Dictionary = m.T[n]
	_log("%s esplora la casella e scopre la tessera %d: %s." % [m.pg[i]["nome"], n, E.descrivi_tessera(n)])
	m.evento.emit("tessera", {"k": k, "n": n})
	if c.get("da_esaurire", false):
		c.erase("da_esaurire")
		var opz := []
		for f in ["legno", "cibo"]:
			if E._fonte_tipo(k, f):
				opz.append({"testo": "Fonte di %s" % f, "f": f})
		if not opz.is_empty():
			var r = await m.chiedi(m.capo(), {"tipo": "fonte", "titolo": "Fonte esaurita", "testo": "Quale fonte si esaurisce?", "opzioni": opz})
			c["esauriti"][opz[r]["f"]] = true
	if t.get("belva", false) and not m.mazzo_belve.is_empty():
		m.mazzo_caccia.append(m.mazzo_belve.pop_back())
		m._mescola(m.mazzo_caccia)
		_log("Una belva entra nel mazzo Caccia (%d carte)." % m.mazzo_caccia.size())
	if t.get("totem", false):
		await Scenari.totem(m, E, k, i)
	if m.esito != "":
		return
	var sc := int(t.get("scoperte", 0))
	if sc > 0:
		await E.pesca_scoperte(sc, i)
	if m.ha_tesoro(509):
		await E.scegli_scoperta(2, i)
	await Scenari.tessera_piazzata(m, E, k, i)


func _risolvi_sistemare(a: Dictionary, i: int) -> void:
	if "nero" in m.gettoni["sistemare"]:
		m.gettoni["sistemare"].erase("nero")
		_log("Il campo è devastato dall'orso: %s lo rimette in ordine senza altri vantaggi." % m.pg[i]["nome"])
		return
	var bibbia := E.ha_oggetto(600)
	if m.n_giocatori() >= 4:
		var r = await m.chiedi_pg(i, {"tipo": "sistemare", "titolo": "Sistemare il campo", "testo": "Con 4 giocatori si sceglie un vantaggio.",
			"opzioni": [{"testo": "+2 Determinazione"}, {"testo": "+1 morale"}]})
		if r == 0:
			m.dai_det(i, 2)
		else:
			m.cambia_morale(1)
	else:
		m.dai_det(i, 2)
		m.cambia_morale(1)
	if bibbia:
		var r2 = await m.chiedi_pg(i, {"tipo": "bibbia", "titolo": "Bibbia", "testo": "Usi la Bibbia (+1 Determinazione e +1 vita)?", "opzioni": [{"testo": "Sì"}, {"testo": "No"}]})
		if r2 == 0:
			E._usa_oggetto(600)
			m.dai_det(i, 1)
			m.cura(i, 1)


func _risolvi_riposo(a: Dictionary, i: int) -> void:
	if m.ha("letto") and m.pg[i]["tipo"] != "venerdi":
		m.dai_det(i, 1)
		m.cura(i, 2)
	else:
		m.cura(i, 1)
		if m.ha_tesoro(529) and m.pg[i]["tipo"] != "venerdi":
			m.dai_det(i, 1)
	_log("%s riposa." % m.pg[i]["nome"])
