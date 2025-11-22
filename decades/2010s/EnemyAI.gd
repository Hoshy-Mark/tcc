extends CombatCharacter
class_name EnemyAI

@export var detection_range: float = 12.0
@export var attack_interval: float = 1.8
var attack_cooldown: float = 0.0

# optional: quão longe o inimigo considera "engage"
@export var disengage_distance: float = 14.0

var player: CombatCharacter = null
var battle_manager

func _ready():
	show_healthbar = true
	manual_control = false
	super._ready()
	# tenta grupo "player" primeiro (mais seguro)
	player = get_tree().get_first_node_in_group("player")
	# fallback para um BattleManager que cria o player
	if not player:
		battle_manager = get_tree().get_root().get_node_or_null("Game2010/BattleManager2010")
		if battle_manager:
			player = battle_manager.player_character

	if not player:
		push_warning("EnemyAI: nenhum player encontrado (procure grupo 'player' ou Game2010/BattleManager2010).")

	# opcional: conectar um sinal caso precise (ex.: para debug)
	# connect("died", Callable(self, "_on_enemy_died"))


func _physics_process(delta: float) -> void:
	# deixa o CombatCharacter atualizar movimento/phys e animações primeiro
	super._physics_process(delta)

	if state == State.DEAD:
		return

	# se estiver em um estado ocupado, não processa a IA
	if state in [State.ATTACKING, State.DODGING, State.STAGGERED, State.BLOCKING]:
		return

	# tenta re-fallback no manager caso o player tenha sido instanciado depois
	if not player and not battle_manager:
		battle_manager = get_tree().get_root().get_node_or_null("Game2010/BattleManager2010")
		if battle_manager:
			player = battle_manager.player_character

	if not player or not player.is_alive():
		_stop_moving()
		return

	var dist := global_position.distance_to(player.global_position)

	# fora do alcance de detecção -> para
	if dist > detection_range:
		_stop_moving()
		return

	# IA ativa
	ai_logic(delta)


func ai_logic(delta: float) -> void:
	attack_cooldown = max(0.0, attack_cooldown - delta)
	var dist := global_position.distance_to(player.global_position)

	# perseguir se estiver fora do alcance de ataque
	if dist > attack_range:
		_chase_player()
		return

	# atacar se puder
	if attack_cooldown <= 0.0 and state not in [State.ATTACKING, State.DODGING, State.STAGGERED, State.BLOCKING, State.DEAD]:
		_attack_player()
		return

	# esperando cooldown -> fica olhando e para
	_face_player()
	_stop_moving()


# ------------------------
# MOVIMENTO (nav agent)
# ------------------------
func _chase_player() -> void:
	if nav_agent:
		# força recálculo de caminho
		nav_agent.set_target_position(player.global_position)
	# coloca o estado para que o CombatCharacter permita mover
	state = State.MOVING


func _stop_moving() -> void:
	if nav_agent:
		nav_agent.set_target_position(global_position)
	velocity = Vector3.ZERO
	state = State.IDLE


# ------------------------
# ATAQUE
# ------------------------
func _attack_player() -> void:
	# checa stamina (usa o sistema do CombatCharacter)
	if stamina < light_attack_cost:
		# recua para recuperar stamina, se tiver nav_agent
		if nav_agent:
			var away = (global_position - player.global_position).normalized() * 2.0
			nav_agent.set_target_position(global_position + away)
		return

	_face_player()

	var heavy := randf() < 0.15
	# chama o perform_attack do próprio CombatCharacter (porque esta classe herda CombatCharacter)
	perform_attack(heavy)

	# bloqueia o ataque até o EnemyAI receber attack_finished ou apenas seta cooldown
	# aqui setamos cooldown; se quiser que cooldown só comece após _finish_attack, conecte sinal 'attack_finished' e atualize aí
	attack_cooldown = attack_interval


# ------------------------
# ROTATION / LOOK AT
# ------------------------
func _face_player() -> void:
	if not player:
		return
	var dir := player.global_position - global_position
	dir.y = 0
	if dir.length() <= 0.001:
		return
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 0.18)
