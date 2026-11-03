class_name GameAudio
extends Node

var tracks: Array[AudioStreamPlayer] = []
var active: int = 0
var context: String = ""
var ducked: bool = false
var transition: Tween
var voices: Array[AudioStreamPlayer] = []
const AREA_TRACKS := {"R01":"hub","R02":"hub","R03":"canal","R04":"canal","R05":"rail","R06":"rail","R07":"lab","R08":"lab","R09":"foundry","R10":"foundry","R11":"archive","R12":"archive"}
const MUSIC := ["city","combat","boss","hub","canal","rail","lab","foundry","archive","ending"]
const SFX := ["ui","metal","electric","vent","heal","shield","victory","defeat","shot","charge","heavy","whoosh","burn","acid"]
const HEAVY_HIT := 24
const CAST_SKILLS := ["S04","S06","S15"]
const MELEE_SKILLS := ["S01","S02","S07","S16"]
const GUARD_SKILLS := ["S11","S22"]
var played_events: Dictionary = {}

func _exit_tree() -> void:
	if transition != null and transition.is_valid(): transition.kill()
	transition = null
	for player in tracks+voices:
		player.stop()
		player.stream = null

func _ready() -> void:
	add_to_group("game_audio")
	for bus in ["Music","SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	for _index in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = -60
		add_child(player)
		tracks.append(player)
	for _index in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = -12
		add_child(player)
		voices.append(player)

func set_context(id: String) -> void:
	if id == context or not id in MUSIC: return
	context = id
	if transition != null and transition.is_valid(): transition.kill()
	var old := tracks[active]
	active = 1-active
	var next := tracks[active]
	var stream: AudioStreamWAV = load("res://audio/"+id+".wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(round(stream.get_length()*stream.mix_rate))
	next.stream = stream
	next.volume_db = -60
	next.play()
	transition = create_tween().set_parallel(true)
	transition.tween_property(old,"volume_db",-60,0.6)
	transition.tween_property(next,"volume_db",-14.0 if ducked else -8.0,0.6)
	transition.chain().tween_callback(func():
		old.stop()
		next.volume_db = -14 if ducked else -8)

func duck(value: bool) -> void:
	ducked = value
	if not tracks.is_empty():
		tracks[active].volume_db = -14 if value else -8

func play_sfx(id: String) -> void:
	if not id in SFX: return
	var voice := voices[0]
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	voice.stream = load("res://audio/"+id+".wav")
	voice.play()

static func room_track(room_id: String) -> String:
	return AREA_TRACKS.get(room_id, "city")

# Sound for one combat event: element picks the hit, skill/action kind picks the swing.
static func sfx_for(event: Dictionary) -> String:
	var p: Dictionary = event.payload
	if event.type == "heal": return "heal"
	if event.type == "damage":
		if p.get("shielded",false): return "shield"
		match p.get("type","physical"):
			"electric": return "electric"
			"thermal", "Heated": return "burn"
			"chemical": return "acid"
		return "heavy" if int(p.get("amount",0)) >= HEAVY_HIT else "metal"
	if event.type == "action":
		var skill: String = p.get("skill_id","")
		match p.kind:
			"vent": return "vent"
			"guard": return "shield"
			"attack", "retreat": return "whoosh"
			"skill":
				if skill in CAST_SKILLS: return "charge"
				if skill in GUARD_SKILLS: return "shield"
				if skill == "S09": return "heal"
				if skill in MELEE_SKILLS: return "whoosh"
				return "shot"
	return ""

func combat_events(events: Array) -> void:
	for event in events:
		if played_events.has(event.id): continue
		played_events[event.id] = true
		var id := sfx_for(event)
		if id != "": play_sfx(id)
	if played_events.size() > 2048: played_events.clear()
