class_name Effetti
extends RefCounted
## Fasi del round (Evento, Morale, Produzione, Meteo, Notte), interprete degli effetti delle carte,
## combattimenti, carte Mistero, usi liberi (abilità, oggetti, segnalini) e regole degli scenari.
## La fase Azione (pianificazione e risoluzione) sta in Azioni.

var m: Motore
var A: Azioni
var combattimento := false
var stop_misteri := false
var tesori_azione: Array = []


func _init(motore: Motore) -> void:
	m = motore
	A = Azioni.new(motore, self)


func _log(t: String) -> void:
	m._log(t)


# =====================================================================================
# INIZIO E FINE ROUND
# =====================================================================================

func momento_iniziale() -> void:
	m.cambiato.emit()


func inizio_round() -> void:
	# chi ha passato la notte fuori torna al campo con quello che ha trovato
	for i in m.pg.size():
		var p: Dictionary = m.pg[i]
		if p["fuori"]:
			p["fuori"] = false
			for t in p["fuori_ris"]:
				m.ris[t] += int(p["fuori_ris"][t])
			p["fuori_ris"] = {}
			_log("%s torna al campo." % p["nome"])
	var ops := m.inizio_round_ops.duplicate()
	m.inizio_round_ops = []
	for x in ops:
		await esegui(x["ops"], {"chi": int(x["chi"])})
	await Scenari.inizio_round(m, self)


func fine_round() -> void:
	m.fase = "fine_round"
	for p in m.pg:
		p["usate"] = {}
		p["vincoli"] = {}
	await Scenari.fine_round(m, self)
	if m.esito != "":
		return
	if m.round >= int(m.S.get("round", 12)):
		m._fine("sconfitta", "Il tempo è scaduto: l'obiettivo dello scenario non è stato raggiunto.")
		return
	m.round += 1
	# il segnalino primo giocatore passa al prossimo personaggio di un giocatore
	var gg := m.giocanti()
	if gg.size() > 0:
		var idx := gg.find(m.primo)
		m.primo = gg[(idx + 1) % gg.size()] if idx >= 0 else gg[0]
	m.cambiato.emit()


# =====================================================================================
# FASE EVENTO
# =====================================================================================

func fase_evento() -> void:
	if m.belva_eventi >= 0:
		var b := m.belva_eventi
		m.belva_eventi = -1
		_log("La belva della notte pericolosa attacca: %s." % m.nome_carta(b))
		await combatti(m.primo, belva_dati(b), {"chi": m.primo})
		if m.esito != "":
			return
	while not m.mazzo_eventi.is_empty() and m.esito == "":
		var e: Dictionary = m.mazzo_eventi.pop_back()
		var id := int(e["id"])
		var c: Dictionary = m.C[id]
		if c["tipo"] != "evento":
			_log("Dal mazzo Eventi: %s (%s)." % [c.get("ev_nome", c["nome"]), c["nome"]])
			m.evento.emit("carta", {"id": id, "lato": "evento"})
			await mostra(id, "evento", "Dal mazzo Eventi")
			var vit := int(e.get("vittima", -1))
			if vit < 0 or m.pg[vit]["morto"]:
				vit = m.primo
			await esegui(c.get("ev", []), {"chi": m.primo, "vittima": vit, "carta": id, "lato": "evento"})
			if c["tipo"] == "mistero" and not _rimescolata:
				m.scarti_misteri.append(id)
			_rimescolata = false
			continue
		_log("Evento: %s." % c["nome"])
		m.evento.emit("carta", {"id": id, "lato": "evento"})
		await mostra(id, "evento", "Evento")
		var sim: String = c.get("simbolo", "")
		if sim in ["costruire", "raccogliere", "esplorare"]:
			if not m.gettoni_avv[sim]:
				m.gettoni_avv[sim] = true
				_log("Segnalino Avventura sul mazzo %s." % sim.capitalize())
		elif sim == "libro":
			await libro({"chi": m.primo})
		if m.esito != "":
			return
		await esegui(c.get("ev", []), {"chi": m.primo, "carta": id, "lato": "evento"})
		if m.esito != "":
			return
		await spingi_minaccia(id)
		break


var _rimescolata := false


func spingi_minaccia(id: int) -> void:
	var uscita: int = m.minacce[0]
	m.minacce[0] = m.minacce[1]
	m.minacce[1] = id
	m.cambiato.emit()
	if uscita >= 0:
		var c: Dictionary = m.C[uscita]
		if c["tipo"] == "relitto":
			_log("Il relitto %s esce dal tabellone." % c["nome"])
		else:
			_log("Minaccia non affrontata: %s." % c["nome"])
			m.evento.emit("carta", {"id": uscita, "lato": "minaccia"})
			await esegui(c.get("mn", []), {"chi": m.primo, "carta": uscita, "lato": "minaccia"})


func libro(ctx: Dictionary) -> void:
	await Scenari.libro(m, self, ctx)


# =====================================================================================
# FASE MORALE E PRODUZIONE
# =====================================================================================

func fase_morale() -> void:
	if m.n_giocatori() == 1:
		m.cambia_morale(1, false)
	var p := m.primo
	var mo := m.morale
	if mo < 0:
		m.dai_det(p, mo)
	elif mo == 3:
		var r = await m.chiedi_pg(p, {"tipo": "morale", "titolo": "Morale alto", "testo": "Il morale è al massimo.",
			"opzioni": [{"testo": "Prendi 2 Determinazione"}, {"testo": "Guarisci 1 ferita"}]})
		if r == 1 and m.pg[p]["ferite"] > 0:
			m.cura(p, 1)
		else:
			m.dai_det(p, 2)
	elif mo > 0:
		m.dai_det(p, min(mo, 2))
	if m.ha("diario"):
		m.dai_det(p, 1)
	if m.ha("tamburi"):
		m.dai_det(p, 2)


func fase_produzione() -> void:
	if m.prod.get("nulla", false):
		_log("Nessuna produzione in questo round.")
		return
	var c: Dictionary = m.isola[m.campo]
	if c["nebbia"]:
		_log("La nebbia copre il campo: nessuna produzione.")
		return
	var t := m.tessera(m.campo)
	var legno := 0
	var cibo := 0
	var ignora_fonti: bool = m.scenario == 4 and int(c["tessera"]) == 10
	if t.get("legno", false) and not c["esauriti"]["legno"] and not ignora_fonti:
		legno += 1
		if "legno_extra" in c["gettoni"]:
			legno += 1
	elif "legno_extra" in c["gettoni"] and m.ha_tesoro(527):
		legno += 1
	if t.get("cibo", "") != "" and not c["esauriti"]["cibo"] and not ignora_fonti:
		cibo += 1
		if "cibo_extra" in c["gettoni"]:
			cibo += 1 + (c["gettoni"].count("cibo_extra") - 1 if m.scenario == 6 else 0)
	# Scorciatoia
	if m.ha("scorciatoia"):
		for k in m.isola.size():
			var s: Dictionary = m.isola[k]
			if "scorciatoia" in s["gettoni"] and not s["nebbia"] and m.esplorata(k):
				var tt := m.tessera(k)
				var opz := []
				if tt.get("legno", false) and not s["esauriti"]["legno"]:
					opz.append({"testo": "Scorciatoia: %d legno" % (2 if "legno_extra" in s["gettoni"] else 1), "r": "legno"})
				if tt.get("cibo", "") != "" and not s["esauriti"]["cibo"]:
					opz.append({"testo": "Scorciatoia: %d cibo" % (2 if "cibo_extra" in s["gettoni"] else 1), "r": "cibo"})
				if not opz.is_empty():
					var r = await m.chiedi(m.capo(), {"tipo": "produzione", "titolo": "Scorciatoia", "testo": "Quale risorsa prendi dalla scorciatoia?", "opzioni": opz})
					var rr: String = opz[r]["r"]
					var q := 2 if (rr + "_extra") in s["gettoni"] else 1
					if rr == "legno":
						legno += q
					else:
						cibo += q
					m.raccolti_round["%d_%s" % [k, rr]] = true
	# Fossa
	if m.ha("fossa") and not m.prod.get("no_cibo", false):
		if m.dado(Motore.DADI["costruire"]["ferita"]) == "f":
			cibo += 2
			_log("La fossa cattura qualcosa: +2 cibo.")
	if m.prod.get("no_cibo", false):
		cibo = 0
	if m.prod.get("no_legno", false):
		legno = 0
	if m.prod.get("piu_legno", false):
		legno += 1
	if m.prod.get("meno_cibo", false):
		cibo = max(0, cibo - 1)
	if m.prod.get("meta", false):
		var tot := int((legno + cibo) / 2)
		if tot < legno + cibo:
			var nl: int = min(legno, tot)
			if cibo > 0 and legno > 0 and tot > 0:
				var opz := []
				for x in range(0, tot + 1):
					if x <= legno and tot - x <= cibo:
						opz.append({"testo": "%d legno e %d cibo" % [x, tot - x], "l": x})
				var r = await m.chiedi(m.capo(), {"tipo": "produzione", "titolo": "Produzione dimezzata", "testo": "Si produce solo la metà delle risorse.", "opzioni": opz})
				nl = opz[r]["l"]
			legno = nl
			cibo = tot - nl
	if legno > 0:
		m.guadagna("legno", legno)
	if cibo > 0:
		m.guadagna("cibo", cibo)
	if legno == 0 and cibo == 0:
		_log("La tessera del campo non produce nulla.")


# =====================================================================================
# FASE AZIONE (vedi Azioni)
# =====================================================================================

func fase_azione() -> void:
	tesori_azione = []
	await Scenari.prima_azione(m, self)
	await usi_liberi_di_tutti("Prima di pianificare")
	if m.esito != "":
		return
	await A.pianifica()
	if m.esito != "":
		return
	await A.risolvi()
	if m.esito != "":
		return
	await fine_azione()


func fine_azione() -> void:
	m.fase = "fine_azione"
	for t in Motore.RISORSE:
		m.ris[t] += int(m.fut[t])
		m.fut[t] = 0
	for s in m.scop_fut:
		if s == "albero_caduto":
			m.guadagna("legno", 1)
		elif s == "larve":
			m.guadagna("cibo", 2)
		else:
			m.scop.append(s)
	m.scop_fut = []
	m.vincoli.erase("oggetti_via")
	var nuove := m.inv_fut.duplicate()
	m.inv_fut = []
	for id in nuove:
		await oggetto_costruito(int(id))
		if m.esito != "":
			return
	var tt := m.tesori_fut.duplicate()
	m.tesori_fut = []
	for x in tt:
		await risolvi_tesoro(int(x["id"]), int(x["chi"]))
		if m.esito != "":
			return
	m.neutre = {}
	m.piano = []
	m.cambiato.emit()


func oggetto_costruito(id: int) -> void:
	var c: Dictionary = m.C[id]
	m.costruite[id] = true
	if not id in m.invenzioni:
		m.invenzioni.append(id)
	for p in m.pg:
		if int(p.get("inv", 0)) == id:
			p["inv"] = 0
	_log("Nuovo oggetto: %s." % c["nome"])
	m.evento.emit("oggetto", {"id": id})
	await esegui(c.get("eff", []), {"chi": m.primo, "carta": id})
	await Scenari.oggetto_costruito(m, self, id)


func risolvi_tesoro(id: int, chi: int) -> void:
	var c: Dictionary = m.C[id]
	await esegui(c.get("top", []), {"chi": chi, "carta": id, "lato": "mistero"})


# =====================================================================================
# FASE METEO
# =====================================================================================

func fase_meteo() -> void:
	var dadi: Array = Scenari.dadi_meteo(m)
	var pioggia := 0
	var neve := 0
	var belve := []
	var esiti := []
	if not m.meteo_anticipato.is_empty():
		esiti = m.meteo_anticipato.duplicate()
		m.meteo_anticipato = []
	else:
		esiti = tira_meteo(dadi)
	for e in esiti:
		pioggia += int(e.get("p", 0))
		neve += int(e.get("n", 0))
		if e.has("b") and e["b"] != "":
			belve.append(e["b"])
	for g in m.meteo:
		match g:
			"pioggia":
				pioggia += 1
			"neve":
				neve += 1
			"dado_belve":
				if belve.is_empty() and not "belve" in dadi:
					var b = m.dado(Motore.DADO_BELVE)
					_log("Dado delle belve: %s." % nome_belve(b))
					if b != "":
						belve.append(b)
	if pioggia + neve == 0 and belve.is_empty() and not "tempesta" in m.meteo:
		m.meteo = []
		return
	m.evento.emit("meteo", {"pioggia": pioggia, "neve": neve, "belve": belve, "tempesta": "tempesta" in m.meteo})
	# protezioni
	if m.ha("fornace") and neve > 0:
		neve -= 1
		_log("La fornace scalda il campo: una nuvola di neve in meno.")
	if m.ha_tesoro(543) and neve > 0:
		neve -= 1
		pioggia += 1
	var r := await _protezioni_meteo(pioggia, neve)
	pioggia = r[0]
	neve = r[1]
	var chi_campo := []
	for i in m.vivi():
		if not m.pg[i]["fuori"] and m.pg[i]["tipo"] != "venerdi":
			chi_campo.append(i)
	if neve > 0:
		_log("Neve: servono %d legno per scaldarsi." % neve)
		var hanno: int = min(neve, m.disponibili("legno"))
		m.ris["legno"] -= hanno
		_ferite_meteo(neve - hanno, chi_campo)
	if m.esito != "":
		return
	var nuvole := pioggia + neve
	if nuvole > m.tetto:
		var scop: int = nuvole - m.tetto
		_log("Il tetto non basta: %d nuvole scoperte, si perdono cibo e legno." % scop)
		var mancano := 0
		for t in ["cibo", "legno"]:
			var serve := scop
			if t == "cibo":
				var a: int = min(serve, m.disponibili("cibo"))
				m.ris["cibo"] -= a
				var b: int = min(serve - a, m.disponibili("cibo_np"))
				m.ris["cibo_np"] -= b
				mancano += serve - a - b
			else:
				var a2: int = min(serve, m.disponibili("legno"))
				m.ris["legno"] -= a2
				mancano += serve - a2
		_ferite_meteo(mancano, chi_campo)
	if m.esito != "":
		return
	if m.scop.has("polvere_sparo") and not belve.is_empty():
		pass
	for b in belve:
		await _belve_meteo(b, chi_campo)
		if m.esito != "":
			return
	if "tempesta" in m.meteo:
		_log("Tempesta: la palizzata perde un livello.")
		if m.palizzata > 0:
			m.palizzata -= 1
		else:
			_ferite_meteo(1, chi_campo)
	m.meteo = []


func tira_meteo(dadi: Array) -> Array:
	var esiti := []
	for d in dadi:
		match d:
			"pioggia":
				var f: Dictionary = m.dado(Motore.DADO_PIOGGIA)
				esiti.append(f)
				_log("Dado della pioggia: %s." % _nome_nuvole(f))
			"neve":
				var f2: Dictionary = m.dado(Motore.DADO_NEVE)
				esiti.append(f2)
				_log("Dado dell'inverno: %s." % _nome_nuvole(f2))
			"belve":
				var b = m.dado(Motore.DADO_BELVE)
				esiti.append({"b": b})
				_log("Dado delle belve: %s." % nome_belve(b))
	return esiti


func _nome_nuvole(f: Dictionary) -> String:
	var t := []
	if f.has("p"):
		t.append("%d %s" % [f["p"], "nuvola di pioggia" if f["p"] == 1 else "nuvole di pioggia"])
	if f.has("n"):
		t.append("%d %s" % [f["n"], "nuvola di neve" if f["n"] == 1 else "nuvole di neve"])
	return ", ".join(t)


func nome_belve(b) -> String:
	match b:
		"belva": return "combattimento con una belva di forza 3"
		"cibo": return "scarta 1 cibo"
		"palizzata": return "-1 palizzata"
	return "nulla"


func _ferite_meteo(n: int, chi: Array) -> void:
	if n <= 0:
		return
	for i in chi:
		m.ferisci(i, n, "meteo")
		if m.esito != "":
			return
	if m.scenario == 3 and m.jenny.get("salvata", false):
		m.ferisci_jenny(n)


func _protezioni_meteo(pioggia: int, neve: int) -> Array:
	# segnalini, coperte, abilità del cuoco: si chiede al primo giocatore
	while pioggia + neve > 0:
		var opz := [{"testo": "Prosegui (%d pioggia, %d neve, tetto %d)" % [pioggia, neve, m.tetto], "a": ""}]
		if "foglie" in m.scop and pioggia > 0:
			opz.append({"testo": "Foglie larghe: ignora 1 nuvola di pioggia", "a": "foglie"})
		if "tela" in m.scop and pioggia + neve > 0:
			opz.append({"testo": "Vecchia tela: ignora 1 nuvola", "a": "tela"})
		for t in m.tesori:
			if int(t["id"]) == 548 and int(t.get("usi", 3)) > 0 and neve > 0:
				opz.append({"testo": "Coperte: ignora 1 nuvola di neve (%d usi)" % int(t.get("usi", 3)), "a": "coperte"})
		for i in m.vivi():
			if m.pg[i]["id"] == "cuoco" and int(m.pg[i]["det"]) >= 3 and not m.pg[i]["usate"].has("grappa") and not m.pg[i]["vincoli"].get("no_abilita", false):
				if pioggia > 0:
					opz.append({"testo": "Cuoco, Grappa (3 Det.): ignora 1 nuvola di pioggia", "a": "grappa_p", "i": i})
				if neve > 0:
					opz.append({"testo": "Cuoco, Grappa (3 Det.): 1 neve diventa pioggia", "a": "grappa_n", "i": i})
		if opz.size() == 1:
			break
		var r = await m.chiedi(m.capo(), {"tipo": "meteo", "titolo": "Meteo", "testo": "Nuvole: %d di pioggia e %d di neve. Il tetto protegge da %d." % [pioggia, neve, m.tetto], "opzioni": opz})
		var a: String = opz[r]["a"]
		match a:
			"":
				break
			"foglie":
				m.scop.erase("foglie")
				pioggia -= 1
			"tela":
				m.scop.erase("tela")
				if pioggia > 0:
					pioggia -= 1
				else:
					neve -= 1
			"coperte":
				for t in m.tesori:
					if int(t["id"]) == 548:
						t["usi"] = int(t.get("usi", 3)) - 1
						if t["usi"] <= 0:
							m.tesori.erase(t)
						break
				neve -= 1
			"grappa_p", "grappa_n":
				var i: int = opz[r]["i"]
				m.pg[i]["det"] -= 3
				m.pg[i]["usate"]["grappa"] = true
				if a == "grappa_p":
					pioggia -= 1
				else:
					neve -= 1
					pioggia += 1
	return [pioggia, neve]


func _belve_meteo(b: String, chi: Array) -> void:
	match b:
		"belva":
			var bonus := await bonus_arma(m.primo, 3, {"meteo": true})
			var d: int = max(0, 3 - (m.arma + bonus))
			_log("Una belva attacca il campo (forza 3, arma %d)." % (m.arma + bonus))
			_ferite_meteo(d, chi)
		"cibo":
			if m.cibo_totale() > 0:
				m.scarta_ris("cibo", 1, -1)
			else:
				_ferite_meteo(1, chi)
		"palizzata":
			if m.palizzata > 0:
				m.palizzata -= 1
				_log("Le belve danneggiano la palizzata (%d)." % m.palizzata)
			else:
				_ferite_meteo(1, chi)


# =====================================================================================
# FASE NOTTE
# =====================================================================================

func fase_notte() -> void:
	# 1. mangiare
	var mangiano := []
	for i in m.vivi():
		var p: Dictionary = m.pg[i]
		if p["tipo"] == "venerdi":
			continue
		if p["fuori"]:
			var cibo_suo := int(p["fuori_ris"].get("cibo", 0)) + int(p["fuori_ris"].get("cibo_np", 0))
			if cibo_suo > 0:
				if int(p["fuori_ris"].get("cibo", 0)) > 0:
					p["fuori_ris"]["cibo"] -= 1
				else:
					p["fuori_ris"]["cibo_np"] -= 1
				_log("%s mangia fuori dal campo." % p["nome"])
			else:
				m.ferisci(i, 2, "fame, fuori dal campo")
			continue
		mangiano.append(i)
	var extra := 1 if "cibo_extra" in m.gettoni["notte"] else 0
	for nc in m.notte_carte:
		if int(nc["id"]) == 1002:
			extra += 1
	await _mangia(mangiano, 1, "cena")
	if m.esito != "":
		return
	if extra > 0:
		for k in extra:
			await _mangia(mangiano, 1, "porzione in più")
			if m.esito != "":
				return
	m.gettoni["notte"].erase("cibo_extra")
	if m.scenario == 3 and m.jenny.get("salvata", false):
		if m.cibo_totale() > 0:
			m.scarta_ris("cibo", 1)
		else:
			m.ferisci_jenny(2)
	await Scenari.notte_cibo(m, self)
	if m.esito != "":
		return
	# 2. spostare il campo
	await scegli_spostamento()
	if m.esito != "":
		return
	# 3. dormire all'aperto
	if not m.rifugio_presente():
		_log("Senza rifugio si dorme all'aperto.")
		for i in m.vivi():
			if m.pg[i]["tipo"] == "venerdi" or m.pg[i]["fuori"]:
				continue
			m.ferisci(i, 1, "notte all'aperto")
			if m.esito != "":
				return
		if m.scenario == 3 and m.jenny.get("salvata", false):
			m.ferisci_jenny(1)
	for i in m.vivi():
		if m.pg[i]["fuori"] and m.pg[i]["tipo"] != "venerdi":
			m.ferisci(i, 1, "notte fuori dal campo")
			if m.esito != "":
				return
	# 4. carte e marcatori della notte
	await _effetti_notte()
	if m.esito != "":
		return
	# 5. cure
	await cure_notte()
	if m.esito != "":
		return
	# 6. il cibo deperisce
	if not m.ha("cantina") and not m.ha_tesoro(508):
		var conservato := 0
		for t in m.tesori:
			if int(t["id"]) == 530:
				conservato = min(2, int(t.get("cibo", 0)))
		if m.ris["cibo"] > conservato:
			_log("Il cibo deperibile avanza e va a male (%d)." % (m.ris["cibo"] - conservato))
			m.ris["cibo"] = conservato
	await Scenari.notte(m, self)


func _mangia(chi: Array, quanto: int, motivo: String) -> void:
	var serve := chi.size() * quanto
	var c := m.cibo_totale()
	if c >= serve:
		m.scarta_ris("cibo", serve)
		return
	var oggetti_cibo := _gallette()
	if c + oggetti_cibo >= serve and oggetti_cibo > 0:
		# le gallette coprono la differenza
		var usa := serve - c
		for k in usa:
			_usa_oggetto(601)
			m.ris["cibo"] += 1
	c = m.cibo_totale()
	if c >= serve:
		m.scarta_ris("cibo", serve)
		return
	# non basta: si sceglie chi mangia
	var affamati := chi.duplicate()
	var restano := c
	while restano >= quanto and not affamati.is_empty():
		var opz := []
		for i in affamati:
			opz.append({"testo": "%s (%d ferite)" % [m.pg[i]["nome"], m.pg[i]["ferite"]], "i": i})
		var r = await m.chiedi(m.capo(), {"tipo": "cibo", "titolo": "Cibo insufficiente", "testo": "Il cibo non basta per tutti (%s). Chi mangia?" % motivo, "opzioni": opz})
		var i: int = opz[r]["i"]
		affamati.erase(i)
		m.scarta_ris("cibo", quanto)
		restano -= quanto
	for i in affamati:
		m.ferisci(i, 2, "fame")
		if m.esito != "":
			return


func _gallette() -> int:
	for o in m.oggetti:
		if int(o["id"]) == 601:
			return int(o["usi"])
	return 0


func _usa_oggetto(id: int) -> void:
	for o in m.oggetti:
		if int(o["id"]) == id:
			o["usi"] = int(o["usi"]) - 1
			_log("Usato: %s." % m.nome_carta(id))
			if o["usi"] <= 0:
				m.oggetti.erase(o)
			return


func ha_oggetto(id: int) -> bool:
	for o in m.oggetti:
		if int(o["id"]) == id and int(o["usi"]) > 0:
			return true
	return false


func scegli_spostamento(forzato := false) -> void:
	var opz := []
	if not forzato:
		opz.append({"testo": "Il campo resta dov'è", "k": -1})
	for k in m.vicini(m.campo):
		if not Scenari.campo_ammesso(m, k):
			continue
		var t := m.tessera(k)
		var desc := "%s%s%s" % [_nome_terreno(t.get("terreno", "")), ", rifugio naturale" if t.get("rifugio", false) else "",
			", fonti: " + _fonti(k) if _fonti(k) != "" else ""]
		opz.append({"testo": "Sposta il campo sulla tessera %d (%s)" % [int(m.isola[k]["tessera"]), desc], "k": k, "casella": k})
	if opz.is_empty():
		if forzato:
			_log("Non c'è una tessera adiacente dove spostare il campo: ogni personaggio subisce 1 ferita.")
			m.ferisci_tutti(1, "campo")
		return
	if not forzato and opz.size() == 1:
		return
	var r = await m.chiedi(m.capo(), {"tipo": "campo", "titolo": "Spostare il campo?" if not forzato else "Il campo va spostato", "testo": "Puoi spostare il campo su una tessera adiacente.", "opzioni": opz})
	var k: int = opz[r]["k"]
	if k >= 0:
		sposta_campo(k)


func sposta_campo(k: int) -> void:
	var vecchio := m.campo
	var naturale: bool = not m.rifugio and m.tessera(vecchio).get("rifugio", false)
	m.campo = k
	if m.rifugio:
		m.tetto = int(ceil(m.tetto / 2.0))
		m.palizzata = int(ceil(m.palizzata / 2.0))
	else:
		m.tetto = 0
		m.palizzata = 0
	# i gettoni positivi seguono il campo
	for g in ["cibo_extra", "legno_extra"]:
		if g in m.isola[vecchio]["gettoni"] and (m.campo_gettoni.has(g)):
			m.isola[vecchio]["gettoni"].erase(g)
			if not g in m.isola[k]["gettoni"] or m.scenario == 6:
				m.isola[k]["gettoni"].append(g)
			else:
				_scarta_fonte_gettone(m.campo_gettoni[g])
	if m.ha("scorciatoia"):
		for c in m.isola:
			c["gettoni"].erase("scorciatoia")
		m.costruite.erase(m.id_inv("scorciatoia"))
		_log("La scorciatoia va ricostruita.")
	_log("Il campo si sposta sulla tessera %d." % int(m.isola[k]["tessera"]))
	m.evento.emit("campo", {"k": k})
	m.cambiato.emit()


func _scarta_fonte_gettone(fonte: String) -> void:
	match fonte:
		"laccio":
			m.costruite.erase(m.id_inv("laccio"))
		"accetta_inv":
			m.costruite.erase(m.id_inv("accetta"))
		"accetta":
			for t in m.tesori:
				if int(t["id"]) == 527:
					m.tesori.erase(t)
					break
		"recinto":
			m.costruite.erase(m.id_inv("recinto"))
	m.campo_gettoni.erase(fonte)


func _nome_terreno(t: String) -> String:
	return {"spiaggia": "spiaggia", "collina": "colline", "montagna": "montagne", "fiume": "fiume", "pianura": "pianura"}.get(t, t)


func _fonti(k: int) -> String:
	var t := m.tessera(k)
	var r := []
	if t.get("legno", false) and not m.isola[k]["esauriti"]["legno"]:
		r.append("legno")
	if t.get("cibo", "") != "" and not m.isola[k]["esauriti"]["cibo"]:
		r.append("cibo")
	return " e ".join(r)


func _effetti_notte() -> void:
	var resta := []
	for nc in m.notte_carte:
		var id := int(nc["id"])
		var chi := int(nc.get("chi", m.primo))
		match id:
			547:
				if not m.ha("medicina"):
					_log("Veleno: ogni personaggio subisce 1 ferita.")
					m.ferisci_tutti(1, "veleno")
			551:
				_log("Il gioiello luccicante: ogni personaggio subisce 1 ferita.")
				m.ferisci_tutti(1, "gioiello")
			537:
				if not m.ha("medicina"):
					m.ferisci(chi, 1, "ragnatela")
				resta.append(nc)
			513:
				for i in m.vivi():
					if int(m.pg[i]["malattia"]) > 0:
						m.ferisci(i, int(m.pg[i]["malattia"]), "strana malattia")
						m.pg[i]["malattia"] = 0
			1002:
				pass
			_:
				pass
		if m.esito != "":
			return
	m.notte_carte = resta


func cure_notte() -> void:
	var usati := {}
	while true:
		var opz := [{"testo": "Nessuna cura (prosegui)", "a": ""}]
		var feriti := []
		for i in m.vivi():
			if int(m.pg[i]["ferite"]) > 0:
				feriti.append(i)
		if feriti.is_empty():
			break
		if m.ha("focolare") and not usati.has("focolare") and m.cibo_totale() > 0:
			opz.append({"testo": "Focolare: 1 cibo per 2 ferite", "a": "focolare"})
		if m.ha("pentola") and not usati.has("pentola") and m.cibo_totale() > 0:
			opz.append({"testo": "Pentola: 1 cibo per 1 ferita", "a": "pentola"})
		if "verdure" in m.scop and m.ha("pentola"):
			opz.append({"testo": "Verdure: guarisci 2 ferite", "a": "verdure"})
		if "erbe_c" in m.scop:
			opz.append({"testo": "Erbe: guarisci 1 ferita", "a": "erbe_c"})
		if "unguento" in m.scop:
			opz.append({"testo": "Unguento curativo: guarisci 1 ferita", "a": "unguento"})
		if m.ha_tesoro(522):
			opz.append({"testo": "Bottiglia di vino: guarisci 2 ferite", "a": "vino"})
		for t in m.tesori:
			if int(t["id"]) == 530 and not t.get("usato", false):
				opz.append({"testo": "Barile: ogni personaggio guarisce 1 ferita", "a": "barile"})
		if ha_oggetto(603):
			opz.append({"testo": "Fiaschetta di rum: guarisci 1 ferita", "a": "rum"})
		for i in m.vivi():
			var p: Dictionary = m.pg[i]
			if p["id"] == "cuoco" and int(p["det"]) >= 2 and m.cibo_totale() > 0 and not p["usate"].has("ricetta") and not p["vincoli"].get("no_abilita", false):
				opz.append({"testo": "Cuoco, Ricetta della nonna (2 Det. + 1 cibo): 2 ferite", "a": "ricetta", "i": i})
		if opz.size() == 1:
			break
		var r = await m.chiedi(m.capo(), {"tipo": "cure", "titolo": "Cure della notte", "testo": "Potete curarvi prima di dormire.", "opzioni": opz})
		var a: String = opz[r]["a"]
		if a == "":
			break
		match a:
			"focolare":
				m.scarta_ris("cibo", 1)
				usati["focolare"] = true
				await _cura_scelta(2)
			"pentola":
				m.scarta_ris("cibo", 1)
				usati["pentola"] = true
				await _cura_scelta(1)
			"verdure", "erbe_c", "unguento":
				m.scop.erase(a)
				await _cura_scelta(2 if a == "verdure" else 1)
			"vino":
				for t in m.tesori:
					if int(t["id"]) == 522:
						m.tesori.erase(t)
						break
				await _cura_scelta(2)
			"barile":
				for t in m.tesori:
					if int(t["id"]) == 530:
						t["usato"] = true
				for i in m.vivi():
					m.cura(i, 1)
			"rum":
				_usa_oggetto(603)
				await _cura_scelta(1)
			"ricetta":
				var i: int = opz[r]["i"]
				m.pg[i]["det"] -= 2
				m.pg[i]["usate"]["ricetta"] = true
				m.scarta_ris("cibo", 1)
				await _cura_scelta(2)
		m.cambiato.emit()


## Cura n ferite divise come si vuole fra i personaggi (una alla volta).
func _cura_scelta(n: int) -> void:
	for k in n:
		var opz := []
		for i in m.vivi():
			if int(m.pg[i]["ferite"]) > 0:
				opz.append({"testo": "%s (%d ferite)" % [m.pg[i]["nome"], m.pg[i]["ferite"]], "i": i})
		if m.scenario == 3 and m.jenny.get("salvata", false) and int(m.jenny["ferite"]) > 0:
			opz.append({"testo": "Jenny (%d ferite)" % m.jenny["ferite"], "i": -2})
		if opz.is_empty():
			return
		var r = await m.chiedi(m.capo(), {"tipo": "cura", "titolo": "Cura", "testo": "Chi guarisce una ferita?", "opzioni": opz})
		var i: int = opz[r]["i"]
		if i == -2:
			m.jenny["ferite"] = int(m.jenny["ferite"]) - 1
		else:
			m.cura(i, 1)


# =====================================================================================
# USI LIBERI: abilità, oggetti iniziali, tesori, segnalini Scoperta
# =====================================================================================

func usi_liberi_di_tutti(quando: String) -> void:
	for i in m.giocanti():
		await usi_liberi(i, quando)
		if m.esito != "":
			return


func usi_liberi(i: int, quando: String) -> void:
	var giri := 0
	while giri < 20 and m.esito == "":
		giri += 1
		var opz := opzioni_libere(i)
		if opz.size() <= 1:
			return
		var r = await m.chiedi_pg(i, {"tipo": "libero", "titolo": "%s: %s" % [m.pg[i]["nome"], quando],
			"testo": "Vuoi usare un'abilità, un oggetto o un segnalino?", "opzioni": opz})
		if opz[r]["a"] == "":
			return
		await usa_libero(i, opz[r])
		m.cambiato.emit()


func opzioni_libere(i: int) -> Array:
	var p: Dictionary = m.pg[i]
	var opz := [{"testo": "Niente, prosegui", "a": ""}]
	var det := int(p["det"])
	var ab_ok: bool = not p["vincoli"].get("no_abilita", false)
	var u: Dictionary = p["usate"]
	if ab_ok:
		match p["id"]:
			"cuoco":
				if det >= 3 and not u.has("zuppa"):
					opz.append({"testo": "Zuppa di sassi (3 Det.): prendi 1 cibo", "a": "zuppa"})
				if det >= 2 and m.cibo_totale() > 0 and not u.has("ricetta"):
					var ferito := false
					for j in m.vivi():
						if int(m.pg[j]["ferite"]) > 0:
							ferito = true
					if ferito:
						opz.append({"testo": "Ricetta della nonna (2 Det. + 1 cibo): guarisci 2 ferite", "a": "ricetta"})
			"carpentiere":
				if det >= 3 and not u.has("idea"):
					opz.append({"testo": "Una nuova idea (3 Det.): pesca 5 invenzioni, tienine 1", "a": "idea"})
				if det >= 3 and not u.has("tuttofare") and m.fase == "azione":
					opz.append({"testo": "Tuttofare (3 Det.): pedina extra per Costruire", "a": "tuttofare"})
			"esploratore":
				if det >= 3 and not u.has("discorso") and m.morale < Motore.MORALE_MAX:
					opz.append({"testo": "Discorso motivazionale (3 Det.): +1 morale", "a": "discorso"})
				if det >= 3 and not u.has("ricognizione_s") and not m.pila_scoperte.is_empty():
					opz.append({"testo": "In avanscoperta (3 Det.): pesca 2 segnalini Scoperta, tienine 1", "a": "avanscoperta"})
				if det >= 2 and not u.has("ricognizione") and m.pila_tessere.size() > 1:
					opz.append({"testo": "Ricognizione (2 Det.): guarda 3 tessere, una va in cima", "a": "ricognizione"})
			"soldato":
				if det >= 3 and not u.has("difesa"):
					opz.append({"testo": "Piano di difesa (3 Det.): +1 arma", "a": "difesa_arma"})
					if m.rifugio_presente():
						opz.append({"testo": "Piano di difesa (3 Det.): +1 palizzata", "a": "difesa_pal"})
				if det >= 4 and not u.has("caccia") and not m.mazzo_belve.is_empty():
					opz.append({"testo": "La caccia (4 Det.): una belva nel mazzo Caccia", "a": "caccia"})
				if det >= 2 and not u.has("pista") and not m.mazzo_caccia.is_empty():
					opz.append({"testo": "Seguire le tracce (2 Det.): guarda la prima belva del mazzo Caccia", "a": "pista"})
	for o in m.oggetti:
		var id := int(o["id"])
		match id:
			605:
				opz.append({"testo": "Pipa e tabacco: +2 Determinazione (%d usi)" % o["usi"], "a": "ogg", "id": id})
			601:
				opz.append({"testo": "Gallette: +1 cibo (%d usi)" % o["usi"], "a": "ogg", "id": id})
			604:
				if m.fase == "azione":
					opz.append({"testo": "Martello e chiodi: pedina extra per Costruire (%d usi)" % o["usi"], "a": "ogg", "id": id})
			607:
				if m.fase == "azione" and m.meteo_anticipato.is_empty() and not Scenari.dadi_meteo(m).is_empty():
					opz.append({"testo": "Barometro: tira subito i dadi meteo (%d usi)" % o["usi"], "a": "ogg", "id": id})
	var visti := {}
	for s in m.scop:
		if visti.has(s):
			continue
		visti[s] = true
		var d := _opzione_scoperta(s)
		if not d.is_empty():
			opz.append(d)
	for t in m.tesori:
		match int(t["id"]):
			507:
				opz.append({"testo": "Miscela di erbe: guarda la prima carta Evento", "a": "tes", "id": 507})
			526:
				opz.append({"testo": "Amuleto protettivo: togli un gettone dal tabellone", "a": "tes", "id": 526})
	return opz


func _opzione_scoperta(s: String) -> Dictionary:
	var n: String = Dati.scoperte()["nomi"].get(s, s)
	match s:
		"capra":
			if m.arma >= 1:
				return {"testo": "%s: +1 pelliccia e +1 cibo" % n, "a": "scop", "s": s}
		"erbe_curative":
			if m.ha("pentola") and not m.ha("medicina"):
				return {"testo": "%s: costruisci la Medicina" % n, "a": "scop", "s": s}
		"erbe":
			if m.ha("pentola"):
				return {"testo": "%s: +1 morale" % n, "a": "scop", "s": s}
		"machete", "machete_c":
			return {"testo": "%s: +1 arma" % n, "a": "scop", "s": s}
		"veleno":
			if m.ha("pentola"):
				return {"testo": "%s: +2 arma" % n, "a": "scop", "s": s}
		"tesoro":
			return {"testo": "%s: pesca un tesoro dal mazzo Misteri" % n, "a": "scop", "s": s}
		"rovi":
			if m.rifugio_presente():
				return {"testo": "%s: +1 palizzata" % n, "a": "scop", "s": s}
		"tabacco":
			return {"testo": "%s: +1 morale" % n, "a": "scop", "s": s}
		"candele", "candele_culto":
			if m.fase == "azione":
				return {"testo": "%s: pedina extra per Costruire (una volta)" % n, "a": "scop", "s": s}
		"medaglione":
			return {"testo": "%s: +3 Determinazione" % n, "a": "scop", "s": s}
		"sciabola":
			return {"testo": "%s: +1 arma" % n, "a": "scop", "s": s}
		"olio":
			if m.scenario == 1:
				return {"testo": "%s: 2 legno sulla pira" % n, "a": "scop", "s": s}
		"fiale":
			if not m.ha("medicina"):
				return {"testo": "%s: costruisci la Medicina" % n, "a": "scop", "s": s}
		"campana_decorata":
			return {"testo": "%s: togli 2 segnalini nebbia" % n, "a": "scop", "s": s}
		"attrezzi_vecchi":
			return {"testo": "%s: costruisci gratis Corda, Pentola o Coltello" % n, "a": "scop", "s": s}
		"aratro":
			return {"testo": "%s: togli un segnalino nero da una tessera" % n, "a": "scop", "s": s}
		"semi":
			return {"testo": "%s: +1 cibo non deperibile" % n, "a": "scop", "s": s}
		"mappa_isola":
			return {"testo": "%s: guarda le prime 3 tessere" % n, "a": "scop", "s": s}
		"liane":
			if m.rifugio_presente():
				return {"testo": "%s: +1 palizzata" % n, "a": "scop", "s": s}
		"capanna":
			return {"testo": "%s: +2 legno" % n, "a": "scop", "s": s}
	return {}


func usa_libero(i: int, o: Dictionary) -> void:
	var p: Dictionary = m.pg[i]
	match o["a"]:
		"zuppa":
			p["det"] -= 3
			p["usate"]["zuppa"] = true
			m.guadagna("cibo", 1, i)
		"ricetta":
			p["det"] -= 2
			p["usate"]["ricetta"] = true
			m.scarta_ris("cibo", 1)
			await _cura_scelta(2)
		"idea":
			p["det"] -= 3
			p["usate"]["idea"] = true
			await nuova_idea(i)
		"tuttofare":
			p["det"] -= 3
			p["usate"]["tuttofare"] = true
			m.neutre["costruire_carpentiere"] = int(m.neutre.get("costruire_carpentiere", 0)) + 1
			_log("Il carpentiere ha una pedina in più per costruire.")
		"discorso":
			p["det"] -= 3
			p["usate"]["discorso"] = true
			m.cambia_morale(1)
		"avanscoperta":
			p["det"] -= 3
			p["usate"]["ricognizione_s"] = true
			await scegli_scoperta(2, i)
		"ricognizione":
			p["det"] -= 2
			p["usate"]["ricognizione"] = true
			await ricognizione(i)
		"difesa_arma", "difesa_pal":
			p["det"] -= 3
			p["usate"]["difesa"] = true
			m.cambia_livello("arma" if o["a"] == "difesa_arma" else "palizzata", 1)
		"caccia":
			p["det"] -= 4
			p["usate"]["caccia"] = true
			m.mazzo_caccia.append(m.mazzo_belve.pop_back())
			_log("Una nuova belva nel mazzo Caccia.")
		"pista":
			p["det"] -= 2
			p["usate"]["pista"] = true
			var b: int = m.mazzo_caccia.back()
			var r = await m.chiedi_pg(i, {"tipo": "pista", "titolo": "Seguire le tracce", "testo": "La prima belva del mazzo Caccia è: %s." % m.nome_carta(b),
				"carta": b, "opzioni": [{"testo": "Lasciala in cima"}, {"testo": "Mettila in fondo"}]})
			if r == 1:
				m.mazzo_caccia.pop_back()
				m.mazzo_caccia.push_front(b)
		"ogg":
			var id: int = o["id"]
			_usa_oggetto(id)
			match id:
				605:
					m.dai_det(i, 2)
				601:
					m.guadagna("cibo", 1)
				604:
					m.neutre["costruire"] = int(m.neutre.get("costruire", 0)) + 1
				607:
					m.meteo_anticipato = tira_meteo(Scenari.dadi_meteo(m))
		"scop":
			await usa_scoperta(i, o["s"])
		"tes":
			match int(o["id"]):
				507:
					_rimuovi_tesoro(507)
					if not m.mazzo_eventi.is_empty():
						var e: Dictionary = m.mazzo_eventi.back()
						await m.chiedi_pg(i, {"tipo": "info", "titolo": "Miscela di erbe", "testo": "La prossima carta del mazzo Eventi è: %s." % m.nome_carta(int(e["id"])),
							"carta": int(e["id"]), "opzioni": [{"testo": "Ho visto"}], "conferma": true})
				526:
					await amuleto_protettivo(i)


func _rimuovi_tesoro(id: int) -> void:
	for t in m.tesori:
		if int(t["id"]) == id:
			m.tesori.erase(t)
			return


func usa_scoperta(i: int, s: String) -> void:
	m.scop.erase(s)
	_log("%s usa il segnalino %s." % [m.pg[i]["nome"], Dati.scoperte()["nomi"].get(s, s)])
	match s:
		"capra":
			m.guadagna("pelliccia", 1)
			m.guadagna("cibo", 1)
		"erbe_curative", "fiale":
			var id := m.id_inv("medicina")
			if m.fase == "azione":
				m.inv_fut.append(id)
			else:
				await oggetto_costruito(id)
		"erbe", "tabacco":
			m.cambia_morale(1)
		"machete", "machete_c", "sciabola":
			m.cambia_livello("arma", 1)
		"veleno":
			m.cambia_livello("arma", 2)
		"tesoro":
			await pesca_misteri(m.primo, {"tesoro": 1}, true)
		"rovi", "liane":
			m.cambia_livello("palizzata", 1)
		"capanna":
			m.guadagna("legno", 2)
		"candele", "candele_culto":
			m.neutre["costruire"] = int(m.neutre.get("costruire", 0)) + 1
		"medaglione":
			await _dividi_det(3)
		"olio":
			Scenari.metti_pira(m, 2, true)
		"campana_decorata":
			await togli_nebbia(2)
		"attrezzi_vecchi":
			await costruisci_gratis(i, ["corda", "pentola", "coltello"])
		"aratro":
			await togli_segnalino_nero(i)
		"semi":
			m.guadagna("cibo_np", 1)
		"mappa_isola":
			await ricognizione(i, true)


func _dividi_det(n: int) -> void:
	for k in n:
		var opz := []
		for i in m.giocanti():
			opz.append({"testo": m.pg[i]["nome"], "i": i})
		var r = await m.chiedi(m.capo(), {"tipo": "det", "titolo": "Determinazione", "testo": "Chi riceve il segnalino Determinazione (%d di %d)?" % [k + 1, n], "opzioni": opz})
		m.dai_det(opz[r]["i"], 1)


func nuova_idea(i: int) -> void:
	var pescate := []
	for k in 5:
		if m.mazzo_inv.is_empty():
			m.mazzo_inv = m.scarti_inv.duplicate()
			m.scarti_inv = []
			m._mescola(m.mazzo_inv)
		if m.mazzo_inv.is_empty():
			break
		pescate.append(m.mazzo_inv.pop_back())
	if pescate.is_empty():
		return
	var opz := []
	for id in pescate:
		opz.append({"testo": m.nome_carta(id), "id": id, "carta": id})
	var r = await m.chiedi_pg(i, {"tipo": "invenzione", "titolo": "Una nuova idea", "testo": "Scegli l'invenzione da mettere sul tabellone.", "opzioni": opz})
	var scelta: int = opz[r]["id"]
	m.invenzioni.append(scelta)
	pescate.erase(scelta)
	m.scarti_inv.append_array(pescate)
	_log("Nuova invenzione sul tabellone: %s." % m.nome_carta(scelta))


func scegli_scoperta(n: int, i: int) -> void:
	var pescati := []
	for k in n:
		if not m.pila_scoperte.is_empty():
			pescati.append(m.pila_scoperte.pop_back())
	if pescati.is_empty():
		return
	var opz := []
	for s in pescati:
		opz.append({"testo": "%s — %s" % [Dati.scoperte()["nomi"].get(s, s), Dati.scoperte()["testi"].get(s, "")], "s": s})
	var r = await m.chiedi_pg(i, {"tipo": "scoperta", "titolo": "Segnalini Scoperta", "testo": "Quale segnalino tieni?", "opzioni": opz})
	_aggiungi_scoperta(opz[r]["s"])


func _aggiungi_scoperta(s: String) -> void:
	if m.fase == "azione":
		m.scop_fut.append(s)
	elif s == "albero_caduto":
		m.guadagna("legno", 1)
	elif s == "larve":
		m.guadagna("cibo", 2)
	else:
		m.scop.append(s)
	_log("Segnalino Scoperta: %s." % Dati.scoperte()["nomi"].get(s, s))


func pesca_scoperte(n: int, chi := -1) -> void:
	for k in n:
		if m.pila_scoperte.is_empty():
			return
		var s: String = m.pila_scoperte.pop_back()
		if chi >= 0 and m.pg[chi]["fuori"] and m.fase == "azione":
			m.pg[chi]["fuori_scop"] = m.pg[chi].get("fuori_scop", []) + [s]
		_aggiungi_scoperta(s)


func ricognizione(i: int, solo_guarda := false) -> void:
	var guarda := []
	for k in 3:
		if not m.pila_tessere.is_empty():
			guarda.append(m.pila_tessere.pop_back())
	if guarda.is_empty():
		return
	var opz := []
	for t in guarda:
		opz.append({"testo": "Tessera %d: %s" % [t, descrivi_tessera(t)], "t": t, "tessera": t})
	var r = await m.chiedi_pg(i, {"tipo": "tessera", "titolo": "Ricognizione", "testo": "Quale tessera metti in cima alla pila?", "opzioni": opz})
	var scelta: int = opz[r]["t"]
	guarda.erase(scelta)
	if not solo_guarda:
		for t in guarda:
			m.pila_tessere.insert(m.rng.randi_range(0, m.pila_tessere.size()), t)
	else:
		for t in guarda:
			m.pila_tessere.append(t)
	m.pila_tessere.append(scelta)


func descrivi_tessera(n: int) -> String:
	var t: Dictionary = m.T.get(n, {})
	var r := [_nome_terreno(t.get("terreno", ""))]
	if t.get("legno", false):
		r.append("legno")
	if t.get("cibo", "") != "":
		r.append("cibo (%s)" % t["cibo"])
	if t.get("belva", false):
		r.append("belva")
	if t.get("totem", false):
		r.append("totem")
	if int(t.get("scoperte", 0)) > 0:
		r.append("%d scoperte" % int(t["scoperte"]))
	if t.get("rifugio", false):
		r.append("rifugio naturale")
	return ", ".join(r)


func amuleto_protettivo(i: int) -> void:
	var opz := []
	for g in m.meteo:
		opz.append({"testo": "Meteo: %s" % g, "dove": "meteo", "g": g})
	for sp in m.gettoni:
		for g in m.gettoni[sp]:
			if g != "lento_fisso":
				opz.append({"testo": "%s: %s" % [sp, g], "dove": sp, "g": g})
	for k in m.isola.size():
		for g in m.isola[k]["gettoni"]:
			if g in ["pericolo", "lento"]:
				opz.append({"testo": "Tessera %d: %s" % [int(m.isola[k]["tessera"]), g], "dove": "isola", "k": k, "g": g})
	for t in m.gettoni_avv:
		if m.gettoni_avv[t]:
			opz.append({"testo": "Avventura %s" % t, "dove": "avv", "g": t})
	if opz.is_empty():
		return
	_rimuovi_tesoro(526)
	var r = await m.chiedi_pg(i, {"tipo": "gettone", "titolo": "Amuleto protettivo", "testo": "Quale gettone togli?", "opzioni": opz})
	var o: Dictionary = opz[r]
	match o["dove"]:
		"meteo":
			m.meteo.erase(o["g"])
		"isola":
			m.isola[o["k"]]["gettoni"].erase(o["g"])
		"avv":
			m.gettoni_avv[o["g"]] = false
		_:
			m.gettoni[o["dove"]].erase(o["g"])


func togli_nebbia(n: int) -> void:
	for k in n:
		var opz := []
		for j in m.isola.size():
			if m.isola[j]["nebbia"]:
				opz.append({"testo": "Casella %d" % j, "k": j, "casella": j})
		if opz.is_empty():
			return
		var r = await m.chiedi(m.capo(), {"tipo": "casella", "titolo": "Via la nebbia", "testo": "Da quale casella togli la nebbia?", "opzioni": opz})
		m.isola[opz[r]["k"]]["nebbia"] = false


func togli_segnalino_nero(i: int) -> void:
	var opz := []
	for k in m.isola.size():
		var c: Dictionary = m.isola[k]
		for f in ["legno", "cibo"]:
			if c["esauriti"][f]:
				opz.append({"testo": "Tessera %d: fonte di %s esaurita" % [int(c["tessera"]), f], "k": k, "f": f, "casella": k})
		if c["terreno_coperto"]:
			opz.append({"testo": "Tessera %d: terreno coperto" % int(c["tessera"]), "k": k, "f": "terreno", "casella": k})
	if opz.is_empty():
		return
	var r = await m.chiedi_pg(i, {"tipo": "casella", "titolo": "Togli un segnalino nero", "testo": "Quale segnalino nero togli?", "opzioni": opz})
	var o: Dictionary = opz[r]
	if o["f"] == "terreno":
		m.isola[o["k"]]["terreno_coperto"] = false
	else:
		m.isola[o["k"]]["esauriti"][o["f"]] = false


func costruisci_gratis(i: int, chiavi: Array) -> void:
	var opz := []
	for id in m.invenzioni:
		if m.costruite.has(id) or int(m.C[id].get("scen", 0)) > 0:
			continue
		if chiavi.is_empty() or m.C[id].get("k", "") in chiavi:
			opz.append({"testo": m.nome_carta(id), "id": id, "carta": id})
	for p in m.pg:
		if int(p.get("inv", 0)) > 0 and (chiavi.is_empty() or m.C[int(p["inv"])].get("k", "") in chiavi):
			opz.append({"testo": m.nome_carta(int(p["inv"])), "id": int(p["inv"]), "carta": int(p["inv"])})
	if opz.is_empty():
		return
	var r = await m.chiedi_pg(i, {"tipo": "invenzione", "titolo": "Costruzione gratuita", "testo": "Quale invenzione costruisci gratis?", "opzioni": opz})
	var id: int = opz[r]["id"]
	if m.fase == "azione":
		m.inv_fut.append(id)
	else:
		await oggetto_costruito(id)


# =====================================================================================
# COMBATTIMENTO
# =====================================================================================

func belva_dati(id: int) -> Dictionary:
	var c: Dictionary = m.C[id]
	return {"forza": int(c.get("forza", 0)), "arma": int(c.get("perdita_arma", 0)), "cibo": int(c.get("cibo", 0)),
		"pelliccia": int(c.get("pelliccia", 0)), "palizzata": int(c.get("palizzata", 0)), "extra": c.get("extra", []), "nome": c["nome"], "id": id}


## Bonus temporaneo all'arma: chiede a chi combatte se usare pistola, fucile, sciabola, frenesia...
func bonus_arma(i: int, forza: int, ctx: Dictionary) -> int:
	var bonus := 0
	var ferite_sciabola := 0
	var giri := 0
	while m.arma + bonus < forza and giri < 8:
		giri += 1
		var opz := [{"testo": "Combatti così (arma %d contro forza %d)" % [m.arma + bonus, forza], "a": ""}]
		if ha_oggetto(606):
			opz.append({"testo": "Pistola: +3 arma per questo combattimento", "a": "pistola"})
		if ha_oggetto(602):
			opz.append({"testo": "Bottiglia vuota: +1 arma per questo combattimento", "a": "bottiglia"})
		if m.ha_tesoro(506):
			opz.append({"testo": "Vecchio fucile: +3 arma (una volta)", "a": "fucile"})
		if m.ha_tesoro(1003):
			opz.append({"testo": "Scoperta sorprendente: +3 arma (una volta)", "a": "sorpresa"})
		if m.ha_tesoro(533) and not ctx.has("sciabola"):
			opz.append({"testo": "Sciabola: +3 arma, ma 1 ferita", "a": "sciabola"})
		if "pistola_j" in m.scop:
			opz.append({"testo": "Pistola (segnalino): +3 arma per questo combattimento", "a": "pistola_j"})
		if "cerbottana" in m.scop:
			opz.append({"testo": "Cerbottana: +2 arma per questo combattimento", "a": "cerbottana"})
		if "pugnale" in m.scop and not ctx.has("pugnale"):
			opz.append({"testo": "Pugnale sacrificale: +3 arma, ma 1 ferita", "a": "pugnale"})
		if i >= 0 and m.pg[i]["id"] == "soldato" and int(m.pg[i]["det"]) >= 3 and not m.pg[i]["usate"].has("frenesia") and not ctx.get("meteo", false) and not m.pg[i]["vincoli"].get("no_abilita", false):
			opz.append({"testo": "Frenesia (3 Det.): +3 arma", "a": "frenesia"})
		if opz.size() == 1:
			break
		var chi_dec := i if i >= 0 else m.primo
		var r = await m.chiedi_pg(chi_dec, {"tipo": "combattimento", "titolo": "Combattimento", "testo": "Forza del nemico %d, livello dell'arma %d." % [forza, m.arma + bonus], "opzioni": opz})
		match opz[r]["a"]:
			"":
				break
			"pistola":
				_usa_oggetto(606)
				bonus += 3
			"bottiglia":
				_usa_oggetto(602)
				bonus += 1
			"fucile":
				_rimuovi_tesoro(506)
				bonus += 3
			"pistola_j":
				m.scop.erase("pistola_j")
				bonus += 3
			"cerbottana":
				m.scop.erase("cerbottana")
				bonus += 2
			"sorpresa":
				_rimuovi_tesoro(1003)
				bonus += 3
			"sciabola":
				ctx["sciabola"] = true
				bonus += 3
				ferite_sciabola += 1
			"pugnale":
				ctx["pugnale"] = true
				bonus += 3
				ferite_sciabola += 1
			"frenesia":
				m.pg[i]["det"] -= 3
				m.pg[i]["usate"]["frenesia"] = true
				bonus += 3
	if ferite_sciabola > 0 and i >= 0:
		m.ferisci(i, ferite_sciabola, "lama")
	return bonus


func combatti(i: int, b: Dictionary, ctx: Dictionary) -> void:
	combattimento = true
	var forza: int = int(b.get("forza", 0))
	if ctx.get("pericolo", false):
		forza += 1
	var bonus := 0
	if not ctx.get("noforza", false):
		bonus = await bonus_arma(i, forza, ctx)
		var danno: int = max(0, forza - (m.arma + bonus))
		if danno > 0 and m.ha_tesoro(503):
			danno -= 1
		_log("%s combatte %s (forza %d, arma %d)." % [m.pg[i]["nome"], b.get("nome", "una belva"), forza, m.arma + bonus])
		m.evento.emit("combattimento", {"pg": i, "forza": forza, "arma": m.arma + bonus, "danno": danno, "id": int(b.get("id", -1))})
		if danno > 0:
			m.ferisci(i, danno, "combattimento")
	if m.esito != "":
		combattimento = false
		return
	var perdita: int = int(b.get("arma", 0))
	if perdita < 0:
		m.cambia_livello("arma", perdita, i)
	if int(b.get("cibo", 0)) > 0:
		m.guadagna("cibo", int(b["cibo"]), i)
	if int(b.get("pelliccia", 0)) > 0:
		m.guadagna("pelliccia", int(b["pelliccia"]), i)
	if int(b.get("palizzata", 0)) < 0:
		m.cambia_livello("palizzata", int(b["palizzata"]), i)
	combattimento = false
	if not b.get("extra", []).is_empty():
		await esegui(b["extra"], {"chi": i})


# =====================================================================================
# CARTE MISTERO
# =====================================================================================

## limiti: {tesoro, trappola, creatura, creatura_o_trappola}. obbligo = devi pescare fino al limite.
func pesca_misteri(i: int, limiti: Dictionary, tutto := false, ctx := {}) -> void:
	stop_misteri = false
	var lim := limiti.duplicate()
	var messe_da_parte := []
	var tesori_pescati := []
	var risolte := 0
	var frusta_usata := false
	while m.esito == "" and not stop_misteri:
		var restano := 0
		for k in lim:
			restano += int(lim[k])
		if lim.has("totale"):
			restano = int(lim["totale"])
		if restano <= 0:
			break
		if m.mazzo_misteri.is_empty():
			if m.scarti_misteri.is_empty():
				break
			m.mazzo_misteri = m.scarti_misteri.duplicate()
			m.scarti_misteri = []
			m._mescola(m.mazzo_misteri)
		var id: int = m.mazzo_misteri.pop_back()
		var tipo: String = m.C[id].get("sottotipo", "tesoro")
		var chiave := tipo
		if lim.has("totale"):
			chiave = "totale"
		elif not lim.has(tipo) or int(lim[tipo]) <= 0:
			if tipo in ["creatura", "trappola"] and int(lim.get("creatura_o_trappola", 0)) > 0:
				chiave = "creatura_o_trappola"
			else:
				messe_da_parte.append(id)
				continue
		lim[chiave] = int(lim[chiave]) - 1
		risolte += 1
		_log("%s pesca una carta Mistero: %s (%s)." % [m.pg[i]["nome"], m.C[id]["nome"], tipo])
		m.evento.emit("carta", {"id": id, "lato": "mistero"})
		await mostra(id, "mistero", "Carta Mistero")
		var ignora := false
		if tipo == "trappola":
			if m.ha_tesoro(523) and not frusta_usata:
				var r = await m.chiedi_pg(i, {"tipo": "frusta", "titolo": "Frusta", "testo": "Usi la frusta per ignorare la trappola?", "carta": id, "opzioni": [{"testo": "Sì, ignorala"}, {"testo": "No"}]})
				if r == 0:
					frusta_usata = true
					ignora = true
			if not ignora and "diario_indy" in m.scop:
				var r2 = await m.chiedi_pg(i, {"tipo": "scoperta", "titolo": "Diario di Indy", "testo": "Usi il diario per ignorare la trappola?", "carta": id, "opzioni": [{"testo": "Sì"}, {"testo": "No"}]})
				if r2 == 0:
					m.scop.erase("diario_indy")
					ignora = true
		elif tipo == "creatura" and "torcia" in m.scop:
			var r3 = await m.chiedi_pg(i, {"tipo": "scoperta", "titolo": "Torcia", "testo": "Usi la torcia per ignorare la creatura?", "carta": id, "opzioni": [{"testo": "Sì"}, {"testo": "No"}]})
			if r3 == 0:
				m.scop.erase("torcia")
				ignora = true
		if tipo == "tesoro":
			tesori_pescati.append(id)
			if m.fase == "azione":
				m.tesori_fut.append({"id": id, "chi": i})
			else:
				await risolvi_tesoro(id, i)
		elif not ignora:
			_rimescolata = false
			await esegui(m.C[id].get("top", []), {"chi": i, "carta": id, "lato": "mistero", "tesori_pescati": tesori_pescati})
			if not _rimescolata:
				m.scarti_misteri.append(id)
			_rimescolata = false
		else:
			m.scarti_misteri.append(id)
		if stop_misteri or m.esito != "":
			break
		var ancora := 0
		for k in lim:
			ancora += int(lim[k])
		if lim.has("totale"):
			ancora = int(lim["totale"])
		if ancora > 0 and not tutto:
			var r4 = await m.chiedi_pg(i, {"tipo": "misteri", "titolo": "Carte Mistero", "testo": "Vuoi continuare a pescare carte Mistero?", "opzioni": [{"testo": "Continua"}, {"testo": "Fermati"}]})
			if r4 == 1:
				break
	for id in messe_da_parte:
		m.mazzo_misteri.append(id)
	if not messe_da_parte.is_empty():
		m._mescola(m.mazzo_misteri)
	stop_misteri = false


# =====================================================================================
# INTERPRETE DEGLI EFFETTI
# =====================================================================================

func _bersagli(t, ctx: Dictionary) -> Array:
	match str(t):
		"tutti":
			var r := []
			for i in m.vivi():
				if m.pg[i]["tipo"] != "venerdi":
					r.append(i)
			return r
		"tutti_e_venerdi":
			return m.vivi()
		"primo":
			return [m.primo]
		"vittima":
			var v := int(ctx.get("vittima", ctx.get("chi", m.primo)))
			if v < 0 or v >= m.pg.size() or m.pg[v]["morto"]:
				v = m.primo
			return [v]
		_:
			var c := int(ctx.get("chi", m.primo))
			return [c]


func esegui(ops: Array, ctx: Dictionary) -> void:
	for op in ops:
		if m.esito != "":
			return
		await esegui_op(op, ctx)
		m.cambiato.emit()


func esegui_op(op: Array, ctx: Dictionary) -> void:
	var nome: String = op[0]
	var chi := int(ctx.get("chi", m.primo))
	match nome:
		"morale":
			m.cambia_morale(int(op[1]))
		"det":
			var n := int(op[1])
			var bers := _bersagli(op[2] if op.size() > 2 else "chi", ctx)
			for i in bers:
				if n < 0 and str(op[2] if op.size() > 2 else "chi") == "tutti":
					# «ogni giocatore scarta»: chi non può paga con ferite
					m.dai_det(i, n)
				else:
					m.dai_det(i, n)
		"det_o_ferita":
			for i in _bersagli(op[1], ctx):
				if int(m.pg[i]["det"]) > 0:
					m.dai_det(i, -1)
				else:
					m.ferisci(i, 1, "senza determinazione")
		"det_tutti_via":
			for i in _bersagli(op[1], ctx):
				m.pg[i]["det"] = 0
				_log("%s perde tutta la Determinazione." % m.pg[i]["nome"])
		"ferita":
			var t = op[2] if op.size() > 2 else "chi"
			if str(t) == "tutti":
				m.ferisci_tutti(int(op[1]))
			else:
				for i in _bersagli(t, ctx):
					m.ferisci(i, int(op[1]))
		"cura_subito":
			for i in _bersagli(op[2], ctx):
				m.cura(i, int(op[1]))
		"ris":
			var n2 := int(op[2])
			if n2 > 0:
				m.guadagna(op[1], n2, chi)
			else:
				m.scarta_ris(op[1], -n2, chi if m.fase == "azione" else -1)
		"ris_sp":
			m.scarta_ris(op[1], -int(op[2]), chi, true)
		"ris_per_giocatore":
			var ng := 0
			for i in m.vivi():
				if m.pg[i]["tipo"] == "pg":
					ng += 1
			m.guadagna(op[1], ng * int(op[2]), chi)
		"scarta_risorse":
			for t in Motore.RISORSE:
				m.ris[t] = 0
			_log("Tutte le risorse sono perdute.")
		"liv":
			m.cambia_livello(op[1], int(op[2]), chi if m.fase == "azione" else -1)
		"liv_sp":
			m.cambia_livello(op[1], int(op[2]), chi, true)
		"liv_scelta":
			var n3 := int(op[1])
			var opz := [{"testo": "Tetto %+d" % n3, "t": "tetto"}, {"testo": "Palizzata %+d" % n3, "t": "palizzata"}]
			if n3 < 0:
				opz = opz.filter(func(o): return int(m.get(o["t"])) > 0)
				if opz.is_empty():
					m.richiesta_mancata(-n3, chi if m.fase == "azione" else -1)
					return
			elif not m.rifugio_presente():
				return
			var r = await m.chiedi_pg(chi, {"tipo": "livello", "titolo": "Tetto o palizzata", "testo": "Quale livello cambia?", "opzioni": opz})
			m.cambia_livello(opz[r]["t"], n3, chi)
		"liv_meta":
			var tipi := ["tetto", "palizzata"] if op.size() < 2 else [op[1]]
			var opz2 := []
			for t2 in tipi:
				opz2.append({"testo": "%s: da %d a %d" % [t2.capitalize(), m.get(t2), int(m.get(t2)) - int(int(m.get(t2)) / 2)], "t": t2})
			var tot := 0
			for t2 in tipi:
				tot += int(m.get(t2))
			if tot == 0:
				m.richiesta_mancata(1, chi if m.fase == "azione" else -1)
				return
			var r2 = await m.chiedi_pg(chi, {"tipo": "livello", "titolo": "Metà del livello", "testo": "Quale livello si dimezza (per difetto)?", "opzioni": opz2})
			var tt: String = opz2[r2]["t"]
			var v := int(m.get(tt))
			m.set(tt, v - int(v / 2))
			_log("%s dimezzato: %d." % [tt.capitalize(), m.get(tt)])
		"arma_zero":
			m.arma = 0
			_log("Il livello dell'arma scende a 0.")
		"meteo":
			if not op[1] in m.meteo:
				m.meteo.append(op[1])
				_log("Nello spazio Meteo: %s." % op[1])
		"gettone":
			if not op[2] in m.gettoni[op[1]] or op[2] == "legno_extra" and op[1] in ["arma_costo", "rifugio_costo"]:
				if op[2] in m.gettoni[op[1]]:
					return
				m.gettoni[op[1]].append(op[2])
				_log("Gettone %s sullo spazio %s." % [op[2], op[1]])
		"togli_gettone":
			m.gettoni[op[1]].erase(op[2])
		"avv":
			m.gettoni_avv[op[1]] = true
			_log("Segnalino Avventura sul mazzo %s." % op[1])
		"prod":
			m.prod[op[1]] = true
		"sposta_campo":
			m.vincoli["campo_spostato"] = {"tetto": m.tetto, "palizzata": m.palizzata}
			await scegli_spostamento(true)
			var pr: Dictionary = m.vincoli["campo_spostato"]
			m.vincoli["campo_perso"] = {"tetto": int(pr["tetto"]) > m.tetto, "palizzata": int(pr["palizzata"]) > m.palizzata}
		"recupera_campo":
			var p2: Dictionary = m.vincoli.get("campo_perso", {})
			if m.rifugio:
				if p2.get("tetto", false):
					m.cambia_livello("tetto", 1)
				if p2.get("palizzata", false):
					m.cambia_livello("palizzata", 1)
		"esaurisci":
			await esaurisci_vicina(op[1], ctx)
		"ripristina":
			await ripristina(op[1])
		"esaurisci_adiacenti":
			await esaurisci_adiacenti(int(op[1]))
		"esaurisci_tessera_adiacente":
			await esaurisci_tessera_adiacente()
		"esaurisci_campo":
			var c0: Dictionary = m.isola[m.campo]
			if m.tessera(m.campo).get("cibo", "") != "" and not c0["esauriti"][op[1]]:
				c0["esauriti"][op[1]] = true
				_log("La fonte di cibo del campo è esaurita.")
			else:
				m.ferisci_tutti(1)
		"esaurisci_qui":
			await esaurisci_qui(op[1], ctx)
		"copri_terreno":
			await copri_terreno(op[1])
		"scopri_terreno":
			for c in m.isola:
				if c["terreno_coperto"] and c["tessera"] >= 0 and m.T[int(c["tessera"])].get("terreno", "") == op[1]:
					c["terreno_coperto"] = false
					break
		"copri_terreno_qui":
			var k := int(ctx.get("casella", -1))
			if k >= 0:
				m.isola[k]["terreno_coperto"] = true
				_log("Il terreno della tessera %d è coperto." % int(m.isola[k]["tessera"]))
		"capovolgi_adiacente":
			await capovolgi_adiacente(ctx)
		"raddrizza":
			var k2 := int(m.vincoli.get("capovolta", -1))
			for x in m.isola:
				if x.get("capovolta_da", -1) == int(ctx.get("carta", -2)):
					x["giu"] = false
					x.erase("capovolta_da")
					_log("La tessera %d torna accessibile." % int(x["tessera"]))
		"capovolgi_gettone":
			for k3 in m.isola.size():
				if op[1] in m.isola[k3]["gettoni"] and m.esplorata(k3):
					capovolgi(k3)
		"rovescia_inv":
			await rovescia_oggetti(int(op[1]), op.size() > 2 and op[2] == "scarta")
		"segna_oggetti":
			await segna_oggetti(int(op[1]))
		"rovescia_segnati":
			for id in m.segnati:
				if m.costruite.has(id):
					rovescia_oggetto(int(id))
			m.segnati = []
		"scarta_inv":
			await scarta_invenzioni(int(op[1]))
		"scegli_inv":
			await scegli_invenzione(chi)
		"pesca_inv":
			if not m.mazzo_inv.is_empty():
				var id2: int = m.mazzo_inv.pop_back()
				m.invenzioni.append(id2)
				_log("Nuova invenzione: %s." % m.nome_carta(id2))
		"oggetti_futuro":
			m.vincoli["oggetti_via"] = true
			_log("Gli oggetti non sono disponibili in questo round.")
		"caccia_guarda":
			if not m.mazzo_caccia.is_empty():
				_log("In cima al mazzo Caccia c'è: %s." % m.nome_carta(m.mazzo_caccia.back()))
		"caccia_scarta":
			if not m.mazzo_caccia.is_empty():
				_log("Scartata la belva %s." % m.nome_carta(m.mazzo_caccia.pop_back()))
		"caccia_fondo":
			if not m.mazzo_caccia.is_empty():
				m.mazzo_caccia.push_front(m.mazzo_caccia.pop_back())
		"belva_su_eventi":
			if not m.mazzo_belve.is_empty():
				m.belva_eventi = m.mazzo_belve.pop_back()
				_log("Una belva (%s) attende sopra il mazzo Eventi." % m.nome_carta(m.belva_eventi))
		"belva_eventi_in_caccia":
			if m.belva_eventi >= 0:
				m.mazzo_caccia.append(m.belva_eventi)
				m._mescola(m.mazzo_caccia)
				m.belva_eventi = -1
		"ululato":
			var tre := []
			for k4 in 3:
				if not m.mazzo_belve.is_empty():
					tre.append(m.mazzo_belve.pop_back())
			if not tre.is_empty():
				tre.sort_custom(func(a, b): return int(m.C[a].get("forza", 0)) > int(m.C[b].get("forza", 0)))
				m.mazzo_caccia.append(tre[0])
				_log("La belva più forte (%s) va in cima al mazzo Caccia." % m.nome_carta(tre[0]))
				for k5 in range(1, tre.size()):
					m.mazzo_belve.append(tre[k5])
				m._mescola(m.mazzo_belve)
		"combatti_caccia":
			if not m.mazzo_caccia.is_empty():
				var b: int = m.mazzo_caccia.pop_back()
				await combatti(chi, belva_dati(b), {"chi": chi, "noforza": op.size() > 1 and op[1] == "noforza"})
		"combatti":
			var d: Dictionary = op[1].duplicate()
			d["nome"] = "la belva"
			await combatti(chi if m.fase != "evento" else m.primo, d, ctx)
		"mistero":
			await pesca_misteri(chi, op[1], op.size() > 2 and op[2] == "max", ctx)
		"stop_misteri":
			stop_misteri = true
		"scarta_tesori_azione":
			for id in ctx.get("tesori_pescati", []):
				for t in m.tesori_fut:
					if int(t["id"]) == int(id):
						m.tesori_fut.erase(t)
						m.scarti_misteri.append(int(id))
						break
		"scarta_minacce":
			var ids := []
			for k6 in 2:
				if m.minacce[k6] >= 0:
					ids.append(m.minacce[k6])
				m.minacce[k6] = -1
			for id in ids:
				if m.C[id]["tipo"] == "evento":
					_log("Si risolve la minaccia di %s." % m.nome_carta(id))
					await esegui(m.C[id].get("mn", []), {"chi": m.primo, "carta": id})
		"primo_passa":
			var gg := m.giocanti()
			if gg.size() > 1:
				m.primo = gg[(gg.find(m.primo) + 1) % gg.size()]
				_log("Il primo giocatore ora è %s." % m.pg[m.primo]["nome"])
		"solo_azioni":
			for i in _bersagli(op[2], ctx):
				m.pg[i]["vincoli"]["solo"] = op[1]
				_log("%s in questo round può solo: %s." % [m.pg[i]["nome"], ", ".join(op[1])])
		"una_pedina":
			for i in _bersagli(op[1], ctx) if str(op[1]) != "tutti" else m.vivi():
				m.pg[i]["vincoli"]["una_pedina"] = true
				_log("%s ha una sola pedina in questo round." % m.pg[i]["nome"])
		"una_pedina_prossimo":
			for i in _bersagli(op[1], ctx):
				m.pg[i]["vincoli_prossimo"] = m.pg[i].get("vincoli_prossimo", {})
				m.pg[i]["vincoli_prossimo"]["una_pedina"] = true
		"no_abilita":
			for i in _bersagli(op[1], ctx):
				m.pg[i]["vincoli"]["no_abilita"] = true
		"no_insieme":
			m.vincoli["no_insieme"] = true
			_log("Litigio: in questo round nessuna azione con pedine di giocatori diversi.")
		"libro":
			await libro(ctx)
		"ancora":
			pass
		"decidi":
			var opz3 := []
			for x in op[1]:
				opz3.append({"testo": x[0]})
			var carta := int(ctx.get("carta", -1))
			var r3 = await m.chiedi_pg(chi, {"tipo": "decidi", "titolo": "Decidi", "testo": m.nome_carta(carta) if carta >= 0 else "", "carta": carta, "opzioni": opz3})
			await esegui(op[1][r3][1], ctx)
		"se_non_inv":
			if not m.ha(op[1]):
				await esegui(op[2], ctx)
		"se_inv":
			if m.ha(op[1]):
				await esegui(op[2], ctx)
			elif op.size() > 3:
				await esegui(op[3], ctx)
		"se_arma":
			if m.arma >= int(op[1]):
				await esegui(op[2], ctx)
			else:
				await esegui(op[3], ctx)
		"scoperte":
			await pesca_scoperte(int(op[1]), chi)
		"oggetto_iniziale":
			if not m.oggetti_resto.is_empty():
				var id3: int = m.oggetti_resto.pop_back()
				m.oggetti.append({"id": id3, "usi": 2})
				_log("Nuovo oggetto iniziale: %s." % m.nome_carta(id3))
		"ferita_speciale":
			m.pg[chi]["speciali"][op[1]] += 1
			ctx["vittima"] = chi
			_log("%s: ferita speciale (%s)." % [m.pg[chi]["nome"], op[1]])
		"togli_speciale":
			for i in _bersagli("vittima", ctx):
				m.pg[i]["speciali"][op[1]] = max(0, int(m.pg[i]["speciali"][op[1]]) - 1)
		"notte_fuori":
			m.pg[chi]["fuori"] = true
			_log("%s passerà la notte fuori dal campo." % m.pg[chi]["nome"])
		"inizio_round":
			m.inizio_round_ops.append({"chi": chi, "ops": op[1]})
		"mescola":
			var carta2 := int(ctx.get("carta", -1))
			if carta2 >= 0:
				m.mazzo_eventi.insert(m.rng.randi_range(0, m.mazzo_eventi.size()), {"id": carta2, "vittima": int(ctx.get("vittima", chi))})
				ctx["mescolata"] = true
				_rimescolata = true
				_log("%s va nel mazzo Eventi." % m.nome_carta(carta2))
		"tieni":
			var id4 := int(ctx.get("carta", -1))
			var usi := int(m.C[id4].get("usi", 0))
			m.tesori.append({"id": id4, "usi": usi if usi > 0 else 1, "chi": chi})
			_rimescolata = true
			_log("Si tiene la carta %s." % m.nome_carta(id4))
		"tieni_notte":
			var id5 := int(ctx.get("carta", -1))
			m.notte_carte.append({"id": id5, "chi": chi})
			_rimescolata = true
			if id5 == 537:
				m.notte_carte[-1]["perm"] = true
		"malattia":
			await strana_malattia()
			m.notte_carte.append({"id": 513, "chi": chi})
		"succ_negato_pg":
			m.pg[chi]["succ_negato"] = "permanente" if op[1] == "permanente" else "prossimo_in_attesa"
		"togli_succ_negato":
			for i in _bersagli("vittima", ctx):
				m.pg[i]["succ_negato"] = ""
		"amuleto":
			for k7 in 2:
				var opz4 := []
				for i in m.giocanti():
					opz4.append({"testo": m.pg[i]["nome"], "i": i})
				var r4 = await m.chiedi(m.capo(), {"tipo": "amuleto", "titolo": "Amuleto con ritratto", "testo": "Su quale personaggio copri una freccia del morale?", "opzioni": opz4})
				m.pg[opz4[r4]["i"]]["frecce_coperte"] += 1
		"cannocchiale":
			await ricognizione(chi, true)
		"costruisci_gratis":
			await costruisci_gratis(chi, op[1])
		"neutre":
			m.neutre_perm[op[1]] = int(m.neutre_perm.get(op[1], 0)) + int(op[2])
		"altra_costruzione":
			m.vincoli["costruzione_extra"] = chi
		"raccolta_extra":
			var a: Dictionary = ctx.get("azione", {})
			if a.has("risorsa"):
				m.guadagna(a["risorsa"], 1, chi)
		"gettone_qui":
			var k8 := int(ctx.get("casella", -1))
			if k8 >= 0 and not op[1] in m.isola[k8]["gettoni"]:
				m.isola[k8]["gettoni"].append(op[1])
				_log("Gettone %s sulla casella." % op[1])
		"gettone_campo":
			if not op[1] in m.isola[m.campo]["gettoni"]:
				m.isola[m.campo]["gettoni"].append(op[1])
				m.campo_gettoni[op[1]] = op[2]
				if op[2] == "accetta":
					m.tesori.append({"id": 527, "usi": 1})
			elif op[2] == "accetta":
				m.scarti_misteri.append(527)
		"esaurisci_tessera_gettone":
			for k9 in m.isola.size():
				if op[1] in m.isola[k9]["gettoni"]:
					m.isola[k9]["esauriti"]["legno"] = true
					m.isola[k9]["esauriti"]["cibo"] = true
					_log("Tutte le fonti della tessera %d sono esaurite." % int(m.isola[k9]["tessera"]))
		"recinto":
			await recinto()
		"scorciatoia":
			await scorciatoia()
		"pira":
			Scenari.metti_pira(m, int(op[1]), true)
		"togli_nebbia":
			await togli_nebbia(int(op[1]))
		"vittoria":
			m._fine("vittoria", "Obiettivo raggiunto!")
		_:
			push_warning("Operazione sconosciuta: %s" % nome)


## Le carte rivelate si mostrano con l'evento «carta» (l'interfaccia le fa comparire senza fermare la partita).
func mostra(_id: int, _lato: String, _titolo: String) -> void:
	pass


func strana_malattia() -> void:
	var n := m.giocanti().size() * 2
	for k in n:
		var opz := []
		for i in m.vivi():
			opz.append({"testo": m.pg[i]["nome"], "i": i})
		var r = await m.chiedi(m.capo(), {"tipo": "malattia", "titolo": "Strana malattia", "testo": "A chi va il segnalino malattia (%d di %d)?" % [k + 1, n], "opzioni": opz})
		m.pg[opz[r]["i"]]["malattia"] += 1


# --- fonti, terreni, tessere

func _fonte_tipo(k: int, f: String) -> bool:
	var t := m.tessera(k)
	if m.isola[k]["tessera"] < 0 or not m.esplorata(k):
		return false
	match f:
		"legno":
			return t.get("legno", false) and not m.isola[k]["esauriti"]["legno"]
		"cibo":
			return t.get("cibo", "") != "" and not m.isola[k]["esauriti"]["cibo"]
		"pesce", "pappagallo":
			return t.get("cibo", "") == f and not m.isola[k]["esauriti"]["cibo"]
	return false


func esaurisci_vicina(f: String, ctx: Dictionary) -> void:
	# la fonte più vicina al campo (prima la tessera del campo)
	var migliori := []
	var best := 99
	for k in m.isola.size():
		if _fonte_tipo(k, f):
			var d := m.distanza(k)
			if d < 0:
				continue
			if d < best:
				best = d
				migliori = [k]
			elif d == best:
				migliori.append(k)
	if migliori.is_empty():
		_log("Nessuna fonte da esaurire: ogni personaggio subisce 1 ferita.")
		m.ferisci_tutti(1)
		return
	var k2: int = migliori[0]
	if migliori.size() > 1:
		var opz := []
		for k in migliori:
			opz.append({"testo": "Tessera %d" % int(m.isola[k]["tessera"]), "k": k, "casella": k})
		var r = await m.chiedi(m.capo(), {"tipo": "casella", "titolo": "Fonte esaurita", "testo": "Quale fonte si esaurisce?", "opzioni": opz})
		k2 = opz[r]["k"]
	var campo_f := "legno" if f == "legno" else "cibo"
	m.isola[k2]["esauriti"][campo_f] = true
	m.isola[k2]["esaurita_da_%d" % int(ctx.get("carta", 0))] = campo_f
	_log("La fonte di %s della tessera %d è esaurita." % [campo_f, int(m.isola[k2]["tessera"])])


func ripristina(f: String) -> void:
	var opz := []
	for k in m.isola.size():
		var c: Dictionary = m.isola[k]
		if c["tessera"] < 0:
			continue
		var t := m.tessera(k)
		for ff in ["legno", "cibo"]:
			if not c["esauriti"][ff]:
				continue
			if f == "qualsiasi" or f == ff or (ff == "cibo" and t.get("cibo", "") == f):
				opz.append({"testo": "Tessera %d: fonte di %s" % [int(c["tessera"]), ff], "k": k, "f": ff, "casella": k})
	if opz.is_empty():
		return
	var r = await m.chiedi(m.capo(), {"tipo": "casella", "titolo": "Fonte ritrovata", "testo": "Quale fonte torna disponibile?", "opzioni": opz})
	m.isola[opz[r]["k"]]["esauriti"][opz[r]["f"]] = false
	_log("La fonte torna disponibile.")


func esaurisci_adiacenti(n: int) -> void:
	for x in n:
		var opz := []
		for k in m.vicini(m.campo):
			for f in ["legno", "cibo"]:
				if _fonte_tipo(k, f):
					opz.append({"testo": "Tessera %d: %s" % [int(m.isola[k]["tessera"]), f], "k": k, "f": f, "casella": k})
		if opz.is_empty():
			m.ferisci_tutti(1)
			return
		var r = await m.chiedi(m.capo(), {"tipo": "casella", "titolo": "Fonti esaurite", "testo": "Scegli una fonte vicina al campo da esaurire (%d di %d)." % [x + 1, n], "opzioni": opz})
		m.isola[opz[r]["k"]]["esauriti"][opz[r]["f"]] = true


func esaurisci_tessera_adiacente() -> void:
	var opz := []
	for k in m.vicini(m.campo):
		if m.esplorata(k) and (_fonte_tipo(k, "legno") or _fonte_tipo(k, "cibo")):
			opz.append({"testo": "Tessera %d" % int(m.isola[k]["tessera"]), "k": k, "casella": k})
	if opz.is_empty():
		return
	var r = await m.chiedi(m.capo(), {"tipo": "casella", "titolo": "Uragano", "testo": "Quale tessera perde tutte le fonti?", "opzioni": opz})
	var k: int = opz[r]["k"]
	m.isola[k]["esauriti"]["legno"] = true
	m.isola[k]["esauriti"]["cibo"] = true


func esaurisci_qui(modo: String, ctx: Dictionary) -> void:
	var k := int(ctx.get("casella", -1))
	if k < 0:
		return
	if m.isola[k]["tessera"] < 0:
		m.isola[k]["da_esaurire"] = true
		return
	var a: Dictionary = ctx.get("azione", {})
	if modo == "raccolta" and a.has("risorsa"):
		m.isola[k]["esauriti"][a["risorsa"]] = true
		_log("La fonte di %s è esaurita." % a["risorsa"])
		return
	var opz := []
	for f in ["legno", "cibo"]:
		if _fonte_tipo(k, f):
			opz.append({"testo": "Fonte di %s" % f, "f": f})
	if opz.is_empty():
		return
	var r = await m.chiedi(m.capo(), {"tipo": "fonte", "titolo": "Fonte esaurita", "testo": "Quale fonte si esaurisce?", "opzioni": opz})
	m.isola[k]["esauriti"][opz[r]["f"]] = true


func copri_terreno(ter: String) -> void:
	var opz := []
	for k in m.isola.size():
		if m.esplorata(k) and not m.isola[k]["terreno_coperto"] and m.tessera(k).get("terreno", "") == ter:
			opz.append({"testo": "Tessera %d" % int(m.isola[k]["tessera"]), "k": k, "casella": k})
	if opz.is_empty():
		return
	var r = await m.chiedi(m.capo(), {"tipo": "casella", "titolo": "Terreno perduto", "testo": "Su quale tessera si copre il terreno?", "opzioni": opz})
	m.isola[opz[r]["k"]]["terreno_coperto"] = true
	_log("Il terreno %s della tessera %d non conta più." % [_nome_terreno(ter), int(m.isola[opz[r]["k"]]["tessera"])])


func capovolgi_adiacente(ctx: Dictionary) -> void:
	var opz := []
	for k in m.vicini(m.campo):
		if m.esplorata(k) and not m.isola[k].get("vulcano", false):
			opz.append({"testo": "Tessera %d" % int(m.isola[k]["tessera"]), "k": k, "casella": k})
	if opz.is_empty():
		return
	var r = await m.chiedi(m.capo(), {"tipo": "casella", "titolo": "Tessera inaccessibile", "testo": "Quale tessera vicina al campo diventa inaccessibile?", "opzioni": opz})
	var k2: int = opz[r]["k"]
	capovolgi(k2)
	m.isola[k2]["capovolta_da"] = int(ctx.get("carta", -1))


func capovolgi(k: int) -> void:
	var c: Dictionary = m.isola[k]
	c["giu"] = true
	c["gettoni"] = []
	c["nebbia"] = false
	_log("La tessera %d diventa inaccessibile." % int(c["tessera"]))
	if k == m.campo:
		m._fine("sconfitta", "Il campo è su una tessera diventata inaccessibile.")


# --- oggetti e invenzioni

func oggetti_costruiti(anche_scenario := false) -> Array:
	var r := []
	for id in m.costruite:
		if not anche_scenario and int(m.C[id].get("scen", 0)) > 0:
			continue
		r.append(id)
	return r


func rovescia_oggetto(id: int, scarta := false) -> void:
	m.costruite.erase(id)
	var c: Dictionary = m.C[id]
	_log("%s torna dal lato Invenzione." % c["nome"])
	# annulla gli effetti positivi
	for op in c.get("eff", []):
		if op[0] == "liv":
			m.cambia_livello(op[1], -int(op[2]), -1, true)
		elif op[0] == "ris" and int(op[2]) > 0:
			m.scarta_ris(op[1], int(op[2]), -1, true)
	match c.get("k", ""):
		"scorciatoia":
			for x in m.isola:
				x["gettoni"].erase("scorciatoia")
		"laccio", "accetta", "recinto":
			for g in m.campo_gettoni.keys():
				if m.campo_gettoni[g] in [c["k"], c["k"] + "_inv"]:
					m.isola[m.campo]["gettoni"].erase(g)
					m.campo_gettoni.erase(g)
	for p in m.pg:
		if Dati.personaggio(p["id"]).get("invenzione", 0) == id:
			p["inv"] = id
			m.invenzioni.erase(id)
	if scarta:
		m.invenzioni.erase(id)
		m.mazzo_inv.insert(m.rng.randi_range(0, m.mazzo_inv.size()), id)


func rovescia_oggetti(n: int, scarta := false) -> void:
	for x in n:
		var opz := []
		for id in oggetti_costruiti():
			opz.append({"testo": m.nome_carta(id), "id": id, "carta": id})
		if opz.is_empty():
			return
		var r = await m.chiedi(m.capo(), {"tipo": "oggetto", "titolo": "Oggetto perduto", "testo": "Quale oggetto torna dal lato Invenzione?", "opzioni": opz})
		rovescia_oggetto(opz[r]["id"], scarta)


func segna_oggetti(n: int) -> void:
	for x in n:
		var opz := []
		for id in oggetti_costruiti():
			if not id in m.segnati:
				opz.append({"testo": m.nome_carta(id), "id": id, "carta": id})
		if opz.is_empty():
			return
		var r = await m.chiedi(m.capo(), {"tipo": "oggetto", "titolo": "Ispezione degli attrezzi", "testo": "Quale oggetto segni?", "opzioni": opz})
		m.segnati.append(opz[r]["id"])


func scarta_invenzioni(n: int) -> void:
	for x in n:
		var opz := []
		for id in m.invenzioni:
			if not m.costruite.has(id) and not m.C[id].get("base", false) and int(m.C[id].get("scen", 0)) == 0:
				opz.append({"testo": m.nome_carta(id), "id": id, "carta": id})
		if opz.is_empty():
			return
		var r = await m.chiedi(m.capo(), {"tipo": "invenzione", "titolo": "Idee perdute", "testo": "Quale invenzione scarti (%d di %d)?" % [x + 1, n], "opzioni": opz})
		var id: int = opz[r]["id"]
		m.invenzioni.erase(id)
		m.mazzo_inv.insert(m.rng.randi_range(0, m.mazzo_inv.size()), id)
		_log("Invenzione scartata: %s." % m.nome_carta(id))


func scegli_invenzione(i: int) -> void:
	if m.mazzo_inv.is_empty():
		return
	var opz := []
	var visti := m.mazzo_inv.duplicate()
	visti.sort()
	for id in visti:
		opz.append({"testo": m.nome_carta(id), "id": id, "carta": id})
	var r = await m.chiedi_pg(i, {"tipo": "invenzione", "titolo": "Idea", "testo": "Scegli un'invenzione da mettere sul tabellone.", "opzioni": opz})
	m.mazzo_inv.erase(opz[r]["id"])
	m.invenzioni.append(opz[r]["id"])
	_log("Nuova invenzione: %s." % m.nome_carta(opz[r]["id"]))


func recinto() -> void:
	var opz := []
	for k in m.vicini(m.campo):
		if _fonte_tipo(k, "pappagallo"):
			opz.append({"testo": "Tessera %d" % int(m.isola[k]["tessera"]), "k": k, "casella": k})
	if not opz.is_empty():
		var r = await m.chiedi(m.capo(), {"tipo": "casella", "titolo": "Recinto", "testo": "Da quale tessera vicina portate gli animali?", "opzioni": opz})
		m.isola[opz[r]["k"]]["esauriti"]["cibo"] = true
	if not "cibo_extra" in m.isola[m.campo]["gettoni"]:
		m.isola[m.campo]["gettoni"].append("cibo_extra")
		m.campo_gettoni["cibo_extra"] = "recinto"


func scorciatoia() -> void:
	var opz := []
	for k in m.vicini(m.campo):
		if m.esplorata(k):
			opz.append({"testo": "Tessera %d (%s)" % [int(m.isola[k]["tessera"]), _fonti(k)], "k": k, "casella": k})
	if opz.is_empty():
		return
	var r = await m.chiedi(m.capo(), {"tipo": "casella", "titolo": "Scorciatoia", "testo": "Su quale tessera vicina va la scorciatoia?", "opzioni": opz})
	m.isola[opz[r]["k"]]["gettoni"].append("scorciatoia")
