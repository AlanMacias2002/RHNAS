#!/bin/bash
# =============================================================================
# cleanup_except_endofmonth.sh
# Descripción : Quita el bit de inmutabilidad y elimina archivos de un
#               directorio, conservando únicamente los generados el último
#               día de cada mes (28/29/30/31 según corresponda).
# Compatible  : RHEL 7 / 8 / 9 (bash 4+)
# Uso         : ./cleanup_except_endofmonth.sh [-d <directorio>] [--dry-run]
# =============================================================================

set -euo pipefail

# ─── Colores ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Valores por defecto ─────────────────────────────────────────────────────
TARGET_DIR=""
DRY_RUN=false

# ─── Ayuda ───────────────────────────────────────────────────────────────────
usage() {
    echo -e "${BOLD}Uso:${NC}"
    echo "  $0 -d <directorio> [--dry-run]"
    echo ""
    echo -e "${BOLD}Opciones:${NC}"
    echo "  -d  <directorio>   Directorio objetivo (obligatorio)"
    echo "  --dry-run          Simula la ejecución sin eliminar nada"
    echo "  -h                 Muestra esta ayuda"
    exit 0
}

# ─── Parseo de argumentos ────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d)
            TARGET_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Opción desconocida: $1${NC}" >&2
            usage
            ;;
    esac
done

# ─── Validaciones ────────────────────────────────────────────────────────────
if [[ -z "$TARGET_DIR" ]]; then
    echo -e "${RED}ERROR: Debes especificar un directorio con -d${NC}" >&2
    usage
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${RED}ERROR: El directorio '$TARGET_DIR' no existe.${NC}" >&2
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR: Este script debe ejecutarse como root (chattr requiere privilegios).${NC}" >&2
    exit 1
fi

# ─── Función: obtener último día del mes para un archivo ─────────────────────
# Recibe año y mes del archivo y devuelve el último día válido de ese mes.
get_last_day_of_month() {
    local year="$1"
    local month="$2"
    # date -d "primer día del mes siguiente menos 1 día"
    date -d "${year}-${month}-01 +1 month -1 day" +%d
}

# ─── Función: determinar si un archivo es de fin de mes ──────────────────────
is_end_of_month() {
    local filepath="$1"

    # Fecha de modificación del archivo
    local file_date
    file_date=$(stat --format="%y" "$filepath" | cut -d' ' -f1)   # YYYY-MM-DD

    local year month day
    year=$(echo  "$file_date" | cut -d'-' -f1)
    month=$(echo "$file_date" | cut -d'-' -f2)
    day=$(echo   "$file_date" | cut -d'-' -f3)

    local last_day
    last_day=$(get_last_day_of_month "$year" "$month")

    # Comparación numérica (elimina ceros a la izquierda)
    if [[ $((10#$day)) -eq $((10#$last_day)) ]]; then
        return 0   # Es fin de mes → conservar
    else
        return 1   # No es fin de mes → candidato a eliminar
    fi
}

# ─── Cabecera ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║       LIMPIEZA DE ARCHIVOS - FIN DE MES              ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo -e "  Directorio : ${BOLD}$TARGET_DIR${NC}"
echo -e "  Modo       : $(${DRY_RUN} && echo -e "${YELLOW}${BOLD}DRY-RUN (simulación)${NC}" || echo -e "${RED}${BOLD}EJECUCIÓN REAL${NC}")"
echo -e "  Fecha      : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ─── Listas de archivos ──────────────────────────────────────────────────────
TO_DELETE=()
TO_KEEP=()

# Solo archivos (no directorios), no recursivo
while IFS= read -r -d '' filepath; do
    if is_end_of_month "$filepath"; then
        TO_KEEP+=("$filepath")
    else
        TO_DELETE+=("$filepath")
    fi
done < <(find "$TARGET_DIR" -maxdepth 1 -type f -print0)

# ─── Procesar archivos a ELIMINAR ────────────────────────────────────────────
echo -e "${BOLD}── Archivos a eliminar ──────────────────────────────────${NC}"

if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}No hay archivos candidatos a eliminar.${NC}"
else
    for filepath in "${TO_DELETE[@]}"; do
        filename=$(basename "$filepath")

        if $DRY_RUN; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Se eliminaría → $filename"
        else
            # 1. Quitar bit de inmutabilidad (ignorar error si no tenía el bit)
            chattr -i "$filepath" 2>/dev/null || true

            # 2. Eliminar el archivo
            if rm -f "$filepath"; then
                echo -e "  ${RED}[ELIMINADO]${NC} $filename"
            else
                echo -e "  ${RED}[ERROR]${NC} No se pudo eliminar: $filename" >&2
            fi
        fi
    done
fi

echo ""

# ─── Resumen de archivos CONSERVADOS ─────────────────────────────────────────
echo -e "${BOLD}── Archivos que NO se eliminan (fin de mes) ─────────────${NC}"

if [[ ${#TO_KEEP[@]} -eq 0 ]]; then
    echo -e "  ${CYAN}Ningún archivo corresponde a fin de mes.${NC}"
else
    for filepath in "${TO_KEEP[@]}"; do
        filename=$(basename "$filepath")
        file_date=$(stat --format="%y" "$filepath" | cut -d' ' -f1)
        year=$(echo  "$file_date" | cut -d'-' -f1)
        month=$(echo "$file_date" | cut -d'-' -f2)
        last_day=$(get_last_day_of_month "$year" "$month")
        echo -e "  ${GREEN}[CONSERVADO]${NC} $filename  ${CYAN}(fin de mes: ${year}-${month}-${last_day})${NC}"
    done
fi

# ─── Resumen final ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                    RESUMEN FINAL                    ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo -e "  Archivos analizados  : $((${#TO_DELETE[@]} + ${#TO_KEEP[@]}))"
echo -e "  ${RED}Eliminados / a elim. : ${#TO_DELETE[@]}${NC}"
echo -e "  ${GREEN}Conservados          : ${#TO_KEEP[@]}${NC}"

if $DRY_RUN; then
    echo ""
    echo -e "  ${YELLOW}${BOLD}★  DRY-RUN completado. No se eliminó ningún archivo.${NC}"
    echo ""
    if [[ ${#TO_KEEP[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}Archivos que NO se van a eliminar:${NC}"
        for filepath in "${TO_KEEP[@]}"; do
            echo -e "    → $(basename "$filepath")"
        done
    fi
fi

echo ""
exit 0
