#!/usr/bin/env bash
# ============================================================
# Yaya OS — Apps por defecto
#   · Xournal++   (notas a mano / lápiz — X1 Yoga Gen4, stylus)
#   · Firefox ESR + uBlock Origin (extensión del sistema, activa para
#     todos los usuarios) — navegador por defecto
#   En live-build: config/hooks/live/0540-yaya-apps.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [apps 1/3] Xournal++ (lápiz / stylus)"
apt-get update
apt-get install -y --no-install-recommends xournalpp \
  && echo "   OK: Xournal++ instalado" \
  || echo "   WARN: Xournal++ omitido"

echo "==> [apps 2/3] Firefox ESR + uBlock Origin"
apt-get install -y --no-install-recommends \
  firefox-esr firefox-esr-l10n-es-es webext-ublock-origin-firefox
# Brave (antiguo default) fuera: si quedó de un build previo, se purga.
apt-get purge -y brave-browser 2>/dev/null || true
rm -f /etc/apt/sources.list.d/brave-browser-release.list \
      /usr/share/keyrings/brave-browser-archive-keyring.gpg

# Políticas de Firefox: sin telemetría, sin "Firefox Studies", uBlock ya
# viene activado vía webext-ublock-origin-firefox (sideload del sistema).
install -d /etc/firefox-esr/policies
cat > /etc/firefox-esr/policies/policies.json <<'JSON'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DontCheckDefaultBrowser": true,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "NoDefaultBookmarks": true,
    "Homepage": { "URL": "https://yaya.tech", "StartPage": "homepage" }
  }
}
JSON

echo "==> [apps 3/3] Firefox como navegador por defecto (todos los usuarios)"
install -d /etc/xdg
cat > /etc/xdg/mimeapps.list <<'MIME'
[Default Applications]
text/html=firefox-esr.desktop
application/xhtml+xml=firefox-esr.desktop
x-scheme-handler/http=firefox-esr.desktop
x-scheme-handler/https=firefox-esr.desktop
x-scheme-handler/about=firefox-esr.desktop
x-scheme-handler/unknown=firefox-esr.desktop
application/pdf=org.gnome.Evince.desktop
MIME
update-alternatives --set x-www-browser /usr/bin/firefox-esr 2>/dev/null || true
update-alternatives --set gnome-www-browser /usr/bin/firefox-esr 2>/dev/null || true

echo "Apps listas."
