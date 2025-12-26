#!/bin/bash

# Source common library
source "$(dirname "$0")/jenkins_monitor_lib.sh"

# Print header
echo -e "${BLUE}Scanning processes for BUILD_URL...${NC}"
echo

# Print table header
printf "%-10s | %-20s | %-35s | %-8s | %-8s\n" "PID" "PROCESS" "BUILD_PATH" "CPU%" "MEM%"
print_line

# Get and format process information
declare -a results
while IFS=',' read -r pid process_name build_path cpu mem; do
    results+=("$(printf "%-10s | %-20s | %-35s | %8.1f | %8.1f\n" \
        "$pid" "$process_name" "$build_path" "$cpu" "$mem")")
done < <(get_jenkins_processes)

# Sort results by CPU usage in descending order
IFS=$'\n' sorted_results=($(sort -t'|' -k4 -nr <<<"${results[*]}"))
unset IFS

# Print the results
for result in "${sorted_results[@]}"; do
    echo "$result"
done

# Print footer
if [ ${#results[@]} -gt 0 ]; then
    print_line
    echo "Total processes found: ${#results[@]}"
else
    echo "No processes with BUILD_URL found"
fi
