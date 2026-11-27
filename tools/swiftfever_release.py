#!/usr/bin/env python3
"""Bump SwiftFever version across all 4 synchronized files, commit, tag v<version>, and push."""

import argparse
from datetime import date
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
RELEASE_FILES = [
    "build.bat",
    "launcher/MainForm.cs",
    "mod/mpfever_1/content/mpfever_common.lua",
    "docs/CHANGELOG.txt",
]

RE_BUILD_BAT = re.compile(r'^(set "VERSION=)([^"]+)(")', re.M)
RE_MAINFORM = re.compile(r'(public const string Version = ")([^"]+)(";)')
RE_MODCOMMON = re.compile(r'^(C\.MODVERSION = ")([^"]+)(")', re.M)
RE_CHANGELOG_TOP = re.compile(r"^(\d+\.\d+\.\d+\S*) - ", re.M)
RE_VALID_VER = re.compile(r"^\d+\.\d+\.\d+(?:\.\d+)?$")


def run(args, check=True):
    return subprocess.run(args, cwd=ROOT, text=True, capture_output=True, check=check)


def read_text_preserve(path: Path):
    raw = path.read_bytes()
    eol = "\r\n" if b"\r\n" in raw else "\n"
    return raw.decode("utf-8-sig").replace("\r\n", "\n"), raw.startswith(b"\xef\xbb\xbf"), eol


def write_text_preserve(path: Path, text: str, bom: bool, eol: str):
    out = text.replace("\n", eol).encode("utf-8")
    if bom:
        out = b"\xef\xbb\xbf" + out
    path.write_bytes(out)


def parse_nums(ver: str):
    return tuple(int(p) for p in ver.split("."))


def bump_version(cur: str) -> str:
    parts = [int(p) for p in cur.split(".")]
    if len(parts) == 3:
        parts.append(1)
    elif len(parts) == 4:
        parts[3] += 1
    else:
        raise SystemExit(f"Unsupported version format: {cur}")
    return ".".join(str(p) for p in parts)


def current_version() -> str:
    text, _, _ = read_text_preserve(ROOT / "build.bat")
    m = RE_BUILD_BAT.search(text)
    if not m:
        raise SystemExit("Could not find VERSION in build.bat")
    return m.group(2)


def collect_bullets():
    last_tag = run(["git", "describe", "--tags", "--abbrev=0", "--match", "v*"], check=False)
    rev_range = f"{last_tag.stdout.strip()}..HEAD" if last_tag.returncode == 0 and last_tag.stdout.strip() else "HEAD~10..HEAD"
    log = run(["git", "log", rev_range, "--pretty=format:%s"], check=False)
    bullets = []
    if log.returncode == 0:
        for line in log.stdout.splitlines():
            s = line.strip()
            if not s or s.startswith("Release "):
                continue
            bullets.append(s)
    return bullets[:6]


def build_changelog_entry(new_ver: str, summary: str, bullets):
    today = date.today().isoformat()
    lines = [f"{new_ver} - {today}: {summary}"]
    if bullets:
        for b in bullets:
            lines.append(f"  - {b}")
    else:
        lines.append("  - Maintenance and build updates.")
    return "\n".join(lines) + "\n\n"


def update_files(old_ver: str, new_ver: str, summary: str, bullets):
    # 1. build.bat
    p = ROOT / "build.bat"
    txt, bom, eol = read_text_preserve(p)
    txt2, n = RE_BUILD_BAT.subn(rf"\g<1>{new_ver}\g<3>", txt, count=1)
    if n != 1:
        raise SystemExit("Failed to update version in build.bat")
    write_text_preserve(p, txt2, bom, eol)

    # 2. launcher/MainForm.cs
    p = ROOT / "launcher/MainForm.cs"
    txt, bom, eol = read_text_preserve(p)
    txt2, n = RE_MAINFORM.subn(rf"\g<1>{new_ver}\g<3>", txt, count=1)
    if n != 1:
        raise SystemExit("Failed to update Version in launcher/MainForm.cs")
    write_text_preserve(p, txt2, bom, eol)

    # 3. mod/mpfever_1/content/mpfever_common.lua
    p = ROOT / "mod/mpfever_1/content/mpfever_common.lua"
    txt, bom, eol = read_text_preserve(p)
    txt2, n = RE_MODCOMMON.subn(rf"\g<1>{new_ver}\g<3>", txt, count=1)
    if n != 1:
        raise SystemExit("Failed to update C.MODVERSION in mpfever_common.lua")
    write_text_preserve(p, txt2, bom, eol)

    # 4. docs/CHANGELOG.txt
    p = ROOT / "docs/CHANGELOG.txt"
    txt, bom, eol = read_text_preserve(p)
    marker = "===================\n\n"
    idx = txt.find(marker)
    if idx < 0:
        raise SystemExit("Could not find changelog header marker in docs/CHANGELOG.txt")
    entry = build_changelog_entry(new_ver, summary, bullets)
    if not txt[idx + len(marker):].startswith(f"{new_ver} - "):
        txt = txt[: idx + len(marker)] + entry + txt[idx + len(marker) :]
        write_text_preserve(p, txt, bom, eol)


def verify_versions(expected: str):
    checks = {
        "build.bat": RE_BUILD_BAT.search(read_text_preserve(ROOT / "build.bat")[0]).group(2),
        "launcher/MainForm.cs": RE_MAINFORM.search(read_text_preserve(ROOT / "launcher/MainForm.cs")[0]).group(2),
        "mod/mpfever_1/content/mpfever_common.lua": RE_MODCOMMON.search(read_text_preserve(ROOT / "mod/mpfever_1/content/mpfever_common.lua")[0]).group(2),
        "docs/CHANGELOG.txt": RE_CHANGELOG_TOP.search(read_text_preserve(ROOT / "docs/CHANGELOG.txt")[0]).group(1),
    }
    if any(v != expected for v in checks.values()):
        raise SystemExit(f"Version mismatch after update: {checks}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("version", nargs="?", help="Target version (default: auto-bump 4th segment from build.bat)")
    ap.add_argument("-m", "--summary", default="SwiftFever update", help="One-line summary for docs/CHANGELOG.txt")
    ap.add_argument("--dry-run", action="store_true", help="Print planned changes without editing files or git")
    ap.add_argument("--no-push", action="store_true", help="Update, commit, and tag locally without pushing")
    ap.add_argument("--files-only", action="store_true", help="Only update the 4 version files and exit")
    ap.add_argument("--allow-dirty", action="store_true", help="Allow uncommitted changes on tracked files")
    ap.add_argument("--allow-branch", action="store_true", help="Allow releasing from branches other than private-fast")
    args = ap.parse_args()

    old_ver = current_version()
    new_ver = args.version.strip() if args.version else bump_version(old_ver)
    if not RE_VALID_VER.match(new_ver):
        raise SystemExit(f"Invalid version '{new_ver}' (expected X.Y.Z or X.Y.Z.W)")
    if not args.version and parse_nums(new_ver) <= parse_nums(old_ver):
        raise SystemExit(f"New version {new_ver} must be newer than {old_ver}")

    tag = f"v{new_ver}"
    if run(["git", "rev-parse", "-q", "--verify", f"refs/tags/{tag}"], check=False).returncode == 0:
        raise SystemExit(f"Tag {tag} already exists locally")

    branch = run(["git", "branch", "--show-current"], check=False).stdout.strip()
    if not args.files_only and not args.allow_branch and branch != "private-fast":
        raise SystemExit(f"Expected branch 'private-fast' (current: '{branch or 'detached'}'); pass --allow-branch to override")

    if not args.allow_dirty and not args.dry_run:
        d1 = run(["git", "diff", "--quiet"], check=False).returncode
        d2 = run(["git", "diff", "--cached", "--quiet"], check=False).returncode
        if d1 != 0 or d2 != 0:
            raise SystemExit("Tracked files have uncommitted changes; commit/stash them or pass --allow-dirty")

    bullets = collect_bullets()
    summary = args.summary.strip() or "SwiftFever update"

    if args.dry_run:
        print(f"Current version : {old_ver}")
        print(f"Next version    : {new_ver} (tag {tag})")
        print(f"Branch          : {branch or 'detached'}")
        print("Changelog entry :")
        print(build_changelog_entry(new_ver, summary, bullets).rstrip())
        print("\nFiles to update :", ", ".join(RELEASE_FILES))
        if not args.files_only:
            print(f"Git commands    : git add ... && git commit -m 'Release {new_ver}' && git tag -a {tag} -m 'SwiftFever {new_ver}'")
            if not args.no_push:
                print(f"Push commands   : git push origin HEAD && git push origin {tag}")
        return 0

    update_files(old_ver, new_ver, summary, bullets)
    verify_versions(new_ver)
    print(f"Updated 4 version files: {old_ver} -> {new_ver}")

    if args.files_only:
        return 0

    subprocess.run(["git", "add", *RELEASE_FILES], cwd=ROOT, check=True)
    subprocess.run(["git", "commit", "-m", f"Release {new_ver}"], cwd=ROOT, check=True)
    subprocess.run(["git", "tag", "-a", tag, "-m", f"SwiftFever {new_ver}"], cwd=ROOT, check=True)

    if not args.no_push:
        subprocess.run(["git", "push", "origin", "HEAD"], cwd=ROOT, check=True)
        subprocess.run(["git", "push", "origin", tag], cwd=ROOT, check=True)
        print(f"\nPushed {tag}! Watch GitHub Actions SwiftFever Release:")
        print(f"  https://github.com/Dan1el-19/SwiftFever/releases/tag/{tag}")
    else:
        print(f"\nCommitted & tagged {tag} locally (--no-push).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
