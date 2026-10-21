#!/usr/bin/env python3
"""Build Shuni's book catalog from DAISY 3 talking books.

Reads tools/library_config.json (which DAISY folder belongs to which class) and,
for every listed book, parses:
  - navigation.ncx  -> book title, lessons/sections, recorded title clips
  - NNN.smil        -> audio file + start/end time of every sentence/image/page
  - dtbook.xml      -> the Bangla text, image alt text and page numbers

and writes assets/library/catalog.json, which the app loads at runtime.
Nothing is invented: every title, timing, sentence and image description comes
from the DAISY files. Missing files are reported and skipped.

Usage (from the project root):
    python tools/build_daisy_catalog.py
"""

from __future__ import annotations

import json
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "tools", "library_config.json")
OUTPUT = os.path.join(ROOT, "assets", "library", "catalog.json")

NS = {
    "ncx": "http://www.daisy.org/z3986/2005/ncx/",
    "smil": "http://www.w3.org/2001/SMIL20/",
    "dtb": "http://www.daisy.org/z3986/2005/dtbook/",
}

BN_DIGITS = "০১২৩৪৫৬৭৮৯"
LESSON_RE = re.compile(r"^\s*পাঠ\s*([০-৯0-9]+)\s*-?\s*(.*?)\s*$")
EN_LESSON_RE = re.compile(r"^\s*Lesson\s*([0-9]+)\s*[-–:]?\s*(.*?)\s*$", re.IGNORECASE)
UNIT_RE = re.compile(r"^\s*Unit\s*[-–]?\s*([0-9]+)\s*[-–:]?\s*(.*?)\s*$", re.IGNORECASE)


def bn_to_int(s: str) -> int:
    return int("".join(str(BN_DIGITS.index(c)) if c in BN_DIGITS else c for c in s))


def clock_to_seconds(value: str) -> float:
    """DAISY clock values look like 00:01:23.4567 (or plain seconds)."""
    value = value.strip()
    if value.endswith("s") and ":" not in value:
        return float(value[:-1])
    parts = value.split(":")
    seconds = 0.0
    for p in parts:
        seconds = seconds * 60 + float(p)
    return round(seconds, 3)


def clean(text: str | None) -> str:
    if not text:
        return ""
    return re.sub(r"\s+", " ", text).strip()


def local(tag: str) -> str:
    return tag.split("}", 1)[-1]


def parse_dtbook(path: str) -> dict:
    """id -> {kind, text, image} for every element a SMIL file can point to."""
    tree = ET.parse(path)
    out: dict[str, dict] = {}
    for el in tree.iter():
        el_id = el.get("id")
        if not el_id:
            continue
        name = local(el.tag)
        if name == "img":
            out[el_id] = {
                "kind": "image",
                "text": clean(el.get("alt")),
                "image": el.get("src"),
            }
        elif name == "pagenum":
            out[el_id] = {"kind": "page", "text": clean("".join(el.itertext()))}
        elif name in ("h1", "h2", "h3", "h4", "h5", "h6", "doctitle"):
            out[el_id] = {"kind": "heading", "text": clean("".join(el.itertext()))}
        else:
            text = clean("".join(el.itertext()))
            if text:
                out[el_id] = {"kind": "text", "text": text}
    return out


def parse_smil(path: str, dtbook: dict) -> list[dict]:
    tree = ET.parse(path)
    segments = []
    for par in tree.iter("{%s}par" % NS["smil"]):
        text_el = par.find("smil:text", NS)
        audio_el = par.find("smil:audio", NS)
        if audio_el is None:
            continue
        ref = text_el.get("src", "") if text_el is not None else ""
        target = dtbook.get(ref.split("#", 1)[-1], {"kind": "text", "text": ""})
        seg = {
            "audio": audio_el.get("src"),
            "start": clock_to_seconds(audio_el.get("clipBegin", "0")),
            "end": clock_to_seconds(audio_el.get("clipEnd", "0")),
            "kind": target["kind"],
            "text": target["text"],
        }
        if target.get("image"):
            seg["image"] = target["image"]
        segments.append(seg)
    return segments


def assign_pages(segments: list[dict]) -> list[str]:
    """In these books a page-number marker comes at the END of its page's
    content, so each segment belongs to the next page marker after it."""
    pages: list[str] = []
    current = None
    for seg in reversed(segments):
        if seg["kind"] == "page":
            current = seg["text"]
            if current not in pages:
                pages.insert(0, current)
        if current is not None and seg["kind"] != "page":
            seg["page"] = current
    return pages


def _clip(nav) -> dict | None:
    audio = nav.find("ncx:navLabel/ncx:audio", NS)
    if audio is None:
        return None
    return {
        "audio": audio.get("src"),
        "start": clock_to_seconds(audio.get("clipBegin", "0")),
        "end": clock_to_seconds(audio.get("clipEnd", "0")),
    }


def _label(nav) -> str:
    return clean(nav.findtext("ncx:navLabel/ncx:text", default="", namespaces=NS))


def build_book(cfg: dict, warnings: list[str]) -> dict | None:
    folder = os.path.join(ROOT, cfg["folder"])
    ncx_path = os.path.join(folder, "navigation.ncx")
    dtbook_path = os.path.join(folder, "dtbook.xml")
    for p in (ncx_path, dtbook_path):
        if not os.path.exists(p):
            warnings.append(f"{cfg['id']}: missing {os.path.relpath(p, ROOT)} - book skipped")
            return None

    dtbook = parse_dtbook(dtbook_path)
    ncx = ET.parse(ncx_path).getroot()
    title = clean(ncx.findtext("ncx:docTitle/ncx:text", default="", namespaces=NS))

    sections: list[dict] = []
    units: list[dict] = []
    book_title_clip = None

    def add_section(nav, unit: dict | None) -> None:
        label = _label(nav)
        smil_file = nav.find("ncx:content", NS).get("src").split("#", 1)[0]
        smil_path = os.path.join(folder, smil_file)
        if not os.path.exists(smil_path):
            warnings.append(f"{cfg['id']}: {label}: missing {smil_file} - section skipped")
            return
        segments = parse_smil(smil_path, dtbook)
        audio_files = []
        for seg in segments:
            if seg["audio"] not in audio_files:
                audio_files.append(seg["audio"])
        missing = [a for a in audio_files if not os.path.exists(os.path.join(folder, a))]
        if missing:
            warnings.append(f"{cfg['id']}: {label}: missing audio {missing} - section skipped")
            return
        m = LESSON_RE.match(label) or EN_LESSON_RE.match(label)
        sections.append({
            "id": nav.get("id"),
            "kind": "lesson" if m else "front",
            "number": None,  # assigned below
            "printedNumber": bn_to_int(m.group(1)) if m else None,
            "unit": unit["number"] if (unit and m) else None,
            "title": clean(m.group(2)) if m else label,
            "fullTitle": label,
            "audioFiles": audio_files,
            "duration": round(max((s["end"] for s in segments if s["audio"] == audio_files[-1]), default=0), 3),
            "titleClip": _clip(nav),
            "segments": segments,
        })

    def walk(parent, unit: dict | None) -> None:
        for nav in parent.findall("ncx:navPoint", NS):
            label = _label(nav)
            has_children = nav.find("ncx:navPoint", NS) is not None
            if nav.get("class") == "h1":
                nonlocal book_title_clip
                book_title_clip = _clip(nav)
                walk(nav, None)
                continue
            um = UNIT_RE.match(label)
            if has_children or um:
                new_unit = {
                    "number": int(um.group(1)) if um else len(units) + 1,
                    "title": clean(um.group(2)) if um else label,
                    "fullTitle": label,
                    "titleClip": _clip(nav),
                }
                units.append(new_unit)
                walk(nav, new_unit)
                continue
            add_section(nav, unit)

    walk(ncx.find("ncx:navMap", NS), None)

    # One printed lesson may be split over two navigation points (e.g. a
    # lesson that runs over a page break). Merge them back into one lesson.
    merged: list[dict] = []
    for sec in sections:
        prev = merged[-1] if merged else None
        if (prev and sec["kind"] == "lesson" and prev["kind"] == "lesson"
                and prev["unit"] == sec["unit"]
                and prev["printedNumber"] == sec["printedNumber"]
                and prev["title"] == sec["title"]):
            prev["audioFiles"] += [a for a in sec["audioFiles"] if a not in prev["audioFiles"]]
            prev["segments"] += sec["segments"]
            # Duration = sum of each audio file's last end time (a lesson split
            # inside one file must not be counted twice).
            prev["duration"] = round(sum(
                max(g["end"] for g in prev["segments"] if g["audio"] == f)
                for f in prev["audioFiles"]), 3)
            continue
        merged.append(sec)
    sections = merged

    # Pages, lesson numbers.
    for sec in sections:
        sec["pages"] = assign_pages(sec["segments"])
    lessons = [s for s in sections if s["kind"] == "lesson"]
    for i, sec in enumerate(lessons, start=1):
        # Without units the printed number is what children say; with units
        # lessons restart at 1 in every unit, so number them through the book
        # and keep the printed number as lessonInUnit.
        if units:
            sec["number"] = i
            sec["lessonInUnit"] = sec["printedNumber"]
        else:
            sec["number"] = sec["printedNumber"]
        del sec["printedNumber"]
    for sec in sections:
        sec.pop("printedNumber", None)
        if sec["kind"] == "lesson" and units and sec["unit"] is None:
            warnings.append(f"{cfg['id']}: lesson outside any unit: {sec['fullTitle']}")

    if not units:
        nums = [s["number"] for s in lessons]
        if nums != list(range(1, len(nums) + 1)):
            warnings.append(f"{cfg['id']}: lesson numbers are not 1..N in order: {nums}")
    else:
        for u in units:
            nums = [s["lessonInUnit"] for s in lessons if s["unit"] == u["number"]]
            if nums != list(range(1, len(nums) + 1)):
                warnings.append(f"{cfg['id']}: unit {u['number']} lesson numbers: {nums}")

    # The cover is the first picture in the book's opening (001.smil).
    cover = None
    first_smil = os.path.join(folder, "001.smil")
    if os.path.exists(first_smil):
        for s in parse_smil(first_smil, dtbook):
            if s.get("image"):
                cover = s["image"]
                break
    if cover is None:
        cover = next((g["image"] for sec in sections for g in sec["segments"] if g.get("image")), None)

    return {
        "id": cfg["id"],
        "title": title,
        "shortTitle": cfg.get("shortTitle", title),
        "subject": cfg.get("subject"),
        "subjectNameBn": cfg.get("subjectNameBn"),
        "spokenNames": cfg.get("spokenNames", []),
        "basePath": cfg["folder"].rstrip("/") + "/",
        "cover": cover,
        "titleClip": book_title_clip,
        "units": units,
        "sections": sections,
    }


def main() -> int:
    with open(CONFIG, encoding="utf-8") as f:
        config = json.load(f)
    warnings: list[str] = []
    classes = []
    for cls in config["classes"]:
        books = [b for b in (build_book(c, warnings) for c in cls["books"]) if b]
        classes.append({"id": cls["id"], "nameBn": cls["nameBn"], "books": books})

    catalog = {"schemaVersion": 1, "classes": classes}
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, separators=(",", ":"))

    for cls in classes:
        for b in cls["books"]:
            lessons = [s for s in b["sections"] if s["kind"] == "lesson"]
            segs = sum(len(s["segments"]) for s in b["sections"])
            print(f"Class {cls['id']}: {b['title']} - {len(b['units'])} units, {len(lessons)} lessons, "
                  f"{len(b['sections']) - len(lessons)} other sections, {segs} segments")
    for w in warnings:
        print("WARNING:", w, file=sys.stderr)
    print("Wrote", os.path.relpath(OUTPUT, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
