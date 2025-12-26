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

echo ""
echo "Jenkins job url  : $JOB_URL"
echo "CSV source       : $CSV_FILE"
echo ""

awk -v job="$JOB_URL" '
NR==1 { next }

index($0, job) {
  samples++

  row_cpu = 0
  row_mem = 0

  n = split($0, fields, " ")
  for (i=1; i<=n; i++) {
    split(fields[i], parts, ",")
    cpu = parts[4]
    mem = parts[5]
    if (cpu+0 == cpu) row_cpu += cpu
    if (mem+0 == mem) row_mem += mem
  }

  cpu_sum += row_cpu
  mem_sum += row_mem

  if (row_cpu > cpu_max) cpu_max = row_cpu
  if (row_mem > mem_max) mem_max = row_mem

  # Node-level CPU_TOTAL
  for (i=1;i<=NF;i++) {
    if ($i ~ /^CPU_TOTAL=/) {
      split($i, a, "=")
      total_cpu_sum += a[2]
      if (a[2] > total_cpu_max) total_cpu_max = a[2]
    }
    if ($i ~ /^MEM_TOTAL=/) {
      split($i, a, "=")
      total_mem_sum += a[2]
      if (a[2] > total_mem_max) total_mem_max = a[2]
    }
    if ($i ~ /^CPU_[0-9]+=/) {
      split($i, a, "=")
      core_id = a[1]
      val = a[2]
      core_cpu_sum[core_id] += val
      core_cpu_count[core_id]++
      if (val > core_cpu_max[core_id]) core_cpu_max[core_id] = val
    }
  }
}

END {
  if (samples==0) {
    print "No data found for this job."
    exit
  }

  printf "Samples collected : %d\n", samples

  print "\nJob CPU (sum of processes):"
  printf "  Avg job CPU     : %.2f %%\n", cpu_sum/samples
  printf "  Max job CPU     : %.2f %%\n", cpu_max

  print "\nJob Memory (sum of processes):"
  printf "  Avg job MEM     : %.2f %%\n", mem_sum/samples
  printf "  Max job MEM     : %.2f %%\n", mem_max

  print "\nNode CPU usage:"
  printf "  Avg total CPU   : %.2f %%\n", total_cpu_sum/samples
  printf "  Max total CPU   : %.2f %%\n", total_cpu_max

  print "\nNode Memory usage:"
  printf "  Avg total MEM   : %.2f %%\n", total_mem_sum/samples
  printf "  Max total MEM   : %.2f %%\n", total_mem_max

  print "\nPer-core CPU usage:"
  for (c in core_cpu_sum) {
    printf "  %-6s avg=%6.2f %%  max=%6.2f %%\n",
           c,
           core_cpu_sum[c]/core_cpu_count[c],
           core_cpu_max[c]
  }
}
' "$CSV_FILE"
