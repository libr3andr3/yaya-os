# Yaya OS — Táctil: qué entorno de escritorio usar

Pregunta: *¿seguir con XFCE o cambiar de DE para pantallas táctiles?*
Respuesta corta según el objetivo del proyecto (hardware refurbished,
4 GB RAM, apariencia Windows 10):

| Necesidad | Recomendación |
|---|---|
| Flota **mayoritariamente NO táctil**, muy poca RAM | **Quedarse en XFCE** + `setup-yaya-touch.sh` para los pocos convertibles |
| Flota **mayoritariamente táctil** (2-en-1, convertibles) | **Build aparte con KDE Plasma 6 (Wayland)** |
| Máxima calidad táctil, sin importar recursos | GNOME — pero **no** encaja con 4 GB ni con el look Win10 |

## Por qué

Lo que hace que un escritorio se sienta "seamless" en táctil:

1. Teclado en pantalla que **auto-aparece** al tocar un campo de texto.
2. Gestos multitáctiles nativos (scroll, pinch-zoom, swipe de bordes).
3. **Auto-rotación** por acelerómetro.
4. Modo tablet: objetivos de toque grandes, long-press = clic derecho.

### XFCE (lo que usa Yaya hoy)
Sin historia táctil nativa. Se puede **aproximar** con piezas sueltas
(`onboard`, `iio-sensor-proxy`, `touchegg`, reglas de `libinput`) — eso
es justo lo que hace `setup-yaya-touch.sh`. Queda "usable", **no
seamless**: el teclado en pantalla no siempre aparece solo, no hay modo
tablet real. Ventaja decisiva: es el más liviano y ya está temado como
Win10. Ideal si el táctil es minoritario.

### KDE Plasma 6 — la recomendación si el táctil importa
- **Modo tablet** real, con teclado en pantalla (Maliit) que **auto-aparece**.
- Gestos y swipes de borde nativos en Wayland; auto-rotación lista de fábrica.
- Scroll cinético, long-press = clic derecho.
- Corre bien en 4 GB (idle ~500–600 MB con Plasma 6).
- **Se tematiza a Windows 10 mejor que cualquier otro** (los clones de
  Win10 más fieles usan Plasma). El trabajo estético actual se traslada
  con ventaja, no se pierde.

Trade-off: es un **segundo build**, no un simple hook. Más peso de ISO y
otra pila de temas que mantener.

### GNOME
El mejor táctil de Linux, pero pesado (idle ~1 GB, necesita GPU decente)
y difícil de disfrazar de Windows 10. Contradice el objetivo de hardware
modesto. No recomendado para Yaya.

## Recomendación operativa

Mantener **dos perfiles de imagen** desde el mismo repo:

- `yaya-xfce` (por defecto): el más liviano; táctil opcional vía
  `setup-yaya-touch.sh` para los convertibles sueltos.
- `yaya-plasma-touch`: para lotes de convertibles/2-en-1. Mismo branding
  (los assets de `branding/` y el hook `setup-yaya-branding.sh` son
  independientes del DE), mismas wallets, tema Win10 sobre Plasma.

Así una sola marca "Yaya OS" cubre ambos tipos de hardware sin cargar a
los equipos viejos con un escritorio que no necesitan.

## Cómo activar el táctil en el build XFCE actual

```bash
# En build-yaya-os, cablear el hook opcional:
cp setup-yaya-touch.sh config/hooks/live/0530-yaya-touch.hook.chroot
chmod +x config/hooks/live/0530-yaya-touch.hook.chroot
```

> Nota: no viene cableado por defecto porque en un desktop no táctil el
> teclado en pantalla puede aparecer sin querer. Actívalo solo para
> imágenes destinadas a hardware táctil.
