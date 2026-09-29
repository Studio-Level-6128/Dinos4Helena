extends Node

const SUPPORTED_LANGUAGES := ["en", "de", "fr"]
const DEFAULT_LANGUAGE := "en"
const SETTINGS_PATH := "user://settings.cfg"
const COOKIE_NAME := "dinos4helena_language"

var language := DEFAULT_LANGUAGE
var messages: Dictionary = {}


func _ready() -> void:
	set_language(_load_saved_language(), false)


func text(key: String, values: Array = []) -> String:
	var translated := str(messages.get(key, key))
	return translated if values.is_empty() else translated % values


func set_language(locale: String, remember := true) -> void:
	var normalized := locale.left(2).to_lower()
	if normalized not in SUPPORTED_LANGUAGES:
		normalized = DEFAULT_LANGUAGE
	var file := FileAccess.open("res://translations/%s.json" % normalized, FileAccess.READ)
	if file == null:
		push_error("Could not load translations for %s" % normalized)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid translation file for %s" % normalized)
		return
	language = normalized
	messages = parsed
	TranslationServer.set_locale(language)
	if remember:
		_save_language()


func _load_saved_language() -> String:
	var cookie_language := _read_language_cookie()
	if cookie_language in SUPPORTED_LANGUAGES:
		return cookie_language
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		var saved := str(settings.get_value("localization", "language", ""))
		if saved in SUPPORTED_LANGUAGES:
			return saved
	return DEFAULT_LANGUAGE


func _save_language() -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("localization", "language", language)
	var save_error := settings.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("Could not save language setting: %s" % error_string(save_error))
	_write_language_cookie()


func _read_language_cookie() -> String:
	if not OS.has_feature("web"):
		return ""
	var script := """(function () {
		var name = '%s=';
		var cookies = document.cookie.split(';');
		for (var i = 0; i < cookies.length; i++) {
			var value = cookies[i].trim();
			if (value.indexOf(name) === 0) return decodeURIComponent(value.substring(name.length));
		}
		return '';
	})()""" % COOKIE_NAME
	return str(JavaScriptBridge.eval(script))


func _write_language_cookie() -> void:
	if not OS.has_feature("web"):
		return
	var script := "document.cookie = '%s=' + encodeURIComponent('%s') + '; path=/; max-age=31536000; SameSite=Lax'" % [COOKIE_NAME, language]
	JavaScriptBridge.eval(script)
