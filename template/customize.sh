#!/system/bin/sh

SKIPUNZIP=0

ui_print() { echo "$1"; }

ui_print "======================================"
ui_print "       KTweak - Kernel Tuner          "
ui_print "======================================"
ui_print ""

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
        if [ -f "$MODPATH/system/bin/ktweak_budget_64" ]; then
            BIN_SUFFIX="_64"
            ui_print " Architecture: ARM64 (fallback)"
        elif [ -f "$MODPATH/system/bin/ktweak_budget_32" ]; then
            BIN_SUFFIX="_32"
            ui_print " Architecture: ARMv7 (fallback)"
        else
            ui_print " ! No compatible binary found!"
            abort
        fi
        ;;
esac

# Chọn profile mặc định là Budget khi cài đặt (người dùng có thể đổi qua WebUI sau)
PROFILE="budget"

# Copy binary
BIN_NAME="ktweak_${PROFILE}${BIN_SUFFIX}"
if [ -f "$MODPATH/system/bin/$BIN_NAME" ]; then
    cp "$MODPATH/system/bin/$BIN_NAME" "$MODPATH/system/bin/ktweak"
    chmod 755 "$MODPATH/system/bin/ktweak"
    echo "$PROFILE" > /data/local/tmp/current_ktweak_profile
    ui_print " Binary installed: $(ls -lh "$MODPATH/system/bin/ktweak" | awk '{print $5}')"
else
    ui_print " ❌ Binary not found: $BIN_NAME"
    abort
fi

# Copy WebUI
if [ -d "$MODPATH/webroot" ]; then
    set_perm_recursive "$MODPATH/webroot" 0 0 0755 0644
    ui_print " WebUI installed"
fi

# Set permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/system/bin/ktweak" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

ui_print ""
ui_print "======================================"
ui_print "  ✅ KTweak installed successfully!"
ui_print "  Default profile: Budget"
ui_print "  Change via WebUI in KernelSU/Magisk"
ui_print "======================================"