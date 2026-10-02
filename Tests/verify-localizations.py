#!/usr/bin/env python3
"""Check String Catalog completeness and, optionally, Xcode's compiled translations."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--app", type=Path, help="Path to a built F1A-TV.app")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / "F1A-TV/Localizable.xcstrings").read_text())
languages = {"en", "de", "es", "fr", "nl", "pt-PT"}
assert catalog["sourceLanguage"] == "en"
assert catalog["version"] == "1.0"
assert not list((root / "F1A-TV").glob("*.lproj/Localizable.strings")), "Legacy duplicate string tables remain"
assert catalog["strings"], "Catalog is empty"
expected = {language: {} for language in languages}
for key, entry in catalog["strings"].items():
    assert set(entry["localizations"]) == languages, f"Missing translation for {key}"
    for language, translation in entry["localizations"].items():
        unit = translation["stringUnit"]
        assert unit["state"] == "translated" and isinstance(unit["value"], str), (key, language)
        expected[language][key] = unit["value"]
if args.app:
    for language, values in expected.items():
        table = args.app / (language + ".lproj") / "Localizable.strings"
        actual = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(table)]))
        assert actual == values, f"Compiled translations differ for {language}"
print(f"Verified {len(catalog['strings'])} keys in all six languages" + (" and compiled string tables." if args.app else "."))
