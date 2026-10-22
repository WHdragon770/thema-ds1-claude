#!/usr/bin/env python3
"""Hook do Claude Code (todos os eventos): grava o que a sessao esta fazendo em ~/.claude/status/<session_id>.json,
pro painel de sessoes no Windows (Documentos\\painel_claude.ps1, coletor ~/bin/claude_painel.py). Nunca falha o hook."""
import json, os, re, sys, time

D = os.path.expanduser("~/.claude/status")

def curto(s, n=140):
    s = re.sub(r"\s+", " ", str(s or "")).strip()
    return s if len(s) <= n else s[: n - 1] + "…"

def detalhe(tool, inp):
    if not isinstance(inp, dict): return ""
    for k in ("description", "prompt", "command", "file_path", "pattern", "url", "query", "skill", "action"):
        if inp.get(k): return curto(inp[k] if k != "prompt" else inp[k].split("\n")[0], 160)
    return ""

MIN_AVISO = 20   # segundos: turno do Claude mais curto que isso não chama o Solaire

def avisar_solaire(titulo, texto):
    """aviso para o PetSolaire no Windows (ver ~/bin/solaire_aviso)"""
    d = "__LOCALAPPDATA_WSL__/PetSolaire/avisos"
    if not os.path.isdir(os.path.dirname(d)): return
    os.makedirs(d, exist_ok=True)
    nome = f"{d}/{time.time():.6f}".replace(".", "_")
    json.dump({"titulo": titulo, "texto": texto, "tipo": "ok", "t": time.time()}, open(nome + ".tmp", "w", encoding="utf-8"), ensure_ascii=False)
    os.replace(nome + ".tmp", nome + ".json")

def main():
    ev = json.load(sys.stdin)
    sid = ev.get("session_id")
    if not sid: return
    os.makedirs(D, exist_ok=True)
    fn = f"{D}/{sid}.json"
    try: st = json.load(open(fn))
    except Exception: st = {"tarefas": {}}
    nome = ev.get("hook_event_name", "")
    agora = time.time()
    st.update(session_id=sid, cwd=ev.get("cwd", st.get("cwd")), evento=nome, t=agora)
    if nome == "SessionStart":
        st.update(estado="aguardando", detalhe="sessão aberta", ferramenta="")
    elif nome == "UserPromptSubmit":
        p = curto(ev.get("prompt", ""), 200)
        st.setdefault("primeiro_prompt", p); st.update(estado="pensando", ultimo_prompt=p, ferramenta="", detalhe="", desde=agora)
    elif nome == "PreToolUse":
        tool, inp = ev.get("tool_name", ""), ev.get("tool_input", {})
        st.update(estado="executando", ferramenta=tool, detalhe=detalhe(tool, inp), t_ferramenta=agora)
        cmd = inp.get("command", "") if isinstance(inp, dict) else ""
        m = re.search(r"(?:^|&&|;)\s*cd\s+(\S+)", cmd)                    # "cd pasta && barra ..." muda a base
        base = os.path.expanduser(m.group(1)) if m else ev.get("cwd", "")
        for tit, arq in re.findall(r'barra\s+"([^"]+)"\s+(\S+)', cmd):   # barra de progresso aberta pela sessao
            if "$" in arq: continue                                          # variavel de script, nao caminho
            arq = os.path.expanduser(arq)
            if not arq.startswith("/"): arq = os.path.normpath(os.path.join(base, arq))
            st["tarefas"][arq] = {"titulo": tit, "desde": agora}
        if isinstance(inp, dict) and inp.get("run_in_background"):
            st.setdefault("fundo", []).append({"desc": detalhe(tool, inp), "desde": agora}); st["fundo"] = st["fundo"][-6:]
    elif nome in ("PostToolUse", "PostToolUseFailure"):
        st.update(estado="pensando", ferramenta="", ultima_ferramenta=f"{ev.get('tool_name', '')}: {st.get('detalhe', '')}")
    elif nome == "Notification":
        st.update(estado="esperando você", detalhe=curto(ev.get("message", ""), 160), ferramenta="")
    elif nome == "Stop":
        st.update(estado="pronto", ferramenta="", detalhe="", fim_turno=agora)
        if agora - st.get("desde", agora) >= MIN_AVISO:                    # turno longo terminou: avisa o PetSolaire
            try:
                nomes = json.load(open(f"{D}/nomes.json", encoding="utf-8-sig"))
            except Exception:
                nomes = {}
            avisar_solaire(nomes.get(sid) or curto(st.get("primeiro_prompt", "Claude"), 60), curto(st.get("ultimo_prompt", ""), 120))
    elif nome == "SessionEnd":
        st.update(estado="fechado")
    tmp = fn + ".tmp"
    json.dump(st, open(tmp, "w"), ensure_ascii=False); os.replace(tmp, fn)

if __name__ == "__main__":
    try: main()
    except Exception: pass
