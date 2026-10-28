class_name RoomLayout
extends RefCounted

const INTERIORS := {
	"R01":[Rect2(416,208,128,48),Rect2(170,60,96,32),Rect2(760,300,96,48)],
	"R02":[Rect2(240,210,128,48),Rect2(590,256,96,48),Rect2(780,64,96,48)],
	"R03":[Rect2(384,200,96,64),Rect2(650,80,128,32)],
	"R04":[Rect2(448,180,96,96),Rect2(170,340,128,48)],
	"R05":[Rect2(256,200,160,64),Rect2(580,240,96,48)],
	"R06":[Rect2(420,192,48,64),Rect2(600,360,128,48)],
	"R07":[Rect2(408,224,96,48),Rect2(770,64,64,32)],
	"R08":[Rect2(376,192,160,64),Rect2(620,80,96,32)],
	"R09":[Rect2(352,200,64,96),Rect2(576,176,128,48)],
	"R10":[Rect2(416,216,144,64),Rect2(760,80,96,32)],
	"R11":[Rect2(320,200,96,64),Rect2(576,200,96,64),Rect2(780,80,64,32)],
	"R12":[Rect2(432,192,96,96),Rect2(200,64,96,32),Rect2(680,400,96,32)],
}

static func walls(room: String) -> Array[Rect2]:
	var result: Array[Rect2] = [Rect2(0,0,960,16),Rect2(0,464,960,16),Rect2(0,0,16,480),Rect2(944,0,16,480)]
	result.append_array(INTERIORS.get(room,[]))
	return result

static func reachable(obstacles: Array[Rect2], clearance: float) -> Array[Vector2]:
	var visited: Dictionary = {}
	var pending: Array[Vector2i] = [Vector2i(6,14)]
	var result: Array[Vector2] = []
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if visited.has(cell): continue
		visited[cell] = true
		if cell.x < 0 or cell.x >= 60 or cell.y < 0 or cell.y >= 30: continue
		var point := Vector2(cell)*16+Vector2(8,8)
		if obstacles.any(func(rect):return rect.grow(clearance).has_point(point)): continue
		result.append(point)
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]: pending.append(cell+direction)
	return result
