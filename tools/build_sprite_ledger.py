"""Build the exhaustive clean-room sprite-production ledger from content data."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content" / "data"
OUTPUT = ROOT / "art" / "sprite_ledger.json"

BUILDING_STATES = [
    "foundation", "construction_25", "construction_50", "construction_75",
    "complete", "paused", "missing_worker", "missing_input", "full_output",
    "damaged_light", "damaged_medium", "damaged_severe", "burning",
    "frozen", "corrupted", "reclaimed", "dismantling", "destroyed", "rubble",
]
ACTOR_CLIPS = [
    "idle", "walk", "run", "sleep", "eat", "drink", "carry", "work",
    "attack", "hit", "flee", "status", "die", "corpse", "ghost",
]


def load(name: str) -> dict:
    return json.loads((CONTENT / name).read_text(encoding="utf-8"))


def building_operation_states(building: dict) -> list[str]:
    category = building["category"]
    states: list[str] = []
    if category == "towers":
        states += ["tracking", "firing", "reloading", "no_ammo", "no_energy"]
    elif category == "golems":
        states += ["charging", "forming", "deployed", "at_capacity", "no_energy"]
    elif category == "magic":
        states += ["unpowered", "powered", "praying", "essence_flow"]
    elif category == "lighting":
        states += ["unlit", "lit", "low_energy"]
    elif category == "trash":
        states += ["receiving", "processing", "burning_waste", "blocked_output"]
    elif category == "roads":
        states += ["connected_variants", "debris"]
    elif category == "walls":
        states += ["connected_variants", "gate_open", "gate_closed"]
    elif category not in ["housing", "town_center"]:
        states += ["operating"]
    return states


def actor_size(actor_id: str, kind: str) -> list[int]:
    if kind in ["villager", "trader"] or actor_id in ["villager", "nephilim", "catjeet"]:
        return [8, 12]
    if actor_id in ["beefalo", "entler"]:
        return [16, 16]
    if actor_id in ["rous", "clucker", "doggo", "doofy_doggo"]:
        return [12, 12]
    if "golem" in actor_id:
        return [16, 18]
    if actor_id in ["slime", "blood_slime", "trashy_slime", "fire_elemental"]:
        return [14, 14]
    return [10, 14]


def build() -> dict:
    buildings = load("buildings.json")["buildings"]
    resources = load("resources.json")["resources"]
    jobs = load("jobs.json")["jobs"]
    actors_meta = load("actors_events_meta.json")
    actors = actors_meta["actors"]
    events = actors_meta["events"]
    world = load("modes_biomes_spells.json")
    spells = world["spells"]
    biomes = world["biomes"]
    sprites: list[dict] = []

    for building in buildings:
        if building["category"] == "legacy":
            sprites.append({
                "id": f"building.{building['id']}", "family": "building",
                "content_id": building["id"], "shipping": False,
                "status": "LEGACY_REMOVED", "evidence": building.get("evidence", "LEGACY_REMOVED"),
            })
            continue
        footprint = building.get("footprint", [5, 5])
        canvas = [footprint[0] * 8 + 8, footprint[1] * 8 + 8]
        states = BUILDING_STATES + building_operation_states(building)
        for tier in range(1, int(building.get("tiers", 1)) + 1):
            sprites.append({
                "id": f"building.{building['id']}.tier_{tier}",
                "family": "building", "content_id": building["id"], "tier": tier,
                "category": building["category"], "footprint": footprint,
                "native_canvas": canvas, "views": ["world", "build_icon", "placement_ghost"],
                "states": states, "projection": "orthographic_top_down_90",
                "palette_budget": 24, "shipping": True,
                "status": "IN_REVIEW", "runtime_implementation": "world_view_minimal_building_renderer+pixel_icon_factory",
            })

    for actor in actors:
        actor_id = actor["id"]
        kind = actor.get("kind", "actor")
        clips = ACTOR_CLIPS.copy()
        if kind == "animal":
            clips += ["birth", "graze", "domesticated", "slaughter"]
        elif kind == "monster":
            clips += ["spawn", "corrupted", "construct_enemy"]
        elif "golem" in actor_id:
            clips += ["forming", "repair", "degrading", "dispel"]
        sprites.append({
            "id": f"actor.{actor_id}", "family": "actor", "content_id": actor_id,
            "kind": kind, "native_canvas": actor_size(actor_id, kind),
            "directions": 4, "clips": sorted(set(clips)), "frames_per_motion": 2,
            "palette_budget": 12, "shipping": True, "status": "IN_REVIEW",
            "runtime_implementation": "world_view_minimal_actor_renderer",
        })

    for job in jobs:
        sprites.append({
            "id": f"job_overlay.{job['id']}", "family": "job_overlay", "content_id": job["id"],
            "native_canvas": [8, 12], "views": ["actor_layer", "jobs_icon"],
            "states": ["idle", "working", "carrying", "tool_action"],
            "palette_budget": 4, "shipping": True, "status": "IN_REVIEW",
            "runtime_implementation": "world_view_job_marker_layer+pixel_icon_factory",
        })

    for resource in resources:
        sprites.append({
            "id": f"resource.{resource['id']}", "family": "resource", "content_id": resource["id"],
            "group": resource.get("group", "misc"), "native_canvas": [8, 8],
            "views": ["ground_single", "ground_stack", "carried", "ui_icon"],
            "states": ["fresh", "reserved", "decaying"], "palette_budget": 8,
            "shipping": True, "status": "IN_REVIEW",
            "runtime_implementation": "world_view_resource_glyph_renderer",
        })

    for spell in spells:
        sprites.append({
            "id": f"spell.{spell['id']}", "family": "spell", "content_id": spell["id"],
            "native_canvas": [24, 24], "views": ["ui_icon", "target_cursor", "world_fx"],
            "states": ["target_valid", "target_invalid", "cast", "sustain", "impact", "fade"],
            "palette_budget": 12, "shipping": True, "status": "IN_REVIEW",
            "runtime_implementation": "pixel_icon_factory+world_view_minimal_spell_fx",
        })

    for biome in biomes:
        sprites.append({
            "id": f"terrain.{biome['id']}", "family": "terrain", "content_id": biome["id"],
            "native_canvas": [8, 8], "views": ["base", "edge_autotile", "minimap"],
            "states": ["spring", "summer", "autumn", "winter", "wet", "dry", "frozen", "snow", "mud", "corrupted", "burned"],
            "variants_minimum": 12, "palette_budget": 8, "shipping": True,
            "status": "IN_REVIEW", "runtime_implementation": "native_8px_terrain_texture",
        })

    for event in events:
        sprites.append({
            "id": f"event.{event['id']}", "family": "event", "content_id": event["id"],
            "native_canvas": [32, 32], "views": ["warning_icon", "world_fx"],
            "states": ["warning", "active", "aftermath"], "palette_budget": 12,
            "shipping": True, "status": "IN_REVIEW",
            "runtime_implementation": "pixel_icon_factory+world_view_event_atmosphere",
        })

    terrain_objects = [
        "tree", "stump", "dead_tree", "rock", "iron_rock", "gold_rock", "crystal",
        "crop", "wild_food", "mushroom", "flower", "hole", "shallow_water", "deep_water",
        "fire", "ash", "rubble", "corruption", "corpse", "loot_marker",
    ]
    for object_id in terrain_objects:
        sprites.append({
            "id": f"world_object.{object_id}", "family": "world_object", "content_id": object_id,
            "native_canvas": [16, 16], "states": ["idle", "selected", "harvested", "damaged", "seasonal", "corrupted"],
            "variants_minimum": 4, "palette_budget": 10, "shipping": True,
            "status": "IN_REVIEW", "runtime_implementation": "world_view_minimal_world_object_renderer",
        })

    ui_sets = [
        "hud_population", "hud_resources", "hud_influence", "hud_energy", "hud_faith",
        "hud_time_weather", "hud_speed", "hud_problems", "construction_categories",
        "harvest_tools", "terrain_tools", "road_tools", "wall_tools", "minimap",
        "data_maps", "selection", "validity", "health_work_bars", "thoughts_warnings",
        "goals_perks_chests", "trade_migration_courier", "editor_tools", "touch_gestures",
    ]
    for ui_id in ui_sets:
        sprites.append({
            "id": f"ui.{ui_id}", "family": "ui", "content_id": ui_id,
            "native_canvas": [24, 24], "states": ["normal", "pressed", "disabled", "alert"],
            "palette_budget": 10, "shipping": True, "status": "IN_REVIEW",
            "runtime_implementation": "pixel_icon_factory",
        })

    counts: dict[str, int] = {}
    for sprite in sprites:
        counts[sprite["family"]] = counts.get(sprite["family"], 0) + 1
    return {
        "version": 1,
        "reference_build": "Rise to Ruins Update 2d build 12230045",
        "policy": "clean_room_original_only",
        "logical_cell_pixels": 8,
        "projection": "orthographic_top_down_90",
        "pixel_contract": {
            "native_resolution_only": True,
            "antialiasing": False,
            "texture_filter": "nearest",
            "exterior_facades": False,
            "outline_pixels": [1, 2],
            "material_tones": [3, 4],
            "mobile_review_zoom": 1.0,
        },
        "counts": counts,
        "sprites": sprites,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    built = build()
    serialized = json.dumps(built, indent=2) + "\n"
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != serialized:
            raise SystemExit("Sprite ledger is stale; run tools/build_sprite_ledger.py")
        print(f"Sprite ledger is current: {len(built['sprites'])} deliverable records")
        return
    OUTPUT.write_text(serialized, encoding="utf-8")
    print(f"Wrote {OUTPUT}: {len(built['sprites'])} records, {built['counts']}")


if __name__ == "__main__":
    main()
