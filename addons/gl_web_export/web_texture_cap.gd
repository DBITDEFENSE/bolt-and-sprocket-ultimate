@tool
extends EditorExportPlugin
## UPDATE 09 section 2c (DECISIONS T-139): the browser build's texture cap. Godot 4.7 has no per-platform import
## override and no export-time size limit, so this export plugin does it: in an export whose features include "web",
## every VRAM-compressed 3D texture larger than CAP px on its long side is decompressed, shrunk to CAP (Lanczos),
## re-mipmapped and re-compressed in the same family (S3TC / BPTC / RGTC for normal maps) as a
## PortableCompressedTexture2D. Lossless / uncompressed textures (UI, the minimap's floor images, fonts) are left
## alone: they are 2D and read pixel for pixel. Desktop exports and the editor never see this.

const CAP: int = 1024

var _web: bool = false
var shrunk: int = 0
var saved_px: int = 0


func _get_name() -> String:
	return "GLWebTextureCap"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform.get_os_name() == "Web"


func _begin_customize_resources(platform: EditorExportPlatform, features: PackedStringArray) -> bool:
	_web = features.has("web")
	shrunk = 0
	saved_px = 0
	return _web


func _get_customization_configuration_hash() -> int:
	return hash("gl_web_texture_cap_%d_v2" % CAP)


func _end_customize_resources() -> void:
	if _web and shrunk > 0:
		print("[web_texture_cap] %d textures capped at %d px (%.1f Mpx fewer)" % [shrunk, CAP, saved_px / 1.0e6])


func _customize_resource(resource: Resource, path: String) -> Resource:
	if not _web or not (resource is CompressedTexture2D or resource is PortableCompressedTexture2D):
		return null
	# A scene's walk hands us its external textures too (path ""): returning a copy would embed it in every scene
	# that uses it. The file gets its own call (path set), so only built-in subresources are handled here.
	if path == "" and resource.resource_path != "" and not resource.resource_path.contains("::"):
		return null
	var tex: Texture2D = resource as Texture2D
	if maxi(tex.get_width(), tex.get_height()) <= CAP:
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty() or not img.is_compressed():
		return null
	var out: Texture2D = cap_image(img)
	if out == null:
		return null
	shrunk += 1
	saved_px += tex.get_width() * tex.get_height() - out.get_width() * out.get_height()
	return out


## The shrink itself (static so a unit test can price it without an export): returns null when nothing changes.
static func cap_image(src: Image, cap: int = CAP) -> PortableCompressedTexture2D:
	var w: int = src.get_width()
	var h: int = src.get_height()
	if maxi(w, h) <= cap:
		return null
	var fmt: Image.Format = src.get_format()
	var normal: bool = fmt == Image.FORMAT_RGTC_RG
	var mode: PortableCompressedTexture2D.CompressionMode = PortableCompressedTexture2D.COMPRESSION_MODE_S3TC
	if fmt == Image.FORMAT_BPTC_RGBA or fmt == Image.FORMAT_BPTC_RGBF or fmt == Image.FORMAT_BPTC_RGBFU:
		mode = PortableCompressedTexture2D.COMPRESSION_MODE_BPTC
	var img: Image = src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	if img.has_mipmaps():
		img.clear_mipmaps()
	var k: float = float(cap) / float(maxi(w, h))
	img.resize(maxi(1, int(round(w * k))), maxi(1, int(round(h * k))), Image.INTERPOLATE_LANCZOS)
	if src.has_mipmaps():
		img.generate_mipmaps(normal)
	var p: PortableCompressedTexture2D = PortableCompressedTexture2D.new()
	p.create_from_image(img, mode, normal)
	return p
