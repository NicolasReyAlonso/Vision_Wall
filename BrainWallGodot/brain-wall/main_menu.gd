extends Control
@export var soundEffectHover: AudioStreamPlayer
@export var soundEffectclick: AudioStreamPlayer
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_button_pressed() -> void:
	soundEffectclick.pitch_scale = 1
	soundEffectclick.play()
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")
	pass # Replace with function body.


func _on_play_button_2_pressed() -> void:
	soundEffectclick.pitch_scale = 0.8
	soundEffectclick.play()
	get_tree().quit()
	pass # Replace with function body.


func _on_play_button_mouse_entered() -> void:
	soundEffectHover.pitch_scale = 1
	soundEffectHover.play()
	pass # Replace with function body.

func _on_play_button_2_mouse_entered() -> void:
	soundEffectHover.pitch_scale = 0.8
	soundEffectHover.play()
	pass # Replace with function body.
