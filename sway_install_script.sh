#!/bin/bash

# Sway WM Installation Script for Minimal Arch Linux
# This script installs and configures a complete Sway desktop environment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Check if running on Arch Linux
if ! command -v pacman &> /dev/null; then
    print_error "This script is designed for ArchLinux systems with pacman package manager."
    exit 1
fi

print_status "Starting Sway WM installation on minimal Arch Linux..."

# Update system
print_status "Updating system packages..."
sudo pacman -Syu --noconfirm

# Install base packages needed for minimal system
print_status "Installing base system packages..."
sudo pacman -S --noconfirm \
    base-devel \
    git \
    wget \
    curl \
    openssh \
    unzip

# Install and configure display manager (SDDM)
print_status "Installing and configuring SDDM display manager..."
sudo pacman -S --noconfirm sddm qt5-graphicaleffects qt5-svg qt5-quickcontrols2

# Install Sway and core Wayland components
print_status "Installing Sway and Wayland components..."
sudo pacman -S --noconfirm \
    sway \
    swaylock \
    swayidle \
    swaybg \
    waybar \
    wl-clipboard \
    xorg-xwayland

# Install essential utilities
print_status "Installing essential utilities..."
sudo pacman -S --noconfirm --needed \
    kitty \
    thunar \
    thunar-volman \
    grim \
    slurp \
    mako \
    brightnessctl \
    playerctl \
    pavucontrol \
    networkmanager \
    network-manager-applet \
    bluez \
    bluez-utils \
    blueman \
    udisks2 \
    gvfs \
    gvfs-mtp \
    gvfs-gphoto2 \
    gvfs-afc \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber

# Install fonts including nerd fonts from official repos
print_status "Installing fonts..."
sudo pacman -S --noconfirm --needed \
    ttf-dejavu \
    ttf-liberation \
    noto-fonts \
    noto-fonts-emoji \
    ttf-font-awesome \
    ttf-firacode-nerd \
    ttf-jetbrains-mono-nerd \
    ttf-sourcecodepro-nerd

# Install optional but useful packages
print_status "Installing additional useful packages..."
sudo pacman -S --noconfirm --needed \
    htop \
    ranger \
    helix \
    micro \
    tree \
    man-db \
    man-pages \
    gtk3 \
    qt5ct \
    lxappearance \
    iwd \
    wireless_tools \
    wpa_supplicant \
    smartmontools \
    xdg-utils

# Detect VirtualBox environment and install guest utilities if needed
print_status "Checking for VirtualBox environment..."
if systemd-detect-virt --quiet --vm; then
    sudo pacman -S --noconfirm --needed open-vm-tools
else
    print_status "No virtualization detected; skipping VirtualBox guest utilities installation."
fi

# Install paru AUR helper
print_status "Installing paru AUR helper..."
if ! command -v paru &> /dev/null; then
    cd /tmp
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/paru
else
    print_warning "paru is already installed, skipping..."
fi

# Install Brave browser from AUR using paru
print_status "Installing Brave browser from AUR..."
paru -S --noconfirm --needed --skipreview brave-bin


# Install Dracula theme components from AUR
print_status "Installing Dracula theme components..."
paru -S --noconfirm --needed --skipreview \
    dracula-gtk-theme \
    dracula-icons-git

# Install NimLaunch application launcher
print_status "Installing NimLaunch application launcher..."
NIMLAUNCH_TMP_DIR="$(mktemp -d)"
if git clone https://github.com/DrunkenAlcoholic/NimLaunch.git "$NIMLAUNCH_TMP_DIR"; then
    install -Dm755 "$NIMLAUNCH_TMP_DIR/bin/nimlaunch" "$HOME/.local/bin/nimlaunch"
    rm -rf "$NIMLAUNCH_TMP_DIR"
else
    print_error "Failed to clone NimLaunch repository."
    rm -rf "$NIMLAUNCH_TMP_DIR"
    exit 1
fi

# Install Nymph fetch utility
print_status "Installing Nymph fetch utility..."
NYMPH_TMP_DIR="$(mktemp -d)"
if git clone https://github.com/DrunkenAlcoholic/Nymph.git "$NYMPH_TMP_DIR"; then
    mkdir -p "$HOME/.local/bin"
    install -Dm755 "$NYMPH_TMP_DIR/bin/nymph" "$HOME/.local/bin/nymph"
    rm -rf "$HOME/.local/bin/logos"
    cp -r "$NYMPH_TMP_DIR/bin/logos" "$HOME/.local/bin/"
    rm -rf "$NYMPH_TMP_DIR"
else
    print_error "Failed to clone Nymph repository."
    rm -rf "$NYMPH_TMP_DIR"
    exit 1
fi

# Create necessary directories
print_status "Creating configuration directories..."
mkdir -p ~/.config/{sway,swaylock,waybar,kitty,mako,gtk-3.0}
mkdir -p ~/.themes ~/.icons

# Create basic Sway configuration
print_status "Creating Sway configuration..."
cat > ~/.config/sway/config << 'EOF'
# Default config for sway
# Read `man 5 sway` for a complete reference.

### Variables
# Logo key. Use Mod1 for Alt.
set $mod Mod4
# Home row direction keys, like vim
set $left h
set $down j
set $up k
set $right l
# Your preferred terminal emulator
set $term kitty
# Your preferred application launcher
set $menu ~/.local/bin/nimlaunch

### Output configuration
# Default wallpaper (more resolutions are available in /usr/share/backgrounds/sway/)
output * bg #282a36 solid_color

### Dracula color scheme for Sway
# class                 border  backgr. text    indicator child_border
client.focused          #6272a4 #6272a4 #f8f8f2 #6272a4   #6272a4
client.focused_inactive #44475a #44475a #f8f8f2 #44475a   #44475a
client.unfocused        #282a36 #282a36 #bfbfbf #282a36   #282a36
client.urgent           #44475a #ff5555 #f8f8f2 #ff5555   #ff5555
client.placeholder      #282a36 #0c0c0c #f8f8f2 #000000   #0c0c0c

### Input configuration
input "type:touchpad" {
    tap enabled
    natural_scroll enabled
}

### Key bindings
# Start a terminal
bindsym $mod+Return exec $term

# Kill focused window
bindsym $mod+Shift+q kill

# Start your launcher
bindsym $mod+d exec $menu

# Start browser
bindsym $mod+b exec brave

# Drag floating windows by holding down $mod and left mouse button.
floating_modifier $mod normal

# Reload the configuration file
bindsym $mod+Shift+c reload

# Exit sway (logs you out of your Wayland session)
bindsym $mod+Shift+e exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'

# Moving around:
bindsym $mod+$left focus left
bindsym $mod+$down focus down
bindsym $mod+$up focus up
bindsym $mod+$right focus right
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Move the focused window
bindsym $mod+Shift+$left move left
bindsym $mod+Shift+$down move down
bindsym $mod+Shift+$up move up
bindsym $mod+Shift+$right move right
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Workspaces:
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9
bindsym $mod+0 workspace number 10

# Move focused container to workspace
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9
bindsym $mod+Shift+0 move container to workspace number 10

# Layout stuff (use Ctrl with H/V to avoid conflicting with navigation/move bindings):
bindsym $mod+Ctrl+h splith
bindsym $mod+Ctrl+v splitv
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym $mod+a focus parent

# Scratchpad:
bindsym $mod+Shift+minus move scratchpad
bindsym $mod+minus scratchpad show

# Resizing containers:
mode "resize" {
    bindsym $left resize shrink width 10px
    bindsym $down resize grow height 10px
    bindsym $up resize shrink height 10px
    bindsym $right resize grow width 10px

    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px

    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Media keys
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86AudioMicMute exec pactl set-source-mute @DEFAULT_SOURCE@ toggle
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86AudioPlay exec playerctl play-pause
bindsym XF86AudioNext exec playerctl next
bindsym XF86AudioPrev exec playerctl previous

# Screenshots
bindsym Print exec grim ~/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png
bindsym $mod+Print exec grim -g "$(slurp)" ~/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png

# Lock screen
bindsym $mod+i exec swaylock

# File manager
bindsym $mod+n exec thunar

# Status Bar:
bar {
    swaybar_command waybar
}

# Autostart
exec mako
exec nm-applet --indicator
exec blueman-applet

# Idle configuration
exec swayidle -w \
         timeout 300 'swaylock -f' \
         timeout 600 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"' \
         before-sleep 'swaylock -f'
EOF

# Create swaylock configuration with Dracula theme
print_status "Creating swaylock configuration with Dracula theme..."
cat > ~/.config/swaylock/config << 'EOF'
color=#282a36
inside-color=#282a36
inside-clear-color=#282a36
inside-ver-color=#282a36
inside-wrong-color=#ff5555

ring-color=#6272a4
ring-clear-color=#50fa7b
ring-ver-color=#bd93f9
ring-wrong-color=#ff5555

line-color=#44475a
line-clear-color=#50fa7b
line-ver-color=#bd93f9
line-wrong-color=#ff5555

separator-color=#282a36
text-color=#f8f8f2
text-clear-color=#f8f8f2
text-ver-color=#f8f8f2
text-wrong-color=#f8f8f2

bs-hl-color=#ff5555
key-hl-color=#50fa7b

indicator-thickness=8
EOF

# Create Waybar configuration with Dracula theme
print_status "Creating Waybar configuration with Dracula theme..."
cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left": ["sway/workspaces", "sway/mode"],
    "modules-center": ["sway/window"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "temperature", "battery", "clock", "tray"],
    
    "sway/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}: {icon}",
        "format-icons": {
            "1": "",
            "2": "",
            "3": "",
            "4": "",
            "5": "",
            "urgent": "",
            "focused": "",
            "default": ""
        }
    },
    
    "clock": {
        "format": " {:%H:%M}",
        "format-alt": " {:%Y-%m-%d %H:%M:%S}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    
    "cpu": {
        "format": " {usage}%",
        "tooltip": false
    },
    
    "memory": {
        "format": " {}%"
    },
    
    "temperature": {
        "critical-threshold": 80,
        "format-critical": "{temperatureC}°C ",
        "format": "{temperatureC}°C ",
        "format-icons": ["", "", ""]
    },
    
    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{capacity}% {icon}",
        "format-charging": "{capacity}% 󰂄",
        "format-plugged": "{capacity}% ",
        "format-alt": "{time} {icon}",
        "format-icons": ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    },
    
    "network": {
        "format-wifi": "{essid} ({signalStrength}%) 󰖩",
        "format-ethernet": "{ipaddr}/{cidr} 󰈀",
        "tooltip-format": "{ifname} via {gwaddr} 󰊗",
        "format-linked": "{ifname} (No IP) 󰈂",
        "format-disconnected": "Disconnected ⚠",
        "format-alt": "{ifname}: {ipaddr}/{cidr}"
    },
    
    "pulseaudio": {
        "format": "{volume}% {icon} {format_source}",
        "format-bluetooth": "{volume}% {icon} {format_source}",
        "format-bluetooth-muted": "󰂲 {icon} {format_source}",
        "format-muted": "󰖁 {format_source}",
        "format-source": "{volume}% ",
        "format-source-muted": "",
        "format-icons": {
            "headphone": "",
            "hands-free": "",
            "headset": "",
            "phone": "",
            "portable": "",
            "car": "",
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    }
}
EOF

cat > ~/.config/waybar/style.css << 'EOF'
/* Dracula Theme for Waybar */
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background-color: #282a36;
    border-bottom: 3px solid #6272a4;
    color: #f8f8f2;
    transition-property: background-color;
    transition-duration: .5s;
}

window#waybar.hidden {
    opacity: 0.2;
}

#workspaces button {
    padding: 0 8px;
    background-color: transparent;
    color: #f8f8f2;
    border-bottom: 3px solid transparent;
}

#workspaces button:hover {
    background: #44475a;
}

#workspaces button.focused {
    background-color: #6272a4;
    border-bottom: 3px solid #bd93f9;
}

#workspaces button.urgent {
    background-color: #ff5555;
}

#mode {
    background-color: #ff79c6;
    color: #282a36;
}

#clock,
#battery,
#cpu,
#memory,
#temperature,
#network,
#pulseaudio,
#tray {
    padding: 0 10px;
    color: #f8f8f2;
}

#window,
#workspaces {
    margin: 0 4px;
}

.modules-left > widget:first-child > #workspaces {
    margin-left: 0;
}

.modules-right > widget:last-child > #workspaces {
    margin-right: 0;
}

#clock {
    background-color: #bd93f9;
    color: #282a36;
    border-radius: 10px;
    margin: 5px;
}

#battery {
    background-color: #50fa7b;
    color: #282a36;
    border-radius: 10px;
    margin: 5px;
}

#battery.charging, #battery.plugged {
    color: #282a36;
    background-color: #50fa7b;
}

@keyframes blink {
    to {
        background-color: #ff5555;
        color: #f8f8f2;
    }
}

#battery.critical:not(.charging) {
    background-color: #ff5555;
    color: #f8f8f2;
    animation-name: blink;
    animation-duration: 0.5s;
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#cpu {
    background-color: #ffb86c;
    color: #282a36;
    border-radius: 10px;
    margin: 5px;
}

#memory {
    background-color: #ff79c6;
    color: #282a36;
    border-radius: 10px;
    margin: 5px;
}

#network {
    background-color: #8be9fd;
    color: #282a36;
    border-radius: 10px;
    margin: 5px;
}

#network.disconnected {
    background-color: #ff5555;
    color: #f8f8f2;
}

#pulseaudio {
    background-color: #f1fa8c;
    color: #282a36;
    border-radius: 10px;
    margin: 5px;
}

#pulseaudio.muted {
    background-color: #6272a4;
    color: #f8f8f2;
}

#temperature {
    background-color: #ffb86c;
    color: #282a36;
    border-radius: 10px;
    margin: 5px;
}

#temperature.critical {
    background-color: #ff5555;
    color: #f8f8f2;
}

#tray {
    background-color: #6272a4;
    border-radius: 10px;
    margin: 5px;
}

#tray > .passive {
    -gtk-icon-effect: dim;
}

#tray > .needs-attention {
    -gtk-icon-effect: highlight;
    background-color: #ff5555;
}
EOF

# Create Kitty configuration with Dracula theme
print_status "Creating Kitty configuration with Dracula theme..."
cat > ~/.config/kitty/kitty.conf << 'EOF'
# Kitty Configuration File - Dracula Theme

# Font settings
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size 12.0

# Window layout
remember_window_size  yes
initial_window_width  640
initial_window_height 400
window_padding_width 10
placement_strategy center

# Tab bar
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted
tab_title_template {title}{' :{}:'.format(num_windows) if num_windows > 1 else ''}

# Dracula Color Scheme
foreground            #f8f8f2
background            #282a36
selection_foreground  #ffffff
selection_background  #44475a

# Cursor colors
cursor                #f8f8f2
cursor_text_color     #282a36

# URL underline color when hovering with mouse
url_color             #8be9fd

# Kitty window border colors
active_border_color   #ff79c6
inactive_border_color #6272a4

# Tab bar colors
active_tab_foreground   #282a36
active_tab_background   #f8f8f2
inactive_tab_foreground #f8f8f2
inactive_tab_background #6272a4

# Colors for marks (marked text in the terminal)
mark1_foreground #282a36
mark1_background #ff5555
mark2_foreground #282a36
mark2_background #f1fa8c
mark3_foreground #282a36
mark3_background #50fa7b

# The 16 terminal colors

# normal
color0 #21222c
color1 #ff5555
color2 #50fa7b
color3 #f1fa8c
color4 #bd93f9
color5 #ff79c6
color6 #8be9fd
color7 #f8f8f2

# bright
color8  #6272a4
color9  #ff6e6e
color10 #69ff94
color11 #ffffa5
color12 #d6acff
color13 #ff92df
color14 #a4ffff
color15 #ffffff

# Performance tuning
repaint_delay 10
input_delay 3
sync_to_monitor yes

# Mouse
copy_on_select no
mouse_hide_wait 3.0
url_style curly

# Advanced
close_on_child_death no
allow_remote_control no
update_check_interval 24
startup_session none
clipboard_control write-clipboard write-primary
term xterm-kitty
EOF

# Create Mako (notification daemon) configuration with Dracula theme
print_status "Creating Mako configuration with Dracula theme..."
cat > ~/.config/mako/config << 'EOF'
sort=-time
layer=overlay
background-color=#282a36
text-color=#f8f8f2
width=300
height=110
border-size=2
border-color=#bd93f9
border-radius=15
icons=1
max-icon-size=64
default-timeout=5000
ignore-timeout=1
font=JetBrainsMono Nerd Font 11

[urgency=low]
border-color=#6272a4
background-color=#44475a

[urgency=normal]
border-color=#ffb86c
background-color=#282a36

[urgency=high]
border-color=#ff5555
background-color=#ff5555
text-color=#f8f8f2
default-timeout=0

[category=mpd]
default-timeout=2000
group-by=category
EOF

# Create Screenshots directory
print_status "Creating Screenshots directory..."
mkdir -p ~/Screenshots

# Create GTK theme configuration for Dracula
print_status "Configuring GTK theme with Dracula..."
cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Dracula
gtk-icon-theme-name=Dracula
gtk-font-name=JetBrainsMono Nerd Font 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
gtk-application-prefer-dark-theme=1
EOF

# Enable and start necessary services
print_status "Enabling system services..."
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
sudo systemctl enable bluetooth
sudo systemctl start bluetooth
sudo systemctl enable sddm
print_warning "SDDM will be enabled but not started until next boot"

# Enable PipeWire services for current user
print_status "Enabling PipeWire audio services..."
if systemctl --user list-unit-files >/dev/null 2>&1; then
    systemctl --user enable pipewire.service
    systemctl --user enable pipewire-pulse.service
    systemctl --user enable wireplumber.service
else
    print_warning "systemd --user is not available in this session; skipping PipeWire user service enablement."
fi

# Add user to necessary groups
print_status "Adding user to necessary groups..."
sudo usermod -aG video,audio,input "$USER"

# Ensure desktop entry for Sway exists
print_status "Ensuring desktop entry for Sway..."
if [[ -f /usr/share/wayland-sessions/sway.desktop ]]; then
    print_status "Desktop entry already present; leaving existing file untouched."
else
    print_warning "Sway desktop entry missing, creating a minimal entry."
    sudo tee /usr/share/wayland-sessions/sway.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Sway
Comment=An i3-compatible Wayland compositor
Exec=sway
TryExec=sway
Type=Application
EOF
fi

# Configure SDDM for better Wayland support
print_status "SDDM remains on its default configuration; adjust /etc/sddm.conf.d manually if you require Wayland-specific tweaks."

# Update font cache
print_status "Updating font cache..."
fc-cache -fv

# Set environment variables for consistent theming
print_status "Setting up environment variables for theming..."
BASHRC_FILE="$HOME/.bashrc"
touch "$BASHRC_FILE"
print_status "Ensuring ~/.local/bin is available on PATH..."
LOCAL_BIN_EXPORT='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -Fxq "$LOCAL_BIN_EXPORT" "$BASHRC_FILE"; then
    {
        echo ""
        echo "# Sway install script PATH update"
        echo "$LOCAL_BIN_EXPORT"
    } >> "$BASHRC_FILE"
else
    print_warning "~/.local/bin is already exported in ~/.bashrc, skipping..."
fi

if ! grep -q "Sway install script theme exports" "$BASHRC_FILE"; then
    {
        echo ""
        echo "# Sway install script theme exports"
        echo "export GTK_THEME=Dracula"
        echo "export QT_QPA_PLATFORMTHEME=qt5ct"
        echo "export XCURSOR_THEME=Adwaita"
    } >> "$BASHRC_FILE"
else
    print_warning "Theme-related environment variables already present in ~/.profile, skipping..."
fi

# Ensure Nymph fetch runs in interactive shells
print_status "Configuring Nymph fetch for shell sessions..."
BASHRC_FILE="$HOME/.bashrc"
touch "$BASHRC_FILE"
if ! grep -q "Sway install script Nymph fetch" "$BASHRC_FILE"; then
    {
        echo ""
        echo "# Sway install script Nymph fetch"
        echo "nymph"
    } >> "$BASHRC_FILE"
else
    print_warning "Nymph fetch snippet already present in ~/.bashrc, skipping..."
fi

# Final message
print_success "Sway installation and configuration complete!"
echo
print_status "Configuration summary:"
echo "  • SDDM display manager installed and enabled"
echo "  • Sway WM with Waybar status bar (Dracula theme)"
echo "  • Kitty terminal emulator (Dracula theme)"
echo "  • Brave browser"
echo "  • NimLaunch application launcher"
echo "  • Nymph fetch utility (auto-runs in terminal)"
echo "  • Swaylock screen locker with Dracula theme"
echo "  • Mako notification daemon (Dracula theme)"
echo "  • GTK applications themed with Dracula"
echo "  • PipeWire audio system (modern replacement for PulseAudio)"
echo "  • Paru AUR helper installed"
echo "  • Nerd Fonts with icon support"
echo "  • Screenshot tools (grim + slurp)"
echo "  • Audio/brightness controls configured"
echo "  • Auto-lock after 5 minutes of inactivity"
echo "  • Consistent Dracula theme across all components"
echo
print_warning "Please reboot your system to start SDDM display manager."
print_warning "After reboot, select 'Sway' from the session menu in SDDM."
echo
print_status "Basic key bindings:"
echo "  • Super + Enter: Open terminal (Kitty)"
echo "  • Super + D: NimLaunch application launcher"
echo "  • Super + B: Open Brave browser"
echo "  • Super + N: File manager"
echo "  • Super + I: Lock screen"
echo "  • Super + Shift + Q: Close window"
echo "  • Super + Shift + E: Exit Sway"
echo "  • Print: Screenshot"
echo "  • Super + Print: Area screenshot"
echo
print_status "Configuration files are located in ~/.config/"
print_status "AUR helper 'paru' is available for installing AUR packages"
print_success "Installation script completed successfully! Please reboot to use SDDM."
