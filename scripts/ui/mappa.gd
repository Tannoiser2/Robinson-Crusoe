extends Control
## La mappa dell'isola sul tabellone originale: tessere esplorate, campo, segnalini, pedine pianificate.
## Le caselle da scegliere si illuminano; un clic su una casella illuminata la sceglie.

signal casella_cliccata(k: int)

## Centri delle caselle sul tabellone originale (4396 x 2599 px) e raggio degli esagoni.
const CENTRI := [Vector2(881, 900), Vector2(1253, 900), Vector2(1628, 900), Vector2(696, 1221), Vector2(1068, 1221),
	Vector2(1440, 1221), Vector2(1817, 1221), Vector2(881, 1543), Vector2(1253, 1543), Vector2(1628, 1543), Vector2(2006, 900)]
const R := 214.0
const ZONA := Rect2(440, 640, 1820, 1170)
const SCALA_TAB := 3200.0 / 4396.0

var m: Motore
var evidenziate: Array = []
var sopra := -1
var _tex_tab: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tex_tab = UI.tex("res://assets/tavolo/tabellone.webp")
	clip_contents = true


func _trasf() -> Array:
	var s: float = min(size.x / ZONA.size.x, size.y / ZONA.size.y)
	var off := (size - ZONA.size * s) / 2.0 - ZONA.position * s
	return [s, off]


func centro(k: int) -> Vector2:
	var t := _trasf()
	return CENTRI[k] * t[0] + t[1]


func _esagono(c: Vector2, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for a in range(-90, 270, 60):
		p.append(c + Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * r)
	return p


func _draw() -> void:
	if _tex_tab == null:
		return
	var t := _trasf()
	var s: float = t[0]
	var off: Vector2 = t[1]
	# fondo: la parte del tabellone con l'isola
	var src := Rect2(ZONA.position * SCALA_TAB, ZONA.size * SCALA_TAB)
	draw_texture_rect_region(_tex_tab, Rect2(ZONA.position * s + off, ZONA.size * s), src)
	if m == null:
		return
	var rr := R * s
	var w := rr * sqrt(3.0)
	for k in m.isola.size():
		if k == 10 and m.scenario != 5:
			continue
		var c: Dictionary = m.isola[k]
		var p := centro(k)
		var rect := Rect2(p - Vector2(w, rr * 2) / 2.0, Vector2(w, rr * 2))
		if c.get("vulcano", false):
			draw_texture_rect(UI.tex("res://assets/tessere/vulcano.webp"), rect, false)
		elif int(c["tessera"]) >= 0 and not c.get("coperta", false):
			var tx := UI.tex("res://assets/tessere/%d.webp" % int(c["tessera"]))
			draw_texture_rect(tx, rect, false, Color(0.45, 0.4, 0.4) if c["giu"] else Color.WHITE)
			if c["giu"]:
				draw_texture_rect(UI.tex("res://assets/tessere/retro.webp"), rect, false, Color(1, 1, 1, 0.85))
		elif c.get("coperta", false) or int(c["tessera"]) == -2:
			draw_texture_rect(UI.tex("res://assets/tessere/retro.webp"), rect, false)
		if c.get("lava", false):
			draw_colored_polygon(_esagono(p, rr * 0.98), Color(0.8, 0.2, 0.05, 0.45))
		if c["nebbia"]:
			draw_colored_polygon(_esagono(p, rr * 0.98), Color(0.95, 0.95, 1.0, 0.45))
		if c.get("cenere", false):
			draw_colored_polygon(_esagono(p, rr * 0.98), Color(0.3, 0.3, 0.3, 0.45))
		_segnalini(k, p, rr)
	# campo
	var pc := centro(m.campo)
	var tc := UI.tex("res://assets/segnalini/%s.png" % ("rifugio" if m.rifugio else "campo"))
	draw_texture_rect(tc, Rect2(pc + Vector2(-rr * 0.32, -rr * 0.86), Vector2(rr * 0.64, rr * 0.64)), false)
	# pedine pianificate
	var per_casella := {}
	for a in m.piano:
		var k := int(a.get("casella", -1))
		if a["tipo"] in ["raccogliere", "esplorare"] or (a["tipo"] == "costruire" and k >= 0 and k != m.campo):
			for i in a["pg"]:
				per_casella[k] = per_casella.get(k, []) + [m.pg[i]["id"]]
	for k in per_casella:
		var lista: Array = per_casella[k]
		var p2 := centro(k)
		for j in lista.size():
			var px := p2 + Vector2((j - (lista.size() - 1) / 2.0) * rr * 0.42, -rr * 0.1)
			draw_texture_rect(UI.tex("res://assets/pedine/%s.png" % lista[j]), Rect2(px - Vector2(rr, rr) * 0.2, Vector2(rr, rr) * 0.4), false)
	# evidenziate
	for k in evidenziate:
		if k < 0 or k >= CENTRI.size():
			continue
		var poly := _esagono(centro(k), rr * 0.96)
		poly.append(poly[0])
		draw_polyline(poly, Color(1.0, 0.85, 0.3, 0.95), max(3.0, rr * 0.05), true)
	if sopra >= 0:
		var poly2 := _esagono(centro(sopra), rr * 0.99)
		poly2.append(poly2[0])
		draw_polyline(poly2, Color(1, 1, 1, 0.7), 2.0, true)


func _segnalini(k: int, p: Vector2, rr: float) -> void:
	var c: Dictionary = m.isola[k]
	var icone := []
	for g in c["gettoni"]:
		if g in ["pericolo", "lento", "cibo_extra", "legno_extra", "scorciatoia"]:
			icone.append("res://assets/segnalini/%s.png" % g)
	if int(c.get("numero", 0)) > 0:
		icone.append("res://assets/segnalini/numero%d.png" % int(c["numero"]))
	var d := rr * 0.34
	for j in icone.size():
		var q := p + Vector2((j - (icone.size() - 1) / 2.0) * d * 1.05, rr * 0.30)
		draw_texture_rect(UI.tex(icone[j]), Rect2(q - Vector2(d, d) / 2.0, Vector2(d, d)), false)
	# fonti esaurite e terreno coperto: segnalini neri sul riquadro della tessera
	var basso := p + Vector2(0, rr * 0.62)
	if c["esauriti"]["legno"]:
		_disco(basso + Vector2(-rr * 0.45, 0), rr * 0.13, Color(0.08, 0.07, 0.06), "legno")
	if c["esauriti"]["cibo"]:
		_disco(basso + Vector2(rr * 0.45, 0), rr * 0.13, Color(0.08, 0.07, 0.06), "cibo")
	if c["terreno_coperto"]:
		_disco(basso + Vector2(0, -rr * 0.02), rr * 0.13, Color(0.08, 0.07, 0.06), "")
	if c["croce"]:
		_disco(p + Vector2(rr * 0.5, -rr * 0.45), rr * 0.13, Color(0.15, 0.3, 0.85), "")
	if c["bruciato"]:
		_disco(p + Vector2(-rr * 0.5, -rr * 0.45), rr * 0.13, Color(0.05, 0.05, 0.05), "")


func _disco(p: Vector2, r: float, col: Color, _testo: String) -> void:
	draw_circle(p, r, col)
	draw_arc(p, r, 0, TAU, 24, Color(0.9, 0.85, 0.7, 0.8), 1.5, true)


func casella_a(pos: Vector2) -> int:
	if m == null:
		return -1
	var t := _trasf()
	var rr: float = R * t[0]
	var best := -1
	var bd := rr * 0.9
	for k in CENTRI.size():
		if k == 10 and m.scenario != 5:
			continue
		var d := pos.distance_to(centro(k))
		if d < bd:
			bd = d
			best = k
	return best


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var k := casella_a(ev.position)
		if k != sopra:
			sopra = k
			tooltip_text = _descrizione(k)
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var k2 := casella_a(ev.position)
		if k2 >= 0:
			casella_cliccata.emit(k2)


func _descrizione(k: int) -> String:
	if k < 0 or m == null:
		return ""
	var c: Dictionary = m.isola[k]
	if c.get("vulcano", false):
		return "Il vulcano: inaccessibile."
	if int(c["tessera"]) < 0 or c.get("coperta", false):
		var d := m.distanza(k)
		return "Casella %d inesplorata%s." % [k + 1, (" (distanza dal campo %d)" % d) if d > 0 else ""]
	var t := "Casella %d, tessera %d: %s" % [k + 1, int(c["tessera"]), m.E.descrivi_tessera(int(c["tessera"]))]
	if k == m.campo:
		t += "\nQui c'è il campo%s." % (" con il rifugio" if m.rifugio else "")
	if c["giu"]:
		t += "\nInaccessibile."
	if c["esauriti"]["legno"] or c["esauriti"]["cibo"]:
		t += "\nFonti esaurite: %s." % ", ".join(["legno", "cibo"].filter(func(x): return c["esauriti"][x]))
	if c["nebbia"]:
		t += "\nNebbia: una pedina in più, terreno non conta."
	if c.get("cenere", false):
		t += "\nCenere: una pedina in più."
	for g in c["gettoni"]:
		t += "\nGettone: %s" % {"pericolo": "pericolo (arma almeno 1 o una ferita)", "lento": "azione lenta (una pedina in più)",
			"cibo_extra": "cibo extra", "legno_extra": "legno extra", "scorciatoia": "scorciatoia"}.get(g, g)
	if c["croce"]:
		t += "\nC'è una croce."
	return t
