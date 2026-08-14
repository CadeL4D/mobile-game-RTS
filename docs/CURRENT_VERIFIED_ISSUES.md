# Current Verified Issues

This is the short, evidence-backed defect list. It intentionally excludes guesses and feature wishes.

## Open blockers

### VI-001 - Physical locations are not yet a complete hauling simulation

- **Fixed portion:** normal live resource changes now pass through the physical inventory API; insufficient consumption is atomic, reservations are respected, oversized additions split into bounded stacks, starting goods are placed on the ground, and schema 5 saves physical stock only once. The `resources` dictionary is now a derived UI/read projection for physical goods.
- **Remaining proof:** several older job flows still use aggregate availability instead of reserving a particular stack, walking to it, carrying it, and delivering it to a real building buffer.
- **Impact:** conservation and save consistency are protected, but the full Rise to Ruins item-by-item hauling behavior is not complete.
- **Required fix:** migrate each worker flow from aggregate consume/add calls to stack reservations and explicit ground/container/carrier transitions.

### VI-002 - Extracted subsystem files are contracts, not integrated gameplay

- **Proof:** the new task, production, needs, population, animal, trade, combat, corruption, logistics, and spell classes have focused contract tests, but most are not called by the authoritative tick.
- **Impact:** counting these files as completed systems double-counts the older live implementation.
- **Required fix:** delegate each old live method to one extracted owner, add a public-command scenario, and remove the duplicate path before moving to the next subsystem.

### VI-003 - Reference parity remains unverified

- **Proof:** the current catalogs contain 148 `VERIFY_RUNTIME` and 190 `WIKI_SUPPORTED` labels.
- **Impact:** names/counts may be useful leads, but exact costs, rates, capacities, graph edges, and behavior cannot be called faithful yet.
- **Required fix:** attach build, screenshot/state, observed value, source, and parity-test ID per record. Never bulk-promote evidence.

### VI-004 - Save replacement is recoverable but not fully atomic on Windows development builds

- **Proof:** when rename-over-target fails, the fallback removes the target and then renames the verified temporary file. `.bak1` preserves the last verified save, but a crash can occur between those operations.
- **Impact:** primary save replacement can be interrupted, though backup recovery should retain the previous state.
- **Required fix:** use a platform-native replace operation where available and add interruption/corrupt-primary/disk-full recovery tests plus user notification.

### VI-005 - No unsigned IPA has been produced yet

- **Proof:** `.github/workflows/build-unsigned-ipa.yml` and the iOS preset exist only in the working tree; there is no successful macOS run or uploaded IPA.
- **Impact:** iOS export, Xcode archive, and unsigned packaging remain configured rather than empirically proven.
- **Required fix:** commit and push the files, run **Build unsigned iOS IPA**, and retain the successful logs, IPA, and SHA-256 artifact.

### VI-006 - iPhone/iPad certification is absent

- **Proof:** existing measurements are Windows/mobile-renderer proxies, not physical-device results.
- **Impact:** safe areas, haptics, thermal behavior, memory, 30 FPS presentation, 10 Hz simulation, suspend/resume, and install behavior are unproven on iOS.
- **Required fix:** run the device matrix and save captures/profiles for an iPhone 12-class phone and a 9th-generation iPad.

### VI-007 - Art and audio are not production complete

- **Proof:** all 478 shipping sprite records are still `IN_REVIEW`; audio is procedural prototype infrastructure rather than the promised original soundtrack and complete SFX set.
- **Impact:** asset count cannot be presented as approved quality or coverage.
- **Required fix:** approve every asset from 1x in-game phone/tablet captures and create, mix, route, and provenance-record production audio.

### VI-008 - Catalog totals overstate reachable gameplay

- **Proof:** 113 achievement definitions and 47 perk definitions exist, but catalog presence is not proof that every achievement is reachable through normal play or every perk has a tested consumer.
- **Impact:** progression can appear complete in data while effects or prerequisites remain shallow/inert.
- **Required fix:** normal-play scenario tests for every achievement and one focused consumer test for every perk modifier.

## Confirmed fixes

- The strict full test run passes: 43 test groups, 488 assertion call sites, 741 loaded content entries, and no hidden Godot error marker.
- Schema 5 eliminates the duplicate physical-resource save field and migrates schema-4 virtual pools without trusting stale aggregate stock.
- Normal construction, upgrades, production, trade, needs, equipment, trash, towers, spells, and resurrection now mutate stock through one guarded inventory API.
- Starting supplies no longer occupy a phantom Camp container; they spawn as bounded ground stacks at the region starting cell.
- UI/text scale, left-handed layout, panel auto-pause, reduced-motion weather/effects, and haptic settings now have an in-app settings surface and live consumers.
- Unsupported evidence promotions were restored; current evidence counts are recorded in `AUDIT_LOG.md`.
- New stack/reservation invariants, plural recipe outputs, unique item production, task deduplication, exact Doggo key use, empty-coop behavior, tower resource ordering, and spell lookup have focused tests.
- Stateful extracted services clear between regions.
- Live over-capacity husbandry and Clucker slaughter yields are corrected and regression-tested.
- The spell category selector is now radial and touch-sized.
- The unsigned-IPA workflow rejects hidden test errors and malformed or accidentally signed packages.
