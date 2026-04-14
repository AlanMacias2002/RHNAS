#!/bin/bash

BACKUP_DIR="/backup/veeam"
CUTOFF_DATE="2025-01-01"
DRY_RUN=true

echo "Buscando archivos anteriores a $CUTOFF_DATE en $BACKUP_DIR..."
echo ""

TOTAL_BYTES=0

while IFS= read -r FILE; do
    SIZE=$(stat -c %s "$FILE")
    TOTAL_BYTES=$((TOTAL_BYTES + SIZE))
    echo "  $FILE  ($(numfmt --to=iec $SIZE))"
done < <(find "$BACKUP_DIR" -type f ! -newermt "$CUTOFF_DATE" 2>/dev/null)

echo ""
echo "Espacio total a liberar: $(numfmt --to=iec $TOTAL_BYTES)"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo "Quitando inmutabilidad y borrando archivos..."
    find "$BACKUP_DIR" -type f ! -newermt "$CUTOFF_DATE" \
        -exec chattr -i {} \; \
        -exec rm -f {} \;
    echo "Listo."
else
    echo "*** DRY_RUN activo — no se borró nada. Cambia DRY_RUN=false para ejecutar. ***"
fi
