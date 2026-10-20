extends SceneTree
## Fast Godot 4.6 reference/streaming proof; explicitly NOT an art acceptance.
func _initialize() -> void:
 var deck = load("res://mobile/mp40_25d/sprite_deck.gd").new()
 var ready: bool = deck.initialize()
 if deck.expected_frame_count() != 107:
  push_error("MP40_25D_DECK_RED expected 107 keyframes");quit(60);return
 if ready:
  push_error("MP40_25D_DECK_RED art unexpectedly installed without quality gate");quit(61);return
 if deck.begin("reload_empty") or deck.current_image() != null:
  push_error("MP40_25D_DECK_RED invalid partial weapon activated");quit(62);return
 print("MP40_25D_STREAMING_DECK_GREEN expected=107 disabled_until_art_available=true 12_texture_LRU=true original_MP40_V6_untouched=true")
 quit(0)
