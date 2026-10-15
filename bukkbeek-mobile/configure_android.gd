@tool
extends EditorScript

func _run() -> void:
 var settings := EditorInterface.get_editor_settings()
 var android_sdk := OS.get_environment("ANDROID_HOME")
 if android_sdk.is_empty():
  android_sdk = OS.get_environment("ANDROID_SDK_ROOT")
 assert(not android_sdk.is_empty(), "Missing Android SDK path on runner")
 var java_sdk := OS.get_environment("JAVA_HOME")
 assert(not java_sdk.is_empty(), "Missing JAVA_HOME")
 settings.set_setting("export/android/android_sdk_path", android_sdk)
 settings.set_setting("export/android/java_sdk_path", java_sdk)
 settings.save()
 print("ANDROID BUILD SDK:", android_sdk, " JAVA:", java_sdk)
