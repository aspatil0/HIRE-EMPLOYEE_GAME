class_name Paint
extends RefCounted
## Static drawing helpers for the procedural placeholder art.
##
## All props/environments draw through these so the "illustrated" look stays
## consistent (soft radial shadows, gradient-shaded polygons, glows). When final
## hand-painted textures arrive, a prop's _draw() is simply replaced by a Sprite2D.

static var _radial: GradientTexture2D
static var _radial_hard: GradientTexture2D


## Soft round falloff texture (white, alpha 1 at center -> 0 at edge).
static func radial_texture() -> GradientTexture2D:
	if _radial == null:
		_radial = _make_radial(PackedFloat32Array([0.0, 0.35, 0.7, 1.0]), PackedFloat32Array([1.0, 0.55, 0.15, 0.0]))
	return _radial


## Tighter falloff, for bulbs and light sources.
static func radial_texture_hard() -> GradientTexture2D:
	if _radial_hard == null:
		_radial_hard = _make_radial(PackedFloat32Array([0.0, 0.2, 0.5, 1.0]), PackedFloat32Array([1.0, 0.85, 0.25, 0.0]))
	return _radial_hard


static func _make_radial(offsets: PackedFloat32Array, alphas: PackedFloat32Array) -> GradientTexture2D:
	var g := Gradient.new()
	var colors := PackedColorArray()
	for a in alphas:
		colors.append(Color(1, 1, 1, a))
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


# --- Shapes -----------------------------------------------------------------

static func rect_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func ellipse_points(center: Vector2, radius: Vector2, segments: int = 48, start: float = 0.0, end: float = TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var full := is_equal_approx(end - start, TAU)
	var count := segments if full else segments + 1
	for i in count:
		var a := start + (end - start) * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return pts


static func rounded_rect_points(r: Rect2, radius: float, seg: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var corners := [
		[Vector2(r.end.x - radius, r.position.y + radius), -PI * 0.5],
		[Vector2(r.end.x - radius, r.end.y - radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI * 0.5],
		[Vector2(r.position.x + radius, r.position.y + radius), PI],
	]
	for c in corners:
		for i in seg + 1:
			var a: float = c[1] + (PI * 0.5) * float(i) / float(seg)
			pts.append(c[0] + Vector2(cos(a), sin(a)) * radius)
	return pts


## Gradient-shaded rect, top colour to bottom colour.
static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(rect_points(r), PackedColorArray([top, top, bottom, bottom]))


static func hgrad(ci: CanvasItem, r: Rect2, left: Color, right: Color) -> void:
	ci.draw_polygon(rect_points(r), PackedColorArray([left, right, right, left]))


## Quad with per-corner colours (a,b,c,d clockwise).
static func quad(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color = ca, cc: Color = ca, cd: Color = ca) -> void:
	ci.draw_polygon(PackedVector2Array([a, b, c, d]), PackedColorArray([ca, cb, cc, cd]))


## Vertical-gradient quad: top edge a-b, bottom edge c-d.
static func quad_v(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, top: Color, bottom: Color) -> void:
	quad(ci, a, b, c, d, top, top, bottom, bottom)


## Any polygon, shaded top-to-bottom by each vertex's height.
static func poly_vgrad(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	var min_y := INF
	var max_y := -INF
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var span := maxf(max_y - min_y, 0.001)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - min_y) / span))
	ci.draw_polygon(pts, cols)


## Any polygon, shaded left-to-right.
static func poly_hgrad(ci: CanvasItem, pts: PackedVector2Array, left: Color, right: Color) -> void:
	var min_x := INF
	var max_x := -INF
	for p in pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
	var span := maxf(max_x - min_x, 0.001)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(left.lerp(right, (p.x - min_x) / span))
	ci.draw_polygon(pts, cols)


## Bilinear point inside quad a(top-left) b(top-right) c(bottom-right) d(bottom-left).
static func quad_point(a: Vector2, b: Vector2, c: Vector2, d: Vector2, u: float, v: float) -> Vector2:
	return a.lerp(b, u).lerp(d.lerp(c, u), v)


## Maps a unit-space rect into a (perspective) quad.
static func quad_rect(q: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		quad_point(q[0], q[1], q[2], q[3], r.position.x, r.position.y),
		quad_point(q[0], q[1], q[2], q[3], r.end.x, r.position.y),
		quad_point(q[0], q[1], q[2], q[3], r.end.x, r.end.y),
		quad_point(q[0], q[1], q[2], q[3], r.position.x, r.end.y),
	])


static func ellipse(ci: CanvasItem, center: Vector2, radius: Vector2, color: Color, segments: int = 48) -> void:
	ci.draw_colored_polygon(ellipse_points(center, radius, segments), color)


static func rounded_rect(ci: CanvasItem, r: Rect2, radius: float, color: Color) -> void:
	ci.draw_colored_polygon(rounded_rect_points(r, radius), color)


# --- Light and shadow ---------------------------------------------------------

## Soft elliptical shadow/glow using the radial falloff texture.
static func soft(ci: CanvasItem, center: Vector2, radius: Vector2, color: Color, hard: bool = false) -> void:
	var tex := radial_texture_hard() if hard else radial_texture()
	ci.draw_texture_rect(tex, Rect2(center - radius, radius * 2.0), false, color)


## Soft shadow under a rectangle-ish object (several overlapping radials).
static func soft_rect_shadow(ci: CanvasItem, r: Rect2, spread: float, color: Color) -> void:
	var steps := maxi(2, int(r.size.x / maxf(r.size.y, 1.0)) + 1)
	var c := color
	c.a = color.a / sqrt(float(steps))
	for i in steps:
		var t := (float(i) + 0.5) / float(steps)
		var cx := lerpf(r.position.x + r.size.y * 0.5, r.end.x - r.size.y * 0.5, t) if steps > 1 else r.get_center().x
		soft(ci, Vector2(cx, r.get_center().y), Vector2(r.size.y * 0.5 + spread, r.size.y * 0.5 + spread * 0.6), c)


## Thin highlight line, for bevels and edges catching light.
static func edge(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 1.5) -> void:
	ci.draw_line(a, b, color, width, true)


## Horizontal wood grain lines inside a polygon's bounding rows.
static func wood_grain(ci: CanvasItem, r: Rect2, color: Color, rows: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in rows:
		var y := r.position.y + r.size.y * (float(i) + rng.randf()) / float(rows)
		var pts := PackedVector2Array()
		var phase := rng.randf() * TAU
		var amp := rng.randf_range(0.6, 3.0)
		var freq := rng.randf_range(0.004, 0.012)
		var x := r.position.x
		while x <= r.end.x:
			pts.append(Vector2(x, y + sin(x * freq + phase) * amp))
			x += 24.0
		var c := color
		c.a *= rng.randf_range(0.4, 1.0)
		ci.draw_polyline(pts, c, rng.randf_range(0.8, 2.2), true)


## Lines of placeholder "text" (for documents, screens).
static func text_lines(ci: CanvasItem, origin: Vector2, width: float, line_h: float, count: int, color: Color, seed_value: int, thickness: float = 2.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var w := width * rng.randf_range(0.45, 1.0)
		if i == count - 1:
			w *= 0.6
		var y := origin.y + i * line_h
		ci.draw_line(Vector2(origin.x, y), Vector2(origin.x + w, y), color, thickness)


static func reset_transform(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
