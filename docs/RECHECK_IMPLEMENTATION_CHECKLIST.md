# Ruinward — Recheck and Completion Checklist

**Created:** 2026-08-13  
**Purpose:** trusted handoff queue after the independent project audit  
**Rule:** every unchecked item is either unproven, partial, missing, or requires a clean recheck

This checklist supersedes the completion marks in `MASTER_COMPLETION_CHECKLIST.md`. It does not discard working code. Preserve the green baseline and close these items with evidence.

## How the implementing model must work

- Complete one numbered work packet at a time.
- Do not bulk-change evidence or task status.
- Do not infer reference values from existing project data.
- Record files changed, focused tests, full-suite result, capture/log paths, and limitations.
- Add a failing focused test before fixing a reproducible behavior bug.
- Verify gameplay through public commands and normal UI flows where possible.
- Keep reference accuracy, implementation, automated testing, and presentation approval as separate statuses.
- Never mark art `APPROVED` without a reviewed 1× in-game capture.
- Never mark parity `CONFIRMED_RUNTIME` without the reference build, screen/state, observed value, and audit note.
- Finish each packet with zero JSON errors, `git diff --check`, focused tests, and the full suite.

### Required completion evidence

Every checked task must have a ledger note containing:

- `task_id`
- `status`
- `files_changed`
- `reference_evidence`
- `focused_test`
- `manual_scenario`
- `full_suite_log`
- `known_limitations`

## P0 — Restore audit integrity

- [x] AUD-001 — Disable `tools/promote_evidence.py` from changing evidence statuses. The file is absent and a restore-only audit tool replaces it.
- [x] AUD-002 — Recover the pre-promotion status of every affected field from version history/diff.
- [x] AUD-003 — Return every unsupported promotion to `VERIFY_RUNTIME` or `WIKI_SUPPORTED`.
- [ ] AUD-004 — Add source URL/build/screen/note fields to every parity record.
- [ ] AUD-005 — Separate row-level evidence from individual value evidence.
- [ ] AUD-006 — Reject `CONFIRMED_RUNTIME` records without observed build and evidence path.
- [ ] AUD-007 — Reject `CONFIRMED_OFFICIAL` records without an authoritative URL and quoted fact summary.
- [ ] AUD-008 — Reject shippable `VERIFY_RUNTIME` entries in release validation.
- [x] AUD-009 — Mark `docs/AUDIT_LOG.md` as historical/untrusted or replace its false conclusions.
- [x] AUD-010 — Reset invalid completion marks in `MASTER_COMPLETION_CHECKLIST.md` or archive that file. A prominent historical-backlog warning now redirects completion decisions to this checklist.
- [ ] AUD-011 — Add an append-only parity observation log.
- [ ] AUD-012 — Add a machine-readable task evidence ledger.
- [ ] AUD-013 — Validate unique content IDs across all catalogs.
- [ ] AUD-014 — Validate every cross-catalog reference.
- [ ] AUD-015 — Validate evidence enum values and required evidence fields.
- [ ] AUD-016 — Fix the two mojibake strings in `docs/ART_REVIEW_LOG.md`.
- [ ] AUD-017 — Preserve unrelated user changes while reorganizing audit files.
- [x] AUD-018 — Record the installed Update 2d build as the parity target.
- [ ] AUD-019 — Record all intentional mobile adaptations separately from parity deviations.
- [x] AUD-020 — Publish a fresh truth snapshot containing verified, partial, missing, and unverified counts.

**Exit gate:** no task or parity status can be changed without traceable evidence.

## P0 — Preserve and independently recheck the green baseline

- [x] BASE-001 — Run the full headless suite twice from clean launches.
- [ ] BASE-002 — Store both engine logs and final exit codes.
- [x] BASE-003 — Confirm all 42 named test groups execute rather than only parse.
- [ ] BASE-004 — Report assertion call sites separately from runtime assertions.
- [x] BASE-005 — Confirm all JSON catalogs parse and validate.
- [x] BASE-006 — Run `git diff --check` and resolve non-line-ending defects.
- [ ] BASE-007 — Re-run every formerly failing regression as a focused test.
- [x] BASE-008 — Launch the editor project and clear all startup errors/warnings that indicate defects.
- [ ] BASE-009 — Start a new Traditional game through the UI.
- [ ] BASE-010 — Place a Camp, save, reload, and continue through normal UI controls.
- [ ] BASE-011 — Capture current desktop, phone, and tablet baseline screens.
- [ ] BASE-012 — Record current frame, tick, memory, save-size, and load-time baselines.

**Exit gate:** the current playable foundation is reproducibly green before deeper changes.

## P0 — Complete executable parity research

- [ ] PAR-001 — Audit all six mode descriptions, defaults, modifiers, and reset behavior.
- [ ] PAR-002 — Audit the exact 45 region names and display order.
- [ ] PAR-003 — Audit every world-graph edge from the reference map.
- [ ] PAR-004 — Confirm or remove `lost_island`.
- [ ] PAR-005 — Audit each region biome, difficulty, start state, and visual identity.
- [ ] PAR-006 — Audit all 15 Camp/Castle stage names and order.
- [ ] PAR-007 — Audit every town-center cost, HP, range, storage, builders, support, and Ancillary allowance.
- [ ] PAR-008 — Audit the complete current build-menu category order.
- [ ] PAR-009 — Audit every current building name and removed legacy building.
- [ ] PAR-010 — Audit every building tier/branch, cost, HP, footprint, range, capacity, and worker slot.
- [ ] PAR-011 — Audit placement, desirability, corruption resistance, and build-range rules.
- [ ] PAR-012 — Audit all 25 profession names, colors, caps, workplaces, and tasks.
- [ ] PAR-013 — Audit all 58 resource names, icons, stacks, decay, and storage categories.
- [ ] PAR-014 — Audit every recipe input, output, duration, worker, and make/maintain rule.
- [ ] PAR-015 — Audit tools, weapons, armor, ammunition, durability, and equipment priorities.
- [ ] PAR-016 — Audit all animals, friendly agents, monsters, life states, and spawn rules.
- [ ] PAR-017 — Audit the exact current tower roster, including Ice Ballista status.
- [ ] PAR-018 — Audit every tower tier, range, reload, ammunition/energy, targeting, and effect.
- [ ] PAR-019 — Audit golem names, caps, construction, energy, degradation, repair, and roles.
- [ ] PAR-020 — Audit corruption spread, ownership, resistance, cleansing, and global pressure.
- [ ] PAR-021 — Audit enemy structures, construction stages, upgrades, and spawn behavior.
- [ ] PAR-022 — Audit damage types, status interactions, armor, shields, and friendly fire.
- [ ] PAR-023 — Audit time phases, season lengths, weather, temperature, and visibility.
- [ ] PAR-024 — Audit all lunar, weather, nomad, and disaster events.
- [ ] PAR-025 — Audit all 32 spell names, groups, costs, cooldowns, radii, durations, and effects.
- [ ] PAR-026 — Reconcile the five implemented spell groups with the requested/reference grouping.
- [ ] PAR-027 — Audit faith, influence, essence, energy, prayer, and maintenance values.
- [ ] PAR-028 — Audit Eerie Vessels, ghosts, Reliquary, resurrection, and Cullis Gate behavior.
- [ ] PAR-029 — Reconcile 117 historical goals with 113 current Steam achievements.
- [ ] PAR-030 — Audit the exact goal graph, prerequisites, counters, rewards, and persistence.
- [ ] PAR-031 — Audit all perks, modifiers, stacking, slots, and chest reward tables.
- [ ] PAR-032 — Audit tutorials, statistics, Custom controls, Sandbox tools, and editor tools.
- [ ] PAR-033 — Record reference bugs separately and specify corrected intended behavior.
- [ ] PAR-034 — Attach a parity test ID to every shippable content record.
- [ ] PAR-035 — Close every `VERIFY_RUNTIME` entry before a parity release claim.

**Exit gate:** every shipping value is runtime-confirmed, officially confirmed, or explicitly documented as a mobile adaptation.

## P1 — Deterministic simulation and performance foundation

- [ ] SIM-001 — Keep the authoritative simulation fixed at 10 Hz.
- [ ] SIM-002 — Verify identical seed/command logs produce identical hashes across repeated launches.
- [ ] SIM-003 — Verify pause, speed changes, focus loss, and resume never skip or double ticks.
- [ ] SIM-004 — Define tick-debt behavior and test long render stalls.
- [ ] SIM-005 — Separate cosmetic RNG from terrain, AI, combat, birth, event, and loot RNG.
- [ ] SIM-006 — Save and restore every authoritative RNG stream.
- [ ] SIM-007 — Replace gameplay-critical floating-point accumulation where it breaks determinism.
- [ ] SIM-008 — Profile per-tick allocations in logistics, tasks, pathfinding, and snapshots.
- [ ] SIM-009 — Remove deep copies and temporary collections from measured hot paths.
- [ ] SIM-010 — Set allocation and time budgets for each hot subsystem.
- [ ] SIM-011 — Enforce the simulation/render ownership boundary.
- [ ] SIM-012 — Ensure snapshots are immutable projections.
- [ ] SIM-013 — Cap event history and rate-history memory.
- [ ] SIM-014 — Add reproducible benchmark scenes and machine-readable reports.
- [ ] SIM-015 — Test 10 Hz stability under the final stress population.

**Exit gate:** deterministic hashes pass and the final stress scene accrues no tick debt.

## P1 — Physical economy and logistics

- [ ] ECO-001 — Give every physical resource stack an ID, type, quantity, cell/container, owner, and reservation state.
- [ ] ECO-002 — Replace direct global recipe mutations with physical input/output buffers.
- [ ] ECO-003 — Keep aggregate totals as derived indexes only.
- [ ] ECO-004 — Add atomic reservations for stacks, quantities, destinations, and carrying slots.
- [ ] ECO-005 — Release reservations on death, job change, cancel, destruction, save/load, and route failure.
- [ ] ECO-006 — Split/merge stacks without loss or duplication.
- [ ] ECO-007 — Implement ground, carried, building-buffer, storage, trade, courier, and loot locations.
- [ ] ECO-008 — Implement villager and agent carrying limits.
- [ ] ECO-009 — Implement pickup, travel, delivery, drop, and unavailable-destination recovery.
- [ ] ECO-010 — Implement storage filters and per-storage capacity.
- [ ] ECO-011 — Implement delivery priorities and urgent-consumer scoring.
- [ ] ECO-012 — Implement make/maintain targets against physical accessible stock.
- [ ] ECO-013 — Prevent reserved stock from satisfying another consumer.
- [ ] ECO-014 — Implement decay by item/location/exposure.
- [ ] ECO-015 — Implement every waste conversion and Trashy Cube flow physically.
- [ ] ECO-016 — Implement tools/equipment as durable carried items.
- [ ] ECO-017 — Implement ammunition stacks and per-shot consumption.
- [ ] ECO-018 — Implement clean/dirty/bottled water logistics.
- [ ] ECO-019 — Implement keys, loot boxes, ownership, opening, and pure-trash outcomes.
- [ ] ECO-020 — Implement trade stock reservation, exchange, and caravan transfer.
- [ ] ECO-021 — Implement courier loading, transit, arrival, failure, and unloading.
- [ ] ECO-022 — Compute production/consumption rates from actual transfers.
- [ ] ECO-023 — Add conservation tests for every recipe and transfer path.
- [ ] ECO-024 — Add deadlock and starvation recovery tests.
- [ ] ECO-025 — Add UI diagnostics for why a resource is unavailable.

**Exit gate:** no normal economy path creates/destroys items outside explicit recipes, decay, spawning, trade, or divine actions.

## P1 — Jobs, task AI, and pathfinding

- [ ] JOB-001 — Make desired/current/maximum quotas authoritative for all 25 jobs.
- [ ] JOB-002 — Require a valid workplace and capacity before taking a staffed job.
- [ ] JOB-003 — Require physical attendance for every staffed operation.
- [ ] JOB-004 — Scale throughput by attending workers, tools, level, status, and building tier.
- [ ] JOB-005 — Implement Builders’ delivery, construction, upgrade, and emergency harvest loop.
- [ ] JOB-006 — Implement Organizers’ complete logistics priority loop.
- [ ] JOB-007 — Implement Lumberjack, Miner, and Crystal Harvester designation loops.
- [ ] JOB-008 — Implement Farmer forage, crop, livestock, breeding, and slaughter loops.
- [ ] JOB-009 — Implement Water Master collection, purification, farm, and fountain loops.
- [ ] JOB-010 — Implement every refinery and manufacturer worker loop.
- [ ] JOB-011 — Implement Cook, Bottler, Medic, and Ranger loops.
- [ ] JOB-012 — Implement Way Maker and Maintainer build/repair/remove/dig loops.
- [ ] JOB-013 — Implement Provisioner and Courier Supplier physical loops.
- [ ] JOB-014 — Implement Trasher and Occultist physical loops.
- [ ] JOB-015 — Make task discovery, scoring, claiming, work, delivery, and release explicit.
- [ ] JOB-016 — Prevent two agents from claiming the same exclusive work.
- [ ] JOB-017 — Recover from deleted targets, finished work, closed routes, and destroyed workplaces.
- [ ] JOB-018 — Detect and recover stuck agents without teleporting normal work.
- [ ] JOB-019 — Add gates, roads, hazards, water, corruption, crowding, and temperature to path costs.
- [ ] JOB-020 — Implement chunk/portal pathfinding or prove the current solver meets scale targets.
- [ ] JOB-021 — Invalidate paths only for changed areas.
- [ ] JOB-022 — Add flow-field behavior for mass migration and major attacks.
- [ ] JOB-023 — Add task, reservation, path, and stuck-time debug overlays.
- [ ] JOB-024 — Test every job through normal simulation, not direct state mutation.
- [ ] JOB-025 — Run a multi-day mixed-economy soak with zero permanent idle deadlocks.

**Exit gate:** every profession completes its complete reference task cycle and recovers from invalid work.

## P1 — Buildings, upgrades, production, roads, and walls

- [ ] BLD-001 — Verify and implement every current building definition.
- [ ] BLD-002 — Implement exact footprint, entrance, placement, collision, and build-range rules.
- [ ] BLD-003 — Implement 0/25/50/75/100 percent construction states.
- [ ] BLD-004 — Deliver construction materials physically.
- [ ] BLD-005 — Implement exact HP, cost, capacity, worker, range, and speed changes per tier.
- [ ] BLD-006 — Implement all branch upgrades and prevent invalid branch switching.
- [ ] BLD-007 — Implement all 15 town-center stages and unlock effects.
- [ ] BLD-008 — Implement Camp/Ancillary build-range and support limits.
- [ ] BLD-009 — Implement harvesting-building designation and range behavior.
- [ ] BLD-010 — Implement farms, seasons, water, crops, pens, coops, and kitchens.
- [ ] BLD-011 — Implement all four refining and four manufacturing chains.
- [ ] BLD-012 — Implement every storage family and Key Shack.
- [ ] BLD-013 — Implement Clinic treatment and medical production.
- [ ] BLD-014 — Implement Ranger Lodge and Outpost confirmed behavior.
- [ ] BLD-015 — Implement Marketplace trade rules and worker attendance.
- [ ] BLD-016 — Implement Migration Way Station and Courier Station flows.
- [ ] BLD-017 — Implement Essence Altar, Collector, Reliquary, and Cullis Gate fully.
- [ ] BLD-018 — Implement fire pits, lighting, heat, support range, and motivator behavior.
- [ ] BLD-019 — Implement all current tower tiers and special rules.
- [ ] BLD-020 — Implement every golem combobulator and Recombobulator support rule.
- [ ] BLD-021 — Implement trash cans, landfills, processors, burners, Cube-E, piles, and walls.
- [ ] BLD-022 — Implement all five road stages, bonuses, decay, work, and removal.
- [ ] BLD-023 — Implement all wall/gate materials, connectivity, access, and projectile rules.
- [ ] BLD-024 — Implement damage, fire, repair, dismantle, destruction, and rubble.
- [ ] BLD-025 — Implement disabled/input-full/output-full/no-worker/no-energy/no-ammo states.
- [ ] BLD-026 — Implement building-specific inspector controls and explanations.
- [ ] BLD-027 — Add focused tests for every tier, branch, recipe, and specialized behavior.
- [ ] BLD-028 — Confirm all legacy buildings remain excluded from shipping menus.

**Exit gate:** every current building can be placed, built, operated, upgraded, damaged, repaired, and removed through normal play.

## P1 — Villagers, animals, traders, and friendly agents

- [ ] POP-001 — Implement stable identity, name, type, level, XP, age, sex/body rules, and job color.
- [ ] POP-002 — Implement health, hunger, thirst, energy, sleep, temperature, and housing per villager.
- [ ] POP-003 — Implement happiness, faith, panic, confusion, and all confirmed status effects.
- [ ] POP-004 — Implement eating, drinking, sleeping, breaks, socializing, fleeing, fighting, and recovery.
- [ ] POP-005 — Implement relationships, mating, pregnancy, birth, childhood, adulthood, and elders.
- [ ] POP-006 — Implement aging, natural death, corpses, decay, ghosts, capture, and resurrection.
- [ ] POP-007 — Implement equipment choice, durability, replacement, and combat use.
- [ ] POP-008 — Implement injury, poison, blight, disease, treatment priority, and death causes.
- [ ] POP-009 — Implement faith reactions to observed divine/world events.
- [ ] POP-010 — Implement influence contribution by villager type and faith.
- [ ] POP-011 — Implement Beefalo lifecycle, products, housing, breeding, and slaughter.
- [ ] POP-012 — Implement Entler lifecycle, products, housing, breeding, and slaughter.
- [ ] POP-013 — Implement Rous lifecycle, products, housing, breeding, and slaughter.
- [ ] POP-014 — Implement Clucker lifecycle, eggs, feathers, housing, breeding, and slaughter.
- [ ] POP-015 — Confirm whether any reference animal is sheared; implement only if verified.
- [ ] POP-016 — Implement animal habitat, hunger, thirst, sleep, aging, death, and combat.
- [ ] POP-017 — Implement Ranger capture/domestication and delivery to housing.
- [ ] POP-018 — Implement Doggo/Doofy self-taming, housing, hauling, fighting, keys, loot, and ghosts.
- [ ] POP-019 — Implement nomad, migrant, Nephilim, elder, child, and Catjeet differences.
- [ ] POP-020 — Implement all friendly golem production, work, combat, energy, degradation, repair, and dispel.
- [ ] POP-021 — Test save/load during pregnancy, migration, combat, hauling, death, and resurrection.

**Exit gate:** every population type completes its full lifecycle without invalid tasks or lost state.

## P1 — Corruption, enemies, combat, time, weather, and events

- [ ] COM-001 — Implement local/global corruption targets, spread, resistance, and cleansing.
- [ ] COM-002 — Implement corruption ownership under terrain, resources, and structures.
- [ ] COM-003 — Implement Drone construction and upgrading of all hostile structures.
- [ ] COM-004 — Implement every confirmed slime, zombie, skeleton, spectre, elemental, Drone, and Headless behavior.
- [ ] COM-005 — Implement graveyard/spawner timing and mode-dependent pressure.
- [ ] COM-006 — Implement day/night and moon-dependent spawning.
- [ ] COM-007 — Implement target selection, threat, pursuit, retreat, wall breaking, and maze response.
- [ ] COM-008 — Implement melee, ranged, projectile, area, fire, ice, electric, poison, water, and magic rules.
- [ ] COM-009 — Implement armor, shield, durability, resistance, immunity, and friendly fire.
- [ ] COM-010 — Implement spectre crossing/targeting and Banish interactions.
- [ ] COM-011 — Implement corpse infection and zombie conversion.
- [ ] COM-012 — Implement drowning, freezing, heat, starvation, blight, and environmental death.
- [ ] COM-013 — Implement tower rotation, projectiles, impact, priorities, resources, and specials.
- [ ] COM-014 — Implement dawn, morning, midday, evening, dusk, and night.
- [ ] COM-015 — Implement day/year progression and all seasons.
- [ ] COM-016 — Implement rain, snow, temperature, crop dormancy, lighting, and visibility.
- [ ] COM-017 — Implement Nomads, Full Moon, Blood Moon, and Eclipse.
- [ ] COM-018 — Implement Meteor Shower, Lightning Storm, Hail, Earthquake, Blight, and Comet.
- [ ] COM-019 — Implement warnings, aftermath, faith/panic, statistics, goals, visuals, and audio for every event.
- [ ] COM-020 — Test every damage/status pairing and event through deterministic scenarios.
- [ ] COM-021 — Run mature-village attack/disaster combinations without stalls or save corruption.

**Exit gate:** every confirmed enemy and event can occur, resolve, persist, and report correctly.

## P1 — God powers, faith, ghosts, and Update 2 systems

- [ ] GOD-001 — Verify the exact 32-spell roster and grouping.
- [ ] GOD-002 — Implement exact cost, reserve, cooldown, cast, radius, duration, and valid targets per spell.
- [ ] GOD-003 — Implement every Aid spell and its side effects.
- [ ] GOD-004 — Implement every Defensive spell and maintained structure behavior.
- [ ] GOD-005 — Implement every Offensive/control spell and damage interaction.
- [ ] GOD-006 — Implement every Utility spell and golem/material behavior.
- [ ] GOD-007 — Complete Divine Hand pickup, carry, drain, validity, drop, and failure behavior.
- [ ] GOD-008 — Implement faith gain/loss from perceived actions.
- [ ] GOD-009 — Implement Occultist attendance, prayer, three-essence yield, and energy conversion.
- [ ] GOD-010 — Implement energy capacities, reservations, consumers, failure, and UI.
- [ ] GOD-011 — Implement Eerie Vessel crafting, soul compatibility, transport, and storage.
- [ ] GOD-012 — Implement ghost binding, maintenance, release, decay, and Reliquary limits.
- [ ] GOD-013 — Implement typed resurrection and all invalid-result handling.
- [ ] GOD-014 — Implement Cullis sacrifices, overload/explosion, essence release, and consequences.
- [ ] GOD-015 — Apply every confirmed Update 2d balance/behavior change.
- [ ] GOD-016 — Add particles, lighting, animation, sound, haptics, statistics, and goals per spell.
- [ ] GOD-017 — Test every spell through valid, invalid, low-resource, and save/load cases.

**Exit gate:** all divine systems match confirmed behavior and remain usable on touch without hidden state.

## P1 — Campaign, regions, goals, perks, tutorials, and statistics

- [ ] CAM-001 — Implement the verified 45-node graph exactly.
- [ ] CAM-002 — Store deterministic region blueprints after first generation.
- [ ] CAM-003 — Implement unestablished, active, lost, reclaimed, and doomed region states.
- [ ] CAM-004 — Implement connected-region establishment rules.
- [ ] CAM-005 — Implement migration queues, capacity, departure, transit, arrival, and failure.
- [ ] CAM-006 — Implement courier queues, cargo, connection, destination loss, and recovery.
- [ ] CAM-007 — Implement regional resource specialization and global corruption influence.
- [ ] CAM-008 — Implement per-mode profiles and progression isolation.
- [ ] CAM-009 — Implement Doom/reset retention exactly per mode.
- [ ] CAM-010 — Replace flat achievement progress with the verified goal prerequisite graph.
- [ ] CAM-011 — Implement every goal counter through normal gameplay events.
- [ ] CAM-012 — Implement goal completion animation, God XP, chest, perk, and other rewards.
- [ ] CAM-013 — Demonstrate all 113 current achievements through reproducible scenarios.
- [ ] CAM-014 — Implement all 47 perk effects and attach a consumer test to each.
- [ ] CAM-015 — Implement perk inventory, slots, equip/unequip, stacking, and persistence.
- [ ] CAM-016 — Implement all five chest tiers with verified tables, costs, odds, and presentation.
- [ ] CAM-017 — Implement lifetime, profile, mode, world, region, actor, building, resource, combat, spell, event, and death statistics.
- [ ] CAM-018 — Build contextual mobile tutorials for all core systems.
- [ ] CAM-019 — Implement tutorial skip, reset, replay, and completion persistence.
- [ ] CAM-020 — Add world-map previews, village markers, corruption overlays, and accessible selection.
- [ ] CAM-021 — Run a multi-region loss/reclaim/Doom/save/load golden campaign.

**Exit gate:** the entire campaign/meta loop is playable without debug mutation and preserves exactly the intended state.

## P1 — Modes, Custom, Sandbox, and map editor

- [ ] MOD-001 — Apply every verified rule for Nightmare.
- [ ] MOD-002 — Apply every verified rule for Survival.
- [ ] MOD-003 — Apply every verified rule for Traditional.
- [ ] MOD-004 — Apply every verified rule for Peaceful.
- [ ] MOD-005 — Expose every verified Custom setting with validation and reset defaults.
- [ ] MOD-006 — Build complete Sandbox controls for actors, resources, corruption, construction, time, season, weather, events, and spells.
- [ ] EDT-001 — Add terrain, topography, water, and corruption tools.
- [ ] EDT-002 — Add resources, plants, structures, objects, creatures, and starting-state tools.
- [ ] EDT-003 — Add event and environment configuration.
- [ ] EDT-004 — Add erase, fill, select, move, copy/paste, undo, and redo.
- [ ] EDT-005 — Add zoom/pan-safe desktop and tablet editing controls.
- [ ] EDT-006 — Validate start area, resources, connectivity, routes, habitats, overlap, and density.
- [ ] EDT-007 — Version `.rtrmap` packages with checksum, metadata, preview, and content requirements.
- [ ] EDT-008 — Add file selection, named saves, overwrite confirmation, import, export, and delete.
- [ ] EDT-009 — Add Windows file and iOS Files/share workflows.
- [ ] EDT-010 — Add package migrations and malformed/unsupported-package errors.
- [ ] EDT-011 — Test edit/save/load/export/import/play on desktop and tablet.

**Exit gate:** each mode is mechanically distinct and the editor can create every supported initial map element safely.

## P1 — Mobile UI, controls, settings, and accessibility

- [ ] MOB-001 — Keep all essential HUD data readable on iPhone 12-class landscape.
- [ ] MOB-002 — Keep all essential HUD data readable on 9th-generation iPad landscape.
- [ ] MOB-003 — Apply safe areas on every screen, sheet, drawer, toast, and modal.
- [ ] MOB-004 — Enforce 44-point targets after final UI/text scaling.
- [ ] MOB-005 — Fix clipped and crowded phone HUD/actions shown in current captures.
- [ ] MOB-006 — Implement tap selection and contextual targeting consistently.
- [ ] MOB-007 — Implement camera drag without activating world tools.
- [ ] MOB-008 — Keep continuous pinch zoom centered between touches.
- [ ] MOB-009 — Implement double-tap center/open inspector.
- [ ] MOB-010 — Implement long-press tooltip/context radial menu.
- [ ] MOB-011 — Implement one-finger brush painting.
- [ ] MOB-012 — Implement second-finger pan without ending a brush.
- [ ] MOB-013 — Implement drag-ghost placement with persistent confirm/cancel.
- [ ] MOB-014 — Implement Divine Hand press-drag with visible cost and drop validity.
- [ ] MOB-015 — Add safe undo or confirmation to destructive actions.
- [ ] MOB-016 — Keep pause/speed reachable in every non-blocking state.
- [ ] MOB-017 — Complete left-handed mirroring.
- [ ] MOB-018 — Apply UI scale and text scale settings to the entire interface.
- [ ] MOB-019 — Apply pause-on-panel and focus-loss settings.
- [ ] MOB-020 — Apply reduce-motion/flash/shake/particles/weather settings.
- [ ] MOB-021 — Add color-blind palettes and non-color status indicators.
- [ ] MOB-022 — Add high contrast and non-pixel/dyslexia-friendly font options.
- [ ] MOB-023 — Add captions for important audio warnings.
- [ ] MOB-024 — Add haptic enable/disable and device-appropriate patterns.
- [ ] MOB-025 — Add complete mouse/keyboard mappings and remapping UI.
- [ ] MOB-026 — Add optional gamepad navigation or document its exclusion.
- [ ] MOB-027 — Build profile, loading, pause, settings, credits, Doom/failure, tutorial, goal-web, perk, statistics, and editor screens.
- [ ] MOB-028 — Test every gesture conflict and modal/panel transition.
- [ ] MOB-029 — Complete physical iPhone and iPad accessibility/readability QA.

**Exit gate:** all primary play flows are comfortable on phone/tablet and remain fully testable on desktop.

## P2 — Original production art and visual quality

- [ ] ART-001 — Keep every shippable sprite `IN_REVIEW` until individually approved.
- [ ] ART-002 — Define and enforce true overhead pixel-art perspective, scale, palette, and density.
- [ ] ART-003 — Replace isolated tree stamps with connected forest canopies and readable clearings.
- [ ] ART-004 — Blend terrain edges with transition masks, clutter, and biome-aware seams.
- [ ] ART-005 — Blend rock formations into terrain without hard rectangular borders.
- [ ] ART-006 — Remove grid/noise repetition at all normal zoom levels.
- [ ] ART-007 — Complete every biome, coast, river, lake, island, ocean, seasonal, wet, dry, frozen, burned, rubble, and corruption state.
- [ ] ART-008 — Complete every tree, stump, rock, ore, crystal, crop, food, flower, and regrowth state.
- [ ] ART-009 — Make every building family identifiable at 1× by silhouette and function.
- [ ] ART-010 — Create unique art for every Camp/Castle stage.
- [ ] ART-011 — Create unique art for every tier/branch of every building.
- [ ] ART-012 — Add foundation, 25/50/75 percent, completed, operating, disabled, damaged, burning, corrupted, dismantling, destroyed, and rubble states.
- [ ] ART-013 — Add input/output, worker, energy, ammunition, storage, range, and status overlays.
- [ ] ART-014 — Complete all road, wall, gate, tower, hostile, golem, trash, faith, and magic visuals.
- [ ] ART-015 — Complete villagers, jobs, life stages, equipment/carry layers, and action animations.
- [ ] ART-016 — Complete every animal, monster, golem, trader, ghost, projectile, and status animation.
- [ ] ART-017 — Complete all UI frames, icons, cursors, indicators, data maps, tooltips, and screens.
- [ ] ART-018 — Complete weather, lighting, corruption, particles, spell, combat, and disaster effects.
- [ ] ART-019 — Review every asset family for silhouette/function at 1×.
- [ ] ART-020 — Review every asset family in a populated multi-biome village.
- [ ] ART-021 — Review every asset family on phone/tablet for contrast, animation, and damage states.
- [ ] ART-022 — Record reviewer, capture, date, notes, provenance, and approval for every ledger entry.
- [ ] ART-023 — Remove rejected/reference generation material from shipping exports.
- [ ] ART-024 — Run atlas, pivot, footprint, palette, frame, and missing-state validators.

**Exit gate:** all ledger items are approved, original, readable at 1×, and proven in-game on target screens.

## P2 — Original audio, music, and haptics

- [ ] AUDO-001 — Replace catalog-only music entries with original production tracks.
- [ ] AUDO-002 — Deliver at least sixteen adaptive tracks totaling about 45 minutes or revise the product promise.
- [ ] AUDO-003 — Create menu, world, calm, night, corruption, lunar, disaster, goal, victory, and Doom music states.
- [ ] AUDO-004 — Crossfade by day/night/season/threat without abrupt restarts.
- [ ] AUDO-005 — Create biome, weather, water, fire, season, and corruption ambience.
- [ ] AUDO-006 — Create complete villager, animal, monster, golem, building, tool, combat, tower, projectile, spell, UI, trade, goal, chest, and death cues.
- [ ] AUDO-007 — Route every cue to the intended bus.
- [ ] AUDO-008 — Add master/music/ambience/UI/creature/building/combat controls.
- [ ] AUDO-009 — Persist mute and volume values.
- [ ] AUDO-010 — Add repetition limiting, pitch/volume variation, and voice caps.
- [ ] AUDO-011 — Handle pause, focus loss, background, resume, and audio-device changes.
- [ ] AUDO-012 — Match haptic patterns to placement, invalid action, completion, goals, disasters, and major spells.
- [ ] AUDO-013 — Add reduced/disabled haptics and audio-warning captions.
- [ ] AUDO-014 — Perform headphones, speaker, phone, tablet, and crowded-scene mix reviews.
- [ ] AUDO-015 — Record license/provenance for every audio asset.

**Exit gate:** production audio exists, is mixed/accessibly controlled, and has no missing catalog cue.

## P1 — Saves, profiles, settings, localization, and recovery

- [ ] SAV-001 — Make replacement crash-safe without deleting the only valid destination first.
- [ ] SAV-002 — Keep checksum validation and eight rotating backups.
- [ ] SAV-003 — Add multiple named profiles.
- [ ] SAV-004 — Add multiple manual save slots with metadata and confirmation.
- [ ] SAV-005 — Add configurable autosave.
- [ ] SAV-006 — Save before region transition, mode reset, background, and suspend.
- [ ] SAV-007 — Recover the newest valid backup and clearly notify the player.
- [ ] SAV-008 — Persist every queue, reservation, RNG, cooldown, event, goal, perk, statistic, and regional transfer.
- [ ] SAV-009 — Store generated blueprints permanently after first generation.
- [ ] SAV-010 — Add migration fixtures for every released schema.
- [ ] SAV-011 — Test interrupted write, corrupt primary, corrupt backup, and disk-full handling.
- [ ] SAV-012 — Add a complete settings screen.
- [ ] SAV-013 — Apply and persist every settings value.
- [ ] SAV-014 — Move player-facing strings out of code/data into localization resources.
- [ ] SAV-015 — Add locale selection, fallback, pluralization, long-text, and missing-key tests.
- [ ] SAV-016 — Test save compatibility after content renames/removals.
- [ ] SAV-017 — Test background/resume on physical iOS devices without lost progress or burst simulation.

**Exit gate:** profiles and settings survive all supported failures/updates and every player-facing string is localizable.

## P1 — Procedural generation, automated QA, soak, and device performance

- [ ] QA-001 — Validate buildable Camp area and accessible wood, rock, crystal, food, and water.
- [ ] QA-002 — Validate critical land connectivity and intentional islands.
- [ ] QA-003 — Validate corruption/monster routes and defensive viability.
- [ ] QA-004 — Validate animal habitats and starting-state compatibility.
- [ ] QA-005 — Validate overlaps, density, coast ratios, chokepoints, and visual-noise limits.
- [ ] QA-006 — Keep the 64-attempt cap and add curated biome/difficulty fallbacks.
- [ ] QA-007 — Test 10,000 deterministic seeds per biome/difficulty combination.
- [ ] QA-008 — Store seed reports and curated visual galleries.
- [ ] QA-009 — Add content completeness tests for every ID/tier/branch/recipe/state.
- [ ] QA-010 — Add public-command normal-play tests for every profession/building/spell.
- [ ] QA-011 — Add save round trips for every authoritative state.
- [ ] QA-012 — Add economy conservation and reservation-failure tests.
- [ ] QA-013 — Add complete combat/damage/status/tower tests.
- [ ] QA-014 — Add all six mode timing/balance scenarios.
- [ ] QA-015 — Add every event, disaster, migration, courier, ghost, resurrection, Doom, and editor golden scenario.
- [ ] QA-016 — Add visual tests for missing frames, pivots, footprints, tiers, damage, corruption, and safe areas.
- [ ] QA-017 — Add audio catalog, bus, voice-limit, and background tests.
- [ ] QA-018 — Run a simulated 30-day mixed settlement soak.
- [ ] QA-019 — Stress 300 villagers, 600 monsters, 200 other agents, and 2,000 structures/segments.
- [ ] QA-020 — Measure camera/zoom, heavy combat, weather, save, load, and path invalidation.
- [ ] QA-021 — Keep peak memory below 1.2 GB on each reference device.
- [ ] QA-022 — Run a 45-minute thermal/battery soak on iPhone and iPad.
- [ ] QA-023 — Prove stable 10 Hz simulation and 30 FPS presentation on both reference devices.
- [ ] QA-024 — Run complete manual golden scenarios from fresh profiles without debug edits.
- [ ] QA-025 — Keep logs, captures, hashes, seeds, save fixtures, and device reports as release evidence.

**Exit gate:** automated, long-run, visual, and physical-device gates all pass with saved evidence.

## P2 — Clean build, CI, legal, and release

- [ ] REL-001 — Change exports from `all_resources` to an explicit shipping include/exclude policy.
- [ ] REL-002 — Exclude tests, tools, logs, captures, reference/rejected art, debug data, and local saves.
- [ ] REL-003 — Add automated checks that reject forbidden packaged files.
- [ ] REL-004 — Produce a clean Windows release candidate.
- [ ] REL-005 — Smoke-test the exported Windows executable in a clean user directory.
- [ ] REL-006 — Produce an unsigned iOS IPA from the supported macOS pipeline.
- [ ] REL-007 — Complete owner-controlled signing, provisioning, and device install.
- [ ] REL-008 — Add CI for JSON/content validation, tests, replay, generation, assets, and Windows build.
- [ ] REL-009 — Validate the added macOS unsigned-iOS workflow with a successful GitHub Actions run and retained IPA/log artifacts.
- [x] REL-010 — Pin the workflow and export tooling to Godot 4.7 stable; document future upgrade checks before changing it.
- [ ] REL-011 — Add license, privacy policy, credits, and complete asset provenance.
- [ ] REL-012 — Confirm no reference pixels, audio, fonts, source, or decompiled data ship.
- [ ] REL-013 — Complete final title/branding and legal review.
- [ ] REL-014 — Complete App Store icons, screenshots, metadata, privacy declarations, and age rating.
- [ ] REL-015 — Verify offline behavior with no ads, IAP, accounts, analytics, servers, DRM, or multiplayer.
- [ ] REL-016 — Run fresh-install, upgrade, background, storage-pressure, and uninstall/reinstall tests.
- [ ] REL-017 — Tag a reproducible release commit only after every release gate passes.

**Exit gate:** clean Windows and iOS release candidates are reproducible, legally documented, device-tested, and contain only shipping assets.

## Final definition of complete

- [ ] FIN-001 — Every shippable parity record is confirmed or explicitly adapted.
- [ ] FIN-002 — Every current Update 2d content item is implemented and normally reachable.
- [ ] FIN-003 — Every profession completes all confirmed tasks without deadlock.
- [ ] FIN-004 — Every building has complete behavior, tiers, and approved visual states.
- [ ] FIN-005 — Every achievement, perk, chest, tutorial, and statistic is functional.
- [ ] FIN-006 — The exact 45-region campaign supports expansion, loss, reclaim, Doom, save, and resume.
- [ ] FIN-007 — All art and audio is original, approved, and provenance-recorded.
- [ ] FIN-008 — Thirty-day soaks and target-scale stress tests pass.
- [ ] FIN-009 — Physical iPhone/iPad readability, performance, memory, thermal, haptic, audio, and safe-area gates pass.
- [ ] FIN-010 — Clean Windows and signed iOS release candidates pass fresh-install smoke tests.
- [ ] FIN-011 — No known crash, save-corruption, permanent AI stall, or release-blocking defect remains.
- [ ] FIN-012 — The independent closeout audit finds no unsupported completion claim.
