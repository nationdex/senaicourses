#!/bin/sh
# Loads the .surql files into SurrealDB over HTTP (curl only).
#   app/load.sh <database> [file ...]
# Default file set, in dependency order: schema, lib, scrapers, ui, api, seed.
# Target: namespace "senai", the given database, at $SURREAL_URL (default
# http://127.0.0.1:8000), credentials $SURREAL_USER:$SURREAL_PASS (default root:root).
# Prints every statement error and exits non-zero if any statement failed.
set -eu
cd "$(dirname "$0")"
db="${1:?usage: load.sh <database> [file ...]}"; shift
url="${SURREAL_URL:-http://127.0.0.1:8000}"
cred="${SURREAL_USER:-root}:${SURREAL_PASS:-root}"
if [ "$#" -eq 0 ]; then
	set -- schema.surql $(for d in lib scrapers ui api seed; do ls $d/*.surql 2>/dev/null; done)
fi
curl -sf -u "$cred" -X POST "$url/sql" -H 'Accept: application/json' \
	--data-binary "DEFINE NAMESPACE IF NOT EXISTS senai; USE NS senai; DEFINE DATABASE IF NOT EXISTS $db;" >/dev/null
fail=0
for f in "$@"; do
	out=$(curl -s -u "$cred" -X POST "$url/sql" -H 'Accept: application/json' \
		-H 'surreal-ns: senai' -H "surreal-db: $db" --data-binary @"$f")
	errs=$(printf '%s' "$out" | jq -r '.. | objects | (select(.status? == "ERR") | .result), (select(.code? != null) | (.information // .description))' 2>/dev/null || echo "unparseable response: $out")
	if [ -n "$errs" ]; then printf 'ERR %s:\n%s\n' "$f" "$errs" >&2; fail=1; else echo "ok  $f"; fi
done
exit $fail
