#!/system/bin/sh

SKIPUNZIP=0

ui_print() { echo "$1"; }

# Hàm chờ phím âm lượng (dùng getevent hoặc dd)
wait_volume_key() {
    local timeout=30
    local key=""
    
    # Thử dùng getevent trước (nếu có)
    if command -v getevent >/dev/null 2>&1; then
        # Tìm thiết bị input hỗ trợ KEY_VOLUME
        local dev=""
        for d in /dev/input/event*; do
            if getevent -p "$d" 2>/dev/null | grep -q "KEY_VOLUME"; then
                dev="$d"
                break
            fi
        done
        if [ -n "$dev" ]; then
            local result=$(timeout 1 getevent -c 1 "$dev" 2>/dev/null | awk '{print $3}')
            case "$result" in
                "00000073") echo "up" ; return ;;
                "00000072") echo "down" ; return ;;
            esac
        fi
    fi
    
    # Fallback: đọc từ /dev/input/event*
    while [ $timeout -gt 0 ]; do
        for ev in /dev/input/event*; do
            if [ -r "$ev" ]; then
                local input=$(timeout 0.2 dd if="$ev" bs=32 count=1 2>/dev/null | hexdump -ve '1/1 "%02x "')
                if [ -n "$input" ]; then
                    if echo "$input" | grep -q "73 00 00 00 01 00 04 00 01 00 00 00"; then
                        echo "up"
                        return
                    elif echo "$input" | grep -q "72 00 00 00 01 00 04 00 01 00 00 00"; then
                        echo "down"
                        return
                    fi
                fi
            fi
        done
        sleep 0.2
        timeout=$((timeout - 1))
    done
    
    echo "timeout"
}

# Hàm chọn profile
select_profile() {
    local profiles="budget latency throughput balance"
    local names="Budget - Tiết kiệm pin|Latency - Độ trễ thấp|Throughput - Thông lượng cao|Balance - Cân bằng"
    local current=0
    local max=3
    local selected=""
    local idx=0
    local name=""
    
    while true; do
        clear 2>/dev/null || echo ""
        ui_print "======================================"
        ui_print "       KERNEL TUNER - CHỌN PROFILE    "
        ui_print "======================================"
        ui_print ""
        
        idx=0
        for p in $profiles; do
            name=$(echo "$names" | cut -d'|' -f$((idx+1)))
            if [ $idx -eq $current ]; then
                ui_print "  👉 $name"
            else
                ui_print "     $name"
            fi
            idx=$((idx + 1))
        done
        
        ui_print ""
        ui_print "======================================"
        ui_print "  [Volume +] = Chọn  |  [Volume -] = Di chuyển"
        ui_print "======================================"
        
        local key=$(wait_volume_key)
        
        case "$key" in
            "up")
                idx=0
                for p in $profiles; do
                    if [ $idx -eq $current ]; then
                        selected="$p"
                        break
                    fi
                    idx=$((idx + 1))
                done
                break
                ;;
            "down")
                current=$((current + 1))
                if [ $current -gt $max ]; then
                    current=0
                fi
                ;;
            "timeout")
                selected="budget"
                ui_print ""
                ui_print "⏱️  Timeout! Chọn mặc định: Budget"
                sleep 2
                break
                ;;
        esac
    done
    
    echo "$selected"
}

ui_print "======================================"
ui_print "       KERNEL TUNER - 4 PROFILES      "
ui_print "======================================"
ui_print ""

PROFILE=$(select_profile)

ui_print ""
ui_print "======================================"
ui_print "  ✅ Đã chọn profile: $PROFILE"
ui_print "======================================"

# Detect architecture
ARCH=$(getprop ro.product.cpu.abi)
case "$ARCH" in
    arm64-v8a|arm64)
        BIN_SUFFIX="_64"
        ui_print " Architecture: ARM64 (64-bit)"
        ;;
    armeabi-v7a|armeabi)
        BIN_SUFFIX="_32"
        ui_print " Architecture: ARMv7 (32-bit)"
        ;;
    x86_64)
        BIN_SUFFIX="_x64"
        ui_print " Architecture: x86_64 (64-bit)"
        ;;
    x86|i686|i586|i486|i386)
        BIN_SUFFIX="_x86"
        ui_print " Architecture: x86 (32-bit)"
        ;;
    *)
        if [ -f "$MODPATH/system/bin/tuner_budget_64" ]; then
            BIN_SUFFIX="_64"
            ui_print " Architecture: ARM64 (fallback)"
        elif [ -f "$MODPATH/system/bin/tuner_budget_32" ]; then
            BIN_SUFFIX="_32"
            ui_print " Architecture: ARMv7 (fallback)"
        else
            ui_print " ! No compatible binary found!"
            abort
        fi
        ;;
esac

# Copy binary
BIN_NAME="tuner_${PROFILE}${BIN_SUFFIX}"
if [ -f "$MODPATH/system/bin/$BIN_NAME" ]; then
    cp "$MODPATH/system/bin/$BIN_NAME" "$MODPATH/system/bin/kernel_tuner"
    chmod 755 "$MODPATH/system/bin/kernel_tuner"
    echo "$PROFILE" > /data/local/tmp/current_profile
    ui_print " Binary installed: $(ls -lh "$MODPATH/system/bin/kernel_tuner" | awk '{print $5}')"
else
    ui_print " ❌ Binary not found: $BIN_NAME"
    abort
fi

# Set permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/system/bin/kernel_tuner" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

ui_print ""
ui_print "======================================"
ui_print "  ✅ Profile $PROFILE đã được cài đặt!"
ui_print "======================================"
ui_print " Để đổi profile: chạy action.sh từ Magisk Manager"
ui_print " Log: /data/local/tmp/KernelTuner.log"
ui_print "======================================"