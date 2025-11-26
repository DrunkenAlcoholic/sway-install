#!/usr/bin/env bash
set -euo pipefail

entries=(
"Super+Enter|Open terminal|kitty"
"Super+D|Application launcher|~/.local/bin/nimlaunch"
"Super+B|Open browser|brave"
"Super+N|Open file manager|thunar"
"Super+I|Lock screen|swaylock -f"
"Super+Shift+Q|Close focused window|swaymsg kill"
"Super+Shift+E|Exit Sway session|swaymsg exit"
"Super+F|Toggle fullscreen|swaymsg fullscreen"
"Super+Space|Toggle focus mode|swaymsg focus mode_toggle"
"Super+Shift+Space|Toggle floating|swaymsg floating toggle"
"Super+Minus|Show scratchpad|swaymsg scratchpad show"
"Super+Shift+Minus|Move to scratchpad|swaymsg move scratchpad"
"Print|Screenshot (full)|grim - | swappy -f -"
"Super+Print|Screenshot (area)|grim -g \"\$(slurp)\" - | swappy -f -"
"Super+Shift+I|Show this help|~/.config/waybar/scripts/keyhint.sh"
"XF86AudioRaiseVolume|Raise volume|wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.5"
"XF86AudioLowerVolume|Lower volume|wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.5"
"XF86AudioMute|Toggle mute|wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
"XF86MonBrightnessUp|Increase brightness|brightnessctl set +5%"
"XF86MonBrightnessDown|Decrease brightness|brightnessctl set 5%-"
)

make_rows() {
    printf "Key\tDescription\tCommand\n"
    for row in "${entries[@]}"; do
        IFS='|' read -r key desc cmd <<<"$row"
        printf "%s\t%s\t%s\n" "$key" "$desc" "$cmd"
    done
}

rows=$(make_rows)
formatted=$(printf '%s\n' "$rows" | column -t -s $'\t')
formatted=$(awk 'NR==1{print "\033[1;36m" $0 "\033[0m"; next} {print}' <<<"$formatted")
title=$'\033[1;35mSway Keybindings\033[0m'
divider=$'\033[2m──────────────────────────────────────────────\033[0m'
formatted="$title"$'\n'$"$divider"$'\n'$formatted
formatted+=$'\n\n\033[2mPress q to close.\033[0m'

tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT
printf '%s\n' "$formatted" > "$tmp_file"

if command -v yad >/dev/null 2>&1; then
    printf '%s\n' "$rows" | tail -n +2 | yad --title="Sway Keybindings" \
        --class=keyhint \
        --name=keyhint \
        --width=900 \
        --height=540 \
        --undecorated \
        --center \
        --borders=12 \
        --window-icon=utilities-terminal \
        --no-buttons \
        --fontname="JetBrainsMono Nerd Font 11" \
        --column-widths=140,320,420 \
        --expand-column=2 \
        --list \
        --column="Key" \
        --column="Description" \
        --column="Command"
    exit 0
fi

if command -v kitty >/dev/null 2>&1; then
    kitty --class keyhint --title "Sway Keybindings" less -R "$tmp_file"
    exit 0
fi

less -R "$tmp_file"
