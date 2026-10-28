"""Verify retained analysis coverage and produce a content-addressed manifest."""
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RESEARCH = ROOT / "docs/research"
REFERENCE = ROOT / "reference/sinjid"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    original = REFERENCE / "original.swf"
    digest = "e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008"
    assert sha(original) == digest, "Wrong preserved SWF"
    as_root, pc_root = REFERENCE / "decompiled/scripts", REFERENCE / "pcode/scripts"
    scripts = sorted(as_root.rglob("*.as"))
    pcode = sorted(pc_root.rglob("*.pcode"))
    ids = lambda files, root: {str(p.relative_to(root).with_suffix("")) for p in files}
    assert len(scripts) == len(pcode) == 1909
    assert ids(scripts, as_root) == ids(pcode, pc_root), "Missing script exports"
    assert not any("DECOMPILATION ERROR" in p.read_text() for p in scripts)

    world = json.loads((RESEARCH / "sinjid-world-inventory.json").read_text())
    skills = json.loads((RESEARCH / "sinjid-skills-static.json").read_text())["skills"]
    items = json.loads((RESEARCH / "sinjid-items-static.json").read_text())["items"]
    assert world["swf_sha256"] == digest
    assert len(world["rooms"]) == 11
    graph = {r["id"]: [e["to"] for e in r["exits"]] for r in world["rooms"]}
    visited, pending = set(), ["Arena0"]
    while pending:
        room = pending.pop()
        if room not in visited:
            visited.add(room)
            pending.extend(graph[room])
    assert visited == set(graph), "Unaccounted hub room"
    counts = Counter()
    for e in world["encounters"]:
        for prefix in ("HUMAN", "MONSTER", "DARK", "TRAIN", "WASP"):
            if e["id"].startswith(prefix):
                counts[prefix] += 1
    assert dict(counts) == {"HUMAN": 20, "MONSTER": 10, "DARK": 5, "TRAIN": 3, "WASP": 2}
    assert len(skills) == 19 and {s["index"] for s in skills} == set(range(19))
    assert all(s["rank_cap"] == 10 for s in skills)
    assert len(items) == 63
    inputs = [original, *scripts, *pcode, *sorted((REFERENCE / "decompiled/texts").glob("*"))]
    manifest = {
        "swf_sha256": digest,
        "authority": "Static export verification; not exhaustive runtime playthrough",
        "checks": {"scripts": len(scripts), "pcode": len(pcode), "rooms": len(graph),
                   "encounter_definitions": dict(counts), "skills": len(skills), "items": len(items)},
        "files": [{"path": str(p.relative_to(ROOT)), "bytes": p.stat().st_size, "sha256": sha(p)} for p in inputs],
    }
    output = RESEARCH / "reference-manifest.json"
    output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"status": "passed", "checks": manifest["checks"], "manifest_sha256": sha(output)}))


if __name__ == "__main__":
    main()
