#!/bin/bash
# Compile le .click arm64 depuis WSL (Clickable refuse les chemins avec espaces :
# on travaille sur une copie dans ~/devicetester) puis le copie dans dist/.
set -e
export PATH=$PATH:~/.local/bin
SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/devicetester
rsync -a --delete --exclude build --exclude .clickable --exclude dist "$SRC"/ ~/devicetester/
cd ~/devicetester
clickable build --arch arm64 --skip-review 2>&1 | grep -E "error|Error|Successfully" || true
mkdir -p "$SRC/dist"
cp build/aarch64-linux-gnu/app/devicetester.jimmy_0.1.0_arm64.click "$SRC/dist/"
ls -la --time-style=full-iso "$SRC/dist"
