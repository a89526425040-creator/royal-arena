extends Control

const CELL_COUNT := 15
const START_GOLD := 100
const SUMMON_COST := 10

var units: Array[int] = []
var gold := START_GOLD
var wave := 1
var enemy_hp := 0
var enemies_alive := 0
var kills := 0
var game_running := true
var cell_buttons: Array[Button] = []
var gold_label: Label
var wave_label: Label
var enemy_label: Label
var status_label: Label
var summon_button: Button
var combat_timer: Timer
var spawn_timer: Timer

func _ready() -> void:
	for i in range(CELL_COUNT):
		units.append(0)
	_build_interface()
	_start_wave()

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.055, 0.09, 1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "ROYAL ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ОБЪЕДИНЯЙ ЮНИТОВ • ЗАЩИЩАЙ ВОРОТА"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.78, 0.9))
	layout.add_child(subtitle)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	layout.add_child(stats)
	gold_label = _make_stat("Золото: %d" % gold)
	wave_label = _make_stat("Волна: %d" % wave)
	enemy_label = _make_stat("Враги: 0")
	stats.add_child(gold_label)
	stats.add_child(wave_label)
	stats.add_child(enemy_label)

	var enemy_panel := PanelContainer.new()
	enemy_panel.custom_minimum_size = Vector2(0, 112)
	var enemy_box := VBoxContainer.new()
	enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_panel.add_child(enemy_box)
	var enemy_title := Label.new()
	enemy_title.text = "ПОЛЕ БОЯ"
	enemy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_title.add_theme_font_size_override("font_size", 20)
	enemy_box.add_child(enemy_title)
	status_label = Label.new()
	status_label.text = "Монстры приближаются..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 17)
	enemy_box.add_child(status_label)
	layout.add_child(enemy_panel)

	var board_title := Label.new()
	board_title.text = "ТВОИ ЮНИТЫ — НАЖМИ НА КЛЕТКУ"
	board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_title.add_theme_font_size_override("font_size", 17)
	layout.add_child(board_title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(grid)

	for i in range(CELL_COUNT):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(0, 92)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.add_theme_font_size_override("font_size", 19)
		cell.text = "＋\nПусто"
		cell.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(cell)
		cell_buttons.append(cell)

	var hint := Label.new()
	hint.text = "Объединяй двух одинаковых юнитов одного ранга."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
	layout.add_child(hint)

	summon_button = Button.new()
	summon_button.text = "ПРИЗВАТЬ ЮНИТА  •  %d ЗОЛОТА" % SUMMON_COST
	summon_button.custom_minimum_size = Vector2(0, 64)
	summon_button.add_theme_font_size_override("font_size", 20)
	summon_button.pressed.connect(_summon_unit)
	layout.add_child(summon_button)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	layout.add_child(bottom)
	var pvp := Button.new()
	pvp.text = "PvP"
	pvp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pvp.pressed.connect(_show_mode_message.bind("PvP"))
	bottom.add_child(pvp)
	var coop := Button.new()
	coop.text = "КООП"
	coop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coop.pressed.connect(_show_mode_message.bind("КООП"))
	bottom.add_child(coop)

	combat_timer = Timer.new()
	combat_timer.wait_time = 1.0
	combat_timer.timeout.connect(_combat_tick)
	add_child(combat_timer)
	combat_timer.start()

	spawn_timer = Timer.new()
	spawn_timer.wait_time = 2.8
	spawn_timer.timeout.connect(_spawn_enemy)
	add_child(spawn_timer)
	spawn_timer.start()
	_refresh_board()

func _make_stat(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	return label

func _refresh_board() -> void:
	for i in range(CELL_COUNT):
		var rank: int = units[i]
		if rank == 0:
			cell_buttons[i].text = "＋\nПусто"
			cell_buttons[i].add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
		else:
			cell_buttons[i].text = _unit_name(rank) + "\nРанг " + str(rank) + "\n⚔ " + str(rank * 2)
			cell_buttons[i].add_theme_color_override("font_color", _rank_color(rank))
	gold_label.text = "Золото: %d" % gold
	wave_label.text = "Волна: %d" % wave
	enemy_label.text = "Враги: %d" % enemies_alive
	summon_button.text = "ПРИЗВАТЬ ЮНИТА  •  %d ЗОЛОТА" % SUMMON_COST
	summon_button.disabled = gold < SUMMON_COST or not game_running

func _unit_name(rank: int) -> String:
	var names := ["", "Лучник", "Рыцарь", "Маг", "Голем", "Дракон", "Титан"]
	return names[mini(rank, names.size() - 1)]

func _rank_color(rank: int) -> Color:
	var colors := [Color.WHITE, Color(0.75, 0.85, 1), Color(0.45, 0.9, 0.65), Color(0.45, 0.75, 1), Color(0.8, 0.55, 1), Color(1, 0.65, 0.3), Color(1, 0.35, 0.35)]
	return colors[mini(rank, colors.size() - 1)]

func _on_cell_pressed(index: int) -> void:
	if not game_running:
		return
	if units[index] == 0:
		status_label.text = "Пустая клетка. Нажми «Призвать юнита»."
		return
	var source_rank: int = units[index]
	for i in range(CELL_COUNT):
		if i != index and units[i] == source_rank:
			units[i] = 0
			units[index] = source_rank + 1
			status_label.text = "Слияние! Получен юнит: %s, ранг %d" % [_unit_name(source_rank + 1), source_rank + 1]
			_refresh_board()
			return
	status_label.text = "Найди второго юнита ранга %d для слияния." % source_rank

func _summon_unit() -> void:
	if not game_running or gold < SUMMON_COST:
		return
	var empty_cells: Array[int] = []
	for i in range(CELL_COUNT):
		if units[i] == 0:
			empty_cells.append(i)
	if empty_cells.is_empty():
		status_label.text = "Поле заполнено! Объедини одинаковых юнитов."
		return
	gold -= SUMMON_COST
	var slot: int = empty_cells[randi() % empty_cells.size()]
	units[slot] = 1
	status_label.text = "Призван новый лучник!"
	_refresh_board()

func _start_wave() -> void:
	enemy_hp = 8 + wave * 5
	enemies_alive = 0
	game_running = true
	status_label.text = "Волна %d: монстры идут к воротам!" % wave
	_refresh_board()

func _spawn_enemy() -> void:
	if not game_running:
		return
	enemies_alive += 1
	enemy_label.text = "Враги: %d" % enemies_alive
	status_label.text = "На поле появился монстр! Прочность: %d" % enemy_hp

func _combat_tick() -> void:
	if not game_running:
		return
	var damage := 0
	for rank in units:
		if rank > 0:
			damage += rank * 2
	if enemies_alive > 0 and damage > 0:
		enemy_hp -= damage
		if enemy_hp <= 0:
			enemies_alive -= 1
			kills += 1
			gold += 8 + wave
			enemy_hp = 8 + wave * 5
			status_label.text = "Монстр побежден! +%d золота" % (8 + wave)
	if kills >= wave * 5:
		wave += 1
		kills = 0
		gold += 20
		status_label.text = "ВОЛНА ПРОЙДЕНА! Бонус +20 золота"
	_refresh_board()

func _show_mode_message(mode: String) -> void:
	status_label.text = mode + ": сетевые матчи подключим следующим этапом."
