#!/usr/bin/env python3
"""Patch a pristine Bukkbeek Godot 4.6 template for Android touch only."""
import sys
from pathlib import Path
src = Path(sys.argv[1]).resolve()
inp = src / "common/managers/input_manager.gd"
txt = inp.read_text()
anchor = "func _ready() -> void:\n\tInput.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)"
replacement = """func _ready() -> void:
\tif OS.get_name() == "Android":
\t\tInput.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
\t\tvar mobile_ui: CanvasLayer = preload("res://mobile/touch_hud.gd").new()
\t\tget_parent().call_deferred("add_child", mobile_ui)
\telse:
\t\tInput.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)"""
assert txt.count(anchor)==1, "Upstream input manager changed"
txt=txt.replace(anchor,replacement,1)
txt=txt.replace('if Input.is_action_just_pressed("exit"):', 'if OS.get_name() != "Android" and Input.is_action_just_pressed("exit"):')
inp.write_text(txt)
p=src/"project.godot"
txt=p.read_text()
assert 'window/size/viewport_width=1920' in txt
txt=txt.replace('config/name="fps-demo"','config/name="Bukkbeek XZIEL Mobile Touch"')
txt=txt.replace('window/size/viewport_width=1920','window/size/viewport_width=1280')
txt=txt.replace('window/size/viewport_height=1080','window/size/viewport_height=720')
txt+='\n[rendering]\nrenderer/rendering_method.mobile="mobile"\ntextures/vram_compression/import_etc2_astc=true\n\n[input_devices]\npointing/emulate_mouse_from_touch=false\n'
p.write_text(txt)
(src/"export_presets.cfg").write_text("""[preset.0]
name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/bukkbeek_xziel_touch_arm64.apk"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]
custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/export_format=0
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.1-touch"
package/unique_name="org.xziel.bukkbeektouch"
package/name="Bukkbeek XZIEL Touch"
package/signed=true
screen/orientation=4
screen/immersive_mode=true
graphics/opengl_debug=false
""")
assert (src/"mobile/touch_hud.gd").exists()
print("XZIEL Android touch overlay ready; Bukkbeek world, zombies, weapons retained")
