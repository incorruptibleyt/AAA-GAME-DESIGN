class_name ShareCard
extends Control
## The Daily Crypt result as a little picture on the end screen: one square per room,
## coloured by how high the Bone Chain climbed in it, a skull for each boss beaten and a
## cross where the run ended. SHARE RESULT copies the same thing as emoji (game.gd).

## Square codes 0-3 are the chain colours; then these.
const BOSS := 4
const FELL := 5
const DARK := 6
## Each code as emoji: chain under x1.5, x1.5+, x2+, the very top of the chain, a boss
## beaten, where the run ended, not reached.
const EMOJI := ["⬜", "🟨", "🟧", "🟥", "💀", "❌", "⬛"]
const COLORS := [Color(0.96, 0.93, 0.84), Color(1.0, 0.8, 0.28), Color(1.0, 0.52, 0.18), Color(1.0, 0.25, 0.14)]
const CELL := 26.0
const GAP := 6.0

## One Array of codes per floor.
var rows: Array = []
var caption := ""
var _box := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_corner_radius_all(6)


## Which colour a room gets for the best chain in it (`top` is the chain's cap).
static func bucket(chain: float, top: float) -> int:
	if chain >= top - 0.01:
		return 3
	if chain >= 2.0:
		return 2
	if chain >= 1.5:
		return 1
	return 0


## The rows as emoji lines, for the share text.
static func emoji(card_rows: Array) -> String:
	var lines := []
	for row: Array in card_rows:
		lines.append("".join(row.map(func(code: int): return EMOJI[code])))
	return "\n".join(lines)


func show_rows(card_rows: Array, text: String) -> void:
	rows = card_rows
	caption = text
	custom_minimum_size = Vector2(0, rows.size() * (CELL + GAP) + (26.0 if caption != "" else 0.0))
	queue_redraw()


func _draw() -> void:
	var y := 0.0
	for row: Array in rows:
		var x := (size.x - (row.size() * (CELL + GAP) - GAP)) / 2.0
		for code: int in row:
			_cell(Rect2(x, y, CELL, CELL), code)
			x += CELL + GAP
		y += CELL + GAP
	if caption != "":
		draw_string(get_theme_default_font(), Vector2(0, y + 18), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Hud.GOLD)


func _cell(r: Rect2, code: int) -> void:
	var c := r.get_center()
	match code:
		DARK:
			_square(r, Color(1, 1, 1, 0.08))
		FELL:
			_square(r, Color(0.5, 0.07, 0.09))
			var k := 7.0
			draw_line(r.position + Vector2(k, k), r.end - Vector2(k, k), Color(1, 0.85, 0.8), 3.0)
			draw_line(Vector2(r.end.x - k, r.position.y + k), Vector2(r.position.x + k, r.end.y - k), Color(1, 0.85, 0.8), 3.0)
		BOSS:
			_square(r, Color(0.2, 0.14, 0.24))
			var bone := COLORS[0]
			var dark := Color(0.2, 0.14, 0.24)
			draw_circle(c + Vector2(0, -2), 8.0, bone)
			draw_rect(Rect2(c.x - 5, c.y + 2, 10, 6), bone)
			draw_circle(c + Vector2(-3.2, -2), 2.5, dark)
			draw_circle(c + Vector2(3.2, -2), 2.5, dark)
			for tx in [-2.0, 0.5, 3.0]:
				draw_line(c + Vector2(tx - 0.5, 5), c + Vector2(tx - 0.5, 8), dark, 1.2)
		_:
			_square(r, COLORS[code])


func _square(r: Rect2, col: Color) -> void:
	_box.bg_color = col
	draw_style_box(_box, r)
