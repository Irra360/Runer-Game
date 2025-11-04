func _on_slider_value_changed(value: float) -> void:
	var porcentaje = value * 5
	print("Volumen: ", porcentaje, "%")

	# Ejemplo: aplicarlo al bus de música
	var db = linear_to_db(porcentaje / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)
