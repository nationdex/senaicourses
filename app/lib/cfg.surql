-- URL prefix every route lives under: SurrealDB serves custom APIs at
-- /api/<namespace>/<database>/<path>. Derived from the session so the same code
-- works in any database (dev databases, production).
DEFINE FUNCTION OVERWRITE fn::cfg::base() -> string {
	RETURN '/api/' + session::ns() + '/' + session::db();
};
