#!/usr/bin/env python3
"""Coletor do painel de sessoes do Claude: junta o registro do Claude Code (~/.claude/sessions/<pid>.json, so as vivas),
o status dos hooks (~/.claude/status/<sid>.json, gravado por claude_status.py), os processos filhos de cada sessao
e as barras de progresso que ela abriu. Imprime 1 linha JSON por segundo (--loop) ou uma vez.
Nomes personalizados: ~/.claude/status/nomes.json {session_id: nome} (o painel grava ao renomear)."""
import subprocess, json, os, sys, time, glob, re

H = os.path.expanduser("~/.claude")
TCK = os.sysconf("SC_CLK_TCK")
IGNORA = ("claude_status.py", "statusline.py", "claude_painel.py", "-mcp")
MEU_DASH = "__LOCALAPPDATA_WSL__/ThemaDS1/meu_dash.json"   # opcional: "painel": [{titulo, progresso}] (ver README, "Ligar o seu dash")

def caminho_wsl(c):
    """C:\\pasta\\arq.txt -> /mnt/c/pasta/arq.txt (caminhos do WSL passam direto)"""
    m = re.match(r"^([A-Za-z]):[\\/](.*)$", c)
    return f"/mnt/{m.group(1).lower()}/" + m.group(2).replace("\\", "/") if m else c

def tarefas_dash():
    try: itens = json.load(open(MEU_DASH, encoding="utf-8-sig")).get("painel") or []
    except Exception: return {}
    return {caminho_wsl(x["progresso"]): {"titulo": x.get("titulo", ""), "desde": 0} for x in itens if isinstance(x, dict) and x.get("progresso")}

def boot():
    return time.time() - float(open("/proc/uptime").read().split()[0])

def procs():
    """pid -> (ppid, inicio_epoch, nome, cmdline)"""
    b, out = boot(), {}
    for d in os.listdir("/proc"):
        if not d.isdigit(): continue
        try:
            st = open(f"/proc/{d}/stat").read(); r = st.rsplit(")", 1)[1].split()
            cmd = open(f"/proc/{d}/cmdline", "rb").read().replace(b"\0", b" ").decode("utf-8", "ignore").strip()
            out[int(d)] = (int(r[1]), b + int(r[19]) / TCK, st[st.index("(") + 1: st.rindex(")")], cmd, r[19])
        except (OSError, IndexError, ValueError):
            pass
    return out

def resumo_cmd(nome, cmd):
    c = cmd.replace(os.path.expanduser("~"), "~")
    if "blender" in nome or "blender" in c:
        m = re.search(r"-P\s+(\S+)", c); return f"Blender {os.path.basename(m.group(1)) if m else ''}".strip()
    m = re.search(r"(?:^|/)(?:bash|sh)\s+(\S+\.sh)", c)
    if m: return f"Script {os.path.basename(m.group(1))}"
    m = re.search(r"python3?\s+(?:-\S+\s+)*(\S+\.py)", c)
    if m: return f"Python {os.path.basename(m.group(1))}"
    return (c or nome)[:70]

def le_tarefa(arq):
    try:
        lin = open(arq).read().strip().splitlines()[-1].strip(); mt = os.path.getmtime(arq)
    except (OSError, IndexError):
        return None
    m = re.match(r"^(FIM|ERRO)\s*(.*)$", lin)
    if m: return {"fim": m.group(1), "texto": m.group(2), "mtime": mt}
    m = re.match(r"^(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*(.*)$", lin)
    if m: return {"q": float(m.group(1)), "total": float(m.group(2)), "texto": m.group(3), "mtime": mt}
    return None

def tempo(s):
    s = int(s)
    return f"{s} s" if s < 60 else f"{s // 60} min" if s < 3600 else f"{s // 3600}h{s % 3600 // 60:02d}"

def fundo(pid, st, filhos, P, agora):
    """Comandos que a sessao deixou rodando em 2o plano (Bash run_in_background): sao os bash do shell-snapshot
    filhos diretos do Claude, menos o da ferramenta em primeiro plano. Viram tarefa sem porcentagem (total 0)."""
    out = []
    for q in filhos.get(pid, []):
        _pp, ini, nm, cmd, _s = P[q]
        if nm != "bash" or "shell-snapshots" not in cmd or agora - ini < 2: continue
        if st.get("estado") == "executando" and abs(ini - st.get("t_ferramenta", 0)) < 3: continue
        f = min(st.get("fundo") or [{}], key=lambda x: abs(x.get("desde", 0) - ini))
        desc = f.get("desc", "") if abs(f.get("desde", 0) - ini) < 5 else ""
        if not desc:
            m = re.search(r"eval '(.*)' < /dev/null", cmd, re.S); desc = re.sub(r"\s+", " ", m.group(1) if m else cmd)[:140]
        out.append({"q": 0, "total": 0, "texto": f"rodando há {tempo(agora - ini)}", "titulo": f"2º plano: {desc}",
                    "arquivo": f"bg:{q}", "desde": ini, "mtime": agora})
    return out

_solaire = None   # arquivo de progresso -> mtime do FIM/ERRO que já virou aviso no PetSolaire

def aviso_solaire(arq, titulo, t, agora):
    """tarefa em 2º plano terminou: o sol do PetSolaire aparece com o nome dela (uma vez por FIM)"""
    global _solaire
    fn = os.path.expanduser("~/.claude/status/_solaire_fim.json")
    if _solaire is None:
        try: _solaire = json.load(open(fn))
        except Exception: _solaire = {}
    if _solaire.get(arq) == t["mtime"] or agora - t["mtime"] > 120: return
    _solaire[arq] = t["mtime"]
    try:
        json.dump(_solaire, open(fn, "w"))
        subprocess.run([os.path.expanduser("~/bin/solaire_aviso"), titulo or os.path.basename(arq), t.get("texto", ""),
                        "erro" if t["fim"] == "ERRO" else "ok"], timeout=5)
    except Exception:
        pass

def le_tarefas(st, agora):
    out = []
    for arq, info in (st.get("tarefas") or {}).items():
        t = le_tarefa(arq)
        if not t: continue
        if t.get("fim") and agora - t["mtime"] > 600: continue                    # acabou faz tempo
        if t.get("fim"): aviso_solaire(arq, info.get("titulo", ""), t, agora)
        if not t.get("fim") and agora - t["mtime"] > 6 * 3600: continue            # abandonada
        out.append(dict(t, titulo=info.get("titulo", ""), arquivo=arq, desde=info.get("desde", 0)))
    return out

# ---------- tokens: soma o "usage" das respostas na transcricao (~/.claude/projects/*/<sid>.jsonl) e nas dos subagentes
# (<sid>/subagents/*.jsonl). Le so o que cresceu desde a ultima volta; a mesma resposta vem em varias linhas (mesmo id).
_tk = {}   # arquivo -> [offset, {msg_id: (entrada, cache_criado, cache_lido, saida)}]

def tokens_arquivo(arq):
    c = _tk.setdefault(arq, [0, {}])
    try:
        if os.path.getsize(arq) < c[0]: c[0], c[1] = 0, {}
        with open(arq, "rb") as fh:
            fh.seek(c[0])
            for lin in fh:
                if not lin.endswith(b"\n"): break                                  # linha ainda sendo escrita
                c[0] += len(lin)
                if b'"usage"' not in lin: continue
                try: m = json.loads(lin).get("message") or {}
                except ValueError: continue
                u = m.get("usage")
                if not u: continue
                c[1][m.get("id") or c[0]] = (u.get("input_tokens", 0), u.get("cache_creation_input_tokens", 0),
                                             u.get("cache_read_input_tokens", 0), u.get("output_tokens", 0))
    except OSError:
        pass
    return [sum(v[i] for v in c[1].values()) for i in range(4)]

def tokens(sid):
    principal = glob.glob(f"{H}/projects/*/{sid}.jsonl")
    if not principal: return None
    conv = tokens_arquivo(principal[0])
    sub = [0, 0, 0, 0]
    for a in glob.glob(f"{H}/projects/*/{sid}/subagents/*.jsonl"):
        sub = [x + y for x, y in zip(sub, tokens_arquivo(a))]
    return {"conversa": sum(conv), "subagentes": sum(sub), "total": sum(conv) + sum(sub),
            "saida": conv[3] + sub[3], "novos": conv[0] + conv[1] + sub[0] + sub[1], "cache_lido": conv[2] + sub[2]}

def nome_bonito(reg, st, nomes):
    sid = reg.get("sessionId")
    if sid in nomes: return nomes[sid]
    if reg.get("nameSource") not in (None, "derived") and reg.get("name"): return reg["name"]
    p = (st or {}).get("primeiro_prompt", "")
    if p:
        pal = re.sub(r"[^\w\sÀ-ÿ-]", " ", p).split()
        return " ".join(pal[:6])[:42] or reg.get("name", "?")
    return reg.get("name", "?")

def coleta():
    P = procs(); agora = time.time()
    try: nomes = json.load(open(f"{H}/status/nomes.json"))
    except Exception: nomes = {}
    filhos = {}
    for pid, (pp, *_r) in P.items(): filhos.setdefault(pp, []).append(pid)
    sess = []
    for fn in glob.glob(f"{H}/sessions/*.json"):
        try: reg = json.load(open(fn))
        except Exception: continue
        pid = reg.get("pid")
        if pid not in P or str(reg.get("procStart")) != P[pid][4]: continue        # morta (ou pid reaproveitado)
        sid = reg.get("sessionId")
        try: st = json.load(open(f"{H}/status/{sid}.json"))
        except Exception: st = {}
        # processos por baixo (descendentes), sem os hooks/statusline e sem shells/coisas instantaneas
        ps, pilha = [], list(filhos.get(pid, []))
        while pilha:
            q = pilha.pop(); pilha += filhos.get(q, [])
            _pp, ini, nm, cmd, _s = P[q]
            if any(i in cmd for i in IGNORA) or nm in ("bash", "sh", "sleep", "timeout", "tail", "cat", "find", "wc") or agora - ini < 2: continue
            if "claude" in nm.lower() and "python" not in nm: continue
            ps.append({"nome": resumo_cmd(nm, cmd), "seg": int(agora - ini), "pid": q})
        ps.sort(key=lambda x: -x["seg"])
        vistos = set(); ps = [x for x in ps if not (x["nome"] in vistos or vistos.add(x["nome"]))]   # subshell repetido
        tarefas = le_tarefas(st, agora) + fundo(pid, st, filhos, P, agora)
        ocupado = reg.get("status") == "busy"
        estado = st.get("estado", "pronto")
        if not ocupado and estado in ("pensando", "executando"): estado = "pronto"
        if ocupado and estado in ("pronto", "aguardando"): estado = "pensando"
        sess.append({"sid": sid, "pid": pid, "nome": nome_bonito(reg, st, nomes), "nome_cc": reg.get("name", ""),
                     "cwd": (reg.get("cwd") or "").replace(os.path.expanduser("~"), "~"), "estado": estado, "ocupado": ocupado,
                     "ferramenta": st.get("ferramenta", "") if estado == "executando" else "",
                     "detalhe": st.get("detalhe", ""), "ultimo_prompt": st.get("ultimo_prompt", ""),
                     "ultima_ferramenta": st.get("ultima_ferramenta", ""),
                     "t_ferr": st.get("t_ferramenta", 0), "msg_espera": st.get("detalhe", "") if estado == "esperando você" else "",
                     "seg_estado": int(agora - (st.get("t_ferramenta") if estado == "executando" else st.get("t", agora)) or 0),
                     "seg_sessao": int(agora - reg.get("startedAt", agora * 1000) / 1000), "processos": ps[:5], "tarefas": tarefas,
                     "tokens": tokens(sid)})
    try: av = le_tarefas(json.load(open(f"{H}/status/_avulsas.json")), agora)   # barras abertas fora de uma sessao
    except Exception: av = []
    av += le_tarefas({"tarefas": tarefas_dash()}, agora)
    if av:
        sess.append({"sid": "_avulsas", "pid": 0, "nome": "Tarefas em segundo plano", "nome_cc": "", "cwd": "", "estado": "pronto",
                     "ocupado": False, "ferramenta": "", "detalhe": "", "ultimo_prompt": "", "ultima_ferramenta": "", "t_ferr": 0,
                     "msg_espera": "", "seg_estado": 0, "seg_sessao": 0, "processos": [], "tarefas": av})
    ordem = {"esperando você": 0, "executando": 1, "pensando": 2}
    sess.sort(key=lambda s: (ordem.get(s["estado"], 3), -s["seg_sessao"]))
    return {"t": agora, "sessoes": sess}

if __name__ == "__main__":
    if "--loop" in sys.argv:
        while True:
            try: print(json.dumps(coleta(), ensure_ascii=False), flush=True)
            except BrokenPipeError: break
            except Exception as e: print(json.dumps({"erro": str(e)}), flush=True)
            time.sleep(1)
    else:
        print(json.dumps(coleta(), ensure_ascii=False, indent=1))
