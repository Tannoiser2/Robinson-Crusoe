extends Control
## Radice dell'applicazione: alterna menu, partita e regole.

var current: Control
## Collegamento a Firebase per il gioco online (resta vivo fra menu e partita).
var net: Net
## Stanza online in preparazione: {role, code, seat}. Vuota se non si è in una stanza.
var lobby := {}
## Ultime scelte del menu (si ritrovano tornando al menu).
var menu_state := {}


func get_net() -> Net:
	if net == null:
		net = Net.new()
		add_child(net)
	return net


func _ready() -> void:
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/ui/legno.webp")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var vign := ColorRect.new()
	vign.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 d = UV - vec2(0.5); float v = smoothstep(0.35, 0.85, length(d * vec2(1.2, 1.0))); COLOR = vec4(0.03, 0.015, 0.0, v * 0.75); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vign.material = mat
	add_child(vign)
	show_menu()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _clear() -> void:
	if current != null:
		current.queue_free()
		current = null


func show_menu() -> void:
	_clear()
	var m := preload("res://scripts/ui/menu.gd").new()
	m.main = self
	add_child(m)
	current = m


func start_game(config: Dictionary) -> void:
	_clear()
	var g := preload("res://scripts/ui/partita.gd").new()
	g.main = self
	g.config = config
	add_child(g)
	current = g


func show_rules() -> void:
	_clear()
	var t := preload("res://scripts/ui/regole.gd").new()
	t.main = self
	add_child(t)
	current = t
