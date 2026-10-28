"""Bind completed REA captures to their exact preserved SWF and result files."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/research"
VERSIONS = ROOT / "reference/sinjid/probe-versions"
PHASES = {"census": 52, "skills": 26, "quests": 13, "economy": 11,
          "progression": 4, "recovery": 4, "training": 11, "options": 5}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    original = sha(ROOT / "reference/sinjid/original.swf")
    assert original == "e258423f2a5887ff236a67eb6eaf674a8d573a5cdb721c20b79c831da4d9e008"
    rows = []
    for phase, count in PHASES.items():
        result_path = DOCS / f"runtime-{phase}-results.json"
        result = json.loads(result_path.read_text())
        evidence = json.loads((DOCS / f"rea-runtime-{phase}-evidence.json").read_text())
        capture = evidence["normalized_result"]
        assert result["status"] == "passed" and len(result["records"]) == count, phase
        assert capture["exit"]["code"] == 0, phase
        files = {f["path"]: f["sha256"] for f in capture["files_after"]}
        assert files["root_0:."] == result["original_sha256"] == original, phase
        assert files["root_1:."] == result["probe_sha256"], phase
        assert files["root_2:."] == sha(result_path), phase
        assert len(result["changes"]) == 1, phase
        change = result["changes"][0]
        assert change["before"]["frame"] == change["after"]["frame"] == 17
        assert change["before"]["code"] == change["after"]["code"] == 12
        for key, suffix in [("probe_sha256", "swf"), ("instrumentation_sha256", "as"),
                            ("runner_sha256", "mjs"), ("audio_observer_sha256", "js")]:
            if key in result:
                assert sha(VERSIONS / f"{result[key]}.{suffix}") == result[key], (phase, key)
        fs = capture["truncation_details"]["filesystem_after"]
        assert not fs["enumeration_truncated"] and not fs["hash_omissions"], phase
        rows.append({"phase": phase, "records": count, "evidence_id": evidence["evidence_id"],
                     "result_sha256": sha(result_path), "probe_sha256": result["probe_sha256"],
                     "capture_truncated": capture["truncated"],
                     "process_sampling_partial": capture["truncation_details"]["process"]["sampling_partial"],
                     "limitations": result.get("limitations", [])})
    output = {"status": "passed", "original_sha256": original,
              "scope": "Representative controlled runtime flows; records are snapshots, not independent exhaustive tests.",
              "total_records": sum(r["records"] for r in rows), "phases": rows}
    (DOCS / "runtime-evidence-verification.json").write_text(json.dumps(output, indent=2) + "\n")
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
