#!/usr/bin/env bash

set -Eeuo pipefail

############################################
# Configuración
############################################

MC_HOME="/mnt/raid0/.minecraft"

USERNAME="${1:-Esteban}"

RAM="${2:-1536m}"

WIDTH="${3:-800}"

HEIGHT="${4:-600}"

############################################
# Variables globales
############################################

JAVA=""

FABRIC_VER=""

MC_VER=""

FABRIC_JSON=""

MC_JSON=""

MAIN_CLASS=""

NATIVES=""

CP=""

############################################
# Colores
############################################

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

############################################
# Funciones
############################################

info(){

    echo -e "${BLUE}[INFO]${NC} $*"

}

ok(){

    echo -e "${GREEN}[ OK ]${NC} $*"

}

warn(){

    echo -e "${YELLOW}[WARN]${NC} $*"

}

die(){

    echo -e "${RED}[FAIL]${NC} $*"

    exit 1

}

############################################
# Verificaciones básicas
############################################

[[ -d "$MC_HOME" ]] || die "No existe $MC_HOME"

command -v jq >/dev/null ||
die "Debe instalar jq (sudo apt install jq)"

############################################
# Buscar Java
############################################

find_java(){

    JAVA=$(command -v java || true)

    [[ -n "$JAVA" ]] ||
    die "Java no encontrado"

    ok "Java: $JAVA"

}

############################################
# Detectar Fabric
############################################

find_fabric(){

    FABRIC_VER=$(
        find "$MC_HOME/versions" \
        -maxdepth 1 \
        -type d \
        -name "fabric-loader-*" |
        sort |
        tail -1 |
        xargs basename
    )

    [[ -n "$FABRIC_VER" ]] ||
    die "No se encontró Fabric"

    FABRIC_JSON="$MC_HOME/versions/$FABRIC_VER/$FABRIC_VER.json"

    [[ -f "$FABRIC_JSON" ]] ||
    die "No existe $FABRIC_JSON"

    ok "Fabric: $FABRIC_VER"

}

############################################
# Leer JSON
############################################

load_json() {

    MC_VER=$(jq -r '.inheritsFrom' "$FABRIC_JSON")

    MAIN_CLASS=$(jq -r '.mainClass' "$FABRIC_JSON")

    MC_JSON="$MC_HOME/versions/$MC_VER/$MC_VER.json"

    ASSET_INDEX=$(
        jq -r '.assetIndex.id' "$MC_JSON"
    )

    ok "Minecraft: $MC_VER"
    ok "Assets: $ASSET_INDEX"
    ok "MainClass: $MAIN_CLASS"
}

############################################
# Agregar un JAR al classpath
############################################

add_cp() {

    local jar="$1"

    [[ -f "$jar" ]] || {
        warn "No existe: $jar"
        return
    }

    echo "ANTES: CP='$CP'"

    if [[ -z "$CP" ]]; then
        CP="$jar"
    else
        CP="$CP:$jar"
    fi

    echo "DESPUÉS: CP='$CP'"
}


############################################
# Convierte Maven GAV a ruta de JAR
############################################

gav_to_path() {

    local gav="$1"

    IFS=':' read -r group artifact version classifier <<< "$gav"

    group="${group//./\/}"

    if [[ -n "${classifier:-}" ]]; then
        echo "$group/$artifact/$version/$artifact-$version-$classifier.jar"
    else
        echo "$group/$artifact/$version/$artifact-$version.jar"
    fi
}

############################################
# Leer bibliotecas desde un JSON
############################################

read_libraries() {

    local JSON="$1"

    while read -r LIB
    do
        NAME=$(jq -r '.name' <<<"$LIB")

        REL_PATH=$(gav_to_path "$NAME")

        add_cp "$MC_HOME/libraries/$REL_PATH"

    done < <(
        jq -c '.libraries[]' "$JSON"
    )
}
############################################
# Construir classpath
############################################

build_classpath() {
    
    declare -F add_cp

    CP=""

    info "Construyendo classpath..."

    read_libraries "$MC_JSON"

    read_libraries "$FABRIC_JSON"

    add_cp "$MC_HOME/versions/$MC_VER/$MC_VER.jar"

    add_cp "$MC_HOME/versions/$FABRIC_VER/$FABRIC_VER.jar"

    [[ -n "$CP" ]] || die "No se pudo construir el classpath"

    echo "CP FINAL:"printf '%s\n' "$CP"
    
    COUNT=$(echo "$CP" | tr ':' '\n' | wc -l)

    ok "Classpath construido ($COUNT entradas)"

}

############################################
# Extraer bibliotecas nativas
############################################

prepare_natives() {

    NATIVES="$MC_HOME/versions/$FABRIC_VER/natives"

    rm -rf "$NATIVES"
    mkdir -p "$NATIVES"

    info "Extrayendo natives..."

    while read -r NAME
    do
        JAR="$MC_HOME/libraries/$(gav_to_path "$NAME")"

        [[ -f "$JAR" ]] || continue

        unzip -oq "$JAR" -d "$NATIVES"

    done < <(

        jq -r '
            .libraries[]
            | select(.name | contains(":natives-linux"))
            | .name
        ' "$MC_JSON"

    )

    ok "Natives preparadas"

}
############################################
# Ejecutar Minecraft
############################################


launch() {

    info "Iniciando Minecraft..."

    echo "JAVA=[$JAVA]"
    echo "MAIN_CLASS=[$MAIN_CLASS]"
    echo "NATIVES=[$NATIVES]"
    echo "CP entries=$(echo "$CP" | tr ':' '\n' | wc -l)"
    
    info "Iniciando Minecraft..."
    
    exec "$JAVA" \
    -Xms"$RAM" \
    -Xmx"$RAM" \
    -Djava.library.path="$NATIVES" \
    -cp "$CP" \
    "$MAIN_CLASS" \
    --gameDir "$MC_HOME" \
    --assetsDir "$MC_HOME/assets" \
    --assetIndex "$ASSET_INDEX"
    --version "$FABRIC_VER" \
    --username Player \
    --accessToken 0 \
    --userType legacy \
    --versionType release

}
############################################
# Programa
############################################

find_java
find_fabric
load_json
build_classpath
prepare_natives

echo
ok "Launcher inicializado correctamente."

launch
