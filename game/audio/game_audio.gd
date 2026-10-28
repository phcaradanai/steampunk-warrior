class_name GameAudio
extends Node

var tracks: Array[AudioStreamPlayer] = []
var active: int = 0
var context: String = ""
var ducked: bool = false
var transition: Tween
var voices: Array[AudioStreamPlayer] = []
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
	if id == context or not id in ["city","combat","boss"]: return
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
	if not id in ["ui","metal","electric","vent","heal","shield","victory","defeat"]: return
	var voice := voices[0]
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	voice.stream = load("res://audio/"+id+".wav")
	voice.play()

func combat_events(events: Array) -> void:
	for event in events:
		if played_events.has(event.id): continue
		played_events[event.id] = true
		if event.type == "damage":
			play_sfx("shield" if event.payload.get("shielded",false) else "electric" if event.payload.get("type","") == "electric" else "metal")
		elif event.type == "heal": play_sfx("heal")
		elif event.type == "action" and event.payload.kind == "vent": play_sfx("vent")
	if played_events.size() > 2048: played_events.clear()
