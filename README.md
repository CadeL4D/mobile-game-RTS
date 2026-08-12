# Ruinward

Ruinward is an original, clean-room Godot 4.7 mobile colony-survival game inspired by the systemic density of classic god-game/tower-defense hybrids. It contains no extracted source code, data, art, audio, fonts, or UI from the reference game.

## Current playable build

- Six campaign modes, including a touch-friendly Custom rules screen and permissive Sandbox rules.
- Original illustrated 45-node world map with a validated adjacency graph.
- Deterministic 256×256 region generation with saved blueprints, survival-resource validation, and seeded corruption.
- Touch/mouse pan, pinch/wheel zoom, placement ghosts, searchable construction and god-power drawers, a 25-job workforce drawer, and live entity inspectors.
- Twenty villagers with needs, food/water/rest behavior, global task reservations, water-aware grid pathfinding, stuck recovery, construction, harvesting, and production.
- Early housing, farm, well, storage capacity, harvesting workplaces, recipes, and simulated resource depletion.
- Nightmare/Peaceful mode differences, corruption spread, hostile waves, building attacks, eleven typed tower roles with energy/ammunition/support states, health bars, threat UI, and adaptive danger music.
- Data-driven hostile health, speed, damage, recovery and resistances; spectre wall phasing; fire/infection; armed Rangers and Doggo defense; armor, ammunition and equipment durability.
- Powered Combobulators, manufactured wood/stone/crystal/Cube-E golems, Labor/Holy summons, work and combat roles, degradation, Recombobulator repair, influence maintenance, dispel, and mobile golem inspection.
- Persistent influence and functional targeted powers including healing, harvest, mend, banish, lightning, meteor/comet, conjuring, construction, land motivation, dissolve, and resurrection.
- Update 2 faith loop: Occultist prayer, three-essence output, three-energy conversion, ghosts, Eerie Vessels, Reliquary binding, and resurrection.
- All 113 current official Steam achievement names/descriptions loaded as an offline catalog, with persistent counters and initial automated rule bindings.
- Checksummed atomic saves, eight backups, schema migration, saved RNG/task/blueprint/combat/divine state, and offline progression.
- Strict 90-degree top-down, native 8-pixel world rendering for terrain, all current building families and tiers, actors, job/tool layers, resources, events, spells, and world objects. The 455-record clean-room sprite ledger is test-enforced; 451 shipping records have an original first pass and remain in visual review.
- Native 20/24-pixel mobile icons for every building, job, resource, god power, event, and interface family. Earlier generated Camp/Farm/Pen/Combobulator/Clinic concepts are explicitly non-shipping and are not used at runtime.
- Original runtime-synthesized UI/build/goal cues and calm/danger/corruption music layers, plus a 16-track production catalog.

This is an active production build, not the completed release. Many advanced buildings, creatures, events, goals, upgrades, art states, and late-game mechanics are cataloged but still require implementation and parity verification.

## Run

Open this folder in Godot 4.7 and press F6/F5, or run:

```powershell
& 'C:\Users\cadel\Documents\Godot\Godot_v4.7-stable_win64.exe' --path .
```

## Automated verification

```powershell
& 'C:\Users\cadel\Documents\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --quit-after 3000 -- --run-tests
```

The suite covers content counts/references, all 455 sprite-ledger records, native icon/renderer coverage, generator determinism, survival validation, water-safe pathfinding, task reservation, early economy, mode-specific threats, tower ammunition/support states, golem production/degradation/repair/summon/dispel, spell costs/effects, faith/ghost/resurrection flow, official achievement progress, save round trips, and legacy schema migration.

## Architecture

- `core/`: deterministic simulation, pathfinding, generation, saves, progression, commands, and services.
- `content/data/`: versioned and validated content definitions.
- `presentation/`: touch/desktop UI, input, world rendering, and capture-driven visual QA.
- `art/`: original generated assets, unmodified sources, and provenance manifests.
- `audio/`: original audio-production documentation and catalog.
- `tests/`: headless content, generator, simulation, progression, and save tests.

Runtime-uncertain parity entries remain explicitly marked in `content/data/parity_ledger.json`; placeholder wiki values are not treated as authoritative.
