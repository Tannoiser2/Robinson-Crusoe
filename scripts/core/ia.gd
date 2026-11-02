class_name IA
extends RefCounted
## Compagni IA: decisioni con regole pratiche (sopravvivere, sfamarsi, ripararsi, puntare all'obiettivo).

const PRIORITA_INV := {"pala": 7.0, "coltello": 6.5, "corda": 6.5, "fuoco": 6.5, "pentola": 5.5, "medicina": 5.0, "mappa": 4.5,
	"mattoni": 4.5, "letto": 3.5, "diga": 4.0, "cantina": 4.0, "lancia": 5.0, "arco": 5.0, "fionda": 4.5, "cesto": 3.5,
	"sacco": 3.5, "laccio": 4.0, "focolare": 4.0, "fossato": 3.5, "muro": 3.5, "scorciatoia": 3.5, "recinto": 3.5,
	"zattera": 3.0, "scudo": 3.0, "lanterna": 3.0, "cinture": 3.0, "fornace": 3.5, "diario": 3.0, "tamburi": 3.0, "fossa": 3.0,
	"accetta": 4.5, "albero_maestro": 6.0, "campana": 3.0, "croce": 9.0, "zattera_jenny": 9.0, "scialuppa": 10.0,
	"scala_corda": 4.0, "lancia_bordo": 10.0, "balista": 6.0, "canoa": 3.0, "staccionata": 4.0, "orto": 5.0}


var ritardo := 0.0


func decide(m: Motore, posto: int, req: Dictionary):
	if m.is_inside_tree():
		if ritardo > 0.0:
			await m.get_tree().create_timer(ritardo).timeout
		else:
			await m.get_tree().process_frame
	return scegli(m, posto, req)


func scegli(m: Motore, posto: int, req: Dictionary) -> int:
	var opz: Array = req.get("opzioni", [])
	if opz.size() <= 1:
		return 0
	var i := int(req.get("pg", m.primo))
	match req.get("tipo", ""):
		"piazza":
			return _piazza(m, i, opz)
		"morale":
			return 1 if int(m.pg[i]["ferite"]) >= 3 else 0
		"combattimento":
			var forza := 0
			var t: String = req.get("testo", "")
			var rx := RegEx.new()
			rx.compile("Forza del nemico (\\d+), livello dell'arma (\\d+)")
			var mm := rx.search(t)
			if mm:
				var danno := int(mm.get_string(1)) - int(mm.get_string(2))
				var resta := m.max_ferite(i) - int(m.pg[i]["ferite"])
				if danno >= 2 or danno >= resta:
					for k in range(1, opz.size()):
						if not "ferita" in opz[k]["testo"] or danno >= 3:
							return k
			return 0
		"rilancio":
			for k in opz.size():
				if opz[k].get("d", "") == "successo":
					return k
			return 0
		"libero":
			return _libero(m, i, opz)
		"cure":
			return 1 if opz.size() > 1 else 0
		"cura", "cibo":
			var best := 0
			var bv := -99.0
			for k in opz.size():
				var j := int(opz[k].get("i", -1))
				var v := 0.0
				if j >= 0:
					v = float(m.pg[j]["ferite"]) / float(m.max_ferite(j))
					if m.pg[j]["tipo"] == "venerdi":
						v -= 0.3
				else:
					v = float(m.jenny.get("ferite", 0)) / float(max(1, int(m.jenny.get("max", 11))))
				if req["tipo"] == "cibo":
					v = v
				if v > bv:
					bv = v
					best = k
			return best
		"campo":
			return _campo(m, opz, req)
		"decidi":
			return _decidi(m, i, opz)
		"meteo":
			return 1 if opz.size() > 1 else 0
		"misteri":
			return 1 if int(m.pg[i]["ferite"]) * 2 >= m.max_ferite(i) else 0
		"pira":
			if not m.rifugio_presente() or (float(m.tetto) < _nuvole_attese(m) and m.round < 9):
				return 0
			var riserva := 0 if m.round >= 8 else 2
			var best4 := 0
			for k in opz.size():
				if int(opz[k].get("n", 0)) <= m.disponibili("legno") - riserva:
					best4 = k
			return best4
		"invenzione":
			var best2 := 0
			var bv2 := -1.0
			for k in opz.size():
				var id := int(opz[k].get("id", 0))
				var v2: float = PRIORITA_INV.get(m.C.get(id, {}).get("k", ""), 2.0)
				if v2 > bv2:
					bv2 = v2
					best2 = k
			return best2
		"livello":
			var best3 := 0
			for k in opz.size():
				var tt: String = opz[k].get("t", "")
				if "+" in opz[k]["testo"]:
					if tt == "tetto" and m.tetto <= m.palizzata:
						best3 = k
					elif tt == "palizzata" and m.palizzata < m.tetto:
						best3 = k
				else:
					if int(m.get(tt)) >= int(m.get(opz[best3].get("t", "tetto"))):
						best3 = k
			return best3
		"piano", "conferma_piano":
			return 0
		"sistemare":
			return 1 if m.morale < 0 else 0
		"casella":
			return _casella(m, opz, req)
	return 0


func _decidi(m: Motore, i: int, opz: Array) -> int:
	var best := 0
	var bv := -99.0
	for k in opz.size():
		var t: String = opz[k]["testo"].to_lower()
		var v := 0.0
		if "prendi" in t or "pesca" in t or "cura" in t or "+1" in t or "costruisci" in t:
			v += 2.0
		if "ferit" in t:
			v -= 1.5 if int(m.pg[i]["ferite"]) < m.max_ferite(i) - 3 else 4.0
		if "mescola" in t:
			v -= 0.6
		if "notte fuori" in t:
			v -= 1.0
		if "scarta questa carta" in t and not "e passa" in t:
			v += 0.1
		if "ogni personaggio" in t:
			v -= 2.0
		if v > bv:
			bv = v
			best = k
	return best


func _campo(m: Motore, opz: Array, req: Dictionary) -> int:
	var best := 0
	var bv := -99.0
	var qui := _valore_tessera(m, m.campo)
	for k in opz.size():
		var c := int(opz[k].get("k", -1))
		var v := 0.0
		if c < 0:
			v = qui + 1.0
		else:
			v = _valore_tessera(m, c) - float(m.tetto + m.palizzata) * 0.6
			if m.rifugio:
				v += float(m.tetto + m.palizzata) * 0.3
		if v > bv:
			bv = v
			best = k
	return best


func _valore_tessera(m: Motore, k: int) -> float:
	var t := m.tessera(k)
	var c: Dictionary = m.isola[k]
	var v := 0.0
	if t.get("cibo", "") != "" and not c["esauriti"]["cibo"]:
		v += 2.5
		if "cibo_extra" in c["gettoni"]:
			v += 1.0
	if t.get("legno", false) and not c["esauriti"]["legno"]:
		v += 1.2
	if t.get("rifugio", false) and not m.rifugio:
		v += 3.0
	if c["nebbia"]:
		v -= 2.5
	return v


func _casella(m: Motore, opz: Array, req: Dictionary) -> int:
	# per le cose brutte (nebbia, cenere, fonti esaurite, tessere capovolte) la casella più lontana dal campo
	var titolo: String = req.get("titolo", "")
	var buona := titolo in ["Fonte ritrovata", "Via la nebbia", "Togli un segnalino nero"]
	var best := 0
	var bv := -99.0
	for k in opz.size():
		var c := int(opz[k].get("k", opz[k].get("casella", -1)))
		var d := m.distanza(c) if c >= 0 else 0
		var v := float(d)
		if buona:
			v = -v
		if v > bv:
			bv = v
			best = k
	return best


func _libero(m: Motore, i: int, opz: Array) -> int:
	var cibo_serve := 0
	for j in m.vivi():
		if m.pg[j]["tipo"] != "venerdi":
			cibo_serve += 1
	for k in opz.size():
		var a: String = opz[k].get("a", "")
		match a:
			"zuppa":
				if m.cibo_totale() < cibo_serve:
					return k
			"discorso":
				if m.morale < 0:
					return k
			"difesa_arma":
				if int(m.pg[i]["det"]) >= 6 and m.arma < 3:
					return k
			"difesa_pal":
				if int(m.pg[i]["det"]) >= 6 and m.palizzata < 2:
					return k
			"caccia":
				if int(m.pg[i]["det"]) >= 7 and m.arma >= 3:
					return k
			"ricetta":
				if int(m.pg[i]["ferite"]) >= 4 and m.cibo_totale() > cibo_serve:
					return k
			"scop":
				var s: String = opz[k].get("s", "")
				if s in ["machete", "machete_c", "sciabola", "veleno", "rovi", "liane", "capra", "tesoro", "medaglione", "olio", "fiale", "erbe_curative", "semi", "capanna", "attrezzi_vecchi"]:
					return k
				if s in ["tabacco", "erbe"] and m.morale < 3:
					return k
			"ogg":
				var id := int(opz[k].get("id", 0))
				if id == 605 and int(m.pg[i]["det"]) < 2:
					return k
	return 0


func _piazza(m: Motore, i: int, opz: Array) -> int:
	var best := 0
	var bv := -999.0
	for k in opz.size():
		var v := valore_piazzamento(m, i, opz[k])
		if v > bv:
			bv = v
			best = k
	return best


func valore_piazzamento(m: Motore, i: int, o: Dictionary) -> float:
	var op: String = o.get("op", "")
	if op == "annulla":
		return -50.0
	if op == "riposa_venerdi":
		return 0.5
	var ferite := int(m.pg[i]["ferite"])
	var maxf := m.max_ferite(i)
	var critico := ferite >= maxf - 3
	if op == "aiuta":
		for a in m.piano:
			if a["id"] == int(o["piano"]):
				if Azioni.new(m, m.E).pedine_totali(a) < int(a["min"]):
					return 9.0
				return 2.5 + _valore_azione(m, i, a) * 0.3
		return 0.0
	var v := _valore_azione(m, i, o)
	var tot := int(o.get("tot", 1))
	var mie := int(o.get("mie", 1))
	var con_dadi: bool = o["tipo"] in ["costruire", "raccogliere", "esplorare"] and tot < int(o.get("auto", tot))
	if con_dadi:
		v *= 0.72
		if critico:
			v -= 3.0
		if o["tipo"] == "costruire":
			v -= 0.6
	v -= 1.1 * float(mie - 1)
	if "serve aiuto" in o.get("testo", ""):
		v -= 2.5
	return v


func _cibo_atteso(m: Motore) -> int:
	var c := m.cibo_totale() + int(m.fut.get("cibo", 0)) + int(m.fut.get("cibo_np", 0))
	for a in m.piano:
		if a["tipo"] == "raccogliere" and a.get("risorsa", "") == "cibo":
			c += 1
		if a["tipo"] == "caccia":
			c += 2
	return c


func _legno_atteso(m: Motore) -> int:
	var c := m.disponibili("legno")
	for a in m.piano:
		if a["tipo"] == "raccogliere" and a.get("risorsa", "") == "legno":
			c += 1
	return c


func _valore_azione(m: Motore, i: int, o: Dictionary) -> float:
	var bocche := 0
	for j in m.vivi():
		if m.pg[j]["tipo"] != "venerdi":
			bocche += 1
	if m.scenario == 3 and m.jenny.get("salvata", false):
		bocche += 1
	var tipo: String = o["tipo"]
	match tipo:
		"minaccia":
			var id := int(o["bers"])
			var c: Dictionary = m.C[id]
			if c["tipo"] == "relitto":
				return 5.0 + float(o.get("var", 0)) * 0.5
			var slot: int = m.minacce.find(id)
			var danno := float(_danno_minaccia(c))
			return 2.0 + danno * (1.6 if slot == 0 else 0.8)
		"caccia":
			if o.get("speciale", "") != "":
				var forza := Scenari.forza_villaggio(m) if o["speciale"] == "villaggio" else 21 - 3 * m.villaggi_bruciati
				return 9.0 - float(max(0, forza - m.arma)) * 2.0
			var v := 3.0 if m.arma >= 4 else (1.5 if m.arma >= 2 else -0.5)
			var deficit2 := bocche - _cibo_atteso(m)
			if deficit2 > 0:
				v += 2.0 + 1.2 * float(deficit2)
			return v
		"costruire":
			match str(o["bers"]):
				"rifugio":
					return 9.5 if not m.rifugio_presente() else 4.0
				"tetto":
					var attese := _nuvole_attese(m)
					var manca := attese - float(m.tetto)
					return 2.0 + clampf(manca, 0.0, 3.0) * 2.2
				"palizzata":
					return 2.5 - float(m.palizzata) * 0.6 + (2.0 if "tempesta" in m.meteo else 0.0)
				"arma":
					return 4.0 - float(m.arma) * 0.9 + (1.0 if m.mazzo_caccia.size() > 0 else 0.0)
			var cid := int(o["bers"])
			var k: String = m.C[cid].get("k", "")
			var p: float = PRIORITA_INV.get(k, 2.5)
			if m.scenario == 6 and cid in m.inv_obiettivo:
				p += 3.0
			if m.scenario == 1 and k == "fuoco":
				p += 2.0
			if k == "croce":
				p = (4.0 if m.round <= 3 else 8.5) - float(m.distanza(int(o.get("casella", m.campo)))) * 0.5
			if p >= 9.0 and m.round <= 2 and not k in ["scialuppa", "lancia_bordo"]:
				p = 6.0
			return p
		"raccogliere":
			if o.get("risorsa", "") == "cibo":
				var deficit := bocche - _cibo_atteso(m)
				return 7.0 + 1.8 * float(deficit) if deficit > 0 else 2.0
			var serve := 1
			var costo := int(Azioni.new(m, m.E).costo_rifugio()[0]["legno"])
			if not m.rifugio_presente():
				serve += costo
			if float(m.tetto) < _nuvole_attese(m):
				serve += costo
			if m.scenario == 1 and m.round >= 6:
				serve += 3
			var mancante := serve - _legno_atteso(m)
			return 5.0 + float(mancante) * 0.8 if mancante > 0 else 1.5
		"esplorare":
			if o.get("speciale", "") != "":
				match o["speciale"]:
					"jenny":
						return 10.0
					"tempio":
						return 3.0
					"mappa_tesoro":
						return 3.5
					_:
						return 8.0
			var esplorate := 0
			for c in m.isola:
				if int(c["tessera"]) >= 0:
					esplorate += 1
			var base := 6.0 if m.round <= 3 and esplorate < 5 else (3.5 if esplorate < 6 else 2.0)
			if m.scenario == 4:
				base += 3.0
			return base - float(m.distanza(int(o["bers"])) - 1) * 1.5
		"sistemare":
			return 5.5 if m.morale < 0 else (2.5 if m.morale < 2 else 1.2)
		"riposo":
			var f := int(m.pg[i]["ferite"])
			var mx := m.max_ferite(i)
			if f >= mx - 3:
				return 8.5
			if f * 2 >= mx:
				return 4.0
			return 0.2 if f > 0 else -1.0
	return 0.0


## Nuvole che ci si aspetta nei prossimi round (dadi dello scenario e gettoni già nello spazio Meteo).
func _nuvole_attese(m: Motore) -> float:
	var mx := 0.0
	var save := m.round
	for r in range(m.round, m.round + 3):
		m.round = r
		var n := 0.0
		for d in Scenari.dadi_meteo(m):
			if d == "pioggia":
				n += 1.3
			elif d == "neve":
				n += 1.7
		if r == save:
			for g in m.meteo:
				if g in ["pioggia", "neve"]:
					n += 1.0
		mx = max(mx, n)
	m.round = save
	return mx


func _danno_minaccia(c: Dictionary) -> int:
	var d := 0
	for op in c.get("mn", []):
		match op[0]:
			"ferita":
				d += 3
			"morale":
				d += 2 * abs(int(op[1]))
			"meteo", "liv", "esaurisci", "prod", "rovescia_inv", "scarta_inv", "liv_scelta", "liv_meta", "gettone", "avv":
				d += 2
			"det":
				d += 1
			_:
				d += 1
	return d
