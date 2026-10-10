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
REQUESTED_MC_VER="${5:-1.20.1}"

JAVA=""
MC_VER=""
MC_JSON=""
MAIN_CLASS=""
ASSET_INDEX=""
NATIVES=""
CP=""

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){ echo -e "${GREEN}[ OK ]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
die(){ echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

[[ -d "$MC_HOME" ]] || die "No existe $MC_HOME"
command -v jq >/dev/null || die "Debe instalar jq (sudo apt install jq)"
command -v unzip >/dev/null || die "Debe instalar unzip (sudo apt install unzip)"

find_java(){
    JAVA=$(command -v java || true)
    [[ -n "$JAVA" ]] || die "Java no encontrado"
    ok "Java: $JAVA"
}

load_version(){
    MC_VER="$REQUESTED_MC_VER"
    MC_JSON="$MC_HOME/versions/$MC_VER/$MC_VER.json"
    [[ -f "$MC_JSON" ]] || die "No existe la versión vanilla: $MC_JSON"

    MAIN_CLASS=$(jq -r '.mainClass // empty' "$MC_JSON")
    ASSET_INDEX=$(jq -r '.assetIndex.id // empty' "$MC_JSON")
    [[ -n "$MAIN_CLASS" ]] || die "No se encontró mainClass en $MC_JSON"
    [[ -n "$ASSET_INDEX" ]] || die "No se encontró assetIndex en $MC_JSON"

    ok "Minecraft vanilla: $MC_VER"
    ok "Assets: $ASSET_INDEX"
    ok "MainClass: $MAIN_CLASS"
}

gav_to_path(){
    local gav="$1"
    IFS=':' read -r group artifact version classifier <<< "$gav"
    group="${group//./\/}"
    if [[ -n "${classifier:-}" ]]; then
        echo "$group/$artifact/$version/$artifact-$version-$classifier.jar"
    else
        echo "$group/$artifact/$version/$artifact-$version.jar"
    fi
}

add_cp(){
    local jar="$1"
    [[ -f "$jar" ]] || { warn "No existe: $jar"; return; }
    if [[ -z "$CP" ]]; then CP="$jar"; else CP="$CP:$jar"; fi
}

read_libraries(){
    local json="$1"
    while read -r lib; do
        local name path
        name=$(jq -r '.name' <<< "$lib")
        path=$(gav_to_path "$name")
        add_cp "$MC_HOME/libraries/$path"
    done < <(jq -c '.libraries[]? | select(.rules == null or (.rules | any(.action == "allow")))' "$json")
}

build_classpath(){
    CP=""
    info "Construyendo classpath..."
    read_libraries "$MC_JSON"
    add_cp "$MC_HOME/versions/$MC_VER/$MC_VER.jar"
    [[ -n "$CP" ]] || die "No se pudo construir el classpath"
    ok "Classpath construido ($(tr ':' '\n' <<< "$CP" | wc -l) entradas)"
}

prepare_natives(){
    NATIVES="$MC_HOME/versions/$MC_VER/natives"
    rm -rf "$NATIVES"
    mkdir -p "$NATIVES"
    info "Extrayendo natives..."

    while read -r name; do
        local jar
        jar="$MC_HOME/libraries/$(gav_to_path "$name")"
        [[ -f "$jar" ]] || continue
        unzip -oq "$jar" -d "$NATIVES"
    done < <(jq -r '.libraries[]? | select(.name | contains(":natives-linux")) | .name' "$MC_JSON")

    ok "Natives preparadas"
}

launch(){
    info "Iniciando Minecraft vanilla..."
    exec "$JAVA" \
        -Xms"$RAM" \
        -Xmx"$RAM" \
        -Djava.library.path="$NATIVES" \
        -cp "$CP" \
        "$MAIN_CLASS" \
        --gameDir "$MC_HOME" \
        --assetsDir "$MC_HOME/assets" \
        --assetIndex "$ASSET_INDEX" \
        --version "$MC_VER" \
        --username "$USERNAME" \
        --accessToken 0 \
        --userType legacy \
        --versionType release \
        --width "$WIDTH" \
        --height "$HEIGHT"
}

find_java
load_version
build_classpath
prepare_natives
echo
ok "Launcher vanilla inicializado correctamente."
launch
