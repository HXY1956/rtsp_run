#!/bin/bash

xhost +local:root

docker run -it --name rtsp_container \
--runtime=nvidia --network host --privileged \
-e DISPLAY=$DISPLAY \
-v /tmp/.X11-unix:/tmp/.X11-unix \
-v /tmp/argus_socket:/tmp/argus_socket \
-v /run/udev:/run/udev:ro \
-v $HOME:$HOME \
rtsp:v1
