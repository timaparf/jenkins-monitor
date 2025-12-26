#!/bin/bash

# Path to the CSV data file (not the log file)
CSV_FILE="/var/lib/jenkins-monitor/processes.csv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if file exists
if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Error: CSV file not found at $CSV_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}Processing $CSV_FILE...${NC}"
echo

# Process CPU peaks
echo "Top 5 Jobs by Peak CPU Usage:"
echo "-----------------------------------------------------------------"
awk -F',' 'NR>0 {
    if ($4 > max[$3] || !(($3) in max)) {
        max[$3] = $4
        timestamp[$3] = $1
    }
}
END {
    for (job in max) {
        printf "%s\t%s\t%s\n", max[job], job, timestamp[job]
    }
}' "$CSV_FILE" | sort -nr | head -n 5 | \
while read -r cpu job timestamp; do
    printf "%-45s %6.2f%%  (at %s)\n" "$job" "$cpu" "$timestamp"
done
echo

# Process memory peaks
echo "Top 5 Jobs by Peak Memory Usage:"
echo "-----------------------------------------------------------------"
awk -F',' 'NR>0 {
    if ($5 > max[$3] || !(($3) in max)) {
        max[$3] = $5
        timestamp[$3] = $1
    }
}
END {
    for (job in max) {
        printf "%s\t%s\t%s\n", max[job], job, timestamp[job]
    }
}' "$CSV_FILE" | sort -nr | head -n 5 | \
while read -r mem job timestamp; do
    printf "%-45s %6.2f%%  (at %s)\n" "$job" "$mem" "$timestamp"
done
echo

echo "Stats generated at: $(date)"
