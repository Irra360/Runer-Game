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
@export var daño: int = 5
@export var tiempo_cooldown_ataque: float = 1.0

# --- Vida del slime ---
@export var vida_maxima: int = 30
var vida_actual: int = vida_maxima

# --- Nodos ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var temporizador_salto: Timer = $Timer
@onready var temporizador_dir: Timer = Timer.new()
@onready var detector_jugador: Area2D = $"Detector del jugador"
@onready var area_ataque: Area2D = $Ataque
@onready var temporizador_ataque: Timer = Timer.new()
@onready var vida_label: Label = $VidaLabel

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
var atacando: bool = false

func _ready() -> void:
	rng.randomize()

	add_child(temporizador_dir)
	temporizador_dir.one_shot = true
	temporizador_dir.timeout.connect(_on_temporizador_dir_timeout)
	temporizador_salto.timeout.connect(_on_temporizador_salto_timeout)

	detector_jugador.body_entered.connect(_on_detector_entered)
	detector_jugador.body_exited.connect(_on_detector_exited)

	area_ataque.body_entered.connect(_on_ataque_entered)
	area_ataque.body_exited.connect(_on_ataque_exited)

	add_child(temporizador_ataque)
	temporizador_ataque.one_shot = true
	temporizador_ataque.timeout.connect(_on_temporizador_ataque_timeout)

	_programar_siguiente_salto()
	_programar_siguiente_cambio_dir()
	anim.play("idle")
	_actualizar_label()

func _physics_process(delta: float) -> void:
	_verificar_estado_jugador()

	if not is_on_floor():
		velocity.y += gravedad * delta

	tiempo_desde_ultimo_salto += delta
	if is_on_floor():
		tiempo_en_suelo += delta
		bloqueo_salto_pared = false
	else:
		tiempo_en_suelo = 0.0

	if preparando_salto or pausando_por_cambio:
		velocity.x = 0
		if not atacando:
			anim.play("idle")
	else:
		if persiguiendo and jugador:
			direccion = sign(jugador.global_position.x - global_position.x)
		if is_on_floor():
			velocity.x = direccion * velocidad_movimiento
			if not atacando:
				anim.play("run")
		else:
			velocity.x = direccion * velocidad_movimiento * multiplicador_salto_x
			if velocity.y < 0.0 and not atacando:
				anim.play("jump")

	if is_on_wall() and is_on_floor() and not preparando_salto:
		if _puede_saltar() and not bloqueo_salto_pared:
			_hacer_salto()
			bloqueo_salto_pared = true

	anim.flip_h = (direccion < 0)
	move_and_slide()

# --- Verificación del estado del jugador ---
func _verificar_estado_jugador() -> void:
	if jugador and jugador.has_method("esta_muerto") and jugador.esta_muerto():
		jugador = null
		jugador_en_rango = null
		persiguiendo = false
		atacando = false
		# Pequeño despegue por si está montado
		global_position.y -= 8
		velocity.y = fuerza_salto

# --- Sistema de vida del slime ---
func recibir_daño(cantidad: int) -> void:
	vida_actual -= cantidad
	if vida_actual < 0:
		vida_actual = 0
	_actualizar_label()

	if vida_actual <= 0:
		morir()

func _actualizar_label() -> void:
	if vida_label:
		vida_label.text = "Vida Slime: %d" % vida_actual

func morir() -> void:
	if anim.sprite_frames.has_animation("muerto"):
		anim.play("muerto")
	await get_tree().create_timer(1.0).timeout
	queue_free()

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
		atacando = false

func _iniciar_ataque() -> void:
	if not temporizador_ataque.is_stopped():
		return
	if jugador_en_rango and jugador_en_rango.has_method("recibir_daño") and jugador_en_rango.has_method("esta_muerto") and not jugador_en_rango.esta_muerto():
		jugador_en_rango.recibir_daño(daño)
		anim.play("attack")
		atacando = true
		temporizador_ataque.start(tiempo_cooldown_ataque)

		# --- Salto evasivo tras atacar ---
		var direccion_salto := -1 if rng.randi_range(0, 1) == 0 else 1
		velocity.x = direccion_salto * velocidad_movimiento * 1.5
		velocity.y = fuerza_salto * 1.5
	else:
		atacando = false
		if velocity.x != 0:
			anim.play("run")
		else:
			anim.play("idle")

func _on_temporizador_ataque_timeout() -> void:
	if jugador_en_rango and jugador_en_rango.has_method("esta_muerto") and not jugador_en_rango.esta_muerto():
		_iniciar_ataque()
	else:
		atacando = false
		if velocity.x != 0:
			anim.play("run")
		else:
			anim.play("idle")

# --- Saltos aleatorios ---
func _on_temporizador_salto_timeout() -> void:
	if _puede_saltar():
		preparando_salto = true
		velocity.x = 0
		if not atacando:
			anim.play("idle")
		await get_tree().create_timer(0.3).timeout
		_hacer_salto()
		preparando_salto = false
	_programar_siguiente_salto()

func _hacer_salto() -> void:
	if is_on_floor():
		velocity.y = fuerza_salto
		if not atacando:
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
