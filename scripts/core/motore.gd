class_name Motore
extends Node
## Motore di Robinson Crusoe (Avventure sull'isola maledetta): stato della partita e regole complete
## del gioco base con i sei scenari.
##
## Come in Paleo, il motore non conosce l'interfaccia: ogni decisione passa da `chiedi(posto, richiesta)`
## e ogni tiro di dado dal generatore con il seme della partita. Stesso seme e stesse risposte = stessa
## partita, quindi si può giocare online in lockstep e riprendere una partita salvata rigiocando le scelte.

signal cambiato
signal messaggio(testo: String)
signal evento(tipo: String, dati: Dictionary)
signal finita(esito: String)
signal scelta_registrata
signal ripresa_finita

const RISORSE := ["legno", "cibo", "cibo_np", "pelliccia"]
const AZIONI := ["minaccia", "caccia", "costruire", "raccogliere", "esplorare", "sistemare", "riposo"]
## Coordinate assiali delle caselle dell'isola sul tabellone (esagoni a punta in su).
## 0-2 riga alta, 3-6 riga centrale, 7-9 riga bassa; 10 = casella in alto a destra (solo scenario 5).
const CASELLE := [[1, -1], [2, -1], [3, -1], [0, 0], [1, 0], [2, 0], [3, 0], [0, 1], [1, 1], [2, 1], [4, -1]]
const PARTENZA := 3
const MORALE_MIN := -3
const MORALE_MAX := 3

## Facce dei dadi (dal modulo TTS): stringa vuota = faccia bianca.
const DADI := {
	"costruire": {"ferita": ["f", "f", "f", "f", "", ""], "avventura": ["?", "?", "?", "", "", ""], "successo": ["s", "s", "s", "s", "d", "d"]},
	"raccogliere": {"ferita": ["f", "", "", "", "", ""], "avventura": ["?", "?", "?", "", "", ""], "successo": ["s", "s", "s", "s", "s", "d"]},
	"esplorare": {"ferita": ["f", "f", "f", "", "", ""], "avventura": ["?", "?", "?", "?", "?", ""], "successo": ["s", "s", "s", "s", "s", "d"]},
}
const DADO_PIOGGIA := [{"p": 1}, {"p": 1}, {"p": 1}, {"p": 2}, {"n": 1}, {"p": 2}]
const DADO_NEVE := [{"n": 1}, {"n": 1}, {"p": 2}, {"n": 2}, {"p": 2}, {"n": 2}]
const DADO_BELVE := ["belva", "cibo", "palizzata", "palizzata", "", ""]

var C: Dictionary
var T: Dictionary
var S: Dictionary                     # scenario in gioco
var rng := RandomNumberGenerator.new()
var seme := 0
var controllori: Array = []
var E: Effetti

# --- configurazione
var scenario := 1
var giocatori: Array = []             # posti: [{nome, ia}]
var varianti := {}

# --- stato
var pg: Array = []                    # personaggi (compresi Venerdì e Jenny)
var cane := false
var primo := 0                        # indice in pg del primo giocatore
var round := 1
var fase := "preparazione"
var esito := ""
var morale := 0
var ris := {"legno": 0, "cibo": 0, "cibo_np": 0, "pelliccia": 0}
var fut := {"legno": 0, "cibo": 0, "cibo_np": 0, "pelliccia": 0}
var scop: Array = []                  # segnalini Scoperta disponibili (nomi)
var scop_fut: Array = []
var pila_scoperte: Array = []
var tetto := 0
var palizzata := 0
var arma := 0
var rifugio := false
var rifugio_round := 0
var isola: Array = []                 # caselle: vedi _casella_vuota()
var campo := PARTENZA
var pila_tessere: Array = []
var invenzioni: Array = []            # id delle invenzioni sul tabellone (lato invenzione o oggetto)
var costruite := {}                   # id -> true (lato Oggetto)
var inv_fut: Array = []               # invenzioni costruite in questa fase Azione
var mazzo_inv: Array = []
var scarti_inv: Array = []
var oggetti: Array = []               # oggetti iniziali: [{id, usi}]
var oggetti_resto: Array = []
var mazzo_eventi: Array = []          # elementi: {id, vittima}
var mazzi_avv := {"costruire": [], "raccogliere": [], "esplorare": []}
var gettoni_avv := {"costruire": false, "raccogliere": false, "esplorare": false}
var mazzo_misteri: Array = []
var scarti_misteri: Array = []
var mazzo_belve: Array = []
var mazzo_caccia: Array = []
var belva_eventi := -1                # Notte pericolosa: belva sopra il mazzo Eventi
var minacce: Array = [-1, -1]         # sinistra, destra
var gettoni := {}                     # spazio -> [gettoni] (costruire, raccogliere, esplorare, sistemare, caccia, notte, arma_costo, rifugio_costo)
var meteo: Array = []                 # gettoni nello spazio Meteo
var meteo_anticipato: Array = []      # dadi tirati in anticipo con il Barometro
var tesori: Array = []                # carte tenute: [{id, usi}]
var tesori_fut: Array = []
var notte_carte: Array = []           # carte nello spazio Notte
var inizio_round_ops: Array = []      # [{chi, ops}]
var prod := {}                        # modifiche alla produzione di questo round
var vincoli := {}                     # vincoli del round (litigio, primo solo certe azioni...)
var segnati: Array = []               # oggetti segnati da Ispezione degli attrezzi
var neutre := {}                      # pedine neutre extra di questo round: tipo -> n
var neutre_perm := {}                 # pedine neutre da segnalini/carte da usare una volta: tipo -> n
var piano: Array = []
var gia_costruiti_round := {}
var esplorati_round := {}
var raccolti_round := {}
var registro: Array = []
var storia: Array = []
var da_rigiocare: Array = []
var turno := 0
# --- scenari
var pira: Array = []                  # Naufraghi: legno su ogni colonna
var pira_round := 0
var croci: Array = []                 # Isola maledetta: caselle con una croce
var croci_completate_round := 0
var totem_contati := 0
var jenny := {}                       # Jenny ha bisogno d'aiuto
var esplorazioni_vulcano := 0
var luoghi_speciali: Array = []
var villaggi_bruciati := 0
var citta_distrutta := false
var figli := 0
var vittoria_fine_round := false
var campo_gettoni := {}
var inv_obiettivo: Array = []         # Famiglia Robinson: le 9 invenzioni da costruire               # gettoni che seguono il campo: gettone -> fonte (laccio, accetta, recinto)


func _init() -> void:
	C = Dati.carte()
	T = Dati.tessere()
	E = Effetti.new(self)


# =====================================================================================
# UTILITÀ
# =====================================================================================

func _log(t: String) -> void:
	registro.append(t)
	if registro.size() > 400:
		registro.pop_front()
	messaggio.emit(t)


func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func nome_carta(id: int) -> String:
	if C.has(id):
		return C[id].get("nome", str(id))
	return str(id)


## richiesta: {tipo, titolo, testo, opzioni: [{testo, ...}], carta?}. Risponde con l'indice dell'opzione.
func chiedi(posto: int, richiesta: Dictionary):
	richiesta["posto"] = posto
	if richiesta.has("opzioni") and richiesta["opzioni"].size() == 1 and not richiesta.get("conferma", false):
		return 0
	if not da_rigiocare.is_empty():
		var v: int = int(da_rigiocare.pop_front())
		storia.append(v)
		if da_rigiocare.is_empty():
			ripresa_finita.emit()
		return v
	var ctl = controllori[posto] if posto < controllori.size() else null
	if ctl == null:
		return 0
	cambiato.emit()
	var r = await ctl.decide(self, posto, richiesta)
	storia.append(int(r))
	scelta_registrata.emit()
	return r


## Chiede al personaggio i (al posto che lo controlla).
func chiedi_pg(i: int, richiesta: Dictionary):
	richiesta["pg"] = i
	return await chiedi(posto_di(i), richiesta)


func posto_di(i: int) -> int:
	if i < 0 or i >= pg.size():
		return capo()
	return int(pg[i].get("posto", capo()))


## Il posto che decide per il gruppo: quello del primo giocatore.
func capo() -> int:
	if pg.is_empty():
		return 0
	return int(pg[primo].get("posto", 0))


func dado(facce: Array):
	return facce[rng.randi_range(0, facce.size() - 1)]


# =====================================================================================
# PREPARAZIONE
# =====================================================================================

## config: {scenario, giocatori: [{nome, ia, personaggio}], seme, varianti: {cane, venerdi, oggetti, eventi_libro}}
func prepara(config: Dictionary) -> void:
	seme = int(config.get("seme", 0))
	if seme == 0:
		seme = randi()
	rng.seed = seme
	scenario = int(config.get("scenario", 1))
	S = Dati.scenario(scenario)
	varianti = config.get("varianti", {}).duplicate()
	giocatori = []
	pg = []
	var gg: Array = config.get("giocatori", [{"nome": "Giocatore 1", "ia": false}])
	var liberi: Array = ["carpentiere", "cuoco", "esploratore", "soldato"]
	for g in gg:
		if g.get("personaggio", "") in liberi:
			liberi.erase(g["personaggio"])
	for i in gg.size():
		var g: Dictionary = gg[i]
		giocatori.append({"nome": g.get("nome", "Giocatore %d" % (i + 1)), "ia": bool(g.get("ia", false))})
		var id: String = g.get("personaggio", "")
		if id == "" or not Dati.personaggio(id):
			if gg.size() <= 2:
				for pref in ["cuoco", "carpentiere", "esploratore", "soldato"]:
					if pref in liberi:
						id = pref
						break
			else:
				id = liberi[rng.randi_range(0, liberi.size() - 1)]
			liberi.erase(id)
		pg.append(_nuovo_pg(id, i))
	var n := gg.size()
	if n <= 2 and varianti.get("venerdi", true):
		pg.append(_nuovo_pg("venerdi", 0))
	cane = (n == 1 and varianti.get("cane", true)) or varianti.get("cane_sempre", false)
	if n >= 3 and varianti.get("venerdi_sempre", false):
		pg.append(_nuovo_pg("venerdi", 0))
	primo = 0
	# isola
	isola = []
	for k in CASELLE.size():
		isola.append(_casella_vuota(k))
	# mazzi
	for tipo in ["costruire", "raccogliere", "esplorare"]:
		mazzi_avv[tipo] = []
	for id in C:
		var c: Dictionary = C[id]
		match c["tipo"]:
			"avventura":
				mazzi_avv[c["azione"]].append(id)
			"mistero":
				mazzo_misteri.append(id)
			"belva":
				mazzo_belve.append(id)
	for tipo in mazzi_avv:
		mazzi_avv[tipo].sort()
		_mescola(mazzi_avv[tipo])
	mazzo_misteri.sort()
	_mescola(mazzo_misteri)
	mazzo_belve.sort()
	_mescola(mazzo_belve)
	_prepara_invenzioni()
	_prepara_eventi()
	_prepara_oggetti()
	_prepara_scoperte()
	_prepara_tessere()
	for sp in ["costruire", "raccogliere", "esplorare", "sistemare", "caccia", "notte", "arma_costo", "rifugio_costo", "riposo"]:
		gettoni[sp] = []
	minacce = [-1, int(varianti.get("relitto", 201))]
	if varianti.get("relitto_casuale", false):
		minacce[1] = [200, 201, 202][rng.randi_range(0, 2)]
	# scenario
	_prepara_scenario()
	for p in pg:
		if p["tipo"] == "pg":
			pass
	_log("Scenario %d: %s. Primo giocatore: %s." % [scenario, S.get("nome", ""), pg[primo]["nome"]])


func _nuovo_pg(id: String, posto: int) -> Dictionary:
	var d := Dati.personaggio(id)
	var p := {"id": id, "nome": d.get("nome", id), "tipo": d.get("tipo", "pg"), "posto": posto, "ferite": 0,
		"segmenti": d.get("segmenti", [4, 4, 3]).duplicate(), "det": 0, "pedine": int(d.get("pedine", 2)),
		"speciali": {"testa": 0, "braccio": 0, "pancia": 0, "gamba": 0}, "usate": {}, "fuori": false, "morto": false,
		"inv": int(d.get("invenzione", 0)), "frecce_coperte": 0, "succ_negato": "", "malattia": 0, "fuori_ris": {},
		"vincoli": {}}
	return p


func _casella_vuota(k: int) -> Dictionary:
	return {"k": k, "tessera": -1, "giu": false, "esauriti": {"legno": false, "cibo": false}, "gettoni": [],
		"terreno_coperto": false, "numero": 0, "nebbia": false, "cenere": false, "croce": false, "bruciato": false, "segnalata": false}


func _prepara_invenzioni() -> void:
	invenzioni = []
	mazzo_inv = []
	var personali := []
	for p in pg:
		if int(p.get("inv", 0)) > 0:
			personali.append(int(p["inv"]))
	for id in C:
		var c: Dictionary = C[id]
		if c["tipo"] != "invenzione":
			continue
		if int(c.get("scen", 0)) > 0:
			if int(c["scen"]) == scenario:
				invenzioni.append(id)
			continue
		if id in personali:
			continue
		if c.get("base", false):
			invenzioni.append(id)
		else:
			mazzo_inv.append(id)
	mazzo_inv.sort()
	_mescola(mazzo_inv)
	var n_iniziali := 9 if scenario == 6 else 5
	inv_obiettivo = []
	for i in n_iniziali:
		if not mazzo_inv.is_empty():
			var id: int = mazzo_inv.pop_back()
			invenzioni.append(id)
			inv_obiettivo.append(id)
	invenzioni.sort()


func _prepara_eventi() -> void:
	var libro := []
	var avv := []
	for id in C:
		var c: Dictionary = C[id]
		if c["tipo"] != "evento":
			continue
		if c.get("simbolo", "") == "libro":
			libro.append(id)
		else:
			avv.append(id)
			if c.get("doppia", false):
				avv.append(id)
	libro.sort()
	avv.sort()
	_mescola(libro)
	_mescola(avv)
	var meta := int(ceil(float(S.get("round", 12)) / 2.0))
	var nl := meta + int(varianti.get("eventi_libro", 0))
	var na := meta - int(varianti.get("eventi_libro", 0))
	mazzo_eventi = []
	for i in nl:
		mazzo_eventi.append({"id": libro[i], "vittima": -1})
	for i in na:
		mazzo_eventi.append({"id": avv[i], "vittima": -1})
	_mescola(mazzo_eventi)


func _prepara_oggetti() -> void:
	var tutti := [600, 601, 602, 603, 604, 605, 606, 607]
	if scenario == 3:
		tutti.erase(607)
	_mescola(tutti)
	oggetti = []
	var forzati: Array = S.get("oggetti", [])
	for id in forzati:
		tutti.erase(int(id))
		oggetti.append({"id": int(id), "usi": 2})
	var n := int(varianti.get("oggetti", 2))
	while oggetti.size() < n and not tutti.is_empty():
		oggetti.append({"id": tutti.pop_back(), "usi": 2})
	oggetti_resto = tutti


func _prepara_scoperte() -> void:
	pila_scoperte = []
	var d := Dati.scoperte()
	for s in d["base"]:
		for i in int(s.get("quanti", 1)):
			pila_scoperte.append(s["k"])
	for s in d["scenari"].get(str(scenario), []):
		pila_scoperte.append(s["k"])
	pila_scoperte.sort()
	_mescola(pila_scoperte)


func _prepara_tessere() -> void:
	pila_tessere = []
	for n in T:
		if int(n) != 8 and not T[n].get("speciale", false):
			pila_tessere.append(int(n))
	pila_tessere.sort()
	_mescola(pila_tessere)


func _prepara_scenario() -> void:
	match scenario:
		4:
			# si parte dalla tessera 10 (casella 6); la tessera 8 è il vulcano (casella 5)
			pila_tessere.erase(10)
			campo = int(S.get("casella_partenza", 5))
			isola[campo]["tessera"] = 10
			var v := int(S.get("casella_vulcano", 4))
			isola[v]["tessera"] = 8
			isola[v]["vulcano"] = true
			isola[v]["giu"] = true
			for k in ["pala", "coltello"]:
				var id := id_inv(k)
				if id > 0:
					costruite[id] = true
			arma = 1
			gettoni["esplorare"].append("lento_fisso")
		5:
			isola[PARTENZA]["tessera"] = 8
			pila_tessere.erase(4)
			isola[10]["tessera"] = 4
			isola[10]["coperta"] = true
		_:
			isola[PARTENZA]["tessera"] = 8
	if scenario != 4:
		campo = PARTENZA
	if scenario == 1:
		pira = []
		for col in S.get("pira", [1, 2, 3, 4, 5]):
			pira.append(0)
	if scenario == 3:
		jenny = {"ferite": 0, "salvata": false, "max": int(S.get("jenny_vita", 11))}
	if scenario == 6:
		figli = 0


# =====================================================================================
# LETTURE DELLO STATO
# =====================================================================================

func vivi() -> Array:
	var r := []
	for i in pg.size():
		if not pg[i]["morto"]:
			r.append(i)
	return r


## Personaggi dei giocatori (senza Venerdì e Jenny).
func giocanti() -> Array:
	var r := []
	for i in pg.size():
		if pg[i]["tipo"] == "pg" and not pg[i]["morto"]:
			r.append(i)
	return r


func indice_venerdi() -> int:
	for i in pg.size():
		if pg[i]["tipo"] == "venerdi":
			return i
	return -1


func n_giocatori() -> int:
	return giocatori.size()


func max_ferite(i: int) -> int:
	var s := 0
	for x in pg[i]["segmenti"]:
		s += int(x)
	return s + 1


func ha(k: String) -> bool:
	## Un Oggetto costruito (chiave dell'invenzione).
	var id := id_inv(k)
	return id > 0 and costruite.has(id) and not vincoli.get("oggetti_via", false)


func id_inv(k: String) -> int:
	for id in C:
		if C[id]["tipo"] == "invenzione" and C[id].get("k", "") == k:
			return id
	return 0


func ha_tesoro(id: int) -> bool:
	for t in tesori:
		if int(t["id"]) == id:
			return true
	return false


func vicini(k: int) -> Array:
	var r := []
	var q: int = CASELLE[k][0]
	var rr: int = CASELLE[k][1]
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, -1], [-1, 1]]:
		for j in CASELLE.size():
			if CASELLE[j][0] == q + d[0] and CASELLE[j][1] == rr + d[1]:
				if j == 10 and scenario != 5:
					continue
				r.append(j)
	return r


func esplorata(k: int) -> bool:
	return isola[k]["tessera"] >= 0 and not isola[k]["giu"] and not isola[k].get("coperta", false)


func tessera(k: int) -> Dictionary:
	return T.get(int(isola[k]["tessera"]), {})


## Distanza dal campo attraverso tessere esplorate (le tessere attraversate contano); -1 se irraggiungibile.
## Per una casella inesplorata: distanza della tessera esplorata vicina più 1.
func distanza(k: int) -> int:
	if k == campo:
		return 0
	var dist := {campo: 0}
	var coda := [campo]
	while not coda.is_empty():
		var a: int = coda.pop_front()
		for b in vicini(a):
			if dist.has(b):
				continue
			if b == k:
				return dist[a] + 1
			if not esplorata(b) or isola[b].get("vulcano", false):
				continue
			dist[b] = dist[a] + 1
			coda.append(b)
	return -1


func terreni_esplorati() -> Dictionary:
	var r := {}
	for c in isola:
		if c["tessera"] < 0 or c["giu"] or c.get("coperta", false) or c["terreno_coperto"] or c["nebbia"] or c.get("vulcano", false):
			continue
		var t: Dictionary = T.get(int(c["tessera"]), {})
		if t.get("terreno", "") != "":
			r[t["terreno"]] = true
	return r


func rifugio_presente() -> bool:
	return rifugio or (esplorata(campo) and tessera(campo).get("rifugio", false))


func pedine_di(i: int) -> int:
	var p: Dictionary = pg[i]
	if p["morto"] or p["fuori"]:
		return 0
	var n: int = int(p["pedine"])
	if p["vincoli"].get("una_pedina", false):
		n = min(n, 1)
	return n


# =====================================================================================
# FERITE, MORALE, DETERMINAZIONE, RISORSE
# =====================================================================================

func ferisci(i: int, n: int, motivo := "") -> void:
	if n <= 0 or i < 0 or i >= pg.size() or pg[i]["morto"]:
		return
	var p: Dictionary = pg[i]
	if p["tipo"] == "jenny_":
		return
	for k in n:
		p["ferite"] += 1
		# le frecce del morale si attraversano dopo ogni segmento
		var acc := 0
		for s in range(p["segmenti"].size() - 1):
			acc += int(p["segmenti"][s])
			if p["ferite"] == acc + 1:
				if p["frecce_coperte"] > 0:
					p["frecce_coperte"] -= 1
				elif p["tipo"] == "pg":
					cambia_morale(-1, false)
		if p["ferite"] >= max_ferite(i):
			p["ferite"] = max_ferite(i)
			p["morto"] = true
			_log("%s muore%s." % [p["nome"], (" (" + motivo + ")") if motivo != "" else ""])
			evento.emit("morte", {"pg": i})
			if p["tipo"] == "pg":
				_fine("sconfitta", "%s è morto." % p["nome"])
			break
	if not p["morto"]:
		_log("%s subisce %d %s%s." % [p["nome"], n, "ferita" if n == 1 else "ferite", (" (" + motivo + ")") if motivo != "" else ""])
	evento.emit("ferita", {"pg": i, "n": n})


func ferisci_tutti(n: int, motivo := "", anche_fuori := true) -> void:
	for i in vivi():
		if pg[i]["tipo"] == "venerdi" and motivo == "meteo":
			continue
		if not anche_fuori and pg[i]["fuori"]:
			continue
		ferisci(i, n, motivo)
		if esito != "":
			return
	if scenario == 3 and jenny.get("salvata", false) and n > 0:
		ferisci_jenny(n)


func ferisci_jenny(n: int) -> void:
	if jenny.is_empty():
		return
	jenny["ferite"] = int(jenny["ferite"]) + n
	_log("Jenny subisce %d ferite (%d/%d)." % [n, jenny["ferite"], jenny["max"]])
	if int(jenny["ferite"]) >= int(jenny["max"]):
		_fine("sconfitta", "Jenny è morta.")


func cura(i: int, n: int) -> void:
	if i < 0 or pg[i]["morto"] or n <= 0:
		return
	var p: Dictionary = pg[i]
	var prima: int = p["ferite"]
	p["ferite"] = max(0, int(p["ferite"]) - n)
	if prima != p["ferite"]:
		_log("%s guarisce %d %s." % [p["nome"], prima - p["ferite"], "ferita" if prima - p["ferite"] == 1 else "ferite"])
		evento.emit("cura", {"pg": i})


func cambia_morale(n: int, log := true) -> void:
	var prima := morale
	morale = clampi(morale + n, MORALE_MIN, MORALE_MAX)
	if log and prima != morale:
		_log("Morale %s (%+d)." % ["sale" if n > 0 else "scende", morale])


func dai_det(i: int, n: int) -> void:
	if i < 0 or pg[i]["morto"] or n == 0:
		return
	if n > 0:
		pg[i]["det"] += n
		_log("%s ottiene %d Determinazione." % [pg[i]["nome"], n])
	else:
		var togli: int = min(-n, int(pg[i]["det"]))
		pg[i]["det"] -= togli
		if togli > 0:
			_log("%s scarta %d Determinazione." % [pg[i]["nome"], togli])
		if -n > togli:
			ferisci(i, -n - togli, "determinazione mancante")


## Guadagno di risorse: durante la fase Azione vanno nelle risorse future.
func guadagna(tipo: String, n: int, i := -1) -> void:
	if n <= 0:
		return
	if i >= 0 and pg[i]["fuori"] and fase == "azione":
		pg[i]["fuori_ris"][tipo] = int(pg[i]["fuori_ris"].get(tipo, 0)) + n
	elif fase == "azione":
		fut[tipo] += n
	else:
		ris[tipo] += n
	_log("+%d %s." % [n, nome_risorsa(tipo, n)])


func nome_risorsa(t: String, n := 1) -> String:
	match t:
		"legno": return "legno"
		"cibo": return "cibo"
		"cibo_np": return "cibo non deperibile"
		"pelliccia": return "pelliccia" if n == 1 else "pellicce"
	return t


## Scarto obbligatorio: se non basta, ferite (al risolutore in fase Azione, altrimenti a tutti).
func scarta_ris(tipo: String, n: int, chi := -1, se_possibile := false) -> void:
	var disp := disponibili(tipo)
	if tipo == "cibo":
		# il cibo si scarta prima deperibile, poi non deperibile
		var a: int = min(n, disponibili("cibo"))
		ris["cibo"] -= a
		var b: int = min(n - a, disponibili("cibo_np"))
		ris["cibo_np"] -= b
		disp = a + b
		if disp > 0:
			_log("Scartato %d cibo." % disp)
	else:
		disp = min(n, disp)
		ris[tipo] -= disp
		if disp > 0:
			_log("Scartato %d %s." % [disp, nome_risorsa(tipo, disp)])
	if disp < n and not se_possibile:
		richiesta_mancata(n - disp, chi)


func disponibili(tipo: String) -> int:
	return max(0, int(ris[tipo]) - int(impegnate().get(tipo, 0)))


func impegnate() -> Dictionary:
	var r := {}
	for a in piano:
		for t in a.get("ris", {}):
			r[t] = int(r.get(t, 0)) + int(a["ris"][t])
	return r


func cibo_totale() -> int:
	return disponibili("cibo") + disponibili("cibo_np")


## Richiesta non soddisfatta: 1 ferita per unità mancante.
func richiesta_mancata(n: int, chi := -1) -> void:
	if n <= 0:
		return
	if fase == "azione" and chi >= 0:
		ferisci(chi, n, "richiesta non soddisfatta")
	elif fase == "evento" and chi >= 0 and E.combattimento:
		ferisci(chi, n, "richiesta non soddisfatta")
	else:
		ferisci_tutti(n, "richiesta non soddisfatta")


func cambia_livello(tipo: String, n: int, chi := -1, se_possibile := false) -> void:
	if n > 0:
		if tipo in ["tetto", "palizzata"] and not rifugio_presente():
			_log("Senza rifugio %s non sale." % ("il tetto" if tipo == "tetto" else "la palizzata"))
			return
		set(tipo, int(get(tipo)) + n)
		_log("%s +%d (%d)." % [tipo.capitalize(), n, get(tipo)])
		return
	var cur: int = get(tipo)
	var togli: int = min(cur, -n)
	set(tipo, cur - togli)
	if togli > 0:
		_log("%s -%d (%d)." % [tipo.capitalize(), togli, get(tipo)])
	if -n > togli and not se_possibile:
		richiesta_mancata(-n - togli, chi)


func _fine(e: String, motivo := "") -> void:
	if esito != "":
		return
	esito = e
	if motivo != "":
		_log(motivo)
	_log("VITTORIA!" if e == "vittoria" else "Sconfitta.")


# =====================================================================================
# SVOLGIMENTO
# =====================================================================================

func gioca() -> void:
	await E.momento_iniziale()
	while esito == "":
		await _round()
		if esito != "":
			break
	fase = "fine"
	cambiato.emit()
	finita.emit(esito)


func _round() -> void:
	vincoli = {}
	prod = {}
	neutre = {}
	gia_costruiti_round = {}
	esplorati_round = {}
	raccolti_round = {}
	for p in pg:
		p["vincoli"] = p.get("vincoli_prossimo", {}).duplicate()
		p["vincoli_prossimo"] = {}
		if p["succ_negato"] == "prossimo_in_attesa":
			p["succ_negato"] = "prossimo"
		elif p["succ_negato"] == "prossimo":
			p["succ_negato"] = ""
	evento.emit("round", {"round": round})
	_log("— Round %d —" % round)
	await E.inizio_round()
	if esito != "":
		return
	# 1. EVENTI
	fase = "evento"
	cambiato.emit()
	if round > 1:
		await E.fase_evento()
	if esito != "":
		return
	# 2. MORALE
	fase = "morale"
	cambiato.emit()
	await E.fase_morale()
	if esito != "":
		return
	# 3. PRODUZIONE
	fase = "produzione"
	cambiato.emit()
	await E.fase_produzione()
	if esito != "":
		return
	# 4. AZIONI
	fase = "azione"
	cambiato.emit()
	await E.fase_azione()
	if esito != "":
		return
	# 5. METEO
	fase = "meteo"
	cambiato.emit()
	await E.fase_meteo()
	if esito != "":
		return
	# 6. NOTTE
	fase = "notte"
	cambiato.emit()
	await E.fase_notte()
	if esito != "":
		return
	await E.fine_round()
