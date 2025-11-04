extends Control

@onready var icono: TextureRect = $TextureRect
@export var normal_texture: Texture2D
@export var hover_texture: Texture2D

func _ready() -> void:
	icono.texture = normal_texture

func _on_mouse_entered() -> void:
	icono.texture = hover_texture

func _on_mouse_exited() -> void:
	icono.texture = normal_texture

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("Botón presionado")
