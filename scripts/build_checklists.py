#!/usr/bin/env python3
"""Generate phase-ordered checklist views from tech-lead/README.md.

tech-lead/README.md is the single source of truth. This script reads every checklist
item ("- [ ] **TAG** text") and writes:

  tech-lead/checklists/by-phase.md    the same items regrouped by W1 / 30 / 60 / 90
  tech-lead/checklists/checklist.csv  one row per item, for importing into a tracker

Usage:
  python scripts/build_checklists.py           # regenerate the files
  python scripts/build_checklists.py --check   # exit 1 if they are stale (CI)
"""

from __future__ import annotations

import argparse
import csv
import io
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "tech-lead" / "README.md"
OUT_DIR = ROOT / "tech-lead" / "checklists"
MD_OUT = OUT_DIR / "by-phase.md"
CSV_OUT = OUT_DIR / "checklist.csv"

PHASES = {
    "W1": "First week",
    "30": "By day 30",
    "60": "By day 60",
    "90": "By day 90",
}

H2 = re.compile(r"^## (.+)$")
H3 = re.compile(r"^### (.+)$")
ITEM = re.compile(r"^- \[ \] (?:\*\*(W1|30|60|90)\*\* )?(.+)$")
SUB_ITEM = re.compile(r"^  - (.+)$")
BY_DAY = re.compile(r"^By day (30|60|90)$")
SECTION_NUM = re.compile(r"^(\d+(?:\.\d+)?)\.? ")
APPENDIX = re.compile(r"^Appendix ([A-Z])\b")
LOCAL_LINK = re.compile(r"\]\(#")
MD_LINK = re.compile(r"\[([^\]]+)\]\([^)]+\)")


@dataclass
class Item:
    phase: str
    section: str
    subsection: str
    text: str
    details: list[str] = field(default_factory=list)
    id: str = ""


def section_key(heading: str) -> str:
    """'3. Cloud' -> '3', '3.2 Identity' -> '3.2', 'Appendix B: ...' -> 'B'."""
    if m := SECTION_NUM.match(heading):
        return m.group(1)
    if m := APPENDIX.match(heading):
        return m.group(1)
    return re.sub(r"[^a-z0-9]+", "-", heading.lower()).strip("-")


def parse(readme: str) -> list[Item]:
    items: list[Item] = []
    section = subsection = ""
    day_phase = None  # set by "### By day N" headings in section 9
    in_fence = False

    for line in readme.splitlines():
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        if m := H2.match(line):
            section, subsection, day_phase = m.group(1), "", None
        elif m := H3.match(line):
            if d := BY_DAY.match(m.group(1)):
                day_phase, subsection = d.group(1), ""
            else:
                subsection, day_phase = m.group(1), None
        elif m := ITEM.match(line):
            phase = m.group(1) or day_phase
            if phase is None:
                raise SystemExit(f"Checklist item has no timing tag: {line!r}")
            items.append(Item(phase, section, subsection, m.group(2)))
        elif (m := SUB_ITEM.match(line)) and items:
            items[-1].details.append(m.group(1))

    # IDs are positional within each (sub)section, e.g. 3.2-04 or B-01.
    counters: dict[str, int] = {}
    for item in items:
        key = section_key(item.subsection or item.section)
        counters[key] = counters.get(key, 0) + 1
        item.id = f"{key}-{counters[key]:02d}"
    return items


def to_markdown(items: list[Item]) -> str:
    out = [
        "# Checklist by phase",
        "",
        "<!-- Generated from README.md by scripts/build_checklists.py. Do not edit by hand. -->",
        "",
        "Every item from the [onboarding checklist](../README.md), regrouped by when it is due. "
        "Section context and the reasoning behind each item live in the README; this view is for working through a phase.",
        "",
    ]
    for phase, title in PHASES.items():
        phase_items = [i for i in items if i.phase == phase]
        out += [f"## {phase}: {title}", "", f"{len(phase_items)} items.", ""]
        group = None
        for item in phase_items:
            heading = item.section if not item.subsection else f"{item.section} › {item.subsection}"
            if heading != group:
                if group is not None:
                    out.append("")
                out += [f"### {heading}", ""]
                group = heading
            text = LOCAL_LINK.sub("](../README.md#", item.text)
            out.append(f"- [ ] `{item.id}` {text}")
            out += [f"  - {LOCAL_LINK.sub('](../README.md#', d)}" for d in item.details]
        out.append("")
    return "\n".join(out)


def to_csv(items: list[Item]) -> str:
    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\n")
    writer.writerow(["ID", "Phase", "Section", "Subsection", "Item", "Details", "Status", "Owner", "Notes"])
    for item in items:
        writer.writerow([
            item.id,
            item.phase,
            item.section,
            item.subsection,
            MD_LINK.sub(r"\1", item.text).replace("**", "").replace("*", ""),
            "; ".join(item.details),
            "Not started",
            "",
            "",
        ])
    return buf.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="fail if generated files are out of date")
    args = parser.parse_args()

    items = parse(README.read_text(encoding="utf-8"))
    # utf-8-sig on the CSV so Excel reads the en dashes and quotes correctly.
    outputs = {MD_OUT: (to_markdown(items), "utf-8"), CSV_OUT: (to_csv(items), "utf-8-sig")}

    if args.check:
        stale = [p for p, (text, enc) in outputs.items()
                 if not p.exists() or p.read_text(encoding=enc).replace("\r\n", "\n") != text]
        for p in stale:
            print(f"{p.relative_to(ROOT)} is out of date. Run: python scripts/build_checklists.py")
        return 1 if stale else 0

    OUT_DIR.mkdir(exist_ok=True)
    for path, (text, enc) in outputs.items():
        path.write_text(text, encoding=enc, newline="\n")
    print(f"Wrote {len(items)} items to {MD_OUT.relative_to(ROOT)} and {CSV_OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
