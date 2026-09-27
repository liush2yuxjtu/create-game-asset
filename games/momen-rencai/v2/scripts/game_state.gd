extends Node
## 设置与存档。自测（--autotest / --storytest）与录屏模式写隔离存档，永不碰玩家存档。

const SAVE := "user://momen2_save.json"
const SAVE_TEST := "user://momen2_save_test.json"

var driver_key := ""
var tutorial_done := false
var has_game := false
var isolated := false   # 录屏/自测：不落盘到玩家存档


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--autotest") or args.has("--storytest") or args.has("--record") or args.has("--movie") or args.has("--storydemo"):
		isolated = true
	load_game()


func save_path() -> String:
	return SAVE_TEST if isolated else SAVE


func save_game() -> void:
	if isolated and OS.get_cmdline_user_args().has("--record"):
		return
	var d := {"v": 2, "key": driver_key, "tutorial_done": tutorial_done, "has_game": has_game,
		"story": Story.to_dict(), "mem": Mem.to_dict()}
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_game() -> void:
	if not FileAccess.file_exists(save_path()):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if typeof(d) != TYPE_DICTIONARY:
		return
	driver_key = str(d.get("key", ""))
	tutorial_done = bool(d.get("tutorial_done", false))
	has_game = bool(d.get("has_game", false))
	if has_game:
		Story.from_dict(d.get("story", {}))
		Mem.from_dict(d.get("mem", {}))


func wipe() -> void:
	tutorial_done = false
	has_game = false
	Story.new_game(99)
	var key := driver_key
	save_game()
	driver_key = key
