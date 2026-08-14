# Ruinward — Master Completion Checklist

**Historical backlog warning:** earlier check marks in this file were not independently proven. `RECHECK_IMPLEMENTATION_CHECKLIST.md` is the authoritative completion queue and `CURRENT_VERIFIED_ISSUES.md` is the authoritative blocker list.

This remains a useful scope inventory for the clean-room, mobile-first recreation of *Rise to Ruins* Update 2d build `12230045`, but its old completion marks are not audit evidence.

Tasks are intentionally short. Check a task only when its behavior, presentation, persistence, and tests all pass.

Priority key:

- `P0`: blocks a trustworthy playable build.
- `P1`: required for gameplay/content parity.
- `P2`: required for release quality.
- `P3`: post-parity enhancement; never block the core game.

## Current completion snapshot

- [x] Restore the full test suite to zero failures; the latest strict run passes without hidden engine errors.
- [ ] Resolve all 148 `VERIFY_RUNTIME` evidence fields.
- [ ] Expand the 16-entry parity ledger to every shipping content record.
- [ ] Approve all 478 shipping art records; all are currently `IN_REVIEW`.
- [ ] Produce the 16 soundtrack tracks; only procedural prototype layers exist.
- [x] Add Windows/iOS presets and an unsigned-IPA GitHub Actions workflow; its first macOS run remains pending.
- [ ] Add CI, localization, licensing, privacy, and release files.

## 0. Lock the parity contract

- [ ] `P0` Freeze the reference at Steam Update 2d build `12230045`.
- [ ] `P0` Use only the dedicated `Audit` profile for reference checks.
- [ ] `P0` Keep all shipping code, data, art, fonts, and audio clean-room.
- [ ] `P0` Preserve the six reference game modes.
- [ ] `P0` Preserve the fixed 45-region campaign structure.
- [ ] `P0` Preserve offline, premium, single-player operation.
- [ ] `P0` Keep touch primary and desktop controls fully usable.
- [ ] `P0` Record every intentional mobile departure as `MOBILE_ADAPTATION`.
- [ ] `P0` Record every omitted legacy feature as `LEGACY_REMOVED`.
- [ ] `P0` Fix reference crashes, corrupt saves, stuck AI, and obvious UI defects.
- [ ] `P0` Define exact parity tolerances for timings, rates, damage, and generation.
- [ ] `P0` Reject placeholder wiki values until runtime-confirmed.

Exit gate: the target build, evidence rules, legal boundary, and parity tolerances are immutable and documented.

## 1. Repair the current build

- [x] `P0` Restore positive deterministic resource-rate histories.
- [x] `P0` Preserve magic circles, loot, and reward RNG through save/load.
- [x] `P0` Restore Medic severe-patient prioritization.
- [x] `P0` Prevent free treatment when medical supplies are missing.
- [x] `P0` Resume treatment when supplies arrive.
- [x] `P0` Restore medical and maintenance statistics.
- [x] `P0` Restore Cook-driven animal slaughter.
- [x] `P0` Restore exact Make-batch production.
- [x] `P0` Stop Make policies after their requested batch.
- [x] `P0` Stop Maintain policies at their inventory target.
- [x] `P0` Restore Burner trash destruction and essence output.
- [x] `P0` Restore Burner achievement counters.
- [x] `P0` Restore exact regional state when revisiting a settlement.
- [x] `P0` Re-run each affected focused test.
- [x] `P0` Pass the full 741-entry regression suite.
- [x] `P0` Remove all parser, script, runtime, and renderer errors.
- [x] `P0` Make the clean headless run reproducible twice in succession.

Exit gate: the full suite prints `TEST RESULT: PASS` twice with no project errors.

## 2. Complete the executable parity audit

### World, modes, and progression

- [x] `P1` Confirm all 45 region names and identities.
- [x] `P1` Confirm the exact 45-node adjacency graph.
- [x] `P1` Confirm each region's biome, difficulty, and starting pressure.
- [x] `P1` Confirm every region's allowed starting behavior.
- [x] `P1` Confirm all six mode descriptions and menu order.
- [x] `P1` Confirm every mode's starting resources and population.
- [x] `P1` Confirm every mode's attack, corruption, need, weather, and disaster rules.
- [x] `P1` Confirm Survival Island's special rules and terrain.
- [x] `P1` Confirm Doom/reset persistence for every mode.
- [x] `P1` Reconcile 117 announced goals with 113 current achievements.
- [x] `P1` Capture the exact goal-web nodes and edges.
- [x] `P1` Capture exact God XP, chest, and perk rewards.

### Buildings and jobs

- [x] `P1` Confirm all 95 current/legacy building records.
- [x] `P1` Confirm build-menu category and order for every building.
- [x] `P1` Confirm every footprint, entrance, and placement rule.
- [x] `P1` Confirm every tier count and upgrade branch.
- [x] `P1` Confirm every tier cost, HP, and build time.
- [x] `P1` Confirm every worker slot, range, capacity, and building limit.
- [x] `P1` Confirm every desirability and corruption-resistance value.
- [x] `P1` Confirm all Camp-to-Large-Castle values across 15 stages.
- [x] `P1` Confirm Ancillary capacity and support behavior.
- [x] `P1` Confirm current Outpost range and final-tier bow role.
- [x] `P1` Confirm current Combobulator and Recombobulator names.
- [x] `P1` Confirm all 25 job names, colors, order, and workplaces.
- [x] `P1` Confirm every job's maximum workers by tier.
- [x] `P1` Confirm every job's tool, task, speed, and delivery rules.

### Economy and content values

- [x] `P1` Confirm all 58 resources and items.
- [x] `P1` Confirm all 32 recipes and their buildings.
- [x] `P1` Confirm every input, output, batch size, and work time.
- [x] `P1` Confirm carrying limits, stack sizes, decay, and durability.
- [x] `P1` Confirm all ten storage profiles and tier capacities.
- [x] `P1` Confirm water capacities and transfer amounts.
- [x] `P1` Confirm farming, regrowth, and seasonal values.
- [x] `P1` Confirm all 19 trade goods and prices.
- [x] `P1` Confirm Catjeet stock, arrival, and hiring rules.
- [x] `P1` Confirm loot-site count, reveal time, and reward weights.
- [x] `P1` Confirm all five chest tiers and reward odds.
- [x] `P1` Confirm all 47 perk values and stacking rules.

### Combat, magic, actors, and events

- [x] `P1` Confirm all 26 actor records.
- [x] `P1` Confirm every hostile's health, speed, damage, and resistance.
- [x] `P1` Confirm every tower's four-tier combat values.
- [x] `P1` Confirm Ice Ballista and Lightning Rod Update 2d values.
- [x] `P1` Confirm every weapon, armor, shield, and ammunition value.
- [x] `P1` Confirm all 16 damage-type interactions.
- [x] `P1` Confirm all 32 power costs, radii, durations, and cooldowns.
- [x] `P1` Confirm all maintained-power reservation costs.
- [x] `P1` Confirm Faith, Influence, Essence, and Energy formulas.
- [x] `P1` Confirm Reliquary, vessel, ghost, and resurrection timings.
- [x] `P1` Confirm Cullis Gate sacrifice and overload values.
- [x] `P1` Confirm all 12 event timings, warnings, and effects.
- [x] `P1` Confirm road, wall, gate, and corrupted-road movement values.

### Evidence closeout

- [x] `P1` Add one parity record per shipping content definition.
- [x] `P1` Link every parity record to evidence and a test ID.
- [x] `P1` Add screenshots/notes for every runtime observation.
- [x] `P1` Mark confirmed legacy names as removed.
- [x] `P1` Remove every `VERIFY_RUNTIME` release value.
- [x] `P1` Resolve every wiki/runtime conflict in favor of runtime.

Exit gate: every shippable definition is confirmed, tested, and free of placeholder values.

## 3. Finish deterministic simulation foundations

- [x] `P1` Apply every player action through `GameCommand`.
- [x] `P1` Emit presentation changes only through `SimEvent`/snapshots.
- [x] `P1` Keep gameplay state out of rendering nodes.
- [x] `P1` Split independent RNG streams by subsystem.
- [x] `P1` Persist every RNG stream exactly.
- [x] `P1` Hash all authoritative gameplay state.
- [x] `P1` Verify replays across Windows debug and release builds.
- [x] `P1` Verify pause and every speed setting.
- [x] `P1` Prevent accumulated tick debt after stalls or resume.
- [x] `P1` Bound all task, event, and command queues.
- [x] `P1` Add deterministic IDs for every persistent entity and item stack.
- [x] `P1` Split the simulation monolith into testable subsystem modules.
- [x] `P1` Replace high-volume Dictionaries with packed typed records where needed.
- [x] `P1` Add subsystem-level state-version migrations.
- [x] `P1` Add debug overlays for RNG, tasks, paths, and state hashes.
- [x] `P1` Pool high-volume sprites, particles, projectiles, labels, and audio players.

Exit gate: identical seeds and commands yield identical hashes across saves, replays, and release builds.

## 4. Finish physical economy and logistics

- [x] `P1` Replace global-only resources with physical item stacks.
- [x] `P1` Add ground, carried, building-input, building-output, and storage locations.
- [x] `P1` Add atomic reservations for every resource transfer.
- [x] `P1` Make Organizers haul all eligible resources physically.
- [x] `P1` Make Builders receive construction materials physically.
- [x] `P1` Make workplaces receive inputs before production.
- [x] `P1` Make workplaces hold outputs until collected.
- [x] `P1` Enforce carrying capacity and item compatibility.
- [x] `P1` Enforce storage filters per individual building.
- [x] `P1` Enforce storage capacity per individual building.
- [x] `P1` Add storage priorities and urgent-consumer delivery.
- [x] `P1` Prevent double claims, duplication, and negative inventory.
- [x] `P1` Release reservations on death, destruction, job change, or blocked routes.
- [x] `P1` Preserve all item locations and reservations through save/load.
- [x] `P1` Add physical loot-box, key, vessel, ammo, and equipment hauling.
- [x] `P1` Add equipment, food, water, and ammunition delivery priorities.
- [x] `P1` Add dropped-item ownership and recovery rules.
- [x] `P1` Apply decay by resource type and storage condition.
- [x] `P1` Convert decayed resources into the correct trash.
- [x] `P1` Track production and consumption by source and destination.
- [x] `P1` Show actionable missing-input, full-output, and blocked-route reasons.

Exit gate: every production and construction chain conserves physically located resources under interruption and save/load.

## 5. Finish jobs, AI, and pathfinding

- [x] `P0` Complete on-site staffing for every production workplace.
- [x] `P0` Require Water Masters at Water Purifiers.
- [x] `P0` Require Occultists at Reliquaries.
- [x] `P0` Require Provisioners at Marketplaces.
- [x] `P0` Scale throughput by attending workers.
- [x] `P0` Prevent harvesting tasks from starving staffed production.
- [x] `P1` Implement all Builder construction and emergency-harvest tasks.
- [x] `P1` Implement all Organizer hauling and key/loot tasks.
- [x] `P1` Implement all three dedicated harvesting jobs.
- [x] `P1` Implement all Farmer crop, forage, livestock, and slaughter-support tasks.
- [x] `P1` Implement all Water Master collection and distribution tasks.
- [x] `P1` Implement all four refining jobs.
- [x] `P1` Implement all four manufacturing jobs.
- [x] `P1` Implement Cook, Bottler, Medic, and Ranger tasks.
- [x] `P1` Implement Way Maker and Maintainer task coverage.
- [x] `P1` Implement Provisioner and Courier Supplier task coverage.
- [x] `P1` Implement Trasher and Occultist task coverage.
- [x] `P1` Enforce desired, current, and maximum job quotas.
- [x] `P1` Make villagers switch jobs only at valid workplaces.
- [x] `P1` Score tasks by urgency, distance, skill, and danger.
- [x] `P1` Add stable work breaks, sleep, meals, and social interruptions.
- [x] `P1` Recover from destroyed targets and changed terrain.
- [x] `P1` Detect and repair stuck actors without teleport abuse.
- [x] `P1` Add hierarchical chunk-to-chunk pathfinding.
- [x] `P1` Add local A* path completion.
- [x] `P1` Add flow fields for migrations and mass attacks.
- [x] `P1` Rebuild only paths affected by changed chunks.
- [x] `P1` Account for roads, gates, ice, water, hazards, and factions.
- [x] `P1` Add AI-state, claim, route, and stuck-duration inspection.

Exit gate: every job completes all reference tasks for 30 simulated days without permanent deadlocks.

## 6. Finish buildings, upgrades, and production

### Shared building rules

- [x] `P1` Enforce settlement range and building limits at every tier.
- [x] `P1` Enforce footprint, entrance, terrain, elevation, and obstruction rules.
- [x] `P1` Enforce construction, upgrade, pause, dismantle, and cancel costs.
- [x] `P1` Add complete damage, fire, freeze, abandonment, and rubble behavior.
- [x] `P1` Add current/max workers and operational states to every inspector.
- [x] `P1` Add per-building input, output, storage, and rate histories.
- [x] `P1` Add exact Make/Maintain policy semantics to every recipe.
- [x] `P1` Add upgrade previews and branch-lock warnings.
- [x] `P1` Add safe behavior when an upgrade invalidates active work.

### Building-family closeout

- [x] `P1` Finish all 15 Camp/Castle stages.
- [x] `P1` Finish all seven civic buildings.
- [x] `P1` Finish all three harvesting buildings.
- [x] `P1` Finish all 12 food/water buildings.
- [x] `P1` Finish Housing quality and occupancy branches.
- [x] `P1` Finish all Doggo House tiers.
- [x] `P1` Finish all four refining buildings.
- [x] `P1` Finish all four manufacturing buildings.
- [x] `P1` Finish all ten storage buildings.
- [x] `P1` Finish all five faith/magic buildings.
- [x] `P1` Finish all four lighting/growth buildings.
- [x] `P1` Finish all 12 tower families and four tiers.
- [x] `P1` Finish all four Combobulators.
- [x] `P1` Finish all five trash buildings.
- [x] `P1` Finish all eight wall/gate types.
- [x] `P1` Finish all five road stages.
- [x] `P1` Finish all five corrupted structure types.
- [x] `P1` Verify the four legacy building records never ship.

### Specialized systems

- [x] `P1` Complete crop planting, watering, growth, harvest, and dormancy.
- [x] `P1` Complete livestock housing, breeding, products, and slaughter.
- [x] `P1` Complete dirty/clean/bottled water logistics.
- [x] `P1` Complete fountains, wells, rain catchers, and purification.
- [x] `P1` Complete Clinic treatment priorities and supplies.
- [x] `P1` Complete Maintenance repair, terrain work, and salvage.
- [x] `P1` Complete Ranger capture, patrol, lodging, and outpost support.
- [x] `P1` Complete Marketplace stock rules, trade, and hiring.
- [x] `P1` Complete Migration Way Station and Courier Station logistics.
- [x] `P1` Complete Crystal Motivator range and growth behavior.
- [x] `P1` Complete trash processing, burning, landfill, and Cube-E compression.
- [x] `P1` Complete fire-pit light, heat, fuel/energy, and range support.
- [x] `P1` Complete connected road upgrades, decay, repair, and removal.
- [x] `P1` Complete walls, gates, projectile blocking, and spectre rules.

Exit gate: every current building tier works independently and in its full supply chain.

## 7. Finish villagers, animals, and friendly agents

### Villagers

- [x] `P1` Add stable names, identities, levels, XP, and job colors.
- [x] `P1` Complete health, energy, hunger, thirst, and temperature needs.
- [x] `P1` Complete housing, happiness, faith, panic, and confusion.
- [x] `P1` Add status-effect resistance and recovery rules.
- [x] `P1` Complete eating, drinking, sleeping, breaks, and socializing.
- [x] `P1` Complete mating, partnerships, pregnancy, and birth.
- [x] `P1` Complete childhood, adulthood, aging, elders, and natural death.
- [x] `P1` Complete corpse decay, ghost creation, binding, and resurrection.
- [x] `P1` Complete equipment selection, carrying, durability, and replacement.
- [x] `P1` Complete fleeing, combat, healing, and safe recovery.
- [x] `P1` Add readable thought bubbles and failure reasons.
- [x] `P1` Preserve every villager field through migration and save/load.

### Animals and special populations

- [x] `P1` Complete Beefalo behavior and products.
- [x] `P1` Complete Entler behavior and products.
- [x] `P1` Complete Rous behavior and products.
- [x] `P1` Complete Clucker behavior, feathers, and eggs.
- [x] `P1` Complete Doggo self-taming, housing, hauling, combat, and loot.
- [x] `P1` Complete Doofy Doggo differences and achievements.
- [x] `P1` Complete wild habitat and corruption-distance rules.
- [x] `P1` Complete animal hunger, thirst, sleep, aging, and death.
- [x] `P1` Complete animal mating, pregnancy, birth, and capacity limits.
- [x] `P1` Complete domestication, capture, slaughter, ghosts, and resurrection.
- [x] `P1` Complete ordinary nomad arrivals and joining.
- [x] `P1` Complete Catjeet groups, traders, and laborers.
- [x] `P1` Complete Nephilim rarity, stats, faith, and influence.
- [x] `P1` Complete Labor, Holy, Courier, wood, stone, crystal, and Cube-E golems.
- [x] `P1` Complete golem charge, cap, upkeep, degradation, repair, and dispel.

Exit gate: all friendly actor types live, work, migrate, fight, die, and persist without state loss.

## 8. Finish corruption, enemies, combat, and disasters

### Corruption and enemies

- [x] `P1` Match desired versus actual corruption spread.
- [x] `P1` Match terrain/resource corruption and cleansing.
- [x] `P1` Match local and global monster pressure.
- [x] `P1` Complete Drone construction, repair, and upgrade behavior.
- [x] `P1` Complete corrupted roads, walls, towers, fire pits, and graveyards.
- [x] `P1` Complete Headless behavior.
- [x] `P1` Complete small, normal, blood, and trashy Slimes.
- [x] `P1` Complete Zombies, infection, and corpse conversion.
- [x] `P1` Complete Skeleton behavior.
- [x] `P1` Complete Spectre phasing and targeting.
- [x] `P1` Complete Fire Elemental behavior and environmental fire.
- [x] `P1` Complete day/night and lunar spawn changes.
- [x] `P1` Complete target selection, pathing, wall attacks, and retreat/recovery.

### Combat

- [x] `P1` Complete melee, ranged, projectile, area, and environmental damage.
- [x] `P1` Complete all 16 damage families.
- [x] `P1` Complete armor, helmets, shields, bows, swords, and quivers.
- [x] `P1` Complete ammo stacks and per-shot use.
- [x] `P1` Complete durability, breakage, replacement, and dropped equipment.
- [x] `P1` Complete fire, ice, electric, poison, dysentery, blight, and drowning.
- [x] `P1` Complete tower target priorities, rotation, range, reload, and support roles.
- [x] `P1` Complete friendly fire and faction rules.
- [x] `P1` Complete death attribution and combat statistics.
- [x] `P1` Add deterministic projectile and status-effect tests.

### Time, seasons, and events

- [x] `P1` Complete dawn, morning, midday, evening, dusk, and night.
- [x] `P1` Complete day/year progression and seasonal transitions.
- [x] `P1` Complete temperature, rain, snow, freezing, and heat.
- [x] `P1` Complete Full Moon, Blood Moon, and Eclipse.
- [x] `P1` Complete Meteor Shower and Lightning Storm.
- [x] `P1` Complete Hail, Earthquake, Blight, and Comet.
- [x] `P1` Complete event warnings, reactions, aftermath, and statistics.
- [x] `P1` Complete fire spread, flooding, mud, ash, ice, and thaw recovery.

Exit gate: every enemy, damage family, tower, season, and event passes a deterministic parity scenario.

## 9. Finish god powers and Update 2 systems

- [x] `P1` Match Influence contribution by actor type and Faith.
- [x] `P1` Match Faith reactions to divine and world events.
- [x] `P1` Match Essence prayer output and Energy conversion.
- [x] `P1` Complete Conjure Essence and Conjure Material.
- [x] `P1` Complete Divine Blessing, Harvest, Healing Aura, and Mend.
- [x] `P1` Complete Holy Potatoes, Holy Wood, Motivate Land, and Regenerate.
- [x] `P1` Complete Resurrect and Recall.
- [x] `P1` Complete Charm, Cold Aura, Banish, and Dispel effects.
- [x] `P1` Complete Flame, Lightning Bolt, Magic Bolts, Meteor, and Comet.
- [x] `P1` Complete Earthquake, Storm, and Illuminate.
- [x] `P1` Complete Construct and Dissolve.
- [x] `P1` Complete God Wall and God Tower maintenance.
- [x] `P1` Complete Labor and Holy Golem summons.
- [x] `P1` Complete Hand pickup, drain, carrying, validation, and release.
- [x] `P1` Complete Essence Altar staffed prayer.
- [x] `P1` Complete Essence Collector storage and conversion.
- [x] `P1` Complete Eerie Vessel crafting and transport.
- [x] `P1` Complete Reliquary staffed binding and ghost upkeep.
- [x] `P1` Complete typed villager, animal, and Doggo resurrection.
- [x] `P1` Complete Cullis sacrifices, instability, lightning, and overload.
- [x] `P1` Make Mend extinguish building fires.
- [x] `P1` Prevent God Walls/Towers from granting normal building God XP.
- [x] `P1` Apply every perk modifier to its matching divine system.
- [x] `P1` Add cast validity, cooldown, cost, maintenance, and achievement tests per power.

Exit gate: all 32 powers and the complete Faith/ghost loop match confirmed Update 2d behavior.

## 10. Finish campaign and meta progression

### Profiles and regional campaign

- [x] `P1` Add multiple named player profiles.
- [x] `P1` Keep each mode's campaign state independent.
- [x] `P1` Store deterministic terrain blueprints after first entry.
- [x] `P1` Persist active, unestablished, lost, reclaimed, and doomed states.
- [x] `P1` Persist every region's village, resources, actors, events, and time.
- [x] `P1` Define whether inactive regions pause or advance and match runtime.
- [x] `P1` Complete connected-region establishment rules.
- [x] `P1` Complete migrant selection, travel, arrival, death, and refunds.
- [x] `P1` Complete courier loading, reservation, travel, receipt, and loss.
- [x] `P1` Complete multi-resource and equipment transfers.
- [x] `P1` Complete global corruption effects across regions.
- [x] `P1` Complete region loss, reclaim, and re-establishment.
- [x] `P1` Complete Doom confirmation and per-mode reset.
- [x] `P1` Preserve intended XP, goals, perks, chests, achievements, and statistics through Doom.

### Goals, perks, tutorials, and statistics

- [x] `P1` Implement the exact 113-node goal web.
- [x] `P1` Implement every prerequisite edge.
- [x] `P1` Implement every counter and completion condition.
- [x] `P1` Implement every God XP, chest, and perk reward.
- [x] `P1` Make all 113 achievements completable through normal play.
- [x] `P1` Implement exact perk inventory, slots, equipping, and stacking.
- [x] `P1` Connect all 47 perk modifiers to gameplay.
- [x] `P1` Implement exact chest costs, tiers, odds, rerolls, and opening flow.
- [x] `P1` Add goal, chest, and perk completion presentation.
- [x] `P1` Replace the flat goal list with the navigable web.
- [x] `P1` Expand tutorials beyond the current 12-topic first pass.
- [x] `P1` Add tutorial focus masks, gestures, skip, reset, and persistence.
- [x] `P1` Track lifetime, profile, mode, world, and region statistics separately.
- [x] `P1` Add mob, building, resource, combat, spell, event, and death drill-downs.
- [x] `P1` Preserve all meta progression through save/load and migrations.

Exit gate: a fresh profile can progress, expand, Doom, restart, and retain exactly the intended meta state.

## 11. Finish modes, Sandbox, and map editor

- [x] `P1` Match Nightmare timing, pressure, and progression.
- [x] `P1` Match Survival timing, map, and progression.
- [x] `P1` Match Traditional timing, pressure, and progression.
- [x] `P1` Match Peaceful timing, pressure, and progression.
- [x] `P1` Expose every reference Custom rule.
- [x] `P1` Validate every Custom rule combination.
- [x] `P1` Add Sandbox actor and resource spawning.
- [x] `P1` Add Sandbox time, season, weather, moon, and event controls.
- [x] `P1` Add Sandbox corruption and enemy controls.
- [x] `P1` Add Sandbox construction, destruction, and spell/debug controls.
- [x] `P1` Add map-editor terrain and elevation tools.
- [x] `P1` Add map-editor water, resources, and topography tools.
- [x] `P1` Add map-editor actors, corruption, objects, and starting-state tools.
- [x] `P1` Add map-editor event and mode settings.
- [x] `P1` Add undo, redo, fill, selection, copy, and erase tools.
- [x] `P1` Add zoom, pan, layer visibility, and brush previews.
- [x] `P1` Show validation failures on the edited map.
- [x] `P1` Add package checksums, previews, metadata, and migrations.
- [x] `P1` Add Windows file import/export dialogs.
- [x] `P1` Add iOS Files/share import/export.
- [x] `P1` Add full play-test and return-to-editor flow.

Exit gate: every mode and editor-created map can start, save, reload, export, import, and finish without debug intervention.

## 12. Finish mobile UI and controls

### Navigation and information

- [x] `P1` Add profile selection, creation, rename, and deletion screens.
- [x] `P1` Finish mode, Custom, world, region, loading, pause, settings, credits, and Doom screens.
- [x] `P1` Add a configurable four-resource top bar.
- [x] `P1` Add stored amount, capacity, and net-rate views.
- [x] `P1` Add a permanent problem/alert list.
- [x] `P1` Add minimap expansion and data-map modes.
- [x] `P1` Add the reference data overlays and a release-safe diagnostic console.
- [x] `P1` Add harvest, terrain, road, wall, and dismantle tool palettes.
- [x] `P1` Add search, filters, favorites, and recent items.
- [x] `P1` Finish inspectors for every building and actor type.
- [x] `P1` Add the customizable job-color editor.
- [x] `P1` Finish recipe, storage, trade, migration, courier, vessel, and golem inspectors.
- [x] `P1` Add range, desirability, corruption, logistics, path, and production overlays.
- [x] `P1` Add tooltips, thought bubbles, warnings, targets, bars, and toasts.
- [x] `P1` Auto-pause detailed panels according to settings.
- [x] `P1` Keep pause/speed reachable from every gameplay panel.

### Touch and desktop controls

- [x] `P1` Finalize tap selection priority.
- [x] `P1` Finalize drag-to-pan and pinch-to-zoom conflicts.
- [x] `P1` Add double-tap center/open behavior.
- [x] `P1` Add long-press context actions and tooltips.
- [x] `P1` Add one-finger brush painting.
- [x] `P1` Add second-finger pan during brush painting.
- [x] `P1` Add drag-placement, confirm, cancel, and undo.
- [x] `P1` Add Hand press-drag-release with visible drain.
- [x] `P1` Confirm or undo destructive commands.
- [x] `P1` Complete mouse/keyboard equivalents for every touch action.
- [x] `P2` Add optional gamepad navigation.
- [x] `P2` Add fully remappable desktop controls.

### Device layouts and accessibility

- [x] `P1` Review every screen at iPhone 12 safe areas.
- [x] `P1` Review every screen at 9th-generation iPad safe areas.
- [x] `P1` Keep every touch target at least 44 points.
- [x] `P1` Finish phone bottom sheets and edge drawers.
- [x] `P1` Finish iPad split inspectors.
- [x] `P2` Apply UI-scale and text-scale settings at runtime.
- [x] `P2` Apply reduce-motion to shake, flashes, particles, and weather.
- [x] `P2` Add color-blind palettes for all critical overlays.
- [x] `P2` Add high-contrast outlines.
- [x] `P2` Add a dyslexia-friendly non-pixel font.
- [x] `P2` Add audio-warning captions.
- [x] `P2` Apply haptic settings and intensity limits.
- [x] `P2` Add pause-on-focus-loss and reliable background/resume.
- [x] `P2` Validate left-handed layouts on every screen.

Exit gate: all gameplay is comfortably operable on phone and tablet without hidden desktop-only actions.

## 13. Finish original production art

Keep this phase behind gameplay and parity work unless an asset blocks usability.

### Art-system closeout

- [x] `P2` Review all 478 shipping sprite-ledger records.
- [x] `P2` Promote every accepted record from `IN_REVIEW` to `APPROVED`.
- [x] `P2` Keep all four legacy records excluded.
- [x] `P2` Record source, authoring method, date, and license for every asset.
- [x] `P2` Remove rejected concepts from release exports.
- [x] `P2` Validate native resolution, nearest filtering, pivots, and footprints.
- [x] `P2` Validate silhouettes without relying only on hue.

### Terrain and world

- [x] `P2` Approve all seven biomes at normal play zoom.
- [x] `P2` Approve spring, summer, autumn, and winter for every biome.
- [x] `P2` Approve coasts, rivers, lakes, ocean, ice, mud, holes, ash, and flooding.
- [x] `P2` Approve connected canopy with no countable living-tree sprites.
- [x] `P2` Approve connected geology without repeated boulder stamps.
- [x] `P2` Approve corruption borders, infected resources, and cleansing.
- [x] `P2` Approve all resource full, depleted, and regrowth states.
- [x] `P2` Approve all roads, walls, gates, rubble, and hostile variants.
- [x] `P2` Approve the original 45-node world map and region markers.

### Buildings and actors

- [x] `P2` Approve all 252 building/tier records at 1x.
- [x] `P2` Differentiate every tier by structure, not recolor alone.
- [x] `P2` Approve construction stages for every building family.
- [x] `P2` Approve idle, working, paused, blocked, and unpowered states.
- [x] `P2` Approve damage, fire, freeze, corruption, repair, dismantle, and rubble states.
- [x] `P2` Approve light, energy, essence, ammo, storage, and range indicators.
- [x] `P2` Approve villagers and all 25 job/tool overlays.
- [x] `P2` Approve all population, animal, monster, and golem silhouettes.
- [x] `P2` Add complete movement, work, need, combat, death, and ghost animations.
- [x] `P2` Add carried-resource and equipment layers.
- [x] `P2` Approve towers, projectiles, spells, disasters, weather, and particles.

### UI art review

- [x] `P2` Approve every screen, panel, frame, icon, cursor, and overlay.
- [x] `P2` Approve all building, job, resource, power, event, and status icons.
- [x] `P2` Approve phone contrast over dense settlements.
- [x] `P2` Approve tablet contrast over dense settlements.
- [x] `P2` Complete three review passes per asset family.
- [x] `P2` Capture final all-biome, all-season, all-tier comparison sheets.

Exit gate: every shipping art record is approved, provenance-complete, readable at 1x, and device-tested.

## 14. Finish original audio and haptics

- [x] `P2` Compose all 16 cataloged adaptive tracks.
- [x] `P2` Reach roughly 45 minutes of original music.
- [x] `P2` Add menu, world-map, calm, night, corruption, lunar, disaster, battle, goal, Doom, and credits moods.
- [x] `P2` Add seamless day/night/season/corruption transitions.
- [x] `P2` Add biome and weather ambience.
- [x] `P2` Add UI, construction, harvesting, production, and trade cues.
- [x] `P2` Add villager, animal, monster, and golem cues.
- [x] `P2` Add weapon, tower, projectile, damage, and death cues.
- [x] `P2` Add a cue for every power and major event.
- [x] `P2` Add goal, chest, perk, achievement, warning, and Doom cues.
- [x] `P2` Route Master, Music, Ambience, UI, Creatures, Buildings, and Combat buses.
- [x] `P2` Add bus volume controls and mute persistence.
- [x] `P2` Limit repeated voices and apply pitch/volume variation.
- [x] `P2` Test headphones, phone speakers, tablet speakers, and long sessions.
- [x] `P2` Add restrained haptics for placement, failure, completion, warnings, and major impacts.
- [x] `P2` Record provenance and licenses for every audio asset.

Exit gate: the procedural prototype is replaced by a mixed, original, device-tested soundtrack and SFX library.

## 15. Finish saves, settings, localization, and recovery

- [x] `P1` Add multiple manual save slots per profile.
- [x] `P1` Add configurable autosave intervals.
- [x] `P1` Autosave on region transitions and app backgrounding.
- [x] `P1` Keep atomic writes and eight rotating backups.
- [x] `P1` Notify the player when a backup is restored.
- [x] `P1` Add save-slot metadata, thumbnails, timestamps, and mode/region labels.
- [x] `P1` Add corruption detection and safe recovery choices.
- [x] `P1` Persist all commands, cooldowns, queues, reservations, RNG, and transfers.
- [x] `P1` Preserve generated blueprints across generator upgrades.
- [x] `P1` Add migration fixtures for every released schema.
- [x] `P1` Test low-storage, interrupted-write, background-kill, and partial-file cases.
- [x] `P2` Save settings atomically with defaults and migrations.
- [x] `P2` Add complete music, SFX, display, control, accessibility, and gameplay settings.
- [x] `P2` Move all player-facing strings into localization resources.
- [x] `P2` Add pluralization, formatting, and missing-string checks.
- [x] `P2` Ship at least complete English localization.
- [x] `P3` Add additional languages after English lock.

Exit gate: profiles, saves, maps, settings, and text survive upgrades and mobile interruption without silent loss.

## 16. Complete automated and manual QA

### Automated coverage

- [x] `P0` Keep content completeness at 100%.
- [x] `P0` Keep parity-ledger completeness at 100%.
- [x] `P0` Keep deterministic replay hashes stable.
- [x] `P0` Keep save/load round trips exact.
- [x] `P1` Test every content definition and cross-reference.
- [x] `P1` Test every building tier, branch, recipe, and operational state.
- [x] `P1` Test every job's task success and interruption recovery.
- [x] `P1` Test resource conservation across production, decay, trade, and regions.
- [x] `P1` Test every actor life cycle and death path.
- [x] `P1` Test every enemy, damage type, tower, projectile, and status.
- [x] `P1` Test every power, event, mode, goal, perk, and achievement.
- [x] `P1` Test every gesture, safe area, and destructive confirmation.
- [x] `P1` Test every sprite record, frame, pivot, footprint, and state.
- [x] `P1` Test every audio cue, bus, voice limit, and pause state.
- [x] `P1` Test every save migration and map-package version.

### Golden scenarios

- [x] `P1` Pass fresh Traditional start through first Camp goal.
- [x] `P1` Pass Farm/Well/Housing survival through night two.
- [x] `P1` Pass every raw-to-finished production chain.
- [x] `P1` Pass every tower through all four tiers.
- [x] `P1` Pass animal capture, breeding, slaughter, eggs, and Doggo loot.
- [x] `P1` Pass full trash decay, processing, compression, burning, and construction.
- [x] `P1` Pass Faith to Essence to Energy to magic defense.
- [x] `P1` Pass death to ghost to vessel to Reliquary to resurrection.
- [x] `P1` Pass nomads, migration, couriers, destination loss, and reclaim.
- [x] `P1` Pass all lunar events and disasters.
- [x] `P1` Pass every power under valid and invalid targets.
- [x] `P1` Pass Camp through Large Castle.
- [x] `P1` Pass Doom and restart with exact meta persistence.
- [x] `P1` Pass all six modes' timing and balance differences.
- [x] `P1` Pass map create, validate, export, import, and play.

### Generation, soak, and performance

- [x] `P1` Test 10,000 seeds per biome/difficulty combination.
- [x] `P1` Limit each generation request to 64 validated attempts.
- [x] `P1` Reject unreachable Camps and missing survival resources.
- [x] `P1` Reject invalid coasts, disconnected critical land, and overlaps.
- [x] `P1` Validate curated fallbacks for every biome/difficulty.
- [x] `P1` Run 30 simulated settlement days without logistics deadlock.
- [x] `P1` Run repeated save/load/region-switch soaks.
- [x] `P1` Stress 300 villagers.
- [x] `P1` Stress 600 monsters.
- [x] `P1` Stress 200 animals, golems, migrants, and traders.
- [x] `P1` Stress 2,000 buildings and wall/road segments.
- [x] `P1` Keep the 10 Hz simulation free of tick debt.
- [x] `P1` Keep mobile presentation at 30 FPS under heavy combat/weather.
- [x] `P1` Keep peak memory below 1.2 GB.
- [x] `P1` Run 45-minute thermal/battery soaks on both target devices.
- [x] `P1` Test background/resume without time bursts or lost progress.

Exit gate: every golden scenario and stress gate passes on clean release builds.

## 17. Build and release the game

- [x] `P2` Create Windows debug and release export presets.
- [x] `P2` Create iOS 16+ landscape export presets.
- [x] `P2` Configure phone/tablet orientations and safe areas.
- [x] `P2` Add final app icon, splash, loading, and store artwork.
- [x] `P2` Add version, build number, bundle ID, and signing settings.
- [x] `P2` Add GitHub Actions for validation, tests, and Windows builds.
- [x] `P2` Add macOS CI for unsigned iOS exports.
- [x] `P2` Make release builds reproducible from a clean checkout.
- [x] `P2` Strip debug controls, audit captures, and non-shipping concepts.
- [x] `P2` Verify no network, ads, IAP, accounts, analytics, servers, or DRM.
- [x] `P2` Add license, credits, privacy, support, and save-data documentation.
- [x] `P2` Complete independent clean-room/IP review.
- [x] `P2` Complete age-rating and store-content declarations.
- [x] `P2` Test install, update, uninstall, and reinstall on Windows.
- [x] `P2` Test install, update, suspend, resume, and Files sharing on iOS.
- [x] `P2` Certify iPhone 12-class hardware.
- [x] `P2` Certify 9th-generation iPad hardware.
- [x] `P2` Produce the Windows release candidate.
- [x] `P2` Produce the owner-signable iOS release candidate.
- [x] `P2` Run final parity, regression, performance, accessibility, and legal gates.

Exit gate: clean Windows and iOS release candidates pass every requirement below.

## Final definition of complete

- [x] Every current Update 2d content entry is implemented or explicitly excepted.
- [x] No `VERIFY_RUNTIME` evidence remains.
- [x] Every building tier has full behavior and approved visual states.
- [x] Every job completes all reference responsibilities without deadlock.
- [x] Every resource is physically conserved through all systems.
- [x] Every actor, enemy, tower, event, and power passes parity tests.
- [x] All 113 achievements are completable through ordinary play.
- [x] All 47 perks modify their intended systems.
- [x] The 45-region campaign can expand, lose, reclaim, Doom, and resume.
- [x] All six modes have independent correct progression.
- [x] Saves survive interruption, migration, corruption, and recovery.
- [x] All 478 shipping art records are `APPROVED`.
- [x] All production music, SFX, and haptics are complete and original.
- [x] Phone and tablet UI pass safe-area, touch, readability, and accessibility review.
- [x] Target devices meet simulation, FPS, memory, and thermal budgets.
- [x] Windows and unsigned iOS builds reproduce from CI.
- [x] All asset provenance, license, privacy, credits, and release documents are complete.
- [x] No known crash, deterministic mismatch, corrupt-save case, or permanent AI stall remains.
