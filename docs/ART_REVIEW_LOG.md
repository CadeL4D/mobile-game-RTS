# Visual review log

This log records evidence from controlled native-resolution captures. A rendered sprite remains `IN_REVIEW` until its family completes all three required passes in `ART_BIBLE.md`.

## Baseline review set — 2026-08-12

Harness: `--capture-visual-review` in `presentation/scripts/main.gd`.

Controlled outputs:

- `build/captures/review_day_1x.png`
- `build/captures/review_night_blood_moon_1x.png`
- `build/captures/review_rain_lightning_1x.png`
- `build/captures/review_corruption_blight_1x.png`

The harness places representative settlement families, four construction stages, light and severe damage, fire, rubble, missing-ammunition and missing-energy states, all workforce jobs, every animal family, and every hostile family. It renders the same composition at exactly 1× under day, night/blood moon, rain/lightning, and corruption/blight.

### Pass-one findings and corrections

- Rejected solid dirt construction cards. Construction now leaves terrain visible and grows through broken rope, stakes, delivered bundles, framing, and partial roofing.
- Rejected rectangular destroyed-state overlays. Destroyed structures now collapse into deterministic beams and sparse rubble.
- Rejected colored damage borders. Damage removes deterministic pixel clusters and exposes underlying terrain, with rubble added at severe damage.
- Rejected single-direction actor bodies. Villagers, animals, monsters, and golems now derive four-direction orientation from their target vector and use two-frame directional feet while moving.
- Reduced night opacity so bodies, tools, entrances, and status badges remain distinguishable on mobile.
- Replaced synthetic diagonal corruption stripes with an organic connected review front and added deterministic edge pixels and internal growth clusters.
- Moved weather particle distribution from the entire 256×256 region to the visible camera rectangle.
- Fixed storms so rain and lightning compose as separate layers.

### Still required before approval

- Tier comparison for every upgrade family, especially the 15 Camp/Castle stages and four tower stages.
- Family-specific operation animation beyond the current functional prop vocabulary.
- Corrupted, reclaimed, freezing/electrical, abandoned, dismantling, and full-output/missing-input reviews for applicable buildings.
- Actor clip review for sleep, eat, drink, carry, manufacture, pray, migrate, death/decay, capture, birth/spawn, and status effects.
- Bright-biome and low-contrast-biome review across all seven biome palettes.
- iPhone safe-area and iPad split-inspector captures at their physical reference aspect ratios.
- Formal clean-room comparison and final `APPROVED` promotion in the sprite ledger.

## Tier comparison — 2026-08-12

Harness: `--capture-tier-review`; output: `build/captures/review_tiers_1x.png`.

The numbered sheet renders:

- Camp/Castle tiers 1–15 in two rows.
- Ancillary and Crystal Storage tiers 1–5.
- Housing tiers 1–7 and Doggo House tiers 1–3.
- Bow Tower and Crystal Golem Combobulator tiers 1–4.
- Clinic tiers 1–3.

Corrections from this pass:

- Camp tiers grow from tents and supplies into multi-roof settlements, masonry village centers, keeps, strongholds, and castles.
- Housing gains annexes, masonry, capacity props, corner reinforcement, and roof bracing.
- General work/storage/magic/golem upgrades add work cover, capacity stacks, masonry corners, machinery, and energy nodes.
- Towers gain stone rings, cardinal supports, and late crystal/power nodes around their weapon-specific center.
- Stronghold/castle courtyards remain open terrain bounded by masonry; the initial dark filled courtyard was rejected.

The sheet proves distinct physical stages for the representative tier-count families. Individual family/biome reviews remain required before any ledger status can advance to `APPROVED`.

## Biome integration harness

Harness: `--capture-biome-review`.

The harness regenerates the same representative village composition for Forest, Haven, Desert, Red Sands, Marsh, Dry Lands, and Islands. Each output is rendered at 1× with the same buildings, villagers, animals, time, and camera. This makes palette collisions and disappearing silhouettes directly comparable. Island generation uses a higher water threshold so its geography is visibly distinct rather than a Forest recolor.

First-pass findings:

- All seven palettes keep building roofs, entrances, powered machinery, job colors, and tiny directional actors readable at 1×.
- Desert and Red Sands are immediately separable; Marsh reads as saturated low ground; Island now contains a substantially wetter land/water pattern.
- The original guaranteed square starting area was rejected. Generation now creates a deterministic circular clearing with a broken natural edge, while preserving a large enough guaranteed footprint for the tested Camp/Housing/Farm/Well opening.
- Desert, Red Sands, Dry Lands, and Marsh clear to their own buildable native ground instead of stamping a green rectangle into the biome.

## Season integration harness

Harness: `--capture-season-review`.

The harness freezes an identical Forest village at midday in Spring, Summer, Autumn, and Winter. Seasonal changes rebuild the cached terrain only when the season changes: spring flowers, subtly dried summer ground, autumn vegetation/leaves, and winter ground snow/iced water coloring. Weather remains clear so ground integration can be judged independently from rain or snow particles.

## Connected environment and building-family iteration â€” 2026-08-12

Harnesses: `--capture-visual-review`, `--capture-tier-review`, and the new `--capture-building-review`.

Controlled outputs:

- `build/captures/review_day_1x.png`
- `build/captures/review_building_families_1x.png`
- `build/captures/review_tiers_1x.png`

Rejected approaches:

- The first cardinal-neighbor terrain pass was rejected because forests resembled circuit-board paths and the simulation cells remained visually dominant.
- The first cubic ownership-mask pass removed the grid but was rejected as a flat procedural heatmap with fragmented landforms and shallow material texture.
- The generated 4x4 building-density study was rejected for shipping because its projection remained too frontal and its detail density was incompatible with the native 8-pixel cell scale. No generated pixels were integrated.
- Opaque rectangular work-yard fills were rejected. Runtime yards now use broken translucent wear fields, functional props, perimeter stakes, and open entrances so the biome remains visually continuous.

Current clean-room corrections:

- Low-frequency canopy and geology fields create broad readable landforms; two cleanup passes remove pinholes and one-cell whiskers.
- Terrain ownership masks render sub-cell boundaries with material-specific pixel bands. Forest, rock, water, crystal and corruption use separate contour palettes and interior texture rules.
- A composed multi-lobed rock shelf with nested ground pockets is now included near the first settlement for geology/readability review.
- Resource placement uses irregular deterministic scatter rather than a fixed sampling grid; guaranteed opening resources and water use broken radial/elliptical patches.
- Forest and common-stone resources are carried by their connected terrain materials; individual living tree/boulder sprites were rejected. Depletion exposes top-down stumps/rubble, while ore and crystal retain distinct embedded signals.
- Shared roofs now use chamfered overhead plans, contained southeast shadows, ridges, trim, and material texture instead of plain rectangles.
- The Clinic, Maintenance Building, Marketplace, Lumber Shack, Mining Facility, Farm, Animal Pen, Lumber Mill, Forge, Bowyer, Essence Altar, Housing and Camp/Castle late tiers now have function-specific overhead structures and props.
- Late Camp/Castle stages now include packed keeps, service wings, corner towers, gatehouses, courtyard supplies, crenellation and flags rather than a small roof in an empty wall square.
- The completed-family sheet isolates sixteen core structures at exactly 1Ã— so silhouette and function can be judged without construction/damage overlays.

Status remains `IN_REVIEW`. The connected composition and core-building vocabulary are materially improved, but final approval still requires secondary-family sheets, per-biome building review, operation/damage/corruption states, and mobile-size comparison.

## Full building-catalog expansion - 2026-08-12

Harnesses: `--capture-building-review` and `--capture-catalog-review`.

Catalog outputs:

- `build/captures/review_catalog_civics_1x.png`
- `build/captures/review_catalog_food_water_1x.png`
- `build/captures/review_catalog_production_1x.png`
- `build/captures/review_catalog_storage_1x.png`
- `build/captures/review_catalog_arcane_industry_1x.png`
- `build/captures/review_catalog_towers_1x.png`
- `build/captures/review_catalog_roads_walls_1x.png`

Rejected approaches and corrections:

- The second generated building-family study improved density and material separation, but was rejected because it still exposed front facades and was not native-resolution pixel art. It remains a provenance-recorded, non-shipping design reference; no generated pixels were integrated.
- A universal fenced-yard frame made every building read as the same rectangle with a different prop. Full rails are now reserved for farms and animal functions; arcane sites use embedded corner stones, storage uses loading bumpers, and civic/industrial work yards use open survey corners.
- Storage palette swaps were rejected. Wood, rock, crystal, mineral, food, gold, ammunition, equipment, and miscellaneous storage now use different bay structures and visibly different stored goods.
- Thin colored road/wall lines were rejected. Roads now form connected material-width surfaces with path wear, sleepers, cobble, boards, and cut-stone patterns. Walls use connected thickness, material construction, gates, blocks, crenellation, crylithium cores, or trash-cube modules.
- Shared circular tower foundations were rejected for physical weapons. Ballista, bow, bullet, sling, and spray towers now use overhead timber/stone weapon platforms; magical towers retain distinct ritual rings and powered nodes.
- Sparse Farm, Animal Pen, and Essence Altar footprints were rejected in the 16-family sheet. Farms now use orientation-aware crop beds, pens use a larger shelter/run/trough/tracks composition, and the altar uses a larger dais with cardinal vessels.

Current result:

- Civics expose logistics, care, repair, trade, migration, and road-work functions through their overhead layout.
- Refining and manufacturing buildings have larger roof/workbench masses, visible drive machinery, tools, quench tubs, and material-specific equipment.
- Work-yard dirt now has a denser irregular center, dithered biome transition, wear clusters, and an entrance track without a hard rectangular ground card.
- Roofs now include a narrow overhead wall/eave skirt, contained contact shadow, material seams, ridge detail, and small edge variation.

Status remains `IN_REVIEW`. The catalog is structurally distinct and readable at 1x, but the next art gates remain operation animation, all damage/corruption states, every biome, mobile UI composition, and final hand-authored polish per family.

## Building lifecycle and operation-state matrix - 2026-08-12

Harness: `--capture-building-states`.

Controlled outputs:

- `build/captures/review_building_states_1x.png`
- `build/captures/review_building_states_phase_b_1x.png`

The matrix is rendered twice at exact 1x with a nine-tick phase change. Its numbered cases are:

1-6: 12%, 32%, 57%, and 82% construction; completed operation; charging.

7-12: missing input, full output, paused, missing worker, at capacity, and no energy.

13-18: no ammunition, light damage, severe damage, burning, frozen, and electrified.

19-24: corrupted, reclaimed, abandoned, repair requested, repairing, and missing repair material.

25-30: dismantle requested, active dismantling, firing, reloading, attracting, and destroyed/rubble.

Corrections made during review:

- Tower state rendering previously preferred the generic operation field and hid combat states such as `no_ammo`, `firing`, and `reloading`. Towers now render from their authoritative combat state.
- The first state capture was rejected because forest/rock obscured early construction and the default placement ghost covered the burning case. The harness now creates a broad irregular review clearing and cancels placement after rebuilding terrain.
- Active dismantling was too similar to a designation. Progress now removes deterministic structure clusters, exposes biome ground, accumulates salvage, and adds partial scaffolding while the simulation-owned progress bar remains visible.
- Frozen, electrified, corrupted, reclaimed, and abandoned now have distinct low-coverage overlays that preserve the underlying building silhouette.
- Operating industry emits small deterministic vents/sparks; logistics sites show moving cargo; arcane, golem, lighting, and tower families use restrained powered pulses.
- Mend now removes the authoritative burning status as well as its visual flag, preventing hidden ongoing fire damage after the spell appears to extinguish a building.

All 252 building-tier ledger entries now include the expanded lifecycle contract: electrified, abandoned, repair requested, repairing, missing repair material, and dismantle requested in addition to the previously required states. Runtime pixels remain clean-room native drawing code.

Status remains `IN_REVIEW`. This matrix proves the shared lifecycle vocabulary, but approval still requires each family to be checked across every biome and at iPhone/iPad play scale.

## Expanded biome-family and mobile-layout review - 2026-08-12

Biome harness: `--capture-biome-review`.

The seven exact-1x captures now contain sixteen representatives spanning town center, civics, housing, food/water, harvesting, refining, manufacturing, storage, magic, lighting, golems, trash, and towers. They also contain eighteen connected Cut Stone/Board Road cells, eighteen connected Crylithium Curtain Wall cells, and moving villagers.

- `build/captures/review_biome_forest_1x.png`
- `build/captures/review_biome_haven_1x.png`
- `build/captures/review_biome_desert_1x.png`
- `build/captures/review_biome_red_sands_1x.png`
- `build/captures/review_biome_marsh_1x.png`
- `build/captures/review_biome_dry_lands_1x.png`
- `build/captures/review_biome_island_1x.png`

The category representatives preserve silhouette and material separation in all seven palettes. Marsh is the tightest value case, but roof edges, entrances, machinery, powered cyan elements, pale roads, and crylithium walls remain readable without depending only on hue.

Mobile harnesses: `--capture-mobile-phone` at 844x390 and `--capture-mobile-tablet` at 1024x768.

- `build/captures/review_mobile_phone_hud.png`
- `build/captures/review_mobile_phone_build_drawer.png`
- `build/captures/review_mobile_phone_mode_select.png`
- `build/captures/review_mobile_tablet_hud.png`
- `build/captures/review_mobile_tablet_build_drawer.png`
- `build/captures/review_mobile_tablet_mode_select.png`

Corrections and measured results:

- The original desktop-scaled phone HUD rendered controls below the 44-point touch contract and ignored notches/home indicators.
- Runtime layout now converts `DisplayServer.get_display_safe_area()` from physical pixels into logical canvas coordinates on iOS/Android. Desktop phone review simulates 47-point left, 21-point right, and 21-point bottom insets.
- The phone top bar uses compact population/resource/influence-energy-faith/time text, a 44-point pause control, and safe-area bounds. Sandbox influence displays as infinity rather than a seven-digit value.
- The phone command row is a taller horizontal scroller; its actions measure 44.4 points. Edge drawers, search fields, catalog rows, tutorial actions, and mode choices use the same physical minimum.
- The phone mode selector is a centered, vertically scrollable safe-area panel, so all six modes and the editor remain reachable without reducing touch targets.
- The iPad layout measures 44.8-point permanent actions and drawer rows, retains more world space, and uses a wider right-side split inspector/drawer.
- Automated capture validation rejects targets below 43.5 measured points or phone panels entering the simulated safe insets. Both reference devices report zero errors.

Status remains `IN_REVIEW`. Building-category/biome readability and the primary play/mode UI now have controlled evidence. World map, custom mode, editor, goals/perks, trade/migration, Reliquary, and every inspector variant still require dedicated phone/tablet captures before final visual approval.

## Dense building architecture pass - 2026-08-12

Controlled outputs:

- `build/captures/review_building_families_1x.png`
- `build/captures/review_catalog_civics_1x.png`
- `build/captures/review_catalog_food_water_1x.png`
- `build/captures/review_catalog_production_1x.png`
- `build/captures/review_catalog_storage_1x.png`
- `build/captures/review_tiers_1x.png`
- `build/captures/review_building_states_1x.png`
- `build/captures/review_building_states_phase_b_1x.png`

Problems identified in the previous pass:

- Most buildings occupied too little of their lots and read as a tiny decorated prop inside a generic work-yard template.
- Shared roofs used uniform full-width stripes, shallow contrast, and weak eaves, producing flat card-like silhouettes.
- Storage and workshop variants depended too heavily on their small resource props while their architectural masses remained interchangeable.
- Generic upgrade annexes, gears, crystals, and full-lot masonry frames made unrelated categories converge as tiers increased.
- The first late-town-center correction grew into one oversized roof and did not create enough difference between Stronghold and Castle stages.

Corrections in this pass:

- Civic, harvesting, food, refining, manufacturing, and storage roofs now occupy substantially more of their functional lots while leaving entrances and machinery readable.
- Shared timber roofs use compact contact shadows, a narrow overhead eave/wall skirt, broken shingle clusters, axis-aware ridges, patch repairs, edge wear, moss, and a top-visible threshold. No front facade is required for their volume.
- Canvas roofs now use stronger perimeter structure, irregular seam clusters, repair patches, lashings, deeper contact shadows, and overhead entrances.
- Category-specific upgrade language replaces the universal recipe: industry gains machinery and furnaces; civics gain service awnings and fortification; rural sites gain lean-tos and supplies; magic gains pylons and crystals; storage gains capacity stacks and loading infrastructure.
- Broken masonry pads reinforce occupied areas without drawing a hard rectangle around the lot.
- All nine storage families now have larger material-specific shelter masses paired with visible logs, bays, crystals, ore, food, vaulting, ammunition, equipment, or miscellaneous goods.
- The fifteen Camp/Castle stages now transition from tents to organized timber buildings, keeps with courts and service wings, and fortified compounds with central keeps, gatehouses, corner towers, curtain walls, supplies, crenellation, and flags.
- A generated architectural-density study influenced only mass and proportion. Its pixels were not integrated and it is recorded as a rejected/non-shipping reference in the provenance manifest.

Validation:

- The project compiles in Godot 4.7.
- The 30-case lifecycle matrix remains legible after the roof and density changes.
- The full headless project regression reports `ContentRegistry: loaded 23 categories, 647 entries` and `TEST RESULT: PASS` in `build/building-art-regression-v4.log`.

Status remains `IN_REVIEW`. This is a materially stronger shared building foundation, but final approval still requires per-family operation animation, individual high-tier art direction, all-biome recapture after this architecture change, and phone/tablet village-density review.

## Connected terrain material and season pass - 2026-08-12

Harnesses: `--capture-building-review`, `--capture-biome-review`, and `--capture-season-review`.

Controlled outputs:

- `build/captures/review_building_families_1x.png`
- `build/captures/review_biome_forest_1x.png`
- `build/captures/review_biome_haven_1x.png`
- `build/captures/review_biome_desert_1x.png`
- `build/captures/review_biome_red_sands_1x.png`
- `build/captures/review_biome_marsh_1x.png`
- `build/captures/review_biome_dry_lands_1x.png`
- `build/captures/review_biome_island_1x.png`
- `build/captures/review_season_spring_1x.png`
- `build/captures/review_season_summer_1x.png`
- `build/captures/review_season_autumn_1x.png`
- `build/captures/review_season_winter_1x.png`

Rejected approaches:

- The previous uniform dot screen made open terrain look synthetic and gave grass, sand, marsh, and rock the same visual frequency.
- Equal-density boulder scattering hid the connected rocky surface and turned geology into a pebble carpet.
- Cubic binary-mask expansion produced ringing at high-contrast material borders.
- A full native 8-pixel-per-cell ownership renderer was visually useful but failed the practical load-time gate: the seven-biome capture batch timed out after roughly 244 seconds.
- A 2-pixel-per-cell ownership test reduced the representative capture from 17.8 to 10.0 seconds, but was rejected because nearest-neighbor expansion exposed obvious 4-pixel tonal blocks and hardened coast/canopy boundaries at normal zoom.
- High-amplitude per-cell shelf jitter created long comb-like stone teeth. Reducing the jitter and applying one restrained post-landmark majority pass removed them without rounding away the broad shelf.
- Spring/summer color-only changes were rejected as visually indistinguishable; autumn and winter tinting was also incomplete because hard-coded green canopy ramps overrode the seasonal base colors.

Current clean-room corrections:

- Terrain uses a hybrid 4-pixel-per-cell ownership field, nearest-neighbor native upscale, and sparse native-pixel accent pass. Cached native noise images supply broad relief, secondary patches, and fine material variation.
- Nine one-hot ownership layers are packed into three RGB channel masks, and an LRU cache retains at most three completed region/season textures. Packing alone did not materially reduce end-to-end desktop capture time, so it is retained as lower read/setup overhead rather than claimed as the final performance solution.
- Open ground is built from quiet large tonal fields. Grass tufts, flowers, dry grass, leaf litter, sand streaks, marsh reeds, mineral glints, corruption sparks, and water ripples are sparse clustered motifs instead of evenly distributed noise.
- Forests form continuous overlapping crown fields with subordinate tree-resource crowns. Rocks form broad value-stepped plates with thin contour cracks and edge talus. Water has a neighboring-material bank, shallow rim, deeper basin, broken ripples, and sparse shoreline vegetation.
- Water animation uses a precomputed capped set of deterministic ripple points and simulation-tick phases. It does not scan the terrain or rebuild the base texture per frame, and winter uses a quieter icy highlight ramp.
- Rocky resource density is lower than forest density so the plate remains visible; crystal and food scatter also use independent spacing.
- The authored settlement shelf uses sub-cell boundary variation and a cleanup pass, eliminating the former one-cell cliff whiskers while retaining nested grass pockets.
- Spring, summer, autumn, and winter now change ground materials, canopy ramps, tree crowns, and sparse seasonal accents. Winter uses broken snow coverage rather than a featureless white overlay.
- The final seven-biome batch completed in 93.7 seconds and the four-season batch in 60.4 seconds on the desktop review machine. These are evidence timings, not mobile approval; chunk caching/threading and device profiling remain required.
- Phone and tablet HUD/build-drawer recaptures preserve building, actor, shoreline, rock, and canopy readability behind the translucent mobile panels; the automated safe-area/touch-target checks continue to report zero errors.
- `art/reference/terrain_direction_imagegen_source_v1.png` is retained as a provenance-recorded, non-shipping material study. No generated pixels enter the runtime.

Status remains `IN_REVIEW`. The terrain is materially more coherent and professional at exact 1x, but final approval still requires chunked rebuild/caching, zoom-level checks, animated water/weather integration, corruption transition review, all terrain editing states, and iPhone/iPad performance evidence.

## Local water-network presentation pass - 2026-08-12

Controlled output:

- `build/captures/review_water_network.png`

Implemented presentation and interaction:

- Wells, Rain Catchers, Water Purifiers, and both Fountain sizes now expose their own saved clean- and dirty-water reservoirs rather than appearing as inert catalog entries.
- Operational world animation distinguishes filling, rain collection, purification, and available drinking water. Water Masters visibly carry a water bucket during collection and delivery.
- The mobile inspector reports the selected building's operating state and local clean/dirty amount and capacity, including the reference-supported 48-unit Small Fountain and 96-unit Large Fountain capacities.
- Villagers walk to a reachable drinking source, while bottled water remains portable. Water Masters collect from reachable shore cells, deliver dirty water to Purifiers, and supply fountains; Organizers can assist with fountain distribution.
- The review capture deliberately combines rainfall, all five water-building roles, an active Water Master, and the selected Purifier inspector at normal play scale.

Validation and caveats:

- The first implementation targeted a deep-water cell and exposed a real pathing defect: Water Masters could claim collection work but never reach it. Collection now targets a walkable shoreline cell adjacent to surface water, and the deterministic scenario completes collection, purification, fountain delivery, drinking, and save/load.
- The building roles and Fountain capacities are wiki-supported. Exact Rain Catcher generation, Purifier throughput/carry balance, and some tier scaling remain `VERIFY_RUNTIME` values and are not claimed as final parity.

Status is `FUNCTIONAL / IN_REVIEW`: the gameplay loop and mobile-readable visual states are complete, while exact Update 2d balance and per-tier art variants still require runtime confirmation.

## Settlement range and organic corruption pass - 2026-08-12

Controlled output:

- `build/captures/review_corruption_range.png`

Visual problems found and corrected:

- The former live corruption overlay drew an opaque purple rectangle and a hard one-pixel outline for every logical terrain cell. Large corrupted areas therefore exposed the simulation grid and did not blend with the connected grass, forest, rock, and water foundation.
- The first replacement joined neighboring circles, but repeated alpha stacking produced a flat saturated slab and hid the material beneath it. That intermediate capture was rejected.
- The accepted pass uses two disjoint, connected pixel-mask layers per cell. Its dark under-root and translucent bloom join across neighbors without internal overdraw, preserve underlying terrain relief, round exposed corners, and add sparse non-repeating veins, dark clots, bright spores, and broken rim highlights.
- Reclaimed terrain now appears as an irregular opening in the infection rather than a set of obvious cleared squares. The selected building's quiet range wash and pixel boundary show why the front is retreating without obscuring buildings or resources.
- The mobile inspector reports the selected structure's settlement range and its corruption-reclamation role. Placement previews use the same radius and show invalid out-of-range sites before submission.

Simulation/evidence represented by the capture:

- Completed non-wall structures form a connected construction network and cast corruption resistance; walls and roads do not cast it.
- Camp radii remain driven by the documented 15 town-center tiers. Ancillary uses the wiki-supported 20/22/24/26/28 progression, Fire Pit uses 12, and Large Fire Pit uses 16.
- A single explicit 16-cell fallback is used by non-wall building families whose exact Update 2d range has not yet been audited. Crylithium Fire Pit progression also remains `VERIFY_RUNTIME`; neither is claimed as final balance.
- Resistance deterministically reclaims covered cells, prevents fresh spread into covered cells, records the official 256-cell `Take it Back!` achievement counter, and survives save/load through derived building state.

Status remains `IN_REVIEW`. The dynamic corruption boundary now matches the connected terrain direction substantially better. Corrupted-resource transitions are covered by the later infected-ecology pass; final terrain approval still requires threat-strength shading, enemy-road/building integration, zoom-level review, and iPhone/iPad performance profiling under a near-map-scale corruption front.

## Terrain-resource integration pass - 2026-08-12

Controlled outputs:

- `build/captures/review_biome_forest_1x.png`
- `build/captures/review_biome_haven_1x.png`
- `build/captures/review_biome_desert_1x.png`
- `build/captures/review_biome_red_sands_1x.png`
- `build/captures/review_biome_marsh_1x.png`
- `build/captures/review_biome_dry_lands_1x.png`
- `build/captures/review_biome_island_1x.png`

Corrections:

- Harvestable wood and rock nodes previously repeated the same large sprite at uniform statistical intervals. Even with connected forest and rock base materials, that overlaid a bright tree-bulb pattern and a large-pebble carpet that fragmented the terrain mass.
- Forest resource density changed from 1/17 at 12 units to 1/29 at 20 units; expected reserve density changes only from 0.706 to 0.690 units per material cell. The continuous canopy now carries the forest silhouette, with harvest trees acting as subordinate landmarks.
- Rock density changed from 1/31 at 12 units to 1/47 at 18 units; expected reserve density remains effectively stable at 0.387 versus 0.383. Four outcrop silhouettes now vary footprint, contact shadow, top plate, crack, and secondary fragment instead of repeating one identical boulder.
- Crystal density changed from 1/23 at 12 units to 1/31 at 16 units, retaining 0.522 versus 0.516 expected units per material cell while reducing cyan visual noise.
- Tree crowns now use season-aware irregular overlapping lobes, restrained two-pixel highlight clusters, variable canopy size, and a subordinate trunk. The former bright rectangular crown badge was removed.
- Iron and gold outcrops share the geological silhouette but expose distinct ore seams rather than relying on a complete recolor.

The full seven-biome recapture completed successfully at exact 1x. Status remains `IN_REVIEW`: resource-to-terrain hierarchy is substantially improved, but cliff elevation language, shoreline foam/bank variants, harvested/regrowth states, dead-tree/corruption transitions, and mobile zoom-density approval remain open.

## Harvested-resource lifecycle and Crystal Motivator pass - 2026-08-12

Controlled output:

- `build/captures/review_resource_lifecycle.png`

Visual and simulation deliverables:

- Wood, rock, crystal, and wild-food nodes now render full, mid, low, and exhausted states from their saved current/original capacity ratio.
- Wood crowns lose canopy mass as they are harvested and finish as a persistent top-down stump. Rock changes from a broad outcrop to split fragments and permanent rubble. Crystal loses its secondary shard, contracts to one short shard, and finishes as a fractured mineral remnant. Wild food loses leaf width and fruit mass before ending as clipped stems.
- Natural regrowth restores wood, crystal, and wild food gradually in non-winter conditions; rock remains nonrenewable. Original node capacity is migrated for old saves and persists through new save/load round trips.
- Motivate Land now restores existing depleted wood, crystal, and wild-food nodes in its radius instead of incorrectly creating only a raw-food node.
- Crystal Motivator has a visible `motivating` operation loop and inspector state. Its exact 8/10/12-cell tier radii, 100-tick interval, and one-unit pulse remain `VERIFY_RUNTIME`; only its crystal-growth role is treated as supported.

Rejected capture iterations:

- The first sheet accidentally re-entered Camp placement after rebuilding the terrain texture, obscuring the matrix with a large placement ghost and range wash.
- The second sheet removed those overlays but allowed the inspector to cover the exhausted fourth column.
- The accepted third sheet isolates all sixteen states at 1.7x review zoom, keeps the mobile inspector visible, and labels columns 4/3/2/1 solely inside the controlled capture harness.

Status is `FUNCTIONAL / IN_REVIEW`. Resource lifecycle transitions and regrowth behavior are now represented. Corruption-killed vegetation is covered by the later infected-ecology pass; exact Update 2d growth timing, resource spreading into neighboring terrain, trampling/terrain clearing, and all-biome seasonal lifecycle capture remain open.

## Material-aware shoreline pass - 2026-08-12

Controlled outputs are the refreshed seven-biome `review_biome_*_1x.png` sheets.

Corrections:

- The former water boundary used a high-value cyan shallow ring around every body of water, making small ponds look cut out of the terrain and applying the same edge language to sand, grass, marsh, forest, and stone.
- Connected water now transitions through a neighboring-material wet bank, muted shallow-water mix, restrained inner glint, and deep basin. The bank inherits its adjacent biome material rather than using a universal shoreline color.
- Ground cells beside water receive sparse broken wet marks; sand can expose occasional pale shell/foam pixels; forest shore cells gain dark roots; stone gains cool wet faces; marsh, sand, grass, and rock tint water-side reeds independently.
- The shoreline additions operate only on sparse native accent blocks and preserve the cached base-texture design. They do not add a per-frame terrain scan.

The forest, desert, marsh, and island sheets were explicitly compared after the full seven-biome recapture. The muted band is accepted across all four. A later season pass adds winter-specific ice banks; status remains `IN_REVIEW` pending dedicated coast/river/pond zoom sheets, flood/mud transitions, and phone/tablet GPU timing.

## Ground-material joins and infected ecology pass - 2026-08-12

Controlled outputs:

- Refreshed `build/captures/review_biome_*_1x.png` sheets for all seven biomes.
- `build/captures/review_corrupted_resources.png`.

Corrections and rejected iteration:

- Forest, stone, and crystal boundaries previously fell back to a near-black outer ramp. Although their silhouettes were connected, the dark contour made them read as cut-out decals against grass, sand, and marsh. Each family now mixes the neighboring ground into a three-step native-pixel transition before entering its own shadow, midtone, and highlight language.
- The first infected-resource sheet was rejected because the simulation-cell front still ended too abruptly. The second exposed evenly repeated root teeth. The accepted version combines a broad low-opacity stain, irregular material fingers, sparse long roots/spores, a quieter broken rim, and the original connected under-root/bloom masks.
- Runtime corruption now renders below resources. Infected trees use a restrained sick canopy with exposed veins and sparse fruiting bodies; crystals shift toward a diseased magenta ramp with a grounded corruption seam; food plants brown and lose healthy leaf/fruit color; stone is only subtly stained because it is not biologically consumed.
- Corruption is now a real lifecycle input: it withers wood and wild food, blocks natural renewable regrowth, and blocks Crystal Motivator restoration until the ground is reclaimed. Rock remains permanent. These values survive the existing resource save envelope, and regression tests exercise all four cases.
- The full seven-biome batch completed after the shared material-ramp change. Forest, desert, marsh, and island were explicitly inspected at exact 1x; no universal black terrain outline or shoreline palette regression remains.

Status is `FUNCTIONAL / IN_REVIEW`. The joins and infected ecology are accepted at the current desktop review scales. Winter ice banks are covered by the subsequent season correction; remaining terrain work includes threat-intensity variation, corrupted roads/buildings, flood/mud/fire aftermath, terrain-editing visuals, and measured phone/tablet performance.

## Winter shoreline correction - 2026-08-12

Controlled outputs are the refreshed four `review_season_*_1x.png` sheets.

- Winter water boundaries now use a neighboring-material cold bank, a pale broken ice lip, and a muted blue-grey inner shelf rather than the normal dark wet bank.
- Ground-side wet marks become restrained frost staining in winter, and shoreline reeds use a dormant grey-green ramp instead of retaining their summer color.
- Deep water remains visibly open and blue so coastlines and pathing stay readable; the correction is an edge treatment rather than a solid frozen-water replacement.
- Spring and winter sheets were explicitly compared at exact 1x after the change. Building, resource, and shoreline silhouettes remain distinct under broken snow coverage.

Status is `IN_REVIEW`: the seasonal distinction is accepted, while exact freeze/thaw gameplay, ice traversal, flood states, and device performance are still outside this pass.

## Threat-strength corruption and hostile infrastructure pass - 2026-08-12

Controlled output:

- `build/captures/review_hostile_corruption.png`

Simulation and presentation delivered:

- Corruption cells now retain a 250-1000 strength value. The snapshot exposes normalized threat intensity, and the renderer moves from a transparent olive-brown frontier through dark roots into an old magenta core without replacing the underlying terrain relief.
- Drones create typed, saved construction sites and visibly grow corrupted roads, walls, towers, fire pits, and graveyards. Towers attack villagers, fire pits seed corruption, graveyards spawn monsters, player towers can target hostile structures, and divine damage records the official `Fight The Corruption` counter.
- Roads and walls join their cardinal neighbors into continuous infected infrastructure. Large sites use distinct overhead silhouettes: eye/crystal towers, infected fire pits, and a marked graveyard/spawner bed.
- Infected trees, stumps, rock, crystal, and food appear in the same review field so threat shading is judged with ecology rather than against an empty color card.

Rejected iterations:

- The first hostile road/wall sheet was rejected because each one-cell segment appeared as an isolated purple bead. Connected outer roots and narrower living cores replaced those dots.
- A later decay-landmark pass was rejected because a linear per-cell hash created diagonal rows of identical dark scars. The accepted sheet uses jittered large-area anchors, varied low-opacity ash/root scars, and much sparser dead growth.
- The partial construction row was moved above the mobile command bar and the placement-help overlay was removed so all 22/52/82-percent sites remain visible at gameplay zoom.

Status is `FUNCTIONAL / IN_REVIEW`. Hostile construction, combat roles, destruction, achievement progress, snapshots, and save/load are covered. Exact Update 2d costs/timing, four-tier hostile upgrade behavior, enemy-road movement, wall pathing ownership, and mobile stress performance remain open.

## Resource ecotone and terrain-aftermath pass - 2026-08-12

Controlled outputs:

- Refreshed `build/captures/review_biome_forest_1x.png` and seven-biome comparison sheets.
- `build/captures/review_terrain_aftermath.png`.

Terrain integration corrections:

- Ground beside forest, rock, and crystal now receives sparse leaf litter, scree, or mineral shards using the neighboring material palette. These fragments extend the ecotone beyond the ownership contour without drawing a universal outline.
- Earlier per-node grove crowns and common-rock outcrops were superseded: living wood and common stone now disappear into continuous canopy/bedrock materials. Only harvested stumps/rubble and distinct ore/crystal seams remain individually readable.
- The biome capture harness accepts `--review-biome=<id>` for fast exact-1x iteration while retaining the full seven-biome batch gate.

Authoritative aftermath states:

- Mud, floodwater, active fire, and ash are saved simulation cells exposed through snapshots. Mud/flood/fire/ash apply distinct movement penalties; floodwater recedes into mud; fire spreads across combustible terrain, damages vegetation/buildings, is extinguished by rain/snow, and cools into persistent ash.
- Flame and Meteor create authoritative burning terrain instead of presentation-only particles. Rain deterministically seeds sparse wet ground and low-bank flooding without consuming the unrelated simulation RNG stream.
- The renderer joins each surface across neighboring cells, adds low-opacity material-specific edge fingers, draws water ripples and mud depressions sparsely, and renders active flame above tree crowns while scorch/ash remains below them.

Rejected iterations:

- The first aftermath sheet drew one flame and one ash slash per simulation cell, exposing an obvious square/hatch carpet. It was rejected.
- The second separated connected ground stains from sparse block-jittered flame/char landmarks. A third pass added broken edge fringes to remove the remaining hard 8-pixel steps without blurring the pixel art.

Status is `FUNCTIONAL / IN_REVIEW`. The accepted sheet covers visual hierarchy, connection, movement effects, spell ignition, extinguishing, flood-to-mud conversion, snapshots, and save/load. Exact reference flood frequency, fire balance, freeze/thaw traversal, terrain digging/clearing, elevation/cliffs, and phone/tablet profiling remain open.

## Live terrain maintenance and mobile material-density pass - 2026-08-12

Controlled outputs:

- `build/captures/review_terrain_work.png`
- Refreshed `build/captures/review_mobile_phone_hud.png` at 844×390.
- Refreshed `build/captures/review_mobile_tablet_hud.png` at 1024×768.

Simulation and interaction delivered:

- Maintenance Buildings publish saved Clear, Dig, Fill, and Restore cell tasks. Maintainers reserve the cell, use a durable Shovel when available, expose work progress through snapshots, recover from canceled/invalid work, and record per-action progression.
- Clear conserves a bounded harvest into village storage/loose overflow, removes the resource from both runtime and saved blueprint, restores biome ground, refreshes navigation, and rebuilds the cached terrain texture. Dig creates a non-expiring saved hole; Fill removes it; Restore removes mud, flood, or ash.
- Mouse and touch share a brush contract. A second touch pans without ending the brush, right-click/Cancel exits the tool, valid/invalid targets preview distinctly, and the four commands remain visible in the horizontal mobile action scroller.

Visual corrections and review decisions:

- The first terrain-work capture was rejected because cell-corner marks collapsed into colored specks at normal zoom. The accepted pass uses dark-backed 12-pixel action medallions, distinct Clear/Dig/Fill/Restore glyphs, and a separate progress strip while preserving the ground beneath.
- Dug holes use an irregular top-down soil lip, compact dark interior, and a few freshly turned clods; no perspective wall or side facade is introduced.
- Forest crown planes and bedrock plates receive stronger stepped values and thicker restrained contour clusters. Meadow relief is slightly wider in value, while tufts/flowers remain clustered rather than becoming an even noise screen.
- `art/reference/terrain_direction_imagegen_source_v2.png` is retained as a non-shipping provenance study. It established the connected canopy → litter → grass, bedrock → talus → soil, and water → wet-bank material hierarchy; no generated pixels are used at runtime.
- The phone harness reports 44.4-point actions and zero layout errors with simulated sensor/home insets. The tablet harness reports 44.8-point actions and zero layout errors.

Status is `FUNCTIONAL / IN_REVIEW`. The live editing loop and current mobile readability are accepted. Exact reference timings/salvage remain `VERIFY_RUNTIME`; cliff/elevation language, freeze/thaw traversal, chunked partial terrain rebuilds, and physical iPhone/iPad performance certification remain open.

Performance follow-up:

- The first Windows Forward Mobile phone proxy rendered 2,182 simultaneous corruption/aftermath cells at 245.85 ms/frame and about 150.7 MB. Profiling showed repeated per-cell overlays and detailed resource clusters owned the frame.
- Cached GPU masks carry corruption and non-hole aftermath at wide zoom; the resource mask carries ore/crystal/forage signals while living wood/common stone stay inside terrain; camera bounds cull detailed entities; close zoom retains organic corruption and aftermath.
- The identical extreme proxy now measures 8.99 ms/frame and 94.2 MB in the 844×390 phone layout, and 8.52 ms/frame and 94.3 MB in the 1024×768 tablet layout on the Windows Forward Mobile renderer.
- These are repeatable desktop proxy measurements, not physical iOS certification. The later chunked pass below replaces the blocking full-region texture and supersedes these loading numbers.

## Chunked connected-material terrain pass - 2026-08-13

Controlled outputs:

- `build/captures/review_terrain_preview.png`
- `build/captures/review_terrain_chunked.png`
- Refreshed `build/captures/review_biome_forest_1x.png`

Rejected iterations:

- One complete crown per wood resource still read as isolated trees even after its lobes overlapped the forest floor.
- Narrow node-to-node bridges produced vine/necklace chains; broad outlined unions produced worm-like canopy islands. Both were removed rather than polished further.
- Equal treatment for common rock nodes recreated the rejected pebble carpet over otherwise connected geology.

Accepted corrections:

- Living wood is now the connected forest material itself. Broad shared ridges and sparse leaf stitches provide canopy depth without enclosing individual trees; only depletion reveals a stump. Common stone follows the same rule, with only depleted rubble and distinct ore seams entering the object layer.
- Terrain ownership is warped and bilinearly blended across logical cells, then rendered at four material samples per cell and nearest-expanded to the locked eight-pixel world grid. Quiet broad ground fields, restrained forest/stone contours, sparse material-specific accents, and deterministic global coordinates avoid tile and chunk seams.
- A linear-filtered one-cell overview appears immediately. Sixty-four 32×32-cell detailed chunks render on isolated worker threads, prioritize the camera, upload textures only on the main thread, reject stale generations/revisions, and rebuild only chunks touched by a changed cell's 3×3 neighborhood.
- The review harness centers one capture on a four-chunk junction and waits for completion. Automated tests compare adjacent chunks against an equivalent combined render pixel-for-pixel, repeat identical payloads, and verify that a mutated tile changes the result.

Performance follow-up:

- The first chunk implementation required roughly 26.7 seconds for all 64 chunks. Rendering four material samples per cell reduced this to 9.2-9.7 seconds in controlled captures while preserving the eight-pixel output.
- High-resolution Windows Forward Mobile proxies measure: phone 233 ms overview, 786 ms first chunk, 8.59 s all chunks, 11.62 ms average extreme frame, 99.4 MB; tablet 250 ms overview, 765 ms first chunk, 8.61 s all chunks, 11.01 ms average extreme frame, 97.7 MB.
- Status remains `FUNCTIONAL / IN_REVIEW`. Blocking region entry and individual tree/common-rock sprites are resolved. Physical iOS profiling, elevation/cliff language, freeze/thaw traversal, all-biome recapture, and additional material polish remain open.

## Populated material integration and winter traversal pass - 2026-08-13

Controlled outputs:

- Refreshed `build/captures/review_biome_forest_1x.png` with the populated settlement.
- Refreshed `build/captures/review_terrain_chunked.png` centered on a four-chunk junction.
- `art/reference/terrain_populated_direction_imagegen_source_v3.png`, retained as a non-shipping clean-room direction study.

Rejected iterations:

- Repeating scalloped leaf stitches still implied rows of separate crowns and were removed.
- Large smooth canopy gradients formed oversized green blobs; high-contrast cellular canopy regions then read as camouflage. Both were rejected.
- Full-perimeter worn ground around every building formed identical circular halos. It was replaced with entrance traffic plus one category-limited side work yard.
- Smooth stone noise created dark contour rings, while an exact cellular search created an overly regular honeycomb and doubled generation cost. Both implementations were discarded.

Accepted corrections:

- Living wood is represented by one dark continuous under-canopy with dense, irregular leaf-scale flecks. Variation is independent of resource-node centers; there are no living per-tree sprites, countable crowns, or node outlines. Only depletion reveals a stump.
- Common stone is one connected geological material split into warped, broken large plates with restrained fissures and sparse chips. Common node sprites remain hidden; ore, crystal, and depleted rubble remain distinct.
- Meadow relief is low contrast so structures and routes own the hierarchy. Buildings now touch the terrain through a short bent entrance path and, for working categories, one irregular material yard; no universal apron is drawn.
- The broad material field uses three samples per logical cell and nearest-expands to the locked eight-pixel world grid before native one-pixel accents. This preserved the accepted exact-1x appearance while recovering asynchronous generation performance.
- Winter deep water is now authoritative traversable ice with a 1.45 path weight and 0.78 movement multiplier. Freeze/thaw invalidates paths, thaw relocates actors safely to shore, and the state survives snapshots and saves.

Performance and validation:

- Four-chunk-junction capture: first detailed chunk 0.87 seconds, all 64 chunks 8.19 seconds, zero runtime errors.
- High-resolution Forward Mobile proxies: phone 393 ms overview, 910 ms first chunk, 8.96 seconds all chunks, 15.79 ms stress frame, 100.4 MB; tablet 385 ms overview, 896 ms first chunk, 9.05 seconds all chunks, 15.53 ms stress frame, 98.7 MB.
- The full 654-entry simulation regression passes, including deterministic adjacent/combined chunk equality, frozen-water routing, thaw recovery, snapshot exposure, and winter save/restore.

Status remains `FUNCTIONAL / IN_REVIEW`. The forest, common stone, populated ground contact, chunk streaming, and winter traversal contracts are accepted for this milestone. Explicit elevation/cliff mechanics, all-biome recapture after the material change, physical iOS profiling, and per-building-family polish remain open.

## Authoritative topography and strict-overhead rim pass - 2026-08-13

Controlled outputs:

- Refreshed all seven `build/captures/review_biome_*_1x.png` sheets after elevation integration.
- Refreshed `build/captures/map_editor.png` with visible topography tools.

Rejected iteration:

- The first elevation renderer drew a nearly continuous dark one-pixel rim along every high-to-low logical-cell edge. Although deterministic, it exposed a staircase grid across meadow and around the authored starting clearing. That visual was rejected.

Accepted implementation:

- Region blueprints are version two and store one byte per cell for water level plus Low Ground, Highland, and Ridge. Version-one saves/maps derive conservative water/land/rock heights during import.
- Generated elevation comes from the same broad low-frequency topography that forms coast and terrain; the playable starting clearing is level, the authored stone shelf is Highland, and its grass pockets remain on the shelf top.
- Open meadow and canopy communicate elevation through restrained broad value changes. Short broken dark/light rim clusters appear only at geological/crystal transitions or rare two-band drops. There are no side-facing cliff facades, black universal contours, or perspective walls.
- Multi-cell buildings require a single level foundation. Highland/Ridge cells remain traversable but add deterministic 1.18/1.36 route weights until roads improve them.
- The local map editor exposes Low Ground, Highland, and Ridge brushes without replacing terrain materials, previews the height values, and persists them through `.rtrmap` packages and play tests.

Validation:

- All seven biome sheets completed with zero render errors. Desert geology, marsh value bands, island coasts, forest canopy, and authored shelves remain readable at exact 1x.
- The full 654-entry regression passes blueprint determinism, version-one migration, elevation round trips, uneven-foundation rejection, highland path weighting, terrain/elevation chunk mutation, seam equality, saves, and all existing simulation scenarios.
- Current phone Forward Mobile proxy with elevation contours: 414 ms overview, 953 ms first detailed chunk, 8.99 seconds all chunks, 15.07 ms stress frame, and 100.7 MB static memory.

Status remains `FUNCTIONAL / IN_REVIEW`. Explicit topography, foundation rules, route weights, strict-overhead visual language, editor support, and seven-biome review are accepted. Physical iOS certification and per-building-family polish remain open.

## Faction-aware infrastructure behavior - 2026-08-13

This is a simulation closeout associated with the already-reviewed connected road/wall art:

- Friendly and hostile actors now use separate authoritative route graphs.
- Settlement walls block both graphs so monsters route around or approach them as attack targets; settlement roads improve both graphs.
- Completed corrupted walls block friendly agents but remain traversable to monsters/drones. Corrupted roads apply a provisional 0.72 hostile path weight and 1.22 hostile movement multiplier while giving villagers no benefit.
- Hostile completion/destruction, settlement wall destruction, winter freeze/thaw, and save/load rebuild or update both graphs and invalidate actor routes safely.
- Full regression covers faction ownership, road weights, movement multipliers, wall passability, destruction release, and save/load reconstruction. Exact Update 2d hostile-road speed and four-tier balance remain `VERIFY_RUNTIME`.

## Cullis Gate and buried-loot visual pass - 2026-08-13

Controlled outputs:

- `build/captures/review_cullis_gate_2x.png`
- `build/captures/review_magic_circles_loot_2x.png`

Accepted implementation:

- The Cullis Gate is a strict-overhead masonry mechanism with a readable violet rift, stable-to-critical color progression, visible lightning, damage, and an overloaded destroyed state. A held payload follows the pointer inside a separated three-finger Hand silhouette rather than hiding behind the spell glyph.
- Buried sites use low-profile runic marks embedded directly into the ground. The symbols preserve the underlying connected meadow/canopy/geology and never become freestanding scenery or reveal their payload in advance.
- A suspicious key has a large ring, long shaft, and tooth silhouette; the loot box uses a compact reinforced walnut lid, two brass straps, and an oversized central lock. Both remain distinct at normal mobile play scale without borrowing source pixels.
- Revealed boxes track Hand-poke movement visually, while all reward/opening logic remains authoritative simulation state rather than presentation-only animation.

Validation:

- Focused Hand/Cullis and loot scenarios pass pickup, carried population accounting, safe release, sacrifice, lightning/overload, deterministic site generation, excavation, physical key opening, Organizer and Doggo automation, weighted/trash rewards, seven achievement hooks, and exact save/load state hashes.
- The full 671-entry regression passes with zero parser/runtime errors. Both desktop review captures completed with zero render errors.

Status is `FUNCTIONAL / IN_REVIEW`. Silhouette/readability and connected-terrain integration are accepted for this milestone; exact reference loot weights, circle-clear timings, Cullis balance, animation polish, physical-device contrast, and final per-family art approval remain open.

## Four-sample populated terrain and regional mobile review - 2026-08-13

Controlled outputs:

- Refreshed `build/captures/review_biome_forest_1x.png`.
- `build/captures/review_mobile_phone_regions_drawer.png` at 844×390.
- `art/reference/terrain_populated_direction_imagegen_source_v4.png`, retained as a non-shipping clean-room direction study.

Rejected iteration:

- The first accent revision emitted a typed-array error once per affected chunk. Its capture was rejected immediately; no image from that run is an approval artifact.
- Three uneven material samples per cell improved speed but retained a visible coarse rhythm in some canopy/ecotone boundaries. That quality setting was superseded.

Accepted corrections:

- Four uniform material samples per logical cell produce consistent two-pixel ownership steps at the native eight-pixel grid. Chunk seams remain exact and all generation remains asynchronous.
- The forest ramp has a deeper under-canopy, stronger midtone separation, and denser irregular one-pixel leaf clusters without ever drawing a complete crown, trunk, or countable individual tree.
- Meadow moisture/soil fields use broader restrained value changes plus sparse light/dark grass clusters. Bedrock retains connected large plates and narrow fissures instead of spawning common-rock objects.
- The phone regional drawer exposes touch-sized migrant count, cargo resource, and cargo quantity controls, with live route contents/timers below. At 844×390 it reports 44.4-point targets and zero safe-area/layout errors.

Validation:

- Forest capture completed with zero renderer errors.
- The full 671-entry regression passes deterministic adjacent/combined chunk equality, regional multi-resource conservation, every existing simulation system, and exact save/load hashes.

Status remains `FUNCTIONAL / IN_REVIEW`. The fourth material-quality pass and regional phone layout are accepted; all-biome/season recapture, refreshed tablet logistics, physical-device performance, and final production-art approval remain open.

## Continuous-canopy filter and divine-structure pass - 2026-08-13

Controlled outputs:

- Refreshed `build/captures/review_biome_forest_1x.png` after the canopy-component filter.
- `build/captures/review_god_structures_2x.png` showing two God Towers, a connected God Wall line, Illuminate, Charm/Cold statuses, and Earthquake holes.

Rejected iteration:

- The first divine-structure vignette exposed several small dark forest components that still read as standalone trees. Although the renderer contained no tree sprite, the material silhouette violated the continuous-canopy rule and the capture was rejected.

Accepted corrections:

- Forest rendering now builds a visual-only connected-component map. Cardinally connected forest masses smaller than 96 logical cells dissolve into surrounding meadow material; broad forests retain the dark shared canopy. Diagonal touches cannot let a detached crown inherit the area of a distant woodland.
- The simulation terrain and resource data remain unchanged. This is a clean presentation filter, so harvest amounts, path costs, save data, and deterministic generation retain their authoritative values.
- God Walls are flush one-cell divine sigil plates with cardinal braces; God Towers are strict-overhead octagonal mechanisms with runic arms and a rotating reticle. Neither uses a side facade or perspective tower body.
- Illuminate uses sparse ground glints over a restrained field instead of an opaque screen tint. Charmed and chilled monsters receive distinct thin status rings and compact marks that remain readable without recoloring the whole actor.

Validation:

- Automated terrain tests reject a 3×3 tree-sized component while preserving an 11×11 connected forest mass.
- Focused divine-power tests cover placement rejection, influence reservation, wall path blocking, tower attacks, destruction/dispel release, save/load, Charm/Cold/Earthquake/Illuminate/Recall/Storm, and the official Recall achievement.
- The full 672-entry regression passes with zero parser/runtime errors.

Status remains `FUNCTIONAL / IN_REVIEW`. The standalone-tree failure is corrected in code and test coverage. Final canopy palette polish, broader biome/season review, physical-device contrast, and per-family production-art approval remain open.

## Native-pixel canopy and late-system art pass - 2026-08-13

Controlled outputs:

- `build/captures/review_biome_forest_1x.png` at exact native world scale.
- `build/captures/review_building_families_1x.png` with populated strict-overhead building families.
- `build/captures/review_mobile_phone_hud.png` and `review_mobile_phone_build_drawer.png` through the Forward Mobile renderer.

Rejected iterations:

- Eight material samples per cell removed the block pattern but took longer than the 45-second terrain-stream gate; it was rejected as unsuitable for mobile.
- The first six-sample revision exposed concentric value-noise rings caused by squared coordinate hashing. That image was rejected despite its improved canopy continuity.

Accepted corrections:

- Six samples per logical cell break the former regular 2×2 material blocks while retaining bounded asynchronous generation.
- Coordinate hashing now uses signed linear coordinates and a deterministic bit avalanche. The equation-driven rings disappear from meadow, canopy, and geology without adding blurred filtering.
- Canopy interiors use overlapping continuous ridge fields and sparse broken highlights; they never reconstruct a circular crown or trunk. The 96-cell component filter continues to remove detached tree-sized material islands.
- Housing quality and occupancy branches gain different roof/material density, garden/annex treatments, and reinforced progression. Catjeet ears/tails, Nephilim wings/halo, animal ghosts, Ice Ballista crylithium nodes, and the Lightning Rod mechanism are readable from a true overhead view.

Validation:

- The 844×390 phone proxy reports zero safe-area or touch-target errors and 44.4-point primary controls.
- The generated ledger contains 478 shipping records plus four historical removals; all 482 records are test-enforced.
- The full 741-entry regression passes with all 113 official goal bindings and zero parser/runtime errors.

Status remains `FUNCTIONAL / IN_REVIEW`. The material defects and standalone-tree failure are corrected. Final per-family polish, full season/biome recapture at the six-sample setting, physical-device profiling, and promotion from `IN_REVIEW` to `APPROVED` remain open.

## Native-noise streaming optimization - 2026-08-13

Accepted correction:

- Five deterministic native `FastNoiseLite` image fields now supply material warp, relief, patch, and detail values for each chunk. The renderer retains six uniform ownership samples per logical cell, continuous canopy/bedrock silhouettes, the 96-cell canopy filter, nearest-neighbor presentation, and exact world-coordinate continuity.
- The sparse accent hash remains separate from material ownership, so the prior concentric-ring failure cannot re-enter the broad terrain shapes.

Validation:

- Adjacent chunks remain pixel-identical to a combined render across the same boundary.
- At the standardized 844x390 Forward Mobile proxy, the immediate overview completes in 351 ms, the first detailed chunk in 1.54 seconds, and all 64 chunks in 19.68 seconds. This is about a 34% reduction in full-detail completion time versus the preceding six-sample renderer.
- The deliberately extreme 2,182-cell corruption/aftermath scene averages 15.09 ms per frame with 104.5 MB static memory, remaining inside the 30 FPS desktop-proxy budget.

Status remains `FUNCTIONAL / IN_REVIEW`. Physical iPhone/iPad profiling and broader biome/season approval are still required.

## Ranger Lodge and Outpost role pass - 2026-08-13

Controlled output:

- Refreshed `build/captures/review_catalog_food_water_1x.png` through the Forward Mobile renderer at 1280x720.

Accepted corrections:

- The established Ranger Lodge now gains a compact overhead bow emplacement while retaining its roof, bow rack, animal tracks, and bedroll language.
- The Outpost keeps a smaller palisaded footprint and only replaces its practice target with a mounted bow mechanism at its final tier. The strict-overhead mechanism uses a braced deck, central stock, and symmetrical limbs rather than a side-view watchtower facade.
- The catalog harness now includes the previously omitted Lightning Rod and Ice Ballista so future complete-family captures cannot silently skip their art.

Validation:

- The focused Ranger/Outpost simulation scenario passes with zero engine or script errors.
- The refreshed food/water catalog confirms that canopy masses remain connected around the building sheet and no living individual-tree sprite has returned.

Status remains `FUNCTIONAL / IN_REVIEW`. Final per-tier comparison sheets and physical-device contrast approval remain open.

Tablet follow-up:

- The refreshed 1024x768 tablet harness captured HUD, construction, regional network, mode selection, world map, region browser, and custom mode screens with zero layout or renderer errors.
- Pause, primary action, and regional controls each measure 44.8 points in the tablet proxy. The regional drawer keeps migrant count, cargo type, cargo quantity, and destination actions visible without covering the permanent speed or bottom command controls.
