"""Verify planning artifacts; this does not test an implemented game."""
import csv
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / "docs/design"
SPEC = ROOT / "docs/superpowers/specs/2026-10-27-steampunk-warrior-expanded-design.md"
PLAN = ROOT / "docs/superpowers/plans/2026-10-27-steampunk-warrior.md"


def main():
    data = json.loads((HERE / "steampunk-content-plan.json").read_text())
    expected = {"classes": 5, "skills": 22, "bosses": 6,
                "rooms": 12, "equipment": 62, "training": 4}
    for kind, count in expected.items():
        assert data["counts"][kind] == len(data[kind]) == count, kind
        assert len({x["id"] for x in data[kind]}) == count, kind
    assert Counter(x["kind"] for x in data["skills"]) == {"active": 19, "passive": 3}
    assert Counter(x["slot"] for x in data["equipment"]) == {
        "weapon": 26, "shield": 17, "head": 10, "suit": 9}
    skills = {x["id"]: x for x in data["skills"]}
    resolved = set()
    while len(resolved) < len(skills):
        ready = {k for k, s in skills.items()
                 if set(filter(None, s["parents"].split(","))) <= resolved}
        assert ready - resolved, "Missing/cyclic skill prerequisite"
        resolved |= ready
    assert all(c["starter_skill"] in skills for c in data["classes"])
    rooms = {r["id"]: set(r["exits"].split(",")) for r in data["rooms"]}
    seen = {"R01"}
    while True:
        more = set.union(*(rooms[r] for r in seen)) - seen
        if not more:
            break
        assert more <= rooms.keys(), "Unknown room exit"
        seen |= more
    assert seen == rooms.keys()
    assert all(b["room"] in rooms for b in data["bosses"])
    for item in data["equipment"]:
        kind, ref = item["source"].split(":")
        assert ((kind == "shop" and ref in rooms)
                or (kind == "quest" and ref in {"Q05", "Q08"})
                or (kind == "boss" and ref == "B06")), item["id"]
    rows = list(csv.DictReader((HERE / "steampunk-equipment-plan.csv").open()))
    assert len(rows) == 62
    assert {r["id"] for r in rows} == {i["id"] for i in data["equipment"]}
    assert all(str(item[k]) == row[k] for item, row in zip(data["equipment"], rows)
               for k in row), "CSV and JSON equipment disagree"
    spec, plan = SPEC.read_text(), PLAN.read_text()
    distribution = [int(n) for n in re.findall(r"R\d{2}=(\d+)", spec)]
    assert len(distribution) == 10 and sum(distribution) == data["counts"]["encounters"] == 36
    assert re.findall(r"### Task (\d+):", plan) == [str(i) for i in range(1, 11)]
    for topic in ["Review Focus", "Self-review", "GameSession", "SaveService", "CombatResolver"]:
        assert topic in plan, topic
    artifacts = [SPEC, PLAN, HERE / "steampunk-content-plan.md",
                 HERE / "steampunk-content-plan.json", HERE / "steampunk-equipment-plan.csv"]
    for path in artifacts:
        if path.suffix != ".md":
            continue
        for target in re.findall(r"\]\(([^)]+)\)", path.read_text()):
            if target.startswith(("https:", "http:", "#")):
                continue
            assert (path.parent / target).resolve().exists(), (path.name, target)
    assert not (ROOT / "game/project.godot").exists(), "Product started before design approval"
    result = {"status": "passed", "authority": "Planning consistency only; not product/runtime/balance validation",
              "counts": expected, "tasks": 10, "encounters": 36,
              "checks": ["unique IDs", "skill prerequisites", "room connectivity",
                         "equipment acquisition references", "CSV/JSON parity", "local links",
                         "ten development tasks", "no Godot project created"],
              "files": [{"path": str(p.relative_to(ROOT)),
                         "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in artifacts]}
    (HERE / "plan-validation.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": "passed", "counts": expected, "tasks": 10}))


if __name__ == "__main__":
    main()
