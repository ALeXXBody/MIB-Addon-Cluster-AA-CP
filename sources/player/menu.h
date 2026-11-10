/* menu.h — v0.7.0: the in-cluster menu (driven from the steering wheel).
 *
 * The hook forwards the wheel's gestures to /tmp/stream-player.menu when
 * GAL_CLUSTER_MENU=1: "open" (short OK), "up"/"down" (rotary), "sel"
 * (short OK again: apply the row). This module polls that file, runs the
 * menu state machine, and draws the rows into the Y plane EXACTLY like
 * turnstrip.h does (luma-only, the same 5x7 font, no extra GL state).
 *
 * Rows:
 *   Zoom    — live: writes /tmp/stream-player.zoom like the hook does
 *   Strip   — live: writes /tmp/stream-player.navstrip ("1"/"0")
 *   Card    — live: cycles the ETA-card/preset (/tmp/gal_uiconfig), the
 *             hook's ui-config sender applies it to the phone on the wire
 *   Pump    — live: writes /tmp/gal_idr_pump (seconds, 0=off); the hook's
 *             focus controller polls it every respin decision
 *   Hi-res  — next session: writes /tmp/gal_hires ("1"/"0"); the hook
 *             reads it when it builds the next phone session
 *   Exit
 *
 * Everything static, no heap; readable from stdio only.
 */
#ifndef CMENU_H
#define CMENU_H
#include <stdio.h>
#include <string.h>

/* draw helpers from turnstrip.h (included before this header in the same
 * translation unit): ts_glyph + font5x7 repaint text rows luma-only. */

#define MENU_EVENT_PATH   "/tmp/stream-player.menu"
#define MENU_TIMEOUT_MS   8000u

static int  cm_visible;
static int  cm_row;                  /* 0..5 */
static unsigned long long cm_last_event_us;

/* the current settings, refreshed beside the event poll (1 fopen/2 s) */
static char cm_zoom_label[20];       /* "1.15", "1.00" ... */
static char cm_strip_label[4];
static char cm_card_label[16];       /* "top"/"sides"/"band"/"off" */
static char cm_pump_label[16];       /* "25s"/"off" */
static char cm_hires_label[12];      /* "on/720p" or "off/800p" + "(next ses)" */

static void cm_read_labels(void)
{
    FILE* f = fopen("/tmp/stream-player.zoom", "r");
    if (f) {
        float v = 1.0f;
        if (fscanf(f, "%f", &v) != 1) v = 1.0f;
        fclose(f);
        snprintf(cm_zoom_label, sizeof cm_zoom_label, "%.2f", v);
    } else {
        snprintf(cm_zoom_label, sizeof cm_zoom_label, "1.00");
    }
    f = fopen("/tmp/stream-player.navstrip", "r");
    cm_strip_label[0] = 0;
    if (f) {
        int v = 0;
        if (fscanf(f, "%d", &v) == 1) snprintf(cm_strip_label, sizeof cm_strip_label,
                                               v ? "ON" : "off");
        fclose(f);
    }
    if (!cm_strip_label[0]) snprintf(cm_strip_label, sizeof cm_strip_label, "off");
    f = fopen("/tmp/gal_uiconfig", "r");
    cm_card_label[0] = 0;
    if (f) {
        char buf[64]; buf[0] = 0;
        if (fgets(buf, sizeof buf, f)) { buf[strcspn(buf, "\r\n")] = 0; }
        fclose(f);
        if (strstr(buf, "0,0,0,0")) snprintf(cm_card_label, sizeof cm_card_label, "top");
        else if (strstr(buf, "52,82,0,0")) snprintf(cm_card_label, sizeof cm_card_label, "top-strip");
        else if (strstr(buf, "0,0,100,100")) snprintf(cm_card_label, sizeof cm_card_label, "sides");
        else if (strstr(buf, "40,40,0,0")) snprintf(cm_card_label, sizeof cm_card_label, "band");
        else snprintf(cm_card_label, sizeof cm_card_label, "off");
    } else {
        snprintf(cm_card_label, sizeof cm_card_label, "off");
    }
    f = fopen("/tmp/gal_idr_pump", "r");
    cm_pump_label[0] = 0;
    if (f) {
        int v = 0;
        if (fscanf(f, "%d", &v) == 1 && v >= 10)
            snprintf(cm_pump_label, sizeof cm_pump_label, "%ds", v);
        fclose(f);
    }
    if (!cm_pump_label[0]) snprintf(cm_pump_label, sizeof cm_pump_label, "off");
    f = fopen("/tmp/gal_hires", "r");
    cm_hires_label[0] = 0;
    if (f) {
        int v = 0;
        if (fscanf(f, "%d", &v) == 1)
            snprintf(cm_hires_label, sizeof cm_hires_label,
                     v ? "720p (next ses)" : "800p");
        fclose(f);
    }
    if (!cm_hires_label[0]) snprintf(cm_hires_label, sizeof cm_hires_label, "phone-chosen");
}

/* --- actions ------------------------------------------------------------ */
static void cm_write(const char* path, const char* fmt_line)
{
    FILE* f = fopen(path, "w");
    if (f != NULL) {
        fprintf(f, "%s\n", fmt_line);
        fclose(f);
    }
}

static void cm_zoom_step(int dir)
{
    float v = 1.0f;
    FILE* f = fopen("/tmp/stream-player.zoom", "r");
    if (f != NULL) { if (fscanf(f, "%f", &v) != 1) v = 1.0f; fclose(f); }
    v += dir > 0 ? 0.13f : -0.13f;
    if (v > 1.35f) v = 1.35f;
    if (v < 1.0f)  v = 1.0f;
    f = fopen("/tmp/stream-player.zoom", "w");
    if (f != NULL) { fprintf(f, "%.2f\n", v); fclose(f); }
}

static void cm_strip_toggle(void)
{
    int on = (strcmp(cm_strip_label, "ON") == 0);
    cm_write("/tmp/stream-player.navstrip", on ? "0" : "1");
}

static const char* cm_card_next(const char* cur)
{
    if (strcmp(cur, "top-strip") == 0)  return "0,0,100,100"; /* sides */
    if (strcmp(cur, "sides") == 0)      return "40,40,0,0";   /* band */
    if (strcmp(cur, "band") == 0)       return "";            /* off */
    return "52,82,0,0";                                        /* top strip */
}

static void cm_card_cycle(void)
{
    cm_read_labels();  /* refresh from the file before the cycle */
    cm_write("/tmp/gal_uiconfig", cm_card_next(cm_card_label));
}

static void cm_pump_toggle(void)
{
    /* payload's hook reads it at every respin decision; >= 10 s arms */
    cm_write("/tmp/gal_idr_pump",
             (strcmp(cm_pump_label, "25s") == 0) ? "0" : "25");
}

static void cm_hires_toggle(void)
{
    cm_write("/tmp/gal_hires",
             (strstr(cm_hires_label, "720p") != NULL) ? "0" : "1");
}

/* --- rows and the state machine ----------------------------------------- */
static const char* const cm_rows[6] =
    { "Zoom", "Strip", "Card", "Pump", "Hi-res", "Exit" };

static void cm_apply(void)
{
    switch (cm_row) {
    case 0: cm_zoom_step(0);  cm_visible = 0; break;   /* zoom row: closes */
    case 1: cm_strip_toggle(); break;
    case 2: cm_card_cycle();  break;
    case 3: cm_pump_toggle(); break;
    case 4: cm_hires_toggle(); break;
    default: cm_visible = 0; break;
    }
}

static void menu_poll(uint64_t now_us)
{
    /* 1 read/s closed; 4/s open (event responsiveness) */
    static uint64_t last_poll_us = 0;
    unsigned ms = (cm_visible ? 250u : 1000u);
    char ev[32];

    if (last_poll_us != 0 && now_us - last_poll_us < ms * 1000ULL) return;
    last_poll_us = now_us;

    {
        FILE* f = fopen(MENU_EVENT_PATH, "r");
        if (f != NULL) {
            if (fgets(ev, sizeof ev, f) != NULL) {
                ev[strcspn(ev, "\r\n")] = 0;
                if (strcmp(ev, "open") == 0) {
                    cm_visible = 1; cm_row = 0;
                } else if (cm_visible) {
                    if (strcmp(ev, "up") == 0) {
                        cm_row = (cm_row + 5) % 6;
                    } else if (strcmp(ev, "down") == 0) {
                        cm_row = (cm_row + 1) % 6;
                    } else if (strcmp(ev, "sel") == 0) {
                        cm_apply();
                    }
                }
                cm_last_event_us = now_us;
            }
            fclose(f);
            (void)remove(MENU_EVENT_PATH);
        }
    }
    if (cm_visible) {
        cm_read_labels();
        if (now_us - cm_last_event_us > MENU_TIMEOUT_MS * 1000ULL) cm_visible = 0;
    }
}

/* --- draw (turnstrip.h's own approach: luma rows, no extra GL state) ---- */
static void menu_draw(uint8_t* pY, int w, int h)
{
    enum { N = 6 };
    static const int SCALE = 2;      // 5x7 cells x2 -> 10x14 text
    static const int ROWH  = 18;     // text 14 + 4 spacing
    char line[48];
    int i, y0;

    if (!cm_visible) return;
    y0 = 10;
    if (y0 + (ROWH + 4) * N + 8 > h) return;

    /* the menu's backing bar, spans most of the width */
memset(pY + y0 * w, 16, (ROWH + 4) * N);
    for (i = 0; i < N; ++i) {
        int gy = y0 + 6 + i * ROWH;
        const char* val = "";
        switch (i) {
        case 0: val = cm_zoom_label;  break;
        case 1: val = cm_strip_label; break;
        case 2: val = cm_card_label;  break;
        case 3: val = cm_pump_label;  break;
        case 4: val = cm_hires_label; break;
        default: val = "";            break;
        }
        snprintf(line, sizeof line, "%s%s%s", cm_rows[i],
                 val[0] ? ": " : "", val);
        {
            int gx = 14 + 8 * (i == cm_row);   /* the chosen row indents */
            size_t s;
            for (s = 0; line[s]; ++s) {
                unsigned ch = (unsigned char)line[s];
                if (ch < 0x20u || ch > 0x7eu) ch = (unsigned)' ';
                if (ch != (unsigned)' ')
                    ts_glyph(pY, w, h, gx, gy, font5x7[ch - 0x20u],
                             (i == cm_row) ? 255u : 150u);
                gx += 5 * SCALE + SCALE;
            }
        }
    }
}

#endif /* CMENU_H */
