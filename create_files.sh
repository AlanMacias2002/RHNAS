#!/bin/bash

TEST_DIR="/tmp/veeam_test"
mkdir -p "$TEST_DIR"

# Crear archivos con distintas fechas
declare -A FILES=(
    ["full_2024-06-15.vbk"]="2024-06-15"
    ["incremental_2024-07-01.vib"]="2024-07-01"
    ["incremental_2024-08-10.vib"]="2024-08-10"
    ["metadata_2024-06-15.vbm"]="2024-11-20"
    ["full_2024-11-01.vbk"]="2024-11-01"
    ["incremental_2024-12-01.vib"]="2024-12-01"
    ["full_2025-02-01.vbk"]="2025-02-01"
    ["incremental_2025-03-01.vib"]="2025-03-01"
    ["metadata_2025-02-01.vbm"]="2025-04-10"
)

echo "Creando archivos de prueba en $TEST_DIR..."
echo ""

for FILENAME in "${!FILES[@]}"; do
    DATE="${FILES[$FILENAME]}"
    FILEPATH="$TEST_DIR/$FILENAME"

    # Crear archivo con contenido random para que ocupe algo
    dd if=/dev/urandom of="$FILEPATH" bs=1M count=$((RANDOM % 10 + 1)) 2>/dev/null

    # Asignar fecha de modificación
    touch -d "$DATE" "$FILEPATH"

    # Poner bit de inmutabilidad
    chattr +i "$FILEPATH"

    echo "  $FILEPATH  |  fecha: $DATE  |  tamaño: $(numfmt --to=iec $(stat -c %s $FILEPATH))"
done

echo ""
echo "Archivos creados. Verificando atributos:"
echo ""
lsattr "$TEST_DIR"
