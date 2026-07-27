#!/usr/bin/env bash
# ============================================================
# Yaya OS — Apps por defecto
#   · Xournal++  (notas a mano / lápiz — X1 Yoga Gen4, stylus)
#   · Brave      (navegador, repo oficial — best-effort)
#   En live-build: config/hooks/live/0540-yaya-apps.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [apps 1/2] Xournal++ (lápiz / stylus)"
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates
# xournalpp trae soporte de presión/lápiz; xserver-xorg-input-wacom ya viene
apt-get install -y --no-install-recommends xournalpp \
  && echo "   OK: Xournal++ instalado" \
  || echo "   WARN: Xournal++ omitido"

echo "==> [apps 2/2] Brave (repo oficial, best-effort)"
install_brave() {
  install -d /usr/share/keyrings
  curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg || return 1
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
    > /etc/apt/sources.list.d/brave-browser-release.list
  apt-get update || return 1
  apt-get install -y brave-browser || return 1
}
install_brave && echo "   OK: Brave instalado" \
  || echo "   WARN: Brave OMITIDO (red). La ISO sigue."

echo "Apps listas."
