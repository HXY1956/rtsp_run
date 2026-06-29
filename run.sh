#!/bin/bash

set -e

CONTAINER_NAME="rtsp_container"
IMAGE_NAME="rtsp:v2"

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
xhost +SI:localuser:root >/dev/null

# ==========================================================
# Check whether the container exists
# ==========================================================
if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then

    echo "[INFO] Container already exists."

    if ! docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
        echo "[INFO] Starting container..."
        docker start "$CONTAINER_NAME" >/dev/null
    fi

else

    echo "[INFO] Creating container..."

    docker run -itd \
        --name "$CONTAINER_NAME" \
        --runtime=nvidia \
        --network host \
        --privileged \
        -e DISPLAY=$DISPLAY \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -v /tmp/argus_socket:/tmp/argus_socket \
        -v /run/udev:/run/udev:ro \
        -v "$HOME":"$HOME" \
        "$IMAGE_NAME"

fi

# ==========================================================
# Enter container
# ==========================================================
echo "[INFO] Entering container..."

docker exec -it "$CONTAINER_NAME" bash
