class_name TutorialHintFrames
extends RefCounted

const HINT_SHEETS := {
	"res://assets/gifs/tap.gif": {
		"sheet": "res://assets/gifs/tap_sheet.png",
		"frames": 48,
		"cols": 8,
		"fps": 14.0,
	},
	"res://assets/gifs/move.gif": {
		"sheet": "res://assets/gifs/move_sheet.png",
		"frames": 31,
		"cols": 8,
		"fps": 30.0,
	},
	"res://assets/gifs/scale.gif": {
		"sheet": "res://assets/gifs/scale_sheet.png",
		"frames": 42,
		"cols": 7,
		"fps": 14.0,
	},
}

const CELL_TAP_SHEET := {
	"sheet": "res://assets/gifs/tap_sheet_cell.png",
	"frames": 48,
	"cols": 8,
	"fps": 14.0,
}

static var _cached: Dictionary = {}


static func frames_for(path: String) -> SpriteFrames:
	return _frames_for_meta(HINT_SHEETS.get(path, {}), path)


static func frames_for_cell_tap() -> SpriteFrames:
	return _frames_for_meta(CELL_TAP_SHEET, "cell_tap")


static func _frames_for_meta(meta: Dictionary, cache_key: String) -> SpriteFrames:
	if _cached.has(cache_key):
		return _cached[cache_key]

	if meta.is_empty():
		return null

	var sheet_tex := load(str(meta.get("sheet", ""))) as Texture2D
	if sheet_tex == null:
		return null

	var frame_count: int = int(meta.get("frames", 0))
	var cols: int = maxi(int(meta.get("cols", 1)), 1)
	var fps: float = float(meta.get("fps", 12.0))
	var rows: int = ceili(frame_count / float(cols))
	var frame_w: float = sheet_tex.get_width() / float(cols)
	var frame_h: float = sheet_tex.get_height() / float(rows)

	var frames := SpriteFrames.new()
	if !frames.has_animation("default"):
		frames.add_animation("default")
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", fps)

	for i in frame_count:
		var col: int = i % cols
		var row: int = i / cols
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet_tex
		atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
		frames.add_frame("default", atlas)

	_cached[cache_key] = frames
	return frames
