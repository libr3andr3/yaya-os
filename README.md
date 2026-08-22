# Yaya OS — XFCE Windows 10 Kit

XFCE configurado para verse y comportarse como Windows 10, con **identidad
de marca Yaya completa** (arranque, greeter, wallpaper, os-release).
Pensado para hardware refurbished (funciona bien en 4GB RAM) y para
integrarse a una ISO Debian con `live-build`.

## Contenido

```
setup-yaya-win10.sh          # apariencia Win10 (tema GTK, iconos, panel)
setup-yaya-branding.sh       # BRANDING DE ARRANQUE: os-release, hostname,
                             #   splash Plymouth (lockup), logo del SO (alien)
setup-yaya-wallets.sh        # Electrum (BTC) + Feather (XMR) -> nodos yaya.cash
setup-yaya-touch.sh          # (opcional) soporte táctil para XFCE
setup-yaya-fastfetch.sh      # fastfetch con marca Yaya: alien en la terminal,
                             #   config global + saludo al abrir terminal
yaya-webcam.sh               # puente DSLR -> /dev/video42 con banner Yaya
fastfetch/                   # assets de terminal
  config.jsonc               #   default del sistema (-> /etc/fastfetch)
  webcam.jsonc / -compact    #   banner del dashboard de yaya-webcam
  yaya-logo*.txt             #   alien ASCII fijo (fallback)
  yaya-logo-gen.py           #   re-renderiza el alien al tamaño de terminal
branding/                    # marca REAL vectorizada (Yaya Tech), SVG puro
  yaya-logo.svg              #   alien solo (logo del SO)
  yaya-logo-full.svg         #   lockup alien + "Yaya Tech" (transparente)
  yaya-boot-1920x1080.svg    #   splash de arranque GRUB (negro + lockup)
  yaya-boot-640x480.svg      #   splash de arranque isolinux
skel/                        # config por defecto para nuevos usuarios
  .config/xfce4/
    panel/whiskermenu-1.rc                        # menú Inicio
    xfconf/xfce-perchannel-xml/
      xfce4-panel.xml                             # panel inferior estilo Win10
      xsettings.xml                               # tema GTK + iconos + fuente
      xfwm4.xml                                   # decoración de ventanas + Aero Snap
      xfce4-keyboard-shortcuts.xml                # Super=Inicio, Win+E, Win+flechas
```

## Branding de arranque (setup-yaya-branding.sh)

El logo real de **Yaya Tech** (alien con seña de paz) fue vectorizado del
PNG original a SVG puro con VTracer — incluido el texto "Yaya Tech", que
son **trazos vectoriales, no `<text>`**: nítido a cualquier resolución y
sin depender de ninguna fuente. Aplica:

- **Identidad del sistema**: `/etc/os-release` (`LOGO=yaya-logo`),
  `/etc/lsb-release`, `hostname=yaya`, `/etc/issue`, `/etc/motd`.
- **Splash de arranque**: tema Plymouth `yaya` — el lockup completo
  (alien + "Yaya Tech") **centrado** sobre negro, escalado al tamaño de
  pantalla en tiempo de arranque (nítido en cualquier resolución).
- **Logo del SO = solo el alien**: se instala como icono `distributor-logo`
  / `start-here`, así que el botón Inicio de Whisker muestra el alien.
- **Menú de arranque** (isolinux/GRUB): mismo lockup sobre negro
  (lo pone `yaya-flash.sh`).

**No toca XFCE**: deliberadamente no cambia wallpaper, tema, panel ni
greeter — solo el arranque y la identidad del sistema. Los SVG se
rasterizan en el chroot con `rsvg-convert` (instalado y purgado por el
propio hook). Corre como hook `0520`.

### Regenerar los SVG desde el PNG original

Los assets de `branding/` ya están vectorizados y versionados. Si cambia
el logo original, se re-vectoriza con VTracer (ver el PNG fuente en
`~/Downloads/yayatech.png`). No hace falta para construir la ISO.

## Fastfetch con marca (setup-yaya-fastfetch.sh)

La "cara" de Yaya OS en la terminal: `fastfetch` muestra el alien en ASCII
junto a la info del sistema, en el verde-teal de la marca (`38;5;79`).

- **Config global**: `/etc/fastfetch/config.jsonc` — aplica a todos los
  usuarios; cualquiera la pisa con `~/.config/fastfetch/config.jsonc`.
- **Logo vivo**: `yaya-logo-gen.py` re-renderiza el alien desde
  `branding/yaya-logo.png` al tamaño exacto que se le pida (Pillow,
  resample BOX + rampa de densidad). Los `.txt` fijos son el fallback
  cuando no hay Pillow.
- **Saludo**: las terminales nuevas abren con el banner (snippet en
  `/etc/skel/.bashrc`, una vez por sesión vía `YAYA_FF_GREETED`).
- **yaya-webcam**: puente DSLR → `/dev/video42` (gphoto2 + ffmpeg +
  v4l2loopback) con el banner centrado en tmux y el contador de frames de
  ffmpeg en la barra de estado. Los deps de streaming no van en la ISO
  base; el script indica cómo instalarlos si faltan.

Hook live-build: `config/hooks/live/0535-yaya-fastfetch.hook.chroot`.

## Táctil / pantallas táctiles

Ver **[TOUCHSCREEN.md](TOUCHSCREEN.md)**. Resumen: XFCE se queda como
imagen por defecto (la más liviana) y `setup-yaya-touch.sh` le agrega
teclado en pantalla + auto-rotación + gestos para los convertibles. Para
una flota mayoritariamente táctil, la recomendación es un **build aparte
con KDE Plasma 6** (mismo branding, mejor táctil), no GNOME.

## Instalación manual (una máquina)

```bash
sudo ./setup-yaya-win10.sh
# cerrar sesión y volver a entrar
```

## Integración con live-build

```bash
# En tu árbol de live-build:
cp setup-yaya-win10.sh config/hooks/live/0500-yaya-win10.hook.chroot
chmod +x config/hooks/live/0500-yaya-win10.hook.chroot
cp -r skel config/includes.chroot/etc/skel-extra   # y ajustar ruta en el hook
# o más simple: meter skel/ directo en config/includes.chroot/etc/skel/
```

Recomendado: en producción, empaqueta el tema y los iconos como .deb
propios (yaya-theme-win10) en tu repo APT en vez de clonar de GitHub en
el hook — build reproducible y sin dependencia de red externa.

## Qué replica de Windows 10

- Panel único inferior de 40px: Inicio | tareas agrupadas | systray | volumen | reloj con fecha
- Tecla Windows abre el menú Inicio (Whisker)
- Win+E → explorador, Win+L → bloquear, Win+flechas → snap de ventanas
- Alt+Tab, Alt+F4
- Botones de ventana a la derecha (min/max/cerrar), snap al arrastrar a bordes
- Tema GTK "Windows-10" y set de iconos "Windows-10" de B00merang (GPL)

## Wallets (setup-yaya-wallets.sh)

Bitcoin y Monero preinstalados, apuntando a infraestructura Yaya por defecto:

| Moneda | Wallet | Nodo default | Por qué |
|---|---|---|---|
| BTC | Electrum | `electrum.yaya.cash:50002` (SSL) | estándar, liviano, servidor propio |
| XMR | Feather | `node.yaya.cash:18089` | ligero, Tor integrado, ideal HW modesto |

Ambas descargas se **verifican con GPG** contra las llaves de los
mantenedores y las versiones están pinneadas — actualiza deliberadamente.

### Lo que yaya.cash debe correr (lado servidor)

```
BTC:  bitcoind (full node) + Fulcrum o electrs  -> puerto 50002 SSL
XMR:  monerod con --restricted-rpc --rpc-bind-port 18089 --public-node
      (RPC restringido: nunca exponer 18081 sin restricted)
```

### Modelo de confianza (documentar al usuario)

Usar el nodo comunitario = el nodo ve tu IP y (en BTC) tus direcciones.
Es el trade-off custodial-by-default. Ambas wallets permiten cambiar a
nodo propio en Configuración — ese es el camino sovereign-by-choice.
Considera ofrecer el nodo también como hidden service (.onion): Feather
lo soporta nativo por Tor.

## Licencias — importante para distribución comercial

- Tema GTK: B00merang-Project/Windows-10 — GPL-3.0 ✔ redistribuible
- Iconos: B00merang-Artwork/Windows-10 — GPL ✔ redistribuible
- NO incluir: Segoe UI, wallpapers de Microsoft, logo de Windows.
  Este kit usa Open Sans (SIL OFL) como reemplazo de Segoe UI.
- Verifica cada asset adicional que agregues antes de meterlo a la ISO.
