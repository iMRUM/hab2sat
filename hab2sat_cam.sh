#!/system/bin/sh

# Configuration
PHOTO_DIR="/sdcard/DCIM/Camera"
LOG_FILE="/sdcard/HAB2Sat_cam.log"
TEMP_DIR="/sdcard/HAB2Sat_temp"
CONTACT_NAME="Nanami"
PID_FILE="/sdcard/HAB2Sat_cam.pid"

# =============================================================================
# LOGGING AND UTILITIES
# =============================================================================

# Log a message to stdout and the log file
log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

get_latest_photo() {
    LATEST_FILE=$(find "$PHOTO_DIR" "$TEMP_DIR" -type f \( -name "*.jpg" -o -name "*.png" \) -print0 | xargs -0 ls -t | head -n 1)
    echo "$LATEST_FILE"
}

# =============================================================================
# PHOTO CAPTURE FUNCTIONS
# =============================================================================

take_photo_camera() {
    log_message "Taking photo with camera app..."
    
    am start -a android.media.action.STILL_IMAGE_CAMERA
    sleep 3
    input tap 540 1700 # TODO: Replace with an accessibility service for robustness
    sleep 2
    input keyevent KEYCODE_HOME
    sleep 2
    NEW_PHOTO_PATH=$(find "$PHOTO_DIR" -maxdepth 1 -type f -mmin -2 -name "*.jpg" | head -n 1)
    if [ -n "$NEW_PHOTO_PATH" ]; then
        log_message "Photo taken: $NEW_PHOTO_PATH"
        return 0
    else
        log_message "No new photo detected"
        return 1
    fi
}

# Take a screenshot as a fallback
take_photo_screenshot() {
    log_message "Taking screenshot as fallback..."
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    SCREENSHOT_PATH="$TEMP_DIR/entrance_$TIMESTAMP.png"

    screencap -p "$SCREENSHOT_PATH"

    if [ -f "$SCREENSHOT_PATH" ]; then
        log_message "Screenshot captured: $SCREENSHOT_PATH"
        return 0
    else
        log_message "Screenshot failed"
        return 1
    fi
}

capture_photo() {
    log_message "Starting photo capture..."
    if take_photo_camera; then
        return 0
    elif take_photo_screenshot; then
        return 0
    fi
    log_message "Failed to capture a valid photo."
    return 1
}

# =============================================================================
# PHOTO SHARING FUNCTIONS
# =============================================================================

send_photo() {
    PHOTO_PATH="$1"

    if [ -z "$PHOTO_PATH" ] || [ ! -f "$PHOTO_PATH" ]; then
        log_message "Error: Photo path is invalid or file not found: $PHOTO_PATH"
        return 1
    fi

    log_message "Sending photo via PhotoShare app: $PHOTO_PATH"

    # Make sure file is readable
    chmod 644 "$PHOTO_PATH"
    if am start -n com.security.photoshare/.ShareActivity --es photo_path "$PHOTO_PATH"; then
        log_message "PhotoShare app launched successfully."
        return 0
    else
        log_message "Failed to launch PhotoShare app."
        return 1
    fi
}

choose_contact() {
    sleep 1
    input tap 524 422 # TODO: Replace with an accessibility service for robustness
    sleep 1.8
    input tap 1012 194
    sleep 2
    input tap 984 1300
    sleep 3
    log_message "Manual send sequence completed."
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

process_photo() {
    log_message "=== Starting photo process ==="
    if capture_photo; then
        PHOTO_PATH=$(get_latest_photo)
        if [ -n "$PHOTO_PATH" ]; then
            if send_photo "$PHOTO_PATH"; then
                choose_contact
                log_message "=== Photo process completed successfully. ==="
            fi
        else
            log_message "No latest photo found after capture attempt."
        fi
    fi
}

show_status() {
    DCIM_COUNT=$(find "$PHOTO_DIR" -name "*.jpg" 2>/dev/null | wc -l)
    TEMP_COUNT=$(find "$TEMP_DIR" -name "*.png" 2>/dev/null | wc -l)
    LATEST=$(get_latest_photo)
    
    log_message "=== STATUS ==="
    log_message "Photos in DCIM: $DCIM_COUNT"
    log_message "Screenshots in temp: $TEMP_COUNT"
    log_message "Latest photo: $LATEST"
    log_message "Contact: $CONTACT_NAME"
    log_message "Device: $(getprop ro.product.model)"
    log_message "Android: $(getprop ro.build.version.release)"
    log_message "=============="
}

main_loop() {
    log_message "=== HAB2Sat. Camera Started ==="
    show_status
    ITERATION=0
    while true; do
        ITERATION=$((ITERATION + 1))
        log_message "--- Iteration $ITERATION ---"

        process_photo

        if [ $((ITERATION % 10)) -eq 0 ]; then
            show_status
        fi

        log_message "Waiting 60 seconds..."
        sleep 60
    done
}

# =============================================================================
# CONTROL FUNCTIONS
# =============================================================================

start_camera() {
    if [ -f "$PID_FILE" ]; then
        echo "Camera already running (PID: $(cat "$PID_FILE"))"
        exit 1
    fi

    echo $$ > "$PID_FILE"
    trap "rm -f \"$PID_FILE\"" EXIT
    main_loop
}

stop_camera() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill "$PID" 2>/dev/null; then
            rm "$PID_FILE"
            echo "HAB2Sat. camera stopped."
        else
            echo "Failed to stop process. PID file removed."
            rm "$PID_FILE"
        fi
    else
        echo "HAB2Sat. camera not running."
    fi
}

status_camera() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps | grep -q "^[[:space:]]*$PID"; then
            echo "HAB2Sat. camera running (PID: $PID)"
            show_status
        else
            echo "PID file exists but process is not running. Cleaning up."
            rm "$PID_FILE"
        fi
    else
        echo "HAB2Sat. camera not running."
    fi
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

case "$1" in
    start)
        start_camera
        ;;
    stop)
        stop_camera
        ;;
    status)
        status_camera
        ;;
    test)
        log_message "=== SINGLE TEST ==="
        process_photo
        ;;
    *)
        echo "Usage: $0 {start|stop|status|test}"
        exit 1
        ;;
esac
