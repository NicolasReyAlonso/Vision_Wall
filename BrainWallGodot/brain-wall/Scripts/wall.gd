extends Node3D

@export var speed: float = 1.0   # antes estaba en 5.0, ahora mucho más lento

func _process(delta: float) -> void:
	# Mover hacia la derecha local del objeto
	translate(transform.basis.x * speed * delta)
