extends Node3D

@onready var mp = $MediaPipePose
@onready var plane = $CameraPlane


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if mp.has_camera_texture():
		plane.material_override.albedo_texture = mp.get_camera_texture()
	pass
