extends SceneTree
var files: Array[String] = []
func walk(path: String) -> void:
 for name in DirAccess.get_files_at(path): files.append(path.path_join(name))
 for name in DirAccess.get_directories_at(path): walk(path.path_join(name))
func _initialize() -> void:
 walk("res://")
 var failed := false
 for file in files:
  if file.begins_with("res://tests/") or file.ends_with(".swf") or "/research/" in file or "/builds/" in file:
   printerr("FAIL: excluded file packed: "+file);failed = true
 var expected := {"classes":5,"skills":22,"items":62,"enemies":25,"rooms":12,"encounters":36,"training":4}
 for kind in expected:
  var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/"+kind+".json"))
  if not data is Array or data.size() != expected[kind]:failed = true;printerr("FAIL: packed catalog "+kind)
 for path in ["res://LICENSES/GODOT-LICENSE.txt","res://LICENSES/GODOT-COPYRIGHT.txt","res://art/fonts/OFL.txt","res://ASSET_CREDITS.md"]:
  if not FileAccess.file_exists(path): failed = true;printerr("FAIL: missing license "+path)
 print("Actual pack audit: ",files.size()," files; excluded research/tests/SWF/builds;counts+licenses;failed=",failed)
 quit(1 if failed else 0)
