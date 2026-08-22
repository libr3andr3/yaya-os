#!/usr/bin/env bash
# ============================================================
# Yaya OS — Fastfetch con marca Yaya
#   · fastfetch como "cara" del sistema en la terminal:
#     alien ASCII + columna de info, colores Yaya
#   · config GLOBAL en /etc/fastfetch/config.jsonc
#     (cada usuario puede pisarla con ~/.config/fastfetch/)
#   · yaya-webcam: puente DSLR -> /dev/video42 con el banner
#   · saludo fastfetch al abrir una terminal nueva (skel)
#
#   Uso manual:  sudo ./setup-yaya-fastfetch.sh
#   En live-build: config/hooks/live/0535-yaya-fastfetch.hook.chroot
# ============================================================
set -euo pipefail

SHARE=/usr/share/yaya/fastfetch
export DEBIAN_FRONTEND=noninteractive

# --- localizar los assets (junto al script, o en /usr/share/yaya) ---
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if   [ -d "$SELF_DIR/fastfetch" ];         then SRC="$SELF_DIR/fastfetch"
elif [ -d /usr/share/yaya/fastfetch-src ]; then SRC=/usr/share/yaya/fastfetch-src
else echo "ERROR: no encuentro los assets de fastfetch"; exit 1; fi

echo "==> [1/5] Paquetes (fastfetch + Pillow para el generador del logo)"
apt-get update
# python3-pil: yaya-logo-gen.py re-renderiza el alien al tamaño exacto de la
# terminal; sin Pillow el banner cae a los .txt fijos (sigue funcionando).
# tmux: el dashboard de yaya-webcam. fastfetch viene directo en trixie+;
# en bookworm está en backports (segundo intento).
apt-get install -y --no-install-recommends fastfetch python3-pil tmux \
  || apt-get install -y --no-install-recommends \
       -t "$(. /etc/os-release && echo "$VERSION_CODENAME")-backports" \
       fastfetch python3-pil tmux

echo "==> [2/5] Assets -> $SHARE"
install -d "$SHARE"
install -m644 "$SRC"/webcam.jsonc "$SRC"/webcam-compact.jsonc \
              "$SRC"/yaya-logo.txt "$SRC"/yaya-logo-small.txt "$SHARE/"
install -m755 "$SRC/yaya-logo-gen.py" "$SHARE/"
# PNG fuente para el generador — el mismo alien que el icono del SO.
if [ -f "$SELF_DIR/branding/yaya-logo.png" ]; then
  install -m644 "$SELF_DIR/branding/yaya-logo.png" "$SHARE/yaya-logo.png"
fi

echo "==> [3/5] Config global -> /etc/fastfetch/config.jsonc"
install -Dm644 "$SRC/config.jsonc" /etc/fastfetch/config.jsonc

echo "==> [4/5] yaya-webcam -> /usr/bin"
# Los deps de streaming (gphoto2, ffmpeg, v4l2loopback-dkms) NO van en la
# ISO base — el propio yaya-webcam indica cómo instalarlos si faltan.
install -Dm755 "$SELF_DIR/yaya-webcam.sh" /usr/bin/yaya-webcam

echo "==> [5/5] Saludo fastfetch en terminales nuevas (skel)"
install -d /etc/skel
if ! grep -q yaya-fastfetch /etc/skel/.bashrc 2>/dev/null; then
  cat >> /etc/skel/.bashrc <<'EOF'

# yaya-fastfetch: la marca saluda al abrir la terminal (una vez por sesión)
if [ -z "${YAYA_FF_GREETED:-}" ] && [ -t 1 ] && command -v fastfetch >/dev/null 2>&1; then
  export YAYA_FF_GREETED=1
  fastfetch
fi
EOF
fi

echo "Listo. Prueba:  fastfetch    ·    yaya-webcam"
