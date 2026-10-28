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
	return true
