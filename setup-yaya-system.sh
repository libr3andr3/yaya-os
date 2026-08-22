#!/bin/sh
# ============================================================
# Yaya OS — ajustes de sistema post-paquetes
#   · Habilita bluetooth.service
#   · Permisos/validación de sudoers NOPASSWD (si existe)
#   · Limpia restos de escritorios anteriores (dconf/onboard) si quedaron
# ============================================================
set -e

systemctl enable bluetooth.service 2>/dev/null || true

if [ -f /etc/sudoers.d/yaya-nopasswd ]; then
  chown root:root /etc/sudoers.d/yaya-nopasswd
  chmod 440 /etc/sudoers.d/yaya-nopasswd
  visudo -cf /etc/sudoers.d/yaya-nopasswd
fi

rm -f /etc/skel/.config/autostart/onboard.desktop \
      /etc/skel/.config/autostart/yaya-autorotate.desktop 2>/dev/null || true

echo "yaya: system tweaks OK"
