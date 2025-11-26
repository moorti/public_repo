#!/bin/bash

URL="https://example.local"
SERVICE=("tomcat" "httpd")
LINE_COUNT=$(curl -sk "$URL" | wc -l)
HTTP_CODE=$(curl -sko /dev/null -w "%{http_code}" "$URL")
LOGFILE=/root/watchdog.log
ROTATE_SIZE=((5*1024*1024))
ROTATE_COUNT=5

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

#Log rotation

rotate_log_if_needed() {
  local size
  if [[ -f "$LOGFILE" ]]; then
    size=$(stat -c%s "$LOGFILE" 2>/dev/null || echo 0 )
  else
    return
  fi

  if (( size >= ROTATE_SIZE )); then
    for (( i=ROTATE_COUNT-1; i>=1; i--)); do
      if [[ -f "${LOGFILE}.${i}.gz" ]]; then
        mv -f "${LOGFILE}.${i}.gz" "${LOGFILE}.$((i+1)).gz"
      fi
  done

    mv -f "${LOGFILE}" "${LOGFILE}.1"
    gzip -f "${LOGFILE}.1"

    : > "${LOGFILE}"
  fi
}

rotate_log_if_needed()

#HTTP code check and service restart

if [[ "$HTTP_CODE| != "200" ]]; then
  echo "$(timestamp) Bad HTTP code: $HTTP_CODE (expected 200). Restarting $SERVICE..." >> $LOGFILE
  systemctl restart "${SERVICE[X]}"
else
  echo "$(timestamp) Normal HTTP code: $HTTP_CODE. No restart needed." >> $LOGFILE
fi
