extends TileMap

# --- Dimensiones del mapa ---
@export var ancho: int = 100
@export var alto: int = 60

# --- ID del tileset (source_id) ---
@export var id_fuente_tileset: int = 1  # ID de la fuente del atlas en el TileSet

# --- Control de altura y ruido ---
@export var altura_base: int = 20          # fila base donde se coloca la capa superior
@export var usar_ruido: bool = true         # si true, varía altura por columna con ruido
@export var escala_ruido: float = 0.05      # frecuencia del ruido
@export var fuerza_ruido: int = 3           # variación máxima de altura (tiles)
var ruido := FastNoiseLite.new()

# --- Capas inferiores configurables ---
@export var capas_inferiores: int = 6       # número de capas para (0,2)(1,2)(2,2)

# --- Nodo contenedor de colisiones ---
@onready var colision_mapa: Node = $Colision_mapa
@export var desplazamiento_colision: Vector2 = Vector2(0, 0)

# --- Coordenadas del atlas ---
const SUPERIOR_OPCIONES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const MEDIO_MAPEO := {
	Vector2i(0, 0): Vector2i(0, 1),
	Vector2i(1, 0): Vector2i(1, 1),
	Vector2i(2, 0): Vector2i(2, 1)
}
const INFERIOR_OPCIONES: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_configurar_ruido()
	generar_mapa()
	generar_colisiones()

func _configurar_ruido() -> void:
	ruido.seed = randi()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ruido.frequency = escala_ruido

# --------------------------------
# Generación del mapa
# --------------------------------
func generar_mapa() -> void:
	clear()
	var capa := 0

	for x in range(ancho):
		# Altura de superficie por columna
		var y_superficie := altura_base
		if usar_ruido:
			var n := ruido.get_noise_1d(float(x))
			y_superficie = altura_base + int(round(n * float(fuerza_ruido)))
			y_superficie = clamp(y_superficie, 0, alto - 1)

		# Evitar escribir fuera del alto del mapa
		if y_superficie >= alto:
			continue

		# --- Capa superior: una sola fila, aleatoria entre (0,0)(1,0)(2,0) ---
		var coord_sup := SUPERIOR_OPCIONES[rng.randi() % SUPERIOR_OPCIONES.size()]
		set_cell(capa, Vector2i(x, y_superficie), id_fuente_tileset, coord_sup)

		# --- Capas medias: siempre 2 filas debajo, mapa directo (0,1)(1,1)(2,1) ---
		var coord_medio: Vector2i = MEDIO_MAPEO.get(coord_sup, Vector2i(1, 1))
		var y_medio_1 := y_superficie + 1
		var y_medio_2 := y_superficie + 2
		if y_medio_1 < alto:
			set_cell(capa, Vector2i(x, y_medio_1), id_fuente_tileset, coord_medio)
		if y_medio_2 < alto:
			set_cell(capa, Vector2i(x, y_medio_2), id_fuente_tileset, coord_medio)

		# --- Capas inferiores: N filas aleatorias entre (0,2)(1,2)(2,2) ---
		for d in range(capas_inferiores):
			var y_inf := y_superficie + 3 + d
			if y_inf >= alto:
				break
			var coord_inf := INFERIOR_OPCIONES[rng.randi() % INFERIOR_OPCIONES.size()]
			set_cell(capa, Vector2i(x, y_inf), id_fuente_tileset, coord_inf)

# --------------------------------
# Colisiones en la capa superior
# --------------------------------
func generar_colisiones() -> void:
	# Limpiar colisiones anteriores
	for child in colision_mapa.get_children():
		child.queue_free()

	var tam_celda: Vector2 = tile_set.tile_size

	# Recorre todas las celdas usadas en la capa 0
	for celda in get_used_cells(0):
		# Colisión solo en la fila superior (la más alta que colocamos en cada columna)
		# Detectamos si es una coordenada de la capa superior del atlas.
		var source_id := get_cell_source_id(0, celda)
		var atlas_coord := get_cell_atlas_coords(0, celda)

		var es_superior := (source_id == id_fuente_tileset and atlas_coord in SUPERIOR_OPCIONES)
		if not es_superior:
			continue

		var forma := RectangleShape2D.new()
		forma.size = tam_celda

		var col := CollisionShape2D.new()
		col.shape = forma
		col.position = map_to_local(celda) + (tam_celda / 2) + desplazamiento_colision
		colision_mapa.add_child(col)
