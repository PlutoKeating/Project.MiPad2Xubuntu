#!/usr/bin/env bash
# 通过 WiFi adb 每分钟记录一次电池数据，用来判断是 BQ27520 电量计记错了容量还是电池老化。
# 用法: ./battery-log.sh [ip:port]   输出 logs/battery-<时间>.csv，Ctrl-C 结束
set -uo pipefail

TARGET="${1:-192.168.1.77:5555}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/logs/battery-$(date +%Y%m%d-%H%M%S).csv"
mkdir -p "$HERE/logs"

echo "time,status,capacity_pct,voltage_mV,current_mA,charge_full_mAh,online" | tee "$OUT"
while true; do
    adb connect "$TARGET" >/dev/null 2>&1
    row=$(adb -s "$TARGET" shell 'cat /sys/class/power_supply/battery/uevent; cat /sys/class/power_supply/bq2589x_charger/online' 2>/dev/null | tr -d '\r' | awk -F= '
        /STATUS=/          { st = $2 }
        /CAPACITY=/        { cap = $2 }
        /VOLTAGE_NOW=/     { v = int($2 / 1000) }
        /CURRENT_NOW=/     { i = int($2 / 1000) }
        /CHARGE_FULL=/     { cf = int($2 / 1000) }
        /^[01]$/           { on = $1 }
        END { if (st != "") printf "%s,%s,%s,%s,%s,%s", st, cap, v, i, cf, on }')
    echo "$(date +%F\ %T),${row:-unreachable}" | tee -a "$OUT"
    sleep 60
done
