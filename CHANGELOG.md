# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-19

First public release, split out of [Stackbrief](https://github.com/H0m3Lab/stackbrief) so any app can use it.

### Added
- `POST /ask {job, input}` (bearer `GATEWAY_KEY`) runs Claude Code headless with `jobs/<job>.md`;
  `GET /health` shows version, queue, jobs and login type.
- One workspace shared by all jobs: the owner's `decisions.md` (read-only) and Claude's own `memory/`.
- Claude limited to Read/Write/Edit/Glob/Grep in its workspace; no ports, all capabilities dropped.
- Call history per job, settings for model, timeout and history size.
- Example jobs (`summarize`, `release-notes`) and `set-token.sh` for subscription tokens.

[Unreleased]: https://github.com/H0m3Lab/claude-gateway/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/H0m3Lab/claude-gateway/releases/tag/v0.1.0
