extends SubViewportContainer
## Il tavolo in 3D: il tabellone originale del modulo TTS su un tavolo di legno, le tessere isola in rilievo,
## le pedine originali (gettoni rotondi con i ritratti), le carte nelle loro aree, le risorse con i modelli
## del modulo e le plance dei naufraghi davanti.
## Coordinate: 1 unità = 100 pixel dell'immagine del tabellone (4396 x 2599), origine al centro.
## Comandi: trascina con il tasto sinistro per ruotare, con il destro (o Maiusc + sinistro) per spostare,
## rotellina per avvicinare, frecce per spostare, doppio clic o R per la vista iniziale.

var vista
var sv: SubViewport
var cam: Camera3D
var perno: Node3D
var dinamici: Node3D
var _mat := {}
var _mesh := {}
var _rot := Vector2(-1.0, 0.0)
var _dist := 34.0
var _ruota := false
var _sposta := false
var _ultimo_id := -1
var _evidenziate: Array = []
var _m: Motore

const W := 43.96
const H := 25.99
const R_TESSERA := 2.14
const CARTA := Vector2(2.3, 3.55)
const CENTRO_VISTA := Vector3(0.0, 0.0, 3.0)
const MAPPA := preload("res://scripts/ui/mappa.gd")


static func px(x: float, y: float, h := 0.0) -> Vector3:
	return Vector3(x / 100.0 - W / 2.0, h, y / 100.0 - H / 2.0)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	sv = SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.anisotropic_filtering_level = Viewport.ANISOTROPY_8X
	add_child(sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.08, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.7, 0.62)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	sv.add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-55, 30, 0)
	sole.light_energy = 0.9
	sole.light_color = Color(1.0, 0.95, 0.85)
	sole.shadow_enabled = true
	sv.add_child(sole)
	perno = Node3D.new()
	sv.add_child(perno)
	cam = Camera3D.new()
	cam.fov = 45
	cam.far = 300
	perno.add_child(cam)
	perno.position = CENTRO_VISTA
	_aggiorna_camera()
	# il tavolo di legno
	var tav := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(70, 1.0, 50)
	tav.mesh = bm
	tav.position = Vector3(0, -0.52, 6)
	var ml := StandardMaterial3D.new()
	ml.albedo_texture = UI.tex("res://assets/ui/legno.webp")
	ml.uv1_scale = Vector3(3, 3, 3)
	ml.roughness = 0.85
	ml.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	tav.material_override = ml
	sv.add_child(tav)
	# il tabellone
	_piano(UI.tex("res://assets/tavolo/tabellone.webp"), Vector3(0, 0.01, 0), Vector2(W, H), 0.0, sv)
	dinamici = Node3D.new()
	sv.add_child(dinamici)
	var aiuto := UI.etichetta("Tasto sinistro: ruota  |  destro o Maiusc + sinistro: sposta  |  rotellina: avvicina  |  frecce: sposta  |  doppio clic o R: vista iniziale", 15, UI.CENERE)
	aiuto.position = Vector2(12, 8)
	aiuto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(aiuto)


func _process(delta: float) -> void:
	if not visible or not has_focus():
		return
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		d.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		d.x += 1
	if Input.is_key_pressed(KEY_UP):
		d.y -= 1
	if Input.is_key_pressed(KEY_DOWN):
		d.y += 1
	if d != Vector2.ZERO:
		_sposta_vista(d * delta * _dist * 0.8)


func _aggiorna_camera() -> void:
	_rot.x = clamp(_rot.x, -1.52, -0.3)
	_dist = clamp(_dist, 5.0, 80.0)
	perno.position.x = clamp(perno.position.x, -35.0, 35.0)
	perno.position.z = clamp(perno.position.z, -20.0, 30.0)
	perno.rotation = Vector3(0, _rot.y, 0)
	cam.position = Vector3(0, -sin(_rot.x) * _dist, cos(_rot.x) * _dist)
	cam.look_at(perno.global_position, Vector3.UP)


func _sposta_vista(d: Vector2) -> void:
	var destra := Vector3(cos(_rot.y), 0, -sin(_rot.y))
	var giu := Vector3(sin(_rot.y), 0, cos(_rot.y))
	perno.position += destra * d.x + giu * d.y
	_aggiorna_camera()


func reimposta_vista() -> void:
	_rot = Vector2(-1.0, 0.0)
	_dist = 34.0
	perno.position = CENTRO_VISTA
	_aggiorna_camera()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_dist *= 0.9
			_aggiorna_camera()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_dist *= 1.1
			_aggiorna_camera()
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				grab_focus()
				_ruota = not ev.shift_pressed
				_sposta = ev.shift_pressed
				var k := _casella_a(ev.position)
				if k >= 0 and k in _evidenziate:
					vista._casella_cliccata(k)
			else:
				_ruota = false
				_sposta = false
			if ev.double_click:
				reimposta_vista()
		elif ev.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_sposta = ev.pressed
			if ev.pressed:
				grab_focus()
		accept_event()
	elif ev is InputEventMouseMotion:
		if _sposta:
			_sposta_vista(-ev.relative * _dist / max(1.0, size.y) * 0.85)
			vista._nascondi_zoom()
		elif _ruota:
			_rot.y -= ev.relative.x * 0.006
			_rot.x -= ev.relative.y * 0.004
			_aggiorna_camera()
			vista._nascondi_zoom()
		else:
			_puntamento(ev.position)
	elif ev is InputEventPanGesture:
		_sposta_vista(ev.delta * _dist * 0.02)
		accept_event()
	elif ev is InputEventMagnifyGesture:
		_dist /= ev.factor
		_aggiorna_camera()
		accept_event()
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_R:
		reimposta_vista()


func _punto_tavolo(pos: Vector2) -> Variant:
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	return Plane(Vector3.UP, 0.1).intersects_ray(from, dir)


func _casella_a(pos: Vector2) -> int:
	var hit = _punto_tavolo(pos)
	if hit == null or _m == null:
		return -1
	for k in MAPPA.CENTRI.size():
		var c: Vector2 = MAPPA.CENTRI[k]
		if Vector2(hit.x, hit.z).distance_to(Vector2(c.x / 100.0 - W / 2.0, c.y / 100.0 - H / 2.0)) < R_TESSERA * 0.85:
			return k
	return -1


func _puntamento(pos: Vector2) -> void:
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var best := -1
	var best_d := 1e9
	for n in dinamici.get_children():
		if not n.has_meta("carta"):
			continue
		var hit = Plane(Vector3.UP, n.global_position).intersects_ray(from, dir)
		if hit == null:
			continue
		var loc: Vector3 = n.global_transform.affine_inverse() * hit
		var half: Vector2 = n.get_meta("mezza")
		if abs(loc.x) <= half.x and abs(loc.z) <= half.y:
			var d: float = from.distance_to(hit)
			if d < best_d:
				best_d = d
				best = int(n.get_meta("carta"))
	if best != _ultimo_id:
		_ultimo_id = best
		if best >= 0:
			var finto := Control.new()
			finto.position = pos
			vista.zoom_img.texture = UI.tex("res://assets/carte/%d.webp" % best)
			vista.zoom_testo.text = Partita.testo_carta(vista.motore, best)
			vista.zoom.visible = true
			vista.zoom.reset_size()
			var gp := get_global_rect().position + pos
			vista.zoom.position = Vector2(clampf(gp.x + 30, 0, vista.size.x - 720), clampf(gp.y - 200, 60, vista.size.y - 500))
			finto.free()
		else:
			vista._nascondi_zoom()


# =====================================================================================
# MATTONI
# =====================================================================================

func _mat_tex(t: Texture2D, illuminato := false) -> StandardMaterial3D:
	var k = [t, illuminato]
	if t == null:
		return _colore(Color(0.5, 0.4, 0.3))
	if not _mat.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_texture = t
		if not illuminato:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		_mat[k] = m
	return _mat[k]


func _colore(c: Color, trasparente := false) -> StandardMaterial3D:
	var k := "c" + c.to_html() + str(trasparente)
	if not _mat.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		if trasparente:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat[k] = m
	return _mat[k]


func _piano(t: Texture2D, pos: Vector3, dim: Vector2, rot: float, genitore: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = dim
	mi.mesh = pm
	mi.material_override = _mat_tex(t)
	mi.position = pos
	mi.rotation.y = rot
	(genitore if genitore != null else dinamici).add_child(mi)
	return mi


func _carta(id: int, pos: Vector3, scala := 1.0, dorso := -1) -> MeshInstance3D:
	var dim := CARTA * scala
	var t: Texture2D = UI.tex("res://assets/carte/%d.webp" % id) if dorso < 0 else UI.tex("res://assets/dorsi/%d.webp" % dorso)
	# un sottile spessore di cartone sotto la carta
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(dim.x * 0.99, 0.03, dim.y * 0.99)
	base.mesh = bm
	base.position = pos + Vector3(0, 0.015, 0)
	base.material_override = _colore(Color(0.25, 0.18, 0.12))
	dinamici.add_child(base)
	var mi := _piano(t, pos + Vector3(0, 0.035, 0), dim, 0.0)
	if dorso < 0:
		mi.set_meta("carta", id)
		mi.set_meta("mezza", dim / 2.0)
	return mi


func _pila(n: int, dorso: int, pos: Vector3, scala := 1.0) -> void:
	if n <= 0:
		return
	var h: float = 0.02 * min(n, 30)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CARTA.x * scala * 0.98, h, CARTA.y * scala * 0.98)
	mi.mesh = bm
	mi.position = pos + Vector3(0, h / 2.0, 0)
	mi.material_override = _colore(Color(0.9, 0.85, 0.75))
	dinamici.add_child(mi)
	_piano(UI.tex("res://assets/dorsi/%d.webp" % dorso), pos + Vector3(0, h + 0.004, 0), CARTA * scala, 0.0)
	_scritta(str(n), pos + Vector3(CARTA.x * scala * 0.5 + 0.35, 0.05, 0), 70, UI.PERGAMENA)


## Gettone rotondo di cartone (pedine e segnalini del modulo: «Custom_Tile» rotondi).
func _gettone(t: Texture2D, pos: Vector3, r := 0.45, spessore := 0.12, colore := Color(0.93, 0.9, 0.82)) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = spessore
	cm.radial_segments = 32
	mi.mesh = cm
	mi.position = pos + Vector3(0, spessore / 2.0, 0)
	mi.material_override = _colore(colore)
	dinamici.add_child(mi)
	_piano(t, pos + Vector3(0, spessore + 0.004, 0), Vector2(r * 2.0, r * 2.0), 0.0)


func _scritta(testo: String, pos: Vector3, size := 90, col := UI.OCRA) -> void:
	var lab := Label3D.new()
	lab.text = testo
	lab.font = UI.font_grassetto
	lab.font_size = size
	lab.pixel_size = 0.01
	lab.modulate = col
	lab.outline_size = 14
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	lab.rotation = Vector3(-PI / 2, 0, 0)
	lab.position = pos
	dinamici.add_child(lab)


func _modello(nome: String) -> Mesh:
	if not _mesh.has(nome):
		_mesh[nome] = load("res://assets/modelli/%s.obj" % nome) if ResourceLoader.exists("res://assets/modelli/%s.obj" % nome) else null
	return _mesh[nome]


func _risorsa(r: String, pos: Vector3, rot := 0.0) -> void:
	var mesh := _modello(r)
	var mi := MeshInstance3D.new()
	if mesh != null:
		mi.mesh = mesh
		mi.material_override = _mat_tex(UI.tex("res://assets/modelli/%s.webp" % r), true)
		mi.scale = Vector3.ONE * (0.55 if r == "legno" else 0.42)
		mi.rotation = Vector3(PI, rot, 0) if r != "legno" else Vector3(0, rot, 0)
		mi.position = pos + Vector3(0, 0.12, 0)
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.2, 0.2)
		mi.mesh = bm
		mi.position = pos + Vector3(0, 0.1, 0)
	dinamici.add_child(mi)


func _tessera(k: int, tex: Texture2D, scura := false) -> void:
	var c: Vector2 = MAPPA.CENTRI[k]
	var p := px(c.x, c.y)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = R_TESSERA
	cm.bottom_radius = R_TESSERA
	cm.height = 0.18
	cm.radial_segments = 6
	mi.mesh = cm
	mi.rotation.y = PI / 6.0 + PI / 2.0
	mi.position = p + Vector3(0, 0.09, 0)
	mi.material_override = _colore(Color(0.85, 0.8, 0.65))
	dinamici.add_child(mi)
	var top := _piano(tex, p + Vector3(0, 0.185, 0), Vector2(R_TESSERA * sqrt(3.0), R_TESSERA * 2.0), 0.0)
	if scura:
		var mt: StandardMaterial3D = _mat_tex(tex).duplicate()
		mt.albedo_color = Color(0.45, 0.42, 0.42)
		top.material_override = mt


# =====================================================================================
# AGGIORNAMENTO
# =====================================================================================

func evidenzia(caselle: Array) -> void:
	_evidenziate = caselle.duplicate()
	if _m != null and visible:
		aggiorna(_m)


func al_evento(_tipo: String, _dati: Dictionary) -> void:
	pass


func aggiorna(m: Motore) -> void:
	_m = m
	for c in dinamici.get_children():
		c.queue_free()
	# tessere
	for k in m.isola.size():
		if k == 10 and m.scenario != 5:
			continue
		var c: Dictionary = m.isola[k]
		var cc: Vector2 = MAPPA.CENTRI[k]
		var p := px(cc.x, cc.y, 0.2)
		if c.get("vulcano", false):
			_tessera(k, UI.tex("res://assets/tessere/vulcano.webp"))
		elif int(c["tessera"]) >= 0 and not c.get("coperta", false):
			_tessera(k, UI.tex("res://assets/tessere/%d.webp" % int(c["tessera"])), c["giu"])
		elif c.get("coperta", false) or int(c["tessera"]) == -2:
			_tessera(k, UI.tex("res://assets/tessere/retro.webp"))
		var segni := []
		for g in c["gettoni"]:
			if g in ["pericolo", "lento", "cibo_extra", "legno_extra", "scorciatoia"]:
				segni.append(g)
		if int(c.get("numero", 0)) > 0:
			segni.append("numero%d" % int(c["numero"]))
		for j in segni.size():
			_gettone(UI.tex("res://assets/segnalini/%s.png" % segni[j]), p + Vector3((j - (segni.size() - 1) / 2.0) * 0.8, 0, 0.55), 0.34, 0.08)
		for f in ["legno", "cibo"]:
			if c["esauriti"][f]:
				_gettone(null, p + Vector3(-0.9 if f == "legno" else 0.9, 0, 1.3), 0.25, 0.15, Color(0.06, 0.05, 0.05))
		if c["terreno_coperto"]:
			_gettone(null, p + Vector3(0, 0, 1.3), 0.25, 0.15, Color(0.06, 0.05, 0.05))
		if c["nebbia"] or c.get("cenere", false):
			var cubo := MeshInstance3D.new()
			var bmc := BoxMesh.new()
			bmc.size = Vector3(0.5, 0.5, 0.5)
			cubo.mesh = bmc
			cubo.position = p + Vector3(1.0, 0.25, -0.6)
			cubo.material_override = _colore(Color(0.95, 0.95, 0.95) if c["nebbia"] else Color(0.4, 0.4, 0.4))
			dinamici.add_child(cubo)
		if c["croce"]:
			var croce := MeshInstance3D.new()
			var bmx := BoxMesh.new()
			bmx.size = Vector3(0.45, 0.45, 0.45)
			croce.mesh = bmx
			croce.position = p + Vector3(-1.0, 0.22, -0.6)
			croce.material_override = _colore(Color(0.15, 0.3, 0.85))
			dinamici.add_child(croce)
		if k in _evidenziate:
			var hl := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = R_TESSERA * 1.06
			cm.bottom_radius = R_TESSERA * 1.06
			cm.height = 0.05
			cm.radial_segments = 6
			hl.mesh = cm
			hl.rotation.y = PI / 6.0 + PI / 2.0
			hl.position = p + Vector3(0, -0.15, 0)
			hl.material_override = _colore(Color(1.0, 0.85, 0.3, 0.45), true)
			dinamici.add_child(hl)
	# campo
	var cc2: Vector2 = MAPPA.CENTRI[m.campo]
	_gettone(UI.tex("res://assets/segnalini/%s.png" % ("rifugio" if m.rifugio else "campo")), px(cc2.x, cc2.y - 120, 0.2), 0.55, 0.12)
	# pedine sulle azioni pianificate
	var per_luogo := {}
	for a in m.piano:
		var k := int(a.get("casella", -1))
		var luogo: Vector3
		if a["tipo"] in ["raccogliere", "esplorare"] or (a["tipo"] == "costruire" and k >= 0 and k != m.campo):
			var c3: Vector2 = MAPPA.CENTRI[k]
			luogo = px(c3.x, c3.y + 30, 0.2)
		else:
			luogo = _luogo_azione(a)
		var chiave := "%.1f_%.1f" % [luogo.x, luogo.z]
		var n: int = per_luogo.get(chiave, 0)
		for i in a["pg"]:
			_gettone(UI.tex("res://assets/pedine/%s.png" % m.pg[i]["id"]), luogo + Vector3((n % 4) * 0.75 - 1.1, 0, int(n / 4) * 0.75), 0.36, 0.14)
			n += 1
		per_luogo[chiave] = n
	# minacce
	var slot_pos := [px(760, 2200), px(1110, 2200)]
	for s in 2:
		if m.minacce[s] >= 0:
			_carta(m.minacce[s], slot_pos[s] + Vector3(0, 0.02, 0), 1.0)
	# mazzi
	_pila(m.mazzo_eventi.size(), 4, px(420, 330), 0.8)
	var mazzi := {"costruire": [8, px(1930, 2250)], "raccogliere": [9, px(2370, 2250)], "esplorare": [10, px(2800, 2250)]}
	for t in mazzi:
		_pila(m.mazzi_avv[t].size(), mazzi[t][0], mazzi[t][1] + Vector3(0, 0.02, 0), 0.75)
		if m.gettoni_avv[t]:
			_gettone(UI.tex("res://assets/segnalini/avv_%s.png" % t), mazzi[t][1] + Vector3(0, 0.6, 0), 0.4, 0.08)
	_pila(m.mazzo_caccia.size(), 7, px(1500, 2250) + Vector3(0, 0.02, 0), 0.75)
	_pila(m.mazzo_misteri.size(), 5, px(80, 1900) + Vector3(-2.5, 0, 0), 0.8)
	_pila(m.mazzo_belve.size(), 7, px(80, 1300) + Vector3(-2.5, 0, 0), 0.8)
	# invenzioni nel foglio di destra
	var lista: Array = m.invenzioni.duplicate()
	for j in lista.size():
		var col := j % 6
		var riga := int(j / 6)
		var pos := px(2420 + col * 285, 900 + riga * 330, 0.02)
		if riga >= 3:
			pos = px(2420 + col * 285, 900 + 2 * 330, 0.02) + Vector3(0, 0.05 * (riga - 2), 0.4 * (riga - 2))
		var cm2 := _carta(int(lista[j]), pos, 0.78)
		if not m.costruite.has(int(lista[j])):
			var mt: StandardMaterial3D = _mat_tex(UI.tex("res://assets/carte/%d.webp" % int(lista[j]))).duplicate()
			mt.albedo_color = Color(0.7, 0.7, 0.7)
			cm2.material_override = mt
	# morale e livelli
	var x_morale := 1258.0 + (m.morale + 3) * 287.0
	_risorsa_indicatore(px(x_morale, 374, 0.02), Color(0.95, 0.95, 0.9))
	if m.rifugio:
		_gettone(UI.tex("res://assets/segnalini/rifugio.png"), px(2857, 600, 0.02), 0.5)
	_scritta("Tetto %d" % m.tetto, px(3187, 230, 0.05), 70, UI.PERGAMENA)
	_scritta("Palizzata %d" % m.palizzata, px(3480, 150, 0.05), 70, UI.PERGAMENA)
	_scritta("Arma %d" % m.arma, px(3880, 820, 0.05), 70, UI.PERGAMENA)
	# meteo
	var mx := 0
	for g in m.meteo:
		var nome: String = {"dado_belve": "pericolo"}.get(g, g)
		_gettone(UI.tex("res://assets/segnalini/%s.png" % nome), px(3720 + mx * 110, 2150, 0.02), 0.45)
		mx += 1
	# risorse nella cassa (risorse disponibili)
	var base := px(2440, 330, 0.05)
	var tipi := ["legno", "cibo", "cibo_np", "pelliccia"]
	for t in tipi.size():
		var n: int = int(m.ris[tipi[t]])
		for q in min(n, 8):
			_risorsa(tipi[t], base + Vector3(-1.4 + t * 0.95, q * 0.12, -0.7 + (q % 3) * 0.5), q * 0.6)
		if n > 0:
			_scritta(str(n), base + Vector3(-1.4 + t * 0.95, 0.4, 1.2), 70, UI.PERGAMENA)
	# scoperte
	for j in m.scop.size():
		_gettone(UI.tex("res://assets/segnalini/%s.png" % m.scop[j]), px(2900 + (j % 6) * 95, 100 + int(j / 6) * 95, 0.02), 0.42)
	# plance dei naufraghi davanti al tabellone
	var gg := m.giocanti()
	var larg := 10.0
	for j in gg.size():
		var i: int = gg[j]
		var p: Dictionary = m.pg[i]
		var cx := (j - (gg.size() - 1) / 2.0) * (larg + 0.6)
		var pos2 := Vector3(cx, 0.01, H / 2.0 + 2.7)
		_piano(UI.tex("res://assets/plance/%s.webp" % p["id"]), pos2, Vector2(larg, larg * 0.4), 0.0)
		# segnalino delle ferite sulla traccia
		var f := float(p["ferite"]) / float(m.max_ferite(i))
		var mesh := _modello("ferita")
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _mat_tex(UI.tex("res://assets/modelli/ferita.webp"), true)
		mi.scale = Vector3.ONE * 1.4
		mi.position = pos2 + Vector3(-larg * 0.25 + f * larg * 0.72, 0.15, larg * 0.4 * 0.37)
		dinamici.add_child(mi)
		_scritta("%s  -  Det. %d  -  ferite %d/%d%s" % [p["nome"], p["det"], p["ferite"], m.max_ferite(i) - 1, "  -  primo giocatore" if i == m.primo else ""],
			pos2 + Vector3(0, 0.05, -larg * 0.2 - 0.5), 60, UI.OCRA if i == m.primo else UI.PERGAMENA)
		var libere := m.E.A.pedine_libere(i) if m.fase == "azione" else m.pedine_di(i)
		for q in libere:
			_gettone(UI.tex("res://assets/pedine/%s.png" % p["id"]), pos2 + Vector3(-larg * 0.5 + 1.0 + q * 0.9, 0, -larg * 0.2 + 0.1), 0.4, 0.14)


func _luogo_azione(a: Dictionary) -> Vector3:
	match a["tipo"]:
		"minaccia":
			var s: int = _m.minacce.find(int(a["bers"]))
			return px(760 if s == 0 else 1110, 2200, 0.3)
		"caccia":
			return px(1500, 1980, 0.05)
		"costruire":
			match str(a["bers"]):
				"rifugio":
					return px(2857, 760, 0.05)
				"tetto":
					return px(3187, 760, 0.05)
				"palizzata":
					return px(3480, 760, 0.05)
				"arma":
					return px(3800, 760, 0.05)
			return px(1930, 1980, 0.05)
		"sistemare":
			return px(3200, 1980, 0.05)
		"riposo":
			return px(3200, 2380, 0.05)
	return px(2000, 2000, 0.05)


func _risorsa_indicatore(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.4
	cm.height = 0.4
	mi.mesh = cm
	mi.position = pos + Vector3(0, 0.2, 0)
	mi.material_override = _colore(col)
	dinamici.add_child(mi)
