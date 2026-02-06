#!/usr/bin/env bash
set -euo pipefail

CSV_FILE="/var/lib/jenkins-monitor/processes.csv"
JOB_URL="${1:-}"

# ----------------------------
# Adjustable thresholds
# ----------------------------
LOW_THRESHOLD="${LOW_THRESHOLD:-50}"     # < LOW => yellow
HIGH_THRESHOLD="${HIGH_THRESHOLD:-90}"   # >= HIGH => red

# ----------------------------
# Soft ANSI colors
# ----------------------------
RED="\033[0;31m"     # light red
GREEN="\033[0;32m"   # light green
YELLOW="\033[0;33m"  # light yellow
NC="\033[0m"         # reset

usage() {
  echo "Usage: $0 <jenkins_job_url>"
  echo ""
  echo "Optional env vars:"
  echo "  LOW_THRESHOLD=50"
  echo "  HIGH_THRESHOLD=90"
}

if [[ -z "$JOB_URL" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
  echo "CSV file not found: $CSV_FILE"
  exit 1
fi

# sanity checks
if ! [[ "$LOW_THRESHOLD" =~ ^[0-9]+([.][0-9]+)?$ ]] || ! [[ "$HIGH_THRESHOLD" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Thresholds must be numeric. LOW_THRESHOLD=$LOW_THRESHOLD HIGH_THRESHOLD=$HIGH_THRESHOLD"
  exit 1
fi

if (( $(awk "BEGIN{print ($LOW_THRESHOLD >= $HIGH_THRESHOLD)}") )); then
  echo "LOW_THRESHOLD must be < HIGH_THRESHOLD. Got LOW=$LOW_THRESHOLD HIGH=$HIGH_THRESHOLD"
  exit 1
fi

echo ""
echo "Jenkins job url  : $JOB_URL"
echo "CSV source       : $CSV_FILE"
echo "Thresholds       : yellow < ${LOW_THRESHOLD}, green ${LOW_THRESHOLD}-${HIGH_THRESHOLD}, red >= ${HIGH_THRESHOLD}"
echo ""

gawk \
  -v job="$JOB_URL" \
  -v LOW="$LOW_THRESHOLD" \
  -v HIGH="$HIGH_THRESHOLD" \
  -v RED="$RED" \
  -v GREEN="$GREEN" \
  -v YELLOW="$YELLOW" \
  -v NC="$NC" '
function fmt(val) { return sprintf("%.2f %%", val) }

function colorize(val,    c) {
  if (val >= HIGH) c = RED
  else if (val < LOW) c = YELLOW
  else c = GREEN
  return c fmt(val) NC
}

# percentile helper:
# - input: array arr[1..n]
# - output: value at percentile p (0..100)
function percentile(arr, n, p,    i, idx) {
  if (n <= 0) return 0
  # sort numeric ascending
  asort(arr)

  # nearest-rank (simple + stable)
  idx = int((p/100) * n)
  if (idx < 1) idx = 1
  if (idx > n) idx = n

  return arr[idx]
}

function print_stats(title, samples, sum, maxv, values, aboveLow, aboveHigh,    avg, p50, p75, p90) {
  if (samples <= 0) {
    print "\n" title ":"
    print "  No samples"
    return
  }

  avg = sum / samples
  p50 = percentile(values, samples, 50)
  p75 = percentile(values, samples, 75)
  p90 = percentile(values, samples, 90)

  print "\n" title ":"
  printf "  Avg            : %s\n", colorize(avg)
  printf "  P50 (median)   : %s\n", colorize(p50)
  printf "  P75            : %s\n", colorize(p75)
  printf "  P90            : %s\n", colorize(p90)
  printf "  Max            : %s\n", colorize(maxv)

  printf "  Time >= LOW    : %s%d%s / %d  (%.2f %%)\n", GREEN, aboveLow, NC, samples, (aboveLow/samples)*100
  printf "  Time >= HIGH   : %s%d%s / %d  (%.2f %%)\n", RED, aboveHigh, NC, samples, (aboveHigh/samples)*100
}

NR == 1 { next }

$0 ~ job {

  samples++

  # ----------------------------
  # Node CPU total
  # ----------------------------
  if (match($0, /CPU_TOTAL=[0-9.]+/, m)) {
    split(m[0], t, "=")
    total = t[2] + 0

    node_cpu_vals[samples] = total
    node_cpu_sum += total
    if (total > node_cpu_max) node_cpu_max = total

    if (total >= LOW)  node_cpu_above_low++
    if (total >= HIGH) node_cpu_above_high++
  }

  # ----------------------------
  # Node MEM total
  # ----------------------------
  if (match($0, /MEM_TOTAL=[0-9.]+/, mm)) {
    split(mm[0], mt, "=")
    memt = mt[2] + 0

    node_mem_vals[samples] = memt
    node_mem_sum += memt
    if (memt > node_mem_max) node_mem_max = memt

    if (memt >= LOW)  node_mem_above_low++
    if (memt >= HIGH) node_mem_above_high++
  }

  # ----------------------------
  # Per-core CPU usage (store max/avg only)
  # ----------------------------
  rest = $0
  while (match(rest, /CPU_[0-9]+=[0-9.]+/)) {
    split(substr(rest, RSTART, RLENGTH), kv, "=")
    core = kv[1]
    val  = kv[2] + 0

    core_sum[core] += val
    core_cnt[core]++
    if (val > core_max[core]) core_max[core] = val

    rest = substr(rest, RSTART + RLENGTH)
  }
}

END {
  if (samples == 0) {
    print "No data found for this job."
    exit 0
  }

  print "Samples collected : " samples

  print_stats("Node CPU usage", samples, node_cpu_sum, node_cpu_max, node_cpu_vals, node_cpu_above_low, node_cpu_above_high)
  print_stats("Node Memory usage", samples, node_mem_sum, node_mem_max, node_mem_vals, node_mem_above_low, node_mem_above_high)

  print "\nPer-core CPU usage (avg/max):"
  for (c in core_sum) {
    avg = core_sum[c] / core_cnt[c]
    max = core_max[c]
    printf "  %-6s avg=%s  max=%s\n", c, colorize(avg), colorize(max)
  }
}
' "$CSV_FILE"
