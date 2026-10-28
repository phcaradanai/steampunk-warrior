extends SceneTree

func _initialize() -> void:
 await process_frame
 create_timer(35).timeout.connect(func():printerr("FAIL: content capture timed out");quit(1))
 var catalog := ContentCatalog.new()
 catalog.load_all("res://data")
 var directory := "user://test-content-"+str(Time.get_ticks_usec())
 var scene = load("res://main.tscn").instantiate()
 scene.saves = SaveService.new(catalog.data,directory)
 root.add_child(scene)
 await process_frame
 await process_frame
 scene._new_game("C03")
 # Render fixtures only; earned campaigns are independently verified in test_campaign.
 scene.session.state.player = scene.session.progression.gain_xp(scene.session.state.player,1000000).state
 scene.session.state.world_flags.postgame = true
 for encounter in catalog.data.encounters: scene.session.state.first_clears[encounter.id] = true
 for room in catalog.data.rooms:
  scene.session.state.room_id = room.id
  scene._show_world()
  await capture(room.id)
 for encounter in catalog.data.encounters:
  if encounter.boss_id.is_empty(): continue
  scene.session.state.room_id = encounter.room
  scene.session.state.world_flags["objective:original_order"] = true
  scene._show_world()
  scene._start_encounter(encounter.id)
  scene.combat_view.paused = true
  await capture(encounter.boss_id)
  if encounter.boss_id == "B06":
   var events: Array = [{"id":"capture-impact","type":"damage","payload":{"target_id":"hero","amount":25,"type":"electric","shielded":true}}]
   scene.combat_view._render(events)
   await process_frame
   await create_timer(.08).timeout
   await capture("impact")
 scene.queue_free()
 await process_frame
 await process_frame
 for filename in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(filename))
 DirAccess.remove_absolute(directory)
 print("Content captures:12rooms6bosses1impact")
 quit()

func capture(id: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var output := ProjectSettings.globalize_path("res://../docs/development/screenshots/content_"+id+".png")
 if root.get_texture().get_image().save_png(output) != OK:quit(1)
