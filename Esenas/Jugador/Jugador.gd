extends CharacterBody2D

# --- Velocidades ---
@export var velocidad_inicial: float = 350.0
@export var velocidad_maxima: float = 650.0
var velocidad_actual: float = 0.0

# --- Salto y gravedad ---
@export var fuerza_salto: float = -900.0
@export var gravedad: float = 1200.0

# --- Vida del jugador ---
@export var vida_maxima: int = 100
var vida_actual: int = vida_maxima
var esta_muerto_flag: bool = false

# --- Nodos ---
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var vida_label: Label = $VidaLabel
@onready var temporizador: Timer = $Timer   # Timer en la escena

# --- Estado de inicio ---
var empezo_correr: bool = false
var direccion: int = 1   # 1 = derecha, -1 = izquierda
var R: bool = false      # false = aún no se presionó dirección, true = ya se presionó una vez

func _ready() -> void:
	_actualizar_label()
	temporizador.one_shot = true
	temporizador.timeout.connect(_on_temporizador_timeout)

func _physics_process(delta: float) -> void:
	if esta_muerto_flag:
		velocity = Vector2.ZERO
		return

	# --- 1. Procesar entrada ---
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

	if not is_on_floor():
		velocity.y += gravedad * delta

	# --- 2. Asignar velocidad horizontal ---
	if empezo_correr:
		velocity.x = velocidad_actual * direccion
	else:
		velocity.x = 0

	# --- 3. Mover al jugador ---
	move_and_slide()

	# --- 4. Animaciones ---
	actualizar_animaciones()

# --- Manejo de pulsaciones ---
func manejar_pulsacion(dir: int) -> void:
	if dir != direccion:
		# Cambió de dirección → reinicia carrera
		direccion = dir
		R = false
		empezo_correr = true
		velocidad_actual = velocidad_inicial
	else:
		if not R:
			# Primera pulsación en esta dirección
			R = true
			empezo_correr = true
			velocidad_actual = velocidad_inicial
		else:
			# Segunda pulsación → correr
			empezo_correr = true
			velocidad_actual = velocidad_maxima

# --- Animaciones ---
func actualizar_animaciones() -> void:
	if not is_on_floor():
		anim.play("jump")
		return

	if velocity.x != 0:
		if velocidad_actual >= velocidad_maxima:
			anim.play("runrun")
		else:
			anim.play("run")
		anim.flip_h = direccion == -1
		return

	anim.play("idle")

# --- Sistema de vida ---
func recibir_daño(cantidad: int) -> void:
	if esta_muerto_flag:
		return
	vida_actual -= cantidad
	if vida_actual < 0:
		vida_actual = 0
	_actualizar_label()

	if vida_actual <= 0:
		morir()

func _actualizar_label() -> void:
	if vida_label:
		vida_label.text = "Vida: %d" % vida_actual

func morir() -> void:
	esta_muerto_flag = true
	velocity = Vector2.ZERO
	if anim.sprite_frames.has_animation("muerto"):
		anim.play("muerto")
	temporizador.start(2.0)  # espera 2 segundos antes de cambiar de escena

# --- Estado para el slime ---
func esta_vivo() -> bool:
	return not esta_muerto_flag

func esta_muerto() -> bool:
	return esta_muerto_flag

# --- Timer ---
func _on_temporizador_timeout() -> void:
	get_tree().change_scene_to_file("res://Esenas/GAME OVER/game_over.tscn")
