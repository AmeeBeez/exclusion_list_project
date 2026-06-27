-- apply_null_constraints.sql
-- Purpose:
-- Apply the standard nullability rules to existing exclusion_project tables
-- without dropping or recreating them.
--
-- Required workflow/source columns are kept NOT NULL:
--   record_type, source_state, source_state_abbr, source_name,
--   provider_name, data_quality_status
--
-- Sparse source-provided attributes are made nullable so blank CSV cells can
-- import as database NULL values.

BEGIN;

DO $$
DECLARE
    table_name TEXT;
    optional_column TEXT;
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
    optional_columns TEXT[] := ARRAY[
        'first_name',
        'middle_name',
        'last_name',
        'business_name',
        'aka',
        'dba',
        'npi',
        'provider_type',
        'license_number',
        'provider_number',
        'action_type',
        'action_effective_date',
        'active_period',
        'exclusion_authority',
        'exclusion_reason',
        'reinstatement_date',
        'source_url',
        'source_file_url',
        'source_file_date',
        'date_accessed',
        'notes'
    ];
BEGIN
    FOREACH table_name IN ARRAY table_names LOOP
        IF to_regclass(format('exclusion_project.%I', table_name)) IS NULL THEN
            RAISE NOTICE 'Skipping missing table exclusion_project.%', table_name;
            CONTINUE;
        END IF;

        EXECUTE format($sql$
            UPDATE exclusion_project.%I
            SET
                record_type = COALESCE(NULLIF(BTRIM(record_type), ''), 'provider_record'),
                source_state = COALESCE(NULLIF(BTRIM(source_state), ''), 'N/A'),
                source_state_abbr = COALESCE(NULLIF(BTRIM(source_state_abbr), ''), 'N/A'),
                source_name = COALESCE(NULLIF(BTRIM(source_name), ''), 'N/A'),
                provider_name = COALESCE(NULLIF(BTRIM(provider_name), ''), 'N/A'),
                data_quality_status = COALESCE(NULLIF(BTRIM(data_quality_status), ''), 'clean_ready_for_import')
        $sql$, table_name);

        EXECUTE format($sql$
            ALTER TABLE exclusion_project.%I
                ALTER COLUMN record_type SET DEFAULT 'provider_record',
                ALTER COLUMN record_type SET NOT NULL,
                ALTER COLUMN source_state SET DEFAULT 'N/A',
                ALTER COLUMN source_state SET NOT NULL,
                ALTER COLUMN source_state_abbr SET DEFAULT 'N/A',
                ALTER COLUMN source_state_abbr SET NOT NULL,
                ALTER COLUMN source_name SET DEFAULT 'N/A',
                ALTER COLUMN source_name SET NOT NULL,
                ALTER COLUMN provider_name SET DEFAULT 'N/A',
                ALTER COLUMN provider_name SET NOT NULL,
                ALTER COLUMN data_quality_status SET DEFAULT 'clean_ready_for_import',
                ALTER COLUMN data_quality_status SET NOT NULL
        $sql$, table_name);

        FOREACH optional_column IN ARRAY optional_columns LOOP
            EXECUTE format(
                'ALTER TABLE exclusion_project.%I ALTER COLUMN %I DROP NOT NULL, ALTER COLUMN %I DROP DEFAULT',
                table_name,
                optional_column,
                optional_column
            );
        END LOOP;
    END LOOP;
END $$;

COMMIT;

SELECT table_name, column_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'exclusion_project'
ORDER BY table_name, ordinal_position;
