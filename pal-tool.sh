#!/bin/bash

# name: pal-tool
# usage:
#   ./pal-tool create-prs <source_branch> [pr_title]
#   ./pal-tool recon <branch_name> <base_branch>
#   ./pal-tool mw-health <DEV|TST|PRD> [-m|--max-chars <number>]
#   ./pal-tool help | -h | --help

COMMAND=$1

function show_help() {
    echo "Usage: pal-tool {create-prs|recon|mw-health|help} ..."
    echo
    echo "Commands:"
    echo "  create-prs <source_branch> [pr_title]              Create pull requests for multiple target branches."
    echo "  recon <branch_name> <base_branch>                  Create a reconciliation branch and merge changes."
    echo "  mw-health <DEV|TST|PRD> [-m|--max-chars <number>]  Check middleware health and print report."
    echo "  help | -h | --help                                 Show this help message."
    echo
    echo "Options for mw-health:"
    echo "  -m, --max-chars <number>    Maximum characters for error messages (default: 300)"
    echo
    echo "Examples:"
    echo "  pal-tool create-prs feature-branch 'My PR Title'"
    echo "  pal-tool recon feature-branch main"
    echo "  pal-tool mw-health DEV"
    echo "  pal-tool mw-health TST -m 500"
    echo "  pal-tool mw-health PRD --max-chars 1000"
    echo "  pal-tool help"
}

function create_prs() {
    SOURCE_BRANCH="$1"
    PR_TITLE="$2"

    if [ -z "$SOURCE_BRANCH" ]; then
        echo "Error: Source branch name not provided."
        echo "Usage: pal-tool create-prs <source_branch> [pr_title]"
        exit 1
    fi

    if [ -z "$PR_TITLE" ]; then
        PR_TITLE="[${SOURCE_BRANCH}] PRs Script Test"
    fi

    TARGET_BRANCHES=("test" "stage" "build_branch")

    for TARGET_BRANCH in "${TARGET_BRANCHES[@]}"; do
        PR_FULL_TITLE="[${SOURCE_BRANCH}][${TARGET_BRANCH^^}] $PR_TITLE"

        echo "🔧 Creating PR from ${SOURCE_BRANCH} to ${TARGET_BRANCH} with title: ${PR_FULL_TITLE}"

        gh pr create --base "$TARGET_BRANCH" --head "$SOURCE_BRANCH" --title "$PR_FULL_TITLE" --body "This PR merges branch \`${SOURCE_BRANCH}\` into \`${TARGET_BRANCH}\`."

        echo "✅ PR for ${TARGET_BRANCH} created successfully!"
    done
}

function recon() {
    BRANCH_NAME=$1
    BASE_BRANCH=$2

    if [ -z "$BRANCH_NAME" ] || [ -z "$BASE_BRANCH" ]; then
        echo "❌ Error: Both branch name and base branch are required."
        echo "Usage: pal-tool recon <branch_name> <base_branch>"
        exit 1
    fi

    REC_BRANCH="${BRANCH_NAME}_rec_${BASE_BRANCH}"

    echo "🔄 Switching to branch $BASE_BRANCH..."
    if ! git checkout "$BASE_BRANCH"; then
        echo "❌ Failed to switch to branch '$BASE_BRANCH'. Could not create reconciliation branch."
        echo "🔍 Git error: $(git status --short)"
        git checkout "$BRANCH_NAME" >/dev/null 2>&1
        exit 1
    fi

    echo "⬇️ Pulling latest changes from $BASE_BRANCH..."
    if ! git pull origin "$BASE_BRANCH"; then
        echo "❌ Failed to pull latest changes from '$BASE_BRANCH'. Aborting reconciliation."
        git checkout "$BRANCH_NAME" >/dev/null 2>&1
        exit 1
    fi

    echo "🌱 Preparing reconciliation branch: $REC_BRANCH..."
    if git rev-parse --verify "$REC_BRANCH" >/dev/null 2>&1; then
        echo "🔁 Reconciliation branch '$REC_BRANCH' already exists. Switching to it..."
        if ! git checkout "$REC_BRANCH"; then
            echo "❌ Failed to switch to existing reconciliation branch."
            git checkout "$BRANCH_NAME" >/dev/null 2>&1
            exit 1
        fi
        echo "⬇️ Pulling latest changes into '$REC_BRANCH'..."
        if ! git pull origin "$REC_BRANCH"; then
            echo "❌ Failed to pull latest changes into existing reconciliation branch."
            git checkout "$BRANCH_NAME" >/dev/null 2>&1
            exit 1
        fi
    else
        echo "🌱 Creating new reconciliation branch: $REC_BRANCH..."
        if ! git checkout -b "$REC_BRANCH"; then
            echo "❌ Failed to create reconciliation branch '$REC_BRANCH'."
            git checkout "$BRANCH_NAME" >/dev/null 2>&1
            exit 1
        fi
    fi

    echo "🔀 Merging branch $BRANCH_NAME into $REC_BRANCH..."
    if ! git merge "$BRANCH_NAME"; then
        echo "❌ Merge failed. Aborting reconciliation process."
        git checkout "$BRANCH_NAME" >/dev/null 2>&1
        exit 1
    fi

    echo "📤 Pushing reconciliation branch to remote..."
    if ! git push origin "$REC_BRANCH"; then
        echo "❌ Failed to push reconciliation branch to remote."
        git checkout "$BRANCH_NAME" >/dev/null 2>&1
        exit 1
    fi

    echo "✅ Reconciliation process completed!"
}

function mw_health() {
    ENV_NAME_RAW=$1
    shift
    MAX_MESSAGE_CHARS=300

    # Parse optional flags
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--max-chars)
                MAX_MESSAGE_CHARS="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Usage: pal-tool mw-health <DEV|TST|PRD> [-m|--max-chars <number>]"
                exit 1
                ;;
        esac
    done

    ENV_NAME=$(printf '%s' "$ENV_NAME_RAW" | tr '[:lower:]' '[:upper:]')
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROCESS_FILE="${SCRIPT_DIR}/process.json"

    if [ -z "$ENV_NAME" ]; then
        echo "Error: Environment not provided."
        echo "Usage: pal-tool mw-health <DEV|TST|PRD> [-m|--max-chars <number>]"
        exit 1
    fi

    case "$ENV_NAME" in
        DEV)
            ENV_URL="https://mw-test-princessauto.objectedge.com"
            ;;
        TST)
            ENV_URL="https://mw-stage-princessauto.objectedge.com"
            ;;
        PRD)
            ENV_URL="https://mwprod-integration-princessauto.objectedge.com"
            ;;
        *)
            echo "Error: Invalid environment '$ENV_NAME'. Use DEV, TST, or PRD."
            exit 1
            ;;
    esac

    if [ ! -f "$PROCESS_FILE" ]; then
        echo "Error: process.json not found at $PROCESS_FILE."
        exit 1
    fi

    read -r -p "User: " USER
    read -r -s -p "Password: " PASSWORD
    echo
    read -r -p "TOTP code: " TOTP_CODE

    BASIC_AUTH=$(echo -n "${USER}:${PASSWORD}:${TOTP_CODE}" | base64)

    spinner() {
        local pid=$1
        local message=$2
        local spin='|/-\'
        local i=0

        while kill -0 "$pid" 2>/dev/null; do
            printf '\r%s %c' "$message" "${spin:i++%4:1}"
            sleep 0.1
        done
        printf '\r%s... done\n' "$message"
    }

    TOKEN_TMP=$(mktemp)
    (
        curl -s -X POST "${ENV_URL}/api/ui/auth/login" \
            -H "Authorization: Basic ${BASIC_AUTH}" \
            -H "Content-Type: application/json" >"$TOKEN_TMP"
    ) &
    TOKEN_PID=$!
    spinner "$TOKEN_PID" "Fetching token"
    wait "$TOKEN_PID"
    RESPONSE=$(cat "$TOKEN_TMP")
    rm -f "$TOKEN_TMP"

    TOKEN=$(printf '%s' "$RESPONSE" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

    if [ -z "$TOKEN" ]; then
        echo "Token not found in response."
        echo "$RESPONSE"
        exit 1
    fi

    PROCESS_NAMES=(
        "Brand Sync"
        "Catalog Sync"
        "Collection Sync"
        "Constructor.io Full Sync"
        "Document Sync"
        "Google Feed"
        "Inventory Full Sync"
        "Inventory Sync"
        "Organization Sync"
        "Pricing Sync"
        "Product Sync"
        "Label Sync"
    )

    if [ -t 1 ]; then
        GREEN='\033[0;32m'
        RED='\033[0;31m'
        YELLOW='\033[0;33m'
        RESET='\033[0m'
    else
        GREEN=''
        RED=''
        YELLOW=''
        RESET=''
    fi

    # Arrays to track results for final report
    declare -a SUCCESS_PROCESSES=()
    declare -a RUNNING_PROCESSES=()
    declare -a FAILED_PROCESSES=()
    declare -a FAILED_MESSAGES=()

    get_process_id() {
        local env_name=$1
        local process_name=$2

        awk -v env="\"${env_name}\"" -v name="\"${process_name}\"" '
            $0 ~ env { in_env=1; next }
            in_env {
                if ($0 ~ /^[[:space:]]*}/) { in_env=0 }
                if ($0 ~ name) {
                    match($0, /:[[:space:]]*([0-9]+)/, m)
                    if (m[1] != "") { print m[1]; exit }
                }
            }
        ' "$PROCESS_FILE"
    }

    is_html_message() {
        local message=$1
        # Check if message contains HTML tags (has < and > with tag-like content)
        local html_pattern='<[a-zA-Z/][^>]*>'
        [[ "$message" =~ $html_pattern ]]
    }

    format_html_message() {
        local message=$1

        # Convert HTML to readable text preserving structure
        message=$(printf '%s' "$message" | \
            sed 's/<br\s*\/*>/\n/g' | \
            sed 's/<\/li>/\n/g' | \
            sed 's/<li>/  • /g' | \
            sed 's/<\/ul>//g' | \
            sed 's/<ul>//g' | \
            sed 's/<\/b>//g' | \
            sed 's/<b>//g' | \
            sed 's/<[^>]*>//g' | \
            sed 's/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g; s/&quot;/"/g; s/&#39;/'\''/g; s/&nbsp;/ /g' | \
            sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

        # If empty after stripping, add generic message
        if [ -z "$message" ]; then
            message="HTML error response received (content stripped for readability)"
        fi

        printf '%s' "$message"
    }

    echo "==============================================="
    echo "Middleware Process Health Check"
    echo "==============================================="

    for PROCESS_NAME in "${PROCESS_NAMES[@]}"; do
        PROCESS_ID=$(get_process_id "$ENV_NAME" "$PROCESS_NAME")
        if [ -z "$PROCESS_ID" ]; then
            printf '%b\n' "${PROCESS_NAME} - ${RED}Fail${RESET} ❌"
            ERROR_MSG="Missing process id for ${ENV_NAME}."
            echo "$ERROR_MSG"
            echo
            FAILED_PROCESSES+=("$PROCESS_NAME")
            FAILED_MESSAGES+=("$ERROR_MSG")
            continue
        fi

        HISTORY_TMP=$(mktemp)
        (
            curl -s -L -X GET "${ENV_URL}/api/ui/history?process=${PROCESS_ID}&message=&minDate=&maxDate=&limit=1&page=1" \
                -H "Authorization: Bearer ${TOKEN}" \
                -H "Content-Type: application/json" >"$HISTORY_TMP"
        ) &
        HISTORY_PID=$!
        spinner "$HISTORY_PID" "Fetching ${PROCESS_NAME} (ID: ${PROCESS_ID})"
        wait "$HISTORY_PID"
        HISTORY_RESPONSE=$(cat "$HISTORY_TMP")
        rm -f "$HISTORY_TMP"

        if [ -z "$HISTORY_RESPONSE" ]; then
            printf '%b\n' "${PROCESS_NAME} - ${RED}Fail${RESET} ❌"
            ERROR_MSG="Empty response from history endpoint."
            echo "$ERROR_MSG"
            echo
            FAILED_PROCESSES+=("$PROCESS_NAME")
            FAILED_MESSAGES+=("$ERROR_MSG")
            continue
        fi

        HISTORY_RESPONSE_STRIPPED=$(printf '%s' "$HISTORY_RESPONSE" | sed 's/^[[:space:]]*//')

        if [ -z "$HISTORY_RESPONSE_STRIPPED" ]; then
            printf '%b\n' "${PROCESS_NAME} - ${RED}Fail${RESET} ❌"
            ERROR_MSG="Empty response from history endpoint."
            echo "$ERROR_MSG"
            echo
            FAILED_PROCESSES+=("$PROCESS_NAME")
            FAILED_MESSAGES+=("$ERROR_MSG")
            continue
        fi

        case "$HISTORY_RESPONSE_STRIPPED" in
            \{*|\[*)
                ;;
            *)
                printf '%b\n' "${PROCESS_NAME} - ${RED}Fail${RESET} ❌"
                ERROR_MSG="Non-JSON response from history endpoint: $HISTORY_RESPONSE"
                echo "$ERROR_MSG"
                echo
                FAILED_PROCESSES+=("$PROCESS_NAME")
                FAILED_MESSAGES+=("$ERROR_MSG")
                continue
                ;;
        esac

        STATUS=$(printf '%s' "$HISTORY_RESPONSE_STRIPPED" | sed -n '0,/"status"[[:space:]]*:/s/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        MESSAGE_RAW=$(printf '%s' "$HISTORY_RESPONSE_STRIPPED" | sed -n '0,/"message"[[:space:]]*:/s/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        MESSAGE=$(printf '%s' "$MESSAGE_RAW" | sed 's/\\"/"/g; s#\\\\/#/#g')

        # Check if message is HTML and format it
        IS_HTML=false
        if is_html_message "$MESSAGE"; then
            MESSAGE=$(format_html_message "$MESSAGE")
            IS_HTML=true
        fi

        if [ -z "$STATUS" ]; then
            printf '%b\n' "${PROCESS_NAME} - ${RED}Fail${RESET} ❌"
            ERROR_MSG="Could not parse status from history response."
            echo "$ERROR_MSG"
            echo
            FAILED_PROCESSES+=("$PROCESS_NAME")
            FAILED_MESSAGES+=("$ERROR_MSG")
            continue
        fi

        if [ "${STATUS,,}" = "success" ]; then
            printf '%b\n' "${PROCESS_NAME} - ${GREEN}Success${RESET} ✅"
            SUCCESS_PROCESSES+=("$PROCESS_NAME")
        elif [ "${STATUS,,}" = "running" ]; then
            printf '%b\n' "${PROCESS_NAME} - ${YELLOW}Running${RESET} ⏳"
            RUNNING_PROCESSES+=("$PROCESS_NAME")
        else
            printf '%b\n' "${PROCESS_NAME} - ${RED}Fail${RESET} ❌"
            if [ -n "$MESSAGE" ]; then
                # Only truncate if not HTML (HTML messages are always shown in full)
                if [ "$IS_HTML" = false ] && [ "${#MESSAGE}" -gt "$MAX_MESSAGE_CHARS" ]; then
                    MESSAGE_DISPLAY="${MESSAGE:0:$MAX_MESSAGE_CHARS}..."
                    printf '%b\n' "$MESSAGE_DISPLAY"
                else
                    printf '%b\n' "$MESSAGE"
                fi
            fi
            FAILED_PROCESSES+=("$PROCESS_NAME")
            FAILED_MESSAGES+=("$MESSAGE")
        fi
        echo
    done

    # Print final report
    echo
    echo "==============================================="
    echo "Final Report"
    echo "==============================================="
    echo "Overnight Middleware Process Health Check $(date '+%m/%d/%Y')"
    echo

    # Print all processes with their status
    for PROCESS_NAME in "${PROCESS_NAMES[@]}"; do
        if [[ " ${SUCCESS_PROCESSES[*]} " =~ " ${PROCESS_NAME} " ]]; then
            printf '%b\n' "${GREEN}✅ ${PROCESS_NAME}${RESET}"
        elif [[ " ${RUNNING_PROCESSES[*]} " =~ " ${PROCESS_NAME} " ]]; then
            printf '%b\n' "${YELLOW}⏳ ${PROCESS_NAME}${RESET}"
        elif [[ " ${FAILED_PROCESSES[*]} " =~ " ${PROCESS_NAME} " ]]; then
            printf '%b\n' "${RED}❌ ${PROCESS_NAME}${RESET}"
        fi
    done

    # Print detailed error messages for failed processes
    if [ ${#FAILED_PROCESSES[@]} -gt 0 ]; then
        echo
        for i in "${!FAILED_PROCESSES[@]}"; do
            printf '%b\n' "${RED}${FAILED_PROCESSES[$i]}:${RESET}"
            if [ -n "${FAILED_MESSAGES[$i]}" ]; then
                printf '%b\n' "${FAILED_MESSAGES[$i]}"
            fi
            echo
        done
    fi

    # Print summary
    echo "==============================================="
    printf "Total: %d | " "${#PROCESS_NAMES[@]}"
    printf '%b' "${GREEN}Success: ${#SUCCESS_PROCESSES[@]}${RESET} | "
    printf '%b' "${YELLOW}Running: ${#RUNNING_PROCESSES[@]}${RESET} | "
    printf '%b\n' "${RED}Failed: ${#FAILED_PROCESSES[@]}${RESET}"
    echo "==============================================="
}

case "$COMMAND" in
    create-prs)
        create_prs "$2" "$3"
        ;;
    recon)
        recon "$2" "$3"
        ;;
    mw-health)
        shift
        mw_health "$@"
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        echo "Invalid command. Use 'pal-tool help' for usage information."
        exit 1
        ;;
esac
