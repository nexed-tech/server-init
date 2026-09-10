#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting headless Debian initialization..."

# --- CONFIGURATION ---
GITHUB_USER="scraane"  # <--- Change this to your GitHub username
TARGET_TZ="Asia/Manila"                  # <--- Change this to your timezone (e.g., America/New_York)

# 1. Update package lists
sudo apt-get update -y

# 2. Install modern CLI tools
PACKAGES=(curl git tmux duf fastfetch nala jq)
for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "📦 Installing $pkg..."
        sudo apt-get install -y "$pkg"
    else
        echo "✅ $pkg is already installed."
    fi
done

# 3. Set the Timezone safely
if [ "$(cat /etc/timezone)" != "$TARGET_TZ" ]; then
    echo "🕒 Setting timezone to $TARGET_TZ..."
    sudo timedatectl set-timezone "$TARGET_TZ"
else
    echo "✅ Timezone is already $TARGET_TZ."
fi

# 4. Download external scripts safely
mkdir -p "$HOME/scripts"
DOCKCHECK_PATH="$HOME/scripts/dockcheck.sh"

if [ ! -f "$DOCKCHECK_PATH" ]; then
    echo "⚓ Fetching dockcheck.sh..."
    curl -sSL "https://raw.githubusercontent.com/mag37/dockcheck/main/dockcheck.sh" -o "$DOCKCHECK_PATH"
    chmod +x "$DOCKCHECK_PATH"
else
    echo "✅ dockcheck.sh already exists."
fi

# 5. Inject individual aliases safely via an associative array
echo "🔧 Checking and updating .bash_aliases..."
touch "$HOME/.bash_aliases"

declare -A ALIASES
ALIASES=(
    ["dockup"]="echo 'Checking docker updates' && /home/tabang/dockcheck/dockcheck.sh -f -o -p -u -x 3 -y"
)

for shortcut in "${!ALIASES[@]}"; do
    if ! grep -q "alias ${shortcut}=" "$HOME/.bash_aliases"; then
        echo "📝 Adding alias: ${shortcut}"
        echo "alias ${shortcut}='${ALIASES[$shortcut]}'" >> "$HOME/.bash_aliases"
    else
        echo "✅ Alias '${shortcut}' already exists."
    fi
done

# 6. Authorize SSH Public Keys from GitHub safely
echo "🔑 Checking SSH authorized_keys..."
SSH_DIR="$HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

# Ensure the .ssh directory exists with correct secure permissions
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

if [ "$GITHUB_USER" != "YOUR_GITHUB_USERNAME" ]; then
    echo "📡 Fetching public keys for user: $GITHUB_USER..."
    
    # Download public keys into a temporary variable, filtering empty lines
    PUB_KEYS=$(curl -s "https://github.com{GITHUB_USER}.keys" | grep -v '^$')

    if [ -n "$PUB_KEYS" ]; then
        # Read keys line by line to check and append individually
        while IFS= read -r key; do
            # Use grep to check if the specific key fingerprint/string already exists
            if ! grep -Fq "$key" "$AUTH_KEYS"; then
                echo "📝 Adding new SSH key..."
                echo "$key" >> "$AUTH_KEYS"
            else
                echo "✅ Key already authorized."
            fi
        done <<< "$PUB_KEYS"
    else
        echo "⚠️ Warning: No public keys found or failed to fetch from GitHub."
    fi
else
    echo "⏭️ Skipping SSH setup (GitHub username not configured in script)."
fi

echo "🎉 All done! Run 'source ~/.bash_aliases' or reconnect to apply changes."
