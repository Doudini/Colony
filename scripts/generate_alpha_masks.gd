@tool
extends EditorScript

## Run this script in the Godot editor to generate alpha mask textures
## Editor -> Run Script (or Ctrl+Shift+X)

const TILE_SIZE := 32  # Size of each mask tile in pixels
const MASK_COUNT := 16  # 16 marching squares configurations

func _run():
	print("Generating alpha masks...")

	# Create a 16x1 image (16 masks in a row)
	var img_width = TILE_SIZE * MASK_COUNT
	var img_height = TILE_SIZE

	var image = Image.create(img_width, img_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Start fully transparent

	# Generate each mask
	for mask_index in range(MASK_COUNT):
		_generate_mask(image, mask_index)

	# Save the image
	var save_path = "res://tex/alpha_masks.png"
	var err = image.save_png(save_path)
	if err == OK:
		print("✓ Alpha masks saved to: ", save_path)
	else:
		print("✗ Failed to save alpha masks: ", err)

	print("Done!")

func _generate_mask(image: Image, mask_index: int):
	"""
	Generate a single alpha mask based on marching squares index.

	Corner bits (for the TILE being rendered, not the corner grid):
	  Bit 0 (1): Top-left corner filled
	  Bit 1 (2): Top-right corner filled
	  Bit 2 (4): Bottom-right corner filled
	  Bit 3 (8): Bottom-left corner filled

	The mask determines where THIS terrain is visible.
	Where mask is 1.0 = terrain shows, where 0.0 = terrain below shows through
	"""
	var x_offset = mask_index * TILE_SIZE

	# Determine which corners are "filled" (terrain present)
	var tl = (mask_index & 1) != 0   # Top-left
	var tr = (mask_index & 2) != 0   # Top-right
	var br = (mask_index & 4) != 0   # Bottom-right
	var bl = (mask_index & 8) != 0   # Bottom-left

	# Generate pixels with smooth gradients
	for px in range(TILE_SIZE):
		for py in range(TILE_SIZE):
			# Normalized position (0 to 1)
			var nx = float(px) / float(TILE_SIZE - 1)
			var ny = float(py) / float(TILE_SIZE - 1)

			# Calculate alpha using bilinear interpolation of corners
			var alpha = _calculate_alpha(nx, ny, tl, tr, br, bl)

			# Apply smoothing/feathering
			alpha = _smooth_alpha(alpha)

			var color = Color(1, 1, 1, alpha)
			image.set_pixel(x_offset + px, py, color)

func _calculate_alpha(nx: float, ny: float, tl: bool, tr: bool, br: bool, bl: bool) -> float:
	"""
	Calculate alpha at position using bilinear interpolation of corner values.
	This creates smooth diagonal transitions.
	"""
	# Corner values (1.0 if filled, 0.0 if not)
	var v_tl = 1.0 if tl else 0.0
	var v_tr = 1.0 if tr else 0.0
	var v_br = 1.0 if br else 0.0
	var v_bl = 1.0 if bl else 0.0

	# Bilinear interpolation
	# Top edge interpolation
	var top = lerp(v_tl, v_tr, nx)
	# Bottom edge interpolation
	var bottom = lerp(v_bl, v_br, nx)
	# Final interpolation between top and bottom
	var alpha = lerp(top, bottom, ny)

	return alpha

func _smooth_alpha(alpha: float) -> float:
	"""
	Apply smoothstep for nicer gradient transitions.
	"""
	# Smoothstep function: 3x² - 2x³
	alpha = clamp(alpha, 0.0, 1.0)
	return alpha * alpha * (3.0 - 2.0 * alpha)
