# REA runtime evidence — verified bindings

Generated from `runtime-evidence-verification.json`; recheck with `python3 docs/research/verify_runtime_evidence.py`.

All eight groups exited0, passed their scoped assertions and retained complete hashes for original SWF, instrumented SWF and result JSON. The126 records are intermediate snapshots, not126 independent tests.

| Group | Records | Evidence | Exact result | Process sampling partial |
| --- | ---: | --- | --- | --- |
| census | 52 | [ev_f0ca607b108af99904d847fd146c49f0445c214a646512ced9abe61ace745216](rea-runtime-census-evidence.json) | [JSON](runtime-census-results.json) | True |
| skills | 26 | [ev_5e5b4204354ebb35655149e64b25d6cf5f9fd27cbcff251c20874217cbcb5f2e](rea-runtime-skills-evidence.json) | [JSON](runtime-skills-results.json) | False |
| quests | 13 | [ev_642deebe9279607a0dc1a55f4142d2dc086dda8ded127667255b92f19db1cbec](rea-runtime-quests-evidence.json) | [JSON](runtime-quests-results.json) | False |
| economy | 11 | [ev_eae7279d498205fff82a117e86bb74ef56d28fb9f550740442eb687a57040365](rea-runtime-economy-evidence.json) | [JSON](runtime-economy-results.json) | True |
| progression | 4 | [ev_9058b2154095f3c2c4438a75e505caa0f782446bb6deb1a52e57fe1526e43308](rea-runtime-progression-evidence.json) | [JSON](runtime-progression-results.json) | False |
| recovery | 4 | [ev_d6d841dfbe48c04cec3667b3c1c1890e7955d090c8427db452d980a7b671647d](rea-runtime-recovery-evidence.json) | [JSON](runtime-recovery-results.json) | True |
| training | 11 | [ev_0f673d2016f83fa4082ff5d6873d305087badf99b50dc6a585f7b9d7ec76d293](rea-runtime-training-evidence.json) | [JSON](runtime-training-results.json) | False |
| options | 5 | [ev_d0a8af16d10d6722580fe4902292cff3d7759a27c6fd704f6040b312d4da128e](rea-runtime-options-evidence.json) | [JSON](runtime-options-results.json) | False |

Census, economy and recovery retain REA’s process-sampling partial flag. File enumeration/hash snapshots and result binding are complete; do not describe the whole captures as untruncated.

Options passed control-state checks only. Audible output remains unverified. See [coverage and limitations](runtime-coverage.md).
