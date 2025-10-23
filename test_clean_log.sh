#!/bin/bash


TEST_ENV_DIR="lab1_test_env"
LOG_DIR="$TEST_ENV_DIR/log"
BACKUP_DIR="$TEST_ENV_DIR/backup"
MAIN_SCRIPT="./clean_log.sh"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'


setup() {
    echo "--- Setting up test environment ---"
    rm -rf "$TEST_ENV_DIR"
    mkdir -p "$LOG_DIR" "$BACKUP_DIR"
}

create_larger_test_data() {

    local LARGE_FILE_SIZE_MB=2500 
    local SMALL_FILE_COUNT=5
    local SMALL_FILE_SIZE_MB=10

    echo "Creating ~${LARGE_FILE_SIZE_MB}MB of test data... "
    

    fallocate -l ${LARGE_FILE_SIZE_MB}M "$LOG_DIR/large_and_old_file.log"
    sleep 1 
    

    for i in $(seq 1 $SMALL_FILE_COUNT); do
        dd if=/dev/zero of="$LOG_DIR/small_file_$i.log" bs=1M count=$SMALL_FILE_SIZE_MB &>/dev/null
        sleep 1
    done
    echo "Test data created."
}

cleanup() {
    echo "--- Cleaning up test environment ---"
    rm -rf "$TEST_ENV_DIR"
    echo "Cleanup complete."
}


test_case_1_should_run() {
    echo -e "\n=== TEST 1: Usage (real) > Threshold (low), cleanup SHOULD run ==="
    setup
    create_larger_test_data
    bash "$MAIN_SCRIPT" "$LOG_DIR" 1 "$BACKUP_DIR"
    if [ $(ls -1 "$BACKUP_DIR" | wc -l) -ne 1 ]; then echo -e "${RED}FAIL: Backup file was not created.${NC}"; return 1; fi
    echo -e "${GREEN}CHECK A: Backup file created. [PASS]${NC}"
    if [ -f "$LOG_DIR/large_and_old_file.log" ]; then echo -e "${RED}FAIL: The oldest (large) file was NOT deleted.${NC}"; return 1; fi
    echo -e "${GREEN}CHECK B: Oldest file was deleted. [PASS]${NC}"
    echo -e "${GREEN}=== TEST 1 PASSED ===${NC}"
}

test_case_2_should_not_run() {
    echo -e "\n=== TEST 2: Usage (real) < Threshold (high), cleanup should NOT run ==="
    setup
    create_larger_test_data
    local initial_file_count=$(ls -1 "$LOG_DIR" | wc -l)
    bash "$MAIN_SCRIPT" "$LOG_DIR" 99
    if [ $(ls -1 "$BACKUP_DIR" | wc -l) -ne 0 ]; then echo -e "${RED}FAIL: Backup directory is not empty!${NC}"; return 1; fi
    echo -e "${GREEN}CHECK A: Backup directory is empty. [PASS]${NC}"
    if [ $(ls -1 "$LOG_DIR" | wc -l) -ne $initial_file_count ]; then echo -e "${RED}FAIL: Files in log directory were modified!${NC}"; return 1; fi
    echo -e "${GREEN}CHECK B: Log files are untouched. [PASS]${NC}"
    echo -e "${GREEN}=== TEST 2 PASSED ===${NC}"
}

test_case_3_bad_directory() {
    echo -e "\n=== TEST 3: Non-existent directory, script should exit with error ==="
    setup
    (bash "$MAIN_SCRIPT" "/path/to/non/existent/dir" 70 >/dev/null 2>&1)
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then echo -e "${RED}FAIL: Script did not exit with an error code for a non-existent directory.${NC}"; return 1; fi
    echo -e "${GREEN}CHECK A: Script exited with an error code ($exit_code). [PASS]${NC}"
    echo -e "${GREEN}=== TEST 3 PASSED ===${NC}"
}

test_case_4_lzma_compression() {
    echo -e "\n=== TEST 4: High compression mode (lzma) SHOULD be used ==="
    setup
    create_larger_test_data
    LAB1_MAX_COMPRESSION=1 bash "$MAIN_SCRIPT" "$LOG_DIR" 1 "$BACKUP_DIR"
    if [ $(ls -1 "$BACKUP_DIR" | wc -l) -ne 1 ]; then echo -e "${RED}FAIL: Expected 1 backup file, but found $backup_file_count.${NC}"; return 1; fi
    echo -e "${GREEN}CHECK A: Backup file created. [PASS]${NC}"
    local xz_file=$(find "$BACKUP_DIR" -name "*.tar.xz")
    if [ -z "$xz_file" ]; then echo -e "${RED}FAIL: Backup file with .tar.xz extension was not found.${NC}"; return 1; fi
    local file_type=$(file "$xz_file")
    if [[ "$file_type" != *"XZ compressed data"* ]]; then echo -e "${RED}FAIL: Backup file is not in lzma (XZ) format! Type detected: $file_type${NC}"; return 1; fi
    echo -e "${GREEN}CHECK B: Backup file format is XZ (lzma). [PASS]${NC}"
    echo -e "${GREEN}=== TEST 4 PASSED ===${NC}"
}


main() {

    if [ "$1" != "--no-cleanup" ]; then
        
        trap cleanup EXIT
    else
        
        echo "No cleanup mode"
    fi

    echo "============================="
    echo "  Running Lab 1 Test Suite   "
    echo "============================="

    test_case_1_should_run
    test_case_2_should_not_run
    test_case_3_bad_directory
    test_case_4_lzma_compression

    echo -e "\n${GREEN}============================="
    echo "  All tests completed.       "
    echo "=============================${NC}"
}


main "$@"
