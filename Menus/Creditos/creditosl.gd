extends Control

var velocidad = 50  

func _process(delta: float) -> void:
	# Mueve el nodo Personal
	var personal = $Node2D/Personal
	personal.position.y -= velocidad * delta

	# Mueve el nodo Desarrolladora
	var desarrolladora = $Node2D/Desarrolladora
	desarrolladora.position.y -= velocidad * delta


func _on_texture_button_pressed() -> void:
	var error = get_tree().change_scene_to_file("res://Esenas/Menus/menu_principal.tscn")
