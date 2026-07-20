#!/usr/bin/env bash
# Instalador de g15-fan-curve. Uso: sudo ./install.sh [uninstall]
set -euo pipefail

BIN=/usr/local/bin
CONFIG=/etc/g15-fancurve.json
UNIT=/etc/systemd/system/g15-fancurve.service
DESKTOP=/usr/share/applications/g15-fan-gui.desktop
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ "$(id -u)" -eq 0 ] || { echo "Ejecuta con sudo." >&2; exit 1; }

if [ "${1:-install}" = uninstall ]; then
  systemctl disable --now g15-fancurve.service 2>/dev/null || true
  rm -f "$UNIT" "$DESKTOP" "$BIN"/g15-fancurve "$BIN"/g15-fan-gui "$BIN"/g15-fan
  systemctl daemon-reload
  echo "Desinstalado. Se conservó $CONFIG (bórralo a mano si quieres)."
  echo "Los ventiladores vuelven a la curva automática de Dell en el próximo boot,"
  echo "o ya mismo con: echo 0 | tee /sys/class/hwmon/hwmon*/fan[12]_boost"
  exit 0
fi

# El daemon necesita el hwmon de alienware_wmi; sin él no hay nada que controlar.
found=""
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = alienware_wmi ] && found=$h && break
done
[ -n "$found" ] || echo "AVISO: no encontré el hwmon 'alienware_wmi'. ¿Módulo alienware-wmi cargado? El daemon no arrancará." >&2
[ -r /sys/firmware/acpi/platform_profile ] || echo "AVISO: sin /sys/firmware/acpi/platform_profile; el daemon usará siempre la curva 'balanced'." >&2

install -m 755 -o root -g root "$SRC"/g15-fancurve "$SRC"/g15-fan-gui "$SRC"/g15-fan "$BIN"/
install -m 644 -o root -g root "$SRC"/g15-fancurve.service "$UNIT"
install -m 644 -o root -g root "$SRC"/g15-fan-gui.desktop "$DESKTOP"

# El config es propiedad del usuario para que la GUI lo guarde sin sudo.
# No se pisa si ya existe: tus curvas ajustadas sobreviven a un reinstall.
if [ -e "$CONFIG" ]; then
  echo "$CONFIG ya existe, lo dejo como está."
else
  install -m 644 -o "${SUDO_USER:-root}" -g root "$SRC"/g15-fancurve.json "$CONFIG"
fi

systemctl daemon-reload
systemctl enable --now g15-fancurve.service
echo "Listo. Estado: $(systemctl is-active g15-fancurve.service)"
echo "Abre la GUI con: g15-fan-gui"
