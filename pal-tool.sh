#!/bin/bash

# name: pal-tool
# usage:
#   ./pal-tool create-prs <source_branch> [pr_title]
#   ./pal-tool recon <branch_name> <base_branch>
#   ./pal-tool help | -h | --help

COMMAND=$1

function show_help() {
    echo "Usage: $0 {create-prs|recon|help} ..."
    echo
    echo "Commands:"
    echo "  create-prs <source_branch> [pr_title]   Create pull requests for multiple target branches."
    echo "  recon <branch_name> <base_branch>       Create a reconciliation branch and merge changes."
    echo "  help | -h | --help                      Show this help message."
    echo
    echo "Examples:"
    echo "  $0 create-prs feature-branch 'My PR Title'"
    echo "  $0 recon feature-branch main"
    echo "  $0 help"
}

function create_prs() {
    SOURCE_BRANCH="$1"
    PR_TITLE="$2"

    if [ -z "$SOURCE_BRANCH" ]; then
        echo "Erro: Nome da branch de origem não informado."
        echo "Uso: $0 create-prs <source_branch> [pr_title]"
        exit 1
    fi

    if [ -z "$PR_TITLE" ]; then
        PR_TITLE="[${SOURCE_BRANCH}] Test de PRs Script"
    fi

    TARGET_BRANCHES=("test" "stage" "build_branch")

    for TARGET_BRANCH in "${TARGET_BRANCHES[@]}"; do
        PR_FULL_TITLE="[${SOURCE_BRANCH}][${TARGET_BRANCH^^}] $PR_TITLE"

        echo "🔧 Criando PR de ${SOURCE_BRANCH} para ${TARGET_BRANCH} com título: ${PR_FULL_TITLE}"

        gh pr create --base "$TARGET_BRANCH" --head "$SOURCE_BRANCH" --title "$PR_FULL_TITLE" --body "Este PR faz merge da branch \`${SOURCE_BRANCH}\` para \`${TARGET_BRANCH}\`."

        echo "✅ PR para ${TARGET_BRANCH} criado com sucesso!"
    done
}

function recon() {
    BRANCH_NAME=$1
    BASE_BRANCH=$2

    if [ -z "$BRANCH_NAME" ] || [ -z "$BASE_BRANCH" ]; then
        echo "❌ Error: Both branch name and base branch are required."
        echo "Usage: $0 recon <branch_name> <base_branch>"
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

case "$COMMAND" in
    create-prs)
        create_prs "$2" "$3"
        ;;
    recon)
        recon "$2" "$3"
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        echo "Invalid command. Use '$0 help' for usage information."
        exit 1
        ;;
esac