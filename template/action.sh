#!/system/bin/sh

MODDIR=${0%/*}
LOG_FILE="/data/local/tmp/kernel_tuner.log"

ui_print() { echo "$1"; }

# Hàm chờ phím âm lượng (giống trong customize.sh)
wait_volume_key() {
    local timeout=30
    local key=""
    
    while [ $timeout -gt 0 ]; do
        for ev in /dev/input/event*; do
            if [ -r "$ev" ]; then
                local input=$(timeout 0.2 dd if="$ev" bs=32 count=1 2>/dev/null | hexdump -ve '1/1 "%02x "')
                if [ -n "$input" ]; then
                    if echo "$input" | grep -q "73 00 00 00 01 00 04 00 01 00 00 00"; then
                        echo "up"
                        return 0
                    elif echo "$input" | grep -q "72 00 00 00 01 00 04 00 01 00 00 00"; then
                        echo "down"
                        return 0
                    fi
                fi
            fi
        done
        sleep 0.2
        timeout=$((timeout - 1))
    done
    
    echo "timeout"
    return 0
}

# Hàm áp dụng profile
apply_profile() {
    local profile="$1"
    local suffix=""
    local arch=$(getprop ro.product.cpu.abi)
    
    case "$arch" in
        arm64-v8a|arm64) suffix="_64" ;;
        armeabi-v7a|armeabi) suffix="_32" ;;
        x86_64) suffix="_x64" ;;
        x86|i686|i586|i486|i386) suffix="_x86" ;;
        *)
            [ -f "$MODPATH/system/bin/tuner_${profile}_64" ] && suffix="_64"
            [ -f "$MODPATH/system/bin/tuner_${profile}_32" ] && suffix="_32"
            [ -f "$MODPATH/system/bin/tuner_${profile}_x64" ] && suffix="_x64"
            [ -f "$MODPATH/system/bin/tuner_${profile}_x86" ] && suffix="_x86"
            ;;
    esac
    
    local bin="$MODPATH/system/bin/tuner_${profile}${suffix}"
    if [ ! -f "$bin" ]; then
        ui_print "❌ Không tìm thấy binary cho profile $profile!"
        return 1
    fi
    
    ui_print "======================================"
    ui_print "  Đang áp dụng profile: $profile"
    ui_print "======================================"
    
    "$bin"
    
    if [ $? -eq 0 ]; then
        ui_print "✅ Profile $profile đã được áp dụng!"
        echo "$profile" > /data/local/tmp/current_profile
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Applied profile: $profile" >> "$LOG_FILE"
        return 0
    else
        ui_print "❌ Có lỗi xảy ra!"
        return 1
    fi
}

# Hàm chọn profile bằng phím âm lượng
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
        ui_print " Profile hiện tại: $(cat /data/local/tmp/current_profile 2>/dev/null || echo 'Chưa chọn')"
        ui_print ""
        
        for i in 0 1 2 3; do
            if [ $i -eq $current ]; then
                ui_print "  👉 ${names[$i]}"
            else
                ui_print "     ${names[$i]}"
            fi
        done
        
        ui_print ""
        ui_print "  [q] Thoát"
        ui_print "======================================"
        ui_print "  [Volume +] = Chọn  |  [Volume -] = Di chuyển"
        ui_print "======================================"
        
        # Đọc phím bấm với timeout ngắn hơn để check phím 'q'
        local key=$(wait_volume_key)
        
        case "$key" in
            "up")
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
                current=$((current + 1))
                if [ $current -gt $max ]; then
                    current=0
                fi
                ;;
            "timeout")
                # Timeout -> quay lại menu
                continue
                ;;
        esac
        
        # Kiểm tra phím 'q' từ input (đọc thêm)
        read -t 1 -r key_char 2>/dev/null
        if [ "$key_char" = "q" ] || [ "$key_char" = "Q" ]; then
            ui_print "Thoát!"
            exit 0
        fi
    done
    
    echo "$selected"
}

# Main
main() {
    # Nếu gọi với tham số profile
    if [ $# -gt 0 ]; then
        case "$1" in
            budget|latency|throughput|balance)
                apply_profile "$1"
                exit $?
                ;;
            *)
                ui_print "❌ Profile không hợp lệ: $1"
                ui_print "Các profile: budget, latency, throughput, balance"
                exit 1
                ;;
        esac
    fi
    
    # Chạy menu tương tác
    while true; do
        PROFILE=$(select_profile)
        if [ -n "$PROFILE" ]; then
            apply_profile "$PROFILE"
            ui_print ""
            ui_print "Nhấn Enter để tiếp tục hoặc 'q' để thoát..."
            read -t 3 -r key 2>/dev/null
            if [ "$key" = "q" ] || [ "$key" = "Q" ]; then
                ui_print "Thoát!"
                exit 0
            fi
        fi
    done
}

main "$@"