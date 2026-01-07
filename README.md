# PAL Tool

A powerful command-line tool for managing GitHub pull requests and branch reconciliation workflows.

## Features

- Create multiple pull requests across different target branches with a single command
- Automated branch reconciliation process
- Middleware health check with per-environment process IDs
- Simple and intuitive command-line interface
- GitHub CLI integration

## Prerequisites

- Ubuntu (tested on Ubuntu 24.04)
- Git
- GitHub CLI (gh)

## Installation

1. Install Git (if not already installed):
```bash
sudo apt update
sudo apt install git
```

2. Install GitHub CLI:
```bash
# Add GitHub CLI repository
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Update package list and install GitHub CLI
sudo apt update
sudo apt install gh
```

3. Authenticate with GitHub:
```bash
gh auth login
```
Follow the interactive prompts to complete the authentication process.

4. Clone and set up the tool:
```bash
git clone <your-repository-url>
cd pal-tool
chmod +x pal-tool.sh
```

5. Create a bash alias (optional but recommended):
```bash
# Add this line to your ~/.bashrc file
echo 'alias pal-tool="$(pwd)/pal-tool.sh"' >> ~/.bashrc

# Reload your bash configuration
source ~/.bashrc
```

Now you can use the `pal-tool` command from any directory!

## Usage

The tool provides four main commands:

### 1. Create Pull Requests

Creates pull requests from a source branch to multiple target branches (test, stage, and build_branch).

```bash
pal-tool create-prs <source_branch> [pr_title]
```

Example:
```bash
pal-tool create-prs feature-branch "My PR Title"
```

### 2. Branch Reconciliation

Creates a reconciliation branch and merges changes from a source branch into it.

```bash
pal-tool recon <branch_name> <base_branch>
```

Example:
```bash
pal-tool recon feature-branch main
```

### 3. Help

Display help information:

```bash
pal-tool help
# or
pal-tool -h
# or
pal-tool --help
```

### 4. Middleware Health Check

Authenticate, fetch the latest history for each configured process, and print a quick status list.

```bash
pal-tool mw-health <DEV|TST|PRD>
```

Example:
```bash
pal-tool mw-health dev
```

The environment argument is case-insensitive. You will be prompted for user, password, and TOTP code.

## How It Works

### Create PRs Command
- Takes a source branch and optional PR title as input
- Creates PRs to test, stage, and build_branch environments
- Automatically formats PR titles with branch information
- Uses GitHub CLI for PR creation

### Reconciliation Command
- Creates a new branch named `<branch_name>_rec_<base_branch>`
- Merges changes from the source branch into the reconciliation branch
- Handles existing reconciliation branches
- Includes error handling and rollback capabilities

### Middleware Health Check
- Reads process IDs from `process.json` based on the selected environment
- Authenticates via Basic Auth to retrieve a token
- Queries the history endpoint for each process and prints Success, Running, or Fail
- Truncates long failure messages to keep output compact

## Configuration

Process IDs are stored in `process.json` under the `DEV`, `TST`, and `PRD` keys. Update these IDs if the environment changes.

## Error Handling

The tool includes comprehensive error handling:
- Validates required parameters
- Checks Git operations success
- Provides clear error messages
- Automatically rolls back to original branch on failure

## Contributing

Feel free to submit issues and enhancement requests!

## MIT License

Copyright (c) 2025 Pedro Carvalho

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
