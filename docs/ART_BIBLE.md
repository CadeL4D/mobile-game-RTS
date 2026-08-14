# Ruinward clean-room sprite bible

## Locked projection and density

The shipping world art uses a **90-degree orthographic top-down camera**. Terrain and building footprints are axis-aligned rectangles. Exterior front/side facades, isometric diamonds, perspective convergence, and three-quarter illustration cameras are rejected.

World art is authored at native logical resolution:

- One terrain cell is 8×8 pixels.
- A building canvas is its footprint in cells × 8, plus at most four pixels of overscan on each edge.
- Villager bodies fit an 8×12 canvas; job/equipment layers share that canvas.
- Most dropped resources fit 8×8; animals and monsters generally fit 10–16 pixels per side.
- Hard alpha only, nearest-neighbor filtering, no antialiasing, no subpixel placement, no post-render smoothing.
- One-pixel primary outlines, occasional two-pixel structural masses, three or four tones per material, and a small accent palette.

## Reference findings

The official full-resolution settlement screenshots show that most work buildings are not illustrated houses. They are open work yards made from thin perimeter posts, one partial roof/workstation, and a few large resource-specific props. Housing uses a compact top-visible roof. Towers, fountains, walls, roads, fields, and resource nodes remain equally coarse. Characters are tiny compared with the footprints, and decoration never hides paths, entrances, stored materials, or worker activity.

Authoritative visual references:

- [Official Steam settlement screenshot—Lumber Shacks and housing](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/328080/ss_17ba3c46b8c62ec81d709499a1fa3e3f4afd9de3.1920x1080.jpg)
- [Official Steam wide village screenshot—production, farms, defenses, and resources](https://cdn.akamai.steamstatic.com/steam/apps/328080/ss_b9451ef13da675084783e87af293def31637bb12.1920x1080.jpg)
- [Official Steam store page](https://store.steampowered.com/app/328080/Rise_to_Ruins/)
- [Current building catalog](https://rise-to-ruins.fandom.com/wiki/Category%3ABuildings)

These references define visual grammar and scale only. No source image is traced, cropped, recolored, extracted, or shipped.

## Original visual grammar

### Buildings

- Read the footprint first, function second, tier third.
- Harvesting and production buildings use open yards with visible input/output stacks.
- Civics use one unmistakable symbol or workstation: a cot and herb shelf for a Clinic, hammers and spare boards for Maintenance, cargo bundles for Couriers, stalls for a Marketplace.
- Housing uses roof masses with a clear entrance gap; capacity upgrades add annexes or beds rather than mere hue changes.
- Magic uses sparse concentric geometry, crystal cores, and emissive pixels; it never becomes a smooth glow illustration.
- Every upgrade adds or replaces physical pixel clusters: stations, containers, masonry, mechanisms, defenses, or work positions.
- Construction states grow the actual silhouette. Damage removes clusters and exposes dark gaps. Fire, ice, electricity, corruption, and dismantling are separate overlay layers.

### Actors

- Four directional silhouettes; two-frame walks at minimum.
- Head/torso/feet remain distinguishable at 1× without facial detail.
- Jobs are color-and-tool overlays, not 25 wholly separate bodies.
- Carried resources and equipment are independent layers.
- Animal and monster identity comes from body proportion, gait, and one accent—not texture noise.

### Terrain and resources

- Base tiles use broad clusters and sparse variants, not per-pixel noise.
- Borders, water, roads, walls, snow, mud, burn, and corruption use deterministic connectivity variants.
- Trees, rocks, crystals, crops, and dropped items retain empty space around their silhouettes.
- Biome palettes share value structure so selection, corruption, hazards, and mobile UI remain readable everywhere.

## Review gates

Every sprite family must pass:

1. Native 1× silhouette and function review on a neutral field.
2. Crowded-village review beside at least three similarly sized families.
3. Mobile capture under bright day, night, rain, snow, corruption, damage, and selection overlays.
4. Palette/alpha validation: no partial alpha, no unapproved colors, no filtering, no missing frames.
5. Clean-room review: no traced contours, copied pixels, copied atlases, or exact source composition.

The generated [sprite ledger](../art/sprite_ledger.json) is exhaustive and test-enforced. The current baseline contains 478 shipping records at `IN_REVIEW` and four historical records at `LEGACY_REMOVED`. `IN_REVIEW` means an original native-pixel runtime path now exists; it does **not** mean the sprite has passed the three comparison/mobile review rounds or is final art. Nothing advances to `APPROVED` without those reviews.

The runtime baseline is code-native: `world_view.gd` draws world sprites at their logical pixel size, and `pixel_icon_factory.gd` creates 20/24-pixel UI textures. The earlier generated building images remain concept and pipeline evidence only. They must never be reintroduced into the runtime renderer without a new projection, density, clean-room, and mobile review.
