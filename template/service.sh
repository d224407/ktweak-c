#!/system/bin/sh

MODDIR=${0%/*}

# Wait for boot
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 5
done

sleep 10

# Kiểm tra xem có kernel_tuner không
if [ -f "$MODPATH/system/bin/kernel_tuner" ]; then
    "$MODPATH/system/bin/kernel_tuner" > /dev/null 2>&1 &
else
    # Nếu không có, tìm binary đầu tiên
    for profile in budget latency throughput balance; do
        for suffix in _64 _32 _x64 _x86; do
            if [ -f "$MODPATH/system/bin/tuner_${profile}${suffix}" ]; then
                "$MODPATH/system/bin/tuner_${profile}${suffix}" > /dev/null 2>&1 &
                break 2
            fi
        done
    done
fi