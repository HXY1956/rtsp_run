#!/bin/bash
set -e

# ==========================================================
# avoid running in root mode, and modify the $USER/$HOME 
# ==========================================================
if [ "$EUID" -eq 0 ] && [ -z "$SUDO_USER" ]; then
    echo "ERROR: Do not run this script as root directly. Run as normal user." >&2
    exit 1
fi

if [ -n "$SUDO_USER" ]; then
    USER="$SUDO_USER"
    HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    export HOME
fi

DOCKER="docker"

# ==========================================================
# Check docker permission
# ==========================================================
if ! docker info &>/dev/null; then
    if sudo docker info &>/dev/null; then
        echo "[INFO] Docker requires sudo for current session."
        echo "[INFO] To avoid sudo, run: sudo usermod -aG docker $USER && newgrp docker"
        DOCKER="sudo docker"
    else
        echo "ERROR: Docker not accessible." >&2
        exit 1
    fi
fi

CONTAINER_NAME="rtsp_container"
IMAGE_NAME="$1"

if [ -z "$IMAGE_NAME" ]; then
    echo "[INFO] Usage: $0 <image_name[:tag]>"
    echo
    echo "[INFO] Example:"
    echo "       $0 rtsp:v1"
    echo "       -- This image is for Ubuntu:20.04"
    echo "       $0 rtsp:v2"
    echo "       -- This image is for Ubuntu:22.04"
    exit 1
fi

# ==========================================================
# Install xhost autostart (only once)
# ==========================================================
AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/xhost-root.desktop"

if [ ! -f "$AUTOSTART_FILE" ]; then
    echo "[INFO] Installing xhost autostart..."

    mkdir -p "$AUTOSTART_DIR"

    cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Allow Docker X11
Exec=/usr/bin/xhost +SI:localuser:root
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

    echo "[INFO] xhost autostart installed."
fi

# ==========================================================
# Enable X11 for current login
# (necessary the first time before autostart takes effect)
# ==========================================================
if [ -n "$DISPLAY" ]; then
    xhost +SI:localuser:root >/dev/null 2>&1 || echo "[WARN] xhost failed, GUI may not work."
else
    echo "[WARN] DISPLAY not set, skipping X11 configuration."
fi

# ==========================================================
# Check whether the container exists
# ==========================================================
# ==========================================================
if $DOCKER ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then

    CURRENT_IMAGE=$($DOCKER inspect --format='{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null)
    
    if [ "$CURRENT_IMAGE" != "$IMAGE_NAME" ]; then
        echo "[WARN] Existing container uses image '$CURRENT_IMAGE', but you specified '$IMAGE_NAME'."
        echo "[INFO] Removing old container and recreating with new image..."
        
        $DOCKER rm -f "$CONTAINER_NAME" >/dev/null
        
        echo "[INFO] Recreating container with '$IMAGE_NAME'..."
        $DOCKER run -itd \
            --name "$CONTAINER_NAME" \
            --runtime=nvidia \
            --network host \
            --privileged \
            -e DISPLAY=$DISPLAY \
            -v /tmp/.X11-unix:/tmp/.X11-unix \
            -v /tmp/argus_socket:/tmp/argus_socket \
            -v /run/udev:/run/udev:ro \
            -v $HOME:$HOME \
            "$IMAGE_NAME"
    else
        if ! $DOCKER ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
            echo "[INFO] Starting existing container..."
            $DOCKER start "$CONTAINER_NAME" >/dev/null
        else
            echo "[INFO] Container is already running."
        fi
    fi

else
    echo "[INFO] Creating container..."
    $DOCKER run -itd \
        --name "$CONTAINER_NAME" \
        --runtime=nvidia \
        --network host \
        --privileged \
        -e DISPLAY=$DISPLAY \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -v /tmp/argus_socket:/tmp/argus_socket \
        -v /run/udev:/run/udev:ro \
        -v $HOME:$HOME \
         "$IMAGE_NAME"
fi

# ==========================================================
# Enter container
# ==========================================================
echo "[INFO] Entering container..."

$DOCKER exec -it "$CONTAINER_NAME" bash
