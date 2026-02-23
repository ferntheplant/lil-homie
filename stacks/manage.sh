#!/bin/bash

# Script to manage all docker-compose stacks
# Usage: ./manage.sh [start|stop|restart|status|logs] [stack]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKS=("caddy" "beeper" "homie" "karakeep" "yams")
TAILSCALE_HOST="lil-homie.tail8cc0d3.ts.net"
TAILSCALE_SERVE_PORTS=("8080" "3003" "3001")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SHARED_ENV_FILE="/Users/fjorn/lil-homie/.env.shared"

compose_cmd() {
    local env_args=(--env-file "${SHARED_ENV_FILE}")
    if [[ -f ".env" ]]; then
        env_args+=(--env-file ".env")
    fi
    docker compose "${env_args[@]}" "$@"
}

tailscale_available() {
    command -v tailscale >/dev/null 2>&1
}

run_with_timeout() {
    local seconds=$1
    shift
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$seconds" "$@" <<'PY'
import subprocess
import sys

timeout = float(sys.argv[1])
cmd = sys.argv[2:]
p = subprocess.Popen(
    cmd,
    stdin=subprocess.DEVNULL,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
try:
    p.wait(timeout=timeout)
except subprocess.TimeoutExpired:
    p.terminate()
    try:
        p.wait(timeout=1)
    except subprocess.TimeoutExpired:
        p.kill()
sys.exit(0)
PY
    else
        "$@" </dev/null >/dev/null 2>&1 || true
    fi
}

serve_on() {
    local port=$1
    if [[ "$port" == "8080" ]]; then
        # Default HTTPS on :443 -> local 8080
        run_with_timeout 3 tailscale serve --bg "${port}" </dev/null >/dev/null 2>&1 || true
    else
        # Explicit HTTPS port -> same local port
        run_with_timeout 3 tailscale serve --bg --https "${port}" "${port}" </dev/null >/dev/null 2>&1 || true
    fi
}

serve_off() {
    local port=$1
    if [[ "$port" == "8080" ]]; then
        run_with_timeout 3 tailscale serve clear https:443 </dev/null >/dev/null 2>&1 || true
    else
        run_with_timeout 3 tailscale serve clear "https:${port}" </dev/null >/dev/null 2>&1 || true
    fi
}

ensure_tailscale_serve() {
    if ! tailscale_available; then
        echo -e "${YELLOW}tailscale not found; skipping serve setup.${NC}"
        return 0
    fi
    echo -e "${YELLOW}→ tailscale serve${NC}"
    for port in "${TAILSCALE_SERVE_PORTS[@]}"; do
        serve_on "${port}"
    done
    echo -e "${YELLOW}If Serve is not enabled for this tailnet, run: tailscale serve --bg 8080 (and 3003/3001)${NC}"
    echo -e "${GREEN}tailscale serve configured for ${TAILSCALE_HOST}.${NC}"
}

disable_tailscale_serve() {
    if ! tailscale_available; then
        return 0
    fi
    echo -e "${YELLOW}→ tailscale serve off${NC}"
    for port in "${TAILSCALE_SERVE_PORTS[@]}"; do
        serve_off "${port}"
    done
}

is_valid_stack() {
    local stack=$1
    for s in "${STACKS[@]}"; do
        if [[ "$s" == "$stack" ]]; then
            return 0
        fi
    done
    return 1
}

require_stack() {
    local stack=$1
    if ! is_valid_stack "$stack"; then
        echo -e "${RED}Unknown stack: ${stack}${NC}"
        echo "Valid stacks: ${STACKS[*]}"
        exit 1
    fi
}

# Function to run docker-compose command on all stacks
run_on_all() {
    local command=$1
    local shift_args=("${@:2}")

    for stack in "${STACKS[@]}"; do
        echo -e "${YELLOW}→ ${stack}${NC}"
        cd "${SCRIPT_DIR}/${stack}"
        compose_cmd $command "${shift_args[@]}"
    done
}

# Function to start a single stack
start_one() {
    local stack=$1
    require_stack "$stack"
    echo -e "${GREEN}Starting ${stack}...${NC}"
    echo -e "${YELLOW}→ ${stack}${NC}"
    cd "${SCRIPT_DIR}/${stack}"
    compose_cmd up -d
    if [[ "$stack" == "caddy" || "$stack" == "homie" ]]; then
        ensure_tailscale_serve
    fi
    echo -e "${GREEN}${stack} started!${NC}"
}

# Function to start all stacks
start_all() {
    echo -e "${GREEN}Starting all stacks...${NC}"
    # Start caddy first to create the network
    echo -e "${YELLOW}→ caddy${NC}"
    cd "${SCRIPT_DIR}/caddy"
    compose_cmd up -d

    # Then start the rest
    for stack in "${STACKS[@]:1}"; do
        echo -e "${YELLOW}→ ${stack}${NC}"
        cd "${SCRIPT_DIR}/${stack}"
        compose_cmd up -d
    done
    ensure_tailscale_serve
    echo -e "${GREEN}All stacks started!${NC}"
}

# Function to stop a single stack
stop_one() {
    local stack=$1
    require_stack "$stack"
    echo -e "${RED}Stopping ${stack}...${NC}"
    echo -e "${YELLOW}→ ${stack}${NC}"
    cd "${SCRIPT_DIR}/${stack}"
    compose_cmd down
    if [[ "$stack" == "caddy" ]]; then
        serve_off "8080"
        serve_off "3003"
    fi
    if [[ "$stack" == "homie" ]]; then
        serve_off "3001"
    fi
    echo -e "${GREEN}${stack} stopped!${NC}"
}

# Function to stop all stacks
stop_all() {
    echo -e "${RED}Stopping all stacks...${NC}"
    # Stop in reverse order (caddy last to avoid network issues)
    for ((idx=${#STACKS[@]}-1 ; idx>=0 ; idx--)); do
        stack="${STACKS[$idx]}"
        echo -e "${YELLOW}→ ${stack}${NC}"
        cd "${SCRIPT_DIR}/${stack}"
        compose_cmd down
    done
    disable_tailscale_serve
    echo -e "${GREEN}All stacks stopped!${NC}"
}

# Function to restart a single stack
restart_one() {
    local stack=$1
    require_stack "$stack"
    echo -e "${YELLOW}Restarting ${stack}...${NC}"
    stop_one "$stack"
    start_one "$stack"
}

# Function to restart all stacks
restart_all() {
    echo -e "${YELLOW}Restarting all stacks...${NC}"
    stop_all
    start_all
}

# Function to show status of all stacks
status_all() {
    echo -e "${GREEN}Status of all stacks:${NC}"
    for stack in "${STACKS[@]}"; do
        echo -e "\n${YELLOW}=== ${stack} ===${NC}"
        cd "${SCRIPT_DIR}/${stack}"
        compose_cmd ps
    done
}

# Function to show logs
logs_all() {
    local follow=${1:-""}
    echo -e "${GREEN}Showing logs for all stacks${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}\n"

    for stack in "${STACKS[@]}"; do
        echo -e "\n${YELLOW}=== ${stack} ===${NC}"
        cd "${SCRIPT_DIR}/${stack}"
        compose_cmd logs $follow
    done
}

logs_one() {
    local stack=$1
    local follow=${2:-""}
    require_stack "$stack"
    echo -e "${GREEN}Showing logs for ${stack}${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}\n"
    cd "${SCRIPT_DIR}/${stack}"
    compose_cmd logs $follow
}

# Main command handling
case "${1:-}" in
    start)
        if [[ -n "${2:-}" ]]; then
            start_one "${2}"
        else
            start_all
        fi
        ;;
    stop)
        if [[ -n "${2:-}" ]]; then
            stop_one "${2}"
        else
            stop_all
        fi
        ;;
    restart)
        if [[ -n "${2:-}" ]]; then
            restart_one "${2}"
        else
            restart_all
        fi
        ;;
    status)
        status_all
        ;;
    logs)
        if [[ -n "${2:-}" ]]; then
            if is_valid_stack "${2}"; then
                logs_one "${2}" "${3:-}"
            else
                logs_all "${2:-}"
            fi
        else
            logs_all "${2:-}"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [--follow]} [stack]"
        echo ""
        echo "Commands:"
        echo "  start   - Start all stacks or a single stack"
        echo "  stop    - Stop all stacks or a single stack"
        echo "  restart - Restart all stacks or a single stack"
        echo "  status  - Show status of all stacks"
        echo "  logs    - Show logs from all stacks (add --follow for tail)"
        echo ""
        echo "Stacks: ${STACKS[*]}"
        exit 1
        ;;
esac
