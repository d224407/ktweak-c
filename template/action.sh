#!/system/bin/sh

MODDIR=${0%/*}

ui_print() { echo "$1"; }

if [ $# -eq 0 ]; then
    ui_print "======================================"
    ui_print "  KTweak - Kernel Tuner"
    ui_print "======================================"
    ui_print " Usage: action.sh <profile>"
    ui_print " Profiles: budget, latency, throughput, balance"
    ui_print ""
    ui_print " Current profile: $(cat /data/local/tmp/current_ktweak_profile 2>/dev/null || echo 'none')"
    ui_print "======================================"
    exit 1
fi

PROFILE="$1"
BIN="$MODDIR/system/bin/ktweak_${PROFILE}"

if [ ! -f "$BIN" ]; then
    ui_print "❌ Profile '$PROFILE' not found!"
    exit 1
fi

ui_print "Applying profile: $PROFILE"
"$BIN"
if [ $? -eq 0 ]; then
    echo "$PROFILE" > /data/local/tmp/current_ktweak_profile
    ui_print "✅ $PROFILE applied successfully!"
else
    ui_print "❌ Failed to apply $PROFILE"
fi