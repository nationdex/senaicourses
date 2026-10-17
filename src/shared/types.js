// Shared data shapes (JSDoc only — no runtime code). Import for editor hints:
//   /** @type {import("../shared/types.js").Course} */

/**
 * @typedef {object} Schedule
 * @property {string} periodo
 * @property {string} horario
 */

/**
 * @typedef {object} Course
 * @property {string} name
 * @property {string} slug
 * @property {number} id
 * @property {number} hours
 * @property {number | null} vagas null = source has no real seat-count data
 *   (e.g. a marketing feed with a fixed placeholder) — never show a fabricated number.
 * @property {number} turmas
 * @property {string[]} startDates
 * @property {Schedule[]} schedules
 * @property {string[]} prices
 * @property {boolean} isBolsa true when the course name contains "BOLSA" (always a free scholarship)
 * @property {string} [url] direct link to the course page on the state's own site
 */

/**
 * One real course category a state's source exposes (e.g. "Automação").
 * `slug` is a stable URL/DB-safe id; `label` is the display name.
 * @typedef {object} Area
 * @property {string} slug
 * @property {string} label
 */

/**
 * @typedef {object} CoursesData
 * @property {Course[]} courses
 * @property {string} lastUpdated ISO timestamp
 */

/**
 * @typedef {object} UnitInfo
 * @property {number} id internal escolaId used for turmas calls — not the official unit number
 * @property {string} name
 * @property {number} [officialId] official unit number shown on the state's site
 */

/**
 * Two-letter Brazilian state code (active adapter or "coming soon").
 * @typedef {"sp"|"sc"|"ac"|"al"|"am"|"ap"|"ba"|"ce"|"df"|"es"|"go"|"ma"|"mg"|"ms"|"mt"|"pa"|"pb"|"pe"|"pi"|"pr"|"rj"|"rn"|"ro"|"rr"|"rs"|"se"|"to"} StateCode
 */

/**
 * @typedef {object} StateInfo
 * @property {StateCode} uf
 * @property {string} name
 * @property {string} sourceLabel domain shown as the data source
 * @property {"active"|"coming-soon"} status
 * @property {string} logo
 * @property {string} flag
 * @property {number} hue OKLCH hue (0-360) — drives --brand-hue
 */

/**
 * Contract every state adapter implements (see adapters/registry.js).
 * @typedef {object} StateAdapter
 * @property {() => Promise<UnitInfo[]>} getUnits
 * @property {() => Promise<Area[]>} getAreas
 * @property {(area: string) => Promise<number[]>} getCatalogUnitIds
 * @property {(unitId: number, area: string, force?: boolean) => Promise<CoursesData>} getUnitData
 * @property {(unitId: number, area: string, force?: boolean) => Promise<CoursesData>} getUnitPaidData
 */

/**
 * Row shape as stored in SurrealDB (see db/schema.surql).
 * @typedef {object} DbCourse
 * @property {string} uf
 * @property {string} area
 * @property {number} unit_id
 * @property {number} course_id
 * @property {string} name
 * @property {string} slug
 * @property {number} hours
 * @property {number | null} vagas
 * @property {number} turmas
 * @property {string[]} start_dates
 * @property {Schedule[]} schedules
 * @property {string[]} prices
 * @property {boolean} is_paid
 * @property {boolean} is_bolsa
 * @property {string} [url]
 * @property {string} scraped_at
 */

export {};
