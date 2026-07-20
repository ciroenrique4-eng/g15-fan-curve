# g15-fan-curve

Curvas de ventilador configurables para portátiles Dell G15, **una por modo de energía**.

Un daemon de ~75 líneas y una GUI GTK4 de ~150. Sin dependencias más allá de Python y GTK:
usa el hwmon `alienware_wmi` que ya expone el kernel, y lee el modo de energía directo de
`/sys/firmware/acpi/platform_profile` (sin dbus, sin `powerprofilesctl`).

![modo](https://img.shields.io/badge/probado_en-Dell_G15_5530-blue) ![so](https://img.shields.io/badge/SO-Linux_(CachyOS_/_Arch)-informational)

## Por qué una curva por modo

Una curva única mapea temperatura → ventilador, pero eso no captura lo que realmente
quieres: a 70 °C en batería prefieres silencio y aceptas el calor; a 70 °C jugando quieres
el ventilador arriba ya. Misma temperatura, distinta respuesta.

Así que hay tres curvas independientes, una por cada valor de `platform_profile`
(`quiet`, `balanced`, `performance`). Cambias el modo de energía por donde ya lo cambias
—GNOME, KDE, `powerprofilesctl`, el applet de tu barra— y la curva cambia con él en ≤2 s.

Ejemplo real a 52 °C fijos, cambiando sólo el modo:

| Modo de energía | `platform_profile` | boost aplicado |
|---|---|---|
| power-saver | `quiet` | 5 |
| balanced | `balanced` | 26 |
| performance | `performance` | 61 |

## Seguridad: el boost es aditivo

El daemon escribe en `fanN_boost`, que **suma** sobre la curva automática de Dell — no la
reemplaza. Consecuencia importante: si el daemon muere, si lo matas o si el config queda
corrupto, los ventiladores no se paran; el firmware sigue gobernándolos como siempre. Lo
peor que puede pasar es que pierdas el boost extra.

Por lo mismo, un boost de 0 no significa "ventiladores apagados", significa "lo que Dell
decida". No puedes dejar el equipo sin refrigeración con este programa.

## Requisitos

- Un Dell G15 (probado en el **5530**). Debería funcionar en cualquier equipo cuyo hwmon
  `alienware_wmi` exponga `fan1_boost`/`fan2_boost`; el instalador avisa si no lo encuentra.
- Linux con el módulo `alienware-wmi` cargado.
- `python3` (daemon) y `python-gobject` + `gtk4` (GUI).

En Arch/CachyOS: `sudo pacman -S python python-gobject gtk4`

## Instalación

```sh
git clone https://github.com/<tu-usuario>/g15-fan-curve
cd g15-fan-curve
sudo ./install.sh
```

Copia los tres ejecutables a `/usr/local/bin`, instala el servicio systemd y el lanzador
`.desktop`, y arranca el daemon. El config sólo se crea si no existe, así que reinstalar
nunca te pisa las curvas ajustadas.

Desinstalar: `sudo ./install.sh uninstall`

## Uso

Abre **G15 Fan Curve** desde el lanzador de aplicaciones, o `g15-fan-gui` en terminal.

- El desplegable de arriba elige qué modo estás editando; abre en el que esté activo.
- Arrastra los puntos verticalmente (el eje X está fijo en 40-90 °C). Se guarda solo al
  soltar, y el daemon lo aplica en ≤2 s — no hace falta reiniciar nada ni pulsar "guardar".
- La línea naranja marca la temperatura actual; abajo se ven temps y RPM en vivo.
- Si cambias el modo de energía con la GUI abierta, la curva en pantalla **no** se mueve
  (te la cambiaría bajo el cursor). La barra de estado lo indica con `(editando: X)`.

## Configuración

`/etc/g15-fancurve.json`, propiedad de tu usuario para que la GUI escriba sin sudo:

```json
{
 "quiet":       {"temps": [40, 50, 60, 70, 80, 90], "boost": [0, 0, 26, 77, 179, 255]},
 "balanced":    {"temps": [40, 50, 60, 70, 80, 90], "boost": [0, 13, 77, 153, 230, 255]},
 "performance": {"temps": [40, 50, 60, 70, 80, 90], "boost": [13, 38, 153, 229, 255, 255]}
}
```

Las claves son los valores literales de `platform_profile`, así que no hay tabla de
traducción que mantener. `boost` va de 0 a 255 (la GUI lo muestra como %). Entre puntos se
interpola linealmente; fuera del rango se aplica el extremo más cercano.

Si un perfil falta o el JSON no es válido, ese ciclo usa la curva `DEFAULT` del daemon en
vez de fallar. Editarlo a mano funciona: el daemon relee el archivo cada 2 s.

## Cómo funciona

`g15-fancurve` (daemon, systemd) cada 2 segundos:

1. Lee `max(CPU, GPU)` de `temp1_input`/`temp2_input` del hwmon `alienware_wmi`.
2. Lee el modo activo de `/sys/firmware/acpi/platform_profile`.
3. Interpola la curva de ese modo y escribe el resultado en `fan1_boost` y `fan2_boost`
   (sólo cuando el valor cambia).

`g15-fan` es un escape hatch para forzar los ventiladores a mano:

```sh
sudo systemctl stop g15-fancurve   # si no, el daemon lo sobrescribe en 2s
sudo g15-fan max                   # o: off, o un valor 0-255
```

## Verificar / depurar

```sh
python3 /usr/local/bin/g15-fancurve --test   # self-check de la interpolación y del parseo
systemctl status g15-fancurve
cat /sys/firmware/acpi/platform_profile      # modo que está usando el daemon
cat /sys/class/hwmon/hwmon*/fan1_boost       # boost aplicado ahora mismo
```

Si el daemon no arranca, casi siempre es que el hwmon `alienware_wmi` no existe
(`ls /sys/class/hwmon/*/name | xargs grep -l alienware` para confirmar).

## Limitaciones

- Ambos ventiladores reciben el mismo valor. El hardware permite valores distintos; no me
  ha hecho falta.
- Las temperaturas de los puntos son fijas (40-90 °C, de 10 en 10); sólo se edita el eje Y.
- Sólo probado en un G15 5530. Si lo pruebas en otro modelo, abre un issue y lo añado.

## Licencia

MIT
