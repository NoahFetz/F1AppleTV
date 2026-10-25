#!/usr/bin/env python3
"""Check String Catalog completeness and, optionally, Xcode's compiled translations."""
import argparse
import json
import re
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--app", type=Path, help="Path to either built application")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / "F1Core/Sources/F1Core/Resources/Localizable.xcstrings").read_text())
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
login_sources = [
    "F1A-Mac/Account/AccountView.swift",
    "F1A-Mac/Account/MacBrowserLogin.swift",
    "F1A-TV/Controller/Views/Security/LoginViewController.swift",
    "F1A-TV/Controller/Views/Security/AccountOverviewViewController.swift",
]
for relative in login_sources:
    source = (root / relative).read_text()
    keys = set(re.findall(r'"([^"\n]+)"\.localizedString', source))
    assert keys <= catalog["strings"].keys(), f"Missing login keys in {relative}: {keys - catalog['strings'].keys()}"
    # SwiftUI literal keys otherwise silently resolve in the app's main bundle,
    # while these apps keep translations in the shared F1Core resource bundle.
    literals = re.findall(r'(?:Text|Button|LabeledContent|LoadingStatus|TVDesign\.(?:label|button))\(\s*(?:title:\s*)?"([^"\n]+)"(?!\.localizedString)', source)
    assert not literals, f"Unlocalized login UI in {relative}: {literals}"
    statuses = re.findall(r'(?:status|error)(?:\.text)?\s*=\s*"([^"\n]+)"(?!\.localizedString)', source)
    assert not statuses, f"Unlocalized login status in {relative}: {statuses}"
    assert not re.search(r"status\.textContent\s*=\s*['\"]", source), f"Unlocalized browser status in {relative}"
if args.app:
    for language, values in expected.items():
        candidates = [table for table in args.app.rglob("Localizable.strings")
                      if table.parent.name == language + ".lproj" and "F1Core_F1Core.bundle" in table.parts]
        assert len(candidates) == 1, f"Missing or duplicate shared translations for {language}"
        table = candidates[0]
        actual = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(table)]))
        assert actual == values, f"Compiled translations differ for {language}"
print(f"Verified {len(catalog['strings'])} keys in all six languages" + (" and compiled string tables." if args.app else "."))
