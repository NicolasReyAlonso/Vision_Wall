# PoseReceiver.gd
extends Node3D

@export var target_height: float = 2.0   # altura deseada en metros dentro del juego

@export var eleven_scene: PackedScene  # Escena de Eleven
@export var audioStreamPlayer: AudioStreamPlayer3D
@export var nodevec: Node3D
var offset: Vector3  # Desplazamiento global
@export var scale_factor: float = 0.7            # Escala global
@export var depth_scale: float = 2.0             # Escala para la profundidad (Z)
@export var mirror_mode: bool = false            # Espejo (false = movimiento natural)
@export var model_scale: float = 1.0             # Escala adicional del personaje

var socket := WebSocketPeer.new()
var players_data: Array = []           # Datos de poses de todos los jugadores
var players_models: Array = []         # Modelos de Eleven por jugador
var players_skeletons: Array = []      # Esqueletos de Eleven por jugador
var bone_names_printed: bool = false   # Para imprimir nombres de huesos solo una vez

const KEYPOINTS = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]  # 13 puntos

# Mapeo directo: nombre interno -> nombre real del hueso
const BONE_NAMES = {
	"upper_arm_L": "upper_arm.L",
	"forearm_L": "forearm.L", 
	"upper_arm_R": "upper_arm.R",
	"forearm_R": "forearm.R",
	"thigh_L": "thigh.L",
	"shin_L": "shin.L",
	"thigh_R": "thigh.R",
	"shin_R": "shin.R",
}

# Índices en el array de posiciones para cada extremidad
# [inicio, fin] - para calcular la dirección del hueso
const LIMB_INDICES = {
	"upper_arm_L": [1, 3],   # hombro izq -> codo izq
	"forearm_L": [3, 5],     # codo izq -> muñeca izq
	"upper_arm_R": [2, 4],   # hombro der -> codo der
	"forearm_R": [4, 6],     # codo der -> muñeca der
	"thigh_L": [7, 9],       # cadera izq -> rodilla izq
	"shin_L": [9, 11],       # rodilla izq -> tobillo izq
	"thigh_R": [8, 10],      # cadera der -> rodilla der
	"shin_R": [10, 12],      # rodilla der -> tobillo der
}

# Colores para diferentes jugadores
const PLAYER_COLORS = [
	Color(0, 1, 0),      # Verde - Jugador 1
	Color(1, 0, 1)       # Magenta - Jugador 2
]

func _ready():
	var err = socket.connect_to_url("ws://localhost:8765")
	playBasicMusic()
	offset = nodevec.global_position 
	if err != OK:
		push_error("Error al conectar WebSocket: %s" % err)
	
	set_process(true)

func playBasicMusic():
	var music_player = audioStreamPlayer
	music_player.play()  # Comienza la música


func _process(delta):
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var data = socket.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(data)
			
			if parsed == null:
				push_warning("JSON inválido: %s" % data)
				continue
			
			# El servidor envía: {"poses": [[{x,y}, ...], [{x,y}, ...]]}
			if "poses" in parsed:
				players_data = parsed["poses"]
				update_all_players()

func update_all_players():
	# Ajustar número de jugadores
	while players_models.size() < players_data.size():
		add_player()
	
	while players_models.size() > players_data.size():
		remove_player()
	
	# Actualizar cada jugador
	for i in range(players_data.size()):
		update_player(i, players_data[i])

func add_player():
	"""Crea una instancia de Eleven para un nuevo jugador"""
	var player_idx = players_models.size()
	
	# Instanciar el modelo de Eleven
	var model = eleven_scene.instantiate()
	add_child(model)
	
	players_models.append(model)
	
	# Debug: imprimir estructura del modelo
	if not bone_names_printed:
		print("=== ESTRUCTURA DEL MODELO ===")
		print_tree_structure(model, 0)
		print("==============================")
	
	# Buscar el Skeleton3D recursivamente
	var skeleton = find_skeleton_recursive(model)
	
	if skeleton != null and not bone_names_printed:
		print("=== HUESOS ENCONTRADOS EN EL MODELO ===")
		for i in range(skeleton.get_bone_count()):
			print("Hueso %d: %s" % [i, skeleton.get_bone_name(i)])
		print("========================================")
		
		# Mostrar qué huesos se encontraron para las rotaciones
		print("=== VERIFICACIÓN DE MAPEO ===")
		for limb_name in LIMB_INDICES.keys():
			var bone_name = BONE_NAMES[limb_name]
			var bone_idx = skeleton.find_bone(bone_name)
			if bone_idx >= 0:
				print("✓ %s -> encontrado como '%s' (idx: %d)" % [limb_name, bone_name, bone_idx])
			else:
				print("✗ %s -> NO ENCONTRADO" % limb_name)
		print("==============================")
		
		bone_names_printed = true
	elif skeleton == null and not bone_names_printed:
		print("⚠ NO SE ENCONTRÓ SKELETON3D EN EL MODELO")
		bone_names_printed = true
	
	players_skeletons.append(skeleton)

func print_tree_structure(node: Node, indent: int):
	"""Imprime la estructura de nodos recursivamente"""
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	print("%s- %s (%s)" % [indent_str, node.name, node.get_class()])
	for child in node.get_children():
		print_tree_structure(child, indent + 1)

func find_skeleton_recursive(node: Node) -> Skeleton3D:
	"""Busca un Skeleton3D recursivamente en todos los hijos"""
	if node is Skeleton3D:
		return node
	
	for child in node.get_children():
		var result = find_skeleton_recursive(child)
		if result != null:
			return result
	
	return null

func remove_player():
	"""Elimina el último jugador"""
	if players_models.is_empty():
		return
	
	# Eliminar modelo
	var model = players_models.pop_back()
	model.queue_free()
	
	# Eliminar skeleton
	players_skeletons.pop_back()

func update_player(player_idx: int, pose: Array):
	if pose.size() != KEYPOINTS.size():
		return

	var model = players_models[player_idx]
	var skeleton = players_skeletons[player_idx]

	# Posicionar el modelo base
	var head_y = pose[0]["y"]
	var left_ankle_y = pose[11]["y"]
	var right_ankle_y = pose[12]["y"]
	var foot_y = max(left_ankle_y, right_ankle_y)

	var raw_height = abs(head_y - foot_y)
	if raw_height < 0.001:
		raw_height = 0.001

	var normal_scale = target_height / raw_height

	# Posición base del modelo (usar centro de caderas)
	var hip_left = pose[7]
	var hip_right = pose[8]
	var hip_x = ((hip_left["x"] + hip_right["x"]) / 2.0 - 0.5) * 2.0
	var hip_y = ((0.5 - (hip_left["y"] + hip_right["y"]) / 2.0)) * 2.0
	var hip_z = 0.0
	if "z" in hip_left:
		hip_z = -(hip_left["z"] + hip_right.get("z", 0)) / 2.0 * depth_scale

	# Invertir X si modo espejo está activado
	if mirror_mode:
		hip_x = -hip_x

	var base_pos = Vector3(
		hip_x * normal_scale * scale_factor,
		hip_y * normal_scale * scale_factor,
		hip_z
	) + offset

	model.position = base_pos
	# Aplicar escala adicional del modelo
	var safe_model_scale = model_scale
	if safe_model_scale <= 0.001:
		safe_model_scale = 1.0 # Valor por defecto si en el inspector está a 0
		
	var final_scale = normal_scale * scale_factor * safe_model_scale
	model.scale = Vector3(final_scale, final_scale, final_scale)

	# Calcular posiciones 3D de todos los keypoints
	var positions = []
	for i in range(KEYPOINTS.size()):
		var lm = pose[i]
		var x = (lm["x"] - 0.5) * 2.0
		var y = (0.5 - lm["y"]) * 2.0
		var z = 0.0
		if "z" in lm:
			z = -lm["z"] * depth_scale
		
		# Invertir X si modo espejo
		if mirror_mode:
			x = -x
		
		positions.append(Vector3(x, y, z))

	# Animar el esqueleto
	if skeleton != null:
		animate_skeleton(skeleton, positions)

# Orden de actualización para asegurar que los padres se actualizan antes que los hijos
const UPDATE_ORDER = [
	"upper_arm_L", "forearm_L",
	"upper_arm_R", "forearm_R",
	"thigh_L", "shin_L",
	"thigh_R", "shin_R"
]

func animate_skeleton(skeleton: Skeleton3D, positions: Array):
	"""Anima el esqueleto basándose en las posiciones de MediaPipe"""
	
	# Usar un orden específico para respetar la jerarquía
	for limb_name in UPDATE_ORDER:
		var bone_name = BONE_NAMES[limb_name]
		var bone_idx = skeleton.find_bone(bone_name)
		
		if bone_idx < 0:
			continue
		
		var indices = LIMB_INDICES[limb_name]
		var start_pos = positions[indices[0]]
		var end_pos = positions[indices[1]]
		
		# Dirección objetivo del hueso en espacio del modelo
		var target_world_dir = (end_pos - start_pos).normalized()
		
		if target_world_dir.length() < 0.001:
			continue
		
		# Obtener la transformación global (Model Space) del padre
		var parent_idx = skeleton.get_bone_parent(bone_idx)
		var parent_global_basis = Basis.IDENTITY
		if parent_idx >= 0:
			parent_global_basis = skeleton.get_bone_global_pose(parent_idx).basis
		
		# Convertir la dirección objetivo al espacio local del padre
		var target_local_dir = (parent_global_basis.inverse() * target_world_dir).normalized()
		
		# Obtener la pose de descanso (Rest Pose)
		var rest_pose = skeleton.get_bone_rest(bone_idx)
		# Asumimos que el hueso apunta hacia Y+ en su espacio local (estándar Blender)
		# Por tanto, rest_pose.basis.y es la dirección del hueso en espacio del padre en reposo
		var rest_dir = rest_pose.basis.y.normalized()
		
		# Calcular la rotación necesaria para alinear la dirección de reposo con la objetivo
		var rotation_quat = rotation_from_to(rest_dir, target_local_dir)
		
		# Aplicar esta rotación a la base de reposo
		# Esto preserva el "roll" original del hueso
		var final_basis = Basis(rotation_quat) * rest_pose.basis
		
		# Aplicar con suavizado (Slerp)
		var current_pose = skeleton.get_bone_pose(bone_idx)
		var current_quat = current_pose.basis.get_rotation_quaternion()
		var target_quat = final_basis.get_rotation_quaternion()
		
		# Factor de suavizado (0.0 = no cambio, 1.0 = instantáneo)
		var smoothed_quat = current_quat.slerp(target_quat, 0.5)
		
		skeleton.set_bone_pose(bone_idx, Transform3D(Basis(smoothed_quat), current_pose.origin))

	# --- Rotación de la Cabeza ---
	var head_bone_idx = skeleton.find_bone("spine.006")
	if head_bone_idx >= 0:
		# Calcular posición del cuello (punto medio entre hombros)
		# positions: 0=nose, 1=left_shoulder, 2=right_shoulder
		var neck_pos = (positions[1] + positions[2]) / 2.0
		var nose_pos = positions[0]
		
		# Dirección objetivo: del cuello a la nariz
		var target_head_dir = (nose_pos - neck_pos).normalized()
		
		if target_head_dir.length() > 0.001:
			# Obtener transformación del padre
			var parent_idx = skeleton.get_bone_parent(head_bone_idx)
			var parent_global_basis = Basis.IDENTITY
			if parent_idx >= 0:
				parent_global_basis = skeleton.get_bone_global_pose(parent_idx).basis
			
			# Convertir a local
			var target_local_dir = (parent_global_basis.inverse() * target_head_dir).normalized()
			
			# Pose de descanso
			var rest_pose = skeleton.get_bone_rest(head_bone_idx)
			# Usar una combinación de Y (Arriba) y Z (Adelante) para aproximar la dirección "Cuello -> Nariz"
			var rest_dir = (rest_pose.basis.y + rest_pose.basis.z).normalized()
			
			# Calcular rotación
			var rotation_quat = rotation_from_to(rest_dir, target_local_dir)
			var final_basis = Basis(rotation_quat) * rest_pose.basis
			
			# Aplicar suavizado
			var current_pose = skeleton.get_bone_pose(head_bone_idx)
			var current_quat = current_pose.basis.get_rotation_quaternion()
			var target_quat = final_basis.get_rotation_quaternion()
			var smoothed_quat = current_quat.slerp(target_quat, 0.5)
			
			skeleton.set_bone_pose(head_bone_idx, Transform3D(Basis(smoothed_quat), current_pose.origin))

func calculate_limb_rotation(limb_name: String, target_world_dir: Vector3, skeleton: Skeleton3D, bone_idx: int) -> Quaternion:
	"""Legacy - no usado"""
	return Quaternion.IDENTITY

func rotation_from_to(from_dir: Vector3, to_dir: Vector3) -> Quaternion:
	"""Calcula el quaternion que rota from_dir hacia to_dir"""
	from_dir = from_dir.normalized()
	to_dir = to_dir.normalized()
	
	var dot = from_dir.dot(to_dir)
	
	if dot > 0.9999:
		return Quaternion.IDENTITY
	elif dot < -0.9999:
		var ortho = Vector3(0, 0, 1) if abs(from_dir.z) < 0.9 else Vector3(0, 1, 0)
		var axis = from_dir.cross(ortho).normalized()
		return Quaternion(axis, PI)
	else:
		var axis = from_dir.cross(to_dir).normalized()
		var angle = acos(clamp(dot, -1.0, 1.0))
		return Quaternion(axis, angle)

func find_bone_by_name(skeleton: Skeleton3D, base_name: String) -> int:
	"""Busca un hueso por nombre"""
	return skeleton.find_bone(base_name)

func calculate_bone_rotation(bone_name: String, direction: Vector3) -> Quaternion:
	"""Legacy - no usado"""
	return Quaternion.IDENTITY
