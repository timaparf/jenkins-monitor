#!/usr/bin/env bash

CSV_FILE="/var/lib/jenkins-monitor/processes.csv"
JOB_URL="$1"

if [[ -z "$JOB_URL" ]]; then
  echo "Usage: $0 <jenkins_job_url>"
  exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
  echo "CSV file not found: $CSV_FILE"
  exit 1
fi

# Extract job name -> jobs/<job>
JOB_PATH=$(echo "$JOB_URL" \
  | sed -E 's|https?://[^/]+||' \
  | sed -E 's|/job/|/|g' \
  | sed -E 's|/[0-9]+/?$||' \
  | sed -E 's|^/||; s|/$||' \
  | gawk -F'/' '{ print "jobs/" $NF }')

echo ""
echo "Jenkins job url  : $JOB_URL"
echo "CSV source       : $CSV_FILE"
echo ""

gawk -v job="$JOB_URL" '
NR==1 { next }

$0 ~ job {

  samples++

  row_cpu = 0
  row_mem = 0

  # Per-process CPU & MEM (job-level)
  n = split($0, fields, " ")
  for (i = 1; i <= n; i++) {
    split(fields[i], parts, ",")
    cpu = parts[4]
    mem = parts[5]

    if (cpu ~ /^[0-9.]+$/) row_cpu += cpu
    if (mem ~ /^[0-9.]+$/) row_mem += mem
  }

  cpu_sum += row_cpu
  mem_sum += row_mem

  if (row_cpu > cpu_max) cpu_max = row_cpu
  if (row_mem > mem_max) mem_max = row_mem

  # --------------------
  # Node-level CPU total
  # --------------------
  if (match($0, /CPU_TOTAL=[0-9.]+/, m)) {
    split(m[0], t, "=")
    total = t[2]
    total_cpu_sum += total
    if (total > total_cpu_max) total_cpu_max = total
  }

  # --------------------
  # Node-level MEM total
  # --------------------
  if (match($0, /MEM_TOTAL=[0-9.]+/, mm)) {
    split(mm[0], mt, "=")
    memt = mt[2]
    total_mem_sum += memt
    if (memt > total_mem_max) total_mem_max = memt
  }

  # Per-core CPU
  rest = $0
  while (match(rest, /CPU_[0-9]+=[0-9.]+/)) {
    split(substr(rest, RSTART, RLENGTH), kv, "=")
    core = kv[1]
    val  = kv[2]

    core_sum[core] += val
    core_cnt[core]++
    if (val > core_max[core]) core_max[core] = val

    rest = substr(rest, RSTART + RLENGTH)
  }
}

END {
  if (samples == 0) {
    print "No data found for this job."
    exit
  }

  printf "Samples collected : %d\n", samples

  print "\nJob CPU (sum of processes):"
  printf "  Avg job CPU     : %.2f %%\n", cpu_sum / samples
  printf "  Max job CPU     : %.2f %%\n", cpu_max

  print "\nJob Memory (sum of processes):"
  printf "  Avg job MEM     : %.2f %%\n", mem_sum / samples
  printf "  Max job MEM     : %.2f %%\n", mem_max

  print "\nNode CPU usage:"
  printf "  Avg total CPU   : %.2f %%\n", total_cpu_sum / samples
  printf "  Max total CPU   : %.2f %%\n", total_cpu_max

  print "\nNode Memory usage:"
  printf "  Avg total MEM   : %.2f %%\n", total_mem_sum / samples
  printf "  Max total MEM   : %.2f %%\n", total_mem_max

  print "\nPer-core CPU usage:"
  for (c in core_sum) {
    printf "  %-6s avg=%6.2f %%  max=%6.2f %%\n",
           c,
           core_sum[c] / core_cnt[c],
           core_max[c]
  }
}
' "$CSV_FILE"
