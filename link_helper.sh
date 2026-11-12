#!/bin/bash

# 0. 歷史紀錄儲存檔
HISTORY_FILE="$HOME/.config/link_helper_history.txt"
mkdir -p "$(dirname "$HISTORY_FILE")"

# 1. 自動從剪貼簿讀取錯誤訊息
CLIPBOARD_TEXT=$(wl-paste 2>/dev/null || xclip -o 2>/dev/null)

# 讓使用者確認或修改抓到的錯誤訊息
ERROR_INPUT=$(zenity --entry --title="自動解析錯誤訊息" \
    --text="已從剪貼簿自動捕捉錯誤訊息，若有誤可直接修改：" \
    --entry-text="$CLIPBOARD_TEXT")

[ -z "$ERROR_INPUT" ] && exit 0

# 2. 自動從錯誤訊息中萃取出缺少的 .so 檔名
MISSING_LIB=$(echo "$ERROR_INPUT" | grep -oP '[a-zA-Z0-9_\-\.]+\.so(\.[0-9]+)*' | head -n 1)

if [ -z "$MISSING_LIB" ]; then
    zenity --error --text="無法從文字中自動辨識出缺少的 .so 檔案名稱，請確認你是否有複製到正確的錯誤訊息！"
    exit 0
fi

# 3. 尋找系統中對應的新版檔案
SUGGESTED_PATH=$(find /usr/lib -name "$(echo $MISSING_LIB | sed 's/\.so\..*/\.so/')" 2>/dev/null | head -n 1)
[ -z "$SUGGESTED_PATH" ] && SUGGESTED_PATH="/usr/lib/"

# 4. 讀取上次的歷史選擇（如果有記錄的話）
LAST_CHOICE=""
[ -f "$HISTORY_FILE" ] && LAST_CHOICE=$(cat "$HISTORY_FILE")

# 5. 彈出互動視窗，顯示分析結果與上次的建議
SELECTED_TARGET=$(zenity --entry --title="智慧修復分析結果" \
    --text="自動檢測到缺少的檔案: $MISSING_LIB\n\n[系統推薦對應的新版路徑]\n(上次選擇記錄: ${LAST_CHOICE:-無})\n\n請確認或修改要指向的正確路徑：" \
    --entry-text="${LAST_CHOICE:-$SUGGESTED_PATH}")

[ -z "$SELECTED_TARGET" ] && exit 0

# 6. 記住這次的選擇作為下次的歷史紀錄
echo "$SELECTED_TARGET" > "$HISTORY_FILE"

# 7. 自動建立軟連結
if pkexec ln -sf "$SELECTED_TARGET" "/usr/lib/$MISSING_LIB"; then
    zenity --info --text="成功建立智慧軟連結！\n\n/usr/lib/$MISSING_LIB\n-> $SELECTED_TARGET"
else
    zenity --error --text="建立失敗！"
fi
