class_name Partita
extends Control
## Vista della partita: mappa dell'isola sul tabellone, minacce e mazzi, stato del campo, naufraghi,
## invenzioni, oggetti e il pannello delle scelte. Il tavolo 3D si apre sopra la mappa.

signal scelta_fatta(indice: int)

var main
var config: Dictionary = {}
var motore: Motore
var ia := IA.new()
var locale := ControlloLocale.new()
var online: SessioneOnline = null

var mappa
var lbl_round: Label
var lbl_fase: Label
var box_tavolo: HBoxContainer
var box_stato: VBoxContainer
var box_pg: VBoxContainer
var box_inv: GridContainer
var box_cose: HFlowContainer
var pannello_scelta: PanelContainer
var scelta_titolo: Label
var scelta_testo: RichTextLabel
var scelta_opzioni: VBoxContainer
var scelta_scroll: ScrollContainer
var scelta_carta: TextureRect
var diario: RichTextLabel
var zoom: PanelContainer
var zoom_img: TextureRect
var zoom_testo: RichTextLabel
var stato_online: Label
var area_mappa: Control
var tavolo3d = null
var vista3d := false
var popup_carte: Control

var _richiesta := {}
var _in_attesa := false
var _ripresa := false
var _da_aggiornare := false
var _coda_carte: Array = []
var _mostra_in_corso := false
const SALVATAGGIO := "user://robinson_partita.json"

const NOMI_FASE := {"preparazione": "Preparazione", "evento": "Fase Evento", "morale": "Fase Morale", "produzione": "Fase Produzione",
	"azione": "Fase Azione", "fine_azione": "Fine della fase Azione", "meteo": "Fase Meteo", "notte": "Fase Notte", "fine_round": "Fine del round", "fine": "Partita finita"}
const COLORI_AZIONE := {"minaccia": Color(0.55, 0.45, 0.35), "caccia": Color(0.78, 0.22, 0.18), "costruire": Color(0.55, 0.36, 0.18),
	"raccogliere": Color(0.5, 0.5, 0.52), "esplorare": Color(0.25, 0.55, 0.25), "sistemare": Color(0.2, 0.3, 0.65), "riposo": Color(0.85, 0.7, 0.2)}
const NOMI_AZIONE := {"minaccia": "Azioni di minaccia", "caccia": "Caccia", "costruire": "Costruire", "raccogliere": "Raccogliere risorse",
	"esplorare": "Esplorare", "sistemare": "Sistemare il campo", "riposo": "Riposo"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	locale.vista = self
	_costruisci()
	motore = Motore.new()
	add_child(motore)
	mappa.m = motore
	motore.cambiato.connect(_segna_aggiornamento)
	motore.messaggio.connect(_al_messaggio)
	motore.evento.connect(_al_evento)
	motore.finita.connect(_alla_fine)
	ia.ritardo = float(config.get("ritardo_ia", 0.7))
	online = config.get("online", null)
	var gg: Array = config.get("giocatori", [])
	if online != null:
		add_child(online)
		online.view = self
		online.locale = locale
		for i in gg.size():
			motore.controllori.append(online)
	else:
		var cia := ControlloIA.new()
		cia.vista = self
		cia.ia = ia
		for g in gg:
			motore.controllori.append(cia if g.get("ia", false) else locale)
	vista3d = config.get("vista3d", false)
	if online == null:
		motore.da_rigiocare = config.get("storia", []).duplicate()
		motore.scelta_registrata.connect(_salva)
		if not motore.da_rigiocare.is_empty():
			_ripresa = true
			motore.ripresa_finita.connect(func(): _ripresa = false; _segna_aggiornamento())
	motore.prepara({"scenario": int(config.get("scenario", 1)), "giocatori": gg, "varianti": config.get("varianti", {}),
		"seme": int(config.get("seme", 0))})
	_aggiorna()
	if vista3d:
		_imposta_3d.call_deferred(true)
	if online != null and online.role != "host":
		online.battito()
	motore.gioca()


# =====================================================================================
# COSTRUZIONE
# =====================================================================================

func _costruisci() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	# barra in alto
	var barra := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.07, 0.04, 0.92)
	sb.border_color = UI.OCRA_SCURA
	sb.border_width_bottom = 2
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	barra.add_theme_stylebox_override("panel", sb)
	root.add_child(barra)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	barra.add_child(hb)
	var s := Dati.scenario(int(config.get("scenario", 1)))
	hb.add_child(UI.titolo("Robinson Crusoe", 34))
	hb.add_child(UI.titolo(s.get("nome", ""), 28, UI.PERGAMENA))
	lbl_round = UI.etichetta("", 22, UI.OCRA, true)
	hb.add_child(lbl_round)
	lbl_fase = UI.etichetta("", 22, UI.PERGAMENA)
	hb.add_child(lbl_fase)
	stato_online = UI.etichetta("", 19, UI.MARE)
	hb.add_child(stato_online)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var b_sc := UI.bottone("Scenario", 18)
	b_sc.pressed.connect(_mostra_scenario)
	hb.add_child(b_sc)
	var b3 := UI.bottone("Tavolo 3D", 18)
	b3.name = "B3D"
	b3.toggle_mode = true
	b3.toggled.connect(_imposta_3d)
	hb.add_child(b3)
	var br := UI.bottone("Regole", 18)
	br.pressed.connect(_mostra_regole)
	hb.add_child(br)
	var bm := UI.bottone("Menu", 18)
	bm.pressed.connect(_torna_menu)
	hb.add_child(bm)
	# corpo
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 8)
	root.add_child(corpo)
	# --- colonna sinistra: mappa + tavolo (minacce, mazzi, diario)
	var sx := VBoxContainer.new()
	sx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sx.size_flags_stretch_ratio = 1.35
	sx.add_theme_constant_override("separation", 6)
	corpo.add_child(sx)
	area_mappa = Control.new()
	area_mappa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sx.add_child(area_mappa)
	mappa = preload("res://scripts/ui/mappa.gd").new()
	mappa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mappa.casella_cliccata.connect(_casella_cliccata)
	area_mappa.add_child(mappa)
	var basso := HBoxContainer.new()
	basso.custom_minimum_size.y = 250
	basso.add_theme_constant_override("separation", 8)
	sx.add_child(basso)
	var pt := UI.pannello(Color(0.14, 0.09, 0.05, 0.9))
	basso.add_child(pt)
	box_tavolo = HBoxContainer.new()
	box_tavolo.add_theme_constant_override("separation", 10)
	pt.add_child(box_tavolo)
	var pd := UI.pergamena()
	pd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basso.add_child(pd)
	diario = RichTextLabel.new()
	diario.scroll_following = true
	diario.bbcode_enabled = true
	diario.add_theme_font_override("normal_font", UI.font_diario)
	diario.add_theme_font_size_override("normal_font_size", 22)
	diario.add_theme_color_override("default_color", UI.INCHIOSTRO)
	pd.add_child(diario)
	# --- colonna destra: stato + scelte
	var dx := VBoxContainer.new()
	dx.custom_minimum_size.x = 760
	dx.add_theme_constant_override("separation", 6)
	corpo.add_child(dx)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dx.add_child(sc)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	sc.add_child(info)
	var p1 := UI.pannello()
	info.add_child(p1)
	box_stato = VBoxContainer.new()
	p1.add_child(box_stato)
	var p2 := UI.pannello()
	info.add_child(p2)
	box_pg = VBoxContainer.new()
	box_pg.add_theme_constant_override("separation", 4)
	p2.add_child(box_pg)
	var p3 := UI.pannello()
	info.add_child(p3)
	var v3 := VBoxContainer.new()
	p3.add_child(v3)
	v3.add_child(UI.titolo("Invenzioni e oggetti", 26))
	box_inv = GridContainer.new()
	box_inv.columns = 8
	box_inv.add_theme_constant_override("h_separation", 6)
	box_inv.add_theme_constant_override("v_separation", 6)
	v3.add_child(box_inv)
	var p4 := UI.pannello()
	info.add_child(p4)
	var v4 := VBoxContainer.new()
	p4.add_child(v4)
	v4.add_child(UI.titolo("Equipaggiamento, tesori e scoperte", 26))
	box_cose = HFlowContainer.new()
	box_cose.add_theme_constant_override("h_separation", 6)
	v4.add_child(box_cose)
	# pannello delle scelte
	pannello_scelta = UI.pannello(Color(0.22, 0.13, 0.07, 0.97), UI.OCRA)
	pannello_scelta.custom_minimum_size.y = 360
	dx.add_child(pannello_scelta)
	var vs := VBoxContainer.new()
	vs.add_theme_constant_override("separation", 4)
	pannello_scelta.add_child(vs)
	var hs := HBoxContainer.new()
	hs.add_theme_constant_override("separation", 10)
	vs.add_child(hs)
	scelta_carta = UI.immagine(null, 0, 0)
	scelta_carta.mouse_filter = Control.MOUSE_FILTER_PASS
	hs.add_child(scelta_carta)
	var vt := VBoxContainer.new()
	vt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hs.add_child(vt)
	scelta_titolo = UI.titolo("", 28)
	vt.add_child(scelta_titolo)
	scelta_testo = RichTextLabel.new()
	scelta_testo.fit_content = true
	scelta_testo.bbcode_enabled = true
	scelta_testo.add_theme_font_size_override("normal_font_size", 19)
	vt.add_child(scelta_testo)
	scelta_scroll = ScrollContainer.new()
	scelta_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scelta_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vs.add_child(scelta_scroll)
	scelta_opzioni = VBoxContainer.new()
	scelta_opzioni.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scelta_opzioni.add_theme_constant_override("separation", 3)
	scelta_scroll.add_child(scelta_opzioni)
	# zoom delle carte
	zoom = UI.pannello(Color(0.1, 0.06, 0.03, 0.97), UI.OCRA)
	zoom.visible = false
	zoom.z_index = 50
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zoom)
	var hz := HBoxContainer.new()
	hz.add_theme_constant_override("separation", 12)
	zoom.add_child(hz)
	zoom_img = UI.immagine(null, 300, 460)
	hz.add_child(zoom_img)
	zoom_testo = RichTextLabel.new()
	zoom_testo.bbcode_enabled = true
	zoom_testo.custom_minimum_size = Vector2(380, 460)
	zoom_testo.add_theme_font_size_override("normal_font_size", 19)
	zoom_testo.add_theme_font_override("bold_font", UI.font_grassetto)
	zoom_testo.add_theme_font_override("italics_font", UI.font_corsivo)
	zoom_testo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hz.add_child(zoom_testo)
	popup_carte = Control.new()
	popup_carte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_carte.z_index = 40
	add_child(popup_carte)


# =====================================================================================
# AGGIORNAMENTO
# =====================================================================================

func _salva() -> void:
	var cfg := config.duplicate()
	cfg.erase("online")
	cfg.erase("storia")
	cfg["seme"] = motore.seme
	var f := FileAccess.open(SALVATAGGIO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"config": cfg, "storia": motore.storia, "round": motore.round}))
		f.close()


static func salvataggio() -> Dictionary:
	if not FileAccess.file_exists(SALVATAGGIO):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SALVATAGGIO))
	return d if d is Dictionary else {}


static func cancella_salvataggio() -> void:
	if FileAccess.file_exists(SALVATAGGIO):
		DirAccess.remove_absolute(SALVATAGGIO)


func _segna_aggiornamento() -> void:
	if _ripresa:
		return
	if not _da_aggiornare:
		_da_aggiornare = true
		call_deferred("_aggiorna")


func _aggiorna() -> void:
	_da_aggiornare = false
	if motore == null:
		return
	lbl_round.text = "Round %d di %d" % [motore.round, int(motore.S.get("round", 12))]
	lbl_fase.text = NOMI_FASE.get(motore.fase, motore.fase)
	_aggiorna_tavolo()
	_aggiorna_stato()
	_aggiorna_pg()
	_aggiorna_inv()
	_aggiorna_cose()
	mappa.queue_redraw()
	if tavolo3d != null and tavolo3d.visible:
		tavolo3d.aggiorna(motore)


func _svuota(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _carta(id: int, w: float, h: float) -> TextureRect:
	var r := UI.immagine(UI.tex("res://assets/carte/%d.webp" % id), w, h)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.mouse_entered.connect(_mostra_zoom.bind(id, r))
	r.mouse_exited.connect(_nascondi_zoom)
	return r


func _dorso(n: int, w: float, h: float) -> TextureRect:
	return UI.immagine(UI.tex("res://assets/dorsi/%d.webp" % n), w, h)


func _colonna(titolo: String, contenuto: Control, nota := "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var l := UI.etichetta(titolo, 16, UI.OCRA, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.add_child(contenuto)
	if nota != "":
		var n := UI.etichetta(nota, 15, UI.CENERE)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
	return v


func _aggiorna_tavolo() -> void:
	_svuota(box_tavolo)
	var m := motore
	# minacce
	for slot in 2:
		var id: int = m.minacce[slot]
		var c: Control
		if id >= 0:
			c = _carta(id, 118, 182)
		else:
			c = UI.immagine(null, 118, 182)
			var bg := ColorRect.new()
			bg.color = Color(0, 0, 0, 0.25)
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			c.add_child(bg)
		box_tavolo.add_child(_colonna("Minaccia " + ("sinistra" if slot == 0 else "destra"), c))
	# mazzi
	box_tavolo.add_child(_colonna("Eventi", _dorso(4, 80, 123), "%d carte" % m.mazzo_eventi.size()))
	var avv := VBoxContainer.new()
	var nomi := {"costruire": 8, "raccogliere": 9, "esplorare": 10}
	var ha := HBoxContainer.new()
	ha.add_theme_constant_override("separation", 4)
	for t in ["costruire", "raccogliere", "esplorare"]:
		var d := _dorso(nomi[t], 62, 96)
		if m.gettoni_avv[t]:
			var g := UI.immagine(UI.tex("res://assets/segnalini/avv_%s.png" % t), 38, 38)
			g.position = Vector2(12, 28)
			d.add_child(g)
		d.tooltip_text = "Avventure %s: %d carte%s" % [t, m.mazzi_avv[t].size(), " (c'è il segnalino Avventura)" if m.gettoni_avv[t] else ""]
		d.mouse_filter = Control.MOUSE_FILTER_PASS
		ha.add_child(d)
	avv.add_child(ha)
	box_tavolo.add_child(_colonna("Avventure", avv))
	var hc := HBoxContainer.new()
	var dc := _dorso(7, 70, 108)
	hc.add_child(dc)
	box_tavolo.add_child(_colonna("Caccia", hc, "%d belve" % m.mazzo_caccia.size()))
	box_tavolo.add_child(_colonna("Misteri", _dorso(5, 70, 108), "%d carte" % m.mazzo_misteri.size()))
	# meteo
	var vm := VBoxContainer.new()
	var hm := HFlowContainer.new()
	hm.custom_minimum_size.x = 120
	for g in m.meteo:
		var nome: String = {"pioggia": "pioggia", "neve": "neve", "tempesta": "tempesta", "dado_belve": "pericolo"}.get(g, g)
		var im := UI.immagine(UI.tex("res://assets/segnalini/%s.png" % nome), 44, 44)
		im.tooltip_text = {"pioggia": "Nuvola di pioggia", "neve": "Nuvola di neve", "tempesta": "Tempesta: -1 palizzata", "dado_belve": "Si tira il dado delle belve"}.get(g, g)
		im.mouse_filter = Control.MOUSE_FILTER_PASS
		hm.add_child(im)
	vm.add_child(hm)
	var dadi: Array = Scenari.dadi_meteo(m)
	var testo_dadi := "Dadi: " + (", ".join(dadi.map(func(x): return {"pioggia": "pioggia", "neve": "inverno", "belve": "belve"}.get(x, x))) if not dadi.is_empty() else "nessuno")
	vm.add_child(UI.etichetta(testo_dadi, 15, UI.CENERE))
	box_tavolo.add_child(_colonna("Meteo", vm))


func _icona_num(icona: String, n: int, tip: String, size := 34) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.add_child(UI.immagine(UI.tex(icona), size, size))
	h.add_child(UI.etichetta(str(n), 22, UI.PERGAMENA, true))
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h


func _aggiorna_stato() -> void:
	_svuota(box_stato)
	var m := motore
	# morale
	var hm := HBoxContainer.new()
	hm.add_theme_constant_override("separation", 4)
	hm.add_child(UI.etichetta("Morale", 20, UI.OCRA, true))
	for v in range(-3, 4):
		var p := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.85, 0.7, 0.35) if v == m.morale else Color(0.25, 0.17, 0.1)
		s.set_corner_radius_all(14)
		s.content_margin_left = 8
		s.content_margin_right = 8
		p.add_theme_stylebox_override("panel", s)
		p.add_child(UI.etichetta("%+d" % v if v != 0 else "0", 18, UI.INCHIOSTRO if v == m.morale else UI.CENERE, true))
		p.tooltip_text = {-3: "Il primo giocatore scarta 3 Determinazione", -2: "Il primo giocatore scarta 2 Determinazione", -1: "Il primo giocatore scarta 1 Determinazione",
			0: "Nessun effetto", 1: "Il primo giocatore ottiene 1 Determinazione", 2: "Il primo giocatore ottiene 2 Determinazione", 3: "2 Determinazione oppure 1 ferita guarita"}[v]
		hm.add_child(p)
	var sp := Control.new()
	sp.custom_minimum_size.x = 14
	hm.add_child(sp)
	hm.add_child(_icona_num("res://assets/ui/rifugio.png", 1 if m.rifugio_presente() else 0,
		"Rifugio: %s" % ("costruito" if m.rifugio else ("rifugio naturale" if m.rifugio_presente() else "non c'è: di notte 1 ferita a testa"))))
	hm.add_child(_icona_num("res://assets/ui/tetto.png", m.tetto, "Tetto: protegge da altrettante nuvole"))
	hm.add_child(_icona_num("res://assets/ui/palizzata.png", m.palizzata, "Palizzata: protegge da tempeste e belve"))
	hm.add_child(_icona_num("res://assets/ui/arma.png", m.arma, "Livello dell'arma"))
	box_stato.add_child(hm)
	# risorse
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 12)
	hr.add_child(UI.etichetta("Risorse", 20, UI.OCRA, true))
	for t in [["legno", "res://assets/ui/legno.png"], ["cibo", "res://assets/ui/cibo.png"], ["cibo_np", "res://assets/ui/cibo_np.png"], ["pelliccia", "res://assets/ui/pelliccia.png"]]:
		var x := _icona_num(t[1], int(m.ris[t[0]]), "%s disponibile%s" % [m.nome_risorsa(t[0], 2).capitalize(), (" (+%d in arrivo a fine fase Azione)" % m.fut[t[0]]) if int(m.fut[t[0]]) > 0 else ""])
		if int(m.fut[t[0]]) > 0:
			x.add_child(UI.etichetta("(+%d)" % m.fut[t[0]], 17, UI.VERDE))
		hr.add_child(x)
	var imp := m.impegnate()
	if not imp.is_empty():
		var tx := []
		for k in imp:
			tx.append("%d %s" % [imp[k], m.nome_risorsa(k, int(imp[k]))])
		hr.add_child(UI.etichetta("impegnate: " + ", ".join(tx), 16, UI.CENERE))
	box_stato.add_child(hr)
	# gettoni sugli spazi azione
	var hg := HFlowContainer.new()
	var nomi_sp := {"costruire": "Costruire", "raccogliere": "Raccogliere", "esplorare": "Esplorare", "sistemare": "Sistemare", "caccia": "Caccia", "notte": "Notte",
		"arma_costo": "Costo arma", "rifugio_costo": "Costo rifugio", "riposo": "Riposo"}
	for spz in m.gettoni:
		for g in m.gettoni[spz]:
			var nome: String = {"lento_fisso": "lento", "nero": "pericolo"}.get(g, g)
			var b := HBoxContainer.new()
			b.add_child(UI.immagine(UI.tex("res://assets/segnalini/%s.png" % nome), 30, 30))
			b.add_child(UI.etichetta(nomi_sp.get(spz, spz), 16, UI.CENERE))
			b.tooltip_text = _spiega_gettone(spz, g)
			b.mouse_filter = Control.MOUSE_FILTER_PASS
			hg.add_child(b)
	if hg.get_child_count() > 0:
		box_stato.add_child(hg)
	var sc := Scenari
	if m.scenario == 1:
		box_stato.add_child(UI.etichetta("Pira: %s (Fuoco %s)" % [" | ".join(range(m.pira.size()).map(func(c): return "%d/%d" % [m.pira[c], m.S["pira"][c]])), "costruito" if m.ha("fuoco") else "da costruire"], 18, UI.PERGAMENA))
	elif m.scenario == 2:
		box_stato.add_child(UI.etichetta("Croci: %d di 5" % m.croci.size(), 18, UI.PERGAMENA))
	elif m.scenario == 3:
		box_stato.add_child(UI.etichetta("Jenny: %s, ferite %d/%d" % ["al campo" if m.jenny.get("salvata", false) else "sullo scoglio", m.jenny.get("ferite", 0), m.jenny.get("max", 11)], 18, UI.PERGAMENA))
	elif m.scenario == 4:
		var ng := str(clampi(m.n_giocatori(), 1, 4))
		box_stato.add_child(UI.etichetta("Esplorazioni: %d/%d, luoghi dei totem: %d/%d" % [m.esplorazioni_vulcano, int(m.S["esplora"][ng]), m.luoghi_speciali.size(), int(m.S["totem_obiettivo"][ng])], 18, UI.PERGAMENA))
	elif m.scenario == 5:
		box_stato.add_child(UI.etichetta("Villaggi bruciati: %d. Forza dei villaggi %d, della città %d." % [m.villaggi_bruciati, sc.forza_villaggio(m), 21 - 3 * m.villaggi_bruciati], 18, UI.PERGAMENA))
	elif m.scenario == 6:
		var fatte := 0
		for id in m.inv_obiettivo:
			if m.costruite.has(int(id)):
				fatte += 1
		box_stato.add_child(UI.etichetta("Invenzioni della famiglia: %d di %d" % [fatte, m.inv_obiettivo.size()], 18, UI.PERGAMENA))


func _spiega_gettone(spz: String, g: String) -> String:
	match g:
		"lento", "lento_fisso":
			return "Azione lenta: la prossima azione di questo tipo richiede una pedina in più."
		"rilancio":
			return "La prossima azione di questo tipo deve rilanciare un risultato di successo."
		"legno_extra":
			return "Serve un legno in più."
		"cibo_extra":
			return "Di notte ogni personaggio mangia un cibo in più."
		"pericolo":
			return "La prossima belva cacciata è più forte di 1." if spz == "caccia" else "Pericolo."
		"nero":
			return "Il prossimo Sistemare il campo non dà vantaggi."
	return g


func _aggiorna_pg() -> void:
	_svuota(box_pg)
	var m := motore
	box_pg.add_child(UI.titolo("Naufraghi", 26))
	for i in m.pg.size():
		var p: Dictionary = m.pg[i]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var ped := UI.immagine(UI.tex("res://assets/pedine/%s.png" % p["id"]), 46, 46)
		if p["morto"]:
			ped.modulate = Color(0.3, 0.3, 0.3)
		h.add_child(ped)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var titolo := "%s" % p["nome"]
		if p["tipo"] == "pg":
			titolo += " (%s)" % m.giocatori[int(p["posto"])]["nome"]
		if i == m.primo:
			titolo += "  - primo giocatore"
		if p["fuori"]:
			titolo += "  - fuori dal campo"
		var lt := UI.etichetta(titolo, 18, UI.OCRA if i == m.primo else UI.PERGAMENA, true)
		v.add_child(lt)
		v.add_child(_traccia_ferite(i))
		var hd := HBoxContainer.new()
		hd.add_child(_icona_num("res://assets/segnalini/det.png", int(p["det"]), "Determinazione", 26))
		var lib := m.E.A.pedine_libere(i) if m.fase == "azione" else m.pedine_di(i)
		hd.add_child(UI.etichetta("  pedine %d" % lib, 16, UI.CENERE))
		var spec := []
		for parte in p["speciali"]:
			if int(p["speciali"][parte]) > 0:
				spec.append(parte)
		if not spec.is_empty():
			hd.add_child(UI.etichetta("  ferite speciali: " + ", ".join(spec), 16, UI.RUGGINE))
		if not p["vincoli"].is_empty():
			var vv := []
			if p["vincoli"].get("una_pedina", false):
				vv.append("una sola pedina")
			if p["vincoli"].has("solo"):
				vv.append("solo " + ", ".join(p["vincoli"]["solo"]))
			if p["vincoli"].get("no_abilita", false):
				vv.append("niente abilità")
			if not vv.is_empty():
				hd.add_child(UI.etichetta("  " + "; ".join(vv), 16, UI.RUGGINE))
		v.add_child(hd)
		var dati := Dati.personaggio(p["id"])
		var tip := ""
		for a in dati.get("abilita", []):
			tip += "%s: %s\n" % [a[0], a[1]]
		if int(p.get("inv", 0)) > 0:
			tip += "Invenzione personale: %s (costruendola +2 Determinazione)" % m.nome_carta(int(p["inv"]))
			h.add_child(_carta(int(p["inv"]), 40, 62))
		h.tooltip_text = tip
		box_pg.add_child(h)
	if m.scenario == 3 and m.jenny.get("salvata", false):
		var hj := HBoxContainer.new()
		hj.add_child(UI.immagine(UI.tex("res://assets/pedine/jenny.png"), 46, 46))
		hj.add_child(UI.etichetta("Jenny: %d ferite su %d" % [m.jenny["ferite"], m.jenny["max"]], 18))
		box_pg.add_child(hj)


## Traccia delle ferite: cuori, frecce del morale e teschio.
func _traccia_ferite(i: int) -> Control:
	var p: Dictionary = motore.pg[i]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 1)
	var n := 0
	var segs: Array = p["segmenti"]
	for s in segs.size():
		for k in int(segs[s]):
			n += 1
			var c := UI.immagine(UI.tex("res://assets/ui/cuore.png"), 20, 20)
			if n <= int(p["ferite"]):
				c.modulate = Color(0.75, 0.12, 0.08)
			h.add_child(c)
		if s < segs.size() - 1:
			var f := UI.immagine(UI.tex("res://assets/ui/freccia.png"), 26, 14)
			f.modulate = Color(1, 1, 1, 0.8)
			h.add_child(f)
	var t := UI.immagine(UI.tex("res://assets/ui/forza.png"), 20, 20)
	h.add_child(t)
	h.add_child(UI.etichetta("  %d/%d" % [p["ferite"], motore.max_ferite(i) - 1], 15, UI.CENERE))
	return h


func _aggiorna_inv() -> void:
	_svuota(box_inv)
	var m := motore
	var ter := m.terreni_esplorati()
	var lista: Array = m.invenzioni.duplicate()
	lista.sort_custom(func(a, b): return int(m.costruite.has(a)) > int(m.costruite.has(b)) or (m.costruite.has(a) == m.costruite.has(b) and a < b))
	for id in lista:
		var c := _carta(id, 78, 120)
		var costruita: bool = m.costruite.has(id)
		var ok := true
		for t in m.C[id].get("ter", []):
			if not ter.has(t):
				ok = false
		for k in m.C[id].get("inv", []):
			if not m.ha(k):
				ok = false
		if costruita:
			var bordo := ReferenceRect.new()
			bordo.border_color = Color(0.95, 0.8, 0.35)
			bordo.border_width = 3
			bordo.editor_only = false
			bordo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bordo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(bordo)
			var l := UI.etichetta("OGGETTO", 13, Color(1, 0.9, 0.5), true)
			l.position = Vector2(4, 100)
			c.add_child(l)
		elif not ok:
			c.modulate = Color(0.55, 0.55, 0.55)
		if m.scenario == 6 and id in m.inv_obiettivo:
			var st := UI.etichetta("obiettivo", 12, UI.MARE, true)
			st.position = Vector2(4, 2)
			c.add_child(st)
		box_inv.add_child(c)


func _aggiorna_cose() -> void:
	_svuota(box_cose)
	var m := motore
	for o in m.oggetti:
		var c := _carta(int(o["id"]), 64, 98)
		var l := UI.etichetta("x%d" % int(o["usi"]), 16, Color(1, 0.9, 0.5), true)
		l.position = Vector2(4, 76)
		c.add_child(l)
		box_cose.add_child(c)
	for t in m.tesori:
		box_cose.add_child(_carta(int(t["id"]), 64, 98))
	for t in m.notte_carte:
		var c2 := _carta(int(t["id"]), 64, 98)
		c2.modulate = Color(0.75, 0.75, 1.0)
		box_cose.add_child(c2)
	var nomi: Dictionary = Dati.scoperte()["nomi"]
	var testi: Dictionary = Dati.scoperte()["testi"]
	for s in m.scop:
		var im := UI.immagine(UI.tex("res://assets/segnalini/%s.png" % s), 52, 52)
		im.tooltip_text = "%s: %s" % [nomi.get(s, s), testi.get(s, "")]
		im.mouse_filter = Control.MOUSE_FILTER_PASS
		box_cose.add_child(im)
	for s in m.scop_fut:
		var im2 := UI.immagine(UI.tex("res://assets/segnalini/%s.png" % s), 52, 52)
		im2.modulate = Color(1, 1, 1, 0.5)
		im2.tooltip_text = "%s (disponibile a fine fase Azione): %s" % [nomi.get(s, s), testi.get(s, "")]
		im2.mouse_filter = Control.MOUSE_FILTER_PASS
		box_cose.add_child(im2)


# =====================================================================================
# ZOOM DELLE CARTE
# =====================================================================================

func _mostra_zoom(id: int, sorgente: Control) -> void:
	zoom_img.texture = UI.tex("res://assets/carte/%d.webp" % id)
	zoom_testo.text = testo_carta(motore, id)
	zoom.visible = true
	zoom.reset_size()
	var r := sorgente.get_global_rect()
	var pos := Vector2(r.end.x + 12, r.position.y - 120)
	if pos.x + 720 > size.x:
		pos.x = r.position.x - 720
	pos.y = clampf(pos.y, 60, size.y - 500)
	pos.x = clampf(pos.x, 0, size.x - 700)
	zoom.position = pos


func _nascondi_zoom() -> void:
	zoom.visible = false


static func testo_carta(m: Motore, id: int) -> String:
	if not m.C.has(id):
		return ""
	var c: Dictionary = m.C[id]
	var t := "[b]%s[/b]" % c["nome"]
	if c.get("nome_en", "") != "" and c["nome_en"] != c["nome"]:
		t += "  ([i]%s[/i])" % c["nome_en"]
	t += "\n"
	match c["tipo"]:
		"evento":
			if c.get("flavor", "") != "":
				t += "[i]%s[/i]\n" % c["flavor"]
			var sim: String = {"costruire": "segnalino Avventura sul mazzo Costruire", "raccogliere": "segnalino Avventura sul mazzo Raccogliere",
				"esplorare": "segnalino Avventura sul mazzo Esplorare", "libro": "effetto del libro dello scenario"}.get(c.get("simbolo", ""), "")
			if sim != "":
				t += "Simbolo: %s.\n" % sim
			t += "%s\n\n[b]Azione di minaccia: %s[/b]\nRichiede: %s\n%s\n\n[b]Effetto minaccia:[/b] %s" % [c.get("testo", ""), c.get("tr_nome", ""), c.get("tr_req", ""), c.get("tr_testo", ""), c.get("mn_testo", "")]
		"relitto":
			t += "[b]%s[/b]\n%s\nCon 1 pedina la ricompensa minore, con 2 quella maggiore." % [c.get("tr_nome", ""), c.get("tr_testo", "")]
		"avventura", "mistero":
			if c["tipo"] == "mistero":
				t += "Carta Mistero: %s.\n" % c.get("sottotipo", "")
			if c.get("flavor", "") != "":
				t += "[i]%s[/i]\n" % c["flavor"]
			t += c.get("testo", "")
			if c.get("ev_nome", "") != "":
				t += "\n\n[b]Se torna dal mazzo Eventi: %s[/b]\n%s" % [c["ev_nome"], c.get("ev_testo", "")]
		"invenzione":
			t += c.get("testo", "")
			var req := []
			for x in c.get("ter", []):
				req.append({"spiaggia": "spiaggia", "collina": "colline", "montagna": "montagne", "fiume": "fiume", "pianura": "pianura"}.get(x, x))
			for k in c.get("inv", []):
				req.append(m.nome_carta(m.id_inv(k)))
			t += "\n\nRichiede: %s" % (", ".join(req) if not req.is_empty() else "nulla")
			var costi := []
			for cst in c.get("costo", [{}]):
				var cc := []
				for r in cst:
					cc.append("%d %s" % [cst[r], m.nome_risorsa(r, int(cst[r]))])
				costi.append(", ".join(cc) if not cc.is_empty() else "gratis")
			t += "\nCosto: %s" % " oppure ".join(costi)
			if m.costruite.has(id):
				t += "\n[b]Costruita: è un Oggetto.[/b]"
		"belva":
			t += "Forza %d, arma %d, cibo %d, pellicce %d.\n%s" % [c.get("forza", 0), c.get("perdita_arma", 0), c.get("cibo", 0), c.get("pelliccia", 0), c.get("testo", "") if c.get("testo", "") != "None" else ""]
		_:
			t += c.get("testo", "")
	return t


# =====================================================================================
# SCELTE
# =====================================================================================

func chiedi_persona(_m: Motore, posto: int, req: Dictionary) -> int:
	_richiesta = req
	_in_attesa = true
	_aggiorna()
	_mostra_richiesta(posto, req)
	var r: int = await scelta_fatta
	_in_attesa = false
	_richiesta = {}
	_svuota(scelta_opzioni)
	scelta_titolo.text = ""
	scelta_testo.text = ""
	scelta_carta.custom_minimum_size = Vector2.ZERO
	scelta_carta.texture = null
	mappa.evidenziate = []
	mappa.queue_redraw()
	if tavolo3d != null:
		tavolo3d.evidenzia([])
	return r


func _mostra_richiesta(posto: int, req: Dictionary) -> void:
	var nome: String = motore.giocatori[posto]["nome"] if posto < motore.giocatori.size() else ""
	scelta_titolo.text = req.get("titolo", "")
	var persone := 0
	for g in motore.giocatori:
		if not g["ia"]:
			persone += 1
	var testo: String = req.get("testo", "")
	if persone > 1 and online == null:
		testo = "[color=#e8b86a]Tocca a %s.[/color] " % nome + testo
	scelta_testo.text = testo
	_svuota(scelta_opzioni)
	if req.has("carta") and int(req["carta"]) >= 0 and motore.C.has(int(req["carta"])):
		scelta_carta.texture = UI.tex("res://assets/carte/%d.webp" % int(req["carta"]))
		scelta_carta.custom_minimum_size = Vector2(90, 138)
		scelta_carta.mouse_entered.connect(_mostra_zoom.bind(int(req["carta"]), scelta_carta), CONNECT_ONE_SHOT)
	else:
		scelta_carta.texture = null
		scelta_carta.custom_minimum_size = Vector2.ZERO
	var opz: Array = req.get("opzioni", [])
	var caselle := []
	var gruppo := ""
	for k in opz.size():
		var o: Dictionary = opz[k]
		if req.get("tipo", "") == "piazza":
			var g: String = o.get("azione", "")
			if o.get("op", "") in ["annulla", "riposa_venerdi"]:
				g = "_altro"
			if g != gruppo:
				gruppo = g
				var lh := UI.etichetta(NOMI_AZIONE.get(g, "Altro"), 18, COLORI_AZIONE.get(g, UI.CENERE).lightened(0.35), true)
				scelta_opzioni.add_child(lh)
		var b := UI.bottone(("%d. " % (k + 1) if k < 9 else "") + o["testo"], 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if o.has("azione"):
			var col: Color = COLORI_AZIONE.get(o["azione"], UI.CENERE)
			var st := StyleBoxFlat.new()
			st.bg_color = col.darkened(0.55)
			st.border_color = col
			st.border_width_left = 6
			st.set_corner_radius_all(6)
			st.content_margin_left = 10
			st.content_margin_top = 3
			st.content_margin_bottom = 3
			b.add_theme_stylebox_override("normal", st)
			var st2 := st.duplicate()
			st2.bg_color = col.darkened(0.3)
			b.add_theme_stylebox_override("hover", st2)
		var cas := int(o.get("casella", -1))
		if cas >= 0:
			caselle.append(cas)
			b.mouse_entered.connect(func(): mappa.evidenziate = [cas]; mappa.queue_redraw(); if tavolo3d != null: tavolo3d.evidenzia([cas]))
			b.mouse_exited.connect(func(): mappa.evidenziate = _caselle_richiesta(); mappa.queue_redraw())
		var cid := int(o.get("carta", o.get("id", -1)))
		if cid >= 0 and motore.C.has(cid) and req.get("tipo", "") in ["invenzione", "oggetto", "piazza"]:
			b.mouse_entered.connect(_mostra_zoom.bind(cid, b))
			b.mouse_exited.connect(_nascondi_zoom)
		b.pressed.connect(_premi.bind(k))
		scelta_opzioni.add_child(b)
	mappa.evidenziate = caselle
	mappa.queue_redraw()
	if tavolo3d != null:
		tavolo3d.evidenzia(caselle)
	scelta_scroll.scroll_vertical = 0


func _caselle_richiesta() -> Array:
	var r := []
	for o in _richiesta.get("opzioni", []):
		if int(o.get("casella", -1)) >= 0:
			r.append(int(o["casella"]))
	return r


func _casella_cliccata(k: int) -> void:
	if not _in_attesa:
		return
	var opz: Array = _richiesta.get("opzioni", [])
	var trovate := []
	for j in opz.size():
		if int(opz[j].get("casella", -1)) == k:
			trovate.append(j)
	if trovate.size() == 1:
		_premi(trovate[0])
	elif trovate.size() > 1:
		# mostra solo le opzioni di quella casella in cima
		for j in range(trovate.size() - 1, -1, -1):
			var idx: int = trovate[j]
			for c in scelta_opzioni.get_children():
				if c is Button and c.text.begins_with("%d. " % (idx + 1)):
					scelta_opzioni.move_child(c, 0)
					c.grab_focus()
		scelta_scroll.scroll_vertical = 0


func mostra_pensiero(posto: int, req: Dictionary) -> void:
	if _in_attesa:
		return
	scelta_titolo.text = "%s ci pensa..." % motore.giocatori[posto]["nome"]
	scelta_testo.text = String(req.get("titolo", ""))
	_svuota(scelta_opzioni)


func _unhandled_key_input(ev: InputEvent) -> void:
	if not _in_attesa or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var n: int = ev.keycode - KEY_1
	if n >= 0 and n < 9 and n < _richiesta.get("opzioni", []).size():
		_premi(n)
		get_viewport().set_input_as_handled()


func _premi(k: int) -> void:
	if not _in_attesa:
		return
	_nascondi_zoom()
	scelta_fatta.emit(k)


# =====================================================================================
# EVENTI DEL MOTORE
# =====================================================================================

func _al_messaggio(t: String) -> void:
	if t.begins_with("— Round"):
		diario.append_text("\n[b]%s[/b]\n" % t.replace("—", "").strip_edges())
	else:
		diario.append_text(t + "\n")


func _al_evento(tipo: String, dati: Dictionary) -> void:
	if _ripresa:
		return
	match tipo:
		"carta":
			_mostra_carta(int(dati["id"]), String(dati.get("lato", "")))
		"dadi":
			_mostra_dadi(dati)
		"ferita":
			pass
	if tavolo3d != null and tavolo3d.visible:
		tavolo3d.al_evento(tipo, dati)


func _mostra_carta(id: int, lato: String) -> void:
	var titolo: String = {"evento": "Evento", "minaccia": "Minaccia non affrontata", "mistero": "Carta Mistero", "avventura": "Avventura", "belva": "Belva"}.get(lato, "")
	var p := UI.pannello(Color(0.1, 0.06, 0.03, 0.96), UI.OCRA)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var l := UI.titolo(titolo, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var im := UI.immagine(UI.tex("res://assets/carte/%d.webp" % id), 260, 400)
	v.add_child(im)
	popup_carte.add_child(p)
	p.reset_size()
	var n := popup_carte.get_child_count() - 1
	p.position = Vector2(size.x * 0.32 - p.size.x / 2 + n * 40, size.y * 0.5 - p.size.y / 2 + n * 20)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _mostra_dadi(d: Dictionary) -> void:
	var es: Dictionary = d["esiti"]
	var col: Color = COLORI_AZIONE.get(String(d["tipo"]), UI.CENERE)
	var p := UI.pannello(Color(0.1, 0.06, 0.03, 0.95), col)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	for x in [["successo", es["successo"] == "s", "SUCCESSO" if es["successo"] == "s" else "+2 DETERM."], ["ferita", es["ferita"] == "f", "FERITA" if es["ferita"] == "f" else "-"],
			["avventura", es["avventura"] == "?", "AVVENTURA" if es["avventura"] == "?" else "-"]]:
		var q := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = col
		st.set_corner_radius_all(10)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 18
		st.content_margin_bottom = 18
		q.add_theme_stylebox_override("panel", st)
		var lb := UI.etichetta(x[2], 20, Color.WHITE if x[1] else Color(1, 1, 1, 0.6), true)
		lb.custom_minimum_size.x = 120
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.add_child(lb)
		h.add_child(q)
	popup_carte.add_child(p)
	p.reset_size()
	p.position = Vector2(size.x * 0.32 - p.size.x / 2, size.y * 0.25)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _alla_fine(esito: String) -> void:
	if online != null:
		online.chiudi()
	else:
		cancella_salvataggio()
	_aggiorna()
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.z_index = 60
	add_child(fondo)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(cc)
	var p := UI.pannello(Color(0.18, 0.11, 0.07, 0.98), UI.OCRA)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var vinto := esito == "vittoria"
	var t := UI.titolo("Salvi! Lo scenario è vinto" if vinto else "L'isola ha vinto", 64, UI.OCRA if vinto else UI.RUGGINE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var ultimo := ""
	for x in range(motore.registro.size() - 1, -1, -1):
		if motore.registro[x] != "VITTORIA!" and motore.registro[x] != "Sconfitta.":
			ultimo = motore.registro[x]
			break
	var lt := UI.etichetta("%s\nRound %d di %d." % [ultimo, motore.round, int(motore.S.get("round", 12))], 22, UI.PERGAMENA)
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lt)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	v.add_child(hb)
	var b1 := UI.bottone("Rivedi il tavolo", 22)
	b1.pressed.connect(fondo.queue_free)
	hb.add_child(b1)
	var b2 := UI.bottone("Torna al menu", 22)
	b2.pressed.connect(_torna_menu)
	hb.add_child(b2)


# =====================================================================================
# VISTA 3D, SCENARIO, REGOLE, MENU, ONLINE
# =====================================================================================

func _imposta_3d(on: bool) -> void:
	vista3d = on
	var b: Button = find_child("B3D", true, false)
	if b != null and b.button_pressed != on:
		b.set_pressed_no_signal(on)
	if on and tavolo3d == null:
		tavolo3d = preload("res://scripts/ui/tavolo3d.gd").new()
		tavolo3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tavolo3d.vista = self
		area_mappa.add_child(tavolo3d)
	if tavolo3d != null:
		tavolo3d.visible = on
		if on:
			tavolo3d.aggiorna(motore)
	mappa.visible = not on


func _mostra_scenario() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.7)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.z_index = 65
	add_child(fondo)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 20)
	fondo.add_child(h)
	var im := UI.immagine(UI.tex("res://assets/scenari/%d.webp" % motore.scenario), 700, 980)
	h.add_child(im)
	var p := UI.pannello()
	p.custom_minimum_size = Vector2(620, 0)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var s := motore.S
	v.add_child(UI.titolo(s["nome"], 40))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size.x = 590
	rt.add_theme_font_size_override("normal_font_size", 20)
	rt.add_theme_font_override("bold_font", UI.font_grassetto)
	var dadi := []
	for r in s.get("meteo", {}):
		dadi.append("round %s: %s" % [r, ", ".join(s["meteo"][r])])
	rt.text = "[b]Obiettivo:[/b] %s\n\n[b]Round:[/b] %d\n[b]Meteo:[/b] %s\n[b]Libro:[/b] %s\n[b]Totem:[/b] %s\n\n[b]Segnalini speciali:[/b] %s" % [
		s["obiettivo"], s["round"], "; ".join(dadi) if not dadi.is_empty() else "nessun dado", s["libro"], s["totem"],
		", ".join(Dati.scoperte()["scenari"].get(str(motore.scenario), []).map(func(x): return "%s (%s)" % [Dati.scoperte()["nomi"].get(x["k"], x["k"]), Dati.scoperte()["testi"].get(x["k"], "")]))]
	v.add_child(rt)
	var b := UI.bottone("Chiudi", 20)
	b.pressed.connect(fondo.queue_free)
	v.add_child(b)


func _mostra_regole() -> void:
	var w := preload("res://scripts/ui/regole.gd").new()
	w.finestra = true
	w.z_index = 70
	add_child(w)


func _torna_menu() -> void:
	if online != null:
		online.alive = false
	main.show_menu()


func online_attesa(s: int) -> void:
	if s < 0:
		stato_online.text = ""
	else:
		stato_online.text = "In attesa di %s..." % motore.giocatori[s]["nome"]


func online_stato(t: String) -> void:
	stato_online.text = t
