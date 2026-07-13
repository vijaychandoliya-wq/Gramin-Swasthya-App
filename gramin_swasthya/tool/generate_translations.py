"""Generate checked-in static translations for the app's UI vocabulary.

This is a development-time tool. The shipped application performs no network
translation and therefore remains usable offline.
"""

from __future__ import annotations

import ast
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_LANGUAGE = ROOT / "lib/l10n/app_language.dart"
OUTPUT = ROOT / "lib/l10n/generated_translations.dart"
# Numeric sentinel remains unchanged even for newly added low-resource models.
SEPARATOR = "000000999999000000"

LANGUAGES = {
    "as": "as",
    "awa": "awa",
    "bn": "bn",
    "bho": "bho",
    # Bodo (brx) is intentionally not generated: as of July 2026 it is not
    # offered by Google Cloud Translation or the Google Translate endpoint.
    "doi": "doi",
    "gu": "gu",
    "kn": "kn",
    "kha": "kha",
    "trp": "trp",
    "gom": "gom",
    "mai": "mai",
    "ml": "ml",
    "mni-Mtei": "mni-Mtei",
    "mr": "mr",
    "mwr": "mwr",
    "lus": "lus",
    "or": "or",
    "pa": "pa",
    "pa-Arab": "pa-Arab",
    "sa": "sa",
    "sat": "sat",
    "ta": "ta",
    "te": "te",
    "tcy": "tcy",
    "ur": "ur",
}


def dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$").replace("\n", "\\n") + "'"


def ui_vocabulary() -> list[str]:
    source = APP_LANGUAGE.read_text(encoding="utf-8")
    start = source.index("static const Map<String, String> _englishToHindi")
    end = source.index("static final Map<String, String> _hindiToEnglish")
    map_source = source[start:end]
    keys: set[str] = set()
    english_to_hindi: dict[str, str] = {}
    pair_pattern = re.compile(
        r"'((?:\\.|[^'])*)'\s*:\s*'((?:\\.|[^'])*)'", re.DOTALL
    )
    for match in pair_pattern.finditer(map_source):
        try:
            key = ast.literal_eval("'" + match.group(1) + "'")
            value = ast.literal_eval("'" + match.group(2) + "'")
            keys.add(key)
            english_to_hindi[key] = value
        except (SyntaxError, ValueError):
            pass

    hindi_to_english = {value: key for key, value in english_to_hindi.items()}
    replacements = sorted(hindi_to_english.items(), key=lambda item: -len(item[0]))

    def canonical_english(value: str) -> str:
        if " / " in value:
            latin = [part.strip() for part in value.split(" / ") if re.search(r"[A-Za-z]", part)]
            if latin:
                value = latin[-1]
        lines = value.splitlines()
        non_devanagari = [line for line in lines if line.strip() and not re.search(r"[\u0900-\u097f]", line)]
        if len(lines) > 1 and non_devanagari:
            value = "\n".join(non_devanagari).strip()
        parenthetical = re.match(r"^(.*?)\s*\(([^()]*)\)(.*)$", value)
        if parenthetical:
            outside = (parenthetical.group(1) + parenthetical.group(3)).strip()
            inside = parenthetical.group(2).strip()
            if bool(re.search(r"[\u0900-\u097f]", outside)) != bool(re.search(r"[\u0900-\u097f]", inside)):
                value = inside if re.search(r"[\u0900-\u097f]", outside) else outside
        if value.strip() in hindi_to_english:
            return hindi_to_english[value.strip()]
        for hindi, english in replacements:
            value = value.replace(hindi, english)
        return value.strip()

    literal_pattern = re.compile(
        r'''(?:LocalizedText|AppLanguage\.text)\(\s*(?:'((?:\\.|[^'])*)'|"((?:\\.|[^"])*)")''',
        re.MULTILINE,
    )
    for dart_file in (ROOT / "lib").rglob("*.dart"):
        if dart_file.name == "generated_translations.dart":
            continue
        dart_source = dart_file.read_text(encoding="utf-8")
        for match in literal_pattern.finditer(dart_source):
            raw = match.group(1) if match.group(1) is not None else match.group(2)
            try:
                quote = "'" if match.group(1) is not None else '"'
                literal = ast.literal_eval(quote + raw + quote)
            except (SyntaxError, ValueError):
                continue
            english = canonical_english(literal)
            if (
                english
                and "$" not in english
                and not re.search(r"[\u0900-\u097f]", english)
                and len(english) <= 500
            ):
                keys.add(english)

    # Extra canonical terms introduced by functional and navigation fixes.
    keys.update({
        "Notifications", "No active notifications", "Unable to load notifications",
        "Profile", "No member", "Prescription", "X-Ray", "ECG", "Other",
        "Mark as Taken", "Mobile number", "Link your mobile number",
        "Medicine time", "Prediabetic", "Diabetic", "Active Links",
        "Let the doctor scan this code",
    })
    # Machine translation is for human-language labels, not units/codes.
    return sorted(k for k in keys if re.search(r"[A-Za-z]", k) and len(k) <= 500)


def translate_batch(strings: list[str], target: str) -> list[str]:
    query = ("\n" + SEPARATOR + "\n").join(strings)
    params = urllib.parse.urlencode({
        "client": "gtx", "sl": "en", "tl": target, "dt": "t", "q": query,
    })
    request = urllib.request.Request(
        "https://translate.googleapis.com/translate_a/single?" + params,
        headers={"User-Agent": "GraminSwasthyaTranslationBuild/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.loads(response.read().decode("utf-8"))
    parts: list[str] = []
    current: list[str] = []
    for segment in data[0]:
        source_segment = (segment[1] or "").strip()
        if source_segment == SEPARATOR:
            parts.append("".join(current).strip())
            current = []
        else:
            current.append(segment[0])
    parts.append("".join(current).strip())
    if len(parts) != len(strings):
        raise RuntimeError(f"separator mismatch for {target}: {len(parts)} != {len(strings)}")
    return parts


def main() -> None:
    strings = ui_vocabulary()
    translations: dict[str, dict[str, str]] = {}
    for code, target in LANGUAGES.items():
        translated: list[str] = []
        for offset in range(0, len(strings), 35):
            batch = strings[offset:offset + 35]
            for attempt in range(4):
                try:
                    translated.extend(translate_batch(batch, target))
                    break
                except Exception:
                    if attempt == 3:
                        raise
                    time.sleep(1.5 * (attempt + 1))
        if len(strings) != len(translated):
            raise RuntimeError(f"translation count mismatch for {code}")
        translations[code] = dict(zip(strings, translated))
        print(f"{code}: {len(translated)} strings")

    lines = [
        "// GENERATED FILE - run tool/generate_translations.py to refresh.",
        "// Translations are static so the app remains fully offline-capable.",
        "const Map<String, Map<String, String>> generatedTranslations = {",
    ]
    for code, values in translations.items():
        lines.append(f"  {dart_string(code)}: {{")
        for key, value in values.items():
            lines.append(f"    {dart_string(key)}: {dart_string(value)},")
        lines.append("  },")
    lines.append("};")
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
