
LOG_DIR=$1

THRESHOLD=${2:-70}

BACKUP_DIR="./backup"


#                                           第二部分

# 检查是否提供了目录路径
if [ -z "$LOG_DIR" ]; then
    echo "Error: No directory path provided."
    exit 1
fi

# 检查目录是否存在。
if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Directory '$LOG_DIR' does not exist."
    exit 1
fi

# 检查备份目录是否位于监控目录之内，以防止逻辑错误。

if [[ "$(realpath "$BACKUP_DIR")" == "$(realpath "$LOG_DIR")"* ]]; then
    echo "Error: The backup directory cannot be inside the monitored directory."
    exit 1
fi

# 创建备份目录

mkdir -p "$BACKUP_DIR"

#                                              第三部分
#主逻辑 
echo "Script execution started."
echo "Monitoring directory: $LOG_DIR"
echo "Threshold: $THRESHOLD%"

# 使用 'df' 获取当前磁盘分区的使用率百分比。

CURRENT_USAGE=$(df --output=pcent "$LOG_DIR" | tail -n 1 | tr -d ' %')
echo "Current disk partition usage: $CURRENT_USAGE%"

# 检查当前使用率是否大于阈值。

if [ "$CURRENT_USAGE" -gt "$THRESHOLD" ]; then
    echo "Usage exceeds the threshold. Starting cleanup process..."

    #计算需要释放的确切空间大小 (单位KB)。
    DISK_INFO=$(df --output=size,used "$LOG_DIR" | tail -n 1)
    TOTAL_SPACE_KB=$(echo $DISK_INFO | awk '{print $1}')
    USED_SPACE_KB=$(echo $DISK_INFO | awk '{print $2}')
    TARGET_USED_KB=$((TOTAL_SPACE_KB * THRESHOLD / 100))
    BYTES_TO_FREE_KB=$((USED_SPACE_KB - TARGET_USED_KB))
    
    echo "Need to free at least $(printf "%.2f" $(echo "$BYTES_TO_FREE_KB/1024" | bc -l)) MB of space."

    # 查找文件，按修改时间排序 (从最旧到最新)，并将结果存入数组。
    
    mapfile -t FILES_TO_ARCHIVE < <(find "$LOG_DIR" -maxdepth 1 -type f -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-)

    declare -a SELECTED_FILES
    FREED_SPACE_KB=0

    # 历已排序的文件列表，选择足够的文件以满足空间释放要求。
    
    for file in "${FILES_TO_ARCHIVE[@]}"; do
        if [ "$FREED_SPACE_KB" -ge "$BYTES_TO_FREE_KB" ]; then
            break
        fi
        FILE_SIZE_KB=$(du -k "$file" | awk '{print $1}')
        FREED_SPACE_KB=$((FREED_SPACE_KB + FILE_SIZE_KB))
        SELECTED_FILES+=("$file")
    done
    
    # --- 执行归档和删除

    # 如果没有文件被选中，则退出。
    
    if [ ${#SELECTED_FILES[@]} -eq 0 ]; then
        echo "No archivable files found."
        exit 0
    fi

    echo "Archiving ${#SELECTED_FILES[@]} oldest files..."
    
    #                                                 第四部分
    #基于当前日期和时间创建唯一的归档文件名。
    
    ARCHIVE_NAME="backup_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    FULL_ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"
    
    echo "Creating archive: $FULL_ARCHIVE_PATH"
    
    # 用 'tar' 命令打包并压缩选定的文件。(-c: 创建, -z: gzip压缩, -f: 指定文件名)
   
    tar -czf "$FULL_ARCHIVE_PATH" --absolute-names "${SELECTED_FILES[@]}"

    #检查上一条命令 (tar) 是否成功执行。($? == 0 代表成功)
    
    if [ $? -eq 0 ]; then
        echo "Archive created successfully. Deleting original files..."
        #归档成功后，才删除原始文件。
        
        rm "${SELECTED_FILES[@]}"
        echo "Cleanup finished."
    else
        #如果归档失败，则报告错误并且不删除任何文件。
        
        echo "Error: Archiving failed. No original files were deleted."
        exit 1
    fi

else
    # 如果磁盘使用率正常，则无需操作。
   
    echo "Disk partition usage is normal. No action required."
fi

#脚本成功完成。

exit 0
