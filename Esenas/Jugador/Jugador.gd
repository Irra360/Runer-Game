extends CharacterBody2D

# Velocidades
@export var velocidad_inicial: float = 350.0
@export var velocidad_maxima: float = 650.0
var velocidad_actual: float = 0.0

# Salto y gravedad
@export var fuerza_salto: float = -900.0
@export var gravedad: float = 1200.0

# Referencia al AnimatedSprite2D
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Estado de inicio
var empezo_correr: bool = false
var direccion: int = 1   # 1 = derecha, -1 = izquierda

# Control de pulsaciones
var R: bool = false   # false = aún no se presionó dirección, true = ya se presionó una vez

func _physics_process(delta: float) -> void:
	# --- 1. Procesar entrada ---
	# Derecha (flecha derecha o tecla D)
	if Input.is_action_just_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		manejar_pulsacion(1)
	# Izquierda (flecha izquierda o tecla A)
	elif Input.is_action_just_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		manejar_pulsacion(-1)

	# Reset con tecla abajo (flecha abajo o tecla S)
	if Input.is_action_just_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		empezo_correr = false
		R = false
		velocidad_actual = 0.0
		velocity.x = 0

	# Salto (flecha arriba o tecla W)
	if is_on_floor() and (Input.is_action_just_pressed("ui_up") or Input.is_key_pressed(KEY_W)):
		velocity.y = fuerza_salto

	# Gravedad
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


func manejar_pulsacion(dir: int) -> void:
	direccion = dir
	if not R:
		# Primera pulsación → velocidad inicial
		R = true
		empezo_correr = true
		velocidad_actual = velocidad_inicial
		print("Primera pulsación → vel:", velocidad_actual, "dir:", direccion)
	else:
		# Segunda pulsación (ya estaba R activo) → velocidad máxima
		empezo_correr = true
		velocidad_actual = velocidad_maxima
		print("Segunda pulsación → vel:", velocidad_actual, "dir:", direccion)


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
