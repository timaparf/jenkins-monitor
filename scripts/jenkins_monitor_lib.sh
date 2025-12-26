#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print a horizontal line
print_line() {
    local length=${1:-100}
    printf '%.0s-' $(seq 1 $length)
    echo
}

# Get process info with BUILD_URL
# Returns array of "pid,process_name,build_path,cpu,mem" entries
get_jenkins_processes() {
    local -a process_info=()

    for pid_dir in /proc/[0-9]*; do
        pid="${pid_dir##*/}"

        if [ -d "/proc/$pid" ]; then
            build_url=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep '^BUILD_URL=' | cut -d'=' -f2)

            if [ -n "$build_url" ]; then
                process_name=$(ps -p "$pid" -o comm= 2>/dev/null)
                cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo 0)
                mem=$(ps -p "$pid" -o %mem= 2>/dev/null | tr -d ' ' || echo 0)

                build_path=$(echo "$build_url" | gawk -F'/job/' '{for(i=2;i<=NF;i++) {split($i,a,"/"); printf a[1] (i==NF ? "" : "/")}} END {print ""}')

                # Escape any commas
                build_path=$(echo "$build_path" | sed 's/,/\\,/g')
                [ ${#build_path} -gt 35 ] && build_path="${build_path:0:32}..."
                [ ${#process_name} -gt 20 ] && process_name="${process_name:0:17}..."

                process_info+=("$pid,$process_name,$build_url,$cpu,$mem")
            fi
        fi
    done

    echo "${process_info[@]}"
}

# Get total CPU usage and per-core usage
get_cpu_usage() {
    # Run mpstat once, 1 second interval
    mpstat -P ALL 1 1 | gawk '
    BEGIN {
        total_cpu = ""
    }
    /^Average:/ {
        cpu=$2
        idle=$NF
        usage=100-idle

        if (cpu == "all") {
            total_cpu = sprintf("%.2f", usage)
        } else {
            per_cpu[cpu] = sprintf("%.2f", usage)
        }
    }
    END {
        # Print total CPU usage
        printf "CPU_TOTAL=%s", total_cpu

        # Print per-core usage
        for (c in per_cpu) {
            printf ",CPU_%s=%s", c, per_cpu[c]
        }
        printf "\n"
    }'
}

# Get total node memory usage (percentage)
get_mem_usage() {
    gawk '
    /MemTotal/ { total=$2 }
    /MemAvailable/ { avail=$2 }
    END {
        if (total > 0) {
            used = total - avail
            printf "MEM_TOTAL=%.2f\n", (used / total) * 100
        } else {
            print "MEM_TOTAL=0.00"
        }
    }' /proc/meminfo
}
