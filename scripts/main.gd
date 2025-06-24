extends Node3D

const ESCALA = 0.05
const RADIO = 1

@export var VELOCIDAD_BASE_INICIAL = 1.2
@export var VELOCIDAD_BASE = VELOCIDAD_BASE_INICIAL
@export var VELOCIDAD_MOVIMIENTO = 0.5
@export var VELOCIDAD_ROTACION = 0.05
@export var DISTANCIA_ENTRE_PATAS = 6 * ESCALA
@export var LONGITUD_PASO = 230 * ESCALA
@export var UMBRAL_DISTANCIA = 200 * ESCALA    
@export var UMBRAL_PATAS_FRONT = 185 * ESCALA
@export var UMBRAL_PATAS_BACK = 100 * ESCALA
@export var ALTURA_PASO = 80 * ESCALA
@export var RANDOM_DISTANCE = 0
@export var MIN_HEIGHT_JUMP = 120 * ESCALA
@export var MAX_HEIGHT_JUMP = 120 * 3 * ESCALA
@export var UMBRAL_DETECCION_SALTO = 400 * ESCALA
@export var MARGEN_SALTO_ADELANTE = 30 * ESCALA
@export var MOVEMENT_TARGET_SPEED = 1.5
@export var DEBUG = false

@export var camara_path: NodePath
var camara: Camera3D

@export var VELOCIDAD_PREPARACION_SALTO = 1.5
@export var VELOCIDAD_EJECUCION_SALTO = 0.4
@export var VELOCIDAD_ATERRIZAJE = 0.7

@export var RADIO_BUSQUEDA_PATA = 200 * ESCALA
@export var UMBRAL_ALTURA_CRITICA = 80 * ESCALA
@export var UMBRAL_ALTURA_SUTIL = 20 * ESCALA
@export var PUNTOS_BUSQUEDA = 64
@export var PESO_DISTANCIA = 0.3
@export var PESO_ALTURA = 0.7
@export var DISTANCIA_MAXIMA_PATA = 300 * ESCALA
@export var DISTANCIA_PARA_CORRER = 1500 * ESCALA
@export var DISTANCIA_PARAR_CORRER = 400 * ESCALA
@export var SALTO_CORRER_MAX = 400 * ESCALA
@export var SALTO_CORRER_MIN = 180 * ESCALA
@export var VELOCIDAD_CORRER = 1  # Multiplicador de velocidad al correr

enum Estado { PASO_1, PASO_2, PASO_3, PASO_4, PASO_5, SALTO_PREP, SALTO, ATERRIZAJE, CORRER_PREP, CORRER_SALTO, CORRER_ATERRIZAJE }

var estado_actual = Estado.PASO_1
var direccion = Vector3(0, 0, 1)
var punto_objetivo = Vector3(0, 0, 0)
var tiempo = 0
var en_ciclo_salto = false
var posicion_obstaculo = Vector3()
var salto_es_bajada = false

var objetivos = {}
var patas = {}
var esferas = {}
var posiciones_iniciales = {}
var progreso_movimiento = {}

class BaseBehavior:
	var context: Node3D
	func _init(ctx: Node3D): context = ctx
	func enter(): pass
	func update(): pass
	func exit(): pass
	func can_transition_to(behavior_name: String) -> bool: return false

class WalkBehavior extends BaseBehavior:
	func _init(ctx: Node3D): super(ctx)
	
	func update():
		var dist_target = context.distancia(context.obtener_centro(), context.punto_objetivo)
		
		if dist_target > context.DISTANCIA_PARA_CORRER:
			return "run"
		
		if not context.en_ciclo_salto and context.es_necesario_saltar():
			return "jump"
		
		if context.debe_avanzar() and not context.validar_siguiente_paso():
			return "walk"
		
		var estado = context.estado_actual
		if context.debe_avanzar() and (estado == Estado.PASO_1 or estado == Estado.PASO_5) and context.distancia(context.patas["frontL"], context.objetivos["frontL"]) < context.UMBRAL_PATAS_FRONT:
			context.cambiar_estado(Estado.PASO_2)
		elif context.distancia(context.patas["backR"], context.objetivos["backR"]) < context.UMBRAL_PATAS_BACK and estado == Estado.PASO_2:
			context.cambiar_estado(Estado.PASO_3)
		elif context.debe_avanzar() and estado == Estado.PASO_3 and context.distancia(context.patas["frontR"], context.objetivos["frontR"]) < context.UMBRAL_PATAS_FRONT:
			context.cambiar_estado(Estado.PASO_4)
		elif context.distancia(context.patas["backL"], context.objetivos["backL"]) < context.UMBRAL_PATAS_BACK and estado == Estado.PASO_4:
			context.cambiar_estado(Estado.PASO_5)
		
		return "walk"
	
	func can_transition_to(behavior_name: String) -> bool:
		return behavior_name in ["jump", "run"]

class JumpBehavior extends BaseBehavior:
	func _init(ctx: Node3D): super(ctx)
	
	func enter():
		context.en_ciclo_salto = true
		context.cambiar_estado(Estado.SALTO_PREP)
	
	func update():
		match context.estado_actual:
			Estado.SALTO_PREP:
				context.salto_es_bajada = context.posicion_obstaculo.y < context.obtener_centro().y
				if context.todas_patas_en_posicion(): 
					context.cambiar_estado(Estado.SALTO)
			Estado.SALTO:
				if context.patas_delanteras_en_objetivo(): 
					context.cambiar_estado(Estado.ATERRIZAJE)
			Estado.ATERRIZAJE:
				if context.patas_traseras_en_objetivo():
					return "walk"
		return "jump"
	
	func exit():
		context.en_ciclo_salto = false
		context.estado_actual = Estado.PASO_1
	
	func can_transition_to(behavior_name: String) -> bool:
		return behavior_name == "walk"

class RunBehavior extends BaseBehavior:
	func _init(ctx: Node3D): super(ctx)
	
	func enter():
		context.cambiar_estado(Estado.CORRER_PREP)
	
	func update():
		var dist_target = context.distancia(context.obtener_centro(), context.punto_objetivo)
		
		# SIEMPRE verificar si debe cambiar a walk, sin importar el estado actual
		if dist_target < context.DISTANCIA_PARAR_CORRER:
			return "walk"
		
		match context.estado_actual:
			Estado.CORRER_PREP:
				if context.todas_patas_en_posicion_correr():
					context.cambiar_estado(Estado.CORRER_SALTO)
			Estado.CORRER_SALTO:
				if context.patas_delanteras_en_obj_correr():
					context.cambiar_estado(Estado.CORRER_ATERRIZAJE)
			Estado.CORRER_ATERRIZAJE:
				if context.patas_traseras_en_obj_correr():
					# Verificar distancia otra vez antes de continuar
					dist_target = context.distancia(context.obtener_centro(), context.punto_objetivo)
					if dist_target < context.DISTANCIA_PARAR_CORRER:
						return "walk"
					else:
						context.cambiar_estado(Estado.CORRER_PREP)
		
		return "run"
	
	func exit():
		# Al salir del modo correr, asegurar que entre en modo caminata normal
		context.estado_actual = Estado.PASO_1
	
	func can_transition_to(behavior_name: String) -> bool:
		return behavior_name == "walk"

class BehaviorHandler:
	var behaviors = {}
	var current_behavior: BaseBehavior
	var current_behavior_name: String = ""
	var context: Node3D
	
	func _init(ctx: Node3D):
		context = ctx
		behaviors["walk"] = WalkBehavior.new(context)
		behaviors["jump"] = JumpBehavior.new(context)
		behaviors["run"] = RunBehavior.new(context)
	
	func start_behavior(behavior_name: String):
		if behavior_name in behaviors:
			current_behavior_name = behavior_name
			current_behavior = behaviors[behavior_name]
			current_behavior.enter()
	
	func update():
		if current_behavior:
			var next_behavior = current_behavior.update()
			if next_behavior != current_behavior_name:
				transition_to(next_behavior)
	
	func transition_to(behavior_name: String):
		if behavior_name in behaviors and current_behavior and current_behavior.can_transition_to(behavior_name):
			current_behavior.exit()
			start_behavior(behavior_name)
	
	func get_current_behavior_name() -> String:
		return current_behavior_name

var behavior_handler: BehaviorHandler

func _ready():
	VELOCIDAD_BASE = VELOCIDAD_BASE_INICIAL
	inicializar()
	if camara_path: camara = get_node(camara_path)
	behavior_handler = BehaviorHandler.new(self)
	behavior_handler.start_behavior("walk")

func _process(delta):
	behavior_handler.update()
	mover_patas(delta)
	actualizar_representacion_visual()
	manejar_movimiento_objetivo()

func inicializar():
	objetivos = {
		"frontL": Vector3(200 * ESCALA + DISTANCIA_ENTRE_PATAS, 0, 300 * ESCALA),
		"frontR": Vector3(200 * ESCALA, 0, 300 * ESCALA),
		"backL": Vector3(200 * ESCALA + DISTANCIA_ENTRE_PATAS, 0, 200 * ESCALA),
		"backR": Vector3(200 * ESCALA, 0, 200 * ESCALA)
	}
	patas = objetivos.duplicate()
	for pata in patas.keys():
		progreso_movimiento[pata] = 1.0
		posiciones_iniciales[pata] = patas[pata]
	crear_representacion_visual()

func crear_representacion_visual():
	if not DEBUG: return
	
	for nombre in patas.keys():
		var esfera = MeshInstance3D.new()
		esfera.name = "pata_" + nombre
		esfera.mesh = SphereMesh.new()
		esfera.scale = Vector3(RADIO, RADIO, RADIO)
		esfera.material_override = crear_material(Color(0, 0, 1))
		add_child(esfera)
		esferas["pata_" + nombre] = esfera
	
	for nombre in objetivos.keys():
		var esfera = MeshInstance3D.new()
		esfera.name = "objetivo_" + nombre
		esfera.mesh = SphereMesh.new()
		esfera.scale = Vector3(RADIO, RADIO, RADIO)
		esfera.material_override = crear_material(Color(0, 1, 0))
		add_child(esfera)
		esferas["objetivo_" + nombre] = esfera

	var objetivo_especial = MeshInstance3D.new()
	objetivo_especial.name = "punto_objetivo"
	objetivo_especial.mesh = SphereMesh.new()
	objetivo_especial.scale = Vector3(RADIO, RADIO, RADIO)
	objetivo_especial.material_override = crear_material(Color(1, 0, 0))
	add_child(objetivo_especial)
	esferas["punto_objetivo"] = objetivo_especial

func crear_material(color):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	return mat

func manejar_movimiento_objetivo():
	var velocidad_objetivo = 0.2 * 2 * MOVEMENT_TARGET_SPEED
	var input_dir = Vector3.ZERO
	
	if camara:
		var orientacion_camara = -camara.global_transform.basis.z
		orientacion_camara.y = 0
		orientacion_camara = orientacion_camara.normalized()
		var derecha_camara = camara.global_transform.basis.x
		derecha_camara.y = 0
		derecha_camara = derecha_camara.normalized()
		
		if Input.is_key_pressed(KEY_W): input_dir += orientacion_camara
		if Input.is_key_pressed(KEY_S): input_dir -= orientacion_camara
		if Input.is_key_pressed(KEY_D): input_dir += derecha_camara
		if Input.is_key_pressed(KEY_A): input_dir -= derecha_camara
	else:
		if Input.is_key_pressed(KEY_W): input_dir.z += 1
		if Input.is_key_pressed(KEY_A): input_dir.x += 1
		if Input.is_key_pressed(KEY_S): input_dir.z -= 1
		if Input.is_key_pressed(KEY_D): input_dir.x -= 1
	
	if input_dir.length() > 0.1:
		punto_objetivo += input_dir.normalized() * velocidad_objetivo
	
	punto_objetivo.y = obtener_centro().y + 4 * ESCALA

func set_target(new_target):
	punto_objetivo = new_target

func validar_siguiente_paso() -> bool:
	var centro = obtener_centro()
	var dir_norm = direccion.normalized()
	
	var pos_frontL = centro + dir_norm * LONGITUD_PASO + Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	var pos_frontR = centro + dir_norm * LONGITUD_PASO + Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	
	var altura_L = obtener_punto_mas_alto(pos_frontL.x, pos_frontL.z, "suelo").y
	var altura_R = obtener_punto_mas_alto(pos_frontR.x, pos_frontR.z, "suelo").y
	
	# Si hay precipicio adelante, buscar camino por el borde
	if altura_L < centro.y - UMBRAL_ALTURA_CRITICA or altura_R < centro.y - UMBRAL_ALTURA_CRITICA:
		var pos_borde = buscar_posicion_borde_seguro(centro + dir_norm * LONGITUD_PASO)
		return pos_borde != Vector3.ZERO
	
	return abs(altura_L - centro.y) <= UMBRAL_ALTURA_CRITICA * 1.5 and abs(altura_R - centro.y) <= UMBRAL_ALTURA_CRITICA * 1.5

func buscar_posicion_borde_seguro(pos_ideal: Vector3) -> Vector3:
	var centro = obtener_centro()
	var dir_objetivo = (punto_objetivo - centro).normalized()
	
	# Buscar en arco de 120° hacia los lados (nunca hacia atrás)
	for i in range(24):
		var factor = (i / 11.0) - 1.0  # -1 a 1
		var angulo_offset = factor * deg_to_rad(60.0)  # 60° a cada lado
		
		var dir_rotado = Vector3(
			dir_objetivo.x * cos(angulo_offset) - dir_objetivo.z * sin(angulo_offset),
			0,
			dir_objetivo.x * sin(angulo_offset) + dir_objetivo.z * cos(angulo_offset)
		)
		
		var pos_candidata = centro + dir_rotado * LONGITUD_PASO
		var altura_candidata = obtener_punto_mas_alto(pos_candidata.x, pos_candidata.z, "suelo").y
		
		if abs(altura_candidata - centro.y) <= UMBRAL_ALTURA_CRITICA:
			return pos_candidata
	
	return Vector3.ZERO

func validar_cohesion_patas(pos_nueva: Vector3, nombre_pata: String) -> Vector3:
	var centro = obtener_centro()
	var distancia_centro = Vector2(pos_nueva.x - centro.x, pos_nueva.z - centro.z).length()
	
	if distancia_centro > DISTANCIA_MAXIMA_PATA:
		var dir_hacia_centro = (centro - pos_nueva).normalized()
		pos_nueva += dir_hacia_centro * (distancia_centro - DISTANCIA_MAXIMA_PATA)
		pos_nueva.y = obtener_punto_mas_alto(pos_nueva.x, pos_nueva.z, "suelo").y
	
	return pos_nueva

func calcular_longitud_salto_correr() -> float:
	var dist_target = distancia(obtener_centro(), punto_objetivo)
	var factor = clamp(dist_target / DISTANCIA_PARA_CORRER, 0.3, 1.0)
	return lerp(SALTO_CORRER_MIN, SALTO_CORRER_MAX, factor)

func cambiar_estado(nuevo_estado):
	estado_actual = nuevo_estado
	var ran_vec = Vector3(randf() * RANDOM_DISTANCE, 0, randf() * RANDOM_DISTANCE)
	var centro = obtener_centro()
	var dir_norm = direccion.normalized()
	
	match nuevo_estado:
		Estado.PASO_1: pass
		
		Estado.PASO_2:
			objetivos["backR"] = validar_cohesion_patas(objetivos["frontR"], "backR")
			posiciones_iniciales["backR"] = patas["backR"]
			progreso_movimiento["backR"] = 0.0
		
		Estado.PASO_3:
			objetivos["frontR"] = validar_cohesion_patas(calcular_siguiente_posicion_delantera(false) + ran_vec, "frontR")
			posiciones_iniciales["frontR"] = patas["frontR"]
			progreso_movimiento["frontR"] = 0.0
		
		Estado.PASO_4:
			objetivos["backL"] = validar_cohesion_patas(objetivos["frontL"], "backL")
			posiciones_iniciales["backL"] = patas["backL"]
			progreso_movimiento["backL"] = 0.0
		
		Estado.PASO_5:
			objetivos["frontL"] = validar_cohesion_patas(calcular_siguiente_posicion_delantera(true) + ran_vec, "frontL")
			posiciones_iniciales["frontL"] = patas["frontL"]
			progreso_movimiento["frontL"] = 0.0
		
		Estado.CORRER_PREP:
			# Preparar para el próximo salto - solo juntar las patas un poco
			var pos_base = centro + dir_norm * (LONGITUD_PASO * 0.3)
			
			objetivos["frontL"] = pos_base + Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.4)
			objetivos["frontR"] = pos_base + Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.4)
			objetivos["backL"] = pos_base + Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.2)
			objetivos["backR"] = pos_base + Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.2)
			
			for pata in patas.keys():
				objetivos[pata].y = obtener_punto_mas_alto(objetivos[pata].x, objetivos[pata].z, "suelo").y
				posiciones_iniciales[pata] = patas[pata]
				progreso_movimiento[pata] = 0.0
		
		Estado.CORRER_SALTO:
			# Solo mover patas delanteras - las traseras se quedan donde están
			var longitud_salto = calcular_longitud_salto_correr()
			var pos_salto = centro + dir_norm * longitud_salto
			
			objetivos["frontL"] = pos_salto + Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.5)
			objetivos["frontR"] = pos_salto + Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.5)
			
			objetivos["frontL"].y = obtener_punto_mas_alto(objetivos["frontL"].x, objetivos["frontL"].z, "suelo").y
			objetivos["frontR"].y = obtener_punto_mas_alto(objetivos["frontR"].x, objetivos["frontR"].z, "suelo").y
			
			# Solo resetear el progreso de las patas delanteras
			for pata in ["frontL", "frontR"]:
				posiciones_iniciales[pata] = patas[pata]
				progreso_movimiento[pata] = 0.0
		
		Estado.CORRER_ATERRIZAJE:
			# Mover patas traseras hacia donde están las delanteras
			objetivos["backL"] = objetivos["frontL"]
			objetivos["backR"] = objetivos["frontR"]
			
			# Solo resetear el progreso de las patas traseras
			for pata in ["backL", "backR"]:
				posiciones_iniciales[pata] = patas[pata]
				progreso_movimiento[pata] = 0.0
			
		Estado.SALTO_PREP:
			var pos_base = centro + dir_norm * (LONGITUD_PASO * 0.5)
			var positions = {
				"frontL": pos_base + Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3),
				"frontR": pos_base + Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3),
				"backL": pos_base + Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3),
				"backR": pos_base + Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3)
			}
			
			for pata in positions.keys():
				positions[pata].y = obtener_punto_mas_alto(positions[pata].x, positions[pata].z, "suelo").y
				objetivos[pata] = positions[pata]
				posiciones_iniciales[pata] = patas[pata]
				progreso_movimiento[pata] = 0.0
		
		Estado.SALTO:
			var es_bajada = posicion_obstaculo.y < obtener_centro().y
			var borde_obstaculo = encontrar_borde_obstaculo()
			
			var pos_base
			if es_bajada:
				# Para bajadas: posicionar a un paso del borde para caer cerca
				pos_base = borde_obstaculo + dir_norm * LONGITUD_PASO
			else:
				# Para subidas: aterrizar justo en el borde del obstáculo
				pos_base = borde_obstaculo
			
			objetivos["frontL"] = pos_base + Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.5)
			objetivos["frontR"] = pos_base + Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.5)
			
			objetivos["frontL"].y = obtener_punto_mas_alto(objetivos["frontL"].x, objetivos["frontL"].z, "suelo").y
			objetivos["frontR"].y = obtener_punto_mas_alto(objetivos["frontR"].x, objetivos["frontR"].z, "suelo").y
			
			for pata in ["frontL", "frontR"]:
				posiciones_iniciales[pata] = patas[pata]
				progreso_movimiento[pata] = 0.0
		
		Estado.ATERRIZAJE:
			objetivos["backL"] = objetivos["frontL"] 
			objetivos["backR"] = objetivos["frontR"]
			for pata in ["backL", "backR"]:
				posiciones_iniciales[pata] = patas[pata]
				progreso_movimiento[pata] = 0.0

func es_necesario_saltar():
	var centro = obtener_centro()
	var dir_norm = direccion.normalized()
	var distancia_al_target = distancia(centro, punto_objetivo)
	
	if distancia_al_target < LONGITUD_PASO * 2: return false
	
	var distancia_necesaria = min(distancia_al_target, UMBRAL_DETECCION_SALTO)
	
	for dist in range(1, 40):
		var distancia_actual = distancia_necesaria * dist / 40.0
		var punto_check = centro + dir_norm * distancia_actual
		punto_check.y = centro.y
		
		var altura_terreno = obtener_punto_mas_alto(punto_check.x, punto_check.z, "suelo").y
		var diferencia_altura = altura_terreno - centro.y
		
		if diferencia_altura > MIN_HEIGHT_JUMP * 0.7 and diferencia_altura < MAX_HEIGHT_JUMP and distancia_actual < distancia_al_target * 0.8:
			posicion_obstaculo = Vector3(punto_check.x, altura_terreno, punto_check.z)
			return true
			
		if diferencia_altura < -MIN_HEIGHT_JUMP * 0.7 and diferencia_altura > -MAX_HEIGHT_JUMP * 2 and distancia_actual < distancia_al_target * 0.8:
			posicion_obstaculo = Vector3(punto_check.x, altura_terreno, punto_check.z)
			return true
	
	return false

func encontrar_borde_obstaculo():
	var centro = obtener_centro()
	var es_bajada = posicion_obstaculo.y < centro.y
	var ultimo_punto_bajo = centro
	var primer_punto_alto = posicion_obstaculo
	
	for _i in range(10):
		var punto_medio = (ultimo_punto_bajo + primer_punto_alto) / 2
		var altura_medio = obtener_punto_mas_alto(punto_medio.x, punto_medio.z, "suelo").y
		var diferencia_altura = altura_medio - centro.y
		
		if es_bajada:
			if diferencia_altura < -MIN_HEIGHT_JUMP * 0.5:
				primer_punto_alto = punto_medio
			else:
				ultimo_punto_bajo = punto_medio
		else:
			if diferencia_altura > MIN_HEIGHT_JUMP * 0.5:
				primer_punto_alto = punto_medio
			else:
				ultimo_punto_bajo = punto_medio
	
	ultimo_punto_bajo.y = obtener_punto_mas_alto(ultimo_punto_bajo.x, ultimo_punto_bajo.z, "suelo").y
	return ultimo_punto_bajo

func todas_patas_en_posicion():
	return progreso_movimiento.values().all(func(p): return p >= 0.9)

func todas_patas_en_posicion_correr():
	return progreso_movimiento.values().all(func(p): return p >= 0.55)


func patas_delanteras_en_objetivo():
	return progreso_movimiento["frontL"] >= 0.9 and progreso_movimiento["frontR"] >= 0.9

func patas_delanteras_en_obj_correr():
	return progreso_movimiento["frontL"] >= 0.65 and progreso_movimiento["frontR"] >= 0.65


func patas_traseras_en_objetivo():
	return progreso_movimiento["backL"] >= 0.9 and progreso_movimiento["backR"] >= 0.9

func patas_traseras_en_obj_correr():
	return progreso_movimiento["backL"] >= 0.57 and progreso_movimiento["backR"] >= 0.57

func obtener_progreso_suave(x):
	return 1 / (1 + exp(-8 * (x - 0.5)))

func mover_patas(delta):
	tiempo += delta * VELOCIDAD_MOVIMIENTO * VELOCIDAD_BASE
	var multiplicador_velocidad = VELOCIDAD_CORRER if behavior_handler.get_current_behavior_name() == "run" else 1.0
	
	for nombre in patas.keys():
		if progreso_movimiento[nombre] < 1.0:
			var velocidad_actual = VELOCIDAD_MOVIMIENTO * VELOCIDAD_BASE * multiplicador_velocidad
			
			match estado_actual:
				Estado.SALTO_PREP: velocidad_actual = VELOCIDAD_PREPARACION_SALTO * VELOCIDAD_BASE
				Estado.SALTO: velocidad_actual = VELOCIDAD_EJECUCION_SALTO * VELOCIDAD_BASE
				Estado.ATERRIZAJE: velocidad_actual = VELOCIDAD_ATERRIZAJE * VELOCIDAD_BASE
				Estado.CORRER_PREP: velocidad_actual = VELOCIDAD_PREPARACION_SALTO * VELOCIDAD_BASE * VELOCIDAD_CORRER
				Estado.CORRER_SALTO: velocidad_actual = VELOCIDAD_EJECUCION_SALTO * VELOCIDAD_BASE * VELOCIDAD_CORRER
				Estado.CORRER_ATERRIZAJE: velocidad_actual = VELOCIDAD_ATERRIZAJE * VELOCIDAD_BASE * VELOCIDAD_CORRER
			
			progreso_movimiento[nombre] += velocidad_actual * delta * 5
			progreso_movimiento[nombre] = min(progreso_movimiento[nombre], 1.0)
			
			var factor_altura = 1.0
			if estado_actual == Estado.SALTO and (nombre == "frontL" or nombre == "frontR"):
				factor_altura = 0.5 if salto_es_bajada else 2.0
			elif estado_actual == Estado.ATERRIZAJE and (nombre == "backL" or nombre == "backR"):
				factor_altura = 0.5 if salto_es_bajada else 1.2
			elif estado_actual == Estado.CORRER_SALTO and (nombre == "frontL" or nombre == "frontR"):
				factor_altura = 1.2  # Salto más bajo para correr
			elif estado_actual == Estado.CORRER_ATERRIZAJE and (nombre == "backL" or nombre == "backR"):
				factor_altura = 0.8  # Aterrizaje más rápido
			
			patas[nombre] = calcular_posicion_interpolada(
				posiciones_iniciales[nombre], 
				objetivos[nombre], 
				obtener_progreso_suave(progreso_movimiento[nombre]), 
				factor_altura
			)
	
	if not en_ciclo_salto:
		var velocidad_rot = VELOCIDAD_ROTACION * VELOCIDAD_BASE * 3.0
		direccion = rotar_hacia(direccion, punto_objetivo, velocidad_rot)

func calcular_posicion_interpolada(pos_inicial, pos_final, progreso, factor_altura = 1.0):
	var interpolacion_xz = pos_inicial.lerp(pos_final, progreso)
	interpolacion_xz.y = calcular_altura_parabola(pos_inicial, pos_final, progreso, factor_altura)
	return interpolacion_xz

func calcular_altura_parabola(pos_inicial, pos_final, progreso, factor_altura = 1.0):
	var y_inicio = pos_inicial.y
	var y_fin = pos_final.y
	var es_bajada = y_fin < y_inicio - ALTURA_PASO
	
	var altura_maxima = max(y_inicio, y_fin) + (ALTURA_PASO * factor_altura * (0.5 if es_bajada else 1.0))
	
	var a = y_inicio + y_fin - 2 * altura_maxima
	var b = -2 * y_inicio + 2 * altura_maxima
	var c = y_inicio
	
	return a * progreso * progreso + b * progreso + c

func actualizar_representacion_visual():
	if not DEBUG: return
	for nombre in patas.keys(): esferas["pata_" + nombre].position = patas[nombre]
	for nombre in objetivos.keys(): esferas["objetivo_" + nombre].position = objetivos[nombre]
	esferas["punto_objetivo"].position = punto_objetivo

func debe_avanzar():
	return distancia(obtener_centro(), punto_objetivo) > UMBRAL_DISTANCIA * 0.5

func distancia(p1, p2):
	return Vector2(p1.x - p2.x, p1.z - p2.z).length()

func obtener_direccion():
	return direccion
	
func obtener_vel_rot():
	return VELOCIDAD_ROTACION * VELOCIDAD_BASE
	
func obtener_target():
	return punto_objetivo

func obtener_centro():
	var suma = Vector3.ZERO
	for pos in patas.values(): suma += pos
	return suma / patas.size()

func rotar_hacia(actual, objetivo, angulo_max):
	var centro = obtener_centro()
	var vector_deseado = (objetivo - centro).normalized()
	var angulo_actual = atan2(actual.z, actual.x)
	var angulo_objetivo = atan2(vector_deseado.z, vector_deseado.x)
	var delta = wrapf(angulo_objetivo - angulo_actual, -PI, PI)
	var nuevo_angulo = angulo_actual + clamp(delta, -angulo_max, angulo_max)
	return Vector3(cos(nuevo_angulo), 0, sin(nuevo_angulo))

func calcular_siguiente_posicion_delantera(izquierda):
	var dir_norm = direccion.normalized()
	var centro = obtener_centro()
	var factor_paso = clamp(VELOCIDAD_BASE / 1.2, 1.0, 1.2)
	
	var pos_ideal = centro + dir_norm * LONGITUD_PASO * factor_paso
	pos_ideal += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS / 2) * (1 if izquierda else -1)
	
	var altura_ideal = obtener_punto_mas_alto(pos_ideal.x, pos_ideal.z, "suelo").y
	pos_ideal.y = altura_ideal
	
	var nombre_pata = "frontL" if izquierda else "frontR"
	var altura_actual = patas[nombre_pata].y
	var diferencia_altura = abs(altura_ideal - altura_actual)
	
	if diferencia_altura <= UMBRAL_ALTURA_SUTIL:
		return pos_ideal
	
	if diferencia_altura >= UMBRAL_ALTURA_CRITICA:
		var mejor_posicion = buscar_mejor_posicion_pata(pos_ideal, altura_actual)
		if mejor_posicion != Vector3.ZERO:
			return mejor_posicion
	
	return pos_ideal

func buscar_mejor_posicion_pata(pos_ideal: Vector3, altura_actual: float) -> Vector3:
	var mejor_posicion = pos_ideal
	var mejor_puntuacion = evaluar_posicion_pata(pos_ideal, pos_ideal, altura_actual)
	
	var centro = obtener_centro()
	var dir_objetivo = (punto_objetivo - centro).normalized()
	var angulo_base = atan2(dir_objetivo.z, dir_objetivo.x)
	var apertura_rad = deg_to_rad(60.0)
	
	for i in range(PUNTOS_BUSQUEDA):
		var factor = (i / float(PUNTOS_BUSQUEDA - 1)) - 0.5
		var angulo = angulo_base + factor * apertura_rad
		var offset_x = cos(angulo) * RADIO_BUSQUEDA_PATA
		var offset_z = sin(angulo) * RADIO_BUSQUEDA_PATA
		
		var pos_candidata = Vector3(pos_ideal.x + offset_x, 0, pos_ideal.z + offset_z)
		pos_candidata.y = obtener_punto_mas_alto(pos_candidata.x, pos_candidata.z, "suelo").y
		
		var puntuacion = evaluar_posicion_pata(pos_candidata, pos_ideal, altura_actual)
		
		if puntuacion > mejor_puntuacion:
			mejor_posicion = pos_candidata
			mejor_puntuacion = puntuacion
	
	return mejor_posicion if mejor_puntuacion > evaluar_posicion_pata(pos_ideal, pos_ideal, altura_actual) + 0.1 else Vector3.ZERO

func evaluar_posicion_pata(pos_candidata: Vector3, pos_ideal: Vector3, altura_actual: float) -> float:
	var distancia_ideal = Vector2(pos_candidata.x - pos_ideal.x, pos_candidata.z - pos_ideal.z).length()
	var factor_distancia = 1.0 - min(distancia_ideal / RADIO_BUSQUEDA_PATA, 1.0)
	
	var diferencia_altura = abs(pos_candidata.y - altura_actual)
	var factor_altura = 1.0 - min(diferencia_altura / UMBRAL_ALTURA_CRITICA, 1.0)
	
	var factor_seguridad = evaluar_seguridad_posicion(pos_candidata, altura_actual)
	var factor_alcance = evaluar_alcance_pata(pos_candidata)
	
	return (factor_distancia * PESO_DISTANCIA + factor_altura * PESO_ALTURA + factor_seguridad * 0.3 + factor_alcance * 0.2)

func evaluar_seguridad_posicion(pos: Vector3, altura_actual: float) -> float:
	var diferencia_altura = pos.y - altura_actual
	
	if diferencia_altura < -UMBRAL_ALTURA_CRITICA * 1.5:
		return 0.0
	elif diferencia_altura < -UMBRAL_ALTURA_CRITICA:
		return 0.3
	elif diferencia_altura > UMBRAL_ALTURA_CRITICA:
		return 0.7
	else:
		return 1.0

func evaluar_alcance_pata(pos: Vector3) -> float:
	var centro = obtener_centro()
	var distancia_centro = Vector2(pos.x - centro.x, pos.z - centro.z).length()
	var alcance_maximo = LONGITUD_PASO * 1.3
	
	if distancia_centro > alcance_maximo:
		return 0.0
	elif distancia_centro > LONGITUD_PASO:
		return 0.5
	else:
		return 1.0

func obtener_patas():
	return patas

func obtener_punto_mas_alto(x, z, grupo_nombre):
	var origen = Vector3(x, obtener_centro().y + 30, z)
	var destino = Vector3(x, -1000, z)
	
	var espacio_estado = get_world_3d().direct_space_state
	var parametros_ray = PhysicsRayQueryParameters3D.new()
	parametros_ray.from = origen
	parametros_ray.to = destino
	
	var resultado = espacio_estado.intersect_ray(parametros_ray)
	
	if resultado and resultado.has("collider"):
		var objeto_colision = resultado["collider"]
		if objeto_colision.is_in_group(grupo_nombre):
			return resultado["position"]
	
	return Vector3(x, 0, z)
