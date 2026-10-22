#!/bin/bash
# Instala o tema DS1 do Claude Code (Windows 10/11 + WSL). Rodar DENTRO do Ubuntu/WSL, na pasta do repositório:
#   bash instalar.sh
# Faz backup de tudo que muda (settings.json do Claude e do Windows Terminal, ~/.tmux.conf) com a extensão .antes-ds1
set -e
cd "$(dirname "$0")"
REPO=$(pwd)

command -v powershell.exe >/dev/null || { echo "Precisa rodar no WSL (não achei o powershell.exe)."; exit 1; }
command -v python3 >/dev/null || { echo "Precisa do python3 (sudo apt install python3)."; exit 1; }
command -v tmux >/dev/null || echo "Aviso: tmux não instalado (sudo apt install tmux). A barra HUD e o Claude novo pelo Solaire usam ele."

LOCAL_WIN=$(powershell.exe -NoProfile -c '$env:LOCALAPPDATA' | tr -d '\r')
LOCAL_WSL=$(wslpath -u "$LOCAL_WIN")
THEMA_WIN="$LOCAL_WIN\\ThemaDS1"; THEMA_WSL="$LOCAL_WSL/ThemaDS1"
DISTRO="${WSL_DISTRO_NAME:-Ubuntu}"
HOME_BS=$(echo "$HOME" | tr '/' '\\')
echo "Windows: $THEMA_WIN | WSL: $DISTRO $HOME"

# troca os marcadores pelos caminhos desta máquina
ajusta() {
    sed -e "s#__LOCALAPPDATA_WSL__#$LOCAL_WSL#g" -e "s#__THEMA_WIN__#$(printf '%s' "$THEMA_WIN" | sed 's/\\/\\\\/g')#g" \
        -e "s#__HOME_BS__#$(printf '%s' "$HOME_BS" | sed 's/\\/\\\\/g')#g" -e "s#__HOME__#$HOME#g" -e "s#__DISTRO__#$DISTRO#g" "$1" > "$2"
}

echo "1/7 scripts do WSL em ~/bin"
mkdir -p ~/bin ~/.claude/status ~/.config/thema-ds1
for f in wsl/bin/*; do ajusta "$f" ~/bin/"$(basename "$f")"; chmod +x ~/bin/"$(basename "$f")"; done
grep -q 'HOME/bin' ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc

echo "2/7 arquivos do Windows em $THEMA_WIN e o Solaire em $LOCAL_WIN\\PetSolaire"
mkdir -p "$THEMA_WSL" "$LOCAL_WSL/PetSolaire"
( cd windows && find . -type f ) | while read -r f; do
    src="windows/$f"; dst="$THEMA_WSL/${f#./}"
    case "$f" in ./PetSolaire/*) dst="$LOCAL_WSL/PetSolaire/${f#./PetSolaire/}";; esac
    mkdir -p "$(dirname "$dst")"
    case "$f" in *.ps1|*.bat|*.txt) ajusta "$src" "$dst";; *) cp "$src" "$dst";; esac
done

echo "3/7 fontes (Cinzel e Libertinus Mono)"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$THEMA_WIN\\instalar_fontes.ps1" | tr -d '\r'

echo "4/7 Claude Code: statusline HUD, hooks do painel/Solaire e frases do DS1"
cp wsl/claude/statusline.py ~/.claude/statusline-ds1.py
[ -f ~/.claude/settings.json ] && cp ~/.claude/settings.json ~/.claude/settings.json.antes-ds1
python3 - "$REPO/wsl/claude/settings-ds1.json" <<'PY'
import json, os, sys
p = os.path.expanduser("~/.claude/settings.json")
try: s = json.load(open(p))
except (OSError, ValueError): s = {}
ds1 = json.load(open(sys.argv[1]))
s["statusLine"] = ds1["statusLine"]
s["spinnerVerbs"] = ds1["spinnerVerbs"]
hooks = s.setdefault("hooks", {})
for ev, lista in ds1["hooks"].items():
    atual = hooks.setdefault(ev, [])
    tem = json.dumps(atual)
    for grupo in lista:
        if all(h["command"] not in tem for h in grupo["hooks"]): atual.append(grupo)
json.dump(s, open(p, "w"), indent=2, ensure_ascii=False)
PY

echo "5/7 tmux"
cp wsl/tmux-ds1.conf ~/.config/thema-ds1/tmux-ds1.conf
[ -f ~/.tmux.conf ] && cp ~/.tmux.conf ~/.tmux.conf.antes-ds1
grep -q 'thema-ds1/tmux-ds1.conf' ~/.tmux.conf 2>/dev/null || printf '\n# tema DS1\nsource-file ~/.config/thema-ds1/tmux-ds1.conf\n' >> ~/.tmux.conf
tmux source-file ~/.tmux.conf 2>/dev/null || true

echo "6/7 Windows Terminal: perfil \"Claude DS1\" (pedra + moldura + fonte serifada)"
WT=$(ls "$LOCAL_WSL"/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json 2>/dev/null | head -1)
if [ -n "$WT" ]; then
    cp "$WT" "$WT.antes-ds1"
    python3 - "$WT" "$THEMA_WIN\\TerminalDS1\\fundo_ds1.png" "$DISTRO" <<'PY'
import json, re, sys
p, fundo, distro = sys.argv[1:4]
txt = open(p, encoding="utf-8-sig").read()
txt = re.sub(r"^\s*//.*$", "", txt, flags=re.M)                    # tira comentários (o settings.json do WT aceita //)
s = json.loads(txt)
GUID = "{d5a1f0c3-0d51-4f1e-9b77-5d0a1e7f0d51}"
s["schemes"] = [x for x in s.get("schemes", []) if x.get("name") != "Dark Souls"] + [{
    "name": "Dark Souls", "background": "#161513", "foreground": "#E8E4DA", "cursorColor": "#D9A55A", "selectionBackground": "#86391A",
    "black": "#1A1816", "red": "#B0382C", "green": "#7C9A52", "yellow": "#D0A450", "blue": "#6A82A0", "purple": "#9A7298", "cyan": "#74A09C", "white": "#D8D2C4",
    "brightBlack": "#6A6458", "brightRed": "#D85A44", "brightGreen": "#9CBC6E", "brightYellow": "#F0C870", "brightBlue": "#8EA6C4", "brightPurple": "#BC94BA", "brightCyan": "#98C4BE", "brightWhite": "#F6F2E8"}]
perfil = {"guid": GUID, "name": "Claude DS1", "commandline": f"wsl.exe -d {distro} --cd ~", "hidden": False, "colorScheme": "Dark Souls",
          "font": {"face": "Libertinus Mono", "size": 13.5}, "cursorShape": "bar", "backgroundImage": fundo, "backgroundImageStretchMode": "fill",
          "backgroundImageOpacity": 1.0, "padding": "34, 30, 34, 30", "useAcrylic": False, "intenseTextStyle": "bright", "tabColor": "#2A2018"}
pr = s.setdefault("profiles", {}); lista = pr.get("list", []) if isinstance(pr, dict) else pr
lista = [x for x in lista if x.get("guid") != GUID]
if isinstance(pr, dict): pr["list"] = [perfil] + lista
else: s["profiles"] = [perfil] + lista
s["themes"] = [x for x in s.get("themes", []) if x.get("name") != "Dark Souls"] + [{
    "name": "Dark Souls", "window": {"applicationTheme": "dark"}, "tabRow": {"background": "#0E0C0AFF", "unfocusedBackground": "#0E0C0AFF"},
    "tab": {"background": "#2A2018FF", "unfocusedBackground": "#0E0C0AFF", "showCloseButton": "hover"}}]
s["theme"] = "Dark Souls"
json.dump(s, open(p, "w", encoding="utf-8"), indent=4, ensure_ascii=False)
PY
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$THEMA_WIN\\atalhos.ps1" | tr -d '\r'
else
    echo "   Windows Terminal não encontrado, pulei."
fi

echo "7/7 cursor"
read -r -p "   Trocar o cursor do mouse pelo dourado DS1 (grande, 144 px)? Dá pra voltar depois. [s/N] " r
case "$r" in s|S|sim) powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$THEMA_WIN\\CursorDS1\\aplicar.ps1" | tr -d '\r';; esac

powershell.exe -NoProfile -c "Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File','$LOCAL_WIN\\PetSolaire\\pet.ps1'"
echo
echo "Pronto! Abra o atalho \"Claude DS1\" na Área de Trabalho. O Solaire já está na barra de tarefas."
if [ -f "$THEMA_WSL/meu_dash.json" ]; then echo "Seu dash continua ligado ($THEMA_WIN\\meu_dash.json)."
elif [ -f ~/meu_dash.json ]; then cp ~/meu_dash.json "$THEMA_WSL/meu_dash.json" && echo "Religuei o seu dash (~/meu_dash.json)."
else echo "Tem um dash seu? Ligue no Solaire, na fogueira e no painel: README, \"Ligar o seu dash\"."; fi
echo "Desfazer: bash desinstalar.sh"
