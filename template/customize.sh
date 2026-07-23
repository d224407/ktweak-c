#!/system/bin/sh

SKIPUNZIP=0

ui_print() { echo "$1"; }

ui_print "======================================"
ui_print "       KERNEL TUNER - 4 PROFILES      "
ui_print "======================================"
ui_print ""
ui_print "Chọn profile bạn muốn áp dụng:"
ui_print ""
ui_print "  [1] Budget     - Tiết kiệm pin, thiết bị yếu"
ui_print "  [2] Latency    - Ưu tiên độ trễ thấp, phản hồi nhanh"
ui_print "  [3] Throughput - Ưu tiên thông lượng cao"
ui_print "  [4] Balance    - Cân bằng giữa latency và throughput"
ui_print "  [5] Để trống (không áp dụng, sẽ chọn sau qua action.sh)"
ui_print ""
ui_print "======================================"

# Chờ người dùng nhập
PROFILE=""
while [ -z "$PROFILE" ]; do
    ui_print -n "Nhập số (1-5): "
    read -r choice 2>/dev/null
    case "$choice" in
        1) PROFILE="budget" ;;
        2) PROFILE="latency" ;;
        3) PROFILE="throughput" ;;
        4) PROFILE="balance" ;;
        5) PROFILE="none" ;;
        *) ui_print "Lựa chọn không hợp lệ! Vui lòng nhập 1-5." ;;
    esac
done

ui_print ""
ui_print "======================================"
if [ "$PROFILE" = "none" ]; then
    ui_print "  Bỏ qua áp dụng profile. Chọn sau qua action.sh"
else
    ui_print "  Đã chọn profile: $PROFILE"
fi
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

# Nếu chọn profile cụ thể, copy binary tương ứng và đặt tên kernel_tuner
if [ "$PROFILE" != "none" ]; then
    BIN_NAME="tuner_${PROFILE}${BIN_SUFFIX}"
    cp "$MODPATH/system/bin/$BIN_NAME" "$MODPATH/system/bin/kernel_tuner"
    chmod 755 "$MODPATH/system/bin/kernel_tuner"
    
    # Lưu profile đã chọn
    echo "$PROFILE" > /data/local/tmp/current_profile
else
    # Tạo file kernel_tuner giả (sẽ không dùng)
    touch "$MODPATH/system/bin/kernel_tuner"
    chmod 755 "$MODPATH/system/bin/kernel_tuner"
fi

# Remove all other binaries (giữ lại để action.sh có thể chọn)
# KHÔNG xóa các binary khác để action.sh có thể chọn profile khác

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/system/bin/tuner_"* 0 0 0755
set_perm "$MODPATH/system/bin/kernel_tuner" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

ui_print ""
ui_print "======================================"
if [ "$PROFILE" = "none" ]; then
    ui_print "  Cài đặt hoàn tất! Chạy action.sh để chọn profile"
else
    ui_print "  Profile $PROFILE đã được cài đặt!"
fi
ui_print "======================================"
ui_print " Để đổi profile: chạy action.sh từ Magisk Manager"
ui_print " Log: /data/local/tmp/kernel_tuner.log"
ui_print "======================================"