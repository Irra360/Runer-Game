extends TileMap

# --- Parámetros configurables ---
@export var width: int = 100
@export var height: int = 60
@export var noise_scale: float = 0.08
@export var threshold: float = 0.0

@export var ground_tile_id: int = 1   # ID del Atlas (no del subtile)
@export var air_tile_id: int = -1     # -1 = vacío

# Lista de coordenadas dentro del Atlas que se usarán como variación de suelo
@export var ground_tiles_coords: Array[Vector2i] = [
	Vector2i(0, 1),  # primer tile (ej. tierra con pasto)
	Vector2i(1, 1),  # segundo tile (ej. tierra normal)
	Vector2i(2, 1)   # puedes añadir más
]

var noise := FastNoiseLite.new()

func _ready():
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_scale

	generate_map()

func generate_map():
	clear()
	var layer := 0

	for x in range(width):
		for y in range(height):
			var n := noise.get_noise_2d(float(x), float(y))
			if n > threshold:
				# Elegir aleatoriamente un subtile del atlas
				var coord := ground_tiles_coords[randi() % ground_tiles_coords.size()]
				set_cell(layer, Vector2i(x, y), ground_tile_id, coord)
			else:
				set_cell(layer, Vector2i(x, y), air_tile_id)

	seal_borders()

# Cierra los bordes para que no queden huecos
func seal_borders():
	var layer := 0
	for x in range(width):
		set_cell(layer, Vector2i(x, 0), ground_tile_id, ground_tiles_coords[0])
		set_cell(layer, Vector2i(x, height - 1), ground_tile_id, ground_tiles_coords[0])
	for y in range(height):
		set_cell(layer, Vector2i(0, y), ground_tile_id, ground_tiles_coords[0])
		set_cell(layer, Vector2i(width - 1, y), ground_tile_id, ground_tiles_coords[0])

# Regenerar con nueva semilla
func regenerate():
	noise.seed = randi()
	generate_map()
