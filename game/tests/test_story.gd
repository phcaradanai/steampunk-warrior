extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://story/quest_service.gd") or not FileAccess.file_exists("res://story/dialogue_service.gd"):
		t.check(false,"Quest and Dialogue services must preserve real choices and rewards")
		return true
	var catalog = load("res://core/content_catalog.gd").new()
	catalog.load_all("res://data")
	var session = load("res://core/game_session.gd").new(catalog.data)
	session.new_game("C05")
	var quests = load("res://story/quest_service.gd").new(catalog.data)
	var dialogue = load("res://story/dialogue_service.gd").new(catalog.data)
	var early: Dictionary = quests.on_event(session.snapshot(),{"type":"interact","payload":{"object_id":"water_valve"}})
	t.check(early.ok and early.state.world_flags.get("objective:water_valve",false),"objective interaction before quest is remembered")
	var accepted: Dictionary = dialogue.choose("D01","accept",early.state)
	t.check(accepted.ok and accepted.state.quest_states.Q01.state == "objectives_complete","accepting after objective does not lose progress")
	var choice: Dictionary = dialogue.choose("D01","help",accepted.state)
	t.check(choice.ok and choice.events.size() == 1 and choice.events[0].type == "quest_reward_request","dialogue requests reward instead of granting outside session transaction")
	session.state = accepted.state
	var result: Dictionary = session.commit_result("dialogue_choice",{"id":"q1choice","node_id":"D01","choice_id":"help"})
	t.check(result.ok and result.state.quest_states.Q01.state == "turned_in" and result.state.player.skill_points == 3,"session commits quest state and point reward together")
	var claimed: Dictionary = session.snapshot()
	result = session.commit_result("dialogue_choice",{"id":"q1again","node_id":"D01","choice_id":"help"})
	t.check(not result.ok and session.snapshot() == claimed,"quest cannot pay again through another dialogue inputID")
	var endings: Array[String] = dialogue.get_ending_options(session.snapshot())
	t.check(endings == ["Shutdown","Seize"],"two endings always remain available without evidence")
	var fixture: Dictionary = session.snapshot()
	fixture.quest_states.Q04.state = "objectives_complete"
	var pending: Dictionary = dialogue.choose("D04","pragmatic",fixture)
	t.check(pending.ok and not pending.state.world_flags.get("harvested_sample",false) and pending.state.quest_states.Q04.pending_choice == "harvest","harvest waits for explicit warning confirmation")
	t.check(dialogue.get_text("D04",pending.state) == catalog.data.story.harvest_warning,"permanent harvest warning takes priority over rescue valve guidance")
	var cancelled: Dictionary = dialogue.choose("D04","cancel",pending.state)
	t.check(cancelled.ok and not cancelled.state.world_flags.get("harvested_sample",false),"cancel preserves Cure choice before commitment")
	var harvest: Dictionary = dialogue.choose("D04","confirm_harvest",pending.state)
	t.check(harvest.ok and harvest.state.world_flags.get("harvested_sample",false) and not harvest.state.world_flags.get("rescued_specimen",false),"confirmed harvest sets one exclusive flag")
	t.check(not "Cure" in dialogue.get_ending_options(harvest.state),"harvest cannot silently grant Cure")
	harvest.state.quest_states.Q04.state = "turned_in"
	t.check("ไม่มีเซลล์มีชีวิต" in dialogue.get_text("D04",harvest.state),"harvest aftermath is visible in the NPC's actual dialogue route")
	var witness: Dictionary = fixture.duplicate(true)
	witness.quest_states.Q08.state = "turned_in"
	witness.world_flags.protected_witness = true
	var protected_text: String = dialogue.get_text("D08",witness)
	witness.world_flags.protected_witness = false
	t.check(dialogue.get_text("D08",witness) != protected_text,"witness custody choice changes displayed aftermath")
	var rescue: Dictionary = dialogue.choose("D04","help",fixture)
	t.check(not rescue.ok,"rescue choice waits for safe pressure valves")
	fixture.world_flags["environment:specimen_intake"] = true
	fixture.world_flags["environment:specimen_exhaust"] = true
	rescue = dialogue.choose("D04","help",fixture)
	rescue.state.quest_states.Q08.state = "turned_in"
	t.check("Cure" in dialogue.get_ending_options(rescue.state),"rescue plus completedQ08 opens Cure")
	for qid in ["Q01","Q03","Q05","Q07","Q08"]:
		for answer in ["help","pragmatic"]:
			session.new_game("C01")
			session.state.quest_states[qid].state = "objectives_complete"
			session.state.player.level = 30
			session.state.player.skill_points = 0
			var node_id: String = "D" + qid.substr(1)
			result = session.commit_result("dialogue_choice",{"id":qid+answer,"node_id":node_id,"choice_id":answer})
			t.check(result.ok and result.state.quest_states[qid].state == "turned_in" and result.state.player.skill_points == 1,"quest point preserved for both moral choices: " + qid + answer)
	_story_content(t,catalog.data,session)
	return true

# Chapter/boss/ending story pieces: presence, Thai-only wording, and persistence of the shown-once flags.
const SKIP_KEYS := ["id","quest_id","speaker","room","rooms","npc_id","object_id","item","bosses","requires","backdrop","figures","post_speaker","entry_room","objective","choices"]

func _strings(value, out: Array, key: String = "") -> void:
	if key in SKIP_KEYS: return
	if value is String: out.append(value)
	elif value is Array:
		for entry in value: _strings(entry,out,key)
	elif value is Dictionary:
		for k in value: _strings(value[k],out,str(k) if not str(k).begins_with("CH") else "")

func _story_content(t, data: Dictionary, session) -> void:
	var story: Dictionary = data.story
	t.check(story.get("intro",[]).size() >= 3 and story.intro.size() <= 5,"intro has three to five pages")
	for page in story.intro:
		t.check(not str(page.get("text","")).is_empty() and not str(page.get("title","")).is_empty(),"intro page has title and text")
	for chapter in story.chapters:
		t.check(not str(chapter.get("opening","")).is_empty() and not str(chapter.get("closing","")).is_empty(),"chapter has opening and closing: " + chapter.id)
		t.check(not data.rooms.filter(func(r): return r.id == chapter.get("entry_room","")).is_empty(),"chapter entry room exists: " + chapter.id)
		for boss in chapter.bosses:
			var lines: Dictionary = story.get("boss_lines",{}).get(boss,{})
			t.check(not str(lines.get("pre_line","")).is_empty() and not str(lines.get("post_line","")).is_empty(),"boss has pre and post line: " + boss)
			t.check(story.boss_intros.has(boss),"boss intro still present: " + boss)
	for ending in story.endings:
		t.check(ending.get("pages",[]).size() >= 2 and ending.pages.size() <= 3 and not str(ending.get("epitaph","")).is_empty() and not str(ending.get("hint","")).is_empty(),"ending has pages, epitaph and hint: " + ending.id)
	var service = load("res://story/dialogue_service.gd").new(data)
	for ending in story.endings:
		var pages: Array = service.ending_pages(ending.id,session.snapshot())
		t.check(pages.size() >= 4 and pages[0].text == ending.text,"ending pages start with the ending text: " + ending.id)
	var credits: Dictionary = service.credits_page()
	t.check("สร้างด้วย Godot Engine" in credits.text and service.credits_lines().size() >= 5,"credits summarise the asset credits")
	for npc in story.npcs:
		for chapter_id in npc.get("ambient_by_chapter",{}):
			t.check(not story.chapters.filter(func(c): return c.id == chapter_id).is_empty(),"ambient chapter exists: " + npc.id)
	var strings: Array = []
	_strings(story,strings)
	var shorthand := RegEx.create_from_string("[A-Za-z]+\\d")
	for text in strings:
		if shorthand.search(text) != null:
			t.check(false,"story text has English shorthand: " + text)
	var fixture: Dictionary = session.snapshot()
	t.check(service.current_chapter_id(fixture) == "CH01","chapter starts at one")
	var npc_line: String = service.ambient_line("NPC06",fixture)
	fixture.first_clears["B01"] = true
	fixture.first_clears["B02"] = true
	fixture.first_clears["B03"] = true
	t.check(service.current_chapter_id(fixture) == "CH04" and service.ambient_line("NPC06",fixture) != npc_line,"NPC ambient line changes with the chapter")
	fixture = session.snapshot()
	fixture.room_id = "R03"
	var due: Dictionary = service.opening_due(fixture)
	t.check(not due.is_empty() and due.pages.size() == 1,"first chapter opening is due in its entry room")
	fixture.world_flags[due.flag] = true
	t.check(service.opening_due(fixture).is_empty(),"chapter opening shows once")
	fixture.world_flags.erase(due.flag)
	fixture.room_id = "R01"
	t.check(service.opening_due(fixture).is_empty() and service.opening_for_pipe("P02",fixture).pages[0].title.begins_with("บทที่ 2"),"pipe line P02 opens chapter two from the hub")
	fixture.world_flags[service.opening_for_pipe("P02",fixture).flag] = true
	t.check(service.opening_for_pipe("P02",fixture).is_empty() and service.opening_for_pipe("P09",fixture).is_empty(),"pipe opening shows once and ignores unknown lines")
	fixture.world_flags["story:open:CH01"] = true
	fixture.room_id = "R03"
	t.check(service.opening_due(fixture).is_empty(),"entry-room and pipe openings share one flag")
	fixture.first_clears["B01"] = true
	var story_b01: Dictionary = service.boss_story("B01",fixture)
	t.check(story_b01.pages.size() == 2 and "story:close:CH01" in story_b01.flags,"first boss clear gives aftermath and closing")
	fixture.world_flags["story:post:B01"] = true
	t.check(service.boss_story("B01",fixture).is_empty(),"boss aftermath shows once")
	fixture.first_clears["B05"] = true
	t.check(service.boss_story("B05",fixture).pages.size() == 1,"chapter closes only after its last boss")
	var saves := SaveService.new(data,"user://test-story-" + str(Time.get_ticks_usec()))
	var saved: Dictionary = session.snapshot()
	saved.world_flags["story:open:CH01"] = true
	saved.world_flags["story:post:B01"] = true
	saved.world_flags["story:close:CH01"] = true
	var errors: Array[String] = saves.validate_snapshot(saved)
	t.check(errors.is_empty(),"story flags pass save validation: " + str(errors))
	var wrote: Dictionary = saves.save_slot("autosave",saved)
	t.check(wrote.ok,"story flags save: " + str(wrote.get("reason","")))
	var loaded: Dictionary = saves.load_slot("autosave")
	t.check(loaded.ok and loaded.state.world_flags.get("story:open:CH01",false) and loaded.state.world_flags.get("story:close:CH01",false) and loaded.state.world_flags.get("story:post:B01",false),"chapter-shown flags survive a save round trip")
