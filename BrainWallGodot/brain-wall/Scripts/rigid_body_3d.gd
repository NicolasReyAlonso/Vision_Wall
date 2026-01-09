extends RigidBody3D

var water_level = 0.0          # Altura del agua en Y
var buoyancy_strength = 30.0   # Intensidad del empuje
var water_drag = 0.2           # Resistencia del agua

func _physics_process(delta):
	var object_y = global_transform.origin.y
	
	if object_y < water_level:
		# Profundidad sumergida
		var depth = water_level - object_y
		
		# Empuje proporcional a la profundidad
		var force = Vector3.UP * buoyancy_strength * depth
		
		apply_central_force(force)
		
		# Resistencia del agua para que no oscile demasiado
		linear_velocity *= (1.0 - water_drag * delta)
		angular_velocity *= (1.0 - water_drag * delta)
