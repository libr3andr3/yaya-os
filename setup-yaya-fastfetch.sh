#!/usr/bin/env bash
# ============================================================
# Yaya OS — fastfetch con marca
#   · Alien renderizado AL TAMAÑO REAL de la terminal en cada invocación
#     (wrapper /usr/local/bin/fastfetch -> yaya-logo-gen.py -> fastfetch).
#   · Config GLOBAL en /etc/fastfetch/config.jsonc (el usuario puede
#     pisarla con ~/.config/fastfetch/config.jsonc).
#   · NO se ejecuta al abrir la terminal: sólo cuando se escribe `fastfetch`.
#   · yaya-webcam -> /usr/bin (deps de streaming fuera de la ISO base).
#
#   Uso manual:  sudo ./setup-yaya-fastfetch.sh
#   En live-build: config/hooks/live/0535-yaya-fastfetch.hook.chroot
# ============================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
SHARE=/usr/share/yaya/fastfetch

# --- localizar los assets (junto al script, o en /usr/share/yaya) ---
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
if   [ -d "$SELF_DIR/fastfetch" ];         then SRC="$SELF_DIR/fastfetch"
elif [ -d /usr/share/yaya/fastfetch-src ]; then SRC=/usr/share/yaya/fastfetch-src
else echo "ERROR: no encuentro los assets de fastfetch"; exit 1; fi

echo "==> [1/5] Paquetes (fastfetch + Pillow para el generador del logo)"
apt-get update
apt-get install -y --no-install-recommends fastfetch python3-pil tmux \
  || apt-get install -y --no-install-recommends -t "$(. /etc/os-release; echo "${VERSION_CODENAME}-backports")" fastfetch python3-pil tmux

echo "==> [2/5] Assets -> $SHARE"
install -d "$SHARE"
install -m644 "$SRC"/*.txt "$SRC"/*.jsonc "$SHARE/"
install -m755 "$SRC/yaya-logo-gen.py" "$SHARE/"
for png in "$SELF_DIR/branding/yaya-logo.png" /usr/share/yaya/branding/yaya-logo.png; do
  [ -f "$png" ] && { install -m644 "$png" "$SHARE/yaya-logo.png"; break; }
done

echo "==> [3/5] Config global -> /etc/fastfetch/config.jsonc"
install -Dm644 "$SRC/config.jsonc" /etc/fastfetch/config.jsonc

echo "==> [4/5] Wrapper: logo al tamaño de la terminal"
cat > /usr/local/bin/fastfetch <<'EOF'
#!/bin/sh
# Yaya OS: renderiza el alien al tamaño actual de la terminal y llama a
# /usr/bin/fastfetch. Cualquier argumento se pasa tal cual (p.ej. --logo none).
FF=/usr/bin/fastfetch
GEN=/usr/share/yaya/fastfetch/yaya-logo-gen.py
case " $* " in *" --logo"*|*" -l "*|*" --help"*|*" -h "*|*" --version"*) exec "$FF" "$@";; esac
if [ -t 1 ] && [ -f "$GEN" ] && command -v python3 >/dev/null 2>&1; then
  cols=$(stty size 2>/dev/null | awk '{print $2}'); rows=$(stty size 2>/dev/null | awk '{print $1}')
  [ "${cols:-0}" -gt 0 ] || cols=${COLUMNS:-80}; [ "${rows:-0}" -gt 0 ] || rows=${LINES:-24}
  lc=$(( cols * 38 / 100 )); lr=$(( rows - 3 ))
  [ "$lc" -gt 60 ] && lc=60; [ "$lc" -lt 12 ] && lc=12
  [ "$lr" -gt 28 ] && lr=28; [ "$lr" -lt 7 ]  && lr=7
  # el logo no debe ser más alto que la lista de módulos (~17 líneas) + margen
  [ "$lr" -gt 20 ] && lr=20
  dir="${XDG_RUNTIME_DIR:-/tmp}"; out="$dir/yaya-fastfetch-logo-$$.txt"
  if python3 "$GEN" "$lc" "$lr" "$out" 2>/dev/null; then
    "$FF" --logo-type file --logo "$out" "$@"; rc=$?; rm -f "$out"; exit $rc
  fi
fi
exec "$FF" "$@"
EOF
chmod +x /usr/local/bin/fastfetch

echo "==> [5/5] yaya-webcam -> /usr/bin; sin saludo automático en la terminal"
WEBCAM="$SELF_DIR/yaya-webcam.sh"; [ -f "$WEBCAM" ] || WEBCAM="$SRC/yaya-webcam.sh"
if [ -f "$WEBCAM" ]; then install -Dm755 "$WEBCAM" /usr/bin/yaya-webcam
else echo "   WARN: yaya-webcam.sh no encontrado; omitido"; fi
# Quitar el antiguo saludo (si existía en skel)
if [ -f /etc/skel/.bashrc ] && grep -q 'yaya-fastfetch' /etc/skel/.bashrc; then
  sed -i '/# yaya-fastfetch:/,/^fi$/d' /etc/skel/.bashrc
fi

echo "Listo. Prueba:  fastfetch    ·    yaya-webcam"
