#!/bin/bash
# Cria usuário gccuser se não existir
if ! id "gccuser" &>/dev/null; then
    sudo useradd -r -m gccuser
    echo "[HOOK] post-install: gccuser criado"
fi
