# SlimeGreen.gd
extends CharacterBody2D

# Estados
enum State { PATROL, CHASE, ATTACK, DAMAGE, DEAD }

# --- Exported (tuneable en el Inspector)
@export var max_health: int = 40
@export var patrol_left: Vector2 = Vector2(-100, 0)   # offset relativo desde la posición de inicio
@export var patrol_right: Vector2 = Vector2(100, 0)   # offset relativo desde la posición de inicio
@export var patrol_speed: float = 60.0
@export var chase_speed: float = 120.0
@export var gravity: float = 1400.0
@export var floor_normal: Vector2 = Vector2.UP

@export var detection_radius: float = 200.0
@export var attack_damage: int = 20
@export var attack_cooldown: float = 0.6
@export var dead_cleanup_time: float = 5.0

# NodePaths (configura en el Inspector o deja en blanco para resolución automática)
@export var sprite_node_path: NodePath = NodePath("AnimatedSprite2D")
@export var hitbox_area_path: NodePath = NodePath("Hitbox")
@export var ray_ground_path: NodePath = NodePath("RayCast2D")
@export var player_path: NodePath = NodePath("")

# --- Internals
var health: int = 0
var state: State = State.PATROL
var velocity: Vector2 = Vector2.ZERO
var facing: int = 1   # 1 = derecha, -1 = izquierda

var patrol_target_a: Vector2
var patrol_target_b: Vector2
var current_patrol_target: Vector2

var last_attack_time: float = -9999.0

# nodos resueltos en _ready
onready var sprite: AnimatedSprite2D = null
onready var hitbox_area: Area2D = null
onready var ray_ground: RayCast2D = null
onready var player: Node = null

# señales
signal died
signal damaged(amount)

func _ready() -> void:
	# resolver nodos por NodePath o por nombres comunes
	if sprite_node_path != NodePath(""):
		sprite = get_node_or_null(sprite_node_path) as AnimatedSprite2D
	if not sprite and has_node("AnimatedSprite2D"):
		sprite = $AnimatedSprite2D as AnimatedSprite2D

	if hitbox_area_path != NodePath(""):
		hitbox_area = get_node_or_null(hitbox_area_path) as Area2D
	if not hitbox_area and has_node("Hitbox"):
		hitbox_area = $Hitbox as Area2D

	if ray_ground_path != NodePath(""):
		ray_ground = get_node_or_null(ray_ground_path) as RayCast2D
	if not ray_ground and has_node("RayCast2D"):
		ray_ground = $RayCast2D as RayCast2D

	if player_path != NodePath(""):
		player = get_node_or_null(player_path)
	if not player:
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player = players[0]

	# validar Sprite y animaciones
	health = max_health
	patrol_target_a = global_position + patrol_left
	patrol_target_b = global_position + patrol_right
	current_patrol_target = patrol_target_b

	if sprite:
		# comprobar animaciones en SpriteFrames (AnimatedSprite2D.frames)
		var frames := sprite.frames
		if frames:
			var required = ["run", "attack", "damage", "dead"]
			for a in required:
				if not frames.has_animation(a):
					push_warning("SlimeGreen: falta animación '%s' en SpriteFrames" % a)
			if frames.has_animation("run"):
				sprite.play("run")
			else:
				var names = frames.get_animation_names()
				if names.size() > 0:
					sprite.play(names[0])
		else:
			push_warning("SlimeGreen: AnimatedSprite2D.frames es null")
	else:
		push_warning("SlimeGreen: AnimatedSprite2D no encontrado en la escena")

	# conectar hitbox
	if hitbox_area:
		if not hitbox_area.is_connected("body_entered", Callable(self, "_on_hitbox_body_entered")):
			hitbox_area.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))

	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_apply_gravity(delta)
	_update_state_and_movement(delta)
	_update_animation()

	# aplicar movimiento (CharacterBody2D.velocity se usa internamente)
	velocity = move_and_slide(velocity, floor_normal)

func _apply_gravity(delta: float) -> void:
	# si no está en el suelo, aplicar gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# reset suave de componente vertical cuando está en suelo
		if velocity.y > 0:
			velocity.y = 0

func _update_state_and_movement(delta: float) -> void:
	# comprobar muerte
	if health <= 0:
		_enter_dead()
		return

	# obtener posición del jugador si existe
	var player_pos: Vector2 = null
	if player and player.has_method("global_position"):
		player_pos = player.global_position

	var dist_to_player := 1e9
	if player_pos:
		dist_to_player = global_position.distance_to(player_pos)

	# si está en daño, esperar recuperación
	if state == State.DAMAGE:
		return

	# detección y persecución
	if player_pos and dist_to_player <= detection_radius:
		state = State.CHASE
		_chase_player(player_pos, delta)
	else:
		if state != State.PATROL:
			state = State.PATROL
		_patrol(delta)

func _patrol(delta: float) -> void:
	var target := current_patrol_target
	var dir := (target - global_position)
	if dir.length() < 6.0:
		# invertir destino
		current_patrol_target = (patrol_target_a if current_patrol_target == patrol_target_b else patrol_target_b)
		dir = (current_patrol_target - global_position)
	if dir.length() > 0:
		dir = dir.normalized()
		velocity.x = dir.x * patrol_speed
		facing = int(sign(velocity.x)) if velocity.x != 0 else facing
	else:
		velocity.x = 0

func _chase_player(player_pos: Vector2, delta: float) -> void:
	var dir := (player_pos - global_position)
	if dir.length() > 0:
		dir = dir.normalized()
		velocity.x = dir.x * chase_speed
		facing = int(sign(velocity.x)) if velocity.x != 0 else facing
	else:
		velocity.x = 0

func _update_animation() -> void:
	if not sprite:
		return

	var frames := sprite.frames


# --- Colisiones entrantes (hitbox) ---
func _on_hitbox_body_entered(body: Node) -> void:
	if state == State.DEAD:
		return

	# colisión con jugador: aplicar daño al jugador y cambiar a ATTACK
	if body.is_in_group("Player"):
		if body.has_method("apply_damage"):
			body.apply_damage(attack_damage)
		elif "health" in body:
			body.health = max(0, int(body.health) - attack_damage)
		state = State.ATTACK
		last_attack_time = Time.get_ticks_msec() / 1000.0
		return

	# colisión con proyectil/arma del jugador: detectar daño
	# se admiten: has_method("get_damage"), metadata "damage", o propiedad damage
	if body.has_method("get_damage") or body.has_meta("damage") or "damage" in body:
		var dmg: int = 1
		if body.has_method("get_damage"):
			dmg = int(body.get_damage())
		elif body.has_meta("damage"):
			dmg = int(body.get_meta("damage"))
		elif "damage" in body:
			dmg = int(body.damage)
		_apply_damage(dmg)
		# eliminar proyectil si procede
		if body.has_method("queue_free"):
			body.queue_free()

func _apply_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	health -= amount
	emit_signal("damaged", amount)
	state = State.DAMAGE
	_update_animation()

	# temporizador de recuperación (stun breve)
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 0.35
	add_child(t)
	t.start()
	t.timeout.connect(Callable(self, "_on_damage_recovery"))

func _on_damage_recovery() -> void:
	if health <= 0:
		_enter_dead()
	else:
		state = State.PATROL

func _enter_dead() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	emit_signal("died")
	_update_animation()

	# desactivar hitbox y colision física
	if hitbox_area:
		hitbox_area.monitoring = false
		hitbox_area.set_deferred("disabled", true)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true

	# programar eliminación tras dead_cleanup_time segundos
	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = dead_cleanup_time
	add_child(cleanup)
	cleanup.start()
	cleanup.timeout.connect(Callable(self, "_on_cleanup_timeout"))

func _on_cleanup_timeout() -> void:
	queue_free()
