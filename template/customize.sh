#!/system/bin/sh

SKIPUNZIP=0

ui_print() { echo "$1"; }

# Hàm chờ người dùng bấm phím âm lượng
wait_volume_key() {
    local timeout=30
    local key=""
    
    ui_print "  Vui lòng dùng phím âm lượng để chọn:"
    ui_print "  [Volume +] = Chọn  |  [Volume -] = Di chuyển"
    ui_print ""
    
    # Đọc sự kiện phím từ /dev/input/event*
    while [ $timeout -gt 0 ]; do
        # Tìm thiết bị input
        for ev in /dev/input/event*; do
            if [ -r "$ev" ]; then
                # Đọc sự kiện trong 0.2 giây
                local input=$(timeout 0.2 dd if="$ev" bs=32 count=1 2>/dev/null | hexdump -ve '1/1 "%02x "')
                if [ -n "$input" ]; then
                    # Volume Up (key 115) hoặc Volume Down (key 114)
                    if echo "$input" | grep -q "73 00 00 00 01 00 04 00 01 00 00 00"; then
                        # KEY_VOLUMEUP = 115
                        echo "up"
                        return 0
                    elif echo "$input" | grep -q "72 00 00 00 01 00 04 00 01 00 00 00"; then
                        # KEY_VOLUMEDOWN = 114
                        echo "down"
                        return 0
                    fi
                fi
            fi
        done
        sleep 0.2
        timeout=$((timeout - 1))
    done
    
    # Timeout -> chọn mặc định (Budget)
    echo "timeout"
    return 0
}

# Hàm hiển thị menu và chọn profile
select_profile() {
    local profiles="budget latency throughput balance"
    local names=("Budget - Tiết kiệm pin, thiết bị yếu" 
                 "Latency - Ưu tiên độ trễ thấp" 
                 "Throughput - Ưu tiên thông lượng cao" 
                 "Balance - Cân bằng")
    local current=0
    local max=3
    local selected=""
    
    while true; do
        clear 2>/dev/null || echo ""
        ui_print "======================================"
        ui_print "       KERNEL TUNER - CHỌN PROFILE    "
        ui_print "======================================"
        ui_print ""
        
        for i in 0 1 2 3; do
            if [ $i -eq $current ]; then
                ui_print "  👉 ${names[$i]}"
            else
                ui_print "     ${names[$i]}"
            fi
        done
        
        ui_print ""
        ui_print "======================================"
        ui_print "  [Volume +] = Chọn  |  [Volume -] = Di chuyển"
        ui_print "======================================"
        
        local key=$(wait_volume_key)
        
        case "$key" in
            "up")
                # Volume Up = Chọn profile hiện tại
                selected="${profiles##* }"
                # Lấy profile tại vị trí current
                local idx=0
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
                # Volume Down = Di chuyển xuống
                current=$((current + 1))
                if [ $current -gt $max ]; then
                    current=0
                fi
                ;;
            "timeout")
                # Timeout -> chọn Budget
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

# Chọn profile
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