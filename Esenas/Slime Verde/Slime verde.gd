extends CharacterBody2D

# --- Parámetros ajustables ---
@export var velocidad_movimiento: float = 80.0
@export var fuerza_salto: float = -280.0
@export var gravedad: float = 900.0
@export var multiplicador_salto_x: float = 1.5
@export var tiempo_min_cambio_dir: float = 2.0
@export var tiempo_max_cambio_dir: float = 10.0
@export var pausa_cambio_dir: float = 0.15
@export var tiempo_cooldown_salto: float = 0.8
@export var tiempo_min_suelo_para_salto: float = 0.2
@export var daño: int = 5                        # 🔑 daño que hace el slime
@export var tiempo_cooldown_ataque: float = 1.0  # 🔑 tiempo entre ataques

# --- Nodos ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var temporizador_salto: Timer = $Timer
@onready var temporizador_dir: Timer = Timer.new()
@onready var detector_jugador: Area2D = $"Detector del jugador"
@onready var area_ataque: Area2D = $Ataque
@onready var temporizador_ataque: Timer = Timer.new()

# --- Estado ---
var direccion: int = 1
var rng := RandomNumberGenerator.new()
var preparando_salto: bool = false
var pausando_por_cambio: bool = false
var tiempo_desde_ultimo_salto: float = 999.0
var tiempo_en_suelo: float = 0.0
var bloqueo_salto_pared: bool = false
var jugador: Node = null
var persiguiendo: bool = false
var jugador_en_rango: Node = null

func _ready() -> void:
	rng.randomize()

	add_child(temporizador_dir)
	temporizador_dir.one_shot = true
	temporizador_dir.timeout.connect(_on_temporizador_dir_timeout)
	temporizador_salto.timeout.connect(_on_temporizador_salto_timeout)

	# 🔑 Conectar señales del detector de jugador
	detector_jugador.body_entered.connect(_on_detector_entered)
	detector_jugador.body_exited.connect(_on_detector_exited)

	# 🔑 Conectar señales del área de ataque
	area_ataque.body_entered.connect(_on_ataque_entered)
	area_ataque.body_exited.connect(_on_ataque_exited)

	# 🔑 Configurar temporizador de ataque
	add_child(temporizador_ataque)
	temporizador_ataque.one_shot = true
	temporizador_ataque.timeout.connect(_on_temporizador_ataque_timeout)

	_programar_siguiente_salto()
	_programar_siguiente_cambio_dir()
	anim.play("idle")

func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y += gravedad * delta

	# Contadores
	tiempo_desde_ultimo_salto += delta
	if is_on_floor():
		tiempo_en_suelo += delta
		bloqueo_salto_pared = false
	else:
		tiempo_en_suelo = 0.0

	# Movimiento
	if preparando_salto or pausando_por_cambio:
		velocity.x = 0
		anim.play("idle")
	else:
		if persiguiendo and jugador:
			direccion = sign(jugador.global_position.x - global_position.x)
		if is_on_floor():
			velocity.x = direccion * velocidad_movimiento
			anim.play("walk")
		else:
			velocity.x = direccion * velocidad_movimiento * multiplicador_salto_x
			if velocity.y < 0.0:
				anim.play("jump")

	# Salto por pared
	if is_on_wall() and is_on_floor() and not preparando_salto:
		if _puede_saltar() and not bloqueo_salto_pared:
			_hacer_salto()
			bloqueo_salto_pared = true

	# Orientación visual
	anim.flip_h = (direccion < 0)

	move_and_slide()

# --- Señales del Detector del jugador ---
func _on_detector_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		jugador = body
		persiguiendo = true

func _on_detector_exited(body: Node) -> void:
	if body == jugador:
		jugador = null
		persiguiendo = false

# --- Señales del Área de Ataque ---
func _on_ataque_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		jugador_en_rango = body
		_iniciar_ataque()

func _on_ataque_exited(body: Node) -> void:
	if body == jugador_en_rango:
		jugador_en_rango = null

func _iniciar_ataque() -> void:
	if not temporizador_ataque.is_stopped():
		return # 🔑 evita daño masivo, espera cooldown
	if jugador_en_rango and jugador_en_rango.has_method("recibir_daño"):
		jugador_en_rango.recibir_daño(daño)
		anim.play("attack")
	temporizador_ataque.start(tiempo_cooldown_ataque)

func _on_temporizador_ataque_timeout() -> void:
	# Si el jugador sigue en rango, volver a atacar
	if jugador_en_rango:
		_iniciar_ataque()

# --- Saltos aleatorios ---
func _on_temporizador_salto_timeout() -> void:
	if _puede_saltar():
		preparando_salto = true
		velocity.x = 0
		anim.play("idle")

		await get_tree().create_timer(0.3).timeout
		_hacer_salto()
		preparando_salto = false
	_programar_siguiente_salto()

func _hacer_salto() -> void:
	if is_on_floor():
		velocity.y = fuerza_salto
		anim.play("jump")
		tiempo_desde_ultimo_salto = 0.0

func _puede_saltar() -> bool:
	return is_on_floor() and tiempo_desde_ultimo_salto >= tiempo_cooldown_salto and tiempo_en_suelo >= tiempo_min_suelo_para_salto

func _programar_siguiente_salto() -> void:
	var espera := rng.randf_range(3.0, 10.0)
	temporizador_salto.wait_time = espera
	temporizador_salto.start()

# --- Cambio de dirección natural ---
func _on_temporizador_dir_timeout() -> void:
	if is_on_floor() and not preparando_salto and not persiguiendo:
		direccion *= -1
		pausando_por_cambio = true
		await get_tree().create_timer(pausa_cambio_dir).timeout
		pausando_por_cambio = false
	_programar_siguiente_cambio_dir()

func _programar_siguiente_cambio_dir() -> void:
	var espera := rng.randf_range(tiempo_min_cambio_dir, tiempo_max_cambio_dir)
	temporizador_dir.wait_time = espera
	temporizador_dir.start()
