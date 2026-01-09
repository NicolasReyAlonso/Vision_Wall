# PoseReceiver.gd
extends Node3D

@export var target_height: float = 2.0   # altura deseada en metros dentro del juego
@export var player_scene: PackedScene  # Escena por defecto (fallback)
@export var audioStreamPlayer: AudioStreamPlayer3D
@export var audioLoop: AudioStreamPlayer3D
@export var offset: Vector3 = Vector3.ZERO
@export var scale_factor: float = 0.7            # Escala global
@export var depth_scale: float = 2.0             # Escala para la profundidad (Z)
@export var mirror_mode: bool = true             # Espejo (true = movimiento espejo)
@export var model_scale: float = 1.0             # Escala adicional del personaje
@export var movement_smoothing: float = 0.2      # Suavizado del movimiento
@export var rotation_smoothing: float = 0.08     # Suavizado de rotación

# Configuración por jugador
@export var lock_z_movement: bool = true         # Bloquear movimiento en eje Z
@export var player1_offset: Vector3 = Vector3(-1.0, 0.0, 0.0)  # Offset del jugador 1
@export var player2_offset: Vector3 = Vector3(1.0, 0.0, 0.0)   # Offset del jugador 2

var socket := WebSocketPeer.new()
var players_data: Array = []
var players: Array = []  # Instancias de los personajes
var players_skeletons: Array = [] # Esqueletos de los personajes
var players_collision_areas: Array = []  # Áreas de colisión de los jugadores
var character_assignments: Array = []
var loaded_scenes: Dictionary = {}
var bone_names_printed: bool = false

# Game Manager
var game_manager: Node = null
var game_ui: CanvasLayer = null

# Índices de KEYPOINTS enviados por MediaPipe:
const KEYPOINTS = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]

# Colores para diferentes jugadores
const PLAYER_COLORS = [
	Color(0, 1, 0),      # Verde - Jugador 1
	Color(1, 0, 1)       # Magenta - Jugador 2
]

# Mapeo de huesos (Prioridad al proporcionado por el usuario)
const BONE_NAMES = {
	"spine": "spine",
	"upper_arm_L": "upper_arm.L",
	"forearm_L": "forearm.L", 
	"upper_arm_R": "upper_arm.R",
	"forearm_R": "forearm.R",
	"thigh_L": "thigh.L",
	"shin_L": "shin.L",
	"thigh_R": "thigh.R",
	"shin_R": "shin.R",
}

# Mapeo alternativo (Español/Mixamo a veces)
const BONE_NAMES_ES = {
	"spine": "mixamorig:Spine",
	"upper_arm_L": "Brazo.L",
	"forearm_L": "Mano.L", 
	"upper_arm_R": "Brazo.R",
	"forearm_R": "Mano.R",
	"thigh_L": "Pierna.L",
	"shin_L": "Pie.L",
	"thigh_R": "Pierna.R",
	"shin_R": "Pie.R",
}

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

const UPDATE_ORDER = [
	"upper_arm_L", "forearm_L",
	"upper_arm_R", "forearm_R",
	"thigh_L", "shin_L",
	"thigh_R", "shin_R"
]

func _ready():
	var character1 = "eleven"
	var character2 = "eleven"
	
	if get_tree().root.has_meta("personaje1"):
		character1 = get_tree().root.get_meta("personaje1")
	if get_tree().root.has_meta("personaje2"):
		character2 = get_tree().root.get_meta("personaje2")
	
	print("Jugador 1: ", character1)
	print("Jugador 2: ", character2)
	
	character_assignments = [character1, character2]
	
	# Pre-cargar escenas
	get_character_scene(character1)
	get_character_scene(character2)
	
	var err = socket.connect_to_url("ws://localhost:8765")
	if err != OK:
		push_error("Error al conectar WebSocket: %s" % err)
	
	if audioStreamPlayer:
		# Conectar señal para iniciar el audio en bucle cuando termine el intro
		if not audioStreamPlayer.finished.is_connected(_on_intro_finished):
			audioStreamPlayer.finished.connect(_on_intro_finished)
		audioStreamPlayer.play()

	# Asegurar que el audio de loop re-reproduzca al terminar (fallback si el stream no tiene loop)
	if audioLoop:
		if not audioLoop.finished.is_connected(_on_loop_finished):
			audioLoop.finished.connect(_on_loop_finished)
	
	# Inicializar Game Manager
	setup_game_manager()
	
	set_process(true)

func setup_game_manager():
	"""Configura el Game Manager y la UI"""
	# Crear instancia del Game Manager
	var game_manager_script = load("res://Scripts/game_manager.gd")
	if game_manager_script:
		game_manager = Node.new()
		game_manager.name = "GameManager"
		game_manager.set_script(game_manager_script)
		add_child(game_manager)
		print("Game Manager inicializado")
	
	# Cargar e instanciar la UI
	var ui_scene = load("res://scenes/game_ui.tscn")
	if ui_scene:
		game_ui = ui_scene.instantiate()
		add_child(game_ui)
		print("Game UI cargada")

func get_character_scene(char_name: String) -> PackedScene:
	if loaded_scenes.has(char_name):
		return loaded_scenes[char_name]
		
	var scene: PackedScene = null
	match char_name:
		"saw":
			print("Cargando Saw...")
			if ResourceLoader.exists("res://assets/models/Saw.glb"):
				scene = load("res://assets/models/Saw.glb")
		"et":
			print("Cargando ET...")
			if ResourceLoader.exists("res://assets/models/ET.glb"):
				scene = load("res://assets/models/ET.glb")
		"eleven":
			print("Cargando Eleven...")
			if ResourceLoader.exists("res://assets/Characters/eleven.tscn"):
				scene = load("res://assets/Characters/eleven.tscn")
		"homer":
			print("Cargando Homer...")
			if ResourceLoader.exists("res://assets/models/Homer.glb"):
				scene = load("res://assets/models/Homer.glb")
		_:
			print("Personaje no reconocido: ", char_name)
	
	if scene:
		loaded_scenes[char_name] = scene
		# Si no hay escena por defecto, usar la primera que carguemos
		if player_scene == null:
			player_scene = scene
	
	return scene

func _process(_delta):
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var data = socket.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(data)
			
			if parsed == null:
				continue
			
			if "poses" in parsed:
				players_data = parsed["poses"]
				update_all_players()
	
	# Input para iniciar el juego (tecla espacio)
	if Input.is_action_just_pressed("ui_accept"):
		if game_manager and not game_manager.game_active:
			game_manager.start_game()

func update_all_players():
	while players.size() < players_data.size():
		add_player()
	
	while players.size() > players_data.size():
		remove_player()
	
	for i in range(players_data.size()):
		update_player(i, players_data[i])

func add_player():
	var player_idx = players.size()
	var char_name = "eleven"
	
	if player_idx < character_assignments.size():
		char_name = character_assignments[player_idx]
	
	var scene_to_instantiate = get_character_scene(char_name)
	if scene_to_instantiate == null:
		scene_to_instantiate = player_scene # Fallback
	
	if scene_to_instantiate == null:
		push_error("No se pudo cargar escena para jugador " + str(player_idx))
		return

	var player_instance = scene_to_instantiate.instantiate()
	# La escala se maneja en update_player ahora
	add_child(player_instance)
	players.append(player_instance)
	
	# Buscar esqueleto
	var skeleton = find_skeleton_recursive(player_instance)
	players_skeletons.append(skeleton)
	
	# Crear área de colisión para el jugador
	var collision_area = create_player_collision_area(player_instance, player_idx)
	players_collision_areas.append(collision_area)
	
	# Debug huesos
	if skeleton and not bone_names_printed:
		print("=== HUESOS ENCONTRADOS ===")
		for i in range(skeleton.get_bone_count()):
			print("Hueso %d: %s" % [i, skeleton.get_bone_name(i)])
		bone_names_printed = true
	
	apply_color_to_player(player_instance, PLAYER_COLORS[player_idx % PLAYER_COLORS.size()])

func create_player_collision_area(player: Node3D, player_idx: int) -> Area3D:
	"""Configura las áreas de colisión existentes en el modelo para detectar choques con paredes"""
	
	# Buscar todas las Area3D existentes en el modelo
	var areas_found = find_all_areas_recursive(player)
	
	if areas_found.is_empty():
		# Fallback: crear área básica si no se encuentran áreas en el modelo
		print("No se encontraron áreas de colisión en el modelo, creando área básica...")
		return create_fallback_collision_area(player, player_idx)
	
	print("Encontradas ", areas_found.size(), " áreas de colisión en el modelo del jugador ", player_idx + 1)
	
	# Configurar cada área encontrada con el player_idx
	var main_area: Area3D = null
	for area in areas_found:
		area.set_meta("player_idx", player_idx)
		# Conectar señal de colisión
		if not area.area_entered.is_connected(_on_player_area_entered):
			area.area_entered.connect(_on_player_area_entered.bind(player_idx))
		
		# Usar la primera área como referencia principal
		if main_area == null:
			main_area = area
	
	return main_area

func find_all_areas_recursive(node: Node) -> Array[Area3D]:
	"""Busca recursivamente todas las Area3D en un nodo"""
	var areas: Array[Area3D] = []
	
	if node is Area3D:
		areas.append(node)
	
	for child in node.get_children():
		var child_areas = find_all_areas_recursive(child)
		areas.append_array(child_areas)
	
	return areas

func create_fallback_collision_area(player: Node3D, player_idx: int) -> Area3D:
	"""Crea un área de colisión básica como fallback"""
	var area = Area3D.new()
	area.name = "PlayerCollisionArea_" + str(player_idx)
	area.set_meta("player_idx", player_idx)
	
	# Crear forma de colisión básica (cápsula para el cuerpo)
	var collision_shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.5
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, 0.75, 0)
	
	area.add_child(collision_shape)
	player.add_child(area)
	
	area.area_entered.connect(_on_player_area_entered.bind(player_idx))
	
	return area

func _on_player_area_entered(other_area: Area3D, player_idx: int):
	"""Callback cuando el jugador colisiona con otra área (pared)"""
	if not game_manager:
		return
	
	# Verificar si es una pared (Area3D de una pared)
	var wall = other_area.get_meta("wall_ref", null)
	if wall == null:
		# Intentar obtener el padre como pared
		var parent = other_area.get_parent()
		if parent and parent.name.begins_with("Wall"):
			wall = parent
	
	if wall == null:
		return
	
	# Verificar si este jugador ya colisionó con esta pared
	var hit_players = wall.get_meta("hit_players", [])
	if player_idx in hit_players:
		return
	
	# Registrar la colisión y restar vida
	hit_players.append(player_idx)
	wall.set_meta("hit_players", hit_players)
	game_manager.hit_player(player_idx)
	print("¡COLISIÓN desde mainscript! Jugador ", player_idx + 1, " golpeó una pared")

func remove_player():
	if players.is_empty():
		return
	var player = players.pop_back()
	player.queue_free()
	if not players_skeletons.is_empty():
		players_skeletons.pop_back()
	if not players_collision_areas.is_empty():
		players_collision_areas.pop_back()

func find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = find_skeleton_recursive(child)
		if result:
			return result
	return null

func update_player(player_idx: int, pose: Array):
	if pose.size() != KEYPOINTS.size() or player_idx >= players.size():
		return
	
	var model = players[player_idx]
	var skeleton = players_skeletons[player_idx]
	
	# Obtener el offset del jugador correspondiente
	var player_offset = player1_offset if player_idx == 0 else player2_offset
	
	# Posicionar el modelo base
	var head_y = pose[0]["y"]
	var left_ankle_y = pose[11]["y"]
	var right_ankle_y = pose[12]["y"]
	var foot_y = max(left_ankle_y, right_ankle_y)

	var raw_height = abs(head_y - foot_y)
	if raw_height < 0.001:
		raw_height = 0.001

	var hip_left = pose[7]
	var hip_right = pose[8]
	var hip_x = ((hip_left["x"] + hip_right["x"]) / 2.0 - 0.5) * 2.0
	var hip_y = ((0.5 - (hip_left["y"] + hip_right["y"]) / 2.0)) * 2.0

	# Invertir X si modo espejo está activado
	if mirror_mode:
		hip_x = -hip_x
	
	# Calcular Z solo si no está bloqueado
	var final_z = player_offset.z + offset.z
	if not lock_z_movement:
		# Factor de profundidad: Ajustar para que el personaje se mueva lo suficiente
		var z_distance_factor = 5.0 
		var z_from_distance = (raw_height - 0.5) * z_distance_factor
		
		var hip_z = 0.0
		if "z" in hip_left:
			hip_z = -(hip_left["z"] + hip_right.get("z", 0)) / 2.0 * depth_scale
		
		final_z += z_from_distance + hip_z
	
	# Posición base
	# Multiplicamos X e Y por un factor fijo para cubrir el área de juego
	var play_area_scale = 3.0 
	
	var base_pos = Vector3(
		hip_x * play_area_scale + player_offset.x + offset.x,
		hip_y * play_area_scale + 1.0 + player_offset.y + offset.y,
		final_z
	)

	# Usar lerp para suavizar movimiento global
	model.global_position = model.global_position.lerp(base_pos, movement_smoothing)
	
	# Escala FIJA del modelo
	var safe_model_scale = model_scale
	if safe_model_scale <= 0.001:
		safe_model_scale = 1.0 
		
	# Aplicamos solo la escala base, sin el factor de distancia
	var final_scale = scale_factor * safe_model_scale
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

	# --- ROTACIÓN DEL CUERPO (Eje Y) ---
	# Calcular ángulo de los hombros para rotar todo el personaje
	var p_left_shoulder = positions[1]
	var p_right_shoulder = positions[2]
	var shoulder_dir = p_right_shoulder - p_left_shoulder
	
	# Evitar rotaciones bruscas si los datos no son claros
	if shoulder_dir.length() > 0.1:
		var target_rot_y = atan2(shoulder_dir.z, shoulder_dir.x) + PI
		# Ajuste de offset si es necesario (depende de la orientación del modelo)
		# Asumimos que el modelo mira hacia +Z por defecto
		model.rotation.y = lerp_angle(model.rotation.y, target_rot_y, rotation_smoothing)

	# Animar el esqueleto
	if skeleton != null:
		animate_skeleton(skeleton, positions)

func animate_skeleton(skeleton: Skeleton3D, positions: Array):
	# Obtener la orientación global del esqueleto para compensar la rotación del nodo padre
	var skeleton_basis_inv = skeleton.global_transform.basis.orthonormalized().inverse()

	# --- Rotación del Torso/Columna ---
	# Calculamos el vector desde el centro de las caderas al centro de los hombros
	var hip_center = (positions[7] + positions[8]) / 2.0
	var shoulder_center = (positions[1] + positions[2]) / 2.0
	var spine_dir_world = (shoulder_center - hip_center).normalized()
	
	# Convertir dirección del mundo a espacio local del esqueleto
	var spine_dir = (skeleton_basis_inv * spine_dir_world).normalized()
	
	if spine_dir.length() > 0.001:
		var spine_bone_name = BONE_NAMES["spine"]
		var spine_idx = skeleton.find_bone(spine_bone_name)
		if spine_idx < 0:
			spine_bone_name = BONE_NAMES_ES["spine"]
			spine_idx = skeleton.find_bone(spine_bone_name)
			
		if spine_idx >= 0:
			# Obtener transformación del padre (normalmente Hips/Pelvis)
			var parent_idx = skeleton.get_bone_parent(spine_idx)
			var parent_global_basis = Basis.IDENTITY
			if parent_idx >= 0:
				parent_global_basis = skeleton.get_bone_global_pose(parent_idx).basis
			
			# Convertir a local
			var target_local_dir = (parent_global_basis.inverse() * spine_dir).normalized()
			
			# Pose de descanso (asumimos Y+ es arriba a lo largo de la columna)
			var rest_pose = skeleton.get_bone_rest(spine_idx)
			var rest_dir = rest_pose.basis.y.normalized()
			
			# Calcular rotación
			var rotation_quat = rotation_from_to(rest_dir, target_local_dir)
			var final_basis = Basis(rotation_quat) * rest_pose.basis
			
			# Aplicar suavizado
			var current_pose = skeleton.get_bone_pose(spine_idx)
			var current_quat = current_pose.basis.get_rotation_quaternion()
			var target_quat = final_basis.get_rotation_quaternion()
			var smoothed_quat = current_quat.slerp(target_quat, 0.5)
			
			skeleton.set_bone_pose(spine_idx, Transform3D(Basis(smoothed_quat), current_pose.origin))

	# Usar un orden específico para respetar la jerarquía
	for limb_name in UPDATE_ORDER:
		var bone_name = BONE_NAMES[limb_name]
		var bone_idx = skeleton.find_bone(bone_name)
		
		# Si no encuentra el hueso con el nombre principal, probar el alternativo
		if bone_idx < 0:
			bone_name = BONE_NAMES_ES[limb_name]
			bone_idx = skeleton.find_bone(bone_name)
		
		if bone_idx < 0:
			continue
		
		var indices = LIMB_INDICES[limb_name]
		var start_pos = positions[indices[0]]
		var end_pos = positions[indices[1]]
		
		# Dirección objetivo del hueso en espacio del mundo
		var target_world_dir = (end_pos - start_pos).normalized()
		
		if target_world_dir.length() < 0.001:
			continue
			
		# Convertir a espacio del esqueleto (compensar rotación del cuerpo)
		var target_model_dir = (skeleton_basis_inv * target_world_dir).normalized()
		
		# Obtener la transformación global (Model Space) del padre
		var parent_idx = skeleton.get_bone_parent(bone_idx)
		var parent_global_basis = Basis.IDENTITY
		if parent_idx >= 0:
			parent_global_basis = skeleton.get_bone_global_pose(parent_idx).basis
		
		# Convertir la dirección objetivo al espacio local del padre
		var target_local_dir = (parent_global_basis.inverse() * target_model_dir).normalized()
		
		# Obtener la pose de descanso (Rest Pose)
		var rest_pose = skeleton.get_bone_rest(bone_idx)
		# Asumimos que el hueso apunta hacia Y+ en su espacio local (estándar Blender)
		var rest_dir = rest_pose.basis.y.normalized()
		
		# Calcular la rotación necesaria para alinear la dirección de reposo con la objetivo
		var rotation_quat = rotation_from_to(rest_dir, target_local_dir)
		
		# Aplicar esta rotación a la base de reposo
		var final_basis = Basis(rotation_quat) * rest_pose.basis
		
		# Aplicar con suavizado (Slerp)
		var current_pose = skeleton.get_bone_pose(bone_idx)
		var current_quat = current_pose.basis.get_rotation_quaternion()
		var target_quat = final_basis.get_rotation_quaternion()
		
		var smoothed_quat = current_quat.slerp(target_quat, 0.5)
		
		skeleton.set_bone_pose(bone_idx, Transform3D(Basis(smoothed_quat), current_pose.origin))

func rotation_from_to(from_dir: Vector3, to_dir: Vector3) -> Quaternion:
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


func _on_intro_finished():
	# Cuando termine el audio introductorio, iniciar el audio en loop (si existe)
	if audioLoop:
		audioLoop.play()


func _on_loop_finished():
	# Fallback: si el stream de loop no soporta loop nativo, re-disparar reproducir al terminar
	if audioLoop:
		audioLoop.play()

func apply_color_to_player(player: Node, color: Color):
	apply_color_recursive(player, color)

func apply_color_recursive(node: Node, color: Color):
	if node is MeshInstance3D:
		var material = node.get_surface_override_material(0)
		if material and material is ShaderMaterial:
			if material.shader:
				material.set_shader_parameter("base_color", color)
	
	for child in node.get_children():
		apply_color_recursive(child, color)
