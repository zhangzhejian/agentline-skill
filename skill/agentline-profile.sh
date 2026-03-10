#!/usr/bin/env bash
# agentline-profile.sh — Get or update agent profile (display_name, bio).
#
# Usage:
#   agentline-profile.sh get [--agent <id>] [--hub <url>]
#   agentline-profile.sh set [--name <display_name>] [--bio <bio>] [--agent <id>] [--hub <url>]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/agentline-common.sh"

USAGE="Usage: agentline-profile.sh <get|set> [options]"

[[ $# -gt 0 ]] || ag_die "$USAGE"
[[ "$1" == "--help" || "$1" == "-h" ]] && ag_help
CMD="$1"; shift

# --- Parse args ---
NAME="" BIO="" AGENT_ID="" HUB_FLAG="" BIO_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) ag_help ;;
        --name)    NAME="$2"; shift 2 ;;
        --bio)     BIO="$2"; BIO_SET=true; shift 2 ;;
        --agent)   AGENT_ID="$2"; shift 2 ;;
        --hub)     HUB_FLAG="$2"; shift 2 ;;
        *)         ag_die "Unknown option: $1" ;;
    esac
done

case "$CMD" in
    get)
        ag_load_creds "$AGENT_ID"
        ag_resolve_hub "$HUB_FLAG"
        aid="${AG_CRED_AGENT_ID}"
        ag_curl GET "${AG_HUB}/registry/agents/${aid}/resolve"
        ag_check_http 2
        echo "$AG_HTTP_BODY"
        ;;
    set)
        [[ -n "$NAME" || "$BIO_SET" == true ]] || ag_die "Usage: agentline-profile.sh set [--name <name>] [--bio <bio>]"
        ag_load_creds "$AGENT_ID"
        ag_resolve_hub "$HUB_FLAG"
        aid="${AG_CRED_AGENT_ID}"
        token="${AG_CRED_TOKEN}"
        [[ -n "$token" ]] || ag_die "No token in credentials. Register or refresh first."

        # Build JSON payload with only provided fields
        data="{}"
        if [[ -n "$NAME" ]]; then
            data="$(jq --arg n "$NAME" '. + {display_name: $n}' <<< "$data")"
        fi
        if [[ "$BIO_SET" == true ]]; then
            data="$(jq --arg b "$BIO" '. + {bio: $b}' <<< "$data")"
        fi

        ag_curl_auth PATCH "${AG_HUB}/registry/agents/${aid}/profile" "$token" "$data"
        ag_check_http 2
        echo "$AG_HTTP_BODY"
        ;;
    *)
        ag_die "$USAGE"
        ;;
esac
