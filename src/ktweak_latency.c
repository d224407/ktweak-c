/*
 * latency.c – Kernel Tuning Profile (Latency)
 * Tối ưu cho độ trễ thấp, phản hồi nhanh
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

#define LOG_FILE "/data/local/tmp/KernelTuner.log"
#define MAX_LINE_LEN 512
#define MAX_PATH_LEN PATH_MAX

#define SCHED_PERIOD 1000000
#define SCHED_TASKS 10
#define HISPEED_FREQ "4294967295"

static void safe_fclose(FILE **fp) {
    if (fp && *fp) {
        fclose(*fp);
        *fp = NULL;
    }
}

static void log_msg(const char *fmt, ...) {
    if (!fmt) return;
    
    char buffer[MAX_LINE_LEN];
    char time_str[32];
    time_t t;
    struct tm *tm_info;
    va_list args;
    FILE *fp = NULL;
    
    time(&t);
    tm_info = localtime(&t);
    if (!tm_info) {
        strcpy(time_str, "[??:??:??]");
    } else {
        strftime(time_str, sizeof(time_str), "[%H:%M:%S]", tm_info);
    }
    
    va_start(args, fmt);
    vsnprintf(buffer, sizeof(buffer), fmt, args);
    va_end(args);
    buffer[sizeof(buffer) - 1] = '\0';
    
    printf("%s %s\n", time_str, buffer);
    
    fp = fopen(LOG_FILE, "a");
    if (fp) {
        fprintf(fp, "%s %s\n", time_str, buffer);
        safe_fclose(&fp);
    }
}

static int safe_write_file(const char *path, const char *value) {
    if (!path || !value) return -1;
    
    FILE *fp = NULL;
    struct stat st;
    int result = -1;
    mode_t original_mode = 0;
    char read_buffer[MAX_LINE_LEN] = {0};
    
    if (stat(path, &st) != 0) {
        return -1;
    }
    
    if (!S_ISREG(st.st_mode)) {
        return -1;
    }
    
    original_mode = st.st_mode & 0777;
    
    if (access(path, W_OK) != 0) {
        chmod(path, original_mode | S_IWUSR);
    }
    
    fp = fopen(path, "w");
    if (!fp) {
        log_msg("Failed to open %s for writing", path);
        goto cleanup;
    }
    
    if (fprintf(fp, "%s\n", value) < 0) {
        log_msg("Failed to write to %s", path);
        goto cleanup;
    }
    
    safe_fclose(&fp);
    
    fp = fopen(path, "r");
    if (!fp) {
        goto cleanup;
    }
    
    if (fgets(read_buffer, sizeof(read_buffer), fp)) {
        size_t len = strlen(read_buffer);
        while (len > 0 && (read_buffer[len-1] == '\n' || read_buffer[len-1] == '\r')) {
            read_buffer[--len] = '\0';
        }
        if (strcmp(read_buffer, value) == 0) {
            result = 0;
        }
    }
    
cleanup:
    safe_fclose(&fp);
    
    if (original_mode > 0) {
        chmod(path, original_mode);
    }
    
    return result;
}

static int safe_snprintf(char *buffer, size_t size, const char *format, ...) {
    if (!buffer || size == 0) return -1;
    va_list args;
    va_start(args, format);
    int result = vsnprintf(buffer, size, format, args);
    va_end(args);
    if (result < 0 || (size_t)result >= size) {
        buffer[size - 1] = '\0';
        return -1;
    }
    return result;
}

static int file_exists(const char *path) {
    if (!path) return 0;
    struct stat st;
    return stat(path, &st) == 0;
}

static void apply_profile(void) {
    char buf[32];
    
    log_msg("========== Applying Latency Profile ==========");
    
    safe_write_file("/proc/sys/kernel/perf_cpu_time_max_percent", "3");
    safe_write_file("/proc/sys/kernel/sched_autogroup_enabled", "1");
    safe_write_file("/proc/sys/kernel/sched_child_runs_first", "1");
    safe_write_file("/proc/sys/kernel/sched_tunable_scaling", "0");
    
    safe_snprintf(buf, sizeof(buf), "%d", SCHED_PERIOD);
    safe_write_file("/proc/sys/kernel/sched_latency_ns", buf);
    
    safe_snprintf(buf, sizeof(buf), "%d", SCHED_PERIOD / SCHED_TASKS);
    safe_write_file("/proc/sys/kernel/sched_min_granularity_ns", buf);
    
    safe_snprintf(buf, sizeof(buf), "%d", SCHED_PERIOD / 2);
    safe_write_file("/proc/sys/kernel/sched_wakeup_granularity_ns", buf);
    
    safe_write_file("/proc/sys/kernel/sched_migration_cost_ns", "5000000");
    safe_write_file("/proc/sys/kernel/sched_nr_migrate", "4");
    safe_write_file("/proc/sys/kernel/sched_schedstats", "0");
    safe_write_file("/proc/sys/kernel/printk_devkmsg", "off");
    
    safe_write_file("/proc/sys/vm/dirty_background_ratio", "3");
    safe_write_file("/proc/sys/vm/dirty_ratio", "30");
    safe_write_file("/proc/sys/vm/dirty_expire_centisecs", "3000");
    safe_write_file("/proc/sys/vm/dirty_writeback_centisecs", "3000");
    safe_write_file("/proc/sys/vm/page-cluster", "0");
    safe_write_file("/proc/sys/vm/stat_interval", "10");
    safe_write_file("/proc/sys/vm/swappiness", "100");
    safe_write_file("/proc/sys/vm/vfs_cache_pressure", "200");
    
    safe_write_file("/proc/sys/net/ipv4/tcp_ecn", "1");
    safe_write_file("/proc/sys/net/ipv4/tcp_fastopen", "3");
    safe_write_file("/proc/sys/net/ipv4/tcp_syncookies", "0");
    
    if (file_exists("/sys/kernel/debug/sched_features")) {
        safe_write_file("/sys/kernel/debug/sched_features", "NEXT_BUDDY");
        safe_write_file("/sys/kernel/debug/sched_features", "NO_TTWU_QUEUE");
    }
    
    if (file_exists("/dev/stune/top-app/schedtune.prefer_idle")) {
        safe_write_file("/dev/stune/top-app/schedtune.prefer_idle", "1");
        safe_write_file("/dev/stune/top-app/schedtune.boost", "1");
    }
    
    DIR *dir = opendir("/sys/devices/system/cpu");
    if (dir) {
        struct dirent *ent;
        char path[MAX_PATH_LEN], avail[MAX_PATH_LEN], gov[MAX_PATH_LEN];
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
    
    if (file_exists("/sys/devices/system/cpu/cpufreq/policy0/schedutil")) {
        safe_write_file("/sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us", "0");
        safe_write_file("/sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us", "0");
        safe_write_file("/sys/devices/system/cpu/cpufreq/policy0/schedutil/rate_limit_us", "0");
        safe_write_file("/sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load", "85");
        safe_write_file("/sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq", HISPEED_FREQ);
    }
    
    DIR *block_dir = opendir("/sys/block");
    if (block_dir) {
        struct dirent *ent;
        char queue_path[MAX_PATH_LEN], sched_path[MAX_PATH_LEN];
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
            safe_write_file(sched_path, "32");
            safe_snprintf(sched_path, sizeof(sched_path), "%s/nr_requests", queue_path);
            safe_write_file(sched_path, "32");
        }
        closedir(block_dir);
    }
    
    log_msg("========== Latency Profile Applied ==========");
}

int main(void) {
    log_msg("Kernel Tuner - Latency Profile");
    apply_profile();
    return 0;
}