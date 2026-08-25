# Yaya OS — Táctil: lo maneja GNOME

**Decisión (2026-08-25): el escritorio es GNOME 48 sobre Wayland**, y el
soporte táctil no se configura — viene de fábrica. Este documento explica
qué da GNOME solo, qué instalamos nosotros (muy poco) y qué se perdió al
cambiar desde Plasma.

## Qué da GNOME sin tocar nada

| Necesidad táctil | GNOME 48 / Wayland |
|---|---|
| Teclado en pantalla que **auto-aparece** al tocar un campo de texto | Nativo, y se retira solo. Sin `maliit`, sin `onboard` |
| Gestos multitáctiles y swipes de borde | Nativos de mutter (3/4 dedos, overview, workspaces) |
| Auto-rotación por acelerómetro | Nativa — sólo necesita `iio-sensor-proxy` |
| Modo tablet (objetivos grandes, long-press = clic derecho) | Nativo |
| Stylus: presión, botones, mapeo por pantalla | Ajustes → Tableta gráfica |
| Scroll cinético | Nativo |

Por eso `setup-yaya-touch.sh` quedó en 20 líneas: instala
`iio-sensor-proxy` más los drivers `libinput` para la sesión X11 de
respaldo, borra cualquier override de X11 heredado de las etapas
anteriores, y deja unos defaults de touchpad en `dconf`
(`tap-to-click`, scroll natural, `disable-while-typing`). Nada más.

Ese hook **sí va cableado por defecto** en la ISO — al contrario que en la
etapa XFCE, donde había que activarlo a mano porque el teclado en pantalla
aparecía sin que nadie lo pidiera. GNOME sólo lo muestra ante input táctil
real, así que en un desktop sin pantalla táctil no molesta.

## Qué se cambió y qué costó

Las etapas anteriores (XFCE con `onboard`+`touchegg`, luego Plasma 6 con
Maliit y llamadas a KWin por DBus para fijar el touchpad en cada login)
existían para **aproximar** lo que GNOME ya trae. Ese código se borró:
no había nada que aproximar.

El costo real, y hay que decirlo: **GNOME pesa más**. En reposo ronda
800 MB – 1 GB de RAM frente a ~500–600 MB de Plasma 6 y bastante menos de
XFCE. En las máquinas de 4 GB de la flota funciona, pero es el escritorio
más exigente que ha usado el proyecto. Mitigaciones que ya están en la
imagen:

- `gnome-core` en vez del metapaquete `gnome` completo: el mismo escritorio
  sin la cola de apps duplicadas (Evolution, juegos) que ya cubrimos con
  LibreOffice/Thunderbird/VLC.
- Sin extensiones de GNOME Shell: cada una es memoria y una fuente de
  roturas en cada actualización.
- GNOME Software sin descargas en segundo plano; de la seguridad se
  encarga `unattended-upgrades`.

Si aparece un lote de máquinas por debajo de 4 GB, la salida no es
recortar GNOME sino un **perfil de imagen aparte** desde este mismo repo:
`setup-yaya-plasma.sh` sigue versionado y el branding
(`setup-yaya-branding.sh`, `branding/`) es independiente del escritorio.

## Xournal++ (retirado)

Se quitó de la ISO el 2026-08-25. Su configuración de stylus —forzar
Xwayland con `GDK_BACKEND=x11` para que los botones del lápiz llegaran—
nunca funcionó de forma fiable. Bajo GNOME el lápiz lo gestiona el
escritorio, y quien necesite tomar notas a mano lo instala desde la tienda.
`setup-yaya-apps.sh` además purga el paquete y el `.desktop` parcheado si
vienen de un build anterior.
