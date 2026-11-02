class_name UI
## Tema e piccoli mattoni dell'interfaccia: legno di naufragio, pergamena, inchiostro e mare dell'isola maledetta.

const ROCCIA := Color(0.17, 0.11, 0.07)
const ROCCIA_CHIARA := Color(0.30, 0.20, 0.13)
const OCRA := Color(0.91, 0.72, 0.42)
const OCRA_SCURA := Color(0.58, 0.40, 0.20)
const RUGGINE := Color(0.70, 0.20, 0.13)
const PERGAMENA := Color(0.95, 0.90, 0.78)
const INCHIOSTRO := Color(0.22, 0.14, 0.08)
const CENERE := Color(0.80, 0.75, 0.66)
const VERDE := Color(0.45, 0.66, 0.38)
const NOTTE := Color(0.16, 0.20, 0.30)
const MARE := Color(0.28, 0.58, 0.60)

static var font_titolo: Font
static var font_logo: Font
static var font_testo: Font
static var font_grassetto: Font
static var font_corsivo: Font
static var font_diario: Font
static var _tex := {}


static func carica_font() -> void:
	if font_testo != null:
		return
	font_titolo = load("res://assets/fonts/IMFellEnglishSC-Regular.ttf")
	font_logo = load("res://assets/fonts/IMFellEnglishSC-Regular.ttf")
	font_testo = load("res://assets/fonts/Alegreya.ttf")
	var fb := FontVariation.new()
	fb.base_font = font_testo
	fb.variation_opentype = {"wght": 700}
	font_grassetto = fb
	font_corsivo = load("res://assets/fonts/Alegreya-Italic.ttf")
	font_diario = load("res://assets/fonts/Caveat.ttf")


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func carta_tex(id: int) -> Texture2D:
	return tex("res://assets/carte/%d.webp" % id)


static func dorso_tex(n: int) -> Texture2D:
	return tex("res://assets/dorsi/%d.webp" % n)


static func attrezzo_tex(t: String) -> Texture2D:
	return tex("res://assets/segnalini/%s.webp" % t)


static func icona(nome: String) -> Texture2D:
	return tex("res://assets/ui/%s.png" % nome)


static func make_theme() -> Theme:
	carica_font()
	var t := Theme.new()
	t.default_font = font_testo
	t.default_font_size = 20
	t.set_color("font_color", "Label", PERGAMENA)
	t.set_color("default_color", "RichTextLabel", PERGAMENA)
	t.set_font("bold_font", "RichTextLabel", font_grassetto)
	t.set_font("italics_font", "RichTextLabel", font_corsivo)
	# pulsanti a forma di pietra levigata
	var n := _stile_pietra(Color(0.38, 0.27, 0.19), OCRA_SCURA)
	var h := _stile_pietra(Color(0.50, 0.34, 0.22), OCRA)
	var p := _stile_pietra(Color(0.62, 0.36, 0.16), OCRA)
	var d := _stile_pietra(Color(0.26, 0.20, 0.16), Color(0.35, 0.28, 0.22))
	t.set_stylebox("normal", "Button", n)
	t.set_stylebox("hover", "Button", h)
	t.set_stylebox("pressed", "Button", p)
	t.set_stylebox("disabled", "Button", d)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PERGAMENA)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.5))
	t.set_font("font", "Button", font_grassetto)
	t.set_font_size("font_size", "Button", 20)
	# campi di testo
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.12, 0.08, 0.06, 0.9)
	le.border_color = OCRA_SCURA
	le.set_border_width_all(2)
	le.set_corner_radius_all(8)
	le.content_margin_left = 10
	le.content_margin_right = 10
	le.content_margin_top = 6
	le.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", PERGAMENA)
	t.set_stylebox("normal", "OptionButton", n)
	t.set_stylebox("hover", "OptionButton", h)
	t.set_stylebox("pressed", "OptionButton", p)
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", PERGAMENA)
	t.set_font("font", "OptionButton", font_grassetto)
	var pm := StyleBoxFlat.new()
	pm.bg_color = Color(0.22, 0.15, 0.11)
	pm.border_color = OCRA_SCURA
	pm.set_border_width_all(2)
	pm.set_corner_radius_all(8)
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_color("font_color", "PopupMenu", PERGAMENA)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_font("font", "PopupMenu", font_testo)
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_color("font_color", "CheckBox", PERGAMENA)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", PERGAMENA)
	t.set_font("font", "CheckBox", font_testo)
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	var tt := StyleBoxFlat.new()
	tt.bg_color = Color(0.12, 0.08, 0.06, 0.96)
	tt.border_color = OCRA
	tt.set_border_width_all(2)
	tt.set_corner_radius_all(6)
	tt.content_margin_left = 10
	tt.content_margin_right = 10
	tt.content_margin_top = 6
	tt.content_margin_bottom = 6
	t.set_stylebox("panel", "TooltipPanel", tt)
	t.set_color("font_color", "TooltipLabel", PERGAMENA)
	t.set_font("font", "TooltipLabel", font_testo)
	t.set_font_size("font_size", "TooltipLabel", 18)
	# barre di scorrimento sottili
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.55, 0.22, 0.55)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0, 0, 0, 0.18)
	sbg.set_corner_radius_all(4)
	sbg.content_margin_left = 4
	sbg.content_margin_right = 4
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", cls, sb)
		t.set_stylebox("grabber_highlight", cls, sb)
		t.set_stylebox("grabber_pressed", cls, sb)
		t.set_stylebox("scroll", cls, sbg)
	return t


static func _stile_pietra(bg: Color, bordo: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bordo
	s.set_border_width_all(2)
	s.border_width_bottom = 4
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 9
	s.corner_radius_bottom_right = 16
	s.corner_radius_bottom_left = 8
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 7
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	return s


## Pannello "pelle conciata" scuro con bordo ocra.
static func pannello(colore := Color(0.20, 0.14, 0.10, 0.92), bordo := OCRA_SCURA) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = colore
	s.border_color = bordo
	s.set_border_width_all(2)
	s.corner_radius_top_left = 18
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_right = 20
	s.corner_radius_bottom_left = 12
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 6
	p.add_theme_stylebox_override("panel", s)
	return p


## Pannello chiaro "pergamena" (testi da leggere).
static func pergamena() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxTexture.new()
	s.texture = tex("res://assets/ui/pergamena.webp")
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", s)
	return p


static func titolo(testo: String, size := 40, col := OCRA) -> Label:
	carica_font()
	var l := Label.new()
	l.text = testo
	l.add_theme_font_override("font", font_titolo)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func etichetta(testo: String, size := 20, col := PERGAMENA, grassetto := false) -> Label:
	carica_font()
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if grassetto:
		l.add_theme_font_override("font", font_grassetto)
	return l


static func immagine(t: Texture2D, w: float, h: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func bottone(testo: String, size := 20) -> Button:
	var b := Button.new()
	b.text = testo
	b.add_theme_font_size_override("font_size", size)
	return b


## Contatore con icona: [icona] n
static func contatore(t: Texture2D, n: int, size := 22, tip := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.add_child(immagine(t, size * 1.4, size * 1.4))
	var l := etichetta(str(n), size, PERGAMENA, true)
	h.add_child(l)
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h
