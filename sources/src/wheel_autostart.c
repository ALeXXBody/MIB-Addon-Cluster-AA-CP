/*
 * wheel_autostart - start the steering-wheel listener at gal start.
 *
 * Zero-press rule: after install + the one reboot the install already
 * needs, the wheel works with no switch. The listener is enabled unless
 * GAL_WHEEL_LISTEN=0 (opt OUT, so the common case spends no slot in the
 * ~10-entry supervisor env array whose overflow silently drops the whole
 * injection). When disabled, or the binary is absent, or a listener is
 * already alive, this is a cheap no-op: one getenv, at most one pid read
 * and a few access() probes. Nothing here may change behaviour for units
 * that never enable the wheel.
 *
 * The child is fully detached (own session, no zombie, stdio on
 * /dev/null + /tmp/gal_wheel.out) so gal never waits on it and a crash
 * leaves no zombie behind. Pure decision logic is host-testable
 * (sources/tests/wheel_autostart_test.c); the spawn itself is QNX-only.
 */
#include "wheel_autostart.h"

#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifdef __QNX__
#include <spawn.h>
#endif

/* Where the installer stages the listener, in every view spelling a gal
 * node may see. First X_OK hit wins; the FAT card copy is never run. */
static const char *const wl_candidates[] = {
    "/mnt/app/eso/lib/gal_dualscreen/wheel_listen",
    "/net/mmx.mibhigh.net/mnt/app/eso/lib/gal_dualscreen/wheel_listen",
    "/net/mmx/mnt/app/eso/lib/gal_dualscreen/wheel_listen",
    "/net/rcc/mnt/app/eso/lib/gal_dualscreen/wheel_listen",
    "/eso/lib/gal_dualscreen/wheel_listen",
    NULL
};

#define WL_PID_FILE "/tmp/gal_wheellisten.pid"
#define WL_FLAG_FILE "/tmp/gal_wheellisten"
#define WL_OUT_FILE "/tmp/gal_wheel.out"

/* Enabled unless explicitly "0". Missing, empty and "1" all start it:
 * fresh installs carry no key and must just work. */
int wheel_want_start(const char *env_value)
{
    if (env_value != NULL && strcmp(env_value, "0") == 0)
        return 0;
    return 1;
}

/* First candidate the probe accepts, or NULL. */
const char *wheel_pick_binary(int (*x_ok)(const char *path))
{
    int i;
    if (x_ok == NULL)
        return NULL;
    for (i = 0; wl_candidates[i] != NULL; i++) {
        if (x_ok(wl_candidates[i]) == 0)
            return wl_candidates[i];
    }
    return NULL;
}

static int wl_x_ok(const char *path)
{
    return access(path, X_OK);
}

/* 1 when the pid file names a live process. Stale/unreadable/garbage -> 0. */
int wheel_pid_alive(void)
{
    FILE *f = fopen(WL_PID_FILE, "r");
    char buf[32];
    long pid;
    char *end;
    if (f == NULL)
        return 0;
    if (fgets(buf, sizeof buf, f) == NULL) {
        fclose(f);
        return 0;
    }
    fclose(f);
    pid = strtol(buf, &end, 10);
    if (end == buf || pid <= 0)
        return 0;
    if (kill((pid_t)pid, 0) == 0)
        return 1;
    return 0;
}

#ifdef __QNX__
static void wl_write_file(const char *path, const char *text)
{
    FILE *f = fopen(path, "w");
    if (f == NULL)
        return;
    fputs(text, f);
    fclose(f);
}
#endif

#ifdef __QNX__
/* Detached spawn: own session, no zombie, stdio contained. Returns the
 * child pid, or -1. Never waits: gal must never block on the listener. */
static pid_t wl_spawn_daemon(const char *path)
{
    struct inheritance inherit;
    int null_fd;
    int out_fd;
    int map[3];
    pid_t pid;
    static char *const argv[] = { "wheel_listen", NULL };
    static char *const envp[] = { "PATH=/bin:/usr/bin", NULL };

    null_fd = open("/dev/null", O_RDWR);
    out_fd = open(WL_OUT_FILE, O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (null_fd < 0 || out_fd < 0) {
        if (null_fd >= 0)
            close(null_fd);
        if (out_fd >= 0)
            close(out_fd);
        return -1;
    }
    map[0] = null_fd;
    map[1] = out_fd;
    map[2] = out_fd;
    memset(&inherit, 0, sizeof inherit);
    inherit.flags = SPAWN_SETSIGMASK | SPAWN_NOZOMBIE | SPAWN_SETSID;
    sigemptyset(&inherit.sigmask);
    pid = spawn(path, 3, map, &inherit, argv, envp);
    close(null_fd);
    close(out_fd);
    return pid;
}
#endif

/* Called once from gal_hook_init. Logs one event=wheel.spawn line so the
 * diag shows whether autostart fired, skipped, or failed. */
void wheel_autostart(void (*logf)(const char *format, ...))
{
    const char *bin;
    char pidbuf[32];
#ifdef __QNX__
    pid_t pid;
#endif

    if (!wheel_want_start(getenv("GAL_WHEEL_LISTEN"))) {
        logf("event=wheel.spawn result=skipped reason=disabled");
        return;
    }
    if (wheel_pid_alive()) {
        logf("event=wheel.spawn result=skipped reason=already_running");
        return;
    }
    bin = wheel_pick_binary(wl_x_ok);
    if (bin == NULL) {
        logf("event=wheel.spawn result=skipped reason=no_binary");
        return;
    }
#ifdef __QNX__
    pid = wl_spawn_daemon(bin);
    if (pid < 0) {
        logf("event=wheel.spawn result=failed path=%s", bin);
        return;
    }
    snprintf(pidbuf, sizeof pidbuf, "%ld\n", (long)pid);
    wl_write_file(WL_PID_FILE, pidbuf);
    wl_write_file(WL_FLAG_FILE, "1\n");
    logf("event=wheel.spawn result=started path=%s pid=%ld", bin, (long)pid);
#else
    (void)pidbuf;
    logf("event=wheel.spawn result=skipped reason=no_qnx_spawn path=%s", bin);
#endif
}
