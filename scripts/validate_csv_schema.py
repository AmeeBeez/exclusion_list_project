from pathlib import Path
import csv
import sys

EXPECTED_COLUMNS = [
    "id", "record_type", "source_state", "source_state_abbr", "source_name",
    "provider_name", "first_name", "middle_name", "last_name", "business_name",
    "aka", "dba", "npi", "provider_type", "license_number", "provider_number",
    "action_type", "action_effective_date", "active_period", "exclusion_authority",
    "exclusion_reason", "reinstatement_date", "source_url", "source_file_url",
    "source_file_date", "date_accessed", "data_quality_status", "notes",
]

DATA_DIR = Path("data/processed")


def validate_csv(path: Path) -> bool:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        header = next(reader, None)
    if header != EXPECTED_COLUMNS:
        print(f"FAILED: {path}")
        print("Expected:", EXPECTED_COLUMNS)
        print("Found:", header)
        return False
    print(f"PASSED: {path}")
    return True


def main() -> int:
    if not DATA_DIR.exists():
        print("No data/processed folder found. Skipping CSV validation.")
        return 0
    patterns = ["stg_*_exclusions.csv", "stg_*_schema.csv", "stg_*_from_pdf_schema.csv"]
    csv_files = sorted({path for pattern in patterns for path in DATA_DIR.glob(pattern)})
    # If no explicitly named cleaned/schema files exist, validate all staging processed files.
    if not csv_files:
        csv_files = sorted(DATA_DIR.glob("stg_*_processed.csv"))
    if not csv_files:
        print("No processed staging CSV files found. Skipping CSV validation.")
        return 0
    results = [validate_csv(path) for path in csv_files]
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
