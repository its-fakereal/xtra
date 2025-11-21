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

if [ $MIN_BYTES -gt $MAX_BYTES ]; then           # Check min < max
    echo "Minimum file size cannot be greater than maximum file size."
    exit 1
fi

# File types to choose from
FILE_TYPES=(
    "txt" "csv" "log" "md" "rtf" "pdf" "doc" "docx" "odt" "xls" "xlsx" "ods" "ppt" "pptx" "odp" "html" "htm" "xml" "json" "yaml" "yml" "tex" # Text and documents
    "sh" "bat" "exe" "apk" "jar" "py" "pl" "rb" "js" "php" # Scripts and executables
    "png" "jpg" "jpeg" "gif" "bmp" "tiff" "svg" "webp" "ico" "heic"  #Images
    "mp3" "wav" "flac" "aac" "ogg" "m4a" "wma"  # Audio
    "mp4" "mov" "avi" "mkv" "webm" "flv" "wmv" "mpeg" "3gp" # Video
    "zip" "tar" "gz" "bz2" "7z" "rar" "xz" "iso" # Archives
    "dat" "bin" "tmp" "log" "cfg" "ini" # Misc / Other
)

CURRENT_BYTES=0
FILE_COUNT=0

# Function to show detailed progress bar
function show_progress() {
    local current=$1
    local total=$2
    local file=$3
    local fsize=$4

    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    printf "\rProgress : ["
    printf "%0.s#" $(seq 1 $filled)
    printf "%0.s-" $(seq 1 $empty)
    printf "] Total %d%% | File name: %s (%d bytes)" "$percent" "$file" "$fsize"
}

# Main Loop
while [ $CURRENT_BYTES -lt $TOTAL_BYTES ]; do
    FILE_NAME=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
    FILE_EXT=${FILE_TYPES[$RANDOM % ${#FILE_TYPES[@]}]}
    FILE_PATH="$OUTPUT_DIR/$FILE_NAME.$FILE_EXT"

    FILE_SIZE=$(( RANDOM % (MAX_BYTES - MIN_BYTES + 1) + MIN_BYTES ))

    # Adjust if the file would exceed total size
    if [ $((CURRENT_BYTES + FILE_SIZE)) -gt $TOTAL_BYTES ]; then
        FILE_SIZE=$((TOTAL_BYTES - CURRENT_BYTES))
    fi

    # Create random file
    head -c $FILE_SIZE </dev/urandom > "$FILE_PATH"

    CURRENT_BYTES=$((CURRENT_BYTES + FILE_SIZE))
    FILE_COUNT=$((FILE_COUNT + 1))
    echo "Created $FILE_PATH ($FILE_SIZE bytes)"
    show_progress $CURRENT_BYTES $TOTAL_BYTES "$FILE_NAME.$FILE_EXT" $FILE_SIZE
done

function format_time() {
    local total_seconds=$1
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $seconds
}
echo "Finished! Created $FILE_COUNT files totaling $CURRENT_BYTES bytes in $OUTPUT_DIR."
echo "Time elapsed: $(format_time $SECONDS)"