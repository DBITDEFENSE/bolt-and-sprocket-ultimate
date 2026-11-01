extends SceneTree
## Rasterises gravelight/ui/wordmark/claude_zombies.svg to claude_zombies.png (2048 px wide, transparent) and the
## 256 px icon (the Z with the tally) to claude_zombies_icon.png + web/favicon.png. Headless:
## "$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/render_wordmark.gd

const DIR: String = "res://gravelight/ui/wordmark/"


func _init() -> void:
	var svg: String = FileAccess.get_file_as_string(DIR + "claude_zombies.svg")
	var img: Image = _render(svg)
	var err: int = OK if img != null else ERR_PARSE_ERROR
	if err != OK:
		push_error("render_wordmark: SVG failed (%d)" % err)
		quit(1)
		return
	if img.get_width() != 2048:
		img.resize(2048, int(round(img.get_height() * 2048.0 / img.get_width())), Image.INTERPOLATE_LANCZOS)
	img.save_png(DIR + "claude_zombies.png")
	print("wordmark ", img.get_size())
	var isvg: String = FileAccess.get_file_as_string(DIR + "claude_zombies_icon.svg")
	var icon: Image = _render(isvg)
	if icon == null:
		push_error("render_wordmark: icon SVG failed")
		quit(1)
		return
	icon.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	icon.save_png(DIR + "claude_zombies_icon.png")
	icon.save_png("res://web/favicon.png")
	print("icon ", icon.get_size())
	quit(0)


## The SVG's <g id="glow"> is a vector stand-in (the SVG rasteriser has no filters and ignores stroke-opacity):
## drop it, draw the lettering, then bake a real soft glow from the lettering's alpha and put it underneath.
func _render(svg: String) -> Image:
	var start: int = svg.find("<g id=\"glow\">")
	var end: int = svg.find("</g>", start) + 4
	var clean: String = svg.substr(0, start) + svg.substr(end)
	var top: Image = Image.new()
	if top.load_svg_from_string(clean, 1.0) != OK:
		return null
	var w: int = top.get_width()
	var h: int = top.get_height()
	top.convert(Image.FORMAT_RGBA8)
	var glow: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	glow.fill(Color(0.753, 0.49, 1.0, 1.0))
	var a: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var al: float = top.get_pixel(x, y).a
			if al > 0.0:
				a.set_pixel(x, y, Color(1, 1, 1, al))
	var out: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for r: Array in [[10, 0.45], [28, 0.4]]:   # [blur divisor, strength]
		var s: Image = a.duplicate()
		s.resize(maxi(8, w / int(r[0])), maxi(8, h / int(r[0])), Image.INTERPOLATE_BILINEAR)
		s.resize(w, h, Image.INTERPOLATE_BILINEAR)
		for y: int in h:
			for x: int in w:
				var ga: float = minf(1.0, s.get_pixel(x, y).a * float(r[1]) * 2.2)
				if ga > 0.002:
					var c: Color = out.get_pixel(x, y)
					var na: float = c.a + ga * (1.0 - c.a)
					out.set_pixel(x, y, Color(0.753, 0.49, 1.0, na))
	out.blend_rect(top, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return out
