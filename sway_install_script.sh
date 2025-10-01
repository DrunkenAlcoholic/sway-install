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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
if [[ ${SWAY_INSTALL_SKIP_UPGRADE:-0} == 1 ]]; then
    print_warning "SWAY_INSTALL_SKIP_UPGRADE=1 detected; skipping system upgrade."
else
    sudo pacman -Syu --noconfirm
fi

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
    bibata-cursor-theme \
    iwd \
    wireless_tools \
    wpa_supplicant \
    smartmontools \
    xdg-utils

# Detect VirtualBox environment and install guest utilities if needed
print_status "Checking virtualization environment..."
virt_type=$(systemd-detect-virt 2>/dev/null || echo "unknown")
case "$virt_type" in
    oracle)
        print_status "VirtualBox detected; installing guest additions..."
        sudo pacman -S --noconfirm --needed virtualbox-guest-utils
        sudo systemctl enable --now vboxservice
        ;;
    vmware)
        print_status "VMware detected; installing open-vm-tools..."
        sudo pacman -S --noconfirm --needed open-vm-tools
        sudo systemctl enable --now vmtoolsd.service
        ;;
    none)
        print_status "No virtualization detected; skipping guest utility installation."
        ;;
    qemu|kvm)
        print_status "Virtualization detected ($virt_type); no additional guest utilities configured."
        ;;
    *)
        print_warning "Virtualization type '$virt_type' detected; no guest utilities configured for automatic installation."
        ;;
esac

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
print_status "Deploying Sway configuration..."
install -Dm644 "$SCRIPT_DIR/.config/sway/config" "$HOME/.config/sway/config"

# Create swaylock configuration with Dracula theme
print_status "Deploying swaylock configuration with Dracula theme..."
install -Dm644 "$SCRIPT_DIR/.config/swaylock/config" "$HOME/.config/swaylock/config"

# Create Waybar configuration with Dracula theme
print_status "Deploying Waybar configuration with Dracula theme..."
install -Dm644 "$SCRIPT_DIR/.config/waybar/config" "$HOME/.config/waybar/config"

install -Dm644 "$SCRIPT_DIR/.config/waybar/style.css" "$HOME/.config/waybar/style.css"

# Create Kitty configuration with Dracula theme
print_status "Deploying Kitty configuration with Dracula theme..."
install -Dm644 "$SCRIPT_DIR/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

# Create Mako (notification daemon) configuration with Dracula theme
print_status "Deploying Mako configuration with Dracula theme..."
install -Dm644 "$SCRIPT_DIR/.config/mako/config" "$HOME/.config/mako/config"

# Create Screenshots directory
print_status "Creating Screenshots directory..."
mkdir -p ~/Screenshots

# Create GTK theme configuration for Dracula
print_status "Configuring GTK theme with Dracula..."
install -Dm644 "$SCRIPT_DIR/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"

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
        echo "export XCURSOR_THEME=Bibata-Modern-Ice"
        echo "export XCURSOR_SIZE=24"
    } >> "$BASHRC_FILE"
else
    if grep -q 'export XCURSOR_THEME=Adwaita' "$BASHRC_FILE"; then
        print_status "Updating existing cursor theme export in ~/.bashrc..."
        sed -i "s/export XCURSOR_THEME=Adwaita/export XCURSOR_THEME=Bibata-Modern-Ice/" "$BASHRC_FILE"
        if ! grep -q 'export XCURSOR_SIZE=' "$BASHRC_FILE"; then
            sed -i "/export XCURSOR_THEME=Bibata-Modern-Ice/a export XCURSOR_SIZE=24" "$BASHRC_FILE"
        fi
    else
        if ! grep -q 'export XCURSOR_SIZE=' "$BASHRC_FILE"; then
            print_status "Adding missing cursor size export to ~/.bashrc..."
            sed -i "/export XCURSOR_THEME=.*$/a export XCURSOR_SIZE=24" "$BASHRC_FILE"
        fi
        print_warning "Theme-related environment variables already present in ~/.bashrc, skipping..."
    fi
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

# Configure Helix alias
print_status "Adding Helix alias..."
if ! grep -Fxq "alias hx='helix'" "$BASHRC_FILE"; then
    {
        echo ""
        echo "# Sway install script Helix alias"
        echo "alias hx='helix'"
    } >> "$BASHRC_FILE"
else
    print_warning "Helix alias already present in ~/.bashrc, skipping..."
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
