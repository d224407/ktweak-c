#!/system/bin/sh

MODDIR=${0%/*}
LOG_FILE="/data/local/tmp/kernel_tuner.log"

ui_print() { echo "$1"; }

# Hàm kiểm tra binary có tồn tại không
check_binary() {
    local profile="$1"
    local arch=$(getprop ro.product.cpu.abi)
    local suffix=""
    
    case "$arch" in
        arm64-v8a|arm64) suffix="_64" ;;
        armeabi-v7a|armeabi) suffix="_32" ;;
        x86_64) suffix="_x64" ;;
        x86|i686|i586|i486|i386) suffix="_x86" ;;
        *)
            if [ -f "$MODPATH/system/bin/tuner_${profile}_64" ]; then
                suffix="_64"
            elif [ -f "$MODPATH/system/bin/tuner_${profile}_32" ]; then
                suffix="_32"
            else
                return 1
            fi
            ;;
    esac
    
    if [ -f "$MODPATH/system/bin/tuner_${profile}${suffix}" ]; then
        echo "$MODPATH/system/bin/tuner_${profile}${suffix}"
        return 0
    fi
    return 1
}

# Hàm áp dụng profile
apply_profile() {
    local profile="$1"
    local bin_path
    
    bin_path=$(check_binary "$profile")
    if [ -z "$bin_path" ]; then
        ui_print "❌ Không tìm thấy binary cho profile $profile!"
        return 1
    fi
    
    ui_print "======================================"
    ui_print "  Đang áp dụng profile: $profile"
    ui_print "======================================"
    
    # Chạy binary
    "$bin_path"
    
    if [ $? -eq 0 ]; then
        ui_print "✅ Profile $profile đã được áp dụng!"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Applied profile: $profile" >> "$LOG_FILE"
    else
        ui_print "❌ Có lỗi xảy ra khi áp dụng profile $profile!"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR applying profile: $profile" >> "$LOG_FILE"
        return 1
    fi
    
    return 0
}

# Hiển thị menu
show_menu() {
    clear 2>/dev/null || echo ""
    ui_print "======================================"
    ui_print "       KERNEL TUNER - CHỌN PROFILE    "
    ui_print "======================================"
    ui_print ""
    ui_print "  Profile hiện tại: $(cat /data/local/tmp/current_profile 2>/dev/null || echo "Chưa chọn")"
    ui_print ""
    ui_print "  [1] Budget     - Tiết kiệm pin, thiết bị yếu"
    ui_print "  [2] Latency    - Ưu tiên độ trễ thấp, phản hồi nhanh"
    ui_print "  [3] Throughput - Ưu tiên thông lượng cao"
    ui_print "  [4] Balance    - Cân bằng giữa latency và throughput"
    ui_print "  [5] Xem log"
    ui_print "  [q] Thoát"
    ui_print ""
    ui_print "======================================"
    ui_print -n "Nhập lựa chọn (1-5/q): "
}

# Xem log
view_log() {
    if [ -f "$LOG_FILE" ]; then
        ui_print "======================================"
        ui_print "  LOG KERNEL TUNER"
        ui_print "======================================"
        tail -n 20 "$LOG_FILE"
        ui_print ""
        ui_print "======================================"
        ui_print -n "Nhấn Enter để tiếp tục..."
        read -r dummy 2>/dev/null
    else
        ui_print "❌ Chưa có log nào!"
        sleep 2
    fi
}

# Main
main() {
    # Kiểm tra xem có đang chạy với tham số không (gọi trực tiếp profile)
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
        show_menu
        read -r choice 2>/dev/null
        
        case "$choice" in
            1) apply_profile "budget" && echo "budget" > /data/local/tmp/current_profile ;;
            2) apply_profile "latency" && echo "latency" > /data/local/tmp/current_profile ;;
            3) apply_profile "throughput" && echo "throughput" > /data/local/tmp/current_profile ;;
            4) apply_profile "balance" && echo "balance" > /data/local/tmp/current_profile ;;
            5) view_log ;;
            q|Q) ui_print "Thoát!"; exit 0 ;;
            *) ui_print "❌ Lựa chọn không hợp lệ! Vui lòng nhập 1-5 hoặc q."; sleep 1 ;;
        esac
        
        if [ "$choice" != "5" ] && [ "$choice" != "q" ] && [ "$choice" != "Q" ]; then
            ui_print ""
            ui_print -n "Nhấn Enter để tiếp tục..."
            read -r dummy 2>/dev/null
        fi
    done
}

main "$@"