#!/usr/bin/env bash
# ============================================================
# Yaya OS — Wallets: Bitcoin (Electrum) + Monero (Feather)
# Nodo por defecto: yaya.cash
# Uso: sudo ./setup-yaya-wallets.sh
# En live-build: config/hooks/live/0510-yaya-wallets.hook.chroot
# ============================================================
set -euo pipefail

# ---- Versiones pinneadas (actualizar deliberadamente, no auto) ----
ELECTRUM_VER="4.5.8"
FEATHER_VER="2.7.0"

# ---- Nodos por defecto (infraestructura comunitaria Yaya) ----
BTC_ELECTRUM_SERVER="electrum.yaya.cash:50002:s"   # Fulcrum/electrs con SSL
XMR_NODE_HOST="node.yaya.cash"
XMR_NODE_PORT="18089"                               # RPC restringido

# ---- Fingerprints de los mantenedores (confianza estricta) ----
ELECTRUM_FPR="6694D8DE7BE8EE5631BED9502BD5824B7F9470E6"   # Thomas Voegtlin
FEATHER_FPR="8185E158A33330C7FD61BC0D1F76E155CEFBA71C"    # tobtoht

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/4] Dependencias"
apt-get update
apt-get install -y --no-install-recommends \
  python3 python3-pip python3-pyqt6 python3-cryptography \
  gnupg curl ca-certificates
# libsecp256k1: el soname cambia por release (-1 en bookworm, -2 en trixie).
# Es OPCIONAL (Electrum cae a ECC en python si falta) -> best-effort, nunca aborta.
apt-get install -y --no-install-recommends libsecp256k1-2 \
  || apt-get install -y --no-install-recommends libsecp256k1-1 \
  || echo "   WARN: libsecp256k1 no disponible; Electrum usara ECC en python (mas lento)"

# ------------------------------------------------------------
# Verificación GPG ESTRICTA pero tolerante a firmas múltiples.
# El tarball de Electrum lleva 3 firmas (varios mantenedores); solo
# confiamos en UNA llave. Exigimos que ESA llave dé firma válida y
# Buena, e ignoramos las firmas de llaves que no importamos — sin
# que el código de salida de gpg (no-cero por "No public key") aborte.
# ------------------------------------------------------------
verify_by() { # <asc> <file> <primary_fpr>
  local st
  st=$(gpg --status-fd 1 --verify "$1" "$2" 2>/dev/null || true)
  echo "$st" | grep -Eq "^\[GNUPG:\] GOODSIG " || return 1
  echo "$st" | grep -Eq "^\[GNUPG:\] VALIDSIG .*$3" || return 1
  return 0
}

# ---- Electrum (best-effort: si falla se OMITE, no rompe la ISO) ----
install_electrum() {
  cd "$TMP" || return 1
  curl -fsSLO "https://download.electrum.org/${ELECTRUM_VER}/Electrum-${ELECTRUM_VER}.tar.gz"     || return 1
  curl -fsSLO "https://download.electrum.org/${ELECTRUM_VER}/Electrum-${ELECTRUM_VER}.tar.gz.asc" || return 1
  gpg --keyserver keyserver.ubuntu.com --recv-keys "$ELECTRUM_FPR" || return 1
  verify_by "Electrum-${ELECTRUM_VER}.tar.gz.asc" "Electrum-${ELECTRUM_VER}.tar.gz" "$ELECTRUM_FPR" \
    || { echo "   Electrum: firma NO confiable -> no se instala"; return 1; }
  pip3 install --break-system-packages "./Electrum-${ELECTRUM_VER}.tar.gz" || return 1
  return 0
}

# ---- Feather (best-effort) ----
install_feather() {
  cd "$TMP" || return 1
  curl -fsSLO "https://featherwallet.org/files/releases/linux/feather-${FEATHER_VER}-linux.AppImage"     || return 1
  curl -fsSLO "https://featherwallet.org/files/releases/linux/feather-${FEATHER_VER}-linux.AppImage.asc" || return 1
  gpg --keyserver keyserver.ubuntu.com --recv-keys "$FEATHER_FPR" || return 1
  verify_by "feather-${FEATHER_VER}-linux.AppImage.asc" "feather-${FEATHER_VER}-linux.AppImage" "$FEATHER_FPR" \
    || { echo "   Feather: firma NO confiable -> no se instala"; return 1; }
  install -Dm755 "feather-${FEATHER_VER}-linux.AppImage" /opt/feather/feather.AppImage || return 1
  cat > /usr/share/applications/feather.desktop <<'EOF'
[Desktop Entry]
Name=Feather (Monero)
Comment=Billetera Monero ligera y privada
Exec=/opt/feather/feather.AppImage
Icon=feather
Terminal=false
Type=Application
Categories=Office;Finance;
EOF
  return 0
}

echo "==> [2/4] Electrum ${ELECTRUM_VER} (verificado con GPG)"
install_electrum && echo "   OK: Electrum instalado" || echo "   WARN: Electrum OMITIDO (red/firma). La ISO sigue."

echo "==> [3/4] Feather Wallet ${FEATHER_VER} (verificado con GPG)"
install_feather  && echo "   OK: Feather instalado"  || echo "   WARN: Feather OMITIDO (red/firma). La ISO sigue."

echo "==> [4/4] Configs por defecto en /etc/skel (nodo yaya.cash)"
# Estas preconfiguraciones son inocuas aunque una wallet se haya omitido:
# solo fijan el nodo por defecto cuando el usuario instale/abra la app.

# ---- Electrum: servidor fijo yaya.cash, sin auto-conectar a terceros ----
install -d /etc/skel/.electrum
cat > /etc/skel/.electrum/config <<EOF
{
    "server": "${BTC_ELECTRUM_SERVER}",
    "auto_connect": false,
    "oneserver": true,
    "check_updates": false,
    "use_rbf": true
}
EOF

# ---- Feather: nodo custom yaya.cash como default ----
install -d /etc/skel/.config/feather
cat > /etc/skel/.config/feather/settings.json <<EOF
{
    "nodes": {
        "custom": ["${XMR_NODE_HOST}:${XMR_NODE_PORT}"],
        "source": 1
    },
    "checkForUpdates": false,
    "hideBalance": false
}
EOF

# ---- Monero GUI (si se instala después): mismo nodo ----
install -d /etc/skel/.config/monero-project
cat > /etc/skel/.config/monero-project/monero-core.conf <<EOF
[General]
remoteNodeAddress=${XMR_NODE_HOST}:${XMR_NODE_PORT}
useRemoteNode=true
EOF

echo ""
echo "Listo."
echo "  BTC : Electrum -> ${BTC_ELECTRUM_SERVER}"
echo "  XMR : Feather  -> ${XMR_NODE_HOST}:${XMR_NODE_PORT}"
echo "El usuario puede cambiar de nodo en ambas apps (sovereign-by-choice)."
