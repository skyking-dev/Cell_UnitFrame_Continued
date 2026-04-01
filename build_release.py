#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import shutil
import tempfile
import zipfile
from pathlib import Path


ADDON_DIR = "Cell_UnitFrames"
TOC_NAME = "Cell_UnitFrames.toc"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build an installable GitHub release ZIP for Cell_UnitFrame_Continued."
    )
    parser.add_argument(
        "--version",
        required=True,
        help="Release version written into the TOC and used in the ZIP filename, e.g. v1.0.0.",
    )
    parser.add_argument(
        "--date",
        default=dt.date.today().isoformat(),
        help="ISO release date for X-Date in the TOC (default: today's local date).",
    )
    parser.add_argument(
        "--out-dir",
        default=".release",
        help="Directory where the packaged ZIP will be written.",
    )
    return parser.parse_args()


def toc_payload_paths(toc_path: Path) -> list[Path]:
    paths: list[Path] = []
    for line in toc_path.read_text(encoding="utf-8").splitlines():
        entry = line.strip()
        if not entry or entry.startswith("#"):
            continue
        paths.append(Path(entry))
    return paths


def validate_inputs(root: Path, payload_paths: list[Path]) -> None:
    missing = [str(path) for path in payload_paths if not (root / path).exists()]
    if missing:
        joined = "\n".join(f"- {path}" for path in missing)
        raise SystemExit(f"Missing files referenced by {TOC_NAME}:\n{joined}")


def staged_toc_text(root: Path, version: str, release_date: str) -> str:
    toc_text = (root / TOC_NAME).read_text(encoding="utf-8")
    return toc_text.replace("@project-version@", version).replace(
        "@project-date-iso@", release_date
    )


def stage_release_tree(
    root: Path, staging_root: Path, toc_text: str, payload_paths: list[Path]
) -> Path:
    addon_root = staging_root / ADDON_DIR
    addon_root.mkdir(parents=True, exist_ok=True)

    (addon_root / TOC_NAME).write_text(toc_text, encoding="utf-8")

    for relative_path in payload_paths:
        source = root / relative_path
        destination = addon_root / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    return addon_root


def write_zip(addon_root: Path, output_zip: Path) -> None:
    output_zip.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(output_zip, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(addon_root.rglob("*")):
            if path.is_dir():
                continue
            archive.write(path, arcname=path.relative_to(addon_root.parent))


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parent
    toc_path = root / TOC_NAME
    payload_paths = toc_payload_paths(toc_path)
    validate_inputs(root, payload_paths)

    output_zip = (root / args.out_dir / f"{ADDON_DIR}-{args.version}.zip").resolve()
    toc_text = staged_toc_text(root, args.version, args.date)

    with tempfile.TemporaryDirectory(prefix="cell_unitframes_release_") as temp_dir:
        staging_root = Path(temp_dir)
        addon_root = stage_release_tree(root, staging_root, toc_text, payload_paths)
        write_zip(addon_root, output_zip)

    print(output_zip)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
