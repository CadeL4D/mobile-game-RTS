# Ruinward

Ruinward is an original, clean-room Godot 4.7 mobile colony-survival game inspired by the systemic density of classic god-game/tower-defense hybrids. It contains no extracted source code, data, art, audio, fonts, or UI from the reference game.

## Current playable build

- Six campaign modes, including a touch-friendly Custom rules screen and permissive Sandbox rules.
- Touch-first regional logistics with Way Station/Courier Station gating, selectable migrant counts, selectable stored-resource cargo and quantities, live transfer summaries, loss refunds, and multi-resource conservation tests.
- Original illustrated 45-node world map with a validated adjacency graph.
- Deterministic 256×256 region generation with versioned three-band elevation, level-foundation validation, saved blueprints, survival-resource validation, and seeded corruption.
- Touch/mouse pan, pinch/wheel zoom, placement ghosts, searchable construction and god-power drawers, a 25-job workforce drawer, and live entity inspectors.
- Twenty villagers with needs, food/water/rest behavior, global task reservations, water-aware grid pathfinding, stuck recovery, construction, harvesting, and production.
- Early housing, farm, well, storage capacity, harvesting workplaces, recipes, and simulated resource depletion.
- Nightmare/Peaceful mode differences, corruption spread, hostile waves, building attacks, eleven typed tower roles with energy/ammunition/support states, health bars, threat UI, and adaptive danger music.
- Data-driven hostile health, speed, damage, recovery and resistances; spectre wall phasing; fire/infection; armed Rangers and Doggo defense; armor, ammunition and equipment durability.
- Faction-aware routing: settlement walls block hostile paths, corrupted walls block friendly paths, normal roads benefit both sides, corrupted roads attract and accelerate only hostile actors, and both graphs rebuild after construction, destruction, thaw, and save/load.
- Powered Combobulators, manufactured wood/stone/crystal/Cube-E golems, Labor/Holy summons, work and combat roles, degradation, Recombobulator repair, influence maintenance, dispel, and mobile golem inspection.
- Persistent influence and a fully functional 32-power catalog: healing/harvest/repair, Charm and Cold Aura combat statuses, destructive Earthquake aftermath, Illuminate fields, nomad Recall, summoned Storms, maintained God Walls/Towers, safe maintenance release through dispel, divine Hand interactions, golem summons, and the remaining targeted powers.
- Update 2 faith loop: Occultist prayer, three-essence output, three-energy conversion, ghosts, Eerie Vessels, Reliquary binding, and resurrection.
- Divine Hand and Cullis Gate loop: authoritative carried actors/resources, safe release, typed sacrifices, instability lightning, destructive overload quakes, save/load, and official child/Doofy achievement hooks.
- Six deterministic buried magic circles per region, physical suspicious keys and loot boxes, Hand/key opening, Hand-poke relocation, automatic Organizer and Doggo opening, weighted perk-aware rewards, overflow drops, and official loot achievements.
- All 113 current official Steam achievement names/descriptions loaded as an offline Goal Web, each with a persistent executable rule binding and deterministic scenario coverage.
- Checksummed atomic saves, eight backups, schema migration, saved RNG/task/blueprint/combat/divine state, and offline progression.
- Strict 90-degree top-down, native 8-pixel world rendering for terrain, all current building families and tiers, actors, job/tool layers, resources, events, spells, and world objects. The 482-record clean-room sprite ledger is test-enforced (478 shipping records plus four historical removals); every shipping record has an original first pass and remains in visual review.
- Terrain streams an immediate calm overview followed by camera-prioritized 32×32-cell detailed chunks. Native deterministic `FastNoiseLite` fields drive six uniform material samples per cell while keeping chunk seams exact; an avalanche-mixed coordinate hash handles sparse native-pixel accents without the former equation-driven rings. Living wood/common stone are integrated into connected canopy/bedrock rather than repeated node sprites, tree-sized disconnected forest components dissolve into meadow while broad cardinally connected masses retain canopy, and completed terrain work rebuilds only affected chunks.
- Deterministic nomad waves include ordinary villagers, Catjeet groups, and rare Nephilim; housing upgrades split into High Quality and High Occupancy branches; Ice Ballista, Lightning Rod spell redirection, animal ghosts, and Doggo resurrection are authoritative and saved.
- Ranger Lodges now scale through their documented 6/12/16 Ranger staffing and lodging progression, while Rangers do not staff Outposts. Established Lodges and final-tier Outposts activate compact bow emplacements that consume Bowyer-made bolt stacks; both special roles have deterministic tests and distinct overhead mechanisms.
- Winter deep water becomes saved traversable ice with route/movement penalties and safe shore recovery on thaw. Highland/ridge bands add restrained strict-overhead geological rims, affect route weights, prevent uneven building foundations, and are editable in local `.rtrmap` packages.
- Touch/mouse Maintainer terrain brushes for clearing resources, digging persistent holes, filling holes, and restoring mud/flood/ash, with saved task progress, durable shovels, mobile-readable designations, and terrain-cache refresh after completed clearing.
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

The suite covers all 741 validated content entries and 482 sprite-ledger records, all 113 executable official-goal bindings, native icon/renderer coverage, generator/elevation determinism, level foundations, connected-canopy filtering, winter ice/thaw routing, survival validation, task reservation, early economy, mode-specific threats, towers, maintained God structures, every spell's authoritative effect, faith/ghost/Doggo resurrection, Hand/Cullis sacrifices, magic circles/keys/loot boxes, housing branches, nomad species, deterministic save round trips, and legacy schema migration.

## Architecture

- `core/`: deterministic simulation, pathfinding, generation, saves, progression, commands, and services.
- `content/data/`: versioned and validated content definitions.
- `presentation/`: touch/desktop UI, input, world rendering, and capture-driven visual QA.
- `art/`: original generated assets, unmodified sources, and provenance manifests.
- `audio/`: original audio-production documentation and catalog.
- `tests/`: headless content, generator, simulation, progression, and save tests.

Runtime-uncertain parity entries remain explicitly marked in `content/data/parity_ledger.json`; placeholder wiki values are not treated as authoritative.
