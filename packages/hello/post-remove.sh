#!/bin/bash
# Remove usuário e home directory
if id "gccuser" &>/dev/null; then
    sudo userdel -r gccuser
    echo "[HOOK] post-remove: gccuser removido"
fi
