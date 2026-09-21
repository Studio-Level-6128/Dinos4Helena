extends SceneTree


func _initialize() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var editor_settings := EditorInterface.get_editor_settings()
	editor_settings.set_setting("export/android/java_sdk_path", root.path_join(".tools/jdk-17"))
	editor_settings.set_setting("export/android/android_sdk_path", root.path_join(".tools/android-sdk"))
	editor_settings.set_setting("text_editor/external/use_external_editor", true)
	editor_settings.set_setting("text_editor/external/exec_path", "/usr/bin/code")
	editor_settings.set_setting("text_editor/external/exec_flags", "{project} --goto {file}:{line}:{col}")
	quit()
