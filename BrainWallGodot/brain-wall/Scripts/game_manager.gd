# game_manager.gd
# Singleton para gestionar el estado del juego Brain Wall
extends Node

signal player_hit(player_idx: int, lives_remaining: int)
signal player_eliminated(player_idx: int)
signal game_over(winner_idx: int)
signal wall_passed(player_idx: int, score: int)

# Configuración del juego
@export var max_lives: int = 3
@export var wall_speed: float = 1.5
@export var spawn_interval: float = 6.0
@export var spawn_distance: float = 12.0  # Distancia Z donde aparecen las paredes (ahora positivo)
@export var despawn_distance: float = -5.0  # Distancia Z donde desaparecen (ahora negativo)
@export var wall_scale: Vector3 = Vector3(0.2, 0.2, 0.2)
@export var wall_height: float = 0  # Altura Y de las paredes

# Offsets para las paredes de cada jugador
@export var player1_wall_offset: Vector3 = Vector3(-1.0, 0.0, 0.0)  # Offset para la pared del jugador 1
@export var player2_wall_offset: Vector3 = Vector3(1.0, 0.0, 0.0)   # Offset para la pared del jugador 2

# Estado de los jugadores
var player_lives: Array[int] = [3, 3]
var player_scores: Array[int] = [0, 0]
var game_active: bool = false

# Paredes disponibles
var wall_scenes: Array[PackedScene] = []
var active_walls: Array[Node3D] = []  # Paredes activas en escena

# Referencia a la escena principal para añadir paredes
var main_scene: Node3D = null

# Timers
var spawn_timer: float = 0.0

func _ready():
	load_wall_scenes()
	reset_game()

func load_wall_scenes():
	"""Carga todas las escenas de paredes disponibles"""
	var walls_path = "res://assets/Walls/WallsScenes/"
	var dir = DirAccess.open(walls_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				var scene_path = walls_path + file_name
				var scene = load(scene_path)
				if scene:
					wall_scenes.append(scene)
					print("Pared cargada: ", file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	print("Total paredes cargadas: ", wall_scenes.size())

func reset_game():
	"""Reinicia el estado del juego"""
	for i in range(2):
		player_lives[i] = max_lives
		player_scores[i] = 0
	
	# Limpiar paredes activas
	for wall in active_walls:
		if is_instance_valid(wall):
			wall.queue_free()
	active_walls.clear()
	
	spawn_timer = 0.0
	game_active = false

func start_game():
	"""Inicia el juego"""
	reset_game()
	game_active = true
	print("¡Juego iniciado! Cada jugador tiene ", max_lives, " vidas")

func _process(delta: float):
	if not game_active:
		return
	
	# Spawn de paredes
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_walls_for_players()
	
	# Actualizar paredes activas
	update_walls(delta)

func spawn_walls_for_players():
	"""Genera dos paredes aleatorias, una para cada jugador"""
	if wall_scenes.is_empty():
		print("No hay paredes disponibles")
		return
	
	# Verificar si al menos un jugador sigue vivo
	var any_alive = false
	for i in range(2):
		if player_lives[i] > 0:
			any_alive = true
			break
	
	if not any_alive:
		return
	
	# Crear una pared para cada jugador
	var offsets = [player1_wall_offset, player2_wall_offset]
	
	for player_idx in range(2):
		# Solo crear pared si el jugador está vivo
		if player_lives[player_idx] <= 0:
			continue
		
		# Seleccionar pared aleatoria
		var random_wall = wall_scenes[randi() % wall_scenes.size()]
		var wall_instance = random_wall.instantiate()
		
		# Configurar posición inicial con el offset del jugador correspondiente
		var spawn_pos = Vector3(
			offsets[player_idx].x,  # Offset X del jugador
			wall_height + offsets[player_idx].y,  # Altura Y + offset Y
			spawn_distance + offsets[player_idx].z  # Distancia Z + offset Z
		)
		wall_instance.global_position = spawn_pos
		
		# Rotar para que mire hacia el jugador (hacia -Z ahora)
		wall_instance.rotation.y = PI  # 180 grados para que mire hacia -Z
		
		# Escalar la pared
		wall_instance.scale = wall_scale
		
		# Añadir metadata (cada pared es para un jugador específico)
		wall_instance.set_meta("player_idx", player_idx)
		wall_instance.set_meta("passed", false)
		wall_instance.set_meta("hit_players", [])  # Lista de jugadores que ya colisionaron
		
		# Configurar detección de colisiones
		setup_wall_collision(wall_instance)
		
		# Añadir a la escena
		get_tree().current_scene.add_child(wall_instance)
		active_walls.append(wall_instance)
		
		print("Pared spawneada para jugador ", player_idx + 1, "!")

func setup_wall_collision(wall: Node3D):
	"""Configura la detección de colisiones en la pared"""
	# Buscar Area3D en la pared
	var collision_node = find_collision_node(wall)
	
	if collision_node:
		if collision_node is Area3D:
			# Conectar señal de área para detectar cuando un jugador entra
			if not collision_node.area_entered.is_connected(_on_wall_area_entered):
				collision_node.area_entered.connect(_on_wall_area_entered.bind(wall))
			collision_node.set_meta("wall_ref", wall)
	else:
		# Si no hay nodo de colisión, crear un Area3D
		create_collision_area(wall)

func find_collision_node(node: Node) -> Node:
	"""Busca recursivamente un nodo de colisión"""
	if node is Area3D or node is RigidBody3D:
		return node
	for child in node.get_children():
		var result = find_collision_node(child)
		if result:
			return result
	return null

func create_collision_area(wall: Node3D):
	"""Crea un área de colisión para la pared"""
	var area = Area3D.new()
	area.name = "WallCollisionArea"
	
	var collision_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.5)
	collision_shape.shape = box
	
	area.add_child(collision_shape)
	wall.add_child(area)
	
	area.area_entered.connect(_on_wall_area_entered.bind(wall))
	area.set_meta("wall_ref", wall)

func _on_wall_area_entered(other_area: Area3D, wall: Node3D):
	"""Callback cuando un área del jugador entra en contacto con la pared"""
	# Verificar si es un área de jugador
	if not other_area.has_meta("player_idx"):
		return
	
	var player_idx = other_area.get_meta("player_idx")
	var hit_players = wall.get_meta("hit_players", [])
	
	# Verificar si este jugador ya colisionó con esta pared
	if player_idx in hit_players:
		return
	
	# Registrar que este jugador colisionó
	hit_players.append(player_idx)
	wall.set_meta("hit_players", hit_players)
	
	# Restar vida al jugador
	hit_player(player_idx)
	print("¡COLISIÓN! Jugador ", player_idx + 1, " golpeó la pared!")

func update_walls(delta: float):
	"""Mueve las paredes y elimina las que han pasado"""
	var walls_to_remove: Array[Node3D] = []
	
	for wall in active_walls:
		if not is_instance_valid(wall):
			walls_to_remove.append(wall)
			continue
		
		# Mover la pared hacia adelante (hacia el jugador, ahora -Z)
		wall.global_position.z -= wall_speed * delta
		
		var has_passed = wall.get_meta("passed", false)
		var wall_player_idx = wall.get_meta("player_idx", -1)
		
		# Verificar si la pared ha pasado a los jugadores (sin colisión = punto)
		if not has_passed and wall.global_position.z < -2.0:
			wall.set_meta("passed", true)
			# Los jugadores que no colisionaron ganan puntos
			var hit_players = wall.get_meta("hit_players", [])
			
			# Si la pared es para un jugador específico, solo ese jugador puede ganar puntos
			if wall_player_idx >= 0:
				if player_lives[wall_player_idx] > 0 and not (wall_player_idx in hit_players):
					player_scores[wall_player_idx] += 1
					wall_passed.emit(wall_player_idx, player_scores[wall_player_idx])
					print("¡Jugador ", wall_player_idx + 1, " pasó la pared! Score: ", player_scores[wall_player_idx])
			else:
				# Pared compartida (modo anterior)
				for i in range(2):
					if player_lives[i] > 0 and not (i in hit_players):
						player_scores[i] += 1
						wall_passed.emit(i, player_scores[i])
						print("¡Jugador ", i + 1, " pasó la pared! Score: ", player_scores[i])
		
		# Eliminar paredes que han salido de la pantalla (ahora comparamos con valor negativo)
		if wall.global_position.z < despawn_distance:
			walls_to_remove.append(wall)
	
	# Limpiar paredes
	for wall in walls_to_remove:
		if is_instance_valid(wall):
			wall.queue_free()
		active_walls.erase(wall)

func hit_player(player_idx: int):
	"""Resta una vida al jugador"""
	if player_idx < 0 or player_idx >= player_lives.size():
		return
	
	player_lives[player_idx] -= 1
	player_hit.emit(player_idx, player_lives[player_idx])
	
	print("Jugador ", player_idx + 1, " perdió una vida. Vidas restantes: ", player_lives[player_idx])
	
	if player_lives[player_idx] <= 0:
		eliminate_player(player_idx)

func eliminate_player(player_idx: int):
	"""Elimina a un jugador del juego"""
	player_eliminated.emit(player_idx)
	print("¡Jugador ", player_idx + 1, " eliminado!")
	
	# Verificar si hay un ganador
	var alive_players = 0
	var winner = -1
	for i in range(player_lives.size()):
		if player_lives[i] > 0:
			alive_players += 1
			winner = i
	
	if alive_players <= 1:
		end_game(winner)

func end_game(winner_idx: int):
	"""Termina el juego"""
	game_active = false
	game_over.emit(winner_idx)
	
	if winner_idx >= 0:
		print("¡JUEGO TERMINADO! Ganador: Jugador ", winner_idx + 1)
	else:
		print("¡JUEGO TERMINADO! Empate")

func get_player_lives(player_idx: int) -> int:
	"""Obtiene las vidas de un jugador"""
	if player_idx >= 0 and player_idx < player_lives.size():
		return player_lives[player_idx]
	return 0

func get_player_score(player_idx: int) -> int:
	"""Obtiene el score de un jugador"""
	if player_idx >= 0 and player_idx < player_scores.size():
		return player_scores[player_idx]
	return 0
