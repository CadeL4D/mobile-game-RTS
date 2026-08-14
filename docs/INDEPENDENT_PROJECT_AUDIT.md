# Ruinward / Rise to Ruins Mobile Recreation — Independent Project Audit

**Audit date:** 2026-08-13  
**Workspace:** `C:\Users\cadel\Documents\Godot\GodotProjects\mobile-game`  
**Target:** clean-room mobile recreation of Rise to Ruins Update 2d  
**Audit type:** source, data, test, build, visual-output, and checklist-integrity review

## Executive verdict

The project is a broad, playable prototype with a functioning deterministic simulation, a large content catalog, desktop/mobile-adaptive UI, generated overhead art, and many first-pass game systems. The independent full test suite passes.

It is **not a complete or parity-verified recreation**, and it is **not release-ready**. The existing `MASTER_COMPLETION_CHECKLIST.md` and `AUDIT_LOG.md` cannot be treated as proof of completion because uncertain entries were bulk-promoted without new reference evidence, catalog counts were presented as implemented gameplay, and visual/audio prototype coverage was described as approved production content.

Use `RECHECK_IMPLEMENTATION_CHECKLIST.md` as the authoritative execution queue. A task is complete only when its stated evidence and acceptance gate exist.

## 2026-08-14 remediation update

The following findings from the original audit have now been corrected and this note supersedes older statements below where they conflict:

- The live aggregate economy uses `PhysicalInventory` as its authoritative stock ledger. Direct global stock changes were removed from normal systems and routed through atomic add/consume/set operations.
- Starting stock is composed of bounded ground stacks at the actual starting cell, not a nonexistent container ID.
- Schema 5 saves physical stock only in `inventory`; `energy` and `faith` are stored separately as nonphysical pools. Schema-4 saves migrate without trusting the old duplicate physical totals.
- UI and text scaling now apply at runtime and are exposed in an in-app settings/accessibility overlay. Panel auto-pause and reduced-motion presentation have live consumers.
- The current strict suite contains 43 test functions and 488 assertion call sites and passes with no engine error markers.

This does **not** close extracted-system integration, exact executable parity, per-stack worker hauling, perk coverage, goal prerequisites, production art/audio approval, GitHub IPA execution, or physical iOS certification.

## Evidence collected

- The complete headless test runner passes from independent launches with exit code 0. The suite currently contains **43 test functions** and **488 `_assert()` call sites**. The latest strict log is `build/current-fixes-tests.log`.
- The reported number **741** is the number of catalog entries loaded by the test run, not the number of test assertions.
- All 16 JSON files parse successfully.
- `git diff --check` passes, with line-ending warnings only.
- A Windows executable was exported successfully, but the export packages development, reference, test, capture, and local-save artifacts.
- Existing phone, tablet, terrain, biome, and building review captures were inspected.
- Source consumers—not only catalog rows—were traced for simulation, production, professions, meta progression, touch, saving, audio, and generation.
- The current world-map wiki and official Update 2d material were used only as secondary checks. Exact parity still requires the installed reference executable.

## Checklist-integrity findings

### Critical: evidence statuses were changed without evidence

`tools/promote_evidence.py` globally replaces every `VERIFY_RUNTIME` string with `CONFIRMED_OFFICIAL`. It does not capture a source, inspect the installed game, record a build, or validate a value.

This changed the data from a previously observed **140 `VERIFY_RUNTIME` entries** to zero while increasing `CONFIRMED_OFFICIAL` entries to 293. Exact region structure, Camp values, jobs, the Outpost, golem names, and the 113/117 goal reconciliation were among the promoted areas.

These promotions are invalid. They must be reverted entry by entry unless a supporting executable observation or authoritative source is attached.

### Critical: checked boxes do not match delivered evidence

The master checklist contains **524 tasks, 505 checked**. It checks all implementation sections even though:

- 478 shippable sprite-ledger entries remain `IN_REVIEW`; none are approved.
- There is no full original 16-track soundtrack.
- There is no exact executable parity ledger closeout.
- Physical per-item logistics is not implemented for the resource catalog.
- The goal web, most perk effects, advanced editor, complete mobile gesture contract, localization, CI, clean exports, iOS build, device profiling, and release documents are incomplete.

The completion marks are therefore status assertions, not reliable audit results.

### High: the previous audit log overstates testing and completion

The earlier `docs/AUDIT_LOG.md` stated that all phases were complete and cited 741 assertions. It has now been replaced with a truthful status snapshot. The current measurable suite is 43 test functions and 488 assertion call sites; 741 is the loaded content-entry count. Passing tests establish internal consistency for the encoded cases, not reference accuracy or complete normal-play reachability.

## Supplied claim audit

| Claim | Result | Evidence and remaining work |
|---|---|---|
| Fixed 10 Hz simulation decoupled from rendering | **Verified foundation** | `SimulationHost` uses a 10 Hz accumulator in `_process`. Deterministic replay/hash tests pass. Stable 60/120 FPS on target hardware has not been measured. |
| Zero-allocation logistics/pathfinding/task-board hot paths | **Not true** | Hot paths allocate and copy Arrays/Dictionaries, call `duplicate(true)`, produce key arrays, filter, sort, and rebuild task records. Profile first; then establish allocation budgets. |
| Schema 5, eight backups, state hash | **Mostly verified** | Schema 5 removes dual physical-stock serialization; checksum/hash, migrations, and eight rotating backups pass round trips. Rename-over-target is attempted first; the Windows fallback preserves `.bak1` but still has a remove/rename interruption window. Profile/manual-slot/recovery UX is absent. |
| Fifteen settlement stages | **Cataloged; partial behavior/art** | Fifteen town-center stages exist. Exact Update 2d costs, capacities, unlock rules, footprints, and all unique visual states are not runtime-confirmed. |
| Twenty-five professions | **Cataloged; partial behavior** | Twenty-five job definitions exist. Several jobs use simplified global rules rather than full workplace attendance, physical input/output, task claiming, and failure recovery. |
| Fifty-eight physical resources | **Catalog count only** | Fifty-eight resource definitions exist. Most economy operations use a single global resource dictionary and aggregated capacities, so these are not all physical stacks moving through storage and reservations. |
| Hunger, thirst, sleep, medical triage | **Partial** | Hunger, thirst, energy, health, treatment/status foundations exist. Personal temperature, happiness, panic, confusion, complete illness flow, and full needs behavior are incomplete. |
| Beefalo, Entler, Rous, Clucker husbandry | **Partial** | Breeding, slaughter, yields, and eggs exist in first-pass form. Shearing is absent; habitat, capture, housing, aging, pregnancy, and lifecycle parity require deeper verification. |
| Doggo hauling and Catjeet caravans | **Functional first pass** | Doggo hauling/combat/loot and Catjeet trade logic exist. Full movement, scheduling, UI, edge cases, and reference balance remain unverified. |
| Thirty-two official spells across seven groups | **Count right; grouping claim wrong** | Thirty-two spell rows exist, but the data contains **five groups**: aid, defensive, hand, offensive, and utility. All values/effects still need executable parity tests. |
| Divine Hand grab/drop | **Functional first pass** | Command and interaction support exists. Mobile targeting, physics-like presentation, invalid targets, costs, edge cases, and parity require work. |
| Faith → Essence → Energy | **Functional first pass** | The loop and relevant buildings exist. Worker attendance, exact rates, capacity, maintenance, feedback, and Update 2d balance require verification. |
| Reliquary resurrection and Cullis sacrifice | **Functional first pass** | Ghost/vessel/resurrection and sacrifice logic exists, but it is simplified and lacks complete on-site job, typed-state, UI, FX, balance, and scenario validation. |
| Twelve tower roles | **Cataloged; partial behavior** | Twelve current tower definitions are present, including Ice Ballista. Exact current roster, all tier values/art, resource flows, targeting, rotation, projectiles, and special behavior are not fully verified. |
| Monster/corruption systems | **Broad first pass** | Core monster families, corruption spread, hostile structures, towers, and events are represented. AI depth, construction/upgrades, spawning, combat rules, and mode balance remain partial. |
| Forty-five-region campaign | **Functional graph; parity unverified** | Forty-five rows and regional interactions exist. Forty-three rows are wiki-supported only. The added `lost_island` node is unsupported by the current wiki list; exact names, identities, and adjacency must be observed in the executable. |
| 113 achievements | **Metadata/rules cataloged; not full goal web** | There are 113 achievement records and simple rule mappings. The UI is a flat list, prerequisite web/rewards are incomplete, and all achievements have not been demonstrated through normal play. |
| Forty-seven perks | **Cataloged; mostly inert** | Forty-seven perk definitions exist, but static consumer tracing found gameplay consumers for only about ten perk stat IDs. Implement and test every remaining effect. |
| Five God Chest tiers | **Cataloged; simplified behavior** | Five tier records exist, but chest granting is a generic fixed-XP interval and random perk selection without complete tier-specific tables, costs, presentation, or parity. |
| Doom reset loop | **Functional first pass** | Reset/persistence paths exist. Exact per-mode retained state and long campaign regression scenarios remain unverified. |
| Six game modes | **Cataloged; partial rule coverage** | All six modes are selectable. Custom exposes only a limited control set; Sandbox lacks the complete reference debug/spawn toolbox; exact rules and timing remain unverified. |
| `.rtrmap` editor | **Basic prototype** | Terrain/elevation painting, validate, save, load-latest, and play test exist. Resources, actors, corruption, objects, starting state, events, advanced editing, file selection/share, preview, migration, and robust packages are absent. |
| Safe areas and 44-point touch targets | **Proxy-verified** | Safe-area and adaptive target sizing code exists; simulated phone/tablet checks pass. No physical iPhone/iPad validation has been performed. |
| Pinch, pan, radial wheels, bottom drawers | **Partial** | Drag pan, pinch zoom, edge drawers, and a touch-sized radial spell-category wheel exist. Double tap, long press, second-finger brush pan, and drag-ghost placement remain absent. |
| Haptics | **Implemented; device-unverified** | Placement, milestone, and event calls reach handheld vibration. Strength/pattern support, settings completeness, and physical device behavior require testing. |
| Nearest-pixel rendering, shaders, night lights | **Prototype implemented** | Nearest base rendering, corruption/terrain/resource shaders, night tint, and light pools exist. Some overlay filtering is deliberately linear. Visual quality and performance are not approved. |
| Six-bus adaptive audio | **Infrastructure only** | Six custom buses plus Master exist. Runtime audio is three short synthesized music layers and sixteen procedural cues. The catalog lists sixteen tracks, but a production soundtrack and full SFX library do not exist. |

## Phase-by-phase project status

| Master section | Audited status | Main reason |
|---|---|---|
| 0. Parity contract | **Failed** | Contract boxes are unchecked and evidence was improperly promoted. |
| 1. Repair current build | **Verified current baseline** | The formerly failing full test suite now passes. This does not prove parity. |
| 2. Executable parity audit | **Not complete** | No complete runtime observation set, evidence attachments, or exact-value closeout. |
| 3. Deterministic simulation | **Good foundation, incomplete scale proof** | Fixed loop/hash/replay foundations work; allocations, profiling, and scale targets are open. |
| 4. Physical economy/logistics | **Major partial** | Global resource pool substitutes for most physical storage, carrying, and reservation flows. |
| 5. Jobs/AI/pathfinding | **Partial** | Task/path/reservation foundations exist; job ownership, attendance, recovery, and hierarchical scaling are incomplete. |
| 6. Buildings/production | **Partial** | Broad catalog and generic operations exist; exact tiers, branches, physical buffers, specialized rules, and visuals are incomplete. |
| 7. Population/animals | **Partial** | Basic needs/life/animal systems exist; full simulation, relationships, statuses, and husbandry do not. |
| 8. Corruption/combat/events | **Partial** | Broad representative systems exist without complete parity, balance, or stress coverage. |
| 9. God powers/Update 2 | **Functional first pass** | Spell count and main loops exist; precise effects, attendance, UI/FX, and balance are incomplete. |
| 10. Campaign/meta | **Partial** | Regional actions and flat achievements work; exact graph, goal web, perks, chests, tutorials, and statistics remain incomplete. |
| 11. Modes/Sandbox/editor | **Partial** | Six modes and a terrain editor exist; complete control surfaces and editor content are absent. |
| 12. Mobile UI/controls | **Partial** | Adaptive proxy layouts and basic gestures exist; full gesture/accessibility/settings/device work is absent. |
| 13. Original production art | **In review** | 478 shippable ledger entries remain `IN_REVIEW`; visual captures show prototype rather than approved production art. |
| 14. Original audio/haptics | **Audio prototype** | Bus/haptic foundation works; soundtrack, complete cues, mix, accessibility, and device QA are missing. |
| 15. Saves/settings/localization | **Partial** | Save foundation and the first settings/accessibility overlay work; profiles, named slots, autosave/resume, localization, and recovery UX remain incomplete. |
| 16. Automated/manual QA | **Partial** | Internal suite passes; coverage, normal-play scenarios, seed matrix, long soaks, target-device performance, and visual/manual QA are incomplete. |
| 17. Build/release | **Configured, not proven** | A macOS unsigned-IPA workflow now exists and export filters were tightened. It has not run on GitHub yet; device proof, signing, legal/privacy/credits, localization, and release smoke gates remain missing. |

## Highest-risk implementation gaps

1. **Parity evidence:** restore all unjustified statuses and observe exact reference behavior before using reference-accurate language.
2. **Physical economy:** replace global stock mutation with item locations, building buffers, reservations, carrying, storage filters, and conservation tests.
3. **Jobs and production:** make the assigned worker physically attend and perform every staffed operation; scale work by real workers.
4. **Meta progression:** build the real prerequisite/reward goal graph and connect every perk to tested gameplay behavior.
5. **Campaign accuracy:** verify every region and every graph edge; remove or confirm `lost_island`.
6. **Mobile completeness:** finish the gesture contract, settings/accessibility, and physical-device validation.
7. **Production assets:** obtain explicit art approval per ledger entry and create the promised soundtrack/SFX rather than catalog placeholders.
8. **Release hygiene:** exclude source/reference/test/save/build-review content, add CI and release documents, and prove Windows/iOS release candidates.

## Test and build interpretation

The passing suite is valuable: it establishes a stable baseline and shows that the recent regression fixes are real. It must remain green throughout implementation. It cannot be used as a percentage-complete metric because many tests check catalog presence, simplified internal mutations, or representative examples rather than reference values, normal player flows, every content entry, target-device performance, or production presentation.

The Windows export proves that Godot can package the project. It is not a release candidate because `all_resources` includes rejected/reference generated art, captures, tests, tools, and a local automated save. The attempted exported-executable smoke launch also needs to be repeated in a clean environment before it can become a gate.

## Required completion rule

No task may be marked complete using only a catalog row, a checked box, a comment, or a passing unrelated test. Every task needs:

1. A specific implementation or verified reference observation.
2. A focused automated test where the behavior can be automated.
3. A normal-play/manual scenario for UI, art, audio, or interaction work.
4. An attached evidence path or source citation.
5. A passing full regression suite.

Reference parity and original presentation are separate gates: a mechanic can be implemented but not parity-verified, and an asset can exist but remain unapproved.

## Reference links

- [Rise to Ruins World Map wiki](https://rise-to-ruins.fandom.com/wiki/World_Map)
- [Official Update 2d announcement](https://store.steampowered.com/news/app/328080/view/3712711277286541677)
- [Current Steam achievements](https://steamcommunity.com/stats/328080/achievements/?curator_clanid=4777282)
