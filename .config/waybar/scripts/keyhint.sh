#!/usr/bin/env bash
set -euo pipefail

if ! command -v yad >/dev/null 2>&1; then
    echo "yad is not installed." >&2
    exit 1
fi

rows=$(cat <<'DATA'
Super+Enter	Open terminal	kitty
Super+D	Application launcher	~/.local/bin/nimlaunch
Super+B	Open browser	brave
Super+N	Open file manager	pcmanfm
Super+I	Lock screen	swaylock -f
Super+Shift+Q	Close focused window	swaymsg kill
Super+Shift+E	Exit Sway session	swaymsg exit
Super+F	Toggle fullscreen	swaymsg fullscreen
Super+Space	Toggle focus mode	swaymsg focus mode_toggle
Super+Shift+Space	Toggle floating	swaymsg floating toggle
Super+Minus	Show scratchpad	swaymsg scratchpad show
Super+Shift+Minus	Move to scratchpad	swaymsg move scratchpad
Print	Screenshot (full)	grim - | swappy -f -
Super+Print	Screenshot (area)	grim -g "$(slurp)" - | swappy -f -
Super+Shift+H	Show this help	~/.config/waybar/scripts/keyhint.sh
XF86AudioRaiseVolume	Raise volume	wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.5
XF86AudioLowerVolume	Lower volume	wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.5
XF86AudioMute	Toggle mute	wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
XF86MonBrightnessUp	Increase brightness	brightnessctl set +5%
XF86MonBrightnessDown	Decrease brightness	brightnessctl set 5%-
DATA
)

yad --title="Sway Keybindings" \
    --width=640 \
    --height=520 \
    --window-icon=utilities-terminal \
    --no-buttons \
    --center \
    --list \
    --column="Key" \
    --column="Description" \
    --column="Command" <<<"$rows"
