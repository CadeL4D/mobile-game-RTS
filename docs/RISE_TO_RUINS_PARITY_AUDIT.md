# Rise to Ruins parity audit

External audit of Ruinward against the reference game (Rise to Ruins, SixtyGig Games,
Steam app 328080), performed 2026-08-14.

## Sources

- Rise to Ruins Wiki (Fandom), retrieved via the MediaWiki API on 2026-08-14. 148 content
  pages; ~104 fetched in full. `https://rise-to-ruins.fandom.com/`
- Steam achievement listing for app 328080, retrieved 2026-08-14.

**Evidence quality caveat.** Large parts of the wiki are tagged `{{UnderConstruction}}` and
several infoboxes contain unedited template placeholders (`HP = 1234 / 2345 / 3456`,
`Tier1Cost = 999 Wood / 999 Rock / 999 CutStone`, `Workers = 2 / 3 / 4 cooks` on buildings
with no cooks). Every finding below excludes those placeholder rows. Where an infobox field
disagrees with a per-tier table on the same page (all tower pages carry a stale
`Range = 12` infobox field alongside a real per-tier range table), the table is treated as
authoritative.

---

## 1. What is verified correct

These were checked field-by-field and match the reference exactly.

| Area | Result |
| --- | --- |
| Steam achievements | 113/113 names **and** descriptions match the live Steam listing exactly. Zero missing, zero extra, zero description drift. |
| Camp/Castle progression | All 15 tiers match on cost, HP, builder count, build range, max storage, buildings supported, and ancillary cap. |
| Game modes | All six present. `season_days` 7 for Nightmare / 5 elsewhere, and first-attack-day ordering (Nightmare 0, Survival 1, Traditional 2, Peaceful never) match the wiki's mode descriptions. |
| Influence cap | `population_count * 40` matches the wiki's stated `#villagers * 40`. |
| World map | 44 of 45 region names match exactly, in the correct biome groupings (7 biome groups, matching the wiki's own section headers). The 45th, `Lost Island`, is not on the wiki — already flagged `VERIFY_RUNTIME` in `parity_ledger.json`. |
| Building catalogue | Every building named on the wiki is present. Only omission is a duplicate ("Wooden gate" = the project's Wood Gate). |
| Fountain capacities | Small 48 / Large 96 — exact. |
| Ancillary | Storage 24/32/40/48/64 and range 20/22/24/26/28 — exact. |
| Equipment Storage | Capacity 10/14/18/22/26 — exact. |
| Fire pits | Range 12 / 16 — exact. |
| Ranger Lodge | 6/12/16 ranger staffing and the final-tier bow emplacement — exact. |
| Tool durability | Tools 300 uses, Bow 200 uses — exact. |
| Jobs | 25 job categories, consistent with wiki job references. |
| Spell catalogue | All 31 wiki-listed god powers present, in the correct Aid/Defensive/Offensive/Utility groups. |

This is a high level of fidelity. The audit below is about the remaining gap.

---

## 2. Numeric divergences from the wiki

Construction costs and HP diverge from the wiki across a large fraction of the catalogue.
Every row below has a non-placeholder wiki value.

### Costs and HP

| Building | Field | Wiki | Project |
| --- | --- | --- | --- |
| Ancillary | tier-1 cost | 32 wood, 8 rock | 16 wood, 8 rock |
| Small Fountain | cost | 24 rock | 16 rock |
| Fire Pit | cost | 6 wood | 4 wood, 4 rock |
| Large Fire Pit | cost / HP | 12 wood / 1195 | 8 wood, 12 rock / 1000 |
| Water Purifier | cost | 24 wood, 24 rock | 20 wood, 20 rock |
| Clinic | cost | 24 wood, 8 rock | 24 wood, 16 rock |
| Kitchen | cost / HP | 24 wood, 16 rock, 4 cut stone / 2120 | 20 wood, 12 rock / 1800 |
| Animal Pen | cost / HP | 32 wood / 2060 | 24 wood, 8 rock / 1900 |
| Clucker Coop | cost | 32 wood | 20 wood, 8 rock |
| Doggo House | HP | 1195 | 1200 |
| Courier Station | cost / HP | 16 wood, 24 rock, 4 crystal / 2120 | 16 boards, 16 cut stone / 2200 |
| Migration Way Station | cost | 24 wood, 32 rock | 32 wood, 24 rock (transposed) |
| Essence Collector | cost | 12 rock, 8 crystal | 24 rock, 24 crystal |
| Crystal Harvestry | cost | 16 wood, 32 rock, 8 **boards** | 16 wood, 32 rock, 8 **crystal** |
| Crystal Storage | capacity/tier | 16/32/48/64/80 | 64/96/128/160/200 |
| Bow Tower | cost / HP | 12 wood, 8 rock, 2 crystal / 1870 | 16 wood, 8 rock / 1900 |
| Ballista Tower | cost / HP | 24 wood, 32 rock, 24 cut stone, 6 crystal / 2330 | 32 wood, 16 rock / 2200 |
| Sling / Bullet Tower | cost / HP | 4 wood, 16 rock, 2 crystal / 1870 | 12–16 wood, 16 rock / 1900–2000 |
| Attract Tower | cost | 16 wood, 4 boards, 16 rock, 8 crystal | 16 rock, 16 crystal |
| Banish Tower | cost / HP | 16 wood, 16 rock, 4 cut stone, 8 crystal / 2120 | 16 rock, 16 crystal / 2100 |
| Spray Tower | cost / HP | 4 wood, 4 boards, 16 rock, 8 cut stone, 2 crystal / 2070 | 12 boards, 12 cut stone / 2100 |
| Static Tower | cost / HP | 16 wood, 4 boards, 16 rock, 8 crystal / 2120 | 12 cut stone, 8 crylithium / 2200 |
| Phantom Dart Tower | cost / HP | 12 wood, 8 crystal / 1775 | 12 cut stone, 6 crylithium / 2200 |
| Recombobulator Tower | cost / HP | 16 wood, 8 crystal / 1945 | 16 cut stone, 8 crylithium / 2200 |
| Elemental Bolt Tower | cost / HP | 4 wood, 24 boards, 16 rock, 8 crystal, 2 crylithium / 2170 | 12 cut stone, 8 crylithium / 2300 |

The tower rows show a consistent pattern: the reference uses **broad multi-resource recipes**
(wood + boards + rock + cut stone + crystal + crylithium in one tier), while Ruinward uses
narrow 2-ingredient recipes. That materially changes the mid-game economy — RtR's towers are
a sink for every production chain simultaneously, which is what forces the player to build
out refining before defending.

**Integrity issue:** all of the buildings above carry `"evidence": "WIKI_SUPPORTED"` in
`content/data/buildings.json`, but their costs and HP do not match the wiki. The evidence tag
is currently asserting more than the data supports. Either the values should be corrected, or
the tag should be downgraded to `VERIFY_RUNTIME` / `ORIGINAL_TUNING`.

### Tower combat model

`combat_evidence` is honestly marked `VERIFY_RUNTIME` here, so this is a tuning gap rather
than a mislabelled one — but the magnitude is worth recording.

| Tower | Wiki (per-tier table) | Project |
| --- | --- | --- |
| Bow Tower | range 16→20, damage 20–30, reload 150→110 ticks | range 30, damage 70, reload 10 ticks |
| Ballista Tower | damage 100–150, ~3× slower than Bow | damage 260, reload 35 ticks |
| Attract Tower | range 18→24, reload 160→85, 25→10 energy/shot | range 30, reload 10, 1 energy/shot |

Ruinward's towers fire roughly **10× faster** than the reference at 2–3× the per-shot damage.
Combined with the ammunition finding below, defense is far cheaper than in RtR.

### Ammunition economy

The wiki states 1 Ballistae Bolt = **20 rounds** in a Bow Tower and **10 bolts** in a Ballista
Tower. Ruinward sets `ammo_per_shot: 1` for both, so a unit of ammunition buys one shot.
Combined with the 10× faster reload, tower ammunition demand is off by 2–3 orders of magnitude
against the reference, which inverts the intended pressure on the Bowyer and Tumbler.

### Roads

Wiki speed bonuses are 20 / 40 / 50 / 60 / 70 % by tier, degrading to a 10 % "debris" state
if unmaintained. Ruinward uses 5 / 12 / 20 / 28 / 36 % — roughly half — and these multipliers
are **hard-coded in `core/simulation/simulation_host.gd:1787`**, not in `buildings.json`,
despite the road entries carrying `"evidence": "WIKI_SUPPORTED"` and the project's
data-driven design goal. Road tier-1 costs also differ (the wiki charges a single resource
per tier; Ruinward charges two from tier 3 up).

---

## 3. Reference systems with no implementation

| System | Reference behaviour | Status in Ruinward |
| --- | --- | --- |
| Villager attributes | Every villager has Strength, Dexterity and Intelligence, which drive work and combat performance | Absent — no stat rolls anywhere in `core/` |
| Land Desirability | A per-building field on nearly every wiki infobox (Camp +2, towers −2, Ranger Lodge −1, fire pits −1); drives where villagers settle and what monsters target | Absent — no `land_desirability` in code or data |
| Corruption Resistance | Per-building value (Camp 3, towers 2, ancillary 2) | Corruption resistance is computed positionally in `simulation_host.gd`, but there is no per-building resistance value in `buildings.json` |
| Town-centre bonuses | Each Camp/Castle tier grants Global Speed +1…+15 % and Building Speed +2…+30 % | Absent — the 15 tiers carry cost/HP/range/storage but not the two bonus curves |
| Monster spawn schedule | Species gated by day: small slime d2, zombie d3, slime d4, skeleton d5, spectre d12, fire elemental d16 | Absent — a single per-mode `first_attack_day` plus a rate multiplier; no per-species gating, so the escalation curve is flat |
| Curtain walls vs spectres | Spectres phase through wood and stone walls, **but curtain walls block them** | Not implemented. `_move_spectre_toward` (`simulation_host.gd:3855`) walks a straight line to the target with no wall test at all, so curtain walls — the designed counter — do nothing |
| Tower energy capacity | Towers hold energy per tier (100/150/200/250) | Magic towers consume energy per shot, but no per-tier energy capacity |
| Quiver | 40 arrows | No durability/capacity value on the quiver resource |
| Emergent paths | "Paths appear on their own at frequently walked tiles" | Not implemented |
| Road decay | Roads decay to Debris without Way Maker / Maintainer upkeep | No debris state; roads do not decay |

Corrected after first publication: an earlier draft of this audit listed the Quiver's
40-arrow capacity as missing. It is present, modelled as `shots: 40` on the quiver
resource rather than as a durability value. No change was needed.

The spectre/curtain-wall item is the most consequential: it removes a counter the player is
expected to build toward, and the README currently lists "spectre wall phasing" as complete.

---

## 4. Original content not in the reference

Not defects — recording them so parity claims stay honest. Confirmed absent from the wiki:
Comet (32nd spell, vs the wiki's 31), Ice Ballista, Cube-E Golem + Combobulator, Crylithium
Wall / Crylithium Curtain Wall / Crylithium Fire Pit, Landfill, Trash Can, Trashy Cube Pile,
Essence Altar, Reliquary, Lightning Rod, and the Lost Island region. Several of these are
plausibly Update 2 content the wiki has not documented rather than invention — the wiki's
last substantive edits predate it — so they warrant runtime verification, not removal.

Naming: the wiki calls the road tiers "Log Path" and "Cobble and Log Path"; Ruinward uses
"Log Road" and "Cobble and Log Road".

---

## 5. Engineering findings (found while auditing, not parity-related)

**Six extracted subsystems are dead code.** `simulation_host.gd` instantiated thirteen
subsystem objects; six of them were never called anywhere in the game:

| Instance | Method calls in the live code |
| --- | --- |
| `task_board`, `inventory`, `reservations`, `task_system`, `trade_system`, `corruption_system`, `spell_system` | live |
| `logistics` (logistics_system.gd) | **0** |
| `production` (production_system.gd) | **0** |
| `needs_system` (needs_system.gd) | **0** |
| `population_system` (population_system.gd) | **0** |
| `animal_system` (animal_system.gd) | **0** |
| `combat_system` (combat_system.gd) | **0** |

The live implementations of logistics, production, needs, population, animals and combat all
still live inside `simulation_host.gd`. The six extracted files were parallel copies exercised
only by `_test_extracted_subsystem_contracts` in `tests/run_all.gd`, so that test reported
green on code the game never ran. They had already drifted: `combat_system.gd` read
`reload_ticks` and `range` flat, while the live path applied per-tier scaling. Either finish
the extraction or delete the copies — as it stood the suite's subsystem coverage was false
confidence.

**`_road_speed_multiplier` is O(buildings) per actor per tick.** `simulation_host.gd:1781`
linearly scans every building for each movement step. At the tier-15 cap of 86 buildings with
a few hundred actors, that is tens of thousands of `Rect2i.has_point` calls per tick on a
phone. A cell→road lookup dictionary rebuilt on construction/destruction would remove it.

---

## 6. Resolution

Everything below was fixed in the same pass as this audit and is covered by
`_test_reference_parity_fixes()` in `tests/run_all.gd`, which runs in both the full suite and
the CI smoke suite.

| Finding | Resolution |
| --- | --- |
| Curtain walls did not block spectres | `blocks_phasing` on both curtain wall tiers; `_phase_barrier_between()` re-targets a phasing actor onto the first curtain wall in its route. Wood and stone walls stay transparent. |
| Ammunition rounds per unit | `rounds_per_ammo` on the tower definition — 20 for the Bow Tower, 10 for the Ballista Tower. |
| Towers fired ~10× too fast, wrong reach | `range_by_tier` and `reload_ticks_by_tier` on all eleven towers, taken from the wiki's per-tier tables. Reload is converted from the reference's 60 Hz tick to this project's 10 Hz tick (÷6), which is recorded in the data patch. |
| Costs and HP diverged on ~25 buildings | Corrected to the published tables (§2). |
| Crystal Storage capacity | Corrected to 16/32/48/64/80. |
| Land Desirability absent | `land_desirability` catalogued per building and summed into `SimulationHost.land_desirability`; it now scales nomad arrival intervals through `get_settlement_desirability_factor()`, bounded to ×0.5–×2. |
| Corruption Resistance absent from data | `corruption_resistance` catalogued per building and weighted into `_corruption_resistance_at()`. |
| Town-centre speed bonuses absent | `global_speed_bonus` / `building_speed_bonus` on all 15 tiers, applied to villager movement and to both construction paths. |
| Monster spawn ladder flat | `spawn_day` per species (slime d2 → fire elemental d16); `_spawn_monsters_if_due()` only draws from unlocked species. |
| Road speeds halved and hard-coded | `road.speed_bonus` in the catalogue at the documented 20/40/50/60/70 %, with the 10 % debris value alongside it. Pathfinder weights derive from the same number. |
| `_road_speed_multiplier` scanned every building per actor per tick | Replaced with a cell-indexed cache rebuilt with navigation. |
| Six dead subsystems | Deleted, along with the test that gave them false coverage. A replacement assertion fails the build if the host ever instantiates a subsystem it does not call. |

Deliberately **not** changed: tower damage numbers and per-shot energy costs. The reference's
values are calibrated against its own monster hit points, energy economy and tick rate, none
of which transfer; copying them would be a balance guess dressed as parity. These stay marked
`combat_evidence: VERIFY_RUNTIME`.

Still open, and larger than this pass: villager Strength/Dexterity/Intelligence, road decay to
debris, emergent paths on walked tiles, and per-tier tower energy *capacity* is catalogued and
buffered but not yet surfaced in the UI.
