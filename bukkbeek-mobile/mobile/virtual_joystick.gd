extends Control
## Functional analog movement joystick for Android.
## This is NOT an action-button skin: the other 12 controls retain exactly the
## official XZIEL approved PNGs. No legacy circle/button PNGs are reintroduced.
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
 var side := minf(size.x, size.y)
 if side <= 0.0:
  return
 var center := size * 0.5
 var radius := side * 0.42
 var knob := center + direction.limit_length(1.0) * radius * 0.65
 # Dark glass footprint, fine outline and moveable thumb cap; no touch events
 # are consumed here (all multitouch ownership belongs to touch_hud.gd).
 draw_circle(center, radius, Color(0.02, 0.06, 0.10, 0.19))
 draw_arc(center, radius, 0.0, TAU, 72, Color(0.79, 0.91, 1.0, 0.34), maxf(2.0, side * 0.012), true)
 draw_line(center, knob, Color(0.65, 0.84, 1.0, 0.29), maxf(2.0, side * 0.035), true)
 draw_circle(knob, side * 0.16, Color(0.13, 0.27, 0.41, 0.54))
 draw_arc(knob, side * 0.16, 0.0, TAU, 48, Color(0.91, 0.97, 1.0, 0.62), maxf(2.0, side * 0.012), true)
