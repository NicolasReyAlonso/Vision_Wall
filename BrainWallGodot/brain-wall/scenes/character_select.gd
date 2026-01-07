extends Control

# Variables para guardar personajes de ambos jugadores
var personaje_jugador1 = ""
var personaje_jugador2 = ""
var seleccionando_jugador = 1  # 1 o 2

# Audio players para efectos de sonido
var audio_click: AudioStreamPlayer
var audio_hover: AudioStreamPlayer

func _ready():
	# Crear AudioStreamPlayers para efectos de sonido
	audio_click = AudioStreamPlayer.new()
	add_child(audio_click)
	audio_click.stream = load("res://assets/SoundEffects/soundEffect_buttonClick.ogg")
	
	audio_hover = AudioStreamPlayer.new()
	add_child(audio_hover)
	audio_hover.stream = load("res://assets/SoundEffects/soundEffect_buttonHover.ogg")
	
	# Conectar eventos de los botones
	var buttons = [
		$MarginContainer/VBoxPrincipal/BotonesContainer/GridContainer/SawButton,
		$MarginContainer/VBoxPrincipal/BotonesContainer/GridContainer/ETButton,
		$MarginContainer/VBoxPrincipal/BotonesContainer/GridContainer/ElevenButton,
		$MarginContainer/VBoxPrincipal/BotonesContainer/GridContainer/HomerButton
	]
	
	$MarginContainer/VBoxPrincipal/BotonesContainer/GridContainer/SawButton.pressed.connect(_on_saw_pressed)
	$MarginContainer/VBoxPrincipal/BotonesContainer/GridContainer/ETButton.pressed.connect(_on_et_pressed)
	$MarginContainer/VBoxPrincipal/BotonesContainer/GridContainer/ElevenButton.pressed.connect(_on_eleven_pressed)
	$MarginContainer/VBoxPrincipal/BotonesContainer/GridContainer/HomerButton.pressed.connect(_on_homer_pressed)
	
	# Conectar eventos de hover y click a todos los botones
	for button in buttons:
		button.mouse_entered.connect(_on_button_hover)
		button.pressed.connect(_on_button_click)
	
	# Actualizar texto inicial
	actualizar_titulo()

func _on_button_hover():
	audio_hover.play()

func _on_button_click():
	audio_click.play()

func actualizar_titulo():
	var titulo = $MarginContainer/VBoxPrincipal/TituloLabel
	var mensaje = "Jugador %d - Selecciona tu personaje\n" % seleccionando_jugador
	
	if personaje_jugador1 != "":
		mensaje += "Jugador 1: %s\n" % personaje_jugador1.to_upper()
	
	if personaje_jugador2 != "":
		mensaje += "Jugador 2: %s\n" % personaje_jugador2.to_upper()
	
	titulo.text = mensaje
	print(mensaje)

func _on_saw_pressed():
	guardar_seleccion("SAW")

func _on_et_pressed():
	guardar_seleccion("ET")

func _on_eleven_pressed():
	guardar_seleccion("ELEVEN")

func _on_homer_pressed():
	guardar_seleccion("HOMER")

func guardar_seleccion(personaje: String):
	if seleccionando_jugador == 1:
		personaje_jugador1 = personaje
		print("Jugador 1 seleccionó: ", personaje)
		seleccionando_jugador = 2
		actualizar_titulo()
	elif seleccionando_jugador == 2:
		personaje_jugador2 = personaje
		print("Jugador 2 seleccionó: ", personaje)
		# Ahora ambos jugadores han seleccionado, comenzar juego
		comenzar_juego()

func comenzar_juego():
	var root = get_tree().root
	root.set_meta("personaje1", personaje_jugador1.to_lower())
	root.set_meta("personaje2", personaje_jugador2.to_lower())
	print("Iniciando juego con Jugador1: ", personaje_jugador1, " y Jugador2: ", personaje_jugador2)
	get_tree().change_scene_to_file("res://scenes/mainScene.tscn")
