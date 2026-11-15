#!/usr/bin/env python3
"""Convert VerseVIEW bible-database (Zefania XML) files to app JSON format.

Input : <XMLBIBLE biblename="Hindi"><BIBLEBOOK bnumber="1" bname="Genesis">
        <CHAPTER cnumber="1"><VERS vnumber="1">text</VERS>...
Output : {book: {chapter: {verse: "text"}}} — same shape as assets/bible_en.json

Usage:
  python3 zefania_to_app_json.py "Hindi Bible.xml" [more.xml ...] -o outdir/
  python3 zefania_to_app_json.py --all /path/to/repo -o outdir/   # convert a folder

The output JSON can be imported in BiblePresenter (Bible tab → Add Language)
or bundled as an asset. NOTE: the VerseVIEW database mixes public-domain and
copyright-restricted translations — check each version's terms before
redistributing converted files.
"""
import argparse
import json
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path

CANONICAL_BOOKS = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua",
    "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
    "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
    "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah",
    "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel",
    "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah",
    "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John",
    "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians",
    "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
    "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon",
    "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John",
    "3 John", "Jude", "Revelation",
]

# VerseVIEW files use slightly different book names than the app's built-in
# assets (e.g. "Psalm" vs "Psalms") — normalize so primary/secondary verse
# pairing stays aligned across languages.
BOOK_ALIASES = {
    "psalm": "Psalms",
    "psalms of david": "Psalms",
    "canticles": "Song of Solomon",
    "song of songs": "Song of Solomon",
}


def canonical_book(name: str) -> str:
    return BOOK_ALIASES.get(name.strip().lower(), name.strip())


def slugify(name: str) -> str:
    s = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    s = re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")
    return s[:32] or "imported"


def convert_xml(xml_path: Path):
    tree = ET.iterparse(str(xml_path), events=("start", "end"))
    bible_name = None
    data = {}
    verse_count = 0
    book = None
    chapter = None
    depth_ignorable = 0

    for event, elem in tree:
        tag = elem.tag.rsplit("}", 1)[-1]  # strip namespace if any
        if event == "start":
            if tag == "XMLBIBLE":
                bible_name = elem.attrib.get("biblename")
            elif tag == "BIBLEBOOK":
                bname = (elem.attrib.get("bname") or "").strip()
                try:
                    bnum = int(elem.attrib.get("bnumber", ""))
                except ValueError:
                    bnum = 0
                if bname:
                    book = canonical_book(bname)
                elif 1 <= bnum <= len(CANONICAL_BOOKS):
                    book = CANONICAL_BOOKS[bnum - 1]
                else:
                    book = None
            elif tag == "CHAPTER":
                try:
                    chapter = int(elem.attrib.get("cnumber", ""))
                except ValueError:
                    chapter = None
            elif tag in ("NOTE", "STYLE") and book and chapter is not None:
                depth_ignorable += 1
        else:
            if tag == "VERS" and book and chapter is not None:
                text = "".join(elem.itertext()).strip()
                if text:
                    try:
                        vnum = int(elem.attrib.get("vnumber", ""))
                    except ValueError:
                        vnum = 0
                    if vnum:
                        data.setdefault(book, {}).setdefault(
                            str(chapter), {})[str(vnum)] = text
                        verse_count += 1
                elem.clear()
            elif tag in ("NOTE", "STYLE") and depth_ignorable:
                depth_ignorable -= 1
            elif tag == "BIBLEBOOK":
                elem.clear()

    if not data:
        raise ValueError(f"{xml_path.name}: no verses found (not Zefania XML?)")
    name = (bible_name or xml_path.stem).strip()
    return name, slugify(name), data, verse_count


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("inputs", nargs="*", help="Zefania .xml files")
    ap.add_argument("--all", metavar="DIR", help="convert every .xml in DIR")
    ap.add_argument("-o", "--outdir", default=".", help="output directory")
    args = ap.parse_args()

    files = [Path(p) for p in args.inputs]
    if args.all:
        files.extend(sorted(Path(args.all).glob("*.xml")))
    if not files:
        ap.error("give .xml files or --all DIR")

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    for f in files:
        try:
            name, code, data, count = convert_xml(f)
        except Exception as e:
            print(f"SKIP {f.name}: {e}", file=sys.stderr)
            continue
        out = outdir / f"bible_{code}.json"
        with open(out, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))
        print(f"{f.name} → {out.name}  ({name}, {count} verses, "
              f"{len(data)} books, {out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
