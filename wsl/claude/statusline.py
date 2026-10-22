#!/usr/bin/env python3
"""Status line HUD do Dark Souls: HP (vermelha) = contexto que resta, ST (verde) = o que resta do limite de 5 h,
almas = tokens gastos na conversa (mesma conta do painel: entrada + cache + saída, subagentes inclusos).
No fim, o assunto da conversa (TEMAS) com um brilho girando enquanto o Claude trabalha.
Também grava rate_limits em ~/.claude/status/limites.json pro widget da barra de tarefas."""
import glob, json, os, re, sys, time

TEMAS = [
    ("minerando", ("miner", "minecraft", "picareta", "mine"), [
        r"  o   /|       ▓▓▓▓  ",
        r"  o_ /         ▓▓▓▓  ",
        r"  o──╼        ▓▓▓▓  ",
        r"  o──╼ *     ▓▓▓▓   ",
        r"  o\  · ✦    ▓▓▓    ",
        r"  o   /|   ◆ ▓▓▓    ",
    ]),
    ("imprimindo 3D", ("stl", "blender", "logo", "braço", "braco", "peça", "peca", "3d", "impress", "bico"), [
        r" ╔══▼═══════╗ ",
        r" ╔═══▼══════╗ ",
        r" ╔════▼═════╗ ",
        r" ╔═════▼════╗ ",
        r" ╔══════▼═══╗ ",
        r" ╔═══════▼══╗ ",
    ]),
    ("atendendo", ("atendimento", "cliente", "suporte", "mensagem", "e-mail", "email", "resposta"), [
        r"  ✉  >        ",
        r"  ✉  > .      ",
        r"  ✉  > ..     ",
        r"  ✉  > ...    ",
        r"  ✉  > ... ✓  ",
    ]),
    ("etiquetando", ("etiqueta", "zatel", "adesivo"), [
        r"  [▤▤]=       ",
        r"  [▤▤]==      ",
        r"  [▤▤]===     ",
        r"  [▤▤]====    ",
        r"  [▤▤]=====✂  ",
    ]),
    ("procurando", ("procur", "busca", "grep", "pesquis", "acha", "encontr", "search"), [
        r" (o)          ",
        r"   (o)        ",
        r"     (o)      ",
        r"       (o)    ",
        r"     (o)      ",
        r"   (o)        ",
    ]),
]
PADRAO = ("pensando", [r" ⠋ ", r" ⠙ ", r" ⠹ ", r" ⠸ ", r" ⠼ ", r" ⠴ ", r" ⠦ ", r" ⠧ ", r" ⠇ ", r" ⠏ "])


def textos(caminho, n=60):
    """texto das últimas mensagens (user + assistant) do transcript"""
    try:
        with open(caminho, "rb") as f:
            f.seek(0, 2); tam = f.tell(); f.seek(max(0, tam - 200_000))
            linhas = f.read().decode("utf-8", "ignore").splitlines()[-n:]
    except OSError:
        return ""
    out = []
    for l in linhas:
        try:
            d = json.loads(l)
        except ValueError:
            continue
        msg = d.get("message") or {}
        c = msg.get("content")
        if isinstance(c, str):
            out.append(c)
        elif isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get("type") == "text":
                    out.append(b.get("text", ""))
    return " ".join(out[-6:]).lower()


try:
    dados = json.load(sys.stdin)
except ValueError:
    dados = {}
# limites do plano (5 h e semana) pro widget da barra de tarefas (Documentos\\limites_claude.ps1)
if dados.get("rate_limits"):
    try:
        arq = os.path.expanduser("~/.claude/status/limites.json")
        with open(arq + ".tmp", "w") as f:
            json.dump({"rate_limits": dados["rate_limits"], "lido_em": int(time.time())}, f)
        os.replace(arq + ".tmp", arq)
    except OSError:
        pass
tr = dados.get("transcript_path", "")
txt = textos(tr) if tr else ""

nome, quadros = PADRAO
melhor = 0
for n, chaves, q in TEMAS:
    pontos = sum(len(re.findall(r"\b" + re.escape(k.strip()), txt)) for k in chaves)
    if pontos > melhor:
        melhor, nome, quadros = pontos, n, q

try:
    ativo = time.time() - os.path.getmtime(tr) < 8
except OSError:
    ativo = False

RST, DIM = "\033[0m", "\033[2m"
def cor(n): return f"\033[38;5;{n}m"

def barra(pct, larg, cheia, vazia=236):
    """barra fina estilo DS1: parte cheia colorida, resto escuro"""
    n = max(0, min(larg, round(larg * pct / 100)))
    return f"{cor(cheia)}{'━' * n}{cor(vazia)}{'━' * (larg - n)}{RST}"

def almas(tr, sid):
    """soma o usage das respostas lendo só o que cresceu (cache em ~/.claude/status/almas/<sid>.json)"""
    if not tr or not sid: return None
    cache = os.path.expanduser(f"~/.claude/status/almas/{sid}.json")
    arqs = [tr] + sorted(glob.glob(os.path.join(os.path.dirname(tr), sid, "subagents", "*.jsonl")))
    try: c = json.load(open(cache))
    except (OSError, ValueError): c = {}
    for a in arqs:
        e = c.setdefault(a, {"o": 0, "ids": {}})
        try:
            if os.path.getsize(a) < e["o"]: e.update(o=0, ids={})
            with open(a, "rb") as fh:
                fh.seek(e["o"])
                for lin in fh:
                    if not lin.endswith(b"\n"): break
                    e["o"] += len(lin)
                    if b'"usage"' not in lin: continue
                    try: m = json.loads(lin).get("message") or {}
                    except ValueError: continue
                    u = m.get("usage")
                    if u: e["ids"][m.get("id") or str(e["o"])] = sum(u.get(k, 0) or 0 for k in
                          ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens"))
        except OSError:
            pass
    try:
        os.makedirs(os.path.dirname(cache), exist_ok=True)
        json.dump(c, open(cache + ".tmp", "w")); os.replace(cache + ".tmp", cache)
    except OSError:
        pass
    return sum(sum(e["ids"].values()) for e in c.values())

partes = []
cw = dados.get("context_window") or {}
hp = cw.get("remaining_percentage")
if hp is None and cw.get("used_percentage") is not None: hp = 100 - cw["used_percentage"]
if hp is not None:
    ch = 160 if hp > 25 else 196
    aviso = f" {cor(208)}ESTUS? /compact{RST}" if hp <= 15 else ""
    partes.append((f"{cor(ch)}HP{RST} {barra(hp, 10, ch)} {cor(ch)}{hp:.0f}%{RST}{aviso}", "contexto"))
def tempo(seg):
    seg = int(seg)
    return f"{seg // 3600}h{seg % 3600 // 60:02d}" if seg >= 3600 else f"{seg // 60}m{seg % 60:02d}s" if seg >= 60 else f"{seg}s"

# ST = duração do turno: enche enquanto o Claude trabalha no pedido (cheia em 10 min, depois fica amarela) e zera no fim.
# Início/fim do turno vêm do hook (~/bin/claude_status.py grava ~/.claude/status/<sid>.json: estado, desde, fim_turno).
try: stt = json.load(open(os.path.expanduser(f"~/.claude/status/{dados.get('session_id')}.json")))
except (OSError, ValueError): stt = {}
if stt.get("desde"):
    if stt.get("estado") != "pronto":
        dur = time.time() - stt["desde"]; cs = 71 if dur < 600 else 178
        partes.append((f"{cor(cs)}ST{RST} {barra(min(100, dur / 6), 6, cs)} {cor(cs)}{tempo(dur)}{RST}", "turno"))
    else:
        ult = max(0, stt.get("fim_turno", stt["desde"]) - stt["desde"])
        partes.append((f"{cor(245)}ST{RST} {barra(0, 6, 71)} {DIM}{tempo(ult)}{RST}", "último turno"))
a = almas(tr, dados.get("session_id"))
if a is not None:
    curto = f"{a / 1e6:.1f}M".replace(".", ",") if a >= 1e6 else f"{a / 1e3:.0f}k" if a >= 1e3 else str(a)
    partes.append((f"{cor(254)}✦ {curto}{RST} {DIM}almas{RST}", "tokens"))
brilho = "✦✧·✧"[int(time.time()) % 4] if ativo else "·"
partes.append((f"{cor(214) if ativo else cor(245)}{brilho} {nome if ativo else 'descansando'}{RST}", "atividade"))
# 2ª linha: o que é cada coisa, pequeno e cinza, embaixo do começo de cada parte
vis = lambda x: len(re.sub(r"\033\[[0-9;]*m", "", x))
linha2, col = "", 0
for txt, rot in partes:
    if rot: linha2 += " " * max(1 if linha2 else 0, col - len(linha2)) + rot
    col += vis(txt) + 2
print("  ".join(t for t, _ in partes))
print(f"{DIM}{cor(242)}{linha2}{RST}")
