#!/bin/sh
set -eu

cat <<'EOF'
███████╗██╗    ██╗ █████╗ ██╗   ██╗     ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     
██╔════╝██║    ██║██╔══██╗╚██╗ ██╔╝     ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     
███████╗██║ █╗ ██║███████║ ╚████╔╝█████╗██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     
╚════██║██║███╗██║██╔══██║  ╚██╔╝ ╚════╝██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     
███████║╚███╔███╔╝██║  ██║   ██║        ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝        ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
                                                                                                                                                                       
EOF

REPO_URL="https://github.com/DrunkenAlcoholic/sway-install.git"
ARCHIVE_URL="https://github.com/DrunkenAlcoholic/sway-install/archive/refs/heads/main.tar.gz"

tmpdir="$(mktemp -d)"
cleanup() {
    rm -rf "$tmpdir"
}
trap cleanup INT TERM EXIT

repo_path=""

if command -v git >/dev/null 2>&1; then
    if git clone --depth=1 "$REPO_URL" "$tmpdir/repo" >/dev/null 2>&1; then
        repo_path="$tmpdir/repo"
    else
        printf '%s\n' "[bootstrap] git clone failed; falling back to tarball download" >&2
    fi
fi

if [ -z "$repo_path" ]; then
    if ! curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$tmpdir"; then
        printf '%s\n' "[bootstrap] Failed to download repository archive" >&2
        exit 1
    fi
    repo_path="$tmpdir/sway-install-main"
fi

if [ ! -x "$repo_path/sway_install_script.sh" ]; then
    chmod +x "$repo_path/sway_install_script.sh"
fi

if [ -r /dev/tty ]; then
    exec </dev/tty
fi

cd "$repo_path"
exec bash ./sway_install_script.sh "$@"
