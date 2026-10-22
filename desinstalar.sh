#!/bin/bash
# Desfaz o tema DS1: volta os backups (.antes-ds1), o cursor e tira os atalhos. Rodar no WSL: bash desinstalar.sh
LOCAL_WIN=$(powershell.exe -NoProfile -c '$env:LOCALAPPDATA' | tr -d '\r'); LOCAL_WSL=$(wslpath -u "$LOCAL_WIN")
[ -f "$LOCAL_WSL/ThemaDS1/CursorDS1/backup.json" ] && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$LOCAL_WIN\\ThemaDS1\\CursorDS1\\restaurar.ps1" | tr -d '\r'
for f in ~/.claude/settings.json ~/.tmux.conf "$LOCAL_WSL"/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json; do
    [ -f "$f.antes-ds1" ] && mv "$f.antes-ds1" "$f" && echo "voltou $f"
done
powershell.exe -NoProfile -c "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | ? { \$_.CommandLine -like '*PetSolaire\\pet.ps1*' } | % { Stop-Process -Id \$_.ProcessId -Force }; Remove-Item ([Environment]::GetFolderPath('Startup') + '\\PetSolaire.lnk'), ([Environment]::GetFolderPath('Startup') + '\\Fogueira DS1.lnk'), ([Environment]::GetFolderPath('Desktop') + '\\Claude DS1.lnk') -ErrorAction SilentlyContinue" 2>/dev/null
[ -f "$LOCAL_WSL/ThemaDS1/meu_dash.json" ] && cp "$LOCAL_WSL/ThemaDS1/meu_dash.json" ~/meu_dash.json && echo "guardei a ligação com o seu dash em ~/meu_dash.json"
rm -rf "$LOCAL_WSL/ThemaDS1" "$LOCAL_WSL/PetSolaire" ~/.config/thema-ds1 ~/.claude/statusline-ds1.py
for f in barra claude_fechar claude_painel.py claude_status.py fogueira lembrete limites painel solaire_aviso solaire_claude tmux_hud; do rm -f ~/bin/$f; done
tmux source-file ~/.tmux.conf 2>/dev/null
echo "Tema DS1 removido. As fontes ficaram instaladas (não atrapalham)."
