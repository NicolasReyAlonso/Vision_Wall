extends CharacterBody3D

@export var speed: float = 2.0   # velocidad hacia la derecha

func _physics_process(delta: float) -> void:
	# Movimiento hacia la derecha local del objeto
	velocity = transform.basis.x * speed
	move_and_slide()
