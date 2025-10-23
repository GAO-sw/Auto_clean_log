
#Experiment 1: Linux Log Archiving and Monitoring Script

This project is an experimental assignment for a Computer Architecture course, which includes two core Shell scripts.

##Script Functionality

1. clean_log.sh:

Monitors the disk partition usage of a specified directory.

When the usage reaches or exceeds a preset threshold, it automatically archives the oldest files in the directory until the space usage meets the requirement.

Supports two compression algorithms: gzip (default) and lzma (enabled via an environment variable).

The script's logic is robust and capable of handling various edge cases.

2. test_clean_log.sh:

A fully automated test script used to verify the correctness of clean_log.sh.

It includes four core test cases:

Normal Archiving: Simulates disk usage exceeding the limit to verify the archiving and deletion functionality.

Skip Archiving: Simulates normal disk space usage to verify that the script performs no action.

Error Handling: Simulates passing a non-existent directory to verify that the script exits with an error.

LZMA Compression: Verifies that the script correctly uses the lzma algorithm when the corresponding environment variable is set.

##How to Run
###Running the Main Script (clean_log.sh)
Bash
download
content_copy
expand_less
# Usage: ./clean_log.sh <target_directory> [threshold_percentage] [backup_directory]
# Example: Monitor the 'log' directory with a threshold of 80% and back up to 'backup'
./clean_log.sh ./log 80 ./backup
