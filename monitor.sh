#!/bin/bash

# Limit in MB
DATA_LIMIT=1200

# 1. Network Interface detection
INTERFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)

# 2. System Usage (Always calculated)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
RAM_USAGE=$(free | grep Mem | awk '{printf "%.0f%", $3/$2 * 100}')

# 3. Logic: Check if Online
if [ -n "$INTERFACE" ]; then
    
    # --- ONLINE MODE: Calculate everything ---
    
    # Get Speeds
    R1=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    T1=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null || echo 0)
    sleep 1
    R2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    T2=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null || echo 0)

    RX=$(( ($R2 - $R1) / 1024 ))
    TX=$(( ($T2 - $T1) / 1024 ))

    format_speed() {
        if [ "$1" -ge 1024 ]; then
            echo "$(echo "scale=1; $1/1024" | bc)M"
        else
            echo "${1}K"
        fi
    }

    D_SPEED=$(format_speed $RX)
    U_SPEED=$(format_speed $TX)

    # Get Total Data
	  TOTAL_DATA=$(vnstat -i $INTERFACE --oneline 2>/dev/null | cut -d';' -f6 | sed 's/iB//g; s/ //g')
	  
	  FLAG_FILE="/tmp/data_alert_$(date +%Y-%m-%d)"

	  if [ ! -f "$FLAG_FILE" ]; then
		  LIMIT=$(sed 's/[MG]//g' <<< "$TOTAL_DATA")

		  # Corrected comparison: Pass the comparison string TO bc
		  if (( $(echo "$LIMIT > $DATA_LIMIT" | bc -l) )); then
		      notify-send "📶 Data Limit Reached" "You used ${LIMIT} MB today!"
		      
		      sudo -u $USER XDG_RUNTIME_DIR="/run/user/$(id -u $USER)" \
		      paplay /usr/share/sounds/freedesktop/stereo/message-new-instant.oga

		      touch "$FLAG_FILE"
		  fi
	  fi

    [ -z "$TOTAL_DATA" ] && TOTAL_DATA="0B"

    # Panel Output (Full)
    echo "<txt>⬇$D_SPEED ⬆$U_SPEED | Σ:$TOTAL_DATA | C:$CPU_USAGE | M:$RAM_USAGE </txt>"
    echo "<tool>Total Data Today: $TOTAL_DATA</tool>"

else
    # --- OFFLINE MODE: Minimal output ---
    echo "<txt>C:$CPU_USAGE | M:$RAM_USAGE </txt>"
    echo "<tool>No internet connection detected</tool>"
fi