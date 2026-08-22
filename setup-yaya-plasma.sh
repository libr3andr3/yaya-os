#!/usr/bin/env bash
# ============================================================
# Yaya OS — KDE Plasma 6 + SDDM + tema Fluent Round (vinceliuice)
#   · Reemplaza a Cinnamon/LightDM.
#   · Wayland por defecto (mejor táctil/gestos); sesión X11 disponible.
#   · Tema global Fluent-round-dark: Plasma, ventanas (Aurorae), Kvantum,
#     iconos Fluent, GTK Fluent (Firefox/LibreOffice), SDDM Fluent.
#   · Sin KWallet molestando; usuario recordado en el login.
#
#   Uso manual:  sudo ./setup-yaya-plasma.sh
#   En live-build: config/hooks/live/0500-yaya-plasma.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/6] Paquetes Plasma 6 + SDDM"
apt-get update
# Si el escritorio o SDDM fallan, el build DEBE fallar (no ISO sin GUI).
apt-get install -y --no-install-recommends \
  plasma-desktop plasma-workspace kwin-wayland kwin-x11 \
  sddm sddm-theme-breeze kde-config-sddm \
  plasma-nm plasma-pa bluedevil powerdevil kscreen \
  xdg-desktop-portal-kde xdg-desktop-portal-gtk \
  kde-style-breeze breeze-gtk-theme kde-config-gtk-style \
  qt6-style-kvantum \
  kde-cli-tools kdialog plasma-widgets-addons kio-extras \
  ffmpegthumbs kdegraphics-thumbnailers \
  dolphin konsole ark kate kcalc gwenview okular kde-spectacle \
  filelight plasma-systemmonitor partitionmanager print-manager \
  plasma-discover plasma-discover-backend-flatpak \
  pipewire-audio pipewire-pulse wireplumber libspa-0.2-bluetooth \
  xdg-user-dirs fonts-open-sans fonts-noto-core \
  git sassc

echo "==> [2/6] SDDM: Fluent, recordar usuario, Wayland por defecto"
echo "/usr/bin/sddm" > /etc/X11/default-display-manager
systemctl enable sddm.service 2>/dev/null || \
  ln -sf /lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
install -d /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-yaya.conf <<'EOF'
[General]
Numlock=none

[Theme]
Current=Fluent

[Users]
RememberLastUser=true
RememberLastSession=true
HideUsers=
MaximumUid=60000
MinimumUid=1000

[Autologin]
Relogin=false
EOF

echo "==> [3/6] Tema Fluent Round (KDE + iconos + GTK + SDDM)"
FH=/tmp/fluent-home; rm -rf "$FH"; mkdir -p "$FH"
SRC=/tmp/fluent-src; rm -rf "$SRC"; mkdir -p "$SRC"
git clone -q --depth 1 https://github.com/vinceliuice/Fluent-kde        "$SRC/kde"
git clone -q --depth 1 https://github.com/vinceliuice/Fluent-icon-theme "$SRC/icons"
git clone -q --depth 1 https://github.com/vinceliuice/Fluent-gtk-theme  "$SRC/gtk"

# KDE: el installer escribe en $HOME/.local/share -> lo movemos a /usr/share.
( cd "$SRC/kde" && HOME="$FH" bash ./install.sh --round -c dark >/dev/null )
install -d /usr/share/aurorae/themes /usr/share/plasma/desktoptheme \
  /usr/share/plasma/look-and-feel /usr/share/color-schemes /usr/share/Kvantum /usr/share/wallpapers
cp -r "$FH"/.local/share/aurorae/themes/.       /usr/share/aurorae/themes/       2>/dev/null || true
cp -r "$FH"/.local/share/plasma/desktoptheme/.  /usr/share/plasma/desktoptheme/  2>/dev/null || true
cp -r "$FH"/.local/share/plasma/look-and-feel/. /usr/share/plasma/look-and-feel/ 2>/dev/null || true
cp -r "$FH"/.local/share/color-schemes/.        /usr/share/color-schemes/        2>/dev/null || true
cp -r "$FH"/.local/share/wallpapers/.           /usr/share/wallpapers/           2>/dev/null || true
cp -r "$FH"/.config/Kvantum/.                   /usr/share/Kvantum/              2>/dev/null || true
# SDDM (tema Fluent para Plasma 6)
( cd "$SRC/kde/sddm" && bash ./install.sh >/dev/null ) || echo "   WARN: tema SDDM Fluent no instalado"
# Iconos (Fluent, Fluent-dark, Fluent-light)
( cd "$SRC/icons" && bash ./install.sh -d /usr/share/icons >/dev/null ) || echo "   WARN: iconos Fluent no instalados"
# GTK (para Firefox, LibreOffice, Thunderbird...)
# (sassc ya instalado: el installer lo pediría con un apt-get interactivo y se colgaría)
( cd "$SRC/gtk" && bash ./install.sh -d /usr/share/themes -c dark --tweaks round </dev/null >/dev/null ) \
  || ( cd "$SRC/gtk" && bash ./install.sh -d /usr/share/themes -c dark </dev/null >/dev/null ) \
  || echo "   WARN: tema GTK Fluent no instalado"
rm -rf "$FH" "$SRC"

# IDs reales instalados (con fallback si cambia el naming upstream)
pick(){ local dir="$1"; shift; local p; for p in "$@"; do ls -d "$dir"/$p 2>/dev/null | head -1 | xargs -r basename && return 0; done; return 1; }
LNF="$(pick /usr/share/plasma/look-and-feel '*Fluent-round-dark' '*Fluent-round*dark*' '*Fluent*dark*')"
DSK="$(pick /usr/share/plasma/desktoptheme 'Fluent-round-dark' 'Fluent-round*dark*' 'Fluent*dark*')"
AUR="$(pick /usr/share/aurorae/themes 'Fluent-round-dark' 'Fluent-round*dark*' 'Fluent*dark*')"
KVT="$(pick /usr/share/Kvantum 'Fluent-round*' 'Fluent*')"
ICO="$(pick /usr/share/icons 'Fluent-dark' 'Fluent*dark*' 'Fluent')"
GTK="$(pick /usr/share/themes 'Fluent-round-Dark*' 'Fluent*round*Dark*' 'Fluent*Dark*' 'Fluent*')"
COL="$( [ -f /usr/share/color-schemes/FluentDark.colors ] && echo FluentDark || echo BreezeDark )"
install -d /usr/share/yaya/theme
printf 'LNF=%s\nDSK=%s\nAUR=%s\nKVT=%s\nICO=%s\nGTK=%s\nCOL=%s\n' "$LNF" "$DSK" "$AUR" "$KVT" "$ICO" "$GTK" "$COL" \
  | tee /usr/share/yaya/theme/ids
[ -n "$LNF" ] || { echo "ERROR: no se instaló el look-and-feel Fluent round"; exit 1; }

echo "==> [4/6] Defaults del sistema (/etc/xdg) para usuarios nuevos"
install -d /etc/xdg/Kvantum /etc/gtk-3.0 /etc/gtk-4.0
cat > /etc/xdg/kdeglobals <<EOF
[KDE]
LookAndFeelPackage=$LNF
widgetStyle=kvantum
SingleClick=false

[General]
ColorScheme=$COL
AccentColor=0,120,212

[Icons]
Theme=$ICO

[KFileDialog Settings]
Show hidden files=false
EOF
cat > /etc/xdg/plasmarc <<EOF
[Theme]
name=$DSK
EOF
cat > /etc/xdg/kwinrc <<EOF
[org.kde.kdecoration2]
library=org.kde.kwin.aurorae
theme=__aurorae__svg__$AUR
ButtonsOnLeft=
ButtonsOnRight=IAX

[Wayland]
InputMethod=/usr/share/applications/com.github.maliit.keyboard.desktop
EOF
cat > /etc/xdg/Kvantum/kvantum.kvconfig <<EOF
[General]
theme=$KVT
EOF
cat > /etc/xdg/kwalletrc <<'EOF'
[Wallet]
Enabled=false
First Use=false
EOF
cat > /etc/xdg/kcminputrc <<'EOF'
[Mouse]
cursorTheme=breeze_cursors
EOF
cat > /etc/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-theme-name=$GTK
gtk-icon-theme-name=$ICO
gtk-application-prefer-dark-theme=1
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=breeze_cursors
EOF
cp /etc/gtk-3.0/settings.ini /etc/gtk-4.0/settings.ini
# Discover: sin notificaciones agresivas de updates (unattended-upgrades ya hace seguridad)
cat > /etc/xdg/PlasmaDiscoverUpdates <<'EOF'
[Global]
UseUnattendedUpdates=false
EOF

echo "==> [5/6] Aplicar el tema global una vez por usuario (primer login)"
cat > /usr/local/bin/yaya-apply-theme <<'EOF'
#!/bin/sh
# Aplica Fluent Round completo (panel, colores, decoración, iconos, Kvantum)
# la primera vez que un usuario entra a Plasma. Guard: ~/.config/yaya-theme-applied
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"; FLAG="$CFG/yaya-theme-applied"
[ -e "$FLAG" ] && exit 0
. /usr/share/yaya/theme/ids 2>/dev/null || exit 0
sleep 6   # plasmashell terminando de arrancar
plasma-apply-lookandfeel -a "$LNF" >/dev/null 2>&1 || true
[ -n "$COL" ] && plasma-apply-colorscheme "$COL" >/dev/null 2>&1 || true
[ -n "$DSK" ] && plasma-apply-desktoptheme "$DSK" >/dev/null 2>&1 || true
kwriteconfig6 --file kdeglobals --group Icons --key Theme "$ICO"
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme "__aurorae__svg__$AUR"
mkdir -p "$CFG/Kvantum"; printf '[General]\ntheme=%s\n' "$KVT" > "$CFG/Kvantum/kvantum.kvconfig"
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
touch "$FLAG"
EOF
chmod +x /usr/local/bin/yaya-apply-theme
install -d /etc/xdg/autostart
cat > /etc/xdg/autostart/yaya-apply-theme.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Yaya theme (first login)
Exec=/usr/local/bin/yaya-apply-theme
OnlyShowIn=KDE;
X-KDE-autostart-phase=2
NoDisplay=true
EOF

echo "==> [6/6] Limpieza"
apt-get purge -y git sassc >/dev/null 2>&1 || true
apt-get autoremove -y >/dev/null 2>&1 || true
echo "Plasma + Fluent Round listo:"
cat /usr/share/yaya/theme/ids | sed 's/^/   /'
