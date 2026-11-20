# Claude gateway

**Claude Code as one shared service for your self-hosted apps.** By H0m3Lab.

Run it once, as its own container. Any app on your Docker host can then send it a job over HTTP and get
text back: a daily update review ([Stackbrief](https://github.com/H0m3Lab/stackbrief)), a summary,
release-note checks, sorting or classification, a draft. It keeps one workspace with your standing rules
(`decisions.md`) and its own notes per job (`memory/`), so it learns your setup over time, across all the
apps that use it.

```
 app A ─┐                       ┌──────────── claude (container) ────────────┐
 app B ─┼─ POST /ask {job,input} │ jobs/<job>.md  +  decisions.md  +  memory/ │──► Anthropic API
 app C ─┘  Bearer GATEWAY_KEY    │ Claude Code, headless, Read/Write/Edit only│
           ◄──── {ok, text} ──── └────────────────────────────────────────────┘
```

## Install

```bash
git clone https://github.com/H0m3Lab/claude-gateway.git && cd claude-gateway
cp .env.example .env && chmod 600 .env                          # GATEWAY_KEY + an AI login
cp decisions.md.example decisions.md && chmod 644 decisions.md  # your rules; Claude reads it as a non-root user
cp examples/jobs/*.md jobs/                                     # optional example jobs
docker compose up -d --build
docker compose exec claude node -e "fetch('http://localhost:8765/health').then(r=>r.text()).then(console.log)"
```

It creates the Docker network `claude` and publishes no ports.

**AI login:** set `ANTHROPIC_API_KEY` (pay per use), or `CLAUDE_CODE_OAUTH_TOKEN` from
`claude setup-token` if you use a Claude subscription (`./set-token.sh` saves it without echoing it).
Check Anthropic's terms for your plan before using it for unattended automation.

## Use it from an app

1. Put the app on the `claude` network. In the app's compose file:
   ```yaml
   services:
     myapp:
       networks: [claude]
   networks:
     claude: {external: true}
   ```
2. Add a job: `jobs/<name>.md` holds the instructions, written like a prompt. The material to work on
   is passed separately and appears inside `<input>`. Jobs are read on every call, so no restart is
   needed. Examples are in [examples/jobs/](examples/jobs/).
3. Call it:
   ```bash
   curl -s -H "Authorization: Bearer $GATEWAY_KEY" -H 'Content-Type: application/json' \
        -d '{"job": "summarize", "input": "text to work on"}' http://claude:8765/ask
   # -> {"ok": true, "text": "...", "duration_ms": 41000, "turns": 3, "cost_usd": 0.04}
   ```
   On failure: `{"ok": false, "error": "..."}` with HTTP 400 (bad request or unknown job), 401 (bad key)
   or 502 (Claude failed or timed out).

Jobs run one at a time, in order. A call waits until its turn, so give your HTTP client a long timeout
(`JOB_TIMEOUT_SEC` + queue time).

## API

| Endpoint | Auth | Returns |
|---|---|---|
| `GET /health` | none | `{ok, version, busy, jobs, auth}` (`auth` = `api-key`, `oauth-token` or `none`) |
| `POST /ask` `{"job": "<name>", "input": "<text>"}` | `Authorization: Bearer <GATEWAY_KEY>` | `{ok, text, duration_ms, turns, cost_usd}` |

Job names: lowercase letters, digits and `-`, up to 40 characters, matching a file in `jobs/`. Input up to
about 2 MB.

## Settings (`.env`)

| Variable | Default | Meaning |
|---|---|---|
| `GATEWAY_KEY` | | shared secret for `/ask`, at least 32 characters (`openssl rand -hex 32`) |
| `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN` | | the AI login (set one) |
| `CLAUDE_MODEL` | Claude Code's default | model for every job |
| `JOB_TIMEOUT_SEC` | `900` | a job is stopped after this long |
| `KEEP_HISTORY` | `200` | calls kept per job in `history/` |
| `TZ` | | time zone for logs |

Local container changes (store data in a host folder, join an existing network, publish a port on
`127.0.0.1` for host scripts) go in `compose.override.yaml`, which is git-ignored:

```yaml
services:
  claude:
    volumes: [/srv/appdata/claude:/data]   # host folder owned by uid 1000
    networks: [apps]                       # also reachable from apps on your existing network
    ports: ["127.0.0.1:8765:8765"]         # host scripts; never expose it beyond localhost
networks:
  apps: {external: true}
```

## What Claude can do in here

Only Read, Write, Edit, Glob and Grep, inside its own workspace. It has no shell, no Docker, no network
tools and no access to the host; the container drops all capabilities. App input often contains text from
outside (package names, emails, web pages), so it's treated as possibly hostile. **Don't add tools that can
act on your systems.** Have the calling app or a person act on the answer instead.
Details: [docs/security.md](docs/security.md).

## Files

| Path | What |
|---|---|
| `jobs/*.md` | one instruction file per job (git-ignored: these are yours) |
| `decisions.md` | your standing rules, read on every job (git-ignored; template `decisions.md.example`) |
| volume `claude-data` | `home/` (Claude's login state), `workspace/` (CLAUDE.md, `memory/<job>.md`), `history/<job>/` (every call as JSON) |

## Troubleshooting

- **Every `/ask` returns 401:** `GATEWAY_KEY` is missing, shorter than 32 characters, or differs from the
  key the app sends. The log says so at startup: `docker compose logs claude`.
- **`/health` shows `"auth":"none"`:** no AI login in `.env`. Set one and `docker compose up -d`.
- **`unknown job`:** the file must be `jobs/<job>.md` with exactly that name; `/health` lists what it sees.
- **Claude can't read `decisions.md`:** it runs as uid 1000; `chmod 644 decisions.md`.
- **`decisions.md` is a directory inside the container:** the file didn't exist when the container
  started, so Docker created a folder. Remove that folder, create the file, `docker compose up -d`.
- **An app can't reach `http://claude:8765`:** the app isn't on the `claude` network (`docker network inspect claude`).
- **Calls time out:** jobs run one at a time; raise the app's HTTP timeout or `JOB_TIMEOUT_SEC`. Every
  call and its result is in `history/<job>/`.

## Releases and contributing

Versions and changes: [Releases](https://github.com/H0m3Lab/claude-gateway/releases) and
[CHANGELOG.md](CHANGELOG.md). Developer and AI-agent guide: [CLAUDE.md](CLAUDE.md). Bug reports and ideas
are welcome as issues; see the [contribution guide](https://github.com/H0m3Lab/.github/blob/main/CONTRIBUTING.md).
Report security problems privately through the **Security** tab.

## License

MIT - see [LICENSE](LICENSE). Uses [Claude Code](https://claude.com/claude-code) by Anthropic; you need
your own Anthropic account. Not affiliated with Anthropic.
