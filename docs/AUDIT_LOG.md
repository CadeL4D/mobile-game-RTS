# Ruinward - Current Audit Status

**Target reference:** Rise to Ruins Update 2d build `12230045`  
**Audit date:** 2026-08-13  
**Authority:** This file replaces the earlier over-stated phase report. Catalog presence is not implementation proof, and a passing internal test is not reference-parity proof.

## Verified baseline

- Godot 4.7 opens and compiles the project without script errors.
- The authoritative loop advances at 10 Hz independently from rendering.
- The full headless run executes 43 named test groups and contains 488 assertion call sites.
- The latest strict run loaded 741 content entries and ended with `TEST RESULT: PASS` without parser, compiler, runtime, or engine error markers.
- The content data currently contains 145 `CONFIRMED_OFFICIAL`, 6 `CONFIRMED_RUNTIME`, 190 `WIKI_SUPPORTED`, 148 `VERIFY_RUNTIME`, 13 `MOBILE_ADAPTATION`, and 6 `LEGACY_REMOVED` labels.
- All 478 shipping sprite-ledger records remain `IN_REVIEW`.
- The repository has an unsigned-iOS GitHub Actions workflow, but no successful macOS Actions run or IPA artifact exists yet.

## Corrected in the 2026-08-13 integrity pass

- Restored unsupported evidence promotions to their committed or unverified state without reverting implementation data.
- Added a repeatable evidence-restoration tool for future audit recovery.
- Fixed stack, unique-item, transit, reservation, recipe-output, task-deduplication, Doggo-key, empty-coop, tower-ammunition, tower-energy, spell-lookup, and subsystem-reset defects.
- Fixed live husbandry so housing above 75 percent automatically designates only excess eligible adults.
- Removed eggs from Clucker slaughter yields; living housed Cluckers remain the egg source.
- Replaced the horizontal spell-category row with a touch-sized radial category wheel.
- Improved schema-3-to-4 item migration and made failed save replacement recoverable through the verified first backup.
- Added a GitHub Actions macOS pipeline that tests, exports an Xcode project, creates an unsigned archive, strips signatures/profiles, verifies the package, and uploads the IPA plus checksum.
- Hardened the test gate so a printed PASS cannot hide a Godot runtime error.
- Excluded tests, tools, docs, workflow files, build output, and reference art from exports.

## Honest phase status

| Area | Status | What is proven |
|---|---|---|
| Audit integrity | In progress | Unsupported promotions were restored; 148 runtime checks and 190 wiki-supported claims remain open. |
| Core loop and deterministic tests | Good foundation | Fixed tick, replay/hash, save round trips, and the current internal scenarios pass. Stress/device targets are unproven. |
| Physical economy | Major partial | New inventory/reservation contracts pass focused tests, but the live simulation still uses the aggregate resource dictionary. |
| Jobs, buildings, production | Broad prototype | Many normal-play paths exist in the monolithic simulation. Complete physical logistics and exact reference values are open. |
| Population and animals | Functional first pass | Live breeding, capture, eggs, automatic slaughter, yields, Doggos, and recovery have tests. Full parity and lifecycle depth are open. |
| Combat, corruption, events | Broad prototype | Representative systems run and have internal tests. Exact tiers, AI, balance, and all interactions are not reference-verified. |
| God powers and Update 2 systems | Functional first pass | Thirty-two catalog powers and main faith/ghost loops exist. Exact values/effects remain partly unverified. |
| Campaign and meta progression | Partial | Forty-five catalog nodes, regional flow, achievements, perks, and Doom foundations exist. Exact graph and full goal/perk behavior are open. |
| Mobile UI | Partial | Adaptive drawers, safe-area foundation, pan/pinch, and a radial spell wheel exist. Full gestures/accessibility and physical-device QA are open. |
| Art and audio | Prototype/in review | Original generated/code-native presentation exists; 478 sprites are unapproved and audio is not a production soundtrack/SFX library. |
| Saving | Recoverable partial | Checksums, migrations, and eight backups exist. Windows replacement has a recoverable non-atomic fallback; profiles, manual slots, and recovery UX are open. |
| Unsigned IPA | Configured, not yet proven | Workflow and iOS preset exist locally. A pushed macOS Actions run must succeed before this becomes verified. |

## Release-language rule

Do not call the game complete, faithful, parity-verified, production-ready, or iOS-certified while any of the following remains true:

- the live global resource dictionary is authoritative;
- `VERIFY_RUNTIME` or unreviewed parity values remain;
- shipping sprite records remain `IN_REVIEW`;
- the unsigned-IPA workflow has not produced and verified an artifact;
- target iPhone/iPad performance and controls have not been physically tested.

Use `CURRENT_VERIFIED_ISSUES.md` for concrete blockers and `RECHECK_IMPLEMENTATION_CHECKLIST.md` for the full execution queue.
