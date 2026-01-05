#!/bin/bash

# Script to manage all docker-compose stacks
# Usage: ./manage.sh [start|stop|restart|status|logs]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACKS=("caddy" "beeper" "homie" "karakeep")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SHARED_ENV_FILE="/Users/fjorn/lil-homie/.env.shared"

# Function to run docker-compose command on all stacks
run_on_all() {
    local command=$1
    local shift_args=("${@:2}")

    for stack in "${STACKS[@]}"; do
        echo -e "${YELLOW}→ ${stack}${NC}"
        cd "${SCRIPT_DIR}/${stack}"
        docker compose --env-file "${SHARED_ENV_FILE}" $command "${shift_args[@]}"
    done
}

# Function to start all stacks
start_all() {
    echo -e "${GREEN}Starting all stacks...${NC}"
    # Start caddy first to create the network
    echo -e "${YELLOW}→ caddy${NC}"
    cd "${SCRIPT_DIR}/caddy"
    docker compose --env-file "${SHARED_ENV_FILE}" up -d

    # Then start the rest
    for stack in "${STACKS[@]:1}"; do
        echo -e "${YELLOW}→ ${stack}${NC}"
        cd "${SCRIPT_DIR}/${stack}"
        docker compose --env-file "${SHARED_ENV_FILE}" up -d
    done
    echo -e "${GREEN}All stacks started!${NC}"
}

# Function to stop all stacks
stop_all() {
    echo -e "${RED}Stopping all stacks...${NC}"
    # Stop in reverse order (caddy last to avoid network issues)
    for ((idx=${#STACKS[@]}-1 ; idx>=0 ; idx--)); do
        stack="${STACKS[$idx]}"
        echo -e "${YELLOW}→ ${stack}${NC}"
        cd "${SCRIPT_DIR}/${stack}"
        docker compose --env-file "${SHARED_ENV_FILE}" down
    done
    echo -e "${GREEN}All stacks stopped!${NC}"
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
        docker compose --env-file "${SHARED_ENV_FILE}" ps
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
        docker compose --env-file "${SHARED_ENV_FILE}" logs $follow
    done
}

# Main command handling
case "${1:-}" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    restart)
        restart_all
        ;;
    status)
        status_all
        ;;
    logs)
        logs_all "${2:-}"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [--follow]}"
        echo ""
        echo "Commands:"
        echo "  start   - Start all stacks (caddy first to create network)"
        echo "  stop    - Stop all stacks"
        echo "  restart - Restart all stacks"
        echo "  status  - Show status of all stacks"
        echo "  logs    - Show logs from all stacks (add --follow for tail)"
        exit 1
        ;;
esac

