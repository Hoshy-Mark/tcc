extends RigidBody3D

@export var speed := 60.0
var target: CombatCharacter2000
var caster: CombatCharacter2000 = null

func _ready():
	# Visual (esfera simples, pode trocar por partícula depois)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = SphereMesh.new()
	add_child(mesh_instance)

	# Colisor
	var collider = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.2
	collider.shape = shape
	add_child(collider)

	contact_monitor = true
	max_contacts_reported = 1
	connect("body_entered", _on_body_entered)

func _physics_process(delta):
	if target and is_instance_valid(target):
		var dir = (target.global_position - global_position).normalized()
		linear_velocity = dir * speed
	else:
		queue_free() # Se o alvo sumir, destruir projétil

func _on_body_entered(body):
	if body == target:
		# BUG: aqui estava sendo passado "target" (o próprio alvo) como
		# atacante em apply_damage(20, target). Isso fazia o personagem
		# atingido registrar ameaça (threat) contra si mesmo em vez de
		# contra quem lançou o projétil, quebrando o sistema de aggro
		# para ataques à distância do Mago.
		if body.has_method("apply_damage"):
			body.apply_damage(20, caster)
		if caster and body.has_method("add_threat"):
			body.add_threat(caster, 20)
		queue_free()
