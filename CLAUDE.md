# CLAUDE.md: Claude gateway

Guide for AI coding agents (and humans) working on this repository. Organization rules:
https://github.com/H0m3Lab/.github/blob/main/STANDARDS.md

## Purpose

One shared Claude Code (headless) container for a self-hosted setup. Apps send it jobs over a small
internal HTTP API and get text back. It keeps one workspace: the owner's rules (`decisions.md`) and its own
notes per job (`memory/`). Stackbrief's daily update review is one user; it is not specific to Stackbrief.

## Architecture

- `server.js` (Node built-ins only): `GET /health`, `POST /ask {job, input}` with bearer `GATEWAY_KEY`
  (timing-safe compare, at least 32 chars). Calls run one at a time through a promise chain. Each runs
  `claude -p --output-format json --tools Read,Write,Edit,Glob,Grep --permission-mode acceptEdits` in
  `/data/workspace`, with `jobs/<job>.md` + `<input>…</input>` on stdin, a timeout of `JOB_TIMEOUT_SEC`,
  and saves `{job, input, result}` to `/data/history/<job>/` (last `KEEP_HISTORY` kept).
- On start it creates the data folders and copies `seed/*` into the workspace if missing (never overwrites).
- `Dockerfile`: node:22-slim + pinned `@anthropic-ai/claude-code` (`CLAUDE_CODE_VERSION`), npm/npx/corepack
  removed after install, runs as `node` (uid 1000) under tini, `HOME=/data/home`, auto-updater off.
- `compose.yaml`: container and network `claude`, volume `claude-data`, `jobs/` and `decisions.md` mounted
  read-only, no ports, `cap_drop: [ALL]`, `no-new-privileges`, 2 GB memory limit.

## Repository layout

```
server.js                 the HTTP API around `claude -p`
Dockerfile                image (pinned Claude Code version)
compose.yaml              container + network `claude`
seed/CLAUDE.md            instructions copied into the workspace on first start
examples/jobs/*.md        example jobs (users copy them into jobs/)
jobs/                     the user's jobs (git-ignored, except .gitkeep)
decisions.md.example      template for the user's standing rules
set-token.sh              saves a Claude subscription token into .env without echoing it
docs/security.md          security model
```

## Commands

| Task | Command |
|---|---|
| Syntax check | `node --check server.js` |
| Lint script | `docker run --rm -v "$PWD:/m:ro" koalaman/shellcheck:v0.10.0 -S warning /m/set-token.sh` |
| Build | `docker compose build` |
| Run | `docker compose up -d` |
| Health | `docker compose exec claude node -e "fetch('http://localhost:8765/health').then(r=>r.text()).then(console.log)"` |
| Logs | `docker compose logs claude` |

CI (`.github/workflows/ci.yml`) runs the syntax check, ShellCheck, `docker compose config`, the image
build, and a gitleaks history scan. There are no unit tests yet; test changes with a real call.

## Configuration

`.env` (template `.env.example`): `GATEWAY_KEY`, `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`,
`CLAUDE_MODEL`, `JOB_TIMEOUT_SEC`, `KEEP_HISTORY`, `TZ`. When you add a setting: safe default in
`server.js`, a line in `.env.example`, the README settings table, and the CHANGELOG.

## Conventions

- `server.js` uses Node built-ins only. Do not add npm dependencies.
- Keep the API stable (`/ask` request/response fields); callers parse it. Add fields, don't rename them.
- Stay generic: nothing specific to one calling app belongs here. App-specific jobs live in that app's repo.

## Data safety (do not break)

- Never delete or overwrite the user's workspace files (`memory/`, `CLAUDE.md` once seeded) or `history/`
  beyond `KEEP_HISTORY`.

## Security (do not weaken)

- Claude gets only Read/Write/Edit/Glob/Grep in its workspace: never Bash, web tools, the Docker socket or
  host mounts. Input is untrusted (prompt injection); answers are advice that a person or app acts on.
- No published ports in `compose.yaml`; never behind a reverse proxy. Keep `cap_drop: [ALL]`,
  `no-new-privileges`, non-root user.
- Never hardcode credentials or private values; use placeholders like `example.com` / `192.0.2.10`.

## Releases

Semantic versioning. The version lives in `server.js` (`VERSION`, shown by `/health`). Steps: CHANGELOG
`[Unreleased]` → new version section, bump `VERSION`, commit, tag `vX.Y.Z`, GitHub release with the
changelog section as notes.
