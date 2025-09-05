#!/bin/bash
set -e

# Cores ANSI
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

highlight() { echo -e "${CYAN}$1${RESET}"; }
log_step() { echo -e "${BLUE}>>>${RESET} $1"; }
log_ok() { echo -e "[${GREEN}+${RESET}] $1"; }
log_warn() { echo -e "[${YELLOW}!${RESET}] $1"; }
log_err() { echo -e "[${RED}-${RESET}] $1"; }

REPO_DIR="/opt/meu-distro-pkgs/repo"
LOGDIR="/var/log/meupm"

mkdir -p $LOGDIR

update_repo() {
    log_step "Atualizando repositório Git"
    if [ -d "/opt/meu-distro-pkgs/.git" ]; then
        git -C /opt/meu-distro-pkgs pull
    else
        git clone https://github.com/seuuser/meu-distro-pkgs.git /opt/meu-distro-pkgs
    fi
    log_ok "Repositório sincronizado"
}

get_depends() {
    PKG=$1
    FILE=$(ls $REPO_DIR | grep "^$PKG" | tail -n1)
    TMPDIR=$(mktemp -d)
    tar -xJf $REPO_DIR/$FILE -C $TMPDIR ./install/desc 2>/dev/null || true
    DEPENDS=$(grep "^Depends:" $TMPDIR/install/desc | cut -d':' -f2 | tr -d ' ')
    rm -rf $TMPDIR
    echo $DEPENDS
}

install_pkg() {
    PKG=$1
    # Instalar dependências antes
    DEPS=$(get_depends $PKG)
    if [ -n "$DEPS" ]; then
        for dep in $DEPS; do
            if ! grep -qx "$dep" $LOGDIR/installed 2>/dev/null; then
                log_step "Instalando dependência $(highlight $dep) para $(highlight $PKG)"
                install_pkg $dep
            fi
        done
    fi

    FILE=$(ls $REPO_DIR | grep "^$PKG" | tail -n1)
    if [ -z "$FILE" ]; then
        log_err "Pacote $(highlight $PKG) não encontrado no repositório."
        exit 1
    fi

    log_step "Instalando pacote $(highlight $PKG)"
    TMPDIR=$(mktemp -d)

    tar -xvJf $REPO_DIR/$FILE -C / | sed "s/^/>>> /" | tee $TMPDIR/filelist

    PKGNAME=$(basename $FILE .txz)
    mv $TMPDIR/filelist $LOGDIR/$PKGNAME.files
    tar -O -xJf $REPO_DIR/$FILE ./install/desc > $LOGDIR/$PKGNAME.desc || true

    grep -qx "$PKGNAME" $LOGDIR/installed 2>/dev/null || echo $PKGNAME >> $LOGDIR/installed
    rm -rf $TMPDIR

    log_ok "Pacote $(highlight $PKGNAME) instalado"
}

remove_pkg() {
    PKG=$1
    FILELIST=$LOGDIR/$PKG.files

    if [[ ! -f $FILELIST ]]; then
        log_warn "Pacote $(highlight $PKG) não encontrado nos logs."
        return
    fi

    log_step "Removendo pacote $(highlight $PKG)"
    tac $FILELIST | while read f; do [ -f "$f" ] && rm -f "$f"; done
    tac $FILELIST | while read f; do [ -d "$f" ] && rmdir --ignore-fail-on-non-empty "$f" 2>/dev/null || true; done

    rm -f $LOGDIR/$PKG.files $LOGDIR/$PKG.desc
    sed -i "/^$PKG$/d" $LOGDIR/installed

    log_ok "Pacote $(highlight $PKG) removido"
}

upgrade_pkg() {
    PKG=$1
    FILE=$(ls $REPO_DIR | grep "^$PKG" | tail -n1)
    if [ -z "$FILE" ]; then
        log_err "Pacote $(highlight $PKG) não encontrado no repositório."
        exit 1
    fi

    NEWPKG=$(basename $FILE .txz)
    OLD=$(grep "^${NEWPKG%-*}-" $LOGDIR/installed || true)

    if [[ -n "$OLD" && "$OLD" != "$NEWPKG" ]]; then
        log_step "Atualizando $(highlight $OLD) -> $(highlight $NEWPKG)"
        remove_pkg $OLD
    fi

    install_pkg $PKG
}

list_installed() {
    log_step "Pacotes instalados:"
    cat $LOGDIR/installed | while read p; do echo ">>> $(highlight $p)"; done
}

list_available() {
    log_step "Pacotes disponíveis no repositório:"
    ls $REPO_DIR | while read p; do echo ">>> $(highlight $p)"; done
}

case $1 in
    update|up)   update_repo ;;
    install|i)   install_pkg $2 ;;
    remove|r)    remove_pkg $2 ;;
    upgrade|u)   upgrade_pkg $2 ;;
    list|ls)     list_installed ;;
    avail|a)     list_available ;;
    *) echo "Uso: $0 {update|up|install|i|remove|r|upgrade|u|list|ls|avail|a} [pacote]" ;;
esac
