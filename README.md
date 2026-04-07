# PAL Tool

A developer workflow dashboard for managing GitHub pull requests, branch reconciliation, and middleware health checks — available as both a **local web app** and a **CLI tool**.

## Features

- **Web Dashboard** — 3-card UI at `localhost:3000` with simulated terminal output
- **Middleware Health Check** — monitor 25 processes across DEV/TST/PRD with one click
- **Create PRs** — open PRs to test, stage, and build_branch in one shot
- **Branch Reconciliation** — fix branch divergence with a guided flow
- **Copy Report** — one-click copy of the Final Report formatted for Teams
- **Streaming Output** — real-time line-by-line results in the browser
- **Auto-detect Branch** — create-prs pre-fills the current git branch

## Prerequisites

- [Node.js](https://nodejs.org/) (v18+)
- Git
- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated
- Bash

## Installation

```bash
git clone <your-repository-url>
cd pal-tool
npm install
```

### Configure credentials

```bash
cp .env.example .env
```

Edit `.env` and set your middleware credentials:

```
MW_USER=your_user@example.com
MW_PASSWORD=your_password
```

The TOTP code is entered in the UI each time you run the health check.

### Add alias (optional)

Add to `~/.bashrc` for global access:

```bash
alias pal-tool='/path/to/pal-tool/pal-tool.sh'
```

Then `source ~/.bashrc`.

## Usage

### Web Dashboard (recommended)

```bash
npm start
# or
pal-tool start
```

The browser opens automatically at `http://localhost:3000`. The dashboard has 3 cards:

| Card | What it does | Inputs |
|------|-------------|--------|
| **Middleware Health** | Check process status for an environment | TOTP code + click DEV/TST/PRD |
| **Create PRs** | Open 3 PRs (test, stage, build_branch) | Source branch (auto-filled) + optional title |
| **Reconciliation** | Fix branch divergence | Branch name + base branch |

Terminal output streams below the cards in real time. When mw-health completes, two copy buttons appear:

- **Report** — copies only the Final Report (from "Overnight Middleware..." onward) — ready to paste in Teams
- **Full** — copies the entire output

### CLI

All commands still work directly from the terminal:

```bash
# Health check (prompts for credentials interactively)
pal-tool mw-health PRD

# Create PRs
pal-tool create-prs feature-branch "My PR Title"

# Reconciliation
pal-tool recon feature-branch main

# Start web dashboard
pal-tool start

# Help
pal-tool help
```

#### mw-health options

```bash
pal-tool mw-health <DEV|TST|PRD> [-m|--max-chars <number>]
```

- `-m, --max-chars <number>` — truncate error messages (default: 300). HTML errors are always shown in full.

When run from the CLI without `MW_USER`/`MW_PASSWORD` env vars, the script prompts interactively for user, password, and TOTP.

## Configuration

### .env

| Variable | Required | Description |
|----------|----------|-------------|
| `MW_USER` | Yes | Middleware login username |
| `MW_PASSWORD` | Yes | Middleware login password |
| `PORT` | No | Web server port (default: 3000) |

### process.json

Maps process names to their IDs per environment (DEV, TST, PRD):

```json
{
  "DEV": { "Brand Sync": 16, "Catalog Sync": 3180, ... },
  "TST": { ... },
  "PRD": { ... }
}
```

Edit `process.json` to add/remove/update monitored processes.

## Project Structure

```
pal-tool/
├── pal-tool.sh          # Main CLI script (bash)
├── server.js            # Express server with SSE streaming
├── package.json         # Node.js dependencies
├── process.json         # Middleware process ID mapping
├── .env.example         # Environment variables template
├── .env                 # Your credentials (gitignored)
├── public/
│   ├── index.html       # Dashboard UI
│   ├── style.css        # Dark theme styling
│   └── app.js           # SSE client + UI logic
└── legacy/
    ├── pal-tool.sh      # Original CLI with interactive user/password/OTP auth
    └── process.json     # Process config for legacy script
```

## Legacy CLI

The original CLI script (with interactive username/password/OTP prompts) is preserved in the `legacy/` folder. It works standalone without Node.js:

```bash
cd legacy
./pal-tool.sh mw-health PRD
```

This version prompts for user, password, and TOTP code every time. Use it if you need the original behavior or can't run Node.js.

## MIT License

Copyright (c) 2025 Pedro Carvalho

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
