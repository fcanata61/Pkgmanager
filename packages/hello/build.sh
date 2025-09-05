#!/bin/bash
set -e

# Cores ANSI
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

highlight() { echo -e "${CYAN}$1${RESET}"; }
log_step() { echo -e "${BLUE}>>>${RESET} $1"; }
log_ok() { echo -e "[${GREEN}+${RESET}] $1"; }

. ./metadata

BUILD_DIR=$(pwd)/build
PKG_DIR=$(pwd)/pkg
rm -rf $BUILD_DIR $PKG_DIR
mkdir -p $BUILD_DIR $PKG_DIR

log_step "Baixando fonte: $(highlight $SOURCE)"
cd $BUILD_DIR
wget -c $SOURCE -O ${NAME}-${VERSION}.tar.gz

log_step "Extraindo código-fonte"
tar -xf ${NAME}-${VERSION}.tar.gz
cd ${NAME}-${VERSION}

log_step "Configurando build"
./configure --prefix=/usr

log_step "Compilando $(highlight $NAME $VERSION)"

# Barra de progresso aproximada
TOTAL=$(make -n | wc -l)
COUNT=0
make -j$(nproc) 2>&1 | while read LINE; do
    COUNT=$((COUNT+1))
    PERCENT=$((COUNT*100/TOTAL))
    BAR=$(printf "%-${PERCENT}s" "#" | tr ' ' '#')
    echo -ne "[${highlight $NAME}] ${PERCENT}% [${BAR}]\r"
done
echo -e "\n"

log_step "Instalando em diretório temporário"
make DESTDIR=$PKG_DIR install

log_step "Gerando metadados"
mkdir -p $PKG_DIR/install
echo "Package: $NAME" > $PKG_DIR/install/desc
echo "Version: $VERSION" >> $PKG_DIR/install/desc
echo "Depends: $DEPENDS" >> $PKG_DIR/install/desc

log_step "Empacotando -> repo/$(highlight ${NAME}-${VERSION}-x86_64.txz)"
cd $PKG_DIR
tar -cvJf ../../repo/${NAME}-${VERSION}-x86_64.txz .

log_ok "Pacote $(highlight $NAME $VERSION) pronto!"
