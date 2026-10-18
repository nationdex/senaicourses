-- Data model. Scrapers WRITE these tables (through fn::db::*), the UI only READS them.
-- Idempotent (OVERWRITE): safe to load on every boot.

-- state: one row per Brazilian state (seeded from seed/states.surql).
DEFINE TABLE OVERWRITE state SCHEMAFULL;
DEFINE FIELD OVERWRITE uf           ON state TYPE string;
DEFINE FIELD OVERWRITE name         ON state TYPE string;
DEFINE FIELD OVERWRITE source_label ON state TYPE string;
DEFINE FIELD OVERWRITE status       ON state TYPE string ASSERT $value IN ['active', 'coming-soon'];
DEFINE FIELD OVERWRITE sort         ON state TYPE int;
DEFINE INDEX OVERWRITE state_uf ON TABLE state FIELDS uf UNIQUE;

-- area: a course category ("sector") a state's source exposes.
DEFINE TABLE OVERWRITE area SCHEMAFULL;
DEFINE FIELD OVERWRITE uf    ON area TYPE string;
DEFINE FIELD OVERWRITE slug  ON area TYPE string;
DEFINE FIELD OVERWRITE label ON area TYPE string;
DEFINE INDEX OVERWRITE area_uf ON TABLE area FIELDS uf;

-- unit: a school/unit of a state.
DEFINE TABLE OVERWRITE unit SCHEMAFULL;
DEFINE FIELD OVERWRITE uf          ON unit TYPE string;
DEFINE FIELD OVERWRITE unit_id     ON unit TYPE number;
DEFINE FIELD OVERWRITE name        ON unit TYPE string;
DEFINE FIELD OVERWRITE official_id ON unit TYPE option<number>;
DEFINE INDEX OVERWRITE unit_uf ON TABLE unit FIELDS uf;

-- course: one row per (uf, área, course, unit, free|paid).
DEFINE TABLE OVERWRITE course SCHEMAFULL;
DEFINE FIELD OVERWRITE uf          ON course TYPE string;
DEFINE FIELD OVERWRITE area        ON course TYPE string;
DEFINE FIELD OVERWRITE unit_id     ON course TYPE number;
DEFINE FIELD OVERWRITE course_id   ON course TYPE number;
DEFINE FIELD OVERWRITE name        ON course TYPE string;
DEFINE FIELD OVERWRITE slug        ON course TYPE string;
DEFINE FIELD OVERWRITE hours       ON course TYPE number;
-- null = the source has no real seat count (never store a fabricated number).
DEFINE FIELD OVERWRITE vagas       ON course TYPE number | null;
DEFINE FIELD OVERWRITE turmas      ON course TYPE number;
DEFINE FIELD OVERWRITE start_dates ON course TYPE array<string>;
DEFINE FIELD OVERWRITE schedules   ON course TYPE array<object>;
DEFINE FIELD OVERWRITE schedules.*.periodo ON course TYPE string;
DEFINE FIELD OVERWRITE schedules.*.horario ON course TYPE string;
DEFINE FIELD OVERWRITE prices      ON course TYPE array<string>;
DEFINE FIELD OVERWRITE is_paid     ON course TYPE bool;
DEFINE FIELD OVERWRITE is_bolsa    ON course TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE url         ON course TYPE option<string>;
DEFINE FIELD OVERWRITE scraped_at  ON course TYPE string;
DEFINE INDEX OVERWRITE course_lookup     ON TABLE course FIELDS uf, area, unit_id, is_paid;
DEFINE INDEX OVERWRITE course_scraped_at ON TABLE course FIELDS scraped_at;
