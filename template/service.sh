#!/system/bin/sh

MODDIR=${0%/*}

# Wait for boot
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 5
done

sleep 10

# Check current profile
PROFILE=$(cat /data/local/tmp/current_ktweak_profile 2>/dev/null)
if [ -z "$PROFILE" ]; then
    PROFILE="budget"
    echo "$PROFILE" > /data/local/tmp/current_ktweak_profile
fi

# Run corresponding binary
BIN="$MODDIR/system/bin/ktweak_${PROFILE}"
if [ -f "$BIN" ]; then
    "$BIN" > /dev/null 2>&1 &
else
    # Fallback to main ktweak
    "$MODDIR/system/bin/ktweak" > /dev/null 2>&1 &
fi

echo "KTweak service started at $(date)" > /data/local/tmp/ktweak_service.log