extends TileMap

# --- Dimensiones del mapa ---
@export var width: int = 100
@export var height: int = 60

# --- ID del tileset (source_id) ---
@export var ground_tile_id: int = 1   # 🔑 fijo en 1

# --- Coordenadas del atlas para la fila superior ---
const TOP_A_LEFT: Vector2i = Vector2i(0, 1)
const TOP_A_RIGHT: Vector2i = Vector2i(1, 1)
const TOP_B_LEFT: Vector2i = Vector2i(2, 1)
const TOP_B_RIGHT: Vector2i = Vector2i(3, 1)
const TOP_C_OPTS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]

# --- Coordenadas del atlas para la fila inferior (solo un nivel) ---
const BOT_A_LEFT: Vector2i = Vector2i(0, 2)
const BOT_A_RIGHT: Vector2i = Vector2i(1, 2)
const BOT_B_LEFT: Vector2i = Vector2i(2, 2)
const BOT_B_RIGHT: Vector2i = Vector2i(3, 2)
const BOT_C_OPTS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2)]

# --- Altura base de superficie ---
@export var surface_y: int = 20

# --- Nodo contenedor de colisiones ---
@onready var colision_mapa: Node = $Colision_mapa
@export var collision_offset: Vector2 = Vector2(0, 0)

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	generate_map()
	generate_collisions()

# --------------------------------
# Generación del mapa (fila superior + un nivel inferior)
# --------------------------------
func generate_map() -> void:
	clear()
	var layer := 0

	# Grupo A al inicio
	set_cell(layer, Vector2i(0, surface_y), ground_tile_id, TOP_A_LEFT)
	set_cell(layer, Vector2i(1, surface_y), ground_tile_id, TOP_A_RIGHT)

	# Grupo B al final
	set_cell(layer, Vector2i(width - 2, surface_y), ground_tile_id, TOP_B_LEFT)
	set_cell(layer, Vector2i(width - 1, surface_y), ground_tile_id, TOP_B_RIGHT)

	# Grupo C entre A y B
	for x in range(2, width - 2):
		var coord_top := TOP_C_OPTS[rng.randi() % TOP_C_OPTS.size()]
		set_cell(layer, Vector2i(x, surface_y), ground_tile_id, coord_top)

	# --- Generar un nivel inferior bajo cada tile superior ---
	for x in range(width):
		var top_coord := get_cell_atlas_coords(layer, Vector2i(x, surface_y))
		var bot_coord: Vector2i

		if top_coord == TOP_A_LEFT:
			bot_coord = BOT_A_LEFT
		elif top_coord == TOP_A_RIGHT:
			bot_coord = BOT_A_RIGHT
		elif top_coord == TOP_B_LEFT:
			bot_coord = BOT_B_LEFT
		elif top_coord == TOP_B_RIGHT:
			bot_coord = BOT_B_RIGHT
		else:
			# Grupo C abajo aleatorio
			bot_coord = BOT_C_OPTS[rng.randi() % BOT_C_OPTS.size()]

		set_cell(layer, Vector2i(x, surface_y + 1), ground_tile_id, bot_coord)

# --------------------------------
# Colisiones en la fila superior
# --------------------------------
func generate_collisions() -> void:
	# Limpia colisiones anteriores
	for child in colision_mapa.get_children():
		child.queue_free()

	var cell_size: Vector2 = tile_set.tile_size

	for cell in get_used_cells(0):
		if cell.y != surface_y:
			continue

		var source_id := get_cell_source_id(0, cell)
		var atlas_coord := get_cell_atlas_coords(0, cell)

		if source_id == ground_tile_id and (
			atlas_coord == TOP_A_LEFT or atlas_coord == TOP_A_RIGHT or
			atlas_coord == TOP_B_LEFT or atlas_coord == TOP_B_RIGHT
		):
			var shape := RectangleShape2D.new()
			shape.size = cell_size

			var col := CollisionShape2D.new()
			col.shape = shape
			col.position = map_to_local(cell) + (cell_size / 2) + collision_offset
			colision_mapa.add_child(col)
