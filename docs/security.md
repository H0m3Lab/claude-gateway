# Security notes

## Claude has nothing that can act
Every job runs Claude Code with `--tools Read,Write,Edit,Glob,Grep`, working directory = its own
workspace in the data volume. No Bash, no web fetch, no Docker socket, no host mounts, no published ports,
all capabilities dropped, `no-new-privileges`, non-root user. The worst a hostile string in a job's input
can do is make Claude write a misleading answer, or misleading notes in its own `memory/`. So treat answers
as advice that the calling app or a person checks before acting.

## Who can call it
Only containers on the `claude` network can reach it, and every `/ask` needs
`Authorization: Bearer $GATEWAY_KEY` (at least 32 characters, compared in constant time). Every app you
give the key to can spend your AI quota and read what Claude remembers about your setup through its
answers, so give it only to apps you trust. Don't publish the port beyond `127.0.0.1`, and never put it
behind a reverse proxy.

## What leaves your network
To Anthropic: the job's instructions, its input, `decisions.md`, and whatever Claude reads from its
workspace (its notes). Don't put secrets in inputs, jobs or `decisions.md`.

## Keeping it updated
The Claude Code version is pinned with the build arg `CLAUDE_CODE_VERSION` and the auto-updater is off.
Rebuild for OS updates: `docker compose build --pull && docker compose up -d`.
