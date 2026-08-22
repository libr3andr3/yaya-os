#!/usr/bin/env bash
# ============================================================
# Yaya OS — post-config de las apps de escritorio
#   · Flathub como remoto Flatpak (para la tienda GNOME Software)
#   · unattended-upgrades: solo seguridad, sin reinicios automáticos
#   · CUPS habilitado
#   En live-build: config/hooks/live/0545-yaya-desktop.hook.chroot
# ============================================================
set -euo pipefail

echo "==> [1/3] Flathub (best-effort, necesita red)"
if command -v flatpak >/dev/null; then
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
    && echo "   OK: Flathub añadido" || echo "   WARN: Flathub omitido (red); se puede añadir luego desde la tienda"
fi

echo "==> [2/3] unattended-upgrades: seguridad automática"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'APT'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT
cat > /etc/apt/apt.conf.d/52yaya-unattended <<'APT'
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
APT

echo "==> [3/3] Servicios"
systemctl enable cups.service cups-browsed.service 2>/dev/null || true
systemctl enable systemd-timesyncd.service 2>/dev/null || true
systemctl enable power-profiles-daemon.service 2>/dev/null || true
echo "Desktop apps listas."
