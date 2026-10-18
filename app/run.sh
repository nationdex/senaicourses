#!/bin/sh
# Starts SurrealDB (the only server process), loads every .surql into the database and
# seeds it. Uses the `surreal` binary when it is on PATH, otherwise the Docker image.
#   app/run.sh            start (if needed) + load + seed
#   app/run.sh --load     only (re)load into an already running server
# Env: SURREAL_DB (cursos) SURREAL_PORT (8000) SURREAL_USER/SURREAL_PASS (root/root)
#      SURREAL_DATA (~/.local/share/senai-surreal) SURREAL_IMAGE (surrealdb/surrealdb:latest)
#      SURREAL_ALLOW_NET (comma list of hosts, default: allow all)  SURREAL_CONTAINER (senai-surreal)
# The crawl secret lives in app/.crawl-key (git-ignored, created on first boot) and is
# written into the database (crawl_secret:main) on every run; crawl.sh reads the same file.
set -eu
cd "$(dirname "$0")"
here=$(pwd)
db="${SURREAL_DB:-cursos}"
port="${SURREAL_PORT:-8000}"
user="${SURREAL_USER:-root}"
pass="${SURREAL_PASS:-root}"
data="${SURREAL_DATA:-$HOME/.local/share/senai-surreal}"
image="${SURREAL_IMAGE:-surrealdb/surrealdb:latest}"
name="${SURREAL_CONTAINER:-senai-surreal}"
url="http://127.0.0.1:$port"
net="${SURREAL_ALLOW_NET:-}"
export SURREAL_URL="$url" SURREAL_USER="$user" SURREAL_PASS="$pass"

up() { curl -sf "$url/health" >/dev/null 2>&1; }

start_docker() {
	if docker inspect "$name" >/dev/null 2>&1; then
		if docker inspect "$name" | grep -q SURREAL_BUCKET_FOLDER_ALLOWLIST; then
			docker start "$name" >/dev/null
			return
		fi
		echo "run.sh: recreating $name (needs the assets mount/allow-list; data volume is kept)" >&2
		docker rm -f "$name" >/dev/null
	fi
	mkdir -p "$data"
	docker run -d --name "$name" --user "$(id -u):$(id -g)" -p "127.0.0.1:$port:8000" \
		-v "$data:/data" -v "$here/assets:/assets:ro" -e SURREAL_BUCKET_FOLDER_ALLOWLIST=/assets \
		"$image" start --user "$user" --pass "$pass" --bind 0.0.0.0:8000 \
		--allow-net ${net:+"$net"} --allow-experimental files --log info surrealkv:///data/senai.kv >/dev/null
}

start_binary() {
	mkdir -p "$data"
	SURREAL_BUCKET_FOLDER_ALLOWLIST="$here/assets" surreal start --user "$user" --pass "$pass" \
		--bind "127.0.0.1:$port" --allow-net ${net:+"$net"} --allow-experimental files --log info \
		"surrealkv://$data/senai.kv" &
	trap 'kill $! 2>/dev/null' INT TERM
	bg=1
}

bg=0
if [ "${1:-}" != "--load" ] && ! up; then
	if command -v surreal >/dev/null 2>&1; then start_binary; else start_docker; fi
fi
i=0
until up; do
	i=$((i + 1)); [ "$i" -gt 60 ] && { echo "run.sh: SurrealDB did not come up" >&2; exit 1; }
	sleep 1
done

# Bucket path: /assets in the container, the real folder when running the binary.
files="schema.surql $(for d in lib scrapers ui api seed; do ls $d/*.surql 2>/dev/null; done)"
tmp=""
if [ "$bg" = 1 ]; then
	tmp=$(mktemp); sed "s#file:/assets#file:$here/assets#" api/assets.surql >"$tmp"
	files=$(printf '%s' "$files" | sed "s#api/assets.surql#$tmp#")
fi
# shellcheck disable=SC2086
./load.sh "$db" $files
[ -n "$tmp" ] && rm -f "$tmp"

if [ ! -s .crawl-key ]; then
	(umask 077; head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' >.crawl-key)
fi
key=$(cat .crawl-key)
curl -sf -u "$user:$pass" -X POST "$url/sql" -H 'Accept: application/json' -H 'surreal-ns: senai' \
	-H "surreal-db: $db" --data-binary "UPSERT crawl_secret:main SET value = '$key';" >/dev/null
echo "ready: $url/api/senai/$db/health"
if [ "$bg" = 1 ]; then wait; fi
