class_name Roster3D
extends RefCounted
# Every NPC, foe and interactive world prop maps to a 3D figure: rig variants for people, procedural kits for the rest.

const LEATHER := "Mat_LeatherTunic"
const HAIR := "Mat_Hair"
const SKIN := "Mat_Skin"
const COAT := "Mat_NavyCoat"
const DARK := "Mat_LeatherDark"
const EYES := "Mat_EyeIris"

# gear = [weapon 0 blade/1 hammer/2 gun, head 0 goggles/1 helmet/2 mask, suit 0 tunic/1 plate/2 coat, shield 0 none/1 small/2 large]
const PEOPLE := {
	"NPC01":{"gear":[1,0,0,0],"pack":true,"colors":{HAIR:"e8e4dc",LEATHER:"6a4a30","suit":"5a6a74"},"build":Vector3(1.08,0.94,1.08),"extras":["beard"],"extra_color":"ece8e0"},
	"NPC02":{"gear":[0,0,2,0],"pack":false,"colors":{HAIR:"2a1a1a",COAT:"3f7a70","suit":"3f7a70"}},
	"NPC03":{"gear":[2,0,2,0],"pack":false,"colors":{HAIR:"c2502a",COAT:"7a3a5a","suit":"7a3a5a"}},
	"NPC04":{"gear":[1,1,2,1],"pack":false,"colors":{HAIR:"3a2a1a",COAT:"26364a","suit":"26364a"},"build":Vector3(1.1,1.0,1.1)},
	"NPC05":{"gear":[2,0,2,0],"pack":false,"colors":{HAIR:"1a1a1a",COAT:"e8e0cc","suit":"e8e0cc"},"extras":["visor"],"extra_color":"7fe8ff"},
	"NPC06":{"gear":[1,2,0,0],"pack":true,"colors":{HAIR:"5a3a1a",LEATHER:"8a3a2a","suit":"8a3a2a"},"build":Vector3(1.15,0.95,1.15)},
	"NPC07":{"gear":[0,0,2,0],"pack":false,"colors":{COAT:"3a3a4a","suit":"3a3a4a"},"extras":["hood"],"extra_color":"3a3a4a"},
	"NPC08":{"gear":[2,0,2,0],"pack":false,"colors":{HAIR:"d8b060",COAT:"5a7a3a","suit":"5a7a3a"}},
	"N10":{"gear":[1,1,1,0],"pack":false,"colors":{"suit":"3a4a6a"}},
	"N11":{"gear":[2,0,2,0],"pack":false,"colors":{COAT:"8a4a2a","suit":"8a4a2a",HAIR:"2a2a2a"}},
	"N12":{"gear":[0,1,1,2],"pack":false,"colors":{"suit":"5a5a6a"},"build":Vector3(1.15,1.0,1.15)},
	"N13":{"gear":[1,2,0,0],"pack":true,"colors":{LEATHER:"8a2a1a","suit":"8a2a1a"}},
	"N14":{"gear":[1,0,0,0],"pack":true,"colors":{LEATHER:"5a4a30","suit":"5a4a30",HAIR:"8a6a40"}},
	"N15":{"gear":[2,2,2,0],"pack":false,"colors":{COAT:"1f4a5a","suit":"1f4a5a"},"extras":["visor"],"extra_color":"7fe8ff"},
	"N16":{"gear":[0,2,2,0],"pack":false,"colors":{COAT:"1e1e24","suit":"1e1e24"},"build":Vector3(0.92,1.02,0.92),"extras":["hood"],"extra_color":"2a2a30"},
	"N17":{"gear":[0,0,2,0],"pack":false,"colors":{COAT:"5a2a5a","suit":"5a2a5a",HAIR:"a03030"}},
	"N18":{"gear":[2,0,2,0],"pack":false,"colors":{COAT:"dcd6c4","suit":"dcd6c4"},"extras":["visor"],"extra_color":"b7f04a"},
	"N19":{"gear":[1,1,1,1],"pack":true,"colors":{"suit":"4a4a4a"},"build":Vector3(1.25,1.02,1.25)},
	# Late-game foes (R09-R12): heavier builds and gear mixes so none reads as an NPC or an early guard.
	"N20":{"gear":[1,1,0,0],"pack":true,"colors":{LEATHER:"2a2a2e","suit":"2a2a2e",HAIR:"1a1a1a",SKIN:"7a6a5a","Mat_Brass":"4a3e34","Mat_Copper":"3a3a3e"},"build":Vector3(0.95,0.9,0.95),"extras":["visor"],"extra_color":"ff8a3a"},
	"N21":{"gear":[1,2,1,2],"pack":true,"colors":{"suit":"7a5a3a",LEATHER:"7a5a3a",SKIN:"8a8a90","Mat_Brass":"6a6a74","Mat_Copper":"3a3a44"},"build":Vector3(1.4,1.1,1.4),"extras":["visor"],"extra_color":"ff4a2a"},
	"N22":{"gear":[0,0,2,1],"pack":false,"colors":{COAT:"d8c898","suit":"d8c898",HAIR:"b8b4ac","Mat_Brass":"d8d0b8","Mat_Copper":"8a7a5a"},"build":Vector3(0.9,1.1,0.9),"extras":["beard","visor"],"extra_color":"ffe08a"},
	"N23":{"gear":[2,1,1,1],"pack":false,"colors":{"suit":"34343c",LEATHER:"34343c","Mat_Brass":"3a3a44","Mat_Copper":"2a2a30"},"build":Vector3(1.12,1.0,1.12),"extras":["visor"],"extra_color":"ff3a3a"},
	"N26":{"gear":[1,1,1,2],"pack":true,"colors":{"suit":"9aa8c0",LEATHER:"6a5a8a","Mat_Brass":"7a5aa8","Mat_Copper":"5a4a8a"},"build":Vector3(1.3,1.08,1.3),"extras":["hood","visor"],"extra_color":"c27bff"},
	"B02":{"gear":[0,1,1,2],"pack":true,"colors":{"suit":"26364a",COAT:"26364a"},"build":Vector3(1.3,1.05,1.3),"extras":["visor"],"extra_color":"ffcf4a"},
	"B04":{"gear":[1,2,1,0],"pack":true,"colors":{"suit":"8a3a1a",LEATHER:"8a3a1a"},"build":Vector3(1.35,1.0,1.35),"extras":["beard"],"extra_color":"ff8a3a"},
	"B05":{"gear":[2,0,2,0],"pack":false,"colors":{COAT:"4a5a7a","suit":"4a5a7a"},"extras":["hood","visor"],"extra_color":"9fb8ff"},
	"B06":{"gear":[2,2,2,0],"pack":false,"colors":{COAT:"5a2a7a","suit":"5a2a7a",HAIR:"dcd0ff",SKIN:"c8b8e8"},"build":Vector3(1.1,1.08,1.1),"extras":["crown","wings"],"extra_color":"c27bff"},
	"dummy":{"dummy":true},
}
const CREATURES := {
	"N01":["rat",{}], "N02":["dog",{}], "N03":["bat",{}], "N04":["centipede",{}], "N05":["beetle",{}],
	"N06":["spider",{}], "N07":["boar",{}], "N08":["heron",{}], "N09":["wolf",{"fur":"5a4a3a"}],
	"N24":["wolf",{"fur":"4a6a3a","glow":"b7f04a"}], "N25":["heron",{"fur":"b48aff","glow":"ffcf4a"}],
	"B01":["croc",{}], "B03":["deer",{}], "root":["sprout",{}],
	"rest":["bed",{}], "shop":["cart",{}], "objective":["crate",{}],
}

static func has(id: String) -> bool:
	return PEOPLE.has(id) or CREATURES.has(id)

static func create(id: String) -> Stage3D:
	if PEOPLE.has(id):
		var person := Hero3D.new()
		person.apply_variant(PEOPLE[id])
		return person
	if CREATURES.has(id):
		return Creature3D.new().build(CREATURES[id][0], CREATURES[id][1])
	return null

# Combat actors without a content definition: the training ward, the root summon.
static func actor_key(actor: Dictionary) -> String:
	if actor.get("role","") == "training": return "dummy"
	return actor.get("definition_id","")
