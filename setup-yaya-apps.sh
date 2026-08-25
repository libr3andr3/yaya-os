#!/usr/bin/env bash
# ============================================================
# Yaya OS — Apps por defecto
#   · Firefox ESR + uBlock Origin (extensión del sistema, activa para
#     todos los usuarios) — navegador por defecto
#   · Handlers por defecto para HTML/PDF
#
# Xournal++ se retiró (2026-08-25): su config de stylus nunca funcionó
# bien y bajo GNOME el lápiz lo gestiona el propio escritorio
# (Ajustes → Tableta gráfica). Quien lo quiera, lo instala desde la
# tienda; no lo cargamos en la ISO.
#
#   En live-build: config/hooks/live/0540-yaya-apps.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [apps 1/3] Firefox ESR + uBlock Origin"
apt-get update
apt-get install -y --no-install-recommends \
  firefox-esr firefox-esr-l10n-es-es webext-ublock-origin-firefox
# Brave (antiguo default) fuera: si quedó de un build previo, se purga.
apt-get purge -y brave-browser 2>/dev/null || true
rm -f /etc/apt/sources.list.d/brave-browser-release.list \
      /usr/share/keyrings/brave-browser-archive-keyring.gpg
# Xournal++ y su .desktop parcheado: fuera si vienen de un build anterior.
apt-get purge -y xournalpp 2>/dev/null || true
rm -f /usr/local/share/applications/com.github.xournalpp.xournalpp.desktop \
      /usr/local/share/applications/xournalpp.desktop

echo "==> [apps 2/3] Políticas de Firefox (sin telemetría ni onboarding)"
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
    "Homepage": { "URL": "https://yaya.tech", "StartPage": "homepage" },
    "UserMessaging": { "SkipOnboarding": true, "ExtensionRecommendations": false,
      "FeatureRecommendations": false, "MoreFromMozilla": false,
      "UrlbarInterventions": false, "WhatsNew": false },
    "Preferences": {
      "datareporting.policy.dataSubmissionPolicyBypassNotification": { "Value": true, "Status": "locked" },
      "browser.aboutwelcome.enabled": { "Value": false, "Status": "locked" }
    }
  }
}
JSON

echo "==> [apps 3/3] Handlers por defecto (todos los usuarios)"
# El visor de PDF de GNOME cambió de nombre entre releases (Evince ->
# Papers): usamos el que EXISTA en el chroot en vez de adivinar.
PDF_DESKTOP=""
for d in org.gnome.Evince.desktop org.gnome.Papers.desktop evince.desktop; do
  [ -f "/usr/share/applications/$d" ] && { PDF_DESKTOP="$d"; break; }
done
install -d /etc/xdg
cat > /etc/xdg/mimeapps.list <<MIME
[Default Applications]
text/html=firefox-esr.desktop
application/xhtml+xml=firefox-esr.desktop
x-scheme-handler/http=firefox-esr.desktop
x-scheme-handler/https=firefox-esr.desktop
x-scheme-handler/about=firefox-esr.desktop
x-scheme-handler/unknown=firefox-esr.desktop
MIME
if [ -n "$PDF_DESKTOP" ]; then
  echo "application/pdf=$PDF_DESKTOP" >> /etc/xdg/mimeapps.list
  echo "   PDF: $PDF_DESKTOP"
else
  echo "   WARN: sin visor de PDF de GNOME; queda el default del escritorio"
fi
update-alternatives --set x-www-browser /usr/bin/firefox-esr 2>/dev/null || true
update-alternatives --set gnome-www-browser /usr/bin/firefox-esr 2>/dev/null || true

echo "Apps listas."
