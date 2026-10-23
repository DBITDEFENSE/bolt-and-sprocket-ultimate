extends GutTest
## Graphics presets gate the costly lighting a map asks for (GLSettings._apply_env): SDFGI, SSIL and SSR stay on
## only when both the map's Environment wanted them and the preset allows them; a preset never adds one.

var _saved: Dictionary


func before_each() -> void:
	_saved = GLSettings.values.duplicate(true)


func after_each() -> void:
	GLSettings.values = _saved


func _we(sdfgi: bool, ssil: bool) -> WorldEnvironment:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.sdfgi_enabled = sdfgi
	we.environment.ssil_enabled = ssil
	return we


func test_low_strips_and_high_restores() -> void:
	var we: WorldEnvironment = _we(true, true)
	GLSettings.values["graphics_preset"] = "low"
	GLSettings._apply_env(we)
	assert_false(we.environment.sdfgi_enabled)
	assert_false(we.environment.ssil_enabled)
	GLSettings.values["graphics_preset"] = "medium"
	GLSettings._apply_env(we)
	assert_false(we.environment.sdfgi_enabled, "medium: no SDFGI")
	assert_true(we.environment.ssil_enabled, "medium keeps SSIL")
	GLSettings.values["graphics_preset"] = "high"
	GLSettings._apply_env(we)
	assert_true(we.environment.sdfgi_enabled, "the map's wish comes back on high")
	we.free()


func test_a_preset_never_adds_an_effect() -> void:
	var we: WorldEnvironment = _we(false, false)
	GLSettings.values["graphics_preset"] = "high"
	GLSettings._apply_env(we)
	assert_false(we.environment.sdfgi_enabled)
	assert_false(we.environment.ssil_enabled)
	assert_false(we.environment.ssr_enabled)
	we.free()
