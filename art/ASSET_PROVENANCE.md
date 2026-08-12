# Asset provenance

All project art must be original and recorded here. No reference-game source assets may be copied, extracted, traced, or redistributed.

| Asset | Method | Date | Purpose |
|---|---|---:|---|
| `generated/world_map_v1.png` | OpenAI built-in image generation; original prompt, no image inputs | 2026-08-12 | Shippable prototype world-map background |
| `reference/world_map_visual_direction_v1.png` | Copy of the generated source retained inside the workspace | 2026-08-12 | Visual direction and biome readability review |
| `generated/buildings/camp_tier1_v1.png` | OpenAI built-in image generation on a flat chroma-magenta field; background removed locally with the imagegen skill helper | 2026-08-12 | Concept-only; removed from runtime pending a native 90-degree top-down pixel replacement |
| `reference/camp_tier1_imagegen_source_v1.png` | Unmodified generated source retained inside the workspace | 2026-08-12 | Reproducibility, edge cleanup, and art review |
| `generated/buildings/farm_tier1_v1.png` | OpenAI built-in image generation on flat chroma magenta; hard alpha extraction and one-pixel edge contraction with the imagegen helper | 2026-08-12 | Concept-only; removed from runtime pending a native 90-degree top-down pixel replacement |
| `reference/farm_tier1_imagegen_source_v1.png` | Unmodified generated source retained inside the workspace | 2026-08-12 | Reproducibility, silhouette, and mobile scale review |
| `generated/buildings/animal_pen_tier1_v1.png` | OpenAI built-in image generation on flat chroma magenta; soft alpha extraction and one-pixel edge contraction with the imagegen helper | 2026-08-12 | Concept-only; removed from runtime pending a native 90-degree top-down pixel replacement |
| `reference/animal_pen_tier1_imagegen_source_v1.png` | Unmodified generated source retained inside the workspace | 2026-08-12 | Reproducibility, silhouette, and mobile scale review |
| `generated/buildings/crystal_golem_combobulator_tier1_v1.png` | OpenAI built-in image generation on flat chroma magenta; soft alpha extraction and one-pixel edge contraction with the imagegen helper | 2026-08-12 | Concept-only; removed from runtime pending a native 90-degree top-down pixel replacement |
| `reference/crystal_golem_combobulator_tier1_imagegen_source_v1.png` | Unmodified generated source retained inside the workspace | 2026-08-12 | Reproducibility, silhouette, and mobile scale review |
| `generated/buildings/clinic_tier1_v1.png` | OpenAI built-in image generation on flat chroma magenta; soft alpha extraction | 2026-08-12 | Rejected concept: camera was too frontal/isometric for the world projection; not integrated |
| `reference/clinic_tier1_imagegen_source_v1.png` | Unmodified rejected generated source retained inside the workspace | 2026-08-12 | Documents the projection rejection and avoids accidental reuse |
| `generated/buildings/clinic_tier1_v2.png` | OpenAI built-in image generation on flat chroma magenta; soft alpha extraction and one-pixel edge contraction with the imagegen helper | 2026-08-12 | Rejected concept: high-overhead but not completely top-down and not native-resolution pixel art |
| `reference/clinic_tier1_imagegen_source_v2.png` | Unmodified generated source retained inside the workspace | 2026-08-12 | Reproducibility, top-down projection, silhouette, and mobile-scale review |
| `generated/buildings/clinic_tier1_v3.png` | OpenAI built-in image generation concept; chroma extraction followed by hard-alpha, no-dither 32-color reduction to a native 56×72 pixel grid | 2026-08-12 | Non-shipping pipeline test: correct projection and pixel grid, but still denser than the audited minimal reference language |
| `reference/clinic_tier1_imagegen_source_v3.png` | Unmodified 90-degree top-down generated source retained inside the workspace | 2026-08-12 | Reproducibility and pixel-reduction source |
| Runtime terrain/building/entity/world-object/event/spell shapes | Original Godot drawing code in `presentation/scripts/world_view.gd` | 2026-08-12 | Clean-room native-resolution 90-degree top-down first pass; 451 shipping ledger records remain in review |
| Runtime building/job/resource/spell/event/mobile-UI icons | Original Godot image construction in `presentation/scripts/pixel_icon_factory.gd` | 2026-08-12 | Clean-room 20/24-pixel nearest-neighbor first pass; no generated or reference pixels used |

Final prompt for the generated world map: an original 16:9 top-down pixel-art fantasy continent with six distinct biome families, irregular coasts/rivers/islands, mobile readability, no labels, logos, trademarks, existing-game geography, or copied imagery.

Final prompt for the generated Camp: one original high top-down three-quarter-view temporary settlement hub with three patched tents, central stone-ring campfire, logs, rocks, notice board, bedrolls, rope and boundary stakes; crisp limited-palette pixel art; no people, text, logo, UI, copied imagery, or external shadow; isolated on uniform `#ff00ff` for alpha extraction.

Final prompt for the generated Farm: one original high top-down three-quarter-view first-tier farm with four irregular crop rows, timber-and-canvas shelter, barrels, irrigation trough, tools, sacks, uneven fence and clear entrance; crisp limited-palette pixel art; no people, animals, text, logo, UI, copied imagery, or external shadow; isolated on uniform `#ff00ff` for alpha extraction.

Final prompt for the generated Animal Pen: one original high top-down three-quarter-view first-tier timber herd enclosure with a clearly open gate, patched shade, trough, hay, feed sacks, ropes, and hoof-worn ground; crisp limited-palette pixel art; no people, animals, text, logo, UI, copied imagery, or external shadow; isolated on uniform `#ff00ff` for alpha extraction.

Final prompt for the generated Crystal Golem Combobulator: one original high top-down three-quarter-view 7x7 magical workshop with chunky stone foundations, timber braces, copper machinery, cyan crystal growth chamber, essence conduits, a clear lower entrance, crates, and attached tools; crisp readable strategy-game pixel art; no text, logo, UI, terrain, copied imagery, or external shadow; isolated on uniform `#ff00ff` for alpha extraction.

Final prompt for the Clinic v3 pipeline test: rebuild the Clinic from a mathematically straight-down 90-degree orthographic camera with zero perspective convergence, an axis-aligned 6×8 footprint, no visible wall facades, a partially roofed upper section, lower entrance gap, and top-visible cot, herbs, bandages, water and medicine props; authentic compact strategy-game pixel composition, no people, text, UI, terrain, copied imagery, or external shadow; isolated on uniform `#ff00ff`, then reduced to a native 56×72 hard-edged 32-color sprite. This output established the processing pipeline but is not approved final art.

Building projection rule established by the Clinic review: production sprites use a 90-degree orthographic overhead camera, align to rectangular terrain footprints rather than isometric diamonds, show no exterior facades, render at native footprint-derived resolution with hard alpha and a limited palette, and retain overhead-readable entrances and functional props.
