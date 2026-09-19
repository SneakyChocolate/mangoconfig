#!/usr/bin/bash

# Change backlight brightness with brightnessctl.
# Usage: brightness.sh [up|down]

case $1 in
    up)
        brightnessctl --class=backlight set +1%
        ;;
    down)
        brightnessctl --class=backlight set 1%-
        ;;
    *)
        echo "usage: brightness.sh [up|down]" >&2
        exit 1
        ;;
esac