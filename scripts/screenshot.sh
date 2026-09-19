#!/bin/bash

if [ "$1" == "full" ]; then
    grim - | wl-copy
else
    grim -g "$(slurp -b '#2E2A1E55' -c '#fb751bff')" - | wl-copy
fi

notify-send "Screenshot copied to clipboard"