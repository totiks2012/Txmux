#!/bin/bash
# tx-watcher.sh — Фоновый монитор состояния

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$DIR/tx-config.conf" ] && source "$DIR/tx-config.conf"

SESSION_FILE="$DIR/txmux_tabs.session"
INTERVAL=${WATCHER_INTERVAL:-3}
MAX_TABS=${MAX_TABS:-8}
START_IDX=${START_IDX:-2}

G='\e[1;32m'; R='\e[1;31m'; Y='\e[1;33m'; B='\e[1;34m'; NC='\e[0m'

while true; do
    clear
    echo -e "${B}=== TX-WATCHER v3.4 REPORT ===${NC} | $(date +"%H:%M:%S")"
    echo "------------------------------------------------"

    if ! pgrep -u "$USER" -f "TXMUX_ID=" > /dev/null; then
        echo -e "${R}[!] СИСТЕМА СПИТ: Активных вкладок не найдено.${NC}"
        sleep 10; continue
    fi

    for i in $(seq $START_IDX $((START_IDX + MAX_TABS - 1))); do
        LINE_NUM=$((i - START_IDX + 1))
        SLOT_PID=""
        for pid in $(pgrep -u "$USER" bash); do
            if [ -r "/proc/$pid/environ" ] && tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -q "^TXMUX_ID=$i$"; then
                SLOT_PID="$pid"
                break
            fi
        done

        CMD="bash"; CWD="$HOME"; NAME="bash"; STATUS="${Y}BASH${NC}"
        if [ -n "$SLOT_PID" ] && [ -d "/proc/$SLOT_PID" ]; then
            CWD="$(readlink -f "/proc/$SLOT_PID/cwd" 2>/dev/null || echo "$HOME")"
            CHILD_PID=$(pgrep -P "$SLOT_PID" | tail -n 1)
            
            if [ -n "$CHILD_PID" ] && [ -d "/proc/$CHILD_PID" ]; then
                RAW_CMD=$(tr '\0' ' ' < "/proc/$CHILD_PID/cmdline" 2>/dev/null | sed 's/ $//')
                if [ -n "$RAW_CMD" ] && [[ "$RAW_CMD" != "bash"* ]]; then
                    CMD="$RAW_CMD"
                    NAME="$(basename "$(echo "$CMD" | awk '{print $1}' | tr -d '"')")"
                    STATUS="${G}ACTIVE ($NAME)${NC}"
                    CWD="$(readlink -f "/proc/$CHILD_PID/cwd" 2>/dev/null || echo "$CWD")"
                fi
            fi
            
            [ -f "$CWD" ] && CWD="$(dirname "$CWD")"
            NEW_DATA="$(echo "${CMD}|${CWD}|${NAME}|$(date +"%H:%M:%S")" | tr -d '\r\n' | tr '@' '_')"
            
            tmp_f=$(mktemp "/tmp/tx_XXXXXX")
            if sed "${LINE_NUM}s@.*@${NEW_DATA}@" "$SESSION_FILE" > "$tmp_f"; then
                mv "$tmp_f" "$SESSION_FILE"
                W_RES="${G}[OK]${NC}"
            else
                W_RES="${R}[FAIL]${NC}"; rm -f "$tmp_f"
            fi
            printf "Слот [%d]: %-25b | %s %b\n" "$i" "$STATUS" "$CWD" "$W_RES"
        else
            printf "Слот [%d]: %-25b | -\n" "$i" "${R}EMPTY${NC}"
        fi
    done
    sleep "$INTERVAL"
done