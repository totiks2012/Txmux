#!/bin/bash
# txmux_03.sh v1.6 — Движок с интегрированной Тенью

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$DIR/tx-config.conf" ] && source "$DIR/tx-config.conf"

TERMINAL_BIN=${TERMINAL_BIN:-"xfce4-terminal"}
MAX_TABS=${MAX_TABS:-8}
START_IDX=${START_IDX:-2}
SESSION_FILE="$DIR/txmux_tabs.session"

export DISPLAY=${DISPLAY:-:0}

check_session_file() {
    if [ ! -f "$SESSION_FILE" ]; then
        for i in $(seq 1 $MAX_TABS); do echo "bash|$HOME|bash" >> "$SESSION_FILE"; done
    fi
}

# Функция добавления Тени в конец команды терминала
append_watcher_if_needed() {
    if ! pgrep -u "$USER" -f "bash.*tx-watcher.sh" > /dev/null; then
        TERMINAL_CMD="$TERMINAL_CMD --tab -T 'WATCHER-LOG' -e 'bash $DIR/tx-watcher.sh'"
    fi
}

launch_session() {
    local filter="$1"
    if [[ "$filter" =~ ^([0-9]+)_$ ]]; then
        local n=${BASH_REMATCH[1]}
        [ "$n" -gt "$MAX_TABS" ] && n=$MAX_TABS
        local new_filter=""
        for ((j=0; j<n; j++)); do new_filter+="$((START_IDX + j))_"; done
        filter=${new_filter%_}
    fi

    check_session_file
    TERMINAL_CMD="$TERMINAL_BIN --display=$DISPLAY"
    local count=0
    local opened_count=0

    while IFS='|' read -r cmd path name; do
        ((count++))
        TAB_NUM=$((count + START_IDX - 1))
        if [ -n "$filter" ] && [[ ! "_${filter}_" == *"_${TAB_NUM}_"* ]]; then continue; fi
        
        ((opened_count++))
        TITLE="$TAB_NUM:$name"
        TERMINAL_CMD="$TERMINAL_CMD --tab -T '$TITLE' -e 'bash -c \"cd \\\"$path\\\"; export TXMUX_ID=$TAB_NUM; $cmd; bash\"'"
    done < "$SESSION_FILE"

    if [ "$opened_count" -gt 0 ]; then
        append_watcher_if_needed  # <-- ВОТ ОНО: добавляем в самый конец
        eval "$TERMINAL_CMD &"
    fi
}

launch_clean_session() {
    echo -e "\e[1;33m>>> Запуск чистых вкладок...\e[0m"
    > "$SESSION_FILE"
    for i in $(seq 1 $MAX_TABS); do echo "bash|$HOME|bash" >> "$SESSION_FILE"; done

    TERMINAL_CMD="$TERMINAL_BIN --display=$DISPLAY"
    for i in $(seq 0 $((MAX_TABS - 1))); do
        TAB_NUM=$((i + START_IDX))
        TERMINAL_CMD="$TERMINAL_CMD --tab -T '$TAB_NUM:bash' -e 'bash -c \"export TXMUX_ID=$TAB_NUM; exec bash\"'"
    done

    append_watcher_if_needed # <-- И здесь тоже в конец
    eval "$TERMINAL_CMD &"
}

# Оставшаяся часть show_list_and_menu и case остается без изменений...
show_list_and_menu() {
    check_session_file
    echo -e "\e[1;36m--- ТЕКУЩАЯ СЕССИЯ TXMUX ---\e[0m"
    printf "\e[1;31m[0]\e[0m \e[1;31m%-10s\e[0m | %s\n" "RESET" "ОБНУЛИТЬ ФАЙЛ"
    echo "----------------------------"
    local count=0
    while IFS='|' read -r cmd path name; do
        ((count++))
        TAB_NUM=$((count + START_IDX - 1))
        printf "\e[1;32m[%d]\e[0m \e[1;34m%-10s\e[0m | %s\n" "$TAB_NUM" "$name" "$path"
    done < "$SESSION_FILE"
    read -p "Выбор (напр: 2_4 или 4_ или 0) > " user_choice
    [ "$user_choice" == "0" ] && launch_clean_session || launch_session "$user_choice"
}

case "$1" in
    s) bash "$DIR/txmux_03.sh" save_logic_placeholder ;; # Здесь должна быть твоя save_session
    l) show_list_and_menu ;;
    *) launch_session "$1" ;;
esac