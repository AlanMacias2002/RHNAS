#!/bin/bash
# =============================================================================
# cleanup_except_endofmonth.sh
# Descripción : Quita el bit de inmutabilidad y elimina archivos de un
#               directorio, conservando únicamente los generados el último
#               día de cada mes (28/29/30/31 según corresponda).
#               Opcionalmente acepta una fecha límite (--fecha): sólo procesa
#               archivos con fecha de modificación ESTRICTAMENTE ANTERIOR a
#               dicha fecha (la fecha límite queda excluida).
# Compatible  : RHEL 7 / 8 / 9 (bash 4+)
# Uso         : ./cleanup_except_endofmonth.sh -d <directorio>
#                   [--fecha YYYY-MM-DD] [--dry-run]
# =============================================================================

set -euo pipefail

# ─── Colores ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Valores por defecto ──────────────────────────────────────────────────────
TARGET_DIR=""
DRY_RUN=false
LIMIT_DATE=""          # YYYY-MM-DD  (vacío = sin límite, procesa todo)
LIMIT_EPOCH=""         # segundos epoch de la fecha límite

# ─── Ayuda ───────────────────────────────────────────────────────────────────
usage() {
    echo -e "${BOLD}Uso:${NC}"
    echo "  $0 -d <directorio> [--fecha YYYY-MM-DD] [--dry-run]"
    echo ""
    echo -e "${BOLD}Opciones:${NC}"
    echo "  -d  <directorio>       Directorio objetivo (obligatorio)"
    echo "  --fecha YYYY-MM-DD     Fecha límite: procesa archivos con fecha de"
    echo "                         modificación ANTERIOR a este día (excluido)."
    echo "                         Formato: año-mes-día  ej. 2024-06-15"
    echo "  --dry-run              Simula la ejecución sin eliminar nada"
    echo "  -h                     Muestra esta ayuda"
    echo ""
    echo -e "${BOLD}Ejemplos:${NC}"
    echo "  # Procesar todo el directorio"
    echo "  $0 -d /data/logs"
    echo ""
    echo "  # Solo archivos anteriores al 2024-06-15 (ese día NO se toca)"
    echo "  $0 -d /data/logs --fecha 2024-06-15"
    echo ""
    echo "  # Igual pero en modo simulación"
    echo "  $0 -d /data/logs --fecha 2024-06-15 --dry-run"
    exit 0
}

# ─── Parseo de argumentos ─────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d)
            TARGET_DIR="$2"
            shift 2
            ;;
        --fecha)
            LIMIT_DATE="$2"
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

# ─── Validaciones ─────────────────────────────────────────────────────────────
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

# Validar y convertir la fecha límite si se proporcionó
if [[ -n "$LIMIT_DATE" ]]; then
    # Formato esperado: YYYY-MM-DD
    if ! [[ "$LIMIT_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo -e "${RED}ERROR: Formato de fecha inválido '${LIMIT_DATE}'. Usa YYYY-MM-DD  ej. 2024-06-15${NC}" >&2
        exit 1
    fi

    # Verificar que la fecha es real (date la rechazará si no lo es)
    if ! LIMIT_EPOCH=$(date -d "$LIMIT_DATE" +%s 2>/dev/null); then
        echo -e "${RED}ERROR: La fecha '${LIMIT_DATE}' no es una fecha válida.${NC}" >&2
        exit 1
    fi
fi

# ─── Función: último día del mes ──────────────────────────────────────────────
get_last_day_of_month() {
    local year="$1"
    local month="$2"
    date -d "${year}-${month}-01 +1 month -1 day" +%d
}

# ─── Función: ¿el archivo cae dentro del rango a procesar? ───────────────────
# Devuelve 0 (true)  → el archivo ENTRA en el rango de procesamiento
# Devuelve 1 (false) → el archivo queda fuera (fecha >= límite) → se ignora
is_within_range() {
    local filepath="$1"

    # Sin fecha límite: todos los archivos entran
    [[ -z "$LIMIT_DATE" ]] && return 0

    local file_epoch
    file_epoch=$(stat --format="%Y" "$filepath")   # mtime en epoch

    # Estrictamente anterior al límite (la fecha límite queda excluida)
    if [[ $file_epoch -lt $LIMIT_EPOCH ]]; then
        return 0
    else
        return 1
    fi
}

# ─── Función: ¿el archivo es de fin de mes? ───────────────────────────────────
is_end_of_month() {
    local filepath="$1"

    local file_date
    file_date=$(stat --format="%y" "$filepath" | cut -d' ' -f1)   # YYYY-MM-DD

    local year month day
    year=$(echo  "$file_date" | cut -d'-' -f1)
    month=$(echo "$file_date" | cut -d'-' -f2)
    day=$(echo   "$file_date" | cut -d'-' -f3)

    local last_day
    last_day=$(get_last_day_of_month "$year" "$month")

    if [[ $((10#$day)) -eq $((10#$last_day)) ]]; then
        return 0   # Es fin de mes → conservar
    else
        return 1   # No es fin de mes → candidato a eliminar
    fi
}

# ─── Cabecera ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║       LIMPIEZA DE ARCHIVOS - FIN DE MES              ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo -e "  Directorio  : ${BOLD}$TARGET_DIR${NC}"
echo -e "  Modo        : $(${DRY_RUN} && echo -e "${YELLOW}${BOLD}DRY-RUN (simulación)${NC}" || echo -e "${RED}${BOLD}EJECUCIÓN REAL${NC}")"
if [[ -n "$LIMIT_DATE" ]]; then
    echo -e "  Fecha límite: ${BOLD}${LIMIT_DATE}${NC} ${CYAN}(archivos con mtime < ${LIMIT_DATE})${NC}"
else
    echo -e "  Fecha límite: ${CYAN}(sin límite — se procesan todos los archivos)${NC}"
fi
echo -e "  Timestamp   : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ─── Clasificación de archivos ────────────────────────────────────────────────
TO_DELETE=()    # dentro del rango y NO son fin de mes
TO_KEEP=()      # dentro del rango y SÍ son fin de mes
OUT_OF_RANGE=() # fuera del rango (fecha >= límite) → no se tocan

while IFS= read -r -d '' filepath; do
    if ! is_within_range "$filepath"; then
        OUT_OF_RANGE+=("$filepath")
    elif is_end_of_month "$filepath"; then
        TO_KEEP+=("$filepath")
    else
        TO_DELETE+=("$filepath")
    fi
done < <(find "$TARGET_DIR" -maxdepth 1 -type f -print0)

# ─── Archivos fuera del rango (informativos) ──────────────────────────────────
if [[ -n "$LIMIT_DATE" && ${#OUT_OF_RANGE[@]} -gt 0 ]]; then
    echo -e "${BOLD}── Archivos ignorados (fecha >= ${LIMIT_DATE}) ───────────────${NC}"
    for filepath in "${OUT_OF_RANGE[@]}"; do
        file_date=$(stat --format="%y" "$filepath" | cut -d' ' -f1)
        echo -e "  ${CYAN}[IGNORADO]${NC} $(basename "$filepath")  ${CYAN}(mtime: ${file_date})${NC}"
    done
    echo ""
fi

# ─── Archivos a ELIMINAR ──────────────────────────────────────────────────────
echo -e "${BOLD}── Archivos a eliminar ──────────────────────────────────${NC}"

if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}No hay archivos candidatos a eliminar en el rango.${NC}"
else
    for filepath in "${TO_DELETE[@]}"; do
        filename=$(basename "$filepath")

        if $DRY_RUN; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Se eliminaría → $filename"
        else
            # 1. Quitar bit de inmutabilidad
            chattr -i "$filepath" 2>/dev/null || true

            # 2. Eliminar
            if rm -f "$filepath"; then
                echo -e "  ${RED}[ELIMINADO]${NC} $filename"
            else
                echo -e "  ${RED}[ERROR]${NC} No se pudo eliminar: $filename" >&2
            fi
        fi
    done
fi

echo ""

# ─── Archivos CONSERVADOS (fin de mes dentro del rango) ───────────────────────
echo -e "${BOLD}── Archivos que NO se eliminan (fin de mes en rango) ────${NC}"

if [[ ${#TO_KEEP[@]} -eq 0 ]]; then
    echo -e "  ${CYAN}Ningún archivo en el rango corresponde a fin de mes.${NC}"
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

# ─── Resumen final ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                    RESUMEN FINAL                    ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
TOTAL_ANALYZED=$(( ${#TO_DELETE[@]} + ${#TO_KEEP[@]} + ${#OUT_OF_RANGE[@]} ))
echo -e "  Archivos totales     : ${TOTAL_ANALYZED}"
echo -e "  ${CYAN}Fuera del rango      : ${#OUT_OF_RANGE[@]}${NC}"
echo -e "  ${RED}Eliminados / a elim. : ${#TO_DELETE[@]}${NC}"
echo -e "  ${GREEN}Conservados          : ${#TO_KEEP[@]}${NC}"

if $DRY_RUN; then
    echo ""
    echo -e "  ${YELLOW}${BOLD}★  DRY-RUN completado. No se eliminó ningún archivo.${NC}"
    echo ""
    echo -e "  ${BOLD}Archivos que NO se van a eliminar:${NC}"

    if [[ ${#TO_KEEP[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}  → Por ser fin de mes (dentro del rango):${NC}"
        for filepath in "${TO_KEEP[@]}"; do
            file_date=$(stat --format="%y" "$filepath" | cut -d' ' -f1)
            echo -e "      ${GREEN}$(basename "$filepath")${NC}  ${CYAN}(mtime: ${file_date})${NC}"
        done
    fi

    if [[ ${#OUT_OF_RANGE[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}  → Por estar fuera del rango (mtime >= ${LIMIT_DATE:-N/A}):${NC}"
        for filepath in "${OUT_OF_RANGE[@]}"; do
            file_date=$(stat --format="%y" "$filepath" | cut -d' ' -f1)
            echo -e "      ${CYAN}$(basename "$filepath")${NC}  ${CYAN}(mtime: ${file_date})${NC}"
        done
    fi

    if [[ ${#TO_KEEP[@]} -eq 0 && ${#OUT_OF_RANGE[@]} -eq 0 ]]; then
        echo -e "    (ninguno)"
    fi
fi

echo ""
exit 0
