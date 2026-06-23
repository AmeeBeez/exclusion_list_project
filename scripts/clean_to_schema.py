#!/usr/bin/env python3
"""
clean_to_schema.py

Purpose:
    Clean exclusion-list CSV files and rewrite them to match the updated
    staging-table schema:
      - id
      - all other columns as VARCHAR-compatible text
      - no missing/null values; blanks are replaced with N/A
      - business_name included instead of relying only on entity_name
      - dates normalized to YYYY-MM-DD when possible, but still written as text

How to run from PowerShell:
    python clean_to_schema.py --input-dir . --output-dir new_schema_ready_csvs

Typical use:
    1. Put your processed files in one folder, for example:
       stg_arizona_exclusions_processed.csv
       stg_arkansas_exclusions_processed.csv
       stg_california_exclusions_processed.csv
       etc.
    2. Run this script from that folder.
    3. Import the output CSVs into the matching PostgreSQL staging tables.

No database connection is used. This only cleans CSV files.
"""

from __future__ import annotations

import argparse
import csv
import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple

NEW_COLUMNS: List[str] = [
    "id", "record_type", "source_state", "source_state_abbr", "source_name",
    "provider_name", "first_name", "middle_name", "last_name", "business_name",
    "aka", "dba", "npi", "provider_type", "license_number", "provider_number",
    "action_type", "action_effective_date", "active_period", "exclusion_authority",
    "exclusion_reason", "reinstatement_date", "source_url", "source_file_url",
    "source_file_date", "date_accessed", "data_quality_status", "notes",
]

NULL_LIKE = {"", "null", "none", "nan", "na", "n/a", "[null]", "nat"}

STATE_FROM_FILE = {
    "alabama": ("Alabama", "AL"),
    "alaska": ("Alaska", "AK"),
    "arizona": ("Arizona", "AZ"),
    "arkansas": ("Arkansas", "AR"),
    "california": ("California", "CA"),
    "colorado": ("Colorado", "CO"),
    "connecticut": ("Connecticut", "CT"),
    "delaware": ("Delaware", "DE"),
    "district_of_columbia": ("District of Columbia", "DC"),
    "dc": ("District of Columbia", "DC"),
    "florida": ("Florida", "FL"),
}

DATE_FORMATS = [
    "%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y", "%m-%d-%Y", "%m-%d-%y",
    "%B %d, %Y", "%b %d, %Y", "%Y%m%d",
]

SYNONYMS = {
    "source_state_abbr": ["source_state_abbr", "source_state_abbrev", "state_abbr"],
    "provider_name": ["provider_name", "name", "provider", "provider name", "name of individual", "name of company"],
    "first_name": ["first_name", "firstname", "first name"],
    "middle_name": ["middle_name", "midname", "middle name", "mi"],
    "last_name": ["last_name", "lastname", "last name"],
    "business_name": ["business_name", "entity_name", "busname", "business", "facility name", "name of company"],
    "aka": ["aka", "a/k/a", "alias"],
    "dba": ["dba", "doing business as", "business_name"],
    "npi": ["npi"],
    "provider_type": ["provider_type", "provider type", "specialty", "general"],
    "license_number": ["license_number", "license number", "licnum"],
    "provider_number": ["provider_number", "provider number", "upin"],
    "action_type": ["action_type", "administrative action", "excltype"],
    "action_effective_date": ["action_effective_date", "effective date", "exclusion effective date", "date of suspension", "termination effective date", "action date", "excldate"],
    "active_period": ["active_period", "period", "active period"],
    "exclusion_authority": ["exclusion_authority", "termination authority", "agency instituting the action", "excltype"],
    "exclusion_reason": ["exclusion_reason", "reason for the action", "administrative action", "excltype"],
    "reinstatement_date": ["reinstatement_date", "exclusion end date", "expiration date", "termination date", "termination date﻿", "reindate"],
    "source_url": ["source_url"],
    "source_file_url": ["source_file_url"],
    "source_file_date": ["source_file_date"],
    "date_accessed": ["date_accessed"],
    "data_quality_status": ["data_quality_status"],
    "notes": ["notes", "address", "principal address", "address(es)"],
}


def normalize_header(value: str) -> str:
    value = value.replace("\ufeff", "").strip().lower()
    value = re.sub(r"\s+", " ", value)
    return value


def clean_text(value: object, default: str = "N/A") -> str:
    if value is None:
        return default
    text = str(value).replace("\ufeff", "").replace("\r", " ").replace("\n", " ").replace("\t", " ").strip()
    text = re.sub(r"\s+", " ", text)
    if text.lower() in NULL_LIKE:
        return default
    return text


def get_value(row: Dict[str, str], canonical: str, default: str = "N/A") -> str:
    candidates = SYNONYMS.get(canonical, [canonical])
    for candidate in candidates:
        key = normalize_header(candidate)
        if key in row:
            value = clean_text(row.get(key), default="")
            if value and value.lower() not in NULL_LIKE:
                return value
    return default


def infer_state_from_filename(path: Path) -> Tuple[str, str]:
    stem = path.stem.lower()
    for token, value in STATE_FROM_FILE.items():
        if token in stem:
            return value
    return "N/A", "N/A"


def normalize_date(value: str) -> str:
    text = clean_text(value)
    if text == "N/A":
        return text
    if text.lower() in {"indefinite", "ongoing", "current", "active"}:
        return text
    candidate = re.sub(r"\b(\d{1,2})(st|nd|rd|th)\b", r"\1", text, flags=re.IGNORECASE)
    candidate = re.sub(r"\s+", " ", candidate.strip())
    for fmt in DATE_FORMATS:
        try:
            parsed = datetime.strptime(candidate, fmt)
            return parsed.strftime("%Y-%m-%d")
        except ValueError:
            continue
    return text


def parse_person_name(provider_name: str) -> Tuple[str, str, str]:
    name = clean_text(provider_name)
    if name == "N/A":
        return "N/A", "N/A", "N/A"
    org_markers = [" llc", " inc", " corp", " company", " clinic", " center", " services", " group", " dba ", " pc", " ltd"]
    if any(marker in f" {name.lower()}" for marker in org_markers):
        return "N/A", "N/A", "N/A"
    if "," in name:
        last, rest = [part.strip() for part in name.split(",", 1)]
        pieces = rest.split()
        first = pieces[0] if pieces else "N/A"
        middle = " ".join(pieces[1:]) if len(pieces) > 1 else "N/A"
        return clean_text(first), clean_text(middle), clean_text(last)
    pieces = name.split()
    if len(pieces) >= 2:
        first = pieces[0]
        last = pieces[-1]
        middle = " ".join(pieces[1:-1]) if len(pieces) > 2 else "N/A"
        return clean_text(first), clean_text(middle), clean_text(last)
    return "N/A", "N/A", name


def normalize_npi(value: str) -> str:
    text = clean_text(value)
    if text == "N/A":
        return text
    if re.fullmatch(r"0+", text):
        return "N/A"
    return text


def build_new_row(old_row: Dict[str, str], row_id: int, source_file: Path) -> Dict[str, str]:
    state_name, state_abbr = infer_state_from_filename(source_file)
    new = {column: "N/A" for column in NEW_COLUMNS}
    new["id"] = str(row_id)
    new["record_type"] = get_value(old_row, "record_type", "provider_record")
    new["source_state"] = get_value(old_row, "source_state", state_name)
    new["source_state_abbr"] = get_value(old_row, "source_state_abbr", state_abbr)
    new["source_name"] = get_value(old_row, "source_name", f"{new['source_state']} exclusion source")

    for col in NEW_COLUMNS:
        if col in {"id", "record_type", "source_state", "source_state_abbr", "source_name", "business_name"}:
            continue
        if col in {"action_effective_date", "reinstatement_date", "source_file_date", "date_accessed"}:
            new[col] = normalize_date(get_value(old_row, col))
        elif col == "npi":
            new[col] = normalize_npi(get_value(old_row, col))
        else:
            new[col] = get_value(old_row, col)

    new["business_name"] = get_value(old_row, "business_name")
    if new["provider_name"] == "N/A":
        if new["business_name"] != "N/A":
            new["provider_name"] = new["business_name"]
        else:
            parts = [new["first_name"], new["middle_name"], new["last_name"]]
            parts = [p for p in parts if p != "N/A"]
            if parts:
                new["provider_name"] = " ".join(parts)

    parsed_first, parsed_middle, parsed_last = parse_person_name(new["provider_name"])
    if new["first_name"] == "N/A" and parsed_first != "N/A":
        new["first_name"] = parsed_first
    if new["middle_name"] == "N/A" and parsed_middle != "N/A":
        new["middle_name"] = parsed_middle
    if new["last_name"] == "N/A" and parsed_last != "N/A":
        new["last_name"] = parsed_last

    if new["business_name"] == "N/A" and new["dba"] != "N/A":
        new["business_name"] = new["dba"]

    for col in NEW_COLUMNS:
        new[col] = clean_text(new[col])
    if new["data_quality_status"] == "N/A":
        new["data_quality_status"] = "clean_ready_for_import"
    return new


def read_csv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        sample = f.read(4096)
        f.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample)
        except csv.Error:
            dialect = csv.excel
        reader = csv.DictReader(f, dialect=dialect)
        if not reader.fieldnames:
            raise ValueError(f"No header row found in {path}")
        normalized_headers = [normalize_header(h) for h in reader.fieldnames]
        rows = []
        for raw in reader:
            normalized = {}
            for original, normalized_key in zip(reader.fieldnames, normalized_headers):
                normalized[normalized_key] = raw.get(original, "")
            rows.append(normalized)
        return normalized_headers, rows


def should_process(path: Path) -> bool:
    name = path.name.lower()
    if not name.endswith(".csv"):
        return False
    if "summary" in name or "load_summary" in name or "source_match" in name:
        return False
    return name.startswith("stg_") or name.startswith("all_states")


def output_filename(path: Path) -> str:
    stem = path.name
    while stem.lower().endswith(".csv"):
        stem = stem[:-4]
    return f"{stem}_schema.csv"


def process_file(path: Path, output_dir: Path) -> Dict[str, str]:
    headers, rows = read_csv(path)
    output_path = output_dir / output_filename(path)
    cleaned_rows = []
    seen = set()
    duplicates = 0

    for row in rows:
        cleaned = build_new_row(row, len(cleaned_rows) + 1, path)
        dupe_key = tuple(cleaned[col] for col in NEW_COLUMNS if col != "id")
        if dupe_key in seen:
            duplicates += 1
            continue
        seen.add(dupe_key)
        cleaned["id"] = str(len(cleaned_rows) + 1)
        cleaned_rows.append(cleaned)

    with output_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=NEW_COLUMNS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(cleaned_rows)

    return {
        "source_file": path.name,
        "output_file": output_path.name,
        "raw_rows": str(len(rows)),
        "output_rows": str(len(cleaned_rows)),
        "duplicates_removed": str(duplicates),
        "output_columns": str(len(NEW_COLUMNS)),
        "status": "processed",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Clean exclusion CSV files into staging schema.")
    parser.add_argument("--input-dir", default=".", help="Folder containing source CSVs.")
    parser.add_argument("--output-dir", default="new_schema_ready_csvs", help="Folder for cleaned output CSVs.")
    args = parser.parse_args()

    input_dir = Path(args.input_dir).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    files = sorted(path for path in input_dir.glob("*.csv") if should_process(path))
    if not files:
        raise SystemExit(f"No staging CSV files found in {input_dir}")

    summary_rows = []
    for path in files:
        try:
            result = process_file(path, output_dir)
        except Exception as exc:
            result = {
                "source_file": path.name,
                "output_file": "N/A",
                "raw_rows": "N/A",
                "output_rows": "N/A",
                "duplicates_removed": "N/A",
                "output_columns": str(len(NEW_COLUMNS)),
                "status": f"error: {exc}",
            }
        summary_rows.append(result)

    summary_path = output_dir / "schema_cleaning_summary.csv"
    with summary_path.open("w", encoding="utf-8", newline="") as f:
        fieldnames = ["source_file", "output_file", "raw_rows", "output_rows", "duplicates_removed", "output_columns", "status"]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"Processed {len(summary_rows)} file(s).")
    print(f"Output folder: {output_dir}")
    print(f"Summary file: {summary_path}")


if __name__ == "__main__":
    main()
