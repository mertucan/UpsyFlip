extends SceneTree
## Generates the Android launcher icons from icon.svg.
## Usage: godot --headless --path . --script res://tools/make_icons.gd
##
## Output (res://art/icon/):
##   icon_192.png                 legacy launcher icon
##   icon_foreground_432.png      adaptive icon foreground (art inside the safe zone)
##   icon_background_432.png      adaptive icon background (solid color)
##   icon_512.png                 Play Store listing icon
## Replace icon.svg (or these PNGs) with the final artwork and run again.

const SOURCE_PATH: String = "res://icon.svg"
const OUTPUT_DIR: String = "res://art/icon/"
const SOURCE_SIZE: float = 128.0
const ADAPTIVE_SIZE: int = 432
## Android masks adaptive icons; only the central ~66% is always visible.
const SAFE_ZONE: float = 0.62
const BACKGROUND_COLOR: Color = Color("1d2440")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var svg: String = FileAccess.get_file_as_string(SOURCE_PATH)

	_render(svg, 192.0 / SOURCE_SIZE).save_png(OUTPUT_DIR + "icon_192.png")
	_render(svg, 512.0 / SOURCE_SIZE).save_png(OUTPUT_DIR + "icon_512.png")

	# Foreground: the artwork without its background plate, inside the safe zone.
	var art_size: int = roundi(ADAPTIVE_SIZE * SAFE_ZONE)
	var art: Image = _render(_without_background(svg), art_size / SOURCE_SIZE)
	var foreground: Image = Image.create_empty(ADAPTIVE_SIZE, ADAPTIVE_SIZE, false, Image.FORMAT_RGBA8)
	var offset: int = (ADAPTIVE_SIZE - art.get_width()) / 2
	foreground.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(offset, offset))
	foreground.save_png(OUTPUT_DIR + "icon_foreground_432.png")

	var background: Image = Image.create_empty(ADAPTIVE_SIZE, ADAPTIVE_SIZE, false, Image.FORMAT_RGBA8)
	background.fill(BACKGROUND_COLOR)
	background.save_png(OUTPUT_DIR + "icon_background_432.png")

	print("Icons written to ", OUTPUT_DIR)
	quit()


func _render(svg: String, scale: float) -> Image:
	var image: Image = Image.new()
	image.load_svg_from_string(svg, scale)
	image.convert(Image.FORMAT_RGBA8)
	return image


## Drops the first <rect .../> element, which is the icon's background plate.
func _without_background(svg: String) -> String:
	var start: int = svg.find("<rect")
	if start < 0:
		return svg
	var end: int = svg.find("/>", start)
	return svg.substr(0, start) + svg.substr(end + 2)
