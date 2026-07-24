#!/system/bin/sh

rm -f /data/local/tmp/current_ktweak_profile
rm -f /data/local/tmp/ktweak_service.log
rm -f /data/local/tmp/KernelTuner.log

echo "KTweak uninstalled at $(date)" > /data/local/tmp/ktweak_uninstall.log