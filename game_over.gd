extends CanvasLayer


func _on_volver_pressed() -> void:
	# 🔑 Reinicia la escena del juego
	get_tree().change_scene_to_file("res://Esenas/jugando.tscn")

func _on_salir_pressed() -> void:
	# 🔑 Regresa al menú principal
	get_tree().change_scene_to_file("res://Esenas/Menus/menu_principal.tscn")
