extends Node3D

const ESCALA = 0.05
const RADIO = 1

@export var VELOCIDAD_BASE_INICIAL = 1.2
@export var VELOCIDAD_BASE = VELOCIDAD_BASE_INICIAL
@export var VELOCIDAD_MOVIMIENTO = 0.7
@export var VELOCIDAD_ROTACION = 0.1
@export var DISTANCIA_ENTRE_PATAS = 12 * ESCALA
@export var LONGITUD_PASO = 220 * ESCALA
@export var UMBRAL_DISTANCIA = 200 * ESCALA    
@export var UMBRAL_PATAS_FRONT = 140 * ESCALA
@export var UMBRAL_PATAS_BACK = 110 * ESCALA
@export var ALTURA_PASO = 70 * ESCALA
@export var RANDOM_DISTANCE = 0.0
@export var MIN_HEIGHT_JUMP = 120 * ESCALA
@export var MAX_HEIGHT_JUMP = 120 * 5 * ESCALA
@export var UMBRAL_DETECCION_SALTO = 270 * ESCALA
@export var MARGEN_SALTO_ADELANTE = 50 * ESCALA
@export var MOVEMENT_TARGET_SPEED = 1.5
@export var DEBUG = false

@export var camara_path: NodePath
var camara: Camera3D

@export var VELOCIDAD_PREPARACION_SALTO = 1.8
@export var VELOCIDAD_EJECUCION_SALTO = 0.8
@export var VELOCIDAD_ATERRIZAJE = 1.1

@export var RADIO_BUSQUEDA_PATA = 200 * ESCALA
@export var UMBRAL_ALTURA_CRITICA = 80 * ESCALA
@export var UMBRAL_ALTURA_SUTIL = 20 * ESCALA
@export var PUNTOS_BUSQUEDA = 32
@export var PESO_DISTANCIA = 0.3
@export var PESO_ALTURA = 0.7
@export var DISTANCIA_MAXIMA_PATA = 300 * ESCALA
@export var DISTANCIA_PARA_CORRER = 1000 * ESCALA
@export var DISTANCIA_PARAR_CORRER = 600 * ESCALA
@export var SALTO_CORRER_MAX = 400 * ESCALA
@export var SALTO_CORRER_MIN = 180 * ESCALA
@export var VELOCIDAD_CORRER = 1

# Variables para el sistema de cola felina
@export var LONGITUD_COLA = 40 * ESCALA
@export var ALTURA_BASE_COLA = 30 * ESCALA  # Altura base sobre las patas traseras
@export var AMPLITUD_FLOTACION = 10 * ESCALA  # Qué tanto "flota" arriba y abajo
@export var AMPLITUD_LATERAL = 70 * ESCALA  # Movimiento lateral caprichoso
@export var VELOCIDAD_ONDULACION = 2  # Velocidad del movimiento ondulante
@export var FACTOR_PERSONALIDAD = 3.0  # Multiplicador de "capricho" del gato
@export var SENSIBILIDAD_MOVIMIENTO = 5.0  # Qué tanto reacciona al movimiento del cuerpo

var cola_posicion: Vector3
var cola_tiempo: float = 0.0
var cola_offset_personal: Vector3 = Vector3.ZERO  # Offset aleatorio personal del gato
var cola_intensidad_actual: float = 1.0
var cola_direccion_preferida: float = 0.0  # El gato "prefiere" mover la cola hacia un lado
var ultimo_cambio_preferencia: float = 0.0

# Estados emocionales de la cola
enum EstadoCola { RELAJADA, CURIOSA, ALERTA, JUGUETONA, CONCENTRADA }
var estado_cola_actual = EstadoCola.RELAJADA

# Agregar esto en _ready() después de la inicialización existente
func inicializar_cola():
	# Generar personalidad única para este gato
	cola_direccion_preferida = randf_range(-1.0, 1.0)  # Algunos gatos prefieren un lado
	cola_offset_personal = Vector3(
		randf_range(-0.3, 0.3),
		randf_range(-0.2, 0.4),
		randf_range(-0.3, 0.3)
	)
	
	# Posición inicial de la cola flotando
	var centro_trasero = (patas["backL"] + patas["backR"]) / 2
	cola_posicion = centro_trasero + Vector3(0, ALTURA_BASE_COLA, -LONGITUD_COLA * 0.7)
	
	# Crear representación visual de la cola
	if DEBUG:
		var esfera_cola = MeshInstance3D.new()
		esfera_cola.name = "cola_tip"
		esfera_cola.mesh = SphereMesh.new()
		esfera_cola.scale = Vector3(RADIO * 1.5, RADIO * 1.5, RADIO * 1.5)
		esfera_cola.material_override = crear_material(Color(0.9, 0.6, 0.1))  # Dorado gatuno
		add_child(esfera_cola)
		esferas["cola_tip"] = esfera_cola

# Agregar esto en _process() después de las llamadas existentes
func actualizar_cola(delta):
	cola_tiempo += delta * VELOCIDAD_ONDULACION
	ultimo_cambio_preferencia += delta
	
	# Cambiar ocasionalmente la "preferencia" del gato (cada 3-8 segundos)
	if ultimo_cambio_preferencia > randf_range(3.0, 8.0):
		cola_direccion_preferida = randf_range(-1.0, 1.0)
		ultimo_cambio_preferencia = 0.0
	
	# Determinar estado emocional basado en actividad
	determinar_estado_emocional()
	
	# Calcular posición base de la cola
	var centro_trasero = (patas["backL"] + patas["backR"]) / 2
	
	# Comportamiento específico según lo que está haciendo el gato
	var patron_movimiento = calcular_patron_segun_actividad(delta)
	
	# Aplicar el patrón de movimiento
	cola_posicion = centro_trasero + patron_movimiento
	
	# Agregar "personalidad" del gato individual
	cola_posicion += cola_offset_personal * FACTOR_PERSONALIDAD
	
	# Actualizar visualización
	if DEBUG and "cola_tip" in esferas:
		esferas["cola_tip"].position = cola_posicion

func determinar_estado_emocional():
	match behavior_handler.get_current_behavior_name():
		"walk":
			if debe_avanzar():
				estado_cola_actual = EstadoCola.CURIOSA
			else:
				estado_cola_actual = EstadoCola.RELAJADA
		"run":
			estado_cola_actual = EstadoCola.ALERTA
		"jump":
			if estado_actual == Estado.SALTO_PREP:
				estado_cola_actual = EstadoCola.CONCENTRADA
			else:
				estado_cola_actual = EstadoCola.ALERTA

func calcular_patron_segun_actividad(delta: float) -> Vector3:
	var posicion_base = Vector3()
	
	match estado_cola_actual:
		EstadoCola.RELAJADA:
			posicion_base = patron_cola_relajada()
		EstadoCola.CURIOSA:
			posicion_base = patron_cola_curiosa()
		EstadoCola.ALERTA:
			posicion_base = patron_cola_alerta()
		EstadoCola.CONCENTRADA:
			posicion_base = patron_cola_concentrada()
		EstadoCola.JUGUETONA:
			posicion_base = patron_cola_juguetona()
	
	return posicion_base

func patron_cola_relajada() -> Vector3:
	# Movimiento suave en forma de "S", como gato descansando pero atento
	var vector_lateral = Vector3(direccion.z, 0, -direccion.x).normalized()
	var vector_atras = -direccion.normalized()
	
	var lateral = (sin(cola_tiempo * 0.8) * 0.4 + cola_direccion_preferida * 0.3) * AMPLITUD_LATERAL
	var y = ALTURA_BASE_COLA + sin(cola_tiempo * 0.5) * AMPLITUD_FLOTACION * 0.3
	var atras = LONGITUD_COLA * 0.8 + sin(cola_tiempo * 0.6) * LONGITUD_COLA * 0.1
	
	return vector_lateral * lateral + Vector3(0, y, 0) + vector_atras * atras

func patron_cola_curiosa() -> Vector3:
	# Movimiento más animado, como gato explorando
	# Combina ondulación lateral con movimiento vertical más pronunciado
	var factor_velocidad = min(VELOCIDAD_BASE, 2.0)
	var vector_lateral = Vector3(direccion.z, 0, -direccion.x).normalized()
	var vector_atras = -direccion.normalized()
	
	var lateral = (sin(cola_tiempo * 1.2) + sin(cola_tiempo * 2.1) * 0.3) * 0.6 * AMPLITUD_LATERAL
	# Agregar "capricho" extra cuando está curioso
	lateral += sin(cola_tiempo * 3.2) * 0.2 * FACTOR_PERSONALIDAD * AMPLITUD_LATERAL
	
	var y = ALTURA_BASE_COLA + sin(cola_tiempo * 1.0) * AMPLITUD_FLOTACION * 0.6 * factor_velocidad
	var atras = LONGITUD_COLA * 0.6 + cos(cola_tiempo * 0.8) * LONGITUD_COLA * 0.2
	
	return vector_lateral * lateral + Vector3(0, y, 0) + vector_atras * atras

func patron_cola_alerta() -> Vector3:
	# Movimiento más rígido pero expresivo, cola más erguida
	var factor_intensidad = 1.0
	if behavior_handler.get_current_behavior_name() == "run":
		factor_intensidad = 1.5
	
	var vector_lateral = Vector3(direccion.z, 0, -direccion.x).normalized()
	var vector_atras = -direccion.normalized()
	
	var lateral = (cola_direccion_preferida * 0.5 + sin(cola_tiempo * 2.0) * 0.3) * AMPLITUD_LATERAL
	var y = ALTURA_BASE_COLA * 1.5 + sin(cola_tiempo * 1.5) * AMPLITUD_FLOTACION * 0.4 * factor_intensidad
	var atras = LONGITUD_COLA * 0.5 + sin(cola_tiempo * 1.8) * LONGITUD_COLA * 0.15
	
	return vector_lateral * lateral + Vector3(0, y, 0) + vector_atras * atras

func patron_cola_concentrada() -> Vector3:
	# Movimiento muy controlado, como gato preparándose para saltar
	# La cola se mueve lentamente pero con precision
	var vector_lateral = Vector3(direccion.z, 0, -direccion.x).normalized()
	var vector_atras = -direccion.normalized()
	
	var lateral = (sin(cola_tiempo * 0.4) * 0.7 + cola_direccion_preferida * 0.4) * AMPLITUD_LATERAL
	# Pequeños "temblores" de concentración
	lateral += sin(cola_tiempo * 8.0) * 0.05 * AMPLITUD_LATERAL
	
	var y = ALTURA_BASE_COLA * 1.2 + cos(cola_tiempo * 0.3) * AMPLITUD_FLOTACION * 0.3
	var atras = LONGITUD_COLA * 0.4 + sin(cola_tiempo * 0.5) * LONGITUD_COLA * 0.1
	
	return vector_lateral * lateral + Vector3(0, y, 0) + vector_atras * atras

func patron_cola_juguetona() -> Vector3:
	# Movimiento errático y divertido (se podría activar aleatoriamente)
	var vector_lateral = Vector3(direccion.z, 0, -direccion.x).normalized()
	var vector_atras = -direccion.normalized()
	
	var lateral = sin(cola_tiempo * 2.5) * cos(cola_tiempo * 1.3) * 0.8 * AMPLITUD_LATERAL
	var y = ALTURA_BASE_COLA + abs(sin(cola_tiempo * 1.8)) * AMPLITUD_FLOTACION * 0.8
	var atras = LONGITUD_COLA * 0.7 + sin(cola_tiempo * 2.2) * LONGITUD_COLA * 0.3
	
	return vector_lateral * lateral + Vector3(0, y, 0) + vector_atras * atras

# Función para que otros sistemas puedan "influir" en la cola
func activar_modo_jugueton(duracion: float = 3.0):
	estado_cola_actual = EstadoCola.JUGUETONA
	# Crear un timer para regresar al estado normal
	get_tree().create_timer(duracion).timeout.connect(func(): estado_cola_actual = EstadoCola.RELAJADA)

# Función para cambiar la personalidad del gato
func cambiar_personalidad(factor: float, nueva_preferencia: float = 999.0):
	FACTOR_PERSONALIDAD = clamp(factor, 0.1, 3.0)
	if nueva_preferencia != 999.0:
		cola_direccion_preferida = clamp(nueva_preferencia, -1.0, 1.0)

# Función para obtener info de la cola
func obtener_info_cola() -> Dictionary:
	return {
		"posicion": cola_posicion,
		"estado": EstadoCola.keys()[estado_cola_actual],
		"personalidad": FACTOR_PERSONALIDAD,
		"preferencia_lateral": cola_direccion_preferida
	}

func obtener_posicion_cola() -> Vector3:
	return cola_posicion


enum Estado { PASO_1, PASO_2, PASO_3, PASO_4, PASO_5, SALTO_PREP, SALTO, ATERRIZAJE, CORRER_PREP, CORRER_SALTO, CORRER_ATERRIZAJE }

var estado_actual = Estado.PASO_1
var direccion = Vector3(0, 0, 1)
var punto_objetivo = Vector3(0, 0, 0)
var tiempo = 0
var en_ciclo_salto = false
var posicion_obstaculo = Vector3()
var salto_es_bajada = false
var salto_es_alto = false

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
		
		if dist_target < context.DISTANCIA_PARAR_CORRER:
			return "walk"
		
		match context.estado_actual:
			Estado.CORRER_PREP:
				context.salto_es_alto = (context.posicion_obstaculo.y - context.obtener_centro().y) > 4
				if context.todas_patas_en_posicion_correr():
					context.cambiar_estado(Estado.CORRER_SALTO)
			Estado.CORRER_SALTO:
				context.salto_es_alto = (context.posicion_obstaculo.y - context.obtener_centro().y) > 4
				if context.patas_delanteras_en_obj_correr():
					context.cambiar_estado(Estado.CORRER_ATERRIZAJE)
			Estado.CORRER_ATERRIZAJE:
				context.salto_es_alto = (context.posicion_obstaculo.y - context.obtener_centro().y) > 4
				if context.patas_traseras_en_obj_correr():
					dist_target = context.distancia(context.obtener_centro(), context.punto_objetivo)
					if dist_target < context.DISTANCIA_PARAR_CORRER:
						return "walk"
					else:
						context.cambiar_estado(Estado.CORRER_PREP)
		
		return "run"
	
	func exit():
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
	inicializar_cola()


func _process(delta):
	behavior_handler.update()
	mover_patas(delta)
	actualizar_representacion_visual()
	manejar_movimiento_objetivo()
	actualizar_cola(delta)

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


@export var DISTANCIA_MINIMA_CAMINAR = 270 * ESCALA  # Distancia mínima para mantener caminando
@export var DISTANCIA_MINIMA_CORRER = 100 * ESCALA  # Distancia mínima para mantener corriendo
@export var VELOCIDAD_ACERCAMIENTO = 2  # Velocidad con la que el target se acerca al gato
@export var RADIO_MUERTO_INPUT = 0.05  # Umbral mínimo para detectar input

var input_activo = false
var ultimo_input_time = 0.0
var tiempo_sin_input = 0.0

func manejar_movimiento_objetivo():
	var delta = get_process_delta_time()
	
	# Verificar si Shift está presionado para cambiar entre caminar/correr
	var modo_correr = Input.is_key_pressed(KEY_SHIFT)
	var velocidad_multiplicador = 9.0 if modo_correr else 2.0
	var velocidad_objetivo = 0.2 * 2 * velocidad_multiplicador
	
	# Detectar ESPECÍFICAMENTE las teclas de movimiento WASD
	var input_dir = Vector3.ZERO
	var teclas_movimiento_presionadas = false
	
	if camara:
		var orientacion_camara = -camara.global_transform.basis.z
		orientacion_camara.y = 0
		orientacion_camara = orientacion_camara.normalized()
		var derecha_camara = camara.global_transform.basis.x
		derecha_camara.y = 0
		derecha_camara = derecha_camara.normalized()
		
		if Input.is_key_pressed(KEY_W): 
			input_dir += orientacion_camara
			teclas_movimiento_presionadas = true
		if Input.is_key_pressed(KEY_S): 
			input_dir -= orientacion_camara
			teclas_movimiento_presionadas = true
		if Input.is_key_pressed(KEY_D): 
			input_dir += derecha_camara
			teclas_movimiento_presionadas = true
		if Input.is_key_pressed(KEY_A): 
			input_dir -= derecha_camara
			teclas_movimiento_presionadas = true
	else:
		if Input.is_key_pressed(KEY_W): 
			input_dir.z += 1
			teclas_movimiento_presionadas = true
		if Input.is_key_pressed(KEY_A): 
			input_dir.x += 1
			teclas_movimiento_presionadas = true
		if Input.is_key_pressed(KEY_S): 
			input_dir.z -= 1
			teclas_movimiento_presionadas = true
		if Input.is_key_pressed(KEY_D): 
			input_dir.x -= 1
			teclas_movimiento_presionadas = true
	
	# Solo considerar input válido si hay teclas de movimiento presionadas Y hay dirección
	var hay_input_movimiento = teclas_movimiento_presionadas and input_dir.length() > RADIO_MUERTO_INPUT
	
	if hay_input_movimiento:
		input_activo = true
		ultimo_input_time = 0.0
		tiempo_sin_input = 0.0
		
		# Mover el target según input del jugador
		mover_target_con_input(input_dir, velocidad_objetivo, modo_correr)
	else:
		# Solo acercar si anteriormente había input activo de movimiento
		# (es decir, se soltaron las teclas de movimiento)
		if input_activo:
			ultimo_input_time += delta
			tiempo_sin_input += delta
			input_activo = false
			
			# Acercar gradualmente el target al gato
			acercar_target_al_gato(modo_correr)
		# Si nunca hubo input activo, no hacer nada (mantener posición)
	
	# Mantener altura del target
	punto_objetivo.y = obtener_centro().y + 3

func mover_target_con_input(input_dir: Vector3, velocidad: float, modo_correr: bool):
	# Calcular nueva posición del target
	var nueva_posicion = punto_objetivo + input_dir.normalized() * velocidad
	
	# Determinar distancia mínima según el modo
	var distancia_minima = DISTANCIA_MINIMA_CORRER if modo_correr else DISTANCIA_MINIMA_CAMINAR
	
	# Validar que el target mantenga la distancia mínima
	punto_objetivo = validar_distancia_minima(nueva_posicion, distancia_minima)

func acercar_target_al_gato(modo_correr: bool):
	var centro_gato = obtener_centro()
	var distancia_actual = distancia(punto_objetivo, centro_gato)
	
	# Determinar distancia objetivo según el modo
	var distancia_objetivo
	if modo_correr:
		distancia_objetivo = DISTANCIA_MINIMA_CORRER
	else:
		distancia_objetivo = DISTANCIA_MINIMA_CAMINAR
	
	# Solo acercar si está más lejos de la distancia objetivo
	if distancia_actual > distancia_objetivo:
		# Calcular dirección hacia el gato
		var direccion_hacia_gato = (centro_gato - punto_objetivo).normalized()
		
		# Calcular velocidad de acercamiento (más rápido si está muy lejos)
		var factor_distancia = clamp(distancia_actual / distancia_objetivo, 1.0, 3.0)
		var velocidad_acercamiento = VELOCIDAD_ACERCAMIENTO * factor_distancia
		
		# Mover el target hacia el gato
		var nueva_posicion = punto_objetivo + direccion_hacia_gato * velocidad_acercamiento
		
		# Asegurar que no se acerque demasiado
		punto_objetivo = validar_distancia_minima(nueva_posicion, distancia_objetivo)

func validar_distancia_minima(nueva_posicion: Vector3, distancia_minima: float) -> Vector3:
	var centro_gato = obtener_centro()
	var distancia_nueva = distancia(nueva_posicion, centro_gato)
	
	# Si la nueva posición está muy cerca, mantener en el perímetro mínimo
	if distancia_nueva < distancia_minima:
		var direccion_desde_gato = (nueva_posicion - centro_gato).normalized()
		
		# Si la dirección es inválida (posiciones idénticas), usar dirección actual
		if direccion_desde_gato.length() < 0.1:
			direccion_desde_gato = (punto_objetivo - centro_gato).normalized()
			if direccion_desde_gato.length() < 0.1:
				direccion_desde_gato = Vector3(0, 0, 1)  # Dirección por defecto
		
		nueva_posicion = centro_gato + direccion_desde_gato * distancia_minima
	
	return nueva_posicion

func set_target(new_target):
	punto_objetivo = new_target

func validar_siguiente_paso() -> bool:
	var centro = obtener_centro()
	var dir_norm = direccion.normalized()
	
	var pos_frontL = centro + dir_norm * LONGITUD_PASO + Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	var pos_frontR = centro + dir_norm * LONGITUD_PASO + Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	
	var altura_L = obtener_punto_mas_alto(pos_frontL.x, pos_frontL.z, "suelo").y
	var altura_R = obtener_punto_mas_alto(pos_frontR.x, pos_frontR.z, "suelo").y
	
	if altura_L < centro.y - UMBRAL_ALTURA_CRITICA or altura_R < centro.y - UMBRAL_ALTURA_CRITICA:
		var pos_borde = buscar_posicion_borde_seguro(centro + dir_norm * LONGITUD_PASO)
		return pos_borde != Vector3.ZERO
	
	return abs(altura_L - centro.y) <= UMBRAL_ALTURA_CRITICA * 1.5 and abs(altura_R - centro.y) <= UMBRAL_ALTURA_CRITICA * 1.5

func buscar_posicion_borde_seguro(pos_ideal: Vector3) -> Vector3:
	var centro = obtener_centro()
	var dir_objetivo = (punto_objetivo - centro).normalized()
	
	for i in range(24):
		var factor = (i / 11.0) - 1.0
		var angulo_offset = factor * deg_to_rad(60.0)
		
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
			var longitud_salto = calcular_longitud_salto_correr()
			var pos_salto = centro + dir_norm * longitud_salto
			
			objetivos["frontL"] = pos_salto + Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.5)
			objetivos["frontR"] = pos_salto + Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.5)
			
			objetivos["frontL"].y = obtener_punto_mas_alto(objetivos["frontL"].x, objetivos["frontL"].z, "suelo").y
			objetivos["frontR"].y = obtener_punto_mas_alto(objetivos["frontR"].x, objetivos["frontR"].z, "suelo").y
			
			for pata in ["frontL", "frontR"]:
				posiciones_iniciales[pata] = patas[pata]
				progreso_movimiento[pata] = 0.0
		
		Estado.CORRER_ATERRIZAJE:
			objetivos["backL"] = objetivos["frontL"]
			objetivos["backR"] = objetivos["frontR"]
			
			for pata in ["backL", "backR"]:
				posiciones_iniciales[pata] = patas[pata]
				progreso_movimiento[pata] = 0.0
			
		Estado.SALTO_PREP:
			var pos_frontL = centro + dir_norm * (LONGITUD_PASO * 0.5)
			var pos_frontR = Vector3(pos_frontL)
			var pos_backL = Vector3(pos_frontL)
			var pos_backR = Vector3(pos_backL)
						
			pos_frontL += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3)
			pos_frontR += Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3)
			pos_backL += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3)
			pos_backR += Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3)
			
			for pos in [pos_frontL, pos_frontR, pos_backL, pos_backR]:
				pos.y = obtener_punto_mas_alto(pos.x, pos.z, "suelo").y
			
			objetivos["frontL"] = pos_frontL
			objetivos["frontR"] = pos_frontR
			objetivos["backL"] = pos_backL
			objetivos["backR"] = pos_backR
			
			for pata in patas.keys():
				posiciones_iniciales[pata] = patas[pata]
				progreso_movimiento[pata] = 0.0
		
		Estado.SALTO:
			var es_bajada = posicion_obstaculo.y < obtener_centro().y
			var borde_obstaculo = encontrar_borde_obstaculo()
			
			var pos_base
			if es_bajada:
				pos_base = borde_obstaculo + dir_norm * LONGITUD_PASO
			else:
				pos_base = borde_obstaculo + dir_norm * LONGITUD_PASO * 0.2
			
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
	
	if (debe_avanzar()):
		for dist in range(1, 30):
			var distancia_actual = UMBRAL_DETECCION_SALTO * dist / 30.0
			var punto_check = centro + dir_norm * distancia_actual
			punto_check.y = centro.y
			
			var altura_terreno = obtener_punto_mas_alto(punto_check.x, punto_check.z, "suelo").y
			var diferencia_altura = altura_terreno - centro.y
			
			if diferencia_altura > MIN_HEIGHT_JUMP && diferencia_altura < MAX_HEIGHT_JUMP:
				posicion_obstaculo = Vector3(punto_check.x, altura_terreno, punto_check.z)
				return true
				
			if diferencia_altura < -MIN_HEIGHT_JUMP && diferencia_altura > -MAX_HEIGHT_JUMP * 2 && dist < 10:
				posicion_obstaculo = Vector3(punto_check.x, altura_terreno, punto_check.z)
				return true
	
	return false

func encontrar_borde_obstaculo():
	var centro = obtener_centro()
	var dir_norm = direccion.normalized()
	var es_bajada = false
	
	if posicion_obstaculo == Vector3():
		for dist in range(1, 30):
			var distancia_actual = UMBRAL_DETECCION_SALTO * dist / 30.0
			var punto_check = centro + dir_norm * distancia_actual
			var altura_terreno = obtener_punto_mas_alto(punto_check.x, punto_check.z, "suelo").y
			var diferencia_altura = altura_terreno - centro.y
			
			if diferencia_altura > MIN_HEIGHT_JUMP:
				posicion_obstaculo = Vector3(punto_check.x, altura_terreno, punto_check.z)
				es_bajada = false
				break
			elif diferencia_altura < -MIN_HEIGHT_JUMP:
				posicion_obstaculo = Vector3(punto_check.x, altura_terreno, punto_check.z)
				es_bajada = true
				break
	else:
		es_bajada = posicion_obstaculo.y < centro.y
	
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
	
	var borde = ultimo_punto_bajo
	borde.y = obtener_punto_mas_alto(borde.x, borde.z, "suelo").y
	
	return borde

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
	return x * x * (3.0 - 2.0 * x)

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
				factor_altura = 0.5 if salto_es_bajada else 3.0
			elif estado_actual == Estado.ATERRIZAJE and (nombre == "backL" or nombre == "backR"):
				factor_altura = 0.5 if salto_es_bajada else 1.2
			elif estado_actual == Estado.CORRER_SALTO and (nombre == "frontL" or nombre == "frontR"):
				factor_altura = 3.0 if salto_es_alto else 1.0
			elif estado_actual == Estado.CORRER_ATERRIZAJE and (nombre == "backL" or nombre == "backR"):
				factor_altura = 0.8
			
			patas[nombre] = calcular_posicion_interpolada(
				posiciones_iniciales[nombre], 
				objetivos[nombre], 
				obtener_progreso_suave(progreso_movimiento[nombre]), 
				factor_altura
			)
			
	
	if not en_ciclo_salto:
		var dist = distancia(obtener_centro(), punto_objetivo)
		if dist > UMBRAL_DISTANCIA * 0.3:  # Umbral mínimo para rotar
			var factor_velocidad = 1/(0.2*dist)
			var velocidad_rot = max(VELOCIDAD_ROTACION * VELOCIDAD_BASE * (1.0 + factor_velocidad), VELOCIDAD_ROTACION*VELOCIDAD_BASE*1.3)
			direccion = rotar_hacia(direccion, punto_objetivo, velocidad_rot)

func calcular_posicion_interpolada(pos_inicial, pos_final, progreso, factor_altura = 1.0):
	var interpolacion_xz = pos_inicial.lerp(pos_final, progreso)
	interpolacion_xz.y = calcular_altura_parabola(pos_inicial, pos_final, progreso, factor_altura)
	return interpolacion_xz

func calcular_altura_parabola(pos_inicial, pos_final, progreso, factor_altura = 1.0):
	var y_inicio = pos_inicial.y
	var y_fin = pos_final.y
	var es_bajada = y_fin < y_inicio - ALTURA_PASO
	
	var altura_maxima
	if estado_actual == Estado.SALTO:
		# Para saltos: altura mínima = altura final + margen de seguridad
		var altura_objetivo_salto = max(y_inicio, y_fin) + (ALTURA_PASO * factor_altura * 1.0)
		
		# Si hay obstáculo detectado, asegurar que pase por encima
		if posicion_obstaculo != Vector3.ZERO:
			var altura_obstaculo = posicion_obstaculo.y + (ALTURA_PASO) # Margen extra
			altura_objetivo_salto = max(altura_objetivo_salto, altura_obstaculo)
		
		altura_maxima = altura_objetivo_salto
	elif estado_actual == Estado.CORRER_SALTO:
		# Para saltos: altura mínima = altura final + margen de seguridad
		var altura_objetivo_salto = max(y_inicio, y_fin) + (ALTURA_PASO * factor_altura * 1.0)
		
		altura_maxima = altura_objetivo_salto
	else:
		# Para pasos normales (como antes)
		if es_bajada:
			altura_maxima = y_inicio + (ALTURA_PASO * factor_altura * 0.5)
		else:
			altura_maxima = max(y_inicio, y_fin) + (ALTURA_PASO * factor_altura)
	
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
	var dist = distancia(obtener_centro(), punto_objetivo)
	var umbral_descanso = UMBRAL_DISTANCIA
	return dist > umbral_descanso

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
	var factor_paso = max(min(VELOCIDAD_BASE / 1.2, 1.2), 1)
	
	var pos = centro + dir_norm * LONGITUD_PASO * factor_paso
	
	if izquierda:
		pos += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	else:
		pos += Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	
	var altura_terreno = obtener_punto_mas_alto(pos.x, pos.z, "suelo").y

	pos.y = obtener_punto_mas_alto(pos.x, pos.z, "suelo").y
	return pos

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

func validar_posicion_anatomica(pos_nueva: Vector3, nombre_pata: String) -> Vector3:
	var centro = obtener_centro()
	var pos_validada = pos_nueva
	
	# Determinar lado (izquierdo/derecho) y tipo (delantero/trasero)
	var es_izquierda = nombre_pata.find("L") != -1
	var es_delantera = nombre_pata.find("front") != -1
	
	# Calcular posición mínima y máxima permitida según la anatomía
	var lateral_min = -DISTANCIA_ENTRE_PATAS * 1.5
	var lateral_max = DISTANCIA_ENTRE_PATAS * 1.5
	
	# Vector lateral basado en la dirección actual
	var vector_lateral = Vector3(direccion.z, 0, -direccion.x).normalized()
	var proyeccion_lateral = (pos_nueva - centro).dot(vector_lateral)
	
	# Validar que las patas no se crucen
	if es_izquierda and proyeccion_lateral < -DISTANCIA_ENTRE_PATAS * 0.3:
		# Pata izquierda muy hacia la derecha - corregir
		pos_validada = centro + vector_lateral * (-DISTANCIA_ENTRE_PATAS * 0.3)
		pos_validada += (direccion.normalized() * (pos_nueva - centro).dot(direccion.normalized()))
	elif not es_izquierda and proyeccion_lateral > DISTANCIA_ENTRE_PATAS * 0.3:
		# Pata derecha muy hacia la izquierda - corregir
		pos_validada = centro + vector_lateral * (DISTANCIA_ENTRE_PATAS * 0.3)
		pos_validada += (direccion.normalized() * (pos_nueva - centro).dot(direccion.normalized()))
	
	# Validar distancia máxima del centro
	var dist_centro = Vector2(pos_validada.x - centro.x, pos_validada.z - centro.z).length()
	if dist_centro > DISTANCIA_MAXIMA_PATA:
		var dir_hacia_pata = (pos_validada - centro).normalized()
		pos_validada = centro + dir_hacia_pata * DISTANCIA_MAXIMA_PATA
	
	# Asegurar altura correcta del terreno
	pos_validada.y = obtener_punto_mas_alto(pos_validada.x, pos_validada.z, "suelo").y
	
	return pos_validada
