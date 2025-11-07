extends Control

func _on_jugar_pressed() -> void:        #Empesar a jugar
	var error = get_tree().change_scene_to_file("res://Esenas/jugando.tscn")
	if error != OK:
		push_error("res://Esenas/jugando.tscn")
 
func _on_texture_button_pressed() -> void:  #Salir del Juego
	get_tree().quit()



func _on_Creditos_button_pressed() -> void:         #Creditos
	pass 
	var error = get_tree().change_scene_to_file("res://Menus/Creditos/Creditosl.tscn")


func opciones_on_opciones_pressed() -> void:
	pass 
	var error = get_tree().change_scene_to_file("res://Esenas/Menus/Opciones.tscn")
