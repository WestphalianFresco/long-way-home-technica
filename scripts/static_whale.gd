extends TextureRect
## Static species artwork: native alpha, fixed composition, no 3D viewport.
var species_id := "humpback"

func _ready() -> void:
	name = "WhalePortrait"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var path := "res://assets/whales/%s-v1.png" % species_id
	if ResourceLoader.exists(path):
		texture = load(path)
	else:
		push_error("Missing whale artwork: " + path)
