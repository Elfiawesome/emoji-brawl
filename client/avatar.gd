class_name Avatar extends Node2D

var target_position: Vector2
var is_local: bool = true

func _update_position(new_pos: Vector2) -> void:
	target_position = new_pos
	#position = target_position

func _process(delta: float) -> void:
	if !is_local:
		var tween := create_tween()
		tween.tween_property(self, "position", target_position, delta*4).set_ease(Tween.EASE_OUT)
		#position = lerp(position, target_position, 1-pow(0.5, delta*10))
	
