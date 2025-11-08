extends CharacterBody2D

# --- Velocidades ---
@export var velocidad_inicial: float = 350.0
@export var velocidad_maxima: float = 650.0
var velocidad_actual: float = 0.0

# --- Salto y gravedad ---
@export var fuerza_salto: float = -900.0
@export var gravedad: float = 1200.0

# --- Vida del jugador ---
@export var vida_maxima: int = 20
var vida_actual: int = vida_maxima

# --- Nodos ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var vida_label: Label = $VidaLabel

# --- Estado ---
var empezo_correr: bool = false
var direccion: int = 1
var R: bool = false

# --- Idle extendido ---
var tiempo_idle: float = 0.0
var reproduciendo_idleinter: bool = false
var esta_muerto: bool = false

func _ready() -> void:
	add_to_group("Player")
	_actualizar_label()
	anim.animation_finished.connect(_on_anim_finished)

func _physics_process(delta: float) -> void:
	if esta_muerto:
		return # bloquea movimiento y cambios de animación

	# Entrada
	if Input.is_action_just_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		manejar_pulsacion(1)
	elif Input.is_action_just_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		manejar_pulsacion(-1)

	if Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		empezo_correr = false
		R = false
		velocidad_actual = 0.0
		velocity.x = 0

	if is_on_floor() and (Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_W)):
		velocity.y = fuerza_salto

	# Gravedad
	if not is_on_floor():
		velocity.y += gravedad * delta

	# Velocidad horizontal
	if empezo_correr:
		velocity.x = velocidad_actual * direccion
	else:
		velocity.x = 0

	move_and_slide()
	actualizar_animaciones(delta)

func manejar_pulsacion(dir: int) -> void:
	if esta_muerto:
		return
	direccion = dir
	if not R:
		R = true
		empezo_correr = true
		velocidad_actual = velocidad_inicial
	else:
		empezo_correr = true
		velocidad_actual = velocidad_maxima

func actualizar_animaciones(delta: float) -> void:
	if esta_muerto:
		return

	# En el aire
	if not is_on_floor():
		_set_anim_safe("jump")
		if velocity.x != 0:
			anim.flip_h = velocity.x < 0
		tiempo_idle = 0.0
		reproduciendo_idleinter = false
		return

	# En movimiento
	if velocity.x != 0:
		if velocidad_actual >= velocidad_maxima:
			_set_anim_safe("runrun")
		else:
			_set_anim_safe("run")
		anim.flip_h = (direccion == -1)
		tiempo_idle = 0.0
		reproduciendo_idleinter = false
		return

	# Idle prolongado
	tiempo_idle += delta
	if not reproduciendo_idleinter and tiempo_idle >= 8.0 and anim.sprite_frames.has_animation("idleinter"):
		reproduciendo_idleinter = true
		_set_anim_force("idleinter")
	else:
		if not reproduciendo_idleinter:
			_set_anim_safe("idle")

func _on_anim_finished() -> void:
	if reproduciendo_idleinter:
		reproduciendo_idleinter = false
		tiempo_idle = 0.0
		_set_anim_safe("idle")

# --- Sistema de vida ---
func recibir_daño(cantidad: int) -> void:
	if esta_muerto:
		return
	vida_actual -= cantidad
	if vida_actual < 0:
		vida_actual = 0
	_actualizar_label()

	if vida_actual <= 0:
		morir()
	else:
		if anim.sprite_frames.has_animation("hit") and not reproduciendo_idleinter:
			_set_anim_force("hit")

func morir() -> void:
	esta_muerto = true
	velocity = Vector2.ZERO
	empezo_correr = false

	# 🔑 reproducir animación "muerto"
	if anim.sprite_frames.has_animation("muerto"):
		_set_anim_force("muerto")

	# 🔑 esperar 3 segundos y luego ir a la escena Game Over
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Esenas/GAME OVER/game_over.tscn")

func _actualizar_label() -> void:
	vida_label.text = "Vida: %d" % vida_actual

# --- Utilidades de animación ---
func _set_anim_safe(nombre: String) -> void:
	if anim.animation != nombre and anim.sprite_frames.has_animation(nombre):
		anim.play(nombre)

func _set_anim_force(nombre: String) -> void:
	if anim.sprite_frames.has_animation(nombre):
		anim.play(nombre)
