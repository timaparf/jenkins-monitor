#!/bin/bash

# Source common library
source "$(dirname "$0")/jenkins_monitor_lib.sh"

# Output CSV file - now using full path
OUTPUT_DIR="/var/lib/jenkins-monitor"
OUTPUT_FILE="${OUTPUT_DIR}/processes.csv"

# Ensure directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Create CSV header if file doesn't exist
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "timestamp,pid,build_path,cpu,mem,cpu_metrics,mem_metrics" > "$OUTPUT_FILE"
fi

# Function to collect and write data
collect_data() {
    # Get current timestamp in ISO 8601 format
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Get process information and write to CSV
    while IFS=',' read -r pid _ build_path cpu mem; do
        cpu_metrics=$(get_cpu_usage)
        mem_metrics=$(get_mem_usage)
        echo "$timestamp,$pid,$build_path,$cpu,$mem,$cpu_metrics,$mem_metrics" >> "$OUTPUT_FILE"
    done < <(get_jenkins_processes)

    # Count number of processes found
    local count=$(get_jenkins_processes | wc -l)
    echo "$(date): Collected data for $count processes"
}

# Check if gawk exists, install if missing (Debian/Ubuntu)
if ! command -v gawk >/dev/null 2>&1; then
    echo "gawk not found. Installing..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y gawk
    else
        echo "Please install gawk manually."
        exit 1
    fi
fi

echo "Starting process monitoring. Writing to $OUTPUT_FILE"
echo "Press Ctrl+C to stop..."

# Run continuously until interrupted
while true; do
    collect_data
    sleep 10
done