extends RefCounted

func run(t) -> bool:
	for id in ["city","combat","boss"]:
		t.check(FileAccess.file_exists("res://audio/"+id+".wav"),"original music exists: "+id)
	for id in ["ui","metal","electric","vent","heal","shield","victory","defeat"]:
		t.check(FileAccess.file_exists("res://audio/"+id+".wav"),"original effect exists: "+id)
	t.check(FileAccess.file_exists("res://audio/game_audio.gd"),"music must route through actual game audio service")
	return true
