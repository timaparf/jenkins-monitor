# Jenkins Resource Monitor Shell Scripts

A lightweight system service that monitors Jenkins job resource usage on Linux systems. It tracks CPU and memory consumption of running Jenkins jobs and provides analysis tools to identify resource-intensive builds.

## Features

- Continuous monitoring of Jenkins build processes
- CPU and memory usage tracking per build job
- Automated data collection to CSV format
- Built-in analysis tools with peak usage reporting
- Automatic log rotation
- Systemd service integration

## Requirements
Tested on AlmaLinux, probably works on CentOS, Fedora, and RHEL systems.
- Linux system with systemd
- Root access for installation
- Running Jenkins instance

## Usage Options

### Option 1: Quick Standalone Usage
If you just want to try it out without installing:

1. Clone this repository
2. Make scripts executable:
```bash
chmod +x scripts/*.sh
```

3. Run the adhoc directly from the scripts directory:
```bash

# Quick status check
sudo ./scripts/jenkins_monitor_adhoc.sh
```

### Option 2: Full Installation
For permanent monitoring setup:

1. Clone this repository
2. Run the installer as root:
```bash
sudo ./install.sh
```

The installer will:
- Create necessary directories in `/opt/jenkins-monitor` and `/var/lib/jenkins-monitor`
- Set up logging in `/var/log/jenkins-monitor`
- Install and start the systemd service
- Configure log rotation

## Usage

### Monitoring Service

The service runs automatically after installation. To manage it:

```bash
# Check service status
sudo systemctl status jenkins-monitor

# Stop the service
sudo systemctl stop jenkins-monitor

# Start the service
sudo systemctl start jenkins-monitor

# Restart the service
sudo systemctl restart jenkins-monitor
```

### Analysis Tools

1. View current running builds:
```bash
sudo /opt/jenkins-monitor/jenkins_monitor_adhoc.sh
```

Example output:
```
Scanning processes for BUILD_URL...

PID        | PROCESS              | BUILD_PATH                          | CPU%     | MEM%    
----------------------------------------------------------------------------------------------------
146542     | python3              | team/test2                          |   1841.0 |      7.4
----------------------------------------------------------------------------------------------------
```

2. Analyze collected data:
```bash
sudo /opt/jenkins-monitor/02_jenkins_analyze_csv.sh
```

Example output:
```
Processing /var/lib/jenkins-monitor/processes.csv...

Top 5 Jobs by Peak CPU Usage:
-----------------------------------------------------------------
test_project/test_job                               0.10%  (at 2024-12-02T09:59:52Z)

Top 5 Jobs by Peak Memory Usage:
-----------------------------------------------------------------
test_project/test_job                               0.20%  (at 2024-12-02T09:59:52Z)
```

### Data Format

The monitoring service collects data in CSV format with the following columns:
- timestamp: ISO 8601 UTC timestamp
- pid: Process ID
- build_path: Jenkins job path
- cpu: CPU usage percentage
- mem: Memory usage percentage

Example CSV content:
```
timestamp,pid,build_path,cpu,mem
2024-12-02T09:59:52Z,146542,test_project/test_job,0.10,0.20
```

### Data and Logs

- CSV data: `/var/lib/jenkins-monitor/processes.csv`
- Service logs: `/var/log/jenkins-monitor/collector.log`
- Error logs: `/var/log/jenkins-monitor/error.log`

## Uninstallation

Run the uninstaller as root:
```bash
sudo ./uninstall.sh
```

The uninstaller provides options to:
1. Remove everything (scripts, data, and logs)
2. Keep data and logs, remove only scripts and service files
3. Cancel uninstallation

## File Locations

- Installation directory: `/opt/jenkins-monitor`
- Data directory: `/var/lib/jenkins-monitor`
- Log directory: `/var/log/jenkins-monitor`
- Service configuration: `/etc/systemd/system/jenkins-monitor.service`
- Log rotation configuration: `/etc/logrotate.d/jenkins-monitor`
# jenkins-monitor
