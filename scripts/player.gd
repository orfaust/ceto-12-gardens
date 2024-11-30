extends CharacterBody2D

signal is_ready()
signal health_changed(health:int, amount: bool)
signal died(game_over:bool)
signal level_completed()
signal has_drank_potion()
signal is_done_walking_to()

@onready var game:Node2D = get_node("/root/Game")
@onready var animated_sprite:AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_ahead:RayCast2D = $RayCastAhead
@onready var ray_cast_behind: RayCast2D = $RayCastBehind
@onready var ray_cast_above:RayCast2D = $RayCastAbove
@onready var audio_hurt:AudioStreamPlayer2D = $AudioStreamHurt
@onready var audio_jump:AudioStreamPlayer2D = $AudioStreamJump
@onready var audio_gain_health: AudioStreamPlayer2D = $AudioGainHealth
@onready var animation_player:AnimationPlayer = $AnimationPlayer
@onready var audio_licking: AudioStreamPlayer2D = $AudioLicking

@onready var paw_collision_right: CollisionShape2D = $PawCollisionRight
@onready var paw_collision_left: CollisionShape2D = $PawCollisionLeft


const MAX_HEALTH = 9
const INITIAL_HEALTH = 2
var health = INITIAL_HEALTH
var walk_to = 0

var current_weapon = null

# movement params
@export var acceleration: float = 8
@export var sliding: float = 10
@export var groundFriction: float = 0.5
@export var airFriction: float = 0.95
@export var jumpVelocity: float = 280.0
@export var jumpFactor: float = 0.25
@export var doubleJumpFactor: float = 0.9
@export var walkingMaxSpeed: float = 150
@export var fightingMaxSpeed: float = 75.0
var currentSpeed:float = 0.0
var max_speed: float = walkingMaxSpeed

# player state
var is_alive:bool = true
var is_vulnerable:bool = true
var is_locked:bool = false
var has_double_jumped:bool = false
var is_sleeping:bool = false

func _ready() -> void:
	health_changed.emit.call_deferred(health, 0)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("drink_potion"):
		has_drank_potion.emit()

func _physics_process(delta:float) -> void:
	if is_sleeping or not is_alive:
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction: float = 0

	if is_locked:
		animated_sprite.stop()
	else:
		# Handle inputs
		if Input.is_action_just_pressed("jump"):
			if is_on_floor():
				has_double_jumped = false
				jump()
			elif ray_cast_ahead.is_colliding():
				double_jump()
			else:
				pass

		direction = Input.get_axis("move left", "move right")

	#var real_speed = SPEED
	if not is_on_floor():
		#real_speed = SPEED * 0.8
		currentSpeed *= airFriction

	if direction > 0:
		turn_right()
	elif direction < 0:
		turn_left();

	if direction and not ray_cast_ahead.is_colliding():
		currentSpeed = move_toward(currentSpeed, max_speed, acceleration)

		velocity.x = move_toward(velocity.x, direction * currentSpeed, currentSpeed / sliding)
	else:
		currentSpeed *= groundFriction
		velocity.x = move_toward(velocity.x, 0, max_speed / sliding)
		#velocity.x = move_toward(velocity.x, 0, currentSpeed)

	# Play animations
	if is_on_floor():
		if ray_cast_above.is_colliding():
			animated_sprite.play("crouch")
		else:
			if direction == 0 and walk_to == 0:
				if not paw():
					animated_sprite.play("idle")
			else:
				animated_sprite.play("walk")
	else:
		animated_sprite.play("jump")

	if walk_to:
		position.x = move_toward(position.x, walk_to, 1)

		if position.x == walk_to:
			walk_to = 0
			animated_sprite.stop()
			is_done_walking_to.emit()


	move_and_slide()

func turn_right():
	animated_sprite.flip_h = false
	ray_cast_ahead.scale.x = 1
	ray_cast_behind.scale.x = 1
	ray_cast_above.scale.x = 1

func turn_left():
	animated_sprite.flip_h = true
	ray_cast_ahead.scale.x = -1
	ray_cast_behind.scale.x = -1
	ray_cast_above.scale.x = -1


func calculate_jump_velocity() -> float:
	return - jumpVelocity - jumpFactor * currentSpeed

func jump():
	velocity.y = calculate_jump_velocity()
	#print(velocity.y)
	audio_jump.pitch_scale = 1
	audio_jump.play()
	
func double_jump():
	if has_double_jumped:
		return

	has_double_jumped = true
	velocity.y = calculate_jump_velocity() * doubleJumpFactor
	audio_jump.pitch_scale = 1.5
	audio_jump.play()

func lock(seconds = 0):
	is_locked = true
	animated_sprite.stop()

	if seconds:
		get_tree().create_timer(seconds).timeout.connect(unlock)

func unlock():
	is_locked = false


func gain_health(amount: int):
	if health == MAX_HEALTH: return

	health = min(health + amount, MAX_HEALTH)
	health_changed.emit(health, amount)
	audio_gain_health.play()

func take_damage(damage, source: Node2D):
	if not is_alive: return
	if not is_vulnerable: return

	var reset_level = (source.name == "KillZone")

	print("damaged ", damage, " by ", source.name)
	audio_hurt.play()

	health = max(health - damage, 0)
	health_changed.emit(health, -1)
	
	if health == 0:
		# game over
		lock()
		die(true)
		return

	if reset_level:
		# player fell
		die(false)
	else:
		makeInvulnerable(1)

func die(game_over:bool = false):
	if not is_alive: return

	is_alive = false
	animation_player.play("die")
	died.emit(game_over)

func makeInvulnerable(seconds):
	is_vulnerable = false
	animation_player.play("invulnerable")
	get_tree().create_timer(seconds).timeout.connect(_on_vulnerable_timer_timeout)

func _on_vulnerable_timer_timeout() -> void:
	is_vulnerable = true
	animation_player.stop()

func sleep(sleep_position:Vector2):
	if is_sleeping: return

	is_sleeping = true
	position = sleep_position

	animated_sprite.play("sleep")
	await animated_sprite.animation_finished
	level_completed.emit()


func resume():
	animated_sprite.stop()
	is_sleeping = false

	if not is_alive:
		is_alive = true
		animation_player.stop()

	turn_right()
	show()

func reset():
	position = Vector2(0, 0)
	resume()
	health = INITIAL_HEALTH
	health_changed.emit(INITIAL_HEALTH, 0)
	unlock()


func setup_for_new_level(new_position: Vector2):
	position = new_position
	hide()
	await get_tree().create_timer(1).timeout

	resume()
	is_ready.emit()


func drink(target_x):
	walk_to = target_x

	if walk_to > position.x:
		turn_right()
	else:
		turn_left()

	await is_done_walking_to

	audio_licking.play()	
	#lock other animations
	is_sleeping = true

	animated_sprite.play("drink")
	await animated_sprite.animation_finished

	is_sleeping = false
	unlock()
	has_drank_potion.emit()


func paw() -> bool:
	paw_collision_left.disabled = true
	paw_collision_right.disabled = true

	# can't paw when there's something behind
	if ray_cast_behind.is_colliding():
		return false

	if not Input.is_action_pressed("paw"):
		return false
	
	animated_sprite.play("paw")

	if animated_sprite.flip_h:
		# is turned left
		paw_collision_left.disabled = false
	else:
		# is turned right
		paw_collision_right.disabled = false

	return true
