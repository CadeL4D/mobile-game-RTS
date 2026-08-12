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
