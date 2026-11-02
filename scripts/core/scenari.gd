class_name Scenari
extends RefCounted
## Regole speciali dei sei scenari del gioco base.


static func _log(m: Motore, t: String) -> void:
	m._log(t)


# =====================================================================================
# METEO, INIZIO E FINE ROUND
# =====================================================================================

static func dadi_meteo(m: Motore) -> Array:
	var r := []
	var met: Dictionary = m.S.get("meteo", {})
	for intervallo in met:
		var p: PackedStringArray = str(intervallo).split("-")
		var a := int(p[0])
		var b := int(p[1]) if p.size() > 1 else a
		if m.round >= a and m.round <= b:
			for d in met[intervallo]:
				if not d in r:
					r.append(d)
	return r


static func inizio_round(m: Motore, E: Effetti) -> void:
	match m.scenario:
		4:
			var lava: Dictionary = m.S.get("lava", {})
			for k in lava.get(str(m.round), []):
				var kk := int(k)
				if kk == m.PARTENZA:
					pass
				_log(m, "La lava raggiunge la casella %d." % (kk + 1))
				m.isola[kk]["lava"] = true
				m.isola[kk]["giu"] = true
				m.isola[kk]["gettoni"] = []
				m.isola[kk]["nebbia"] = false
				m.isola[kk]["cenere"] = false
				if m.isola[kk]["tessera"] < 0:
					m.isola[kk]["tessera"] = -2
				if kk == m.campo:
					m._fine("sconfitta", "La lava ha travolto il campo.")
					return
			# la tessera di partenza è la casella 5 (indice 4) nello schema dello scenario
		5:
			if m.round == 4 and m.isola[10].get("coperta", false):
				m.isola[10]["coperta"] = false
				m.isola[10]["numero"] = 6
				_log(m, "Appare la Città dei cannibali (tessera 4)!")
				m.evento.emit("tessera", {"k": 10, "n": 4})


static func fine_round(m: Motore, E: Effetti) -> void:
	match m.scenario:
		2:
			if m.croci.size() >= 5:
				m._fine("vittoria", "Cinque croci si ergono sull'isola: la maledizione è spezzata!")
		5:
			if m.citta_distrutta:
				m._fine("vittoria", "La città dei cannibali è in fiamme: siete salvi!")
		6:
			var ok := m.rifugio and m.tetto >= 1 and m.palizzata >= 1 and m.arma >= 1
			for id in m.inv_obiettivo:
				if not m.costruite.has(int(id)):
					ok = false
			if ok:
				m._fine("vittoria", "La famiglia Robinson ha costruito la sua casa sull'isola!")


# =====================================================================================
# LIBRO E TOTEM
# =====================================================================================

static func libro(m: Motore, E: Effetti, ctx: Dictionary) -> void:
	match m.scenario:
		1:
			_log(m, "Libro: nessun effetto in questo scenario.")
		2:
			_log(m, "Nebbia misteriosa: due segnalini nebbia.")
			await _metti_segnalini(m, "nebbia", 2)
		3:
			_log(m, "Tempesta: la palizzata perde un livello.")
			if m.palizzata > 0:
				m.palizzata -= 1
			else:
				for i in m.vivi():
					if m.pg[i]["tipo"] != "venerdi":
						m.ferisci(i, 1, "tempesta")
		4:
			_log(m, "Eruzione: due segnalini cenere.")
			await _metti_segnalini(m, "cenere", 2)
		5:
			await attacco_cannibali(m, E)
		6:
			_log(m, "Raccolto scarso: la produzione di questo round si dimezza.")
			m.prod["meta"] = true


static func _metti_segnalini(m: Motore, tipo: String, n: int) -> void:
	for x in n:
		var opz := []
		for k in m.isola.size():
			var c: Dictionary = m.isola[k]
			if k == 10 and m.scenario != 5:
				continue
			if c[tipo] if c.has(tipo) else false:
				continue
			if c.get("vulcano", false):
				continue
			if tipo == "nebbia" and c["giu"]:
				continue
			opz.append({"testo": "Casella %d%s" % [k + 1, (" (tessera %d)" % int(c["tessera"])) if c["tessera"] >= 0 else " (inesplorata)"], "k": k, "casella": k})
		if opz.is_empty():
			return
		var r = await m.chiedi(m.capo(), {"tipo": "casella", "titolo": "Nebbia" if tipo == "nebbia" else "Cenere",
			"testo": "Dove metti il segnalino (%d di %d)? Le azioni lì richiedono una pedina in più." % [x + 1, n], "opzioni": opz})
		m.isola[opz[r]["k"]][tipo] = true


static func attacco_cannibali(m: Motore, E: Effetti) -> void:
	var n: int = max(0, 3 - m.villaggi_bruciati)
	_log(m, "I cannibali attaccano: %d ferite a testa." % n)
	if n > 0:
		m.ferisci_tutti(n, "cannibali")
	if m.esito != "":
		return
	var opz := []
	for k in m.vicini(m.campo):
		if campo_ammesso(m, k):
			opz.append({"testo": "Sposta il campo sulla tessera %d" % int(m.isola[k]["tessera"]), "k": k, "casella": k})
	if m.rifugio:
		opz.append({"testo": "Perdi rifugio, tetto e palizzata", "k": -1})
	else:
		opz.append({"testo": "Ogni personaggio subisce 2 ferite", "k": -2})
	var r = await m.chiedi(m.capo(), {"tipo": "campo", "titolo": "Attacco dei cannibali", "testo": "Il campo va spostato, altrimenti...", "opzioni": opz})
	var k2: int = opz[r]["k"]
	if k2 >= 0:
		E.sposta_campo(k2)
	elif k2 == -1:
		m.rifugio = false
		m.tetto = 0
		m.palizzata = 0
		_log(m, "Il rifugio è distrutto.")
	else:
		m.ferisci_tutti(2, "cannibali")


static func totem(m: Motore, E: Effetti, k: int, i: int) -> void:
	m.totem_contati += 1
	var n := m.totem_contati
	match m.scenario:
		2:
			if n == 1:
				m.isola[k]["numero"] = 1
				_log(m, "Il Tempio oscuro: si potrà esplorare una volta per pescare carte Mistero.")
			elif n == 2:
				_log(m, "L'Altare della morte: %s subisce 2 ferite." % m.pg[i]["nome"])
				m.ferisci(i, 2, "altare")
			else:
				_log(m, "Un nascondiglio dei cultisti: la nebbia avvolge la tessera.")
				m.isola[k]["nebbia"] = true
		3:
			m.isola[k]["numero"] = n
			match n:
				1:
					_log(m, "Rocce scivolose: %s subisce 2 ferite." % m.pg[i]["nome"])
					m.ferisci(i, 2, "rocce")
				2:
					_log(m, "Il cimitero: il morale scende di 2.")
					m.cambia_morale(-2)
				3:
					_log(m, "Resti di alberi e pennoni: la Corda è pronta.")
					var id := m.id_inv("corda")
					if not m.costruite.has(id):
						m.inv_fut.append(id)
				4:
					_log(m, "Il relitto del pallone: +2 pellicce.")
					m.guadagna("pelliccia", 2, i)
		4:
			if n <= 4:
				m.isola[k]["numero"] = n
				_log(m, "Un luogo speciale da esplorare: %s." % nome_luogo(m, "luogo%d" % n, k))
		5:
			if n <= 4:
				m.isola[k]["numero"] = n
				_log(m, "Un villaggio dei cannibali!")
				if n == 4:
					m.ferisci(i, 1 if m.ha("medicina") else 3, "villaggio")
				else:
					m.ferisci(i, 1, "villaggio")
				if n >= 2 and m.esito == "":
					var opz := []
					if m.disponibili("legno") > 0:
						opz.append({"testo": "Scarta 1 legno", "r": "legno"})
					if m.cibo_totale() > 0:
						opz.append({"testo": "Scarta 1 cibo", "r": "cibo"})
					if not opz.is_empty():
						var r = await m.chiedi(m.capo(), {"tipo": "risorsa", "titolo": "I cannibali attaccano il campo", "testo": "Che cosa perdete?", "opzioni": opz})
						m.scarta_ris(opz[r]["r"], 1, -1, true)
			else:
				_log(m, "Altri segni dei cannibali: la loro forza cresce.")
		6:
			var ter: String = m.tessera(k).get("terreno", "")
			var primo := true
			for j in m.isola.size():
				if j != k and m.isola[j]["tessera"] >= 0 and not m.isola[j]["giu"] and m.tessera(j).get("terreno", "") == ter:
					primo = false
			if primo:
				m.isola[k]["terreno_coperto"] = true
				_log(m, "Terra desolata: il terreno %s resta inesplorato." % ter)


static func tessera_piazzata(m: Motore, E: Effetti, k: int, i: int) -> void:
	if m.scenario == 4:
		m.esplorazioni_vulcano += 1


# =====================================================================================
# COSTRUZIONI
# =====================================================================================

static func costruibile(m: Motore, id: int) -> bool:
	var k: String = m.C[id].get("k", "")
	match k:
		"scialuppa":
			return m.jenny.get("salvata", false)
		"zattera_jenny":
			return not m.jenny.get("salvata", false)
		"lancia_bordo":
			return obiettivo_vulcano(m)
	return true


static func obiettivo_vulcano(m: Motore) -> bool:
	var ng := str(clampi(m.n_giocatori(), 1, 4))
	var serve_e := int(m.S.get("esplora", {}).get(ng, 6))
	var serve_t := int(m.S.get("totem_obiettivo", {}).get(ng, 3))
	return m.esplorazioni_vulcano >= serve_e and m.luoghi_speciali.size() >= serve_t


static func caselle_costruzione(m: Motore, id: int) -> Array:
	if m.C[id].get("k", "") != "croce":
		return [-1]
	var r := []
	for k in m.isola.size():
		if m.esplorata(k) and not m.isola[k]["croce"] and m.distanza(k) >= 0:
			r.append(k)
	return r


static func costruito_subito(m: Motore, E: Effetti, id: int, a: Dictionary, i: int) -> bool:
	match m.C[id].get("k", ""):
		"croce":
			var k := int(a.get("casella", m.campo))
			m.isola[k]["croce"] = true
			m.croci.append(k)
			_log(m, "Una croce sulla tessera %d (%d di 5)." % [int(m.isola[k]["tessera"]), m.croci.size()])
			m.evento.emit("costruito", {"cosa": "croce", "k": k})
			return true
	return false


static func oggetto_costruito(m: Motore, E: Effetti, id: int) -> void:
	controlla_naufraghi(m)


static func metti_pira(m: Motore, n: int, forzato := false) -> void:
	if m.scenario != 1:
		return
	var cap: Array = m.S.get("pira", [1, 2, 3, 4, 5])
	for c in cap.size():
		if int(m.pira[c]) < int(cap[c]):
			var spazio: int = int(cap[c]) - int(m.pira[c])
			var metti: int = min(spazio, n)
			m.pira[c] = int(m.pira[c]) + metti
			_log(m, "%d legno sulla pira (colonna %d: %d/%d)." % [metti, c + 1, m.pira[c], cap[c]])
			if not forzato:
				m.pira_round = m.round
			break
	controlla_naufraghi(m)


static func pira_completa(m: Motore) -> bool:
	var cap: Array = m.S.get("pira", [1, 2, 3, 4, 5])
	for c in cap.size():
		if int(m.pira[c]) < int(cap[c]):
			return false
	return true


static func controlla_naufraghi(m: Motore) -> void:
	if m.scenario == 1 and pira_completa(m) and m.ha("fuoco") and m.round >= 10:
		m._fine("vittoria", "La nave vede il fuoco della pira: siete salvi!")


## Prima della fase Azione (Naufraghi: si può mettere legno sulla pira).
static func prima_azione(m: Motore, E: Effetti) -> void:
	if m.scenario != 1 or pira_completa(m) or m.pira_round == m.round:
		return
	var cap: Array = m.S.get("pira", [1, 2, 3, 4, 5])
	var col := 0
	while col < cap.size() and int(m.pira[col]) >= int(cap[col]):
		col += 1
	var spazio: int = int(cap[col]) - int(m.pira[col])
	var max_l: int = min(spazio, m.disponibili("legno"))
	if max_l <= 0:
		return
	var opz := [{"testo": "Nessun legno sulla pira", "n": 0}]
	for n in range(1, max_l + 1):
		opz.append({"testo": "Metti %d legno sulla pira (colonna %d)" % [n, col + 1], "n": n})
	var r = await m.chiedi(m.capo(), {"tipo": "pira", "titolo": "La pira di legna", "testo": "Colonna %d: %d di %d legni." % [col + 1, m.pira[col], cap[col]], "opzioni": opz})
	var n2: int = opz[r]["n"]
	if n2 > 0:
		m.ris["legno"] -= n2
		metti_pira(m, n2)
	controlla_naufraghi(m)


# =====================================================================================
# CACCE ED ESPLORAZIONI SPECIALI
# =====================================================================================

static func villaggio_attivo(m: Motore, k: int) -> bool:
	if m.scenario != 5 or k < 0:
		return false
	var c: Dictionary = m.isola[k]
	var nn := int(c.get("numero", 0))
	return ((nn >= 1 and nn <= 4) or nn == 6) and not c["bruciato"] and m.esplorata(k)


static func campo_ammesso(m: Motore, k: int) -> bool:
	if not m.esplorata(k) or m.isola[k].get("vulcano", false):
		return false
	if villaggio_attivo(m, k):
		return false
	return true


static func forza_villaggio(m: Motore) -> int:
	var totem := 0
	for k in m.isola.size():
		var c: Dictionary = m.isola[k]
		if m.esplorata(k) and m.tessera(k).get("totem", false) and not c["bruciato"]:
			totem += 1
	return 4 + totem


static func cacce_speciali(m: Motore) -> Array:
	var r := []
	if m.scenario != 5:
		return r
	for k in m.isola.size():
		if villaggio_attivo(m, k) and m.distanza(k) >= 0:
			r.append({"bers": k, "speciale": "citta" if int(m.isola[k]["numero"]) == 6 else "villaggio"})
	return r


static func caccia_speciale(m: Motore, E: Effetti, a: Dictionary, i: int) -> void:
	var k := int(a["bers"])
	var citta: bool = a["speciale"] == "citta"
	var forza := 21 - 3 * m.villaggi_bruciati if citta else forza_villaggio(m)
	await E.combatti(i, {"forza": forza, "nome": "la città dei cannibali" if citta else "il villaggio dei cannibali"}, {"chi": i})
	if m.esito != "":
		return
	m.isola[k]["bruciato"] = true
	if citta:
		m.citta_distrutta = true
		_log(m, "La città dei cannibali brucia! Sopravvivete fino alla fine del round.")
	else:
		m.villaggi_bruciati += 1
		_log(m, "Il villaggio brucia (%d bruciati)." % m.villaggi_bruciati)


static func luoghi_esplorabili(m: Motore) -> Array:
	var r := []
	match m.scenario:
		2:
			for k in m.isola.size():
				if int(m.isola[k].get("numero", 0)) == 1 and not m.isola[k].get("visitato", false) and m.esplorata(k) and m.distanza(k) >= 0:
					r.append({"k": k, "speciale": "tempio"})
		3:
			if m.ha("zattera_jenny") and not m.jenny.get("salvata", false):
				r.append({"k": m.campo, "speciale": "jenny"})
		4:
			for k in m.isola.size():
				var nn := int(m.isola[k].get("numero", 0))
				if nn >= 1 and nn <= 4 and not m.isola[k].get("visitato", false) and m.esplorata(k) and m.distanza(k) >= 0:
					r.append({"k": k, "speciale": "luogo%d" % nn})
	if m.ha_tesoro(532):
		r.append({"k": m.campo, "speciale": "mappa_tesoro", "esatte": 2})
	return r


static func nome_luogo(m: Motore, s: String, k: int) -> String:
	match s:
		"tempio": return "il Tempio oscuro"
		"jenny": return "salvare Jenny con la zattera"
		"luogo1": return "il Piccolo tempio"
		"luogo2": return "il Villaggio in rovina"
		"luogo3": return "la Grotta nascosta"
		"luogo4": return "il Tempio sotterraneo"
		"mappa_tesoro": return "seguire la Mappa del tesoro"
	return s


static func esplora_luogo(m: Motore, E: Effetti, a: Dictionary, i: int) -> void:
	var k := int(a["bers"])
	var s: String = a["speciale"]
	match s:
		"tempio":
			m.isola[k]["visitato"] = true
			_log(m, "%s entra nel Tempio oscuro." % m.pg[i]["nome"])
			await E.pesca_misteri(i, {"tesoro": 3, "creatura": 1})
		"jenny":
			m.jenny["salvata"] = true
			_log(m, "Jenny è salva e arriva al campo!")
			m.evento.emit("jenny", {})
		"luogo1", "luogo2", "luogo3", "luogo4":
			m.isola[k]["visitato"] = true
			var n: int = {"luogo1": 3, "luogo2": 4, "luogo3": 4, "luogo4": 5}[s]
			if "vecchia_mappa" in m.scop:
				var r = await m.chiedi_pg(i, {"tipo": "scoperta", "titolo": "Vecchia mappa", "testo": "Usi la vecchia mappa per pescare una carta in meno?", "opzioni": [{"testo": "Sì"}, {"testo": "No"}]})
				if r == 0:
					m.scop.erase("vecchia_mappa")
					n -= 1
			_log(m, "%s esplora %s (%d carte Mistero)." % [m.pg[i]["nome"], nome_luogo(m, s, k), n])
			await E.pesca_misteri(i, {"totale": n}, true)
			m.luoghi_speciali.append(k)
		"mappa_tesoro":
			for t in m.tesori:
				if int(t["id"]) == 532:
					m.tesori.erase(t)
					break
			await E.pesca_misteri(i, {"tesoro": 2}, true)


# =====================================================================================
# NOTTE
# =====================================================================================

static func notte_cibo(m: Motore, E: Effetti) -> void:
	if m.scenario != 6:
		return
	var f := int(m.S.get("figli", {}).get(str(m.round), 0))
	if f <= 0:
		return
	_log(m, "I figli devono mangiare: %d cibo." % f)
	if m.cibo_totale() < f:
		m.scarta_ris("cibo", m.cibo_totale(), -1, true)
		m._fine("sconfitta", "Non c'è cibo per i bambini.")
		return
	m.scarta_ris("cibo", f)


static func notte(m: Motore, E: Effetti) -> void:
	if m.scenario == 3 and not m.jenny.get("salvata", false):
		m.ferisci_jenny(2)
