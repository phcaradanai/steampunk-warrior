extends SceneTree

var failures: int = 0
func check(value: bool, label: String) -> void:
 if not value:
  failures += 1
  printerr("FAIL: "+label)

func energy(capture: AudioEffectCapture) -> float:
 var frames := capture.get_buffer(capture.get_frames_available())
 var peak := 0.0
 for frame in frames: peak = maxf(peak,maxf(absf(frame.x),absf(frame.y)))
 return peak

func _initialize() -> void:
 await process_frame
 create_timer(15).timeout.connect(func():printerr("FAIL: audio smoke timed out");quit(1))
 if DisplayServer.get_name() == "headless":
  printerr("FAIL: audio smoke requires native playback driver")
  quit(1)
  return
 var settings := InputSettings.new("user://unused-audio-test.cfg")
 settings.apply_options()
 var capture := AudioEffectCapture.new()
 capture.buffer_length = 2
 AudioServer.add_bus_effect(0,capture)
 var audio := GameAudio.new()
 root.add_child(audio)
 for id in ["city","combat","boss"]:
  capture.clear_buffer()
  audio.set_context(id)
  await create_timer(.85).timeout
  check(audio.tracks[audio.active].playing and energy(capture) > .001,"native music mixer emits PCM: "+id)
 audio.duck(true)
 await create_timer(.1).timeout
 check(audio.tracks[audio.active].volume_db == -14,"dialogue duck lowers active music")
 settings.set_option("music",0.0)
 await create_timer(.15).timeout
 capture.clear_buffer()
 await create_timer(.15).timeout
 check(energy(capture) < .0001,"music mute reaches actual mixed output")
 audio.play_sfx("metal")
 await create_timer(.1).timeout
 check(energy(capture) > .001,"sound effects play through SFX bus while music is muted")
 settings.set_option("sfx",0.0)
 await create_timer(.3).timeout
 capture.clear_buffer()
 audio.play_sfx("electric")
 await create_timer(.2).timeout
 check(energy(capture) < .0001,"SFX mute reaches actual mixed output")
 AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
 settings.restore_defaults()
 audio.queue_free()
 await create_timer(.2).timeout
 print("Native audio smoke: ",failures," failures;3scores,ducking,independent mutes verified by mixed PCM")
 quit(1 if failures > 0 else 0)
