/* Host test for src/wheel_autostart.c pure logic:
 *   cc -I src tests/wheel_autostart_test.c src/wheel_autostart.c -o /tmp/wlstart && /tmp/wlstart
 * The QNX spawn itself is not exercised here (guarded by __QNX__); the
 * decision rules are: default-on unless "0", first-executable candidate,
 * pid-file liveness. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "wheel_autostart.h"

static int fails = 0;
#define CHECK(cond) do { \
    if (!(cond)) { printf("FAIL %d: %s\n", __LINE__, #cond); fails++; } \
} while (0)

static const char *want_path;
static int stub_x_ok(const char *path)
{
    return (want_path != NULL && strcmp(path, want_path) == 0) ? 0 : -1;
}

static void stub_logf(const char *format, ...)
{
    (void)format;
}

int main(void)
{
    /* opt-out only on exact "0": fresh installs (no key) just work */
    CHECK(wheel_want_start(NULL) == 1);
    CHECK(wheel_want_start("") == 1);
    CHECK(wheel_want_start("1") == 1);
    CHECK(wheel_want_start("yes") == 1);
    CHECK(wheel_want_start("0") == 0);
    CHECK(wheel_want_start("00") == 1);

    /* candidate picking */
    want_path = NULL;
    CHECK(wheel_pick_binary(stub_x_ok) == NULL);
    CHECK(wheel_pick_binary(NULL) == NULL);
    want_path = "/mnt/app/eso/lib/gal_dualscreen/wheel_listen";
    CHECK(strcmp(wheel_pick_binary(stub_x_ok), want_path) == 0);
    want_path = "/net/rcc/mnt/app/eso/lib/gal_dualscreen/wheel_listen";
    CHECK(strcmp(wheel_pick_binary(stub_x_ok), want_path) == 0);

    /* no pid file -> not alive */
    unlink("/tmp/gal_wheellisten.pid");
    CHECK(wheel_pid_alive() == 0);

    /* own pid -> alive */
    {
        FILE *f = fopen("/tmp/gal_wheellisten.pid", "w");
        fprintf(f, "%ld\n", (long)getpid());
        fclose(f);
        CHECK(wheel_pid_alive() == 1);
    }

    /* garbage -> not alive */
    {
        FILE *f = fopen("/tmp/gal_wheellisten.pid", "w");
        fputs("not-a-pid\n", f);
        fclose(f);
        CHECK(wheel_pid_alive() == 0);
    }

    /* reaped child -> not alive (kill fails ESRCH, no zombie games) */
    {
        pid_t c = fork();
        FILE *f;
        if (c == 0)
            _exit(0);
        (void)waitpid(c, NULL, 0);
        f = fopen("/tmp/gal_wheellisten.pid", "w");
        fprintf(f, "%ld\n", (long)c);
        fclose(f);
        CHECK(wheel_pid_alive() == 0);
    }
    unlink("/tmp/gal_wheellisten.pid");

    /* host build: no QNX spawn, must log skip and change nothing */
    setenv("GAL_WHEEL_LISTEN", "0", 1);
    wheel_autostart(stub_logf);
    CHECK(access("/tmp/gal_wheellisten.pid", F_OK) != 0);

    if (fails == 0)
        printf("wheel_autostart_test: OK\n");
    return fails != 0;
}
