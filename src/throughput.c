/*
 * throughput.c – Kernel Tuning Profile (Throughput)
 * Dịch từ throughput.txt
 * Tối ưu cho thông lượng cao, xử lý nhiều tác vụ
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <time.h>
#include <stdarg.h>
#include <errno.h>
#include <limits.h>
#include <ctype.h>
#include <fcntl.h>
#include <stdint.h>

/* ==================== Định nghĩa hằng số ==================== */

#define LOG_FILE "/data/local/tmp/KernelTuner.log"
#define MAX_CMD_LEN 1024
#define MAX_PATH_LEN PATH_MAX
#define MAX_LINE_LEN 512

#define SCHED_PERIOD 10000000  // 10ms in nanoseconds
#define SCHED_TASKS 6
#define HISPEED_FREQ "4294967295"

// ... (các hàm safe_malloc, safe_free, safe_fclose, safe_snprintf, log_msg, safe_write_file, file_exists giống như budget.c)

static void apply_profile(void) {
    char buf[32];
    
    log_msg("========== Applying Throughput Profile ==========");
    
    // --- Kernel parameters ---
    safe_write_file("/proc/sys/kernel/perf_cpu_time_max_percent", "20");
    safe_write_file("/proc/sys/kernel/sched_autogroup_enabled", "0");
    safe_write_file("/proc/sys/kernel/sched_child_runs_first", "0");
    safe_write_file("/proc/sys/kernel/sched_tunable_scaling", "0");
    
    safe_snprintf(buf, sizeof(buf), "%d", SCHED_PERIOD);
    safe_write_file("/proc/sys/kernel/sched_latency_ns", buf);
    
    safe_snprintf(buf, sizeof(buf), "%d", SCHED_PERIOD / SCHED_TASKS);
    safe_write_file("/proc/sys/kernel/sched_min_granularity_ns", buf);
    
    safe_snprintf(buf, sizeof(buf), "%d", SCHED_PERIOD / 2);
    safe_write_file("/proc/sys/kernel/sched_wakeup_granularity_ns", buf);
    
    safe_write_file("/proc/sys/kernel/sched_migration_cost_ns", "5000000");
    safe_write_file("/proc/sys/kernel/sched_nr_migrate", "128");
    safe_write_file("/proc/sys/kernel/sched_schedstats", "0");
    safe_write_file("/proc/sys/kernel/printk_devkmsg", "off");
    
    // --- VM parameters ---
    safe_write_file("/proc/sys/vm/dirty_background_ratio", "15");
    safe_write_file("/proc/sys/vm/dirty_ratio", "30");
    safe_write_file("/proc/sys/vm/dirty_expire_centisecs", "3000");
    safe_write_file("/proc/sys/vm/dirty_writeback_centisecs", "3000");
    safe_write_file("/proc/sys/vm/page-cluster", "0");
    safe_write_file("/proc/sys/vm/stat_interval", "10");
    safe_write_file("/proc/sys/vm/swappiness", "100");
    safe_write_file("/proc/sys/vm/vfs_cache_pressure", "80");
    
    // --- Network parameters ---
    safe_write_file("/proc/sys/net/ipv4/tcp_ecn", "1");
    safe_write_file("/proc/sys/net/ipv4/tcp_fastopen", "3");
    safe_write_file("/proc/sys/net/ipv4/tcp_syncookies", "0");
    
    // --- sched_features ---
    if (file_exists("/sys/kernel/debug/sched_features")) {
        safe_write_file("/sys/kernel/debug/sched_features", "NEXT_BUDDY");
        safe_write_file("/sys/kernel/debug/sched_features", "TTWU_QUEUE");
    }
    
    // --- STUNE ---
    if (file_exists("/dev/stune/top-app/schedtune.prefer_idle")) {
        safe_write_file("/dev/stune/top-app/schedtune.prefer_idle", "0");
        safe_write_file("/dev/stune/top-app/schedtune.boost", "1");
    }
    
    // --- CPU Governor ---
    DIR *dir = opendir("/sys/devices/system/cpu");
    if (dir) {
        struct dirent *ent;
        char path[MAX_PATH_LEN];
        char avail[MAX_PATH_LEN];
        char gov[MAX_PATH_LEN];
        char content[256];
        FILE *fp;
        
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "cpu", 3) != 0 || !isdigit(ent->d_name[3])) continue;
            
            safe_snprintf(path, sizeof(path), "/sys/devices/system/cpu/%s/cpufreq", ent->d_name);
            if (!file_exists(path)) continue;
            
            safe_snprintf(avail, sizeof(avail), "%s/scaling_available_governors", path);
            if (!file_exists(avail)) continue;
            
            fp = fopen(avail, "r");
            if (fp) {
                if (fgets(content, sizeof(content), fp)) {
                    if (strstr(content, "schedutil")) {
                        safe_snprintf(gov, sizeof(gov), "%s/scaling_governor", path);
                        safe_write_file(gov, "schedutil");
                    } else if (strstr(content, "interactive")) {
                        safe_snprintf(gov, sizeof(gov), "%s/scaling_governor", path);
                        safe_write_file(gov, "interactive");
                    }
                }
                safe_fclose(&fp);
            }
        }
        closedir(dir);
    }
    
    // --- schedutil tunables ---
    if (file_exists("/sys/devices/system/cpu/cpufreq/policy0/schedutil")) {
        safe_snprintf(buf, sizeof(buf), "%d", SCHED_PERIOD / 1000);
        safe_write_file("/sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us", buf);
        safe_snprintf(buf, sizeof(buf), "%d", 4 * SCHED_PERIOD / 1000);
        safe_write_file("/sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us", buf);
        safe_snprintf(buf, sizeof(buf), "%d", SCHED_PERIOD / 1000);
        safe_write_file("/sys/devices/system/cpu/cpufreq/policy0/schedutil/rate_limit_us", buf);
        safe_write_file("/sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load", "85");
        safe_write_file("/sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq", HISPEED_FREQ);
    }
    
    // --- I/O Scheduler ---
    DIR *block_dir = opendir("/sys/block");
    if (block_dir) {
        struct dirent *ent;
        char queue_path[MAX_PATH_LEN];
        char sched_path[MAX_PATH_LEN];
        char content[256];
        FILE *fp;
        
        while ((ent = readdir(block_dir)) != NULL) {
            if (ent->d_name[0] == '.') continue;
            
            safe_snprintf(queue_path, sizeof(queue_path), "/sys/block/%s/queue", ent->d_name);
            if (!file_exists(queue_path)) continue;
            
            safe_snprintf(sched_path, sizeof(sched_path), "%s/scheduler", queue_path);
            if (!file_exists(sched_path)) continue;
            
            fp = fopen(sched_path, "r");
            if (fp) {
                if (fgets(content, sizeof(content), fp)) {
                    const char *scheds[] = {"cfq", "noop", "kyber", "bfq", "mq-deadline", "none"};
                    for (int i = 0; i < 6; i++) {
                        if (strstr(content, scheds[i])) {
                            safe_write_file(sched_path, scheds[i]);
                            break;
                        }
                    }
                }
                safe_fclose(&fp);
            }
            
            safe_snprintf(sched_path, sizeof(sched_path), "%s/add_random", queue_path);
            safe_write_file(sched_path, "0");
            safe_snprintf(sched_path, sizeof(sched_path), "%s/iostats", queue_path);
            safe_write_file(sched_path, "0");
            safe_snprintf(sched_path, sizeof(sched_path), "%s/read_ahead_kb", queue_path);
            safe_write_file(sched_path, "256");
            safe_snprintf(sched_path, sizeof(sched_path), "%s/nr_requests", queue_path);
            safe_write_file(sched_path, "512");
        }
        closedir(block_dir);
    }
    
    log_msg("========== Throughput Profile Applied ==========");
}

int main(int argc, char **argv) {
    log_msg("Kernel Tuner - Throughput Profile");
    apply_profile();
    return 0;
}