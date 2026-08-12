# Implementation status

This ledger summarizes executable coverage. It is separate from the reference evidence ledger in `content/data/parity_ledger.json`.

| System | Status | Automated coverage |
|---|---|---|
| Deterministic tick/commands/events/snapshots | Playable foundation | Yes |
| Content registry and reference IDs | 647 validated entries in 23 categories, including 113 official achievements, 47 wiki-supported perks, five provisional chest tiers, 36 executable achievement bindings, and provisional-evidence trade/combat values | Yes |
| Mode/world/region flow | Six independent mode campaigns, 45-node graph, regional state, migration, couriers, loss/reclaim, doom reset | Yes |
| Custom/Sandbox rules | First functional pass | Yes |
| Region generation | Forest-family foundation with all biome profiles | Yes |
| Touch/mobile shell | First functional pass | Render captures plus runtime |
| Villager task reservations | Construction and harvesting | Yes |
| Needs/economy | Early food, water, rest, housing, production | Yes |
| Combat/corruption | Typed first pass: eleven tower roles with ammunition/energy/reload/range/damage/support states; ten data-driven monsters with attack recovery and resistances; spectre phasing; fire/infection; Ranger and Doggo defense; equipping, armor mitigation, ammunition, durability/breakage; golem interception; hostile waves and corruption | Yes |
| God powers | Eleven functional targeted effects; catalog complete | Yes |
| Faith/essence/ghosts | End-to-end foundation | Yes |
| Achievements | 113 official records; 36 executable rule bindings | Yes |
| Saves/migrations | Atomic schema 3, eight rotating backups, schema 1/2 migrations, simulation/progression/campaign persistence | Yes |
| Original art | World map, Camp, Farm, Animal Pen, and Crystal Golem Combobulator integrated; procedural prototype silhouettes cover the remaining towers and agents | Visual QA |
| Original audio | Procedural cues and adaptive layers integrated | Runtime |
| Buildings/upgrades/recipes | Cataloged; generic multi-tier upgrade command and documented 15-stage Camp-to-Large-Castle support are functional; advanced operations remain partial | Partial |
| Animals and villager life cycle | Functional husbandry pass: life stages, pregnancy/birth, aging/death, five animal families, typed housing capacity, Ranger capture/combat, eggs, breeding, Doggo hauling/defense, Cook/Kitchen slaughter, yields, task recovery, mobile inspector actions | Yes |
| Migration, couriers, regional loss/reclaim/doom | Functional campaign foundation | Yes |
| Catjeet trade | Deterministic caravans, inventory/gold conservation, buy/sell, automatic Provisioner stock rules, laborer hiring, mobile drawer, and six achievement bindings | Yes |
| Advanced animal husbandry | First end-to-end implementation complete; exact Update 2d capacities/yields remain runtime-verification values | Yes |
| Roads and walls | Five road stages and eight wall/gate types are placeable; connected rendering, path weights, movement bonuses, completed-wall blocking, traversable gates, destroyed-wall invalidation, touch/mouse brushing, and three achievement bindings are functional | Yes |
| Trash/decay | Functional decay, loose trash, collection capacity, deterministic processing, burning/essence, Cube-E compression recipe, and Trashy Slime pressure | Yes |
| Golems and Combobulators | Wood/stone/crystal/Cube-E typed production data; deterministic charge/capacity, energy upkeep, source-loss degradation, work/combat roles, Labor/Holy summons, influence maintenance, dispel recovery, Recombobulator repair, save/snapshot/UI support, and four official achievement bindings | Yes |
| Weather/events/disasters | Deterministic seasonal weather, lunar states, and first disaster effects | Yes |
| Goals/perks/chests/tutorials/statistics | Persistent profile God XP, 113-node mobile Goal Web list, deterministic five-tier chest inventory/opening, 47-perk catalog/stacking, four live perk modifier families, Doom/save persistence, contextual 12-topic mobile guide, per-day resource rates, and profile statistics UI are functional; exact web edges, chest balance, remaining modifier consumers, tutorial spotlight polish, and scope-specific statistics remain pending | Partial |
| Map editor/import/export | Functional local `.rtrmap` terrain editor, validator, save/load/play loop | Yes |
| iOS export/performance certification | Pending | No |
