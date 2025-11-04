extends TileMap

@export var width: int = 100
@export var height: int = 60
@export var base_height: int = 20      # altura base del suelo
@export var noise_scale: float = 0.05   # escala del ruido
@export var noise_strength: int = 3   # variación máxima de altura

@export var ground_tile_id: int = 1    # ID del atlas
@export var grass_tiles: Array[Vector2i] = [
	Vector2i(0, 0),  # césped 1
	Vector2i(1, 0)   # césped 2
]
@export var dirt_tiles: Array[Vector2i] = [
	Vector2i(0, 1),  # tierra 1
	Vector2i(1, 1)   # tierra 2
]

var noise := FastNoiseLite.new()

# Nodo contenedor de colisiones (debe ser un StaticBody2D en tu escena)
@onready var colision_mapa := $Colision_mapa

# Offset manual para ajustar colisiones (ejemplo: 2 px a la derecha, 2 px arriba)
@export var collision_offset: Vector2 = Vector2(-8.5 , -6.5)

func _ready():
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_scale

	generate_map()
	generate_collisions()

# -------------------------------
# Generación del mapa
# -------------------------------
func generate_map():
	clear()
	var layer := 0

	for x in range(width):
		# calcular altura del suelo con ruido
		var n := noise.get_noise_1d(float(x))
		var surface_y := base_height + int(round(n * noise_strength))

		# --- Césped en la superficie ---
		var grass_coord := grass_tiles[randi() % grass_tiles.size()]
		set_cell(layer, Vector2i(x, surface_y), ground_tile_id, grass_coord)

		# --- Tierra debajo (mínimo 8 niveles) ---
		for y in range(surface_y + 1, min(surface_y + 9, height)):
			var dirt_coord := dirt_tiles[randi() % dirt_tiles.size()]
			set_cell(layer, Vector2i(x, y), ground_tile_id, dirt_coord)

		# --- Rellenar hasta el fondo con tierra ---
		for y in range(surface_y + 9, height):
			var dirt_coord := dirt_tiles[randi() % dirt_tiles.size()]
			set_cell(layer, Vector2i(x, y), ground_tile_id, dirt_coord)

# -------------------------------
# Generación de colisiones en césped
# -------------------------------
func generate_collisions():
	# Limpia colisiones anteriores
	for child in colision_mapa.get_children():
		child.queue_free()

	var cell_size: Vector2 = tile_set.tile_size

	# Recorre todas las celdas usadas en el TileMap
	for cell in get_used_cells(0):
		var id = get_cell_source_id(0, cell)
		var coord = get_cell_atlas_coords(0, cell)

		# Si es un tile de césped
		if id == ground_tile_id and coord in grass_tiles:
			var shape := RectangleShape2D.new()
			shape.size = cell_size

			var col := CollisionShape2D.new()
			col.shape = shape
			# Ajuste de posición: centro del tile + offset manual
			col.position = map_to_local(cell) + (cell_size / 2) + collision_offset

			colision_mapa.add_child(col)
