#!/bin/bash
# Para processos do gccuser antes de remover arquivos
sudo pkill -u gccuser || true
echo "[HOOK] pre-remove: processos de gccuser finalizados"
