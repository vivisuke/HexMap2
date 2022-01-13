extends Node2D

enum {
	ACT_FW = 0,		# Forward
	ACT_FL,			# Forward Left
	ACT_FR,			# Forward Right
	ACT_BW,			# Backward
	ACT_BL			# Backward Left
	ACT_BR,			# Backward Right
	N_ACT,
}
enum {
	TILE_LOAD = 0,
	TILE_GOAL,
	TILE_WALL,
}
const ALPHA = 0.2
const GAMMA = 0.99
const REWARD_GOAL = 1.0
const START_XY = Vector2(0, 0)
#const GOAL_XY = Vector2(4, 0)
#const GOAL_XY = Vector2(5, 5)
const GOAL_ANGLE = 0
const CELL_WIDTH = 100
const CELL_HEIGHT = 87
const MAP_CENTER = Vector2(50, 58)
const N_HORZ = 5
const N_VERT = 6
#const TILE_LOAD = 0
#const TILE_GOAL = 1
#const TILE_WALL = 2
const ROT_ANGLE = 60
const N_ANGLE = 360 / ROT_ANGLE
const QTABLE_SIZE = N_HORZ * N_VERT * N_ANGLE		# ゴール位置は含まない

var started = false
var nStep = 0
var sumStep = 0
var nRound = 0
var nRoundRest = 0
#var car_pos = START_XY
#var car_angle = 0				# 単位：degrees
var TileMapGPos
var GOAL_XY = Vector2(-1, -1)
var Q = []				# Q値テーブル（位置・方向状態）
var qLabel = []			# Q値表示用ラベル
var rng = RandomNumberGenerator.new()

var QValueLabel = load("res://QValueLabel.tscn")

func get_carMapXY():
	return $TileMap.world_to_map($Car.position - TileMapGPos)
func xyToCenterPos(xy):
	return $TileMap.map_to_world(xy) + TileMapGPos + MAP_CENTER
func xyaToQIX(xy, a : int):		# map x, y and [0, 5] angle
	return (xy.y * N_HORZ + xy.x) * 6 + a
func xyToIX(x, y):
	return y * N_HORZ + x
func printQValue(xy, aix):		# aix: [0, 6)
	var ix = xyaToQIX(xy, aix)
	print(ix)
	print("Q[%d] = " % ix, Q[ix])
func init_Q_table():
	Q.resize(QTABLE_SIZE)
	#for i in range(Q.size()): Q[i] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]
	#for i in range(Q.size()): Q[i] = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, ]
	for i in range(Q.size()): Q[i] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, ]
	var ix = 0
	for y in range(N_VERT):
		for x in range(N_HORZ):
			var pos = xyToCenterPos(Vector2(x, y))
			for deg in range(0, 360, 60):		#
				for act in range(N_ACT):
					var to = get_dstPosPDA(pos, deg, act)	# 移動先位置を返す
					if to.x < 0: Q[ix][act] = -1			# 移動不可の場合
				ix += 1
func _ready():
	rng.randomize()		# 乱数ジェネレータシードランダム化
	TileMapGPos = $TileMap.global_position		# タイルマップ原点位置
	qLabel.resize(N_HORZ*N_VERT)		# ラベル配列サイズ指定
	init_Q_table()		# Q値テーブル初期化
	for y in range(N_VERT):		# 全マップについてループ
		for x in range(N_HORZ):
			if $TileMap.get_cell(x, y) < TILE_WALL:		# (x, y) が床の場合
				var gpos = $TileMap.map_to_world(Vector2(x, y)) + TileMapGPos + Vector2(2, 30)
				var label = QValueLabel.instance()	# ラベルインスタンス生成
				label.rect_position = gpos			# ラベル位置設定
				add_child(label)					# 画面に配置
				qLabel[xyToIX(x, y)] = label		# ラベル配列に登録
			if $TileMap.get_cell(x, y) == TILE_GOAL:	# （x, y) がゴールの場合
				GOAL_XY = Vector2(x, y)		# ゴール位置保存
	$Car.position = xyToCenterPos(START_XY)		# 車スタート位置設定
	printQValue(START_XY, $Car.rotation_degrees/60)
	pass # Replace with function body.
func get_dstPosPDA(pos, deg, act) -> Vector2 :		# 移動不可の場合は (-1, -1) を返す
	#var deg = $Car.rotation_degrees
	if act == ACT_BL:	deg += 60
	elif act == ACT_BR:	deg -= 60
	var rad = deg * PI / 180
	#var rad = $Car.rotation		# 車角度（ラジアン）
	#if act == ACT_BL:	rad += PI/3
	#elif act == ACT_BR:	rad -= PI/3
	var dp = Vector2(cos(rad)*CELL_WIDTH, sin(rad)*CELL_HEIGHT)		# 移動方向
	if act >= ACT_BW:
		dp = -dp
	var to = pos + dp
	var m = $TileMap.world_to_map(to - TileMapGPos)
	to = $TileMap.map_to_world(m) + TileMapGPos + MAP_CENTER
	if $TileMap.get_cellv(m) == TILE_WALL:
		return Vector2(-1, -1)		# 移動不可
	else:
		return to
func get_dstPos(act) -> Vector2 :		# 移動不可の場合は (-1, -1) を返す
	return get_dstPosPDA($Car.position, $Car.rotation_degrees, act)
###
func _input(event):
	if event is InputEventKey:
		var act = -1
		if event.is_action_pressed("ui_left"): act = ACT_FL
		elif event.is_action_pressed("ui_up"): act = ACT_FW
		elif event.is_action_pressed("ui_right"): act = ACT_FR
		elif event.is_action_pressed("ui_down"): act = ACT_BW
		elif Input.is_key_pressed(KEY_COMMA): act = ACT_BL
		elif Input.is_key_pressed(KEY_PERIOD): act = ACT_BR
		elif Input.is_key_pressed(KEY_0):
			$Car.position = xyToCenterPos(Vector2(0, 0))
			$Car.rotation_degrees = 0
		elif Input.is_key_pressed(KEY_R):
			$Car.rotation_degrees += 60
			if $Car.rotation_degrees >= 360: $Car.rotation_degrees = 0
		if act >= 0:
			doAction(act)
		printQValue(get_carMapXY(), $Car.rotation_degrees/60)

func sel_act_maxQ(qix):
	#print(Q[qix][aix])
	var maxQ = -99
	#var maxAct = -1
	var lst = []
	for act in range(N_ACT):
		var dst = get_dstPos(act)
		if dst.x >= 0:
			if Q[qix][act] > maxQ:
				maxQ = Q[qix][act]
				lst = [act]
				#maxAct = act
			elif Q[qix][act] == maxQ:
				lst.push_back(act)
	if lst.empty(): return -1
	if lst.size() == 1:
		return lst[0]
	return lst[rng.randi_range(0, lst.size()-1)]
func sel_act_random():
	#print("sel_act_random():")
	var lst = []
	for act in range(N_ACT):
		var to = get_dstPos(act)
		if to.x >= 0: lst.push_back(act)
	if lst.empty(): return -1
	return lst[rng.randi_range(0, lst.size() - 1)]
func doAction(act):
	var to = get_dstPos(act)
	if to.x >= 0:
		$Car.position = to
		if act == ACT_FL || act == ACT_BR:
			$Car.rotation_degrees -= ROT_ANGLE
			if $Car.rotation_degrees < 0: $Car.rotation_degrees += 360
		elif act == ACT_FR || act == ACT_BL:
			$Car.rotation_degrees += ROT_ANGLE
			if $Car.rotation_degrees >= 360: $Car.rotation_degrees -= 360
		#if get_carMapXY() == GOAL_XY:
		#	started = false
		#car_pos = $Car.position
func is_goaled(xy, angle):
	return xy == GOAL_XY && angle == GOAL_ANGLE
func _process(delta):
	if !started: return
	var deg0 : int = round($Car.rotation_degrees)
	if (deg0 / 60) * 60 != deg0:
		print("???")
	nStep += 1
	$StepLabel.text = "Step: %d" % nStep
	var xy0 = get_carMapXY()		# x: [0, N_HORZ), y:[0, N_VERT)
	var qix0 = xyaToQIX(get_carMapXY(), $Car.rotation_degrees / 60)
	#var aix0 = $Car.rotation_degrees / 60
	#var act = rng.randi_range(ACT_FW, ACT_BW)
	var act = -1
	#if rng.randf_range(0, 1) <= 0.95:
	#if rng.randf_range(0, 1) <= 0.99:
	if true:
		act = sel_act_maxQ(qix0)
		if act < 0:
			 sel_act_maxQ(qix0)
	else:
		act = sel_act_random()
		if act < 0:
			 sel_act_random()
	#var xy = get_carMapXY()
	#print(xy, " ", $Car.rotation_degrees, ", act = ", act)
	if act < 0:
		started = false
	else:
		doAction(act)
		var xy = get_carMapXY()
		var qix = xyaToQIX(xy, $Car.rotation_degrees / 60)
		var reward = 0.0
		var maxQ = 0.0
		if is_goaled(xy, $Car.rotation_degrees):
			#print("goaled.")
			started = false
			reward = REWARD_GOAL
		else:
			maxQ = Q[qix].max()
		Q[qix0][act] += ALPHA * (reward + GAMMA * maxQ - Q[qix0][act])
		var label = qLabel[xyToIX(xy0.x, xy0.y)]
		if Q[qix0][act] > float(label.text):
			label.text = "%.3f" % Q[qix0][act]
	if !started:
		#print("nStep = ", nStep)
		sumStep += nStep
		if nRound % 10 == 0:
			print("avg steps = %.1f" % (sumStep/10.0))
			sumStep = 0
		nRoundRest -= 1
		if nRoundRest != 0:
			doStart()
			#started = true

func doStart():
	started = true
	nStep = 0
	#car_pos = START_XY
	$Car.position = xyToCenterPos(START_XY)
	#car_angle = 0
	$Car.rotation_degrees = 0
	nRound += 1
	$RoundLabel.text = "Round: #%d" % nRound
func _on_StartButton_pressed():
	nRoundRest = 1
	doStart()

func _on_100RoundButton_pressed():
	nRoundRest = 100
	doStart()

func _on_BackLearnButton_pressed():
	var lst = [xyaToQIX(GOAL_XY, GOAL_ANGLE)]
	while !lst.empty():
		var lst2 = []
		for i in range(lst.size()):
			var t : int = lst[i]
			#if t == 47:
			#	print(t)
			var deg = (t % 6) * 60
			t /= 6
			var x = t % N_HORZ
			var y = t / N_HORZ
			var pos = xyToCenterPos(Vector2(x, y))
			var reward = 0.0
			var maxQ = 0.0
			if $TileMap.get_cell(x, y) == TILE_GOAL:
				reward = REWARD_GOAL
			else:
				maxQ = Q[lst[i]].max()
			for act in range(N_ACT):
				var dp = get_dstPosPDA(pos, deg, act)	# 位置
				if dp.x >= 0:
					if act >= ACT_BW: act -= ACT_BW
					else: act += ACT_BW
					#print(act)
					var m0 = $TileMap.world_to_map(dp - TileMapGPos)
					var deg0 = deg
					if act == ACT_FL || act == ACT_BR:
						deg0 += ROT_ANGLE
						if deg0 >= 360: deg0 -= 360
					elif act == ACT_FR || act == ACT_BL:
						deg0 -= ROT_ANGLE
						if deg0 < 0: deg0 += 360
					var qix = xyaToQIX(Vector2(m0.x, m0.y), deg0/60)
					var qv = (reward + GAMMA * maxQ) * 0.99
					#if qix == 36:
					#	print("Q[", qix, "] = ", Q[qix], ", act = ", act)
					#if qix == 47:
					#	print("Q[", qix, "] = ", Q[qix], ", act = ", act)
					if Q[qix].max() == 0.0:
					#if qv > Q[qix].max():
					#if Q[qix][act] < qv:
						Q[qix][act] = qv
						qLabel[xyToIX(m0.x, m0.y)].text = "%.3f" % qv
						lst2.push_back(qix)
		lst = lst2
	pass # Replace with function body.
