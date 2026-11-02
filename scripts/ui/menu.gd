extends Control
## Menu iniziale: scenario, giocatori (persona o IA) con il loro personaggio, varianti, vista 2D/3D e gioco online.

var main
var scenario := 1
var gruppi: Array = []
var varianti := {}
var vista3d := false
var ritardo := 0.7

var box_gruppi: VBoxContainer
var box_scenari: HBoxContainer
var lbl_scenario: RichTextLabel
var messaggio: Label
var on_code: LineEdit
var on_nome: LineEdit
var on_start: Button
var pannello_online: PanelContainer

const PERSONAGGI := ["carpentiere", "cuoco", "esploratore", "soldato"]
const NOMI_PG := {"carpentiere": "Carpentiere", "cuoco": "Cuoca", "esploratore": "Esploratrice", "soldato": "Soldatessa", "": "A caso"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: Dictionary = main.menu_state
	scenario = st.get("scenario", 1)
	gruppi = st.get("gruppi", [{"nome": "Stefano", "ia": false, "personaggio": "cuoco"}])
	varianti = st.get("varianti", {"venerdi": true, "cane": true})
	vista3d = st.get("vista3d", false)
	ritardo = st.get("ritardo", 0.7)
	_costruisci()
	if not main.lobby.is_empty():
		_pannello_online.call_deferred()


func _salva() -> void:
	main.menu_state = {"scenario": scenario, "gruppi": gruppi, "varianti": varianti, "vista3d": vista3d, "ritardo": ritardo}


func _costruisci() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 30)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	# titolo
	var ht := HBoxContainer.new()
	ht.add_theme_constant_override("separation", 24)
	v.add_child(ht)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -10)
	ht.add_child(tv)
	tv.add_child(UI.titolo("Robinson Crusoe", 78, UI.OCRA))
	tv.add_child(UI.titolo("Avventure sull'isola maledetta", 34, UI.PERGAMENA))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.add_child(sp)
	var cont := Partita.salvataggio()
	if not cont.is_empty():
		var bc := UI.bottone("Continua la partita (scenario %d, round %d)" % [int(cont.get("config", {}).get("scenario", 1)), int(cont.get("round", 1))], 22)
		bc.pressed.connect(func():
			var cfg: Dictionary = cont["config"].duplicate()
			cfg["storia"] = cont.get("storia", [])
			main.start_game(cfg))
		ht.add_child(bc)
	var b_reg := UI.bottone("Regole", 22)
	b_reg.pressed.connect(main.show_rules)
	ht.add_child(b_reg)
	# scenari
	v.add_child(UI.titolo("Scegli lo scenario", 36))
	box_scenari = HBoxContainer.new()
	box_scenari.add_theme_constant_override("separation", 12)
	v.add_child(box_scenari)
	for s in Dati.scenari():
		var n := int(s["n"])
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = n == scenario
		b.custom_minimum_size = Vector2(250, 210)
		b.tooltip_text = s["obiettivo"]
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.add_theme_constant_override("separation", 2)
		b.add_child(vb)
		var im := UI.immagine(UI.tex("res://assets/scenari/%d.webp" % n), 230, 150)
		im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		vb.add_child(im)
		var l := UI.etichetta("%d. %s" % [n, s["nome"]], 20, UI.PERGAMENA, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(l)
		b.pressed.connect(_scegli_scenario.bind(n))
		box_scenari.add_child(b)
	var pd := UI.pannello()
	v.add_child(pd)
	lbl_scenario = RichTextLabel.new()
	lbl_scenario.bbcode_enabled = true
	lbl_scenario.fit_content = true
	lbl_scenario.add_theme_font_size_override("normal_font_size", 19)
	lbl_scenario.add_theme_font_override("bold_font", UI.font_grassetto)
	pd.add_child(lbl_scenario)
	_aggiorna_scenario()
	# giocatori e varianti
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.add_theme_constant_override("separation", 8)
	h.add_child(col1)
	col1.add_child(UI.titolo("Naufraghi", 34))
	box_gruppi = VBoxContainer.new()
	box_gruppi.add_theme_constant_override("separation", 6)
	col1.add_child(box_gruppi)
	_aggiorna_gruppi()
	var col2 := VBoxContainer.new()
	col2.custom_minimum_size.x = 560
	col2.add_theme_constant_override("separation", 6)
	h.add_child(col2)
	col2.add_child(UI.titolo("Varianti", 34))
	for vv in [["venerdi", "Venerdì aiuta con 1 o 2 giocatori"], ["cane", "Il cane aiuta nel solitario"], ["relitto_casuale", "Relitto iniziale a caso"],
			["oggetti_extra", "3 oggetti iniziali invece di 2 (più facile)"], ["eventi_facili", "Più eventi Avventura e meno Libro"]]:
		var cb := CheckBox.new()
		cb.text = vv[1]
		cb.button_pressed = varianti.get(vv[0], vv[0] in ["venerdi", "cane"])
		cb.toggled.connect(func(on): varianti[vv[0]] = on; _salva())
		col2.add_child(cb)
	var c3 := CheckBox.new()
	c3.text = "Tavolo 3D all'avvio"
	c3.button_pressed = vista3d
	c3.toggled.connect(func(on): vista3d = on; _salva())
	col2.add_child(c3)
	var hr := HBoxContainer.new()
	col2.add_child(hr)
	hr.add_child(UI.etichetta("Velocità dell'IA:", 19))
	var opt := OptionButton.new()
	for x in [["Rapida", 0.25], ["Normale", 0.7], ["Lenta", 1.4]]:
		opt.add_item(x[0])
	opt.selected = 0 if ritardo < 0.5 else (1 if ritardo < 1.0 else 2)
	opt.item_selected.connect(func(k): ritardo = [0.25, 0.7, 1.4][k]; _salva())
	hr.add_child(opt)
	# pulsanti
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	v.add_child(hb)
	var b_go := UI.bottone("Inizia la partita", 28)
	b_go.pressed.connect(_inizia)
	hb.add_child(b_go)
	var b_on := UI.bottone("Gioca online", 24)
	b_on.pressed.connect(_pannello_online)
	hb.add_child(b_on)
	messaggio = UI.etichetta("", 19, UI.OCRA)
	hb.add_child(messaggio)


func _scegli_scenario(n: int) -> void:
	scenario = n
	for b in box_scenari.get_children():
		b.button_pressed = box_scenari.get_children().find(b) == n - 1
	_aggiorna_scenario()
	_salva()


func _aggiorna_scenario() -> void:
	var s := Dati.scenario(scenario)
	lbl_scenario.text = "[b]%s[/b] (%d round). %s\n[b]Libro:[/b] %s  [b]Totem:[/b] %s" % [s["nome"], s["round"], s["obiettivo"], s["libro"], s["totem"]]


func _aggiorna_gruppi() -> void:
	for c in box_gruppi.get_children():
		c.queue_free()
	for i in gruppi.size():
		var g: Dictionary = gruppi[i]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		box_gruppi.add_child(r)
		var pid: String = g.get("personaggio", "")
		var ped := UI.immagine(UI.tex("res://assets/pedine/%s.png" % (pid if pid != "" else "neutra_esplorare")), 44, 44)
		r.add_child(ped)
		var le := LineEdit.new()
		le.text = g["nome"]
		le.custom_minimum_size.x = 220
		le.text_changed.connect(func(t): g["nome"] = t; _salva())
		r.add_child(le)
		var ot := OptionButton.new()
		ot.add_item("Persona")
		ot.add_item("IA")
		ot.selected = 1 if g["ia"] else 0
		ot.item_selected.connect(func(k): g["ia"] = k == 1; _salva())
		r.add_child(ot)
		var op := OptionButton.new()
		var lista := [""] + PERSONAGGI
		for p in lista:
			op.add_item(NOMI_PG[p])
		op.selected = lista.find(pid)
		op.item_selected.connect(func(k): g["personaggio"] = lista[k]; _salva(); _aggiorna_gruppi())
		r.add_child(op)
		if gruppi.size() > 1:
			var bx := UI.bottone("Togli", 17)
			bx.pressed.connect(func(): gruppi.remove_at(i); _salva(); _aggiorna_gruppi())
			r.add_child(bx)
	if gruppi.size() < 4:
		var ba := UI.bottone("+ Aggiungi un naufrago", 19)
		ba.pressed.connect(func():
			var usati := []
			for g2 in gruppi:
				usati.append(g2.get("personaggio", ""))
			var libero := ""
			for p in PERSONAGGI:
				if not p in usati:
					libero = p
					break
			gruppi.append({"nome": "Naufrago %d" % (gruppi.size() + 1), "ia": true, "personaggio": libero})
			_salva()
			_aggiorna_gruppi())
		box_gruppi.add_child(ba)
	var nota := UI.etichetta("Con 1 o 2 naufraghi gioca anche Venerdì (e nel solitario il cane). Le persone sullo stesso dispositivo si passano il turno.", 17, UI.CENERE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_gruppi.add_child(nota)


func _config() -> Dictionary:
	var gg := []
	var usati := {}
	for g in gruppi:
		var p: String = g.get("personaggio", "")
		if p != "" and usati.has(p):
			p = ""
		usati[p] = true
		var nm: String = String(g["nome"]).strip_edges()
		gg.append({"nome": nm if nm != "" else "Naufrago", "ia": g["ia"], "personaggio": p})
	var v := {"venerdi": varianti.get("venerdi", true), "cane": varianti.get("cane", true), "relitto_casuale": varianti.get("relitto_casuale", false)}
	if varianti.get("oggetti_extra", false):
		v["oggetti"] = 3
	if varianti.get("eventi_facili", false):
		v["eventi_libro"] = -2
	return {"scenario": scenario, "giocatori": gg, "varianti": v, "vista3d": vista3d, "ritardo_ia": ritardo}


func _inizia() -> void:
	_salva()
	main.start_game(_config())


# =================================================================== online

func _pannello_online() -> void:
	if pannello_online != null:
		pannello_online.queue_free()
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(cc)
	pannello_online = UI.pannello(Color(0.18, 0.12, 0.08, 0.98), UI.OCRA)
	pannello_online.custom_minimum_size.x = 760
	cc.add_child(pannello_online)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pannello_online.add_child(v)
	v.add_child(UI.titolo("Gioca online", 46))
	var spieg := UI.etichetta("Chi crea la stanza sceglie scenario, naufraghi (le persone sono i posti per gli amici) e varianti in questo menu, poi crea la stanza e dà il codice. Ognuno gioca il proprio naufrago; i posti rimasti liberi li gioca l'IA.", 18, UI.CENERE)
	spieg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(spieg)
	var hn := HBoxContainer.new()
	v.add_child(hn)
	hn.add_child(UI.etichetta("Il tuo nome:", 19))
	on_nome = LineEdit.new()
	on_nome.custom_minimum_size.x = 280
	var net: Net = main.get_net()
	on_nome.text = String(net.load_session().get("name", gruppi[0]["nome"]))
	hn.add_child(on_nome)
	var hc := HBoxContainer.new()
	hc.add_theme_constant_override("separation", 10)
	v.add_child(hc)
	var b_crea := UI.bottone("Crea una stanza", 20)
	b_crea.pressed.connect(_online_crea)
	hc.add_child(b_crea)
	on_code = LineEdit.new()
	on_code.placeholder_text = "Codice"
	on_code.max_length = 4
	on_code.custom_minimum_size.x = 120
	hc.add_child(on_code)
	var b_entra := UI.bottone("Entra", 20)
	b_entra.pressed.connect(_online_entra)
	hc.add_child(b_entra)
	on_start = UI.bottone("Inizia online", 22)
	on_start.visible = main.lobby.get("role", "") == "host"
	on_start.pressed.connect(_online_avvia)
	v.add_child(on_start)
	var stato := UI.etichetta("", 18, UI.OCRA)
	stato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stato.name = "Stato"
	v.add_child(stato)
	var b_chiudi := UI.bottone("Chiudi", 18)
	b_chiudi.pressed.connect(func():
		main.lobby = {}
		fondo.queue_free()
		pannello_online = null)
	v.add_child(b_chiudi)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		_lobby_poll(main.lobby["code"])
	else:
		var sess := net.load_session()
		var vecchia := String(sess.get("room", ""))
		if vecchia != "":
			on_code.text = vecchia
			_di("Eri nella stanza %s: premi Entra per rientrare." % vecchia)


func _di(t: String) -> void:
	if pannello_online != null:
		var l: Label = pannello_online.find_child("Stato", true, false)
		if l != null:
			l.text = t


func _online_crea() -> void:
	var cfg := _config()
	var nm := on_nome.text.strip_edges()
	if nm == "":
		_di("Scrivi il tuo nome.")
		return
	var seats := []
	for i in cfg["giocatori"].size():
		if not cfg["giocatori"][i]["ia"]:
			seats.append(i)
	if seats.is_empty():
		_di("Imposta almeno un naufrago come Persona: sono i posti della stanza.")
		return
	_salva()
	var net: Net = main.get_net()
	_di("Creo la stanza…")
	var code := await net.create_room(nm, seats)
	if code == "":
		_di("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": seats[0]}
	net.remember_room(code, seats[0])
	net._save({"name": nm})
	on_code.text = code
	on_start.visible = true
	_lobby_poll(code)


func _online_entra() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_nome.text.strip_edges()
	if code.length() != 4 or nm == "":
		_di("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	var net: Net = main.get_net()
	_di("Entro nella stanza %s…" % code)
	var seat := await net.join_room(code, nm)
	if seat < 0:
		_di("Stanza %s non trovata, piena, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") == "playing" and room.has("game"):
		_avvia(room["game"], true)
		return
	on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_di("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		var seats := Net._as_dict(room.get("seats", {}))
		var nomi := []
		for k in seats:
			nomi.append("%s (naufrago %d)" % [seats[k].get("name", "?"), int(k) + 1])
		if main.lobby["role"] == "host":
			_di("Stanza [ %s ]: dai il codice ai tuoi amici.\nPresenti: %s.\nQuando ci siete tutti premi Inizia online." % [code, ", ".join(nomi)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_avvia(room["game"], false)
				return
			_di("Sei nella stanza [ %s ] (naufrago %d). Presenti: %s.\nAspetta che chi l'ha creata avvii la partita." % [code, int(main.lobby["seat"]) + 1, ", ".join(nomi)])
		await get_tree().create_timer(2.0).timeout


func _online_avvia() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_di("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	for i in cfg["giocatori"].size():
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary and not cfg["giocatori"][i]["ia"]:
			cfg["giocatori"][i]["nome"] = str(seats_db[k].get("name", cfg["giocatori"][i]["nome"]))
		else:
			cfg["giocatori"][i]["ia"] = true
	cfg["seme"] = 1 + randi() % 2000000000
	cfg.erase("vista3d")
	cfg.erase("ritardo_ia")
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_di("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_avvia(g, false)


func _avvia(g: Dictionary, rientro: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rientro:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_di("Configurazione della partita non valida.")
		return
	var ses := SessioneOnline.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	cfg["vista3d"] = vista3d
	cfg["ritardo_ia"] = ritardo
	main.lobby = {}
	main.start_game(cfg)
