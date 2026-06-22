-- backup_and_replace_schema.sql
-- Purpose:
-- 1) Back up every table currently inside exclusion_project.
-- 2) Replace the project tables with the standard staging schema:
--    - id BIGSERIAL PRIMARY KEY
--    - all non-id columns VARCHAR NOT NULL
--    - no varchar length limits
--
-- Run this in pgAdmin Query Tool while connected to exclusion_lists_db.
-- IMPORTANT: This script DROPS and RECREATES the project tables after backing them up.

BEGIN;

CREATE SCHEMA IF NOT EXISTS exclusion_project;

-- Back up every existing table in exclusion_project into a timestamped backup schema.
DO $$
DECLARE
    backup_schema_name TEXT := 'exclusion_project_backup_' || to_char(clock_timestamp(), 'YYYYMMDD_HH24MISS');
    r RECORD;
BEGIN
    EXECUTE format('CREATE SCHEMA %I', backup_schema_name);

    FOR r IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'exclusion_project'
          AND table_type = 'BASE TABLE'
        ORDER BY table_name
    LOOP
        EXECUTE format(
            'CREATE TABLE %I.%I AS TABLE exclusion_project.%I',
            backup_schema_name,
            r.table_name,
            r.table_name
        );
    END LOOP;

    RAISE NOTICE 'Backup completed in schema: %', backup_schema_name;
END $$;

-- Drop old project tables so they can be rebuilt with the new global schema.
DROP TABLE IF EXISTS exclusion_project.all_state_exclusions CASCADE;
DROP TABLE IF EXISTS exclusion_project.stg_alabama_exclusions CASCADE;
DROP TABLE IF EXISTS exclusion_project.stg_alaska_exclusions CASCADE;
DROP TABLE IF EXISTS exclusion_project.stg_arizona_exclusions CASCADE;
DROP TABLE IF EXISTS exclusion_project.stg_arkansas_exclusions CASCADE;
DROP TABLE IF EXISTS exclusion_project.stg_california_exclusions CASCADE;
DROP TABLE IF EXISTS exclusion_project.stg_colorado_exclusions CASCADE;
DROP TABLE IF EXISTS exclusion_project.stg_connecticut_exclusions CASCADE;
DROP TABLE IF EXISTS exclusion_project.stg_delaware_exclusions CASCADE;
DROP TABLE IF EXISTS exclusion_project.stg_district_of_columbia_exclusions CASCADE;
DROP TABLE IF EXISTS exclusion_project.stg_florida_exclusions CASCADE;

-- Recreate every project table with the same standard staging schema.
DO $$
DECLARE
    table_name TEXT;
    table_names TEXT[] := ARRAY[
        'all_state_exclusions',
        'stg_alabama_exclusions',
        'stg_alaska_exclusions',
        'stg_arizona_exclusions',
        'stg_arkansas_exclusions',
        'stg_california_exclusions',
        'stg_colorado_exclusions',
        'stg_connecticut_exclusions',
        'stg_delaware_exclusions',
        'stg_district_of_columbia_exclusions',
        'stg_florida_exclusions'
    ];
    col_defs TEXT := $cols$
        id BIGSERIAL PRIMARY KEY,
        record_type VARCHAR NOT NULL DEFAULT 'N/A',
        source_state VARCHAR NOT NULL DEFAULT 'N/A',
        source_state_abbr VARCHAR NOT NULL DEFAULT 'N/A',
        source_name VARCHAR NOT NULL DEFAULT 'N/A',
        provider_name VARCHAR NOT NULL DEFAULT 'N/A',
        first_name VARCHAR NOT NULL DEFAULT 'N/A',
        middle_name VARCHAR NOT NULL DEFAULT 'N/A',
        last_name VARCHAR NOT NULL DEFAULT 'N/A',
        business_name VARCHAR NOT NULL DEFAULT 'N/A',
        aka VARCHAR NOT NULL DEFAULT 'N/A',
        dba VARCHAR NOT NULL DEFAULT 'N/A',
        npi VARCHAR NOT NULL DEFAULT 'N/A',
        provider_type VARCHAR NOT NULL DEFAULT 'N/A',
        license_number VARCHAR NOT NULL DEFAULT 'N/A',
        provider_number VARCHAR NOT NULL DEFAULT 'N/A',
        action_type VARCHAR NOT NULL DEFAULT 'N/A',
        action_effective_date VARCHAR NOT NULL DEFAULT 'N/A',
        active_period VARCHAR NOT NULL DEFAULT 'N/A',
        exclusion_authority VARCHAR NOT NULL DEFAULT 'N/A',
        exclusion_reason VARCHAR NOT NULL DEFAULT 'N/A',
        reinstatement_date VARCHAR NOT NULL DEFAULT 'N/A',
        source_url VARCHAR NOT NULL DEFAULT 'N/A',
        source_file_url VARCHAR NOT NULL DEFAULT 'N/A',
        source_file_date VARCHAR NOT NULL DEFAULT 'N/A',
        date_accessed VARCHAR NOT NULL DEFAULT 'N/A',
        data_quality_status VARCHAR NOT NULL DEFAULT 'N/A',
        notes VARCHAR NOT NULL DEFAULT 'N/A'
    $cols$;
BEGIN
    FOREACH table_name IN ARRAY table_names LOOP
        EXECUTE format('CREATE TABLE exclusion_project.%I (%s)', table_name, col_defs);
    END LOOP;
END $$;

-- Helpful indexes for later searching.
CREATE INDEX IF NOT EXISTS idx_all_state_exclusions_source_state ON exclusion_project.all_state_exclusions(source_state);
CREATE INDEX IF NOT EXISTS idx_all_state_exclusions_npi ON exclusion_project.all_state_exclusions(npi);
CREATE INDEX IF NOT EXISTS idx_all_state_exclusions_provider_name ON exclusion_project.all_state_exclusions(provider_name);
CREATE INDEX IF NOT EXISTS idx_all_state_exclusions_last_name ON exclusion_project.all_state_exclusions(last_name);
CREATE INDEX IF NOT EXISTS idx_all_state_exclusions_business_name ON exclusion_project.all_state_exclusions(business_name);

COMMIT;

-- Confirm tables and columns after running the script.
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'exclusion_project'
ORDER BY table_name;
