#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# =============================================================================
#  pw-hires-in — réception du son d'un PC par le réseau (côté Raspberry Pi)
#
#  Prérequis : pi-sound-server (PipeWire sous l'utilisateur hifi, sortie MASTER).
#  Si pi-server est présent, son pare-feu est complété (réseau local, un seul
#  émetteur à la fois).
#
#     sudo bash install.sh
#
#  Configuration : /etc/pw-hires-in/pw-in.conf (déployée depuis le dépôt)
#                  /etc/pw-hires-in/local.conf (réglages propres, conservés)
#  Idempotent : peut être relancé (c'est ce que fait « sudo pi-server update »).
# =============================================================================
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "À lancer avec sudo."; exit 1; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
F="$HERE/files"
CONF_DIR=/etc/pw-hires-in
CONF="$CONF_DIR/pw-in.conf"
log()  { printf '\n\033[1;36m[pw-hires-in]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

# --- Prérequis -------------------------------------------------------------------
if ! command -v pipewire >/dev/null || \
        ! compgen -G "/usr/lib/*/pipewire-0.3/libpipewire-module-rtp-source.so" >/dev/null; then
    log "Module RTP de PipeWire"
    apt-get -o DPkg::Lock::Timeout=900 -o APT::Install-Recommends=false -y install pipewire
fi
if [[ ! -f /etc/pi-sound-server/audio-hub.conf ]]; then
    warn "pi-sound-server n'est pas installé : le son reçu sera envoyé vers « MASTER »"
    warn "de l'utilisateur hifi (à régler dans $CONF : [global] user / target)."
fi

# Ancienne version (rock-n-roll-pw-in) : deux récepteurs sur le même port
if [[ -e /usr/local/bin/rock-n-roll-pw-in ]]; then
    log "Retrait de l'ancienne version (rock-n-roll-pw-in)"
    bash "$HERE/uninstall.sh"
fi

# --- Configuration ------------------------------------------------------------
log "Configuration"
mkdir -p "$CONF_DIR"
# Déployée depuis le dépôt à chaque installation / mise à jour ; l'ancienne est
# sauvegardée. Les réglages propres à cette Pi vont dans local.conf (jamais écrasé).
if [[ -f "$CONF" ]] && ! cmp -s "$HERE/pw-in.conf" "$CONF"; then
    cp -a "$CONF" "$CONF.avant-maj"
    echo "   ancienne configuration gardée : $CONF.avant-maj"
fi
install -m 644 "$HERE/pw-in.conf" "$CONF"
if [[ ! -f "$CONF_DIR/local.conf" ]]; then
    cat > "$CONF_DIR/local.conf" <<'EOF'
# Réglages propres à cette Pi : lus après pw-in.conf, jamais écrasés par une mise à jour.
# Exemple :
# [rtp]
# latency-ms = 20
EOF
fi
install -m 755 "$F/bin/pw-hires-in" /usr/local/bin/pw-hires-in

# --- Génération, pare-feu et démarrage ---------------------------------------------
log "Génération et démarrage du récepteur"
/usr/local/bin/pw-hires-in apply

PORT="$(/usr/local/bin/pw-hires-in check | sed -n 's/.*port UDP \([0-9]*\).*/\1/p')"
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
log "Terminé"
cat <<EOF
   Récepteur RTP : $(hostname).local ($IP), port UDP ${PORT:-46000}
   Sur le PC : dépôt pw-hires-out
       git clone https://github.com/flavi1/pw-hires-out.git
       bash pw-hires-out/install.sh --host $(hostname).local
   État : sudo pw-hires-in status
EOF
