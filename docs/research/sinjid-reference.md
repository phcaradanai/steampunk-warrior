# Sinjid reference investigation — 2026-10-27

## Scope and status

Requested reference: https://www.webdesignmuseum.org/flash-games/sinjid-shadow-of-the-warrior-in-2004

Questions: what is the reference, what creates its gameplay loop, and which ideas can support an original steampunk RPG?

SUPERSEDED: This is the initial failed-attempt log. The investigation subsequently recovered 1,909 scripts, obtained successful REA process and runtime evidence, and produced complete static catalogs. Read [the current audit](sinjid-comprehensive-audit.md) for findings, evidence and remaining runtime gaps. Statements below describe the initial attempt only.

## Evidence ledger

| Question | Evidence | Conclusion / limit |
| --- | --- | --- |
| Identity | Museum page, read with web tool | Sinjid: Shadow of the Warrior, 2004; credited InfraRift and Krin. |
| Core intent | Creator comments at https://www.newgrounds.com/portal/view/209736 | Combat-driven RPG with items, skills and progression toward challenging Dark Portal bosses. Published December 24, 2004. |
| Preserved runtime | https://archive.org/details/sinjid_sotw_flash | Archive declares SWF with Ruffle emulation; description mentions four classes. This is archive metadata, not observed gameplay. |
| Arena / turn-based loop | https://jayisgames.com/review/sinjid-shadow-of-the-warrior.php | Review describes arena RPG and turn-based gateway battles. Secondary source; not runtime verification. |
| How the original is implemented | REA capture_browser_scenario | Unresolved: browser startup exceeded 20000 ms; cleanup_incomplete with browser_profile retained. No successful Evidence ID returned. |

## REA operations and recovery

Selected target was the exact museum URL. Selected browser was `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`, launch mode, temporary owned profile, one wait-for-body action. Capture requested console, page errors and network response bodies. The initial invalid input requests did not execute; corrected request reached provider startup and failed.

The provider reported startup timeout and incomplete profile cleanup, including a 30000 ms analysis timeout. Do not repeat the original capture until its retained cleanup owner releases resources. The exposed tool catalog does not offer a browser cleanup operation. An elevated read-only process inspection showed the REA server and no matching browser with remote debugging arguments; this does NOT prove the retained profile was released.

Installed REA 6.8.0 doctor: Codex registration aligned, Node available. Missing native decompilers are informational and do not explain this browser startup failure. No client settings changed; no engine installation attempted. REA server reconnection/restart is the next recovery step for the retained browser owner before another capture. A later corrected capture may require a higher command_timeout_ms and adequate outer tool deadline, as the provider advised.

## Adaptation decisions (our proposal)

Retain the compact loop: safe hub → prepare character → discrete fight → rewards → return to NPCs and unlock progression. Use original characters, dialogue, art and data.

Replace ninja fantasy with a steam-powered industrial city, steam pressure instead of generic mana, mutants plus human military enemies, evidence-driven story progression and a final reactor decision. These are new design decisions, not facts extracted from Sinjid.

## Outstanding checks

- Observe actual hub movement, combat selection, turn order and victory/death handling through a working preserved runtime.
- Determine whether deeper SWF inspection is needed; no claim that JavaScript wrapper inspection recovers ActionScript gameplay.
- Validate new-game balance and usability independently; fidelity to original numeric balance is not an acceptance condition.
