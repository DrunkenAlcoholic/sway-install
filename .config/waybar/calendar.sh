#!/usr/bin/env bash

swaymsg exec "kitty --class calendar --title Calendar sh -lc 'cal -3; echo; echo "Press any key to close"; read -n 1'"
