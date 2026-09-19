#!/usr/bin/bash

# Changes the volume of the default sink/source using wpctl (WirePlumber).
# Usage: volume.sh [up|down|mute|micmute]

SINK="@DEFAULT_AUDIO_SINK@"
SOURCE="@DEFAULT_AUDIO_SOURCE@"

case $1 in
    up)
        # "-l 1.0" caps the volume at 100%, same as the niri config
        wpctl set-volume "$SINK" 0.01+ -l 1.0
        ;;
    down)
        wpctl set-volume "$SINK" 0.01-
        ;;
    mute)
        wpctl set-mute "$SINK" toggle
        ;;
    micmute)
        wpctl set-mute "$SOURCE" toggle
        ;;
    *)
        echo "usage: volume.sh [up|down|mute|micmute]" >&2
        exit 1
        ;;
esac