#!/bin/sh
# Drives the scrapers inside SurrealDB: for each active state it calls
#   GET {base}/crawl/<uf>/<n>   (secret header x-crawl-key)
# starting at n=0 and following `next` until `done`. POSIX sh + curl + jq.
#
#   app/crawl.sh            crawl every active state not crawled recently
#   app/crawl.sh sp mg      crawl just these states (ignores the "recent" rule)
#
# Safety (ported from the legacy crawler): at most CRAWL_STATE_CONCURRENCY states at once
# (each state is a different upstream site), jittered pause after every step, a failed
# step is retried with exponential back-off, CRAWL_FAILURE_LIMIT consecutive failed steps
# drop the state for this cycle and it is then skipped for 1,2,4,8 (max) cycles, an overall
# time budget (what does not fit is picked up next cycle), and states finished less than
# CRAWL_MAX_AGE_S ago are skipped.
#
# Env (defaults): SURREAL_URL (http://127.0.0.1:8000)  SURREAL_DB (cursos)  CRAWL_KEY (app/.crawl-key)
#   CRAWL_STATE_CONCURRENCY (2)  CRAWL_DELAY_MS (300; pause = delay + random 0..delay)
#   CRAWL_RETRIES (3 retries per step; waits 2s,4s,8s...)  CRAWL_FAILURE_LIMIT (8)
#   CRAWL_BUDGET_S (5400; a full cold cycle needs ~4h: sp ~600 steps, to ~447 — a cycle must reach done, the last step prunes)  CRAWL_MAX_AGE_S (21600)  CRAWL_RETENTION_DAYS (7; 0 = no retention job)
#   CRAWL_STEP_TIMEOUT_S (180)
set -u
cd "$(dirname "$0")"
base="${SURREAL_URL:-http://127.0.0.1:8000}/api/senai/${SURREAL_DB:-cursos}"
key="${CRAWL_KEY:-$(cat .crawl-key 2>/dev/null)}"
[ -n "$key" ] || { echo "crawl.sh: no secret (run app/run.sh first)" >&2; exit 2; }
conc="${CRAWL_STATE_CONCURRENCY:-2}"
delay_ms="${CRAWL_DELAY_MS:-300}"
retries="${CRAWL_RETRIES:-3}"
fail_limit="${CRAWL_FAILURE_LIMIT:-8}"
budget="${CRAWL_BUDGET_S:-5400}"
max_age="${CRAWL_MAX_AGE_S:-21600}"
retention="${CRAWL_RETENTION_DAYS:-7}"
step_timeout="${CRAWL_STEP_TIMEOUT_S:-180}"
all="sp sc al rs ma mg ms go to pi ro ce mt df pr es pa pe rn"
force=0
if [ "$#" -gt 0 ]; then states="$*"; force=1; else states="$all"; fi
now=$(date +%s)
deadline=$((now + budget))
work=$(mktemp -d)
trap 'rm -rf "$work"; kill 0 2>/dev/null' INT TERM
trap 'rm -rf "$work"' EXIT

get() { curl -s --max-time "$step_timeout" -H "x-crawl-key: $key" -w '\n%{http_code}' "$base/$1"; }
log() { printf '%s [%s] %s\n' "$(date +%H:%M:%S)" "$1" "$2"; }
pause() { # delay + random(0..delay) ms
	LC_ALL=C awk -v d="$delay_ms" -v s="$$" 'BEGIN{srand(s+systime()); printf "%.3f", (d + rand()*d)/1000}' | xargs sleep
}

# --- status: skip recently crawled states / states in back-off -------------------------
status=$(get crawl-status)
code=$(printf '%s' "$status" | tail -n1)
[ "$code" = 200 ] || { echo "crawl.sh: /crawl-status -> HTTP $code (is the server up and the key right?)" >&2; exit 2; }
status=$(printf '%s\n' "$status" | sed '$d')

crawl_state() { # $1 = uf ; returns 0 ok / 1 failed / 2 not run
	uf=$1
	n=0; fails=0; steps=0
	while :; do
		if [ "$(date +%s)" -ge "$deadline" ]; then log "$uf" "time budget exhausted at step $n — resuming next cycle"; return 2; fi
		attempt=0; wait_s=2; body=""
		maxretry=$retries; queue=0
		case " sc ce to mt sp " in *" $uf "*) queue=1; maxretry=2 ;; esac   # queue-driven: 3 attempts, then skip_task
		while :; do
			resp=$(get "crawl/$uf/$n"); code=$(printf '%s' "$resp" | tail -n1); body=$(printf '%s\n' "$resp" | sed '$d')
			[ "$code" = 200 ] && break
			attempt=$((attempt + 1))
			[ "$attempt" -gt "$maxretry" ] && break
			log "$uf" "step $n failed (HTTP $code: $(printf '%s' "$body" | head -c 120)), retry $attempt in ${wait_s}s"
			sleep "$wait_s"; wait_s=$((wait_s * 2))
		done
		if [ "$code" != 200 ]; then
			if [ "$queue" = 1 ]; then
				sk=$(get "crawl-skip/$uf/$n" | head -n1)
				if [ "$sk" = 1 ]; then log "$uf" "step $n skipped after $((maxretry + 1)) failures (skip_task)"; n=$((n + 1)); pause; continue; fi
			fi
			fails=$((fails + 1))
			log "$uf" "step $n gave up ($fails/$fail_limit)"
			if [ "$n" = 0 ] || [ "$fails" -ge "$fail_limit" ]; then return 1; fi
			n=$((n + 1)); pause; continue
		fi
		fails=0; steps=$((steps + 1))
		done_flag=$(printf '%s' "$body" | jq -r '.done' 2>/dev/null)
		next=$(printf '%s' "$body" | jq -r '.next // empty' 2>/dev/null)
		note=$(printf '%s' "$body" | jq -r '.note' 2>/dev/null)
		log "$uf" "step $n: $note"
		if [ "$done_flag" = true ]; then log "$uf" "done ($steps steps)"; return 0; fi
		[ -n "$next" ] || { log "$uf" "step $n returned no next and not done"; return 1; }
		n=$next; pause
	done
}

worker() { # claims states through an atomic O_EXCL create, so two workers never take the same one
	for uf in $states; do
		( set -C; : >"$work/claim.$uf" ) 2>/dev/null || continue
		line=$(printf '%s\n' "$status" | awk -v u="$uf" '$1==u')
		if [ "$force" = 0 ] && [ -n "$line" ]; then
			set -- $line
			if [ "$4" -gt 0 ]; then log "$uf" "in back-off ($4 cycle(s) left) — skipping"; get "crawl-report/$uf/skip" >/dev/null; continue; fi
			if [ "$2" -gt 0 ] && [ $(( $(date +%s) - $2 )) -lt "$max_age" ]; then log "$uf" "crawled recently — skipping"; continue; fi
		fi
		crawl_state "$uf"; rc=$?
		case $rc in
			0) get "crawl-report/$uf/ok" >/dev/null ;;
			1) get "crawl-report/$uf/fail" >/dev/null; log "$uf" "FAILED — dropped for this cycle"; : >"$work/failed.$uf" ;;
		esac
	done
}

i=0
while [ "$i" -lt "$conc" ]; do worker & i=$((i + 1)); done
wait

if [ "$retention" -gt 0 ] 2>/dev/null; then
	r=$(get "retention/$retention"); log retention "HTTP $(printf '%s' "$r" | tail -n1), removed $(printf '%s\n' "$r" | sed '$d') stale course(s) (> ${retention}d)"
fi
failed=$(ls "$work" 2>/dev/null | grep -c '^failed\.')
log crawl "cycle finished, $failed state(s) failed"
[ "$failed" -eq 0 ]
