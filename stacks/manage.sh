#!/bin/bash

# Script to manage all docker-compose stacks
# Usage: ./manage.sh [start|stop|restart|status|logs] [stack]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKS=("caddy" "beeper" "homie" "karakeep" "yams")

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
        logs_all "${2:-}"
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
