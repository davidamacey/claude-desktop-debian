#!/usr/bin/env bash
# Update Claude Desktop to the latest version
# Usage: ./update-claude-desktop.sh

set -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Claude Desktop Updater ==="

# Pull latest build scripts
echo "Pulling latest build scripts..."
cd "$script_dir" || exit 1
git pull --rebase || { echo "Failed to pull latest changes" >&2; exit 1; }

# Check current vs available version
current=$(dpkg-query -W -f='${Version}' claude-desktop 2>/dev/null) || current='none'
available=$(grep -oP 'x64/\K[0-9]+\.[0-9]+\.[0-9]+' build.sh | head -1)
echo "Installed: $current"
echo "Available: $available"

if [[ "$current" == "$available" ]]; then
	echo "Already up to date."
	read -rp "Rebuild anyway? [y/N] " answer
	[[ "${answer,,}" == 'y' ]] || exit 0
fi

# Build
echo "Building .deb package..."
bash build.sh --build deb || { echo "Build failed" >&2; exit 1; }

# Install
deb_file="$script_dir/claude-desktop_${available}_amd64.deb"
if [[ ! -f "$deb_file" ]]; then
	echo "No .deb file found: $deb_file" >&2
	exit 1
fi

echo "Installing $deb_file..."
sudo apt install -y "$deb_file" || { echo "Install failed" >&2; exit 1; }

# Apply XRDP fix
echo "Applying XRDP launcher fix..."
sudo cp "$script_dir/scripts/launcher-common.sh" \
	/usr/lib/claude-desktop/launcher-common.sh

# Restart if running
if pgrep -f claude-desktop &>/dev/null; then
	echo "Restarting Claude Desktop..."
	pkill -f claude-desktop
	sleep 2
	nohup claude-desktop &>/dev/null &
	echo "Claude Desktop restarted."
else
	echo "Claude Desktop not running. Start with: claude-desktop"
fi

echo "=== Update complete: $(dpkg-query -W -f='${Version}' claude-desktop) ==="
