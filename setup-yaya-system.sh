#!/bin/sh
# ============================================================
# Yaya OS — ajustes de sistema post-paquetes
#   · Compila la BD dconf (Onboard auto-show NO aplicaba sin esto)
#   · Habilita bluetooth.service
#   · Permisos/validación de sudoers NOPASSWD
# ============================================================
set -e

# dconf: compilar /etc/dconf/db/local.d -> /etc/dconf/db/local
if command -v dconf >/dev/null; then
  dconf update
  [ -f /etc/dconf/db/local ] || { echo "yaya: FALTA /etc/dconf/db/local tras dconf update"; exit 1; }
  echo "yaya: dconf db compilada"
else
  echo "yaya: dconf-cli no instalado"; exit 1
fi

# bluetooth
systemctl enable bluetooth.service 2>/dev/null || true

# sudoers
if [ -f /etc/sudoers.d/yaya-nopasswd ]; then
  chown root:root /etc/sudoers.d/yaya-nopasswd
  chmod 440 /etc/sudoers.d/yaya-nopasswd
  visudo -cf /etc/sudoers.d/yaya-nopasswd
fi
echo "yaya: system tweaks OK"
