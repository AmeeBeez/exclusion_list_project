Schema Migration and Cleaning Package

Files:
1. backup_and_replace_schema.sql
   - Run this in pgAdmin Query Tool while connected to exclusion_lists_db.
   - It creates a timestamped backup schema, backs up current project tables, drops the old project tables, and recreates them with the schema.

2. apply_null_constraints.sql
   - Optional for databases that already have the tables.
   - It updates existing tables in place so only required workflow/source columns are NOT NULL.
   - It makes sparse source-provided columns nullable.

3. clean_to_schema.py
   - Run manually from PowerShell or VS Code.
   - It reads staging CSV/XLSX files and outputs CSVs matching the new schema.
   - It detects the source state from file contents when possible, then falls back to the filename.
   - It names outputs as stg_<state>_exclusions.csv.
   - It fills required workflow/source fields and leaves sparse source fields blank.
   - Blank CSV cells import as NULL for nullable columns.
   - It writes all fields as text-compatible values.

Recommended order:
1. Download your current CSV files locally.
2. Run clean_to_schema.py on the folder containing the CSVs.
3. In pgAdmin, run backup_and_replace_schema.sql for a rebuild, or run apply_null_constraints.sql if tables already exist and should be altered in place.
4. Import the cleaned stg_<state>_exclusions.csv files into the matching staging tables.
5. Run row counts to confirm successful imports.

PowerShell example:
python clean_to_schema.py --input-dir "C:\Users\YourName\Downloads\exclusion_csvs" --output-dir "C:\Users\YourName\Downloads\new_schema_ready_csvs"

Important:
- The SQL script backs up first, but it still drops/recreates project tables. Do not run it until you are ready.
- The new schema includes an id column. The Python output includes id values, so pgAdmin import can load every column directly.
