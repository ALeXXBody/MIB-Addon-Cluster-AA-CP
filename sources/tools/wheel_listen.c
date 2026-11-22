/*
 * wheel_listen - steering-wheel input for the cluster map, read straight
 * from the HMI's own DSI tracer instead of waiting for Android Auto input
 * reports that this firmware never sends (7 live sessions, zero outbound
 * InputReport anywhere).
 *
 * Mechanism (car-proven on the same Harman HMI family, joeyQuery /
 * MHI2-altScreen TRACE-015 + docs/cluster-controls.md, GPL-3.0 --
 * behavior reimplemented here, no code copied): the HMI DSI tracer
 * streams lines such as
 *   1#org.dsi.ifc.keypanel.DSIKeyPanelListener#updateEncoder2#<ts>|int:4|int:40|int:+1|int:0|int:1
 * (telnet appender, port 1798; bluepirat BufferedTelnetAppender, port
 * 20991, form "<seq>?<instance>#class#method#ts|args"). updateEncoder2
 * with keyboard 4, encoder 40, delta +1/-1 is a scroll-wheel notch (each
 * notch is logged twice; only the "1#" instance counts). updateKey2 with
 * keyboard 4, key 40 is the wheel OK press (1 down, 0 released, 3/4/5
 * long); key 35 is the View button; 99/100 are the VC menus.
 *
 * Rotary notches drive the player's zoom file (mirror of the hook's own
 * cluster_remote_zoom: +-0.13, clamped to [1.0, 1.35]) through tmp+rename,
 * exactly as greenmenu/zoom.sh writes it. OK press cycles the card-clear
 * preset on short press and toggles the turn-info strip on long press --
 * the same file actions the hook takes for bound wheel gestures, so the
 * GEM menu's promise ("short OK -> presets, long OK -> strip") holds
 * whichever input path delivered the press. View/99/100 are LOGGED ONLY
 * (the cluster's gauge control must not move).
 *
 * Everything else with a DSIKeyPanelListener line is only LOGGED
 * (WL_LOG_PATH, with .prev rotation) -- key shapes for later mapping,
 * never acted on.
 *
 * Portable C99: the same file builds for the unit (QNX cross toolchain)
 * and for the host test below (-DWL_TEST_MAIN), which feeds canned
 * transcripts on stdin and prints the actions it would take.
 *
 * License: GPL-3.0-or-later (this repository's license).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef WL_ZOOM_PATH
#define WL_ZOOM_PATH "/tmp/stream-player.zoom"
#endif
#ifndef WL_UICONFIG_PATH
#define WL_UICONFIG_PATH "/tmp/gal_uiconfig"
#endif
#ifndef WL_NAVSTRIP_PATH
#define WL_NAVSTRIP_PATH "/tmp/stream-player.navstrip"
#endif
#ifndef WL_LOG_PATH
#define WL_LOG_PATH "/tmp/gal_wheel.log"
#endif
#ifndef WL_LOG_MAX_BYTES
#define WL_LOG_MAX_BYTES 65536L
#endif

#define WL_STEP 0.13f
#define WL_ZOOM_MIN 1.0f
#define WL_ZOOM_MAX 1.35f

/* Action the line asks for. ZOOM_DIR is +1/-1, KEY_* are observed presses. */
enum {
    WL_NONE = 0,
    WL_ZOOM_UP,
    WL_ZOOM_DOWN,
    WL_KEY_OK_DOWN,
    WL_KEY_OK_UP_SHORT,
    WL_KEY_OK_UP_LONG,
    WL_KEY_VIEW,
    WL_KEY_VC_LEFT,
    WL_KEY_VC_RIGHT
};

/* Long-press latch: updateKey2(4,40,3|4) arms it, updateKey2(4,40,0)
 * resolves short vs long. file-static so the live loop and the test
 * driver share the exact state machine. */
static int wl_long_armed;

/* Describe the key the line carries. Returns WL_NONE unless it is a
 * mapped action; *iskey is set for every DSIKeyPanelListener line so
 * the caller can record unknown ones. */
/* Describe the key the line carries. Matches the car-proven reference
 * exactly (substring probes, no positional int parsing, so instance
 * prefixes, bluepirat "?seq#"-wrappers, and the trailing fields can never shift
 * read): updateKey2(4,40,1) = down, (4,40,0) = release (short unless a
 * long was armed), (4,35) = View, 99/100 = VC menus (logged only).
 * Returns a WL_KEY_* code or WL_NONE. */
static int wl_parse_key(const char *m, int *iskey)
{
    *iskey = 1;
    if (strstr(m, "|int:4|int:40|int:1|") != NULL)
        return WL_KEY_OK_DOWN;
    if (strstr(m, "|int:4|int:40|int:3|") != NULL ||
        strstr(m, "|int:4|int:40|int:4|") != NULL)
        return WL_KEY_OK_DOWN + 100; /* long-press armed, no action yet */
    if (strstr(m, "|int:4|int:40|int:0|") != NULL)
        return WL_KEY_OK_UP_SHORT; /* refined below with the latch */
    if (strstr(m, "|int:4|int:35|") != NULL)
        return WL_KEY_VIEW;
    if (strstr(m, "|int:4|int:99|") != NULL)
        return WL_KEY_VC_LEFT;
    if (strstr(m, "|int:4|int:100|") != NULL)
        return WL_KEY_VC_RIGHT;
    return WL_NONE;
}

/* Parse one tracer line. Returns +1/-1 for a rotary notch on keyboard 4 /
 * encoder 40, one of the WL_KEY_* codes for a mapped key event, or
 * WL_NONE. Sets *iskey for every DSIKeyPanelListener line so unknown
 * presses are recorded, never acted on. */
static int wl_parse_line(const char *line, int *iskey)
{
    const char *m;
    int r;

    *iskey = 0;
    if (line == NULL || strstr(line, "DSIKeyPanelListener") == NULL)
        return WL_NONE;
    *iskey = 1;
    /* live form starts with "1#"; bluepirat form buries "?1#" after a
     * sequence number. Either way the method name anchors the parse and
     * the duplicate "5#" instance is ignored. */
    m = strstr(line, "?1#");
    if (m != NULL)
        line = m + 1;
    else if (line[0] != '1' || line[1] != '#')
        return WL_NONE;
    /* OK press / View / VC menus. */
    m = strstr(line, "updateKey2");
    if (m != NULL) {
        r = wl_parse_key(m, iskey);
        if (r == WL_KEY_OK_DOWN + 100) {
            wl_long_armed = 1;
            return WL_NONE;
        }
        if (r == WL_KEY_OK_UP_SHORT) {
            int was_long = wl_long_armed;
            wl_long_armed = 0;
            return was_long ? WL_KEY_OK_UP_LONG : WL_KEY_OK_UP_SHORT;
        }
        if (r == WL_KEY_OK_DOWN) {
            wl_long_armed = 0;
            return WL_KEY_OK_DOWN;
        }
        return r;
    }
    /* rotary notch: updateEncoder2 keyboard 4, encoder 40, delta +-1 */
    m = strstr(line, "updateEncoder2");
    if (m == NULL)
        return WL_NONE;
    {
        const char *p = strstr(m, "|int:4|int:40|int:");
        int step = 0;
        if (p != NULL)
            step = atoi(p + (sizeof("|int:4|int:40|int:") - 1));
        if (step > 0)
            return 1;
        if (step < 0)
            return -1;
    }
    return WL_NONE;
}

/* Current zoom factor: the running player's file, or 1.0 when absent. */
static float wl_current_zoom(const char *path,
                             FILE *(*open_fn)(const char *, const char *))
{
    FILE *f;
    float v = 1.0f;
    if (open_fn == NULL)
        return 1.0f;
    f = open_fn(path, "r");
    if (f != NULL) {
        if (fscanf(f, "%f", &v) != 1) v = 1.0f;
        fclose(f);
    }
    return v;
}

static float wl_clamp(float v)
{
    if (v < WL_ZOOM_MIN) return WL_ZOOM_MIN;
    if (v > WL_ZOOM_MAX) return WL_ZOOM_MAX;
    return v;
}

/* Append one line to the key log, rotating to .prev past the cap. */
static void wl_log_key(const char *logpath, const char *line,
                       int (*rename_fn)(const char *, const char *),
                       FILE *(*open_fn)(const char *, const char *),
                       long (*size_fn)(const char *))
{
    char prev[256];
    FILE *f;
    if (size_fn != NULL && size_fn(logpath) > WL_LOG_MAX_BYTES) {
        snprintf(prev, sizeof prev, "%s.prev", logpath);
        if (rename_fn != NULL) {
            rename_fn(logpath, prev);
        }
    }
    if (open_fn == NULL)
        return;
    f = open_fn(logpath, "a");
    if (f != NULL) {
        fputs(line, f);
        if (line[0] != '\0' && line[strlen(line) - 1u] != '\n')
            fputc('\n', f);
        fclose(f);
    }
}

/* Atomic file write (tmp + rename): the hook and the player poll these
 * files and must never read a torn value. */
static int wl_write_file(const char *path, const char *text,
                         FILE *(*open_fn)(const char *, const char *),
                         int (*rename_fn)(const char *, const char *),
                         int (*remove_fn)(const char *))
{
    char tmp[320];
    FILE *f;
    if (open_fn == NULL || rename_fn == NULL)
        return -1;
    snprintf(tmp, sizeof tmp, "%s.new", path);
    f = open_fn(tmp, "w");
    if (f == NULL)
        return -1;
    fputs(text, f);
    fclose(f);
    if (rename_fn(tmp, path) != 0) {
        if (remove_fn != NULL)
            remove_fn(tmp);
        return -1;
    }
    return 0;
}

#ifndef WL_TEST_MAIN
/* Live client below (sockets). */
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

static int wl_connect(const char *host, int port)
{
    struct sockaddr_in addr;
    int fd;
    int flags;
    fd_set wfds;
    struct timeval tv;
    int rc;
    int err = 0;
    socklen_t errlen = sizeof err;

    fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0)
        return -1;
    memset(&addr, 0, sizeof addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons((unsigned short)port);
    if (inet_aton(host, &addr.sin_addr) == 0) {
        struct hostent *he = gethostbyname(host);
        if (he == NULL || he->h_addr_list[0] == NULL) {
            close(fd);
            return -1;
        }
        memcpy(&addr.sin_addr, he->h_addr_list[0], sizeof addr.sin_addr);
    }
    flags = fcntl(fd, F_GETFL, 0);
    if (flags >= 0)
        (void)fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    rc = connect(fd, (struct sockaddr *)&addr, sizeof addr);
    if (rc != 0 && errno != EINPROGRESS) {
        close(fd);
        return -1;
    }
    FD_ZERO(&wfds);
    FD_SET(fd, &wfds);
    tv.tv_sec = 3;
    tv.tv_usec = 0;
    rc = select(fd + 1, NULL, &wfds, NULL, &tv);
    if (rc <= 0 || getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &errlen) != 0 || err != 0) {
        close(fd);
        return -1;
    }
    if (flags >= 0)
        (void)fcntl(fd, F_SETFL, flags);
    return fd;
}

/* ---------------------------------------------------------------------------
 * omonob CarPlayClusterControls wire (GPL-3.0 jar shipped unmodified in
 * thirdparty/, installed beside the HMI's own jars). Its bootclasspath-
 * patched DSIKeyPanelDispatcher forwards the MFW keys to a worker that
 * sends PLAIN-ASCII UDP datagrams on 127.0.0.1, ports 7032/7033. The only
 * three payloads command() can produce are "canvas-zoom-in",
 * "canvas-zoom-out" and "canvas-noop" (map-previous/next are deliberately
 * mapped to noop in that jar). A datagram therefore proves the jar is
 * installed and the HMI restarted with it - no tracer ports needed.
 * Every datagram is logged to the wheel log; zoom commands act, the rest
 * is recorded for later mapping (rotary/OK reach this wire only in a
 * future jar revision). */
static int wl_udp_fds[2] = { -1, -1 };
static const int wl_udp_ports[2] = { 7032, 7033 };

static int wl_udp_bind(int port)
{
    struct sockaddr_in addr;
    int fd;
    int one = 1;

    fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0)
        return -1;
    (void)setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
    memset(&addr, 0, sizeof addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons((unsigned short)port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(fd, (struct sockaddr *)&addr, sizeof addr) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

/* Returns +1/-1 for a zoom command, or WL_NONE. *iskey logs every
 * datagram, including the noop ones (they prove the path is live). */
static int wl_parse_command(const char *cmd, int *iskey)
{
    *iskey = 1;
    if (cmd == NULL || cmd[0] == '\0')
        return WL_NONE;
    if (strcmp(cmd, "canvas-zoom-in") == 0)
        return 1;
    if (strcmp(cmd, "canvas-zoom-out") == 0)
        return -1;
    return WL_NONE;
}

static long wl_file_size(const char *path)
{
    FILE *f = fopen(path, "rb");
    long n = -1;
    if (f != NULL) {
        if (fseek(f, 0, SEEK_END) == 0)
            n = ftell(f);
        fclose(f);
    }
    return n;
}

static const char *wl_zoom_path(void)
{
    const char *v = getenv("GAL_WHEEL_ZOOM_FILE");
    return (v != NULL && *v != '\0') ? v : WL_ZOOM_PATH;
}

static const char *wl_uiconfig_path(void)
{
    const char *v = getenv("GAL_WHEEL_UICONFIG_FILE");
    return (v != NULL && *v != '\0') ? v : "/tmp/gal_uiconfig";
}

static const char *wl_navstrip_path(void)
{
    const char *v = getenv("GAL_WHEEL_NAVSTRIP_FILE");
    return (v != NULL && *v != '\0') ? v : "/tmp/stream-player.navstrip";
}

static const char *wl_keylog_path(void)
{
    const char *v = getenv("GAL_WHEEL_KEYLOG_FILE");
    return (v != NULL && *v != '\0') ? v : WL_LOG_PATH;
}

/* Short OK press cycles the card-clear preset (same files the hook's own
 * cluster_remote_cycle_card writes); long OK toggles the turn-info strip
 * (same file the hook's own toggle writes). */
static void wl_ok_short(void)
{
    static const char *seq[] = { "52,82,0,0", "0,0,100,100", "40,40,0,0", "" };
    char cur[64] = "";
    FILE *f = fopen(wl_uiconfig_path(), "r");
    const char *next = seq[0];
    size_t i;
    if (f != NULL) {
        if (fgets(cur, sizeof cur, f) == NULL) cur[0] = 0;
        fclose(f);
    }
    for (i = 0; i < 4; i++) {
        if (strcmp(cur, seq[i]) == 0 || (cur[0] != '\0' && seq[i][0] == '\0' && i == 3)) {
            next = seq[(i + 1) & 3u];
            break;
        }
        if (cur[0] == '\0') {
            next = seq[0];
            break;
        }
    }
    {
        char buf[80];
        snprintf(buf, sizeof buf, "%s\n", next);
        if (wl_write_file(wl_uiconfig_path(), buf, fopen, rename, remove) == 0)
            fprintf(stderr, "wheel_listen: card preset -> %s\n", next[0] ? next : "off");
        else
            fprintf(stderr, "wheel_listen: card preset write failed\n");
    }
}

static void wl_ok_long(void)
{
    char cur[8] = "0";
    FILE *f = fopen(wl_navstrip_path(), "r");
    if (f != NULL) {
        if (fgets(cur, sizeof cur, f) == NULL) cur[0] = 0;
        fclose(f);
    }
    {
        int now = (cur[0] == '1');
        char buf[8];
        snprintf(buf, sizeof buf, "%d\n", now ? 0 : 1);
        if (wl_write_file(wl_navstrip_path(), buf, fopen, rename, remove) == 0)
            fprintf(stderr, "wheel_listen: turn strip -> %d\n", now ? 0 : 1);
        else
            fprintf(stderr, "wheel_listen: strip write failed\n");
    }
}

int main(int argc, char *argv[])
{
    const char *host = getenv("GAL_WHEEL_HOST");
    const char *portenv = getenv("GAL_WHEEL_PORT");
    int ports[4];
    int nports = 0;
    int i;
    float cur = 1.0f;
    char line[2048];
    size_t used = 0;

    if (host == NULL || *host == '\0')
        host = (argc > 1) ? argv[1] : "127.0.0.1";
    if (portenv != NULL && *portenv != '\0') {
        ports[nports++] = atoi(portenv);
    } else if (argc > 2) {
        ports[nports++] = atoi(argv[2]);
    } else {
        /* telnet appender first (live lines), bluepirat second (buffered). */
        ports[nports++] = 1798;
        ports[nports++] = 20991;
    }

    fprintf(stderr, "wheel_listen: starting (host=%s zoom=%s)\n", host, wl_zoom_path());
    /* omonob jar path: bind the two dispatcher datagram ports BEFORE the
     * tracer loop. Binding never fails on a live unit (RAM sockets); the
     * fds simply stay quiet until the jar is installed and the HMI
     * restarted with it. GAL_WHEEL_UDP=0 opts out (tracer-only runs). */
    {
        const char *udpenv = getenv("GAL_WHEEL_UDP");
        int u;
        if (udpenv == NULL || strcmp(udpenv, "0") != 0) {
            for (u = 0; u < 2; ++u) {
                wl_udp_fds[u] = wl_udp_bind(wl_udp_ports[u]);
                if (wl_udp_fds[u] >= 0)
                    fprintf(stderr, "wheel_listen: udp listening on 127.0.0.1:%d\n",
                            wl_udp_ports[u]);
                else
                    fprintf(stderr, "wheel_listen: udp bind %d failed (%s)\n",
                            wl_udp_ports[u], strerror(errno));
            }
        } else {
            fprintf(stderr, "wheel_listen: udp datagram path disabled (GAL_WHEEL_UDP=0)\n");
        }
    }
    for (;;) {
        int fd = -1;
        for (i = 0; i < nports && fd < 0; ++i) {
            fprintf(stderr, "wheel_listen: connecting to %s:%d...\n", host, ports[i]);
            fd = wl_connect(host, ports[i]);
            if (fd >= 0)
                fprintf(stderr, "wheel_listen: connected to %s:%d\n", host, ports[i]);
        }
        if (fd < 0 && wl_udp_fds[0] < 0 && wl_udp_fds[1] < 0) {
            fprintf(stderr, "wheel_listen: no tracer endpoint reachable; retry in 10s\n");
            sleep(10);
            continue;
        }
        if (fd < 0) {
            /* Datagram-only operation: the jar path is live without any
             * tracer port. Wait for datagrams; the connect attempts below
             * resume only after this process restarts. */
            for (;;) {
                char dgram[256];
                fd_set rs;
                int u;
                int maxfd = -1;
                ssize_t r;
                FD_ZERO(&rs);
                for (u = 0; u < 2; ++u) {
                    if (wl_udp_fds[u] < 0)
                        continue;
                    FD_SET(wl_udp_fds[u], &rs);
                    if (wl_udp_fds[u] > maxfd)
                        maxfd = wl_udp_fds[u];
                }
                if (select(maxfd + 1, &rs, NULL, NULL, NULL) <= 0)
                    continue;
                for (u = 0; u < 2; ++u) {
                    int iskey = 0;
                    int act;
                    if (wl_udp_fds[u] < 0 || !FD_ISSET(wl_udp_fds[u], &rs))
                        continue;
                    r = recvfrom(wl_udp_fds[u], dgram, sizeof dgram - 1, 0,
                                 NULL, NULL);
                    if (r <= 0)
                        continue;
                    while (r > 0 && (dgram[r - 1] == '\n' || dgram[r - 1] == '\r'))
                        --r;
                    dgram[r] = 0;
                    act = wl_parse_command(dgram, &iskey);
                    if (iskey)
                        wl_log_key(wl_keylog_path(), dgram, rename, fopen,
                                   wl_file_size);
                    if (act == 1 || act == -1) {
                        char zbuf[32];
                        cur = wl_current_zoom(wl_zoom_path(), fopen);
                        cur = wl_clamp(cur + (act > 0 ? WL_STEP : -WL_STEP));
                        snprintf(zbuf, sizeof zbuf, "%.2f\n", (double)cur);
                        if (wl_write_file(wl_zoom_path(), zbuf, fopen, rename, remove) == 0)
                            fprintf(stderr, "wheel_listen: udp zoom %.2f (dir %+d)\n",
                                    (double)cur, act);
                        else
                            fprintf(stderr, "wheel_listen: udp zoom write failed\n");
                    } else {
                        fprintf(stderr, "wheel_listen: udp command logged (no action bound)\n");
                    }
                }
            }
        }
        used = 0;
        for (;;) {
            /* Tracer connected: wait on the stream AND the datagram ports
             * together, so the jar path keeps working whenever the tracer
             * exists too. */
            char buf[1024];
            ssize_t r;
            ssize_t k;
            fd_set rs;
            int maxfd = fd;
            int u;
            struct timeval tv;
            int rc;
            FD_ZERO(&rs);
            FD_SET(fd, &rs);
            for (u = 0; u < 2; ++u) {
                if (wl_udp_fds[u] < 0)
                    continue;
                FD_SET(wl_udp_fds[u], &rs);
                if (wl_udp_fds[u] > maxfd)
                    maxfd = wl_udp_fds[u];
            }
            tv.tv_sec = 1;
            tv.tv_usec = 0;
            rc = select(maxfd + 1, &rs, NULL, NULL, &tv);
            if (rc <= 0)
                continue;
            for (u = 0; u < 2; ++u) {
                int iskey = 0;
                int act;
                char dgram[256];
                if (wl_udp_fds[u] < 0 || !FD_ISSET(wl_udp_fds[u], &rs))
                    continue;
                r = recvfrom(wl_udp_fds[u], dgram, sizeof dgram - 1, 0,
                             NULL, NULL);
                if (r <= 0)
                    continue;
                while (r > 0 && (dgram[r - 1] == '\n' || dgram[r - 1] == '\r'))
                    --r;
                dgram[r] = 0;
                act = wl_parse_command(dgram, &iskey);
                if (iskey)
                    wl_log_key(wl_keylog_path(), dgram, rename, fopen,
                               wl_file_size);
                if (act == 1 || act == -1) {
                    char zbuf[32];
                    cur = wl_current_zoom(wl_zoom_path(), fopen);
                    cur = wl_clamp(cur + (act > 0 ? WL_STEP : -WL_STEP));
                    snprintf(zbuf, sizeof zbuf, "%.2f\n", (double)cur);
                    if (wl_write_file(wl_zoom_path(), zbuf, fopen, rename, remove) == 0)
                        fprintf(stderr, "wheel_listen: udp zoom %.2f (dir %+d)\n",
                                (double)cur, act);
                    else
                        fprintf(stderr, "wheel_listen: udp zoom write failed\n");
                } else {
                    fprintf(stderr, "wheel_listen: udp command logged (no action bound)\n");
                }
            }
            if (!FD_ISSET(fd, &rs))
                continue;
            r = recv(fd, buf, sizeof buf, 0);
            if (r <= 0)
                break;
            for (k = 0; k < r; ++k) {
                if (buf[k] == '\n' || used + 1u >= sizeof line) {
                    int iskey = 0;
                    int act;
                    line[used] = 0;
                    used = 0;
                    if (line[0] == '\0')
                        continue;
                    act = wl_parse_line(line, &iskey);
                    if (iskey)
                        wl_log_key(wl_keylog_path(), line, rename, fopen, wl_file_size);
                    if (act == 1 || act == -1) {
                        char zbuf[32];
                        cur = wl_current_zoom(wl_zoom_path(), fopen);
                        cur = wl_clamp(cur + (act > 0 ? WL_STEP : -WL_STEP));
                        snprintf(zbuf, sizeof zbuf, "%.2f\n", (double)cur);
                        if (wl_write_file(wl_zoom_path(), zbuf, fopen, rename, remove) == 0)
                            fprintf(stderr, "wheel_listen: zoom %.2f (dir %+d)\n",
                                    (double)cur, act);
                        else
                            fprintf(stderr, "wheel_listen: zoom write failed\n");
                    } else if (act == WL_KEY_OK_UP_SHORT) {
                        wl_ok_short();
                    } else if (act == WL_KEY_OK_UP_LONG) {
                        wl_ok_long();
                    }
                } else if (buf[k] != '\r') {
                    line[used++] = buf[k];
                }
            }
        }
        close(fd);
        fprintf(stderr, "wheel_listen: stream closed; reconnecting in 5s\n");
        sleep(5);
    }
    return 0;
}
#else /* WL_TEST_MAIN: host test driver, no sockets */
/* Reads canned transcript lines on stdin, prints the actions the live
 * loop would take. File writes go at $WL_TEST_TMPDIR (one file per
 * logical path name). Key log and zoom file end-state are asserted by
 * the sim test. */
#include <sys/stat.h>
static const char *t_tmpdir(void)
{
    static char d[256];
    const char *v;
    if (d[0] != '\0')
        return d;
    v = getenv("WL_TEST_TMPDIR");
    snprintf(d, sizeof d, "%s", (v != NULL && *v != '\0') ? v : "/tmp/wltest");
    return d;
}
static void t_path(const char *name, char *out, size_t outsz)
{
    snprintf(out, outsz, "%s/%s", t_tmpdir(), name);
}
static FILE *t_open(const char *path, const char *mode)
{
    /* map the three live paths into the sandbox dir by basename */
    const char *b = strrchr(path, '/');
    char real[300];
    if (b == NULL)
        return NULL;
    t_path(b + 1, real, sizeof real);
    return fopen(real, mode);
}
static int t_rename(const char *a, const char *b)
{
    char ra[300], rb[300];
    const char *ba = strrchr(a, '/');
    const char *bb = strrchr(b, '/');
    if (ba == NULL || bb == NULL)
        return -1;
    t_path(ba + 1, ra, sizeof ra);
    t_path(bb + 1, rb, sizeof rb);
    return rename(ra, rb);
}
static int t_remove(const char *a)
{
    char ra[300];
    const char *ba = strrchr(a, '/');
    if (ba == NULL)
        return -1;
    t_path(ba + 1, ra, sizeof ra);
    return remove(ra);
}
static long t_size(const char *path)
{
    char real[300];
    const char *b = strrchr(path, '/');
    FILE *f;
    long n = -1;
    if (b == NULL)
        return -1;
    t_path(b + 1, real, sizeof real);
    f = fopen(real, "rb");
    if (f != NULL) {
        if (fseek(f, 0, SEEK_END) == 0)
            n = ftell(f);
        fclose(f);
    }
    return n;
}
int main(void)
{
    char line[2048];
    float cur = 1.0f;
    const char *start = getenv("WL_TEST_START");
    if (start != NULL && *start != '\0')
        cur = (float)atof(start);
    {
        /* sandbox dir */
        char cmd[320];
        snprintf(cmd, sizeof cmd, "mkdir -p %s", t_tmpdir());
        if (system(cmd) != 0)
            return 2;
    }
    while (fgets(line, sizeof line, stdin) != NULL) {
        int iskey = 0;
        int act;
        size_t l = strlen(line);
        while (l > 0u && (line[l - 1u] == '\n' || line[l - 1u] == '\r'))
            line[--l] = 0;
        if (line[0] == '\0')
            continue;
        act = wl_parse_line(line, &iskey);
        if (iskey)
            wl_log_key(WL_LOG_PATH, line, t_rename, t_open, t_size);
        if (act == 1 || act == -1) {
            char zpath[300], zbuf[32];
            t_path("stream-player.zoom", zpath, sizeof zpath);
            /* emulate the live loop: start from the file each notch */
            cur = wl_current_zoom(zpath, t_open);
            cur = wl_clamp(cur + (act > 0 ? WL_STEP : -WL_STEP));
            snprintf(zbuf, sizeof zbuf, "%.2f\n", (double)cur);
            if (wl_write_file(zpath, zbuf, t_open, t_rename, t_remove) == 0)
                printf("ZOOM %+d %.2f\n", act, (double)cur);
            else
                printf("ZOOM-FAIL\n");
        } else if (act == WL_KEY_OK_DOWN) {
            printf("KEYDOWN\n");
        } else if (act == WL_KEY_OK_UP_SHORT) {
            printf("KEYUP-SHORT\n");
        } else if (act == WL_KEY_OK_UP_LONG) {
            printf("KEYUP-LONG\n");
        } else if (act == WL_KEY_VIEW) {
            printf("KEY-VIEW\n");
        } else if (act == WL_KEY_VC_LEFT) {
            printf("KEY-VCLEFT\n");
        } else if (act == WL_KEY_VC_RIGHT) {
            printf("KEY-VCRIGHT\n");
        } else if (iskey) {
            printf("KEY-LOG-ONLY\n");
        } else {
            printf("IGNORE\n");
        }
    }
    printf("FINAL %.2f\n", (double)cur);
    return 0;
}
#endif
