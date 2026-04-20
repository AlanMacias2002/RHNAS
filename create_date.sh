#!/bin/bash
set -euo pipefail

TARGET_DIR="./test_files"

mkdir -p "$TARGET_DIR"

echo "Creando archivos en: $TARGET_DIR"
echo ""

# ─────────────────────────────────────────
# 1. Archivos de FIN DE MES (10 archivos)
# ─────────────────────────────────────────

echo "Creando archivos de FIN DE MES..."

for i in {1..10}; do
    month=$(printf "%02d" $i)
    year=2024

    # Obtener último día del mes
    last_day=$(date -d "$year-$month-01 +1 month -1 day" +%d)

    filename="eom_${year}_${month}_${last_day}.txt"
    filepath="$TARGET_DIR/$filename"

    touch "$filepath"
    touch -d "$year-$month-$last_day 12:00:00" "$filepath"

    echo "  ✔ $filename ($year-$month-$last_day)"
done

echo ""

# ─────────────────────────────────────────
# 2. Archivos NO FIN DE MES (90 archivos)
# ─────────────────────────────────────────

echo "Creando archivos NORMALES..."

for i in {1..90}; do
    year=2024

    # Mes aleatorio (1-12)
    month=$(printf "%02d" $((RANDOM % 12 + 1)))

    # Día aleatorio (1-27 para evitar fin de mes)
    day=$(printf "%02d" $((RANDOM % 27 + 1)))

    filename="normal_${i}_${year}_${month}_${day}.txt"
    filepath="$TARGET_DIR/$filename"

    touch "$filepath"
    touch -d "$year-$month-$day 12:00:00" "$filepath"

    echo "  - $filename ($year-$month-$day)"
done

echo ""
echo "✔ Archivos creados correctamente"
echo ""

# ─────────────────────────────────────────
# Resumen rápido
# ─────────────────────────────────────────

echo "Resumen:"
echo "  Total archivos      : 100"
echo "  Fin de mes (esperados): 10"
echo "  A eliminar (esperados): 90"
