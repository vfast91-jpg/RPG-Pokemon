#!/usr/bin/env python3
"""One-shot migration: collapse the active v8 species sources into one plain JSON master."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
MANIFEST_PATH = DATA / "gen1_database_manifest_v8.json"
META_PATH = DATA / "gen1_database_meta_v8.json"
MASTER_PATH = DATA / "gen1_species_all_v8.json"

EXPECTED_SPECIES = 185
EXPECTED_ROOTS = 78
SENTINELS = {
    "lapras",
    "snorlax",
    "articuno",
    "zapdos",
    "moltres",
    "dragonite",
    "mewtwo",
    "mew",
    "annihilape",
    "sylveon",
}

# These files were only introduced to recover the data from the broken gzip
# packs. Once the single master exists they must not remain as competing v8
# sources. Older v3-v7 source files are deliberately retained because lower
# compatibility layers still reference them before the final v8 registry wins.
TEMP_PATTERNS = (
    "gen1_species_v3_dex*_v2.json",
    "gen1_species_v3_family_extensions_v2_*.json",
)
BROKEN_GZIP_FILES = (
    "gen1_species_v3_dex041_095_v1.json.gz",
    "gen1_species_v3_dex096_150_v1.json.gz",
    "gen1_species_v3_family_extensions_v1.json.gz",
)


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise RuntimeError(f"JSON root is not an object: {path}")
    return value


def repo_path(resource_path: str) -> Path:
    prefix = "res://"
    if not resource_path.startswith(prefix):
        raise RuntimeError(f"Expected res:// path, got: {resource_path}")
    return ROOT / resource_path[len(prefix) :]


def main() -> None:
    manifest = read_json(MANIFEST_PATH)
    meta = read_json(META_PATH)

    species_files = manifest.get("species_files")
    if not isinstance(species_files, list) or not species_files:
        raise RuntimeError("v8 manifest has no species_files list")

    merged: dict[str, dict] = {}
    for raw_path in species_files:
        path = repo_path(str(raw_path))
        if path.suffix == ".gz":
            raise RuntimeError(f"Active v8 source must be plain JSON before migration: {path}")
        pack = read_json(path)
        entries = pack.get("species")
        if not isinstance(entries, dict):
            raise RuntimeError(f"Species pack has no species object: {path}")
        for raw_id, raw_entry in entries.items():
            species_id = str(raw_id)
            if not isinstance(raw_entry, dict):
                raise RuntimeError(f"Invalid species entry {species_id} in {path}")
            merged[species_id] = raw_entry

    expected_species = int(manifest.get("species_count", EXPECTED_SPECIES))
    expected_roots = int(manifest.get("route_root_count", EXPECTED_ROOTS))
    if expected_species != EXPECTED_SPECIES or expected_roots != EXPECTED_ROOTS:
        raise RuntimeError(
            f"Unexpected v8 contract: species={expected_species}, roots={expected_roots}"
        )
    if len(merged) != EXPECTED_SPECIES:
        raise RuntimeError(f"Merged roster is incomplete: {len(merged)}/{EXPECTED_SPECIES}")

    roots = meta.get("route_roots")
    families = meta.get("family_members")
    if not isinstance(roots, list) or len(roots) != EXPECTED_ROOTS:
        raise RuntimeError(f"Route roots are incomplete: {len(roots) if isinstance(roots, list) else 0}/{EXPECTED_ROOTS}")
    if not isinstance(families, dict):
        raise RuntimeError("Meta family_members is missing")

    meta_species: set[str] = set()
    for root in roots:
        root_id = str(root)
        members = families.get(root_id)
        if not isinstance(members, list) or not members:
            raise RuntimeError(f"Family has no members: {root_id}")
        meta_species.update(str(member) for member in members)

    merged_ids = set(merged)
    if meta_species != merged_ids:
        missing = sorted(meta_species - merged_ids)
        extra = sorted(merged_ids - meta_species)
        raise RuntimeError(f"Meta/master mismatch. Missing={missing}; Extra={extra}")

    missing_sentinels = sorted(SENTINELS - merged_ids)
    if missing_sentinels:
        raise RuntimeError(f"Late/legendary sentinel Pokemon missing: {missing_sentinels}")

    master = {
        "schema_version": 8,
        "source_date": str(manifest.get("source_date", "2026-08-23")),
        "source": "Pokemon_Datenbank_Gen1_VOLLSTAENDIG_2026-08-22.xlsx",
        "definition": "Single authoritative plain-JSON species source for the complete 185-Pokemon Gen-1 family roster.",
        "species_count": EXPECTED_SPECIES,
        "species": merged,
    }
    MASTER_PATH.write_text(
        json.dumps(master, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )

    manifest["species_files"] = ["res://data/gen1_species_all_v8.json"]
    manifest["species_master_file"] = "res://data/gen1_species_all_v8.json"
    manifest["species_storage"] = "single_plain_json"
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )

    for pattern in TEMP_PATTERNS:
        for path in DATA.glob(pattern):
            if path != MASTER_PATH:
                path.unlink()
    for name in BROKEN_GZIP_FILES:
        path = DATA / name
        if path.exists():
            path.unlink()

    print(
        f"Gen1 species master built: {len(merged)} Pokemon, "
        f"{len(roots)} route families, {MASTER_PATH.relative_to(ROOT)}"
    )


if __name__ == "__main__":
    main()
