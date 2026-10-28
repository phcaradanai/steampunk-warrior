extends SceneTree
func _initialize() -> void:
 for name in ["EditorExportPlatformMacOS","EditorExportPlatformWindows"]:
  var platform = ClassDB.instantiate(name)
  var preset = platform.create_preset()
  print(name," properties ",preset.get_property_list())
 quit()
