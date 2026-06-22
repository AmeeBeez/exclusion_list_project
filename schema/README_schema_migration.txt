Schema Migration and Cleaning Package

Files:
1. backup_and_replace_schema.sql
   - Run this in pgAdmin Query Tool while connected to exclusion_lists_db.
   - It creates a timestamped backup schema, backs up current project tables, drops the old project tables, and recreates them with the schema.

2. clean_to_schema.py
   - Run manually from PowerShell or VS Code.
   - It reads staging CSV files and outputs CSVs matching the new schema.
   - It fills blanks with N/A so PostgreSQL NOT NULL constraints will not fail.
   - It writes all fields as text-compatible values.

Recommended order:
1. Download your current CSV files locally.
2. Run clean_to_schema.py on the folder containing the CSVs.
3. In pgAdmin, run backup_and_replace_schema.sql.
4. Import the cleaned *_schema.csv files into the matching staging tables.
5. Run row counts to confirm successful imports.

PowerShell example:
python clean_to_schema.py --input-dir "C:\Users\YourName\Downloads\exclusion_csvs" --output-dir "C:\Users\YourName\Downloads\new_schema_ready_csvs"

Important:
- The SQL script backs up first, but it still drops/recreates project tables. Do not run it until you are ready.
- The new schema includes an id column. The Python output includes id values, so pgAdmin import can load every column directly.
