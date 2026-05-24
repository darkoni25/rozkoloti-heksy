class_name TurnManager
extends Node

signal turn_started(unit: Unit)
signal combat_ended(winner: int)   # winner = Unit.Team value, or -1 for draw

var _units:  Array[Unit] = []
var _order:  Array[int]  = []
var _idx:    int         = 0
var _ended:  bool        = false

func setup(units: Array[Unit]) -> void:
	_units = units
	_order.assign(range(units.size()))
	# Сортуємо за ініціативою — вищий ходить першим; randi_range у Unit розриває нічию
	_order.sort_custom(func(a: int, b: int) -> bool:
		return _units[a].initiative > _units[b].initiative
	)
	_idx   = 0
	_ended = false
	_begin()

func active() -> Unit:
	return _units[_order[_idx]]

func advance() -> void:
	if _ended:
		return
	_idx = (_idx + 1) % _order.size()
	_begin()

func remove_unit(uid: int) -> void:
	var pos := _order.find(uid)
	if pos == -1:
		return
	_order.remove_at(pos)
	if pos <= _idx:
		_idx = max(0, _idx - 1)
	if _idx >= _order.size():
		_idx = 0
	_check_end()

func _check_end() -> void:
	if _ended:
		return
	if _order.is_empty():
		_ended = true
		combat_ended.emit(-1)
		return
	var first_team: int = _units[_order[0]].team
	for uid in _order:
		if _units[uid].team != first_team:
			return   # both teams still alive
	_ended = true
	combat_ended.emit(first_team)

func _begin() -> void:
	if _ended or _order.is_empty():
		return
	var checked := 0
	while not active().is_alive():
		remove_unit(active().id)
		if _ended or _order.is_empty():
			return
		checked += 1
		if checked > _units.size():
			return
	if _ended:
		return
	active().acted = false
	turn_started.emit(active())
