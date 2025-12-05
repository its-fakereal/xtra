#!/bin/bash

# 1️ Detect available GUI dialog tool
if command -v zenity &>/dev/null; then
    OUTPUT_DIR=$(zenity --file-selection --directory --title="Select output directory for random files")
elif command -v kdialog &>/dev/null; then
    OUTPUT_DIR=$(kdialog --getexistingdirectory "$PWD" --title "Select output directory for random files")
else
    echo "No GUI tool (zenity or kdialog) found. Please install one or enter a directory manually."
    read -p "Enter output directory: " OUTPUT_DIR
fi

# 2️ Use current folder as fallback if user cancels or leaves empty
if [ -z "$OUTPUT_DIR" ]; then
    DEFAULT_DIR="$(pwd)/files_$(date +%s)"
    clear
    echo
    echo  IF YOUR GIVEN PATH IS INCORRECT THEN, FILES ARE GOING TO CREATE IN: $DEFAULT_DIR
    read -p "Enter output directory [default: $DEFAULT_DIR]: " OUTPUT_DIR
    OUTPUT_DIR=${OUTPUT_DIR:-$DEFAULT_DIR}
fi
mkdir -p "$OUTPUT_DIR"
trap 'echo -e "\nAborted. Cleaning up..."; rm -rf "$OUTPUT_DIR"; rm -f /tmp/tmp.*; exit' INT

# #2 Ask user for output directory
# DEFAULT_DIR="$(pwd)/files_$(date +%s)"
# clear
# echo
# echo  IF YOUR GIVEN PATH IS INCORRECT THEN, FILES ARE GOING TO CREATE IN: $DEFAULT_DIR
# read -p "Enter output directory [default: $DEFAULT_DIR]: " OUTPUT_DIR
# OUTPUT_DIR=${OUTPUT_DIR:-$DEFAULT_DIR}
# mkdir -p "$OUTPUT_DIR"
# trap 'echo -e "\nAborted. Cleaning up..."; rm -rf "$OUTPUT_DIR"; rm -f /tmp/tmp.*; exit' INT

# # 3 Output directory no path required
# OUTPUT_DIR="./files_$(date +%s)"
# mkdir -p "$OUTPUT_DIR"
# trap 'echo -e "\nAborted. Cleaning up..."; rm -rf "$OUTPUT_DIR"; rm -f /tmp/tmp.*; exit' INT


clear
echo "                          __________________________________________________"
echo "                                       RANDOM FILES GENERATOR"
echo "                          __________________________________________________"
echo
echo "Files will be created in: $OUTPUT_DIR"
echo

# storage calculator
printf "%-20s %-20s %-19s %-19s %-12s %-30s %-30s\n" \
   "Label" "Total" "Used" "Free" "Type" "Filesystem" "Mounted at"

# Function: convert human-readable sizes to MB
to_mb() {
  local val=$(echo "$1" | sed 's/[^0-9.]//g')
  case "$1" in
    *T) echo "$(echo "$val * 1048576" | bc)" ;;
    *G) echo "$(echo "$val * 1024" | bc)" ;;
    *M) echo "$val" ;;
    *K) echo "$(echo "scale=0; $val / 1024" | bc)" ;;
    *) echo "N/A" ;;
  esac
}

# Loop through all mounted, real filesystems
df -h --output=source,size,used,avail,fstype,target | tail -n +2 | \
while read -r src total used avail fstype mount; do
  # Skip pseudo filesystems
  [[ $src =~ ^tmpfs|^udev|^overlay|^zram|^none$|^cgroup|^proc|^sysfs ]] && continue
  [[ -z $src || -z $mount ]] && continue

  # Normalize device name
  devpath=$src
  if [[ ! -e $src && $src =~ ^/dev/mapper/ ]]; then
    # Try to find underlying physical device for LUKS/LVM
    realdev=$(lsblk -no PKNAME "$src" 2>/dev/null)
    [[ -n $realdev ]] && devpath="/dev/$realdev"
  fi

#label
  label=$(lsblk -no LABEL "$devpath" 2>/dev/null)
  [[ -z $label ]] && label=$(blkid -s LABEL -o value "$devpath" 2>/dev/null)
  [[ -z $label ]] && label="—"

  # Convert size units to MB
  total_mb=$(to_mb "$total")
  used_mb=$(to_mb "$used")
  avail_mb=$(to_mb "$avail")

  # Print aligned output
  printf "%-20s %-20s %-19s %-19s %-12s %-30s %-30s\n" \
    "$label" \
    "$total ($total_mb MB)" \
    "$used ($used_mb MB)" \
    "$avail ($avail_mb MB)" \
    "$fstype" "$src" \
    "$mount" 
done
echo 
# Total and available storage in GB
read total used avail <<< $(df -BG / | tail -1 | awk '{print $2, $3, $4}' | sed 's/G//g')
used_percent=$((used * 100 / total))
echo "                   ${total} GB TOTAL IN CURRENT DRIVE. "
echo "                   Available: ${avail} GB | Used: ${used} GB ($used_percent%)"
echo
read -p "Enter total size to generate (e.g. 10kb,10mb,10gb): " TOTAL_SIZE
read -p "Enter minimum file size (e.g.,10kb,10M): " MIN_SIZE
read -p "Enter maximum file size (e.g.,100kb,100M): " MAX_SIZE
echo "Available CPU cores: $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)"
echo
read -p "Enter number of parallel jobs (e.g., 4): " THREADS

# Start timing
SECONDS=0

# Convert sizes
function size_to_bytes() {
    local SIZE=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    SIZE=${SIZE%B}
    if [[ $SIZE =~ ^([0-9]+)([MG])$ ]]; then
        local NUM=${BASH_REMATCH[1]}
        local UNIT=${BASH_REMATCH[2]}
        case $UNIT in
            K) echo $((NUM * 1024)) ;;
            M) echo $((NUM * 1024 * 1024)) ;;
            G) echo $((NUM * 1024 * 1024 * 1024)) ;;
        esac
    else
        echo "Invalid size format. Use 10M,10m,2g or 2G."
        exit 1
    fi
}

TOTAL_BYTES=$(size_to_bytes "$TOTAL_SIZE")
MIN_BYTES=$(size_to_bytes "$MIN_SIZE")
MAX_BYTES=$(size_to_bytes "$MAX_SIZE")

if [ $MIN_BYTES -gt $MAX_BYTES ]; then
    echo "Minimum file size cannot be greater than maximum."
    exit 1
fi

FILE_TYPES=("txt" "csv" "json" "html" "log")
CURRENT_BYTES=0
FILE_COUNT=0
PROGRESS_FILE=$(mktemp)
echo 0 > "$PROGRESS_FILE"

# --- Progress bar ---
show_progress() {
    local current=$(cat "$PROGRESS_FILE" 2>/dev/null || echo 0)
    (( current > TOTAL_BYTES )) && current=$TOTAL_BYTES
    local percent=$((current * 100 / TOTAL_BYTES))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    printf "\rProgress : ["
    printf "%0.s#" $(seq 1 $filled)
    printf "%0.s-" $(seq 1 $empty)
    printf "] %3d%% (%d / %d bytes)" "$percent" "$current" "$TOTAL_BYTES"
}

# --- Generate file (parallel job) ---
generate_file() {
    local FILE_PATH=$1
    local FILE_SIZE=$2
    local BLOCK_SIZE=10485760  # 10MB per block
    local WRITTEN=0
    > "$FILE_PATH"

    while [ $WRITTEN -lt $FILE_SIZE ]; do
        CHUNK=$(( FILE_SIZE - WRITTEN ))
        [ $CHUNK -gt $BLOCK_SIZE ] && CHUNK=$BLOCK_SIZE

        TEMP_DATA=$(mktemp)
        head -c $CHUNK /dev/urandom | tr -dc '[:print:]\n' > "$TEMP_DATA"
        ACTUAL=$(stat -c%s "$TEMP_DATA")

        if [ $ACTUAL -lt $CHUNK ]; then
            PADDING=$((CHUNK - ACTUAL))
            head -c $PADDING < /dev/zero | tr '\0' ' ' >> "$TEMP_DATA"
        fi

        cat "$TEMP_DATA" >> "$FILE_PATH"
        rm -f "$TEMP_DATA"
        WRITTEN=$(stat -c%s "$FILE_PATH")
    done

    (
        flock -x 200
        local prev=$(cat "$PROGRESS_FILE" 2>/dev/null || echo 0)
        echo $((prev + FILE_SIZE)) > "$PROGRESS_FILE"
    ) 200>/tmp/progress.lock
}

# --- Parallel control ---
run_in_parallel() {
    local MAX_JOBS=$1
    while [ "$(jobs -rp | wc -l)" -ge "$MAX_JOBS" ]; do
        sleep 0.2
    done
}

# --- Background progress updater ---
monitor_progress() {
    while :; do
        show_progress
        sleep 0.5
        # Exit when all background jobs are done
        if [ "$(jobs -rp | wc -l)" -eq 0 ]; then
            break
        fi
    done
}

monitor_progress &
MONITOR_PID=$!

# --- Main generation loop ---
while [ $CURRENT_BYTES -lt $TOTAL_BYTES ]; do
    FILE_NAME=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
    FILE_EXT=${FILE_TYPES[$RANDOM % ${#FILE_TYPES[@]}]}
    FILE_PATH="$OUTPUT_DIR/$FILE_NAME.$FILE_EXT"

    FILE_SIZE=$(( RANDOM % (MAX_BYTES - MIN_BYTES + 1) + MIN_BYTES ))
    if [ $((CURRENT_BYTES + FILE_SIZE)) -gt $TOTAL_BYTES ]; then
        FILE_SIZE=$((TOTAL_BYTES - CURRENT_BYTES))
    fi

    CURRENT_BYTES=$((CURRENT_BYTES + FILE_SIZE))
    FILE_COUNT=$((FILE_COUNT + 1))

    run_in_parallel "$THREADS"
    echo -e "\nFinished! Created $FILE_COUNT readable files totaling $CURRENT_BYTES bytes in $OUTPUT_DIR."
    show_progress
    generate_file "$FILE_PATH" "$FILE_SIZE" &
done

kill "$MONITOR_PID" 2>/dev/null
echo

# --- Format time ---
format_time() {
    local total_seconds=$1
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $seconds
}
echo -e "\nFinished! Created $FILE_COUNT readable files totaling $CURRENT_BYTES bytes in $OUTPUT_DIR."
echo "Time elapsed: $(format_time $SECONDS)"

rm -f "$PROGRESS_FILE" /tmp/progress.lock
