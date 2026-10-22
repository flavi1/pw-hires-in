#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# pw-hires-in — désinstallation (sudo). La configuration /etc/pw-hires-in est gardée
# sauf avec --purge. Retire aussi l'ancienne version (rock-n-roll-pw-in).
# Ne touche ni à pi-sound-server ni au reste du pare-feu.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "À lancer avec sudo."; exit 1; }
AUSER="$(awk -F= '/^\[/{s=$0} s=="[global]" && $1~/^[[:space:]]*user[[:space:]]*$/{gsub(/[[:space:]]/,"",$2); print $2; exit}' \
    /etc/pi-sound-server/audio-hub.conf 2>/dev/null || true)"
AUSER="${AUSER:-hifi}"
UHOME="$(getent passwd "$AUSER" | cut -d: -f6 || true)"
for u in pw-hires-rtp rock-n-roll-rtp rock-n-roll-roc; do
    systemctl --user -M "$AUSER@" disable --now "$u.service" 2>/dev/null || true
    [[ -n "$UHOME" ]] && rm -f "$UHOME/.config/systemd/user/$u.service" "$UHOME/.config/pipewire/$u.conf"
done
systemctl --user -M "$AUSER@" daemon-reload 2>/dev/null || true
rm -f /usr/local/bin/pw-hires-in /usr/local/bin/rock-n-roll-pw-in /usr/local/bin/rock-n-roll-roc
rm -rf /etc/rock-n-roll-pw-in /var/lib/rock-n-roll-pw-in      # ancienne version
[[ "${1:-}" != --purge ]] || rm -rf /etc/pw-hires-in
fw=0
for f in /etc/nftables.d/30-pw-hires-in.nft /etc/nftables.d/30-rock-n-roll-pw-in.nft; do
    [[ -f "$f" ]] && { rm -f "$f"; fw=1; }
done
if [[ $fw -eq 1 ]] && nft -c -f /etc/nftables.conf; then
    systemctl restart nftables
    systemctl is-active --quiet fail2ban && systemctl restart fail2ban || true
    echo "Pare-feu : ports de réception refermés"
fi
echo "pw-hires-in désinstallé."
