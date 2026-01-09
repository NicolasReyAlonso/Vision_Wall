# game_ui.gd
# UI para mostrar vidas, score y estado del juego
extends CanvasLayer

@onready var player1_lives_label: Label = $MarginContainer/HBoxContainer/Player1Panel/VBoxContainer/LivesLabel
@onready var player2_lives_label: Label = $MarginContainer/HBoxContainer/Player2Panel/VBoxContainer/LivesLabel
@onready var player1_score_label: Label = $MarginContainer/HBoxContainer/Player1Panel/VBoxContainer/ScoreLabel
@onready var player2_score_label: Label = $MarginContainer/HBoxContainer/Player2Panel/VBoxContainer/ScoreLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var winner_label: Label = $GameOverPanel/VBoxContainer/WinnerLabel
@onready var start_button: Button = $StartButton

var game_manager: Node = null

func _ready():
	# Buscar el GameManager
	game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		# Si no es autoload, buscarlo en la escena
		game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	
	if game_manager:
		game_manager.player_hit.connect(_on_player_hit)
		game_manager.player_eliminated.connect(_on_player_eliminated)
		game_manager.game_over.connect(_on_game_over)
		game_manager.wall_passed.connect(_on_wall_passed)
	
	game_over_panel.visible = false
	update_ui()

func _on_start_button_pressed():
	if game_manager:
		game_manager.start_game()
		game_over_panel.visible = false
		start_button.visible = false
		update_ui()

func update_ui():
	if not game_manager:
		return
	
	var p1_lives = game_manager.get_player_lives(0)
	var p2_lives = game_manager.get_player_lives(1)
	var p1_score = game_manager.get_player_score(0)
	var p2_score = game_manager.get_player_score(1)
	
	player1_lives_label.text = "Vidas: " + get_hearts(p1_lives)
	player2_lives_label.text = "Vidas: " + get_hearts(p2_lives)
	player1_score_label.text = "Score: " + str(p1_score)
	player2_score_label.text = "Score: " + str(p2_score)

func get_hearts(lives: int) -> String:
	var hearts = ""
	for i in range(lives):
		hearts += "❤️"
	for i in range(3 - lives):
		hearts += "🖤"
	return hearts

func _on_player_hit(player_idx: int, _lives_remaining: int):
	update_ui()
	# Efecto visual de daño
	flash_damage(player_idx)

func _on_player_eliminated(_player_idx: int):
	update_ui()

func _on_game_over(winner_idx: int):
	game_over_panel.visible = true
	if winner_idx >= 0:
		winner_label.text = "¡JUGADOR " + str(winner_idx + 1) + " GANA!"
	else:
		winner_label.text = "¡EMPATE!"
	start_button.visible = true
	start_button.text = "REINICIAR"

func _on_wall_passed(_player_idx: int, _score: int):
	update_ui()

func flash_damage(player_idx: int):
	# Efecto de flash rojo cuando el jugador recibe daño
	var panel = player1_lives_label.get_parent().get_parent() if player_idx == 0 else player2_lives_label.get_parent().get_parent()
	if panel:
		var original_color = panel.modulate
		panel.modulate = Color.RED
		await get_tree().create_timer(0.2).timeout
		panel.modulate = original_color
