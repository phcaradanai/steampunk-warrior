extends SceneTree

func _initialize() -> void:
 await process_frame
 var config := ConfigFile.new()
 var index := 0
 for entry in [["EditorExportPlatformMacOS","macOS","macOS","builds/macos/SteampunkWarrior.zip"],["EditorExportPlatformWindows","Windows Desktop","Windows Desktop","builds/windows/SteampunkWarrior.exe"]]:
  var platform = ClassDB.instantiate(entry[0])
  var preset = platform.create_preset()
  var section := "preset."+str(index)
  config.set_value(section,"name",entry[1])
  config.set_value(section,"platform",entry[2])
  config.set_value(section,"runnable",true)
  config.set_value(section,"advanced_options",false)
  config.set_value(section,"export_filter","all_resources")
  config.set_value(section,"include_filter","*.json,*.txt,*.md")
  config.set_value(section,"exclude_filter","tests/*,builds/*,art/characters/actors-a.png,art/characters/hero-boiler-seed.png")
  config.set_value(section,"export_path",entry[3])
  config.set_value(section,"script_export_mode",2)
  for property in preset.get_property_list():
   if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
    config.set_value(section+".options",property.name,preset.get(property.name))
  config.set_value(section+".options","application/icon","res://art/icons/gear.svg")
  if index == 0:
   config.set_value(section+".options","application/bundle_identifier","com.vesper.steampunkwarrior")
   config.set_value(section+".options","binary_format/architecture","universal")
   config.set_value(section+".options","codesign/codesign",1)
  else:
   config.set_value(section+".options","application/modify_resources",false)
   config.set_value(section+".options","codesign/enable",false)
  index += 1
 var result := config.save("res://export_presets.cfg")
 print("Native factory presets saved: ",result)
 await process_frame
 quit(1 if result != OK else 0)
