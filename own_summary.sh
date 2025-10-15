#!/bin/bash
# ~/.login_info.sh
# Silent system info script with package check, background updates, crontab verification, and dynamic fetcher

HIDDEN_DIR="$HOME/.hidden_dir"
CHECKFILE="$HIDDEN_DIR/.pkg_check_done"
WEATHERFILE="$HIDDEN_DIR/.weather.txt"
SPEEDFILE="$HIDDEN_DIR/.speed.txt"
PKGS=("fastfetch" "neofetch" "duf" "wget" "sshpass" "curl" "speedtest")

mkdir -p "$HIDDEN_DIR"

# ----- PACKAGE CHECK (silent) -----
if [ ! -f "$CHECKFILE" ]; then
    missing=()
    for pkg in "${PKGS[@]}"; do
        command -v "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        sudo yum install -y "${missing[@]}" >/dev/null 2>&1 || echo "⚠️ Failed to install some packages: ${missing[*]}"
    fi
    touch "$CHECKFILE"
fi

# ----- WEATHER UPDATE (every 12h) -----
if [ ! -f "$WEATHERFILE" ] || [ $(find "$WEATHERFILE" -mmin +720 2>/dev/null) ]; then
    curl -s http://wttr.in/Radzymin > "$WEATHERFILE" 2>/dev/null &
fi

# ----- SPEEDTEST UPDATE (every 24h) -----
if [ ! -f "$SPEEDFILE" ] || [ $(find "$SPEEDFILE" -mmin +1440 2>/dev/null) ]; then
    {
        echo " "
        date
        /usr/bin/speedtest
    } >> "$SPEEDFILE" 2>/dev/null &
fi

# ----- ENSURE CRONTAB ENTRIES EXIST -----
CRON_ENTRIES=(
"5 */2 * * * $HIDDEN_DIR/.get_ip.sh > /dev/null 2>&1"
"15 6,18 * * * $HIDDEN_DIR/.weather.sh > /dev/null 2>&1"
"10 */12 * * * $HIDDEN_DIR/.speed.sh > /dev/null 2>&1"
)

crontab -l 2>/dev/null | grep -v '^#' > "$HIDDEN_DIR/.current_cron" || true
for entry in "${CRON_ENTRIES[@]}"; do
    if ! grep -Fxq "$entry" "$HIDDEN_DIR/.current_cron"; then
        (crontab -l 2>/dev/null; echo "$entry") | crontab -
    fi
done
rm -f "$HIDDEN_DIR/.current_cron"

# ----- DISPLAY SYSTEM INFO -----
echo

# Weather
cat "$WEATHERFILE" 2>/dev/null || echo "Weather info not available."
echo

# System info (fastfetch preferred, neofetch fallback)
if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
elif command -v neofetch >/dev/null 2>&1; then
    neofetch
else
    echo "System info unavailable (neither fastfetch nor neofetch installed)."
fi
echo

# Disk usage
duf --hide-fs squashfs 2>/dev/null || { echo "duf not available, using df:"; df -h | grep -v loop; }
echo

# Current IP
echo "Current IP:"
wget -qO- http://ipinfo.io/ip || echo "N/A"
echo
echo

# Last IP
echo "Last IP:"
tail -1 "$HIDDEN_DIR/.last_ip.txt" 2>/dev/null || echo "N/A"
echo

# Latest speed test
echo "Speed test (latest result):"
grep -E 'Down|Upl' "$SPEEDFILE" | tail -2 2>/dev/null || echo "No speed data yet."
echo

# Date and system info
echo "Current date:"
date
echo

echo "Last system update:"
sudo yum history | sed -n '1,4p'
echo

echo "Last date update - WEBSITE:"
wget -q -O - http://WEBSITE/test_file.txt | tail -n 2
echo

echo "Linaro date and uptime:"
sshpass -p 'password' ssh -q -p PORT user@remote 'date; uptime' 2>/dev/null || echo "SSH connection failed."
echo
