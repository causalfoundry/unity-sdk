#!/usr/bin/env python3
"""Fast, dependency-free structural validation for the Kenkai UPM package."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PACKAGE_NAME = "io.kenkai.upm.sdk"
MINIMUM_UNITY = "2021.3"
SEMVER = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")
GUID = re.compile(r"^[0-9a-f]{32}$")
REQUIRED = (
    "package.json",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.md",
    "THIRD PARTY NOTICES.md",
    "Runtime/CausalFoundry.Unity.asmdef",
    "Editor/CausalFoundry.Unity.Editor.asmdef",
    "Documentation~/index.md",
    "Samples~/Core SDK Basics/CausalFoundry.Kenkai.Samples.Core.asmdef",
    "Tests/Editor/CausalFoundry.Unity.Editor.Tests.asmdef",
    "Runtime/Plugins/Android/causalfoundry-unity-android.aar",
    "Runtime/Plugins/iOS/Native~/KenkaiCore/Package.swift",
)
FORBIDDEN_SUFFIXES = (".csproj", ".sln", ".suo", ".user", ".tmp", ".tgz")


def under_ignored_folder(path: Path, root: Path) -> bool:
    return any(part.endswith("~") for part in path.relative_to(root).parts[:-1])


def under_dot_path(path: Path, root: Path) -> bool:
    """Return true for repository metadata that Unity does not import as package assets."""
    return any(part.startswith(".") for part in path.relative_to(root).parts)


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    errors: list[str] = []
    warnings: list[str] = []

    for relative in REQUIRED:
        if not (root / relative).exists():
            errors.append(f"missing required package item: {relative}")

    try:
        manifest = json.loads((root / "package.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"package.json is not valid JSON: {exc}")
        manifest = {}

    if manifest.get("name") != PACKAGE_NAME:
        errors.append(f"package name must be {PACKAGE_NAME!r}")
    if manifest.get("unity") != MINIMUM_UNITY:
        errors.append(f"minimum Unity version must be {MINIMUM_UNITY!r}")
    version = str(manifest.get("version", ""))
    if not SEMVER.fullmatch(version):
        errors.append(f"package version is not SemVer: {version!r}")

    try:
        sdk_source = (root / "Runtime/CFSDK.cs").read_text(encoding="utf-8")
        sdk_version_match = re.search(
            r'internal\s+const\s+string\s+PackageVersion\s*=\s*"([^"]+)"\s*;',
            sdk_source,
        )
        if sdk_version_match is None:
            errors.append("Runtime/CFSDK.cs must declare the UPM PackageVersion constant")
        elif sdk_version_match.group(1) != version:
            errors.append(
                "Runtime PackageVersion must match package.json: "
                f"{sdk_version_match.group(1)!r} != {version!r}"
            )
    except OSError as exc:
        errors.append(f"could not read Runtime/CFSDK.cs: {exc}")

    if "unity" in str(manifest.get("name", "")).lower():
        errors.append("custom UPM package names must not contain the reserved word 'unity'")
    if manifest.get("dependencies", {}).get("com.unity.modules.androidjni") != "1.0.0":
        errors.append("package must declare com.unity.modules.androidjni 1.0.0")

    for sample in manifest.get("samples", []):
        sample_path = sample.get("path")
        if not isinstance(sample_path, str) or not (root / sample_path).is_dir():
            errors.append(f"sample path does not exist: {sample_path!r}")

    asmdef_names: dict[str, Path] = {}
    for asmdef in root.rglob("*.asmdef"):
        if under_dot_path(asmdef, root):
            continue
        try:
            name = json.loads(asmdef.read_text(encoding="utf-8")).get("name")
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"invalid asmdef {asmdef.relative_to(root)}: {exc}")
            continue
        if not name:
            errors.append(f"asmdef has no name: {asmdef.relative_to(root)}")
        elif name in asmdef_names:
            errors.append(
                "duplicate asmdef name "
                f"{name!r}: {asmdef_names[name].relative_to(root)} and {asmdef.relative_to(root)}"
            )
        else:
            asmdef_names[name] = asmdef

    seen_guids: dict[str, Path] = {}
    for meta in root.rglob("*.meta"):
        if under_dot_path(meta, root):
            continue
        match = re.search(r"(?m)^guid: ([0-9a-f]+)$", meta.read_text(encoding="utf-8", errors="replace"))
        if not match or not GUID.fullmatch(match.group(1)):
            errors.append(f"missing or invalid GUID: {meta.relative_to(root)}")
            continue
        guid = match.group(1)
        if guid in seen_guids:
            errors.append(
                f"duplicate GUID {guid}: {seen_guids[guid].relative_to(root)} and {meta.relative_to(root)}"
            )
        else:
            seen_guids[guid] = meta

    files = [
        path
        for path in root.rglob("*")
        if path.is_file() and not under_dot_path(path, root)
    ]
    for path in files:
        relative = path.relative_to(root)
        if path.name == ".DS_Store" or path.suffix.lower() in FORBIDDEN_SUFFIXES:
            errors.append(f"forbidden generated file: {relative}")
        if (
            path.suffix != ".meta"
            and path.name != "package.json"
            and not under_ignored_folder(path, root)
            and not Path(str(path) + ".meta").is_file()
        ):
            errors.append(f"imported asset has no .meta file: {relative}")
        if len(str(relative)) > 140:
            warnings.append(f"long packaged path ({len(str(relative))} chars): {relative}")

    size = sum(path.stat().st_size for path in files)
    if warnings:
        print("Warnings:")
        for warning in warnings:
            print(f"  - {warning}")
    if errors:
        print("Package validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(
        f"Validated {PACKAGE_NAME} {version}: "
        f"{len(files)} files, {size / (1024 * 1024):.2f} MiB, {len(seen_guids)} GUIDs."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
