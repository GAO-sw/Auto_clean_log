#!/bin/bash

LOG_DIR=$1
THRESHOLD=${2:-70}
BACKUP_DIR="./backup"

if [ -z "$LOG_DIR" ]; then
    echo "Error: No directory path provided."
    exit 1
fi

if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Directory '$LOG_DIR' does not exist."
    exit 1
fi

if [[ "$(realpath "$BACKUP_DIR")" == "$(realpath "$LOG_DIR")"* ]]; then
    echo "Error: The backup directory cannot be inside the monitored directory."
    exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "Script execution started."
echo "Monitoring directory: $LOG_DIR"
echo "Threshold: $THRESHOLD%"

CURRENT_USAGE=$(df --output=pcent "$LOG_DIR" | tail -n 1 | tr -d ' %')
echo "Current disk partition usage: $CURRENT_USAGE%"

if [ "$CURRENT_USAGE" -gt "$THRESHOLD" ]; then
    echo "Usage exceeds the threshold. Starting cleanup process..."

    DISK_INFO=$(df --output=size,used "$LOG_DIR" | tail -n 1)
    TOTAL_SPACE_KB=$(echo $DISK_INFO | awk '{print $1}')
    USED_SPACE_KB=$(echo $DISK_INFO | awk '{print $2}')
    TARGET_USED_KB=$((TOTAL_SPACE_KB * THRESHOLD / 100))
    BYTES_TO_FREE_KB=$((USED_SPACE_KB - TARGET_USED_KB))
    
    echo "Need to free at least $(printf "%.2f" $(echo "$BYTES_TO_FREE_KB/1024" | bc -l)) MB of space."

    mapfile -t FILES_TO_ARCHIVE < <(find "$LOG_DIR" -maxdepth 1 -type f -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-)

    declare -a SELECTED_FILES
    FREED_SPACE_KB=0

    for file in "${FILES_TO_ARCHIVE[@]}"; do
        if [ "$FREED_SPACE_KB" -ge "$BYTES_TO_FREE_KB" ]; then
            break
        fi
        FILE_SIZE_KB=$(du -k "$file" | awk '{print $1}')
        FREED_SPACE_KB=$((FREED_SPACE_KB + FILE_SIZE_KB))
        SELECTED_FILES+=("$file")
    done
    
    if [ ${#SELECTED_FILES[@]} -eq 0 ]; then
        echo "No archivable files found."
        exit 0
    fi

    echo "Archiving ${#SELECTED_FILES[@]} oldest files..."
    
    ARCHIVE_NAME="backup_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    FULL_ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"
    
    echo "Creating archive: $FULL_ARCHIVE_PATH"
    
    tar -czf "$FULL_ARCHIVE_PATH" --absolute-names "${SELECTED_FILES[@]}"

    if [ $? -eq 0 ]; then
        echo "Archive created successfully. Deleting original files..."
        rm "${SELECTED_FILES[@]}"
        echo "Cleanup finished."
    else
        echo "Error: Archiving failed. No original files were deleted."
        exit 1
    fi

else
    echo "Disk partition usage is normal. No action required."
fi

exit 0
