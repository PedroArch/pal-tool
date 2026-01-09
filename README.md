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

**Syntax:**
```bash
pal-tool create-prs <source_branch> [pr_title]
```

**Parameters:**
- `<source_branch>` (required): The source branch to create PRs from
- `[pr_title]` (optional): Custom title for the pull requests. If not provided, defaults to "[source_branch] PRs Script Test"

**Behavior:**
- Creates PRs to three target branches: `test`, `stage`, and `build_branch`
- Each PR title is automatically formatted as: `[source_branch][TARGET_BRANCH] pr_title`
- PR body includes a description of the merge operation
- Uses GitHub CLI (`gh`) for PR creation

**Examples:**
```bash
# Create PRs with default title
pal-tool create-prs feature-login

# Create PRs with custom title
pal-tool create-prs feature-payment "Add payment gateway integration"

# Output example:
# 🔧 Creating PR from feature-login to test with title: [feature-login][TEST] My Feature
# ✅ PR for test created successfully!
# 🔧 Creating PR from feature-login to stage with title: [feature-login][STAGE] My Feature
# ✅ PR for stage created successfully!
# 🔧 Creating PR from feature-login to build_branch with title: [feature-login][BUILD_BRANCH] My Feature
# ✅ PR for build_branch created successfully!
```

---

### 2. Branch Reconciliation

Creates a reconciliation branch and merges changes from a source branch into it.

**Syntax:**
```bash
pal-tool recon <branch_name> <base_branch>
```

**Parameters:**
- `<branch_name>` (required): The feature/source branch to merge
- `<base_branch>` (required): The base branch to reconcile with (e.g., main, develop)

**Behavior:**
1. Checks out the base branch
2. Pulls latest changes from remote
3. Creates or reuses a reconciliation branch named: `<branch_name>_rec_<base_branch>`
4. Merges the source branch into the reconciliation branch
5. Pushes the reconciliation branch to remote
6. Handles errors gracefully with automatic rollback to original branch

**Examples:**
```bash
# Reconcile feature branch with main
pal-tool recon feature-authentication main

# Reconcile hotfix with develop
pal-tool recon hotfix-bug-123 develop

# Output example:
# 🔄 Switching to branch main...
# ⬇️ Pulling latest changes from main...
# 🌱 Preparing reconciliation branch: feature-authentication_rec_main...
# 🔀 Merging branch feature-authentication into feature-authentication_rec_main...
# 📤 Pushing reconciliation branch to remote...
# ✅ Reconciliation process completed!
```

**Use Cases:**
- Resolving conflicts between feature branches and main branch
- Preparing branches for integration
- Testing merge compatibility before final merge

---

### 3. Middleware Health Check

Authenticates to middleware environments and checks the health status of configured processes.

**Syntax:**
```bash
pal-tool mw-health <DEV|TST|PRD> [-m|--max-chars <number>]
```

**Parameters:**
- `<DEV|TST|PRD>` (required): Environment to check (case-insensitive)
  - `DEV`: Development environment (mw-test-princessauto.objectedge.com)
  - `TST`: Test/Stage environment (mw-stage-princessauto.objectedge.com)
  - `PRD`: Production environment (mwprod-integration-princessauto.objectedge.com)

**Options:**
- `-m, --max-chars <number>` (optional): Maximum characters for error messages (default: 300)

**Interactive Prompts:**
- `User`: Your username for authentication
- `Password`: Your password (hidden input)
- `TOTP code`: Time-based one-time password for 2FA

**Behavior:**
1. Authenticates using Basic Auth with TOTP
2. Retrieves an access token
3. Checks the latest execution history for each configured process
4. Displays status with color-coded output:
   - ✅ **Success** (Green): Process completed successfully
   - ⏳ **Running** (Yellow): Process is currently executing
   - ❌ **Fail** (Red): Process failed with error message (truncated to 300 chars)

**Monitored Processes:**
- Brand Sync
- Catalog Sync
- Collection Sync
- Constructor.io Full Sync
- Document Sync
- Google Feed
- Inventory Full Sync
- Inventory Sync
- Organization Sync
- Pricing Sync
- Product Sync
- Label Sync

**Examples:**
```bash
# Check development environment
pal-tool mw-health dev

# Check test environment with custom error message length
pal-tool mw-health TST -m 500

# Check production environment with extended error messages
pal-tool mw-health PRD --max-chars 1000

# Output example:
# User: john.doe
# Password: ********
# TOTP code: 123456
# Fetching token... done
# ===============================================
# Middleware Process Health Check
# ===============================================
# Fetching Brand Sync... done
# Brand Sync - Success ✅
#
# Fetching Catalog Sync... done
# Catalog Sync - Running ⏳
#
# Fetching Collection Sync... done
# Collection Sync - Fail ❌
# Error: Connection timeout after 30 seconds...
#
# ===============================================
# Final Report
# ===============================================
#
# ✅ Brand Sync
# ✅ Catalog Sync
# ✅ Collection Sync
# ✅ Constructor.io Full Sync
# ✅ Document Sync
# ✅ Google Feed
# ✅ Inventory Full Sync
# ✅ Inventory Sync
# ✅ Organization Sync
# ❌ Pricing Sync
# ✅ Product Sync
# ✅ Label Sync
#
# Pricing Sync:
# Required fields missing — parentProduct and type.
#
# ===============================================
# Total: 12 | Success: 10 | Running: 0 | Failed: 1
# ===============================================
```

**Configuration:**
Process IDs are configured in [process.json](process.json) and mapped to each environment (DEV, TST, PRD).

---

### 4. Help

Display comprehensive help information about all available commands.

**Syntax:**
```bash
pal-tool help
# or
pal-tool -h
# or
pal-tool --help
```

**Output:**
- Lists all available commands
- Shows syntax for each command
- Provides usage examples

## How It Works

### Create PRs Command
The `create-prs` command automates the creation of pull requests across multiple environments:
1. Validates that a source branch is provided
2. Uses default title if custom title is not provided
3. Iterates through target branches: `test`, `stage`, and `build_branch`
4. Formats each PR title with source branch, target branch (uppercase), and custom title
5. Creates PR with formatted title and auto-generated body using GitHub CLI
6. Provides visual feedback with emojis for each step

**Key Features:**
- Batch PR creation saves time when deploying to multiple environments
- Consistent naming convention for easy tracking
- Auto-generated PR descriptions

### Reconciliation Command
The `recon` command creates a safe reconciliation branch for testing merges:
1. Validates both branch name and base branch parameters
2. Switches to the base branch and pulls latest changes
3. Checks if reconciliation branch already exists
   - If exists: switches to it and pulls latest changes
   - If not: creates new branch with naming pattern `<branch>_rec_<base>`
4. Merges the source branch into the reconciliation branch
5. Pushes reconciliation branch to remote
6. On any error: automatically returns to original branch

**Key Features:**
- Safe merge testing without affecting main branches
- Handles both new and existing reconciliation branches
- Comprehensive error handling with automatic cleanup
- Visual progress indicators with emojis

### Middleware Health Check
The `mw-health` command monitors middleware process execution status:
1. Validates environment parameter (DEV/TST/PRD, case-insensitive)
2. Parses optional flags for error message truncation
3. Maps environment to corresponding middleware URL
4. Prompts for credentials (username, password, TOTP code)
5. Creates Basic Auth token with TOTP
6. Authenticates to middleware API and retrieves bearer token
7. Reads process IDs from `process.json` for selected environment
8. For each configured process:
   - Queries the history endpoint for latest execution
   - Parses status from JSON response
   - Displays color-coded status with appropriate emoji
   - Shows truncated error message for failed processes
   - Tracks results for final report
9. Generates comprehensive final report with:
   - Visual summary of all processes with status icons
   - Detailed error messages for failed processes
   - Summary statistics (Total, Success, Running, Failed)
10. Uses spinner animation during API calls for better UX

**Key Features:**
- Multi-environment support (DEV, TST, PRD)
- Real-time health status for 12 different processes
- Color-coded output for quick visual scanning
- Comprehensive final report with visual summary
- Configurable error message length via `-m` or `--max-chars` flag
- Detailed error information for failed processes
- Summary statistics at the end
- Secure credential handling (password masked, TOTP required)
- Graceful error handling with informative messages
- Animated spinner for API calls

## Configuration

### process.json Structure
Process IDs are stored in `process.json` under the `DEV`, `TST`, and `PRD` keys. Each environment contains a mapping of process names to their corresponding process IDs.

**Example:**
```json
{
  "DEV": {
    "Brand Sync": 16,
    "Catalog Sync": 3180,
    "Collection Sync": 22,
    ...
  },
  "TST": { ... },
  "PRD": { ... }
}
```

**To update process IDs:**
1. Edit [process.json](process.json)
2. Update the process ID for the specific environment and process name
3. Save the file

## Error Handling

The tool includes comprehensive error handling across all commands:

### General Error Handling
- Validates required parameters before execution
- Provides clear, descriptive error messages
- Uses exit codes for scripting compatibility

### create-prs Errors
- Missing source branch parameter
- GitHub CLI authentication issues
- Network connectivity problems
- Invalid branch references

### recon Errors
- Missing required parameters (branch_name or base_branch)
- Failed git operations (checkout, pull, merge, push)
- Invalid branch names
- Merge conflicts
- **Automatic rollback**: Returns to original branch on any failure

### mw-health Errors
- Invalid environment parameter
- Missing process.json file
- Authentication failures (invalid credentials or TOTP)
- Network connectivity issues
- API response parsing errors
- Missing process IDs in configuration
- Invalid JSON responses from middleware

## Quick Reference

### Command Summary Table

| Command | Syntax | Required Args | Optional Args | Description |
|---------|--------|---------------|---------------|-------------|
| **create-prs** | `pal-tool create-prs <source> [title]` | source branch | PR title | Create PRs to test, stage, and build_branch |
| **recon** | `pal-tool recon <branch> <base>` | branch name, base branch | none | Create reconciliation branch and merge |
| **mw-health** | `pal-tool mw-health <env> [-m <num>]` | DEV/TST/PRD | -m, --max-chars | Check middleware health with report |
| **help** | `pal-tool help` | none | none | Display help information |

### Common Use Cases

**Deploy feature to all environments:**
```bash
# Create PRs for all target branches
pal-tool create-prs feature-new-api "Add new REST API endpoints"
```

**Test merge compatibility:**
```bash
# Create reconciliation branch to test merge
pal-tool recon feature-complex-changes main
```

**Monitor production health:**
```bash
# Check production middleware status
pal-tool mw-health PRD

# Check with extended error messages
pal-tool mw-health PRD -m 1000
```

**Daily workflow example:**
```bash
# 1. Check development status
pal-tool mw-health dev

# 2. Create reconciliation branch
pal-tool recon my-feature main

# 3. After resolving conflicts, create PRs
pal-tool create-prs my-feature "Implement user dashboard"

# 4. Verify test environment with detailed errors
pal-tool mw-health tst --max-chars 500
```

## Contributing

Feel free to submit issues and enhancement requests!

## MIT License

Copyright (c) 2025 Pedro Carvalho

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
