#ifndef WHEEL_AUTOSTART_H
#define WHEEL_AUTOSTART_H

/* Internal to the hook (never part of its dynamic interface): hidden so
 * the build's unexpected-exports check keeps passing. */
#if defined(__GNUC__)
#define WL_LOCAL __attribute__((visibility("hidden")))
#else
#define WL_LOCAL
#endif

/* Enabled unless the value is exactly "0" (opt out). */
WL_LOCAL int wheel_want_start(const char *env_value);
/* First X_OK candidate, or NULL. x_ok(path) is 0 on executable. */
WL_LOCAL const char *wheel_pick_binary(int (*x_ok)(const char *path));
/* 1 when /tmp/gal_wheellisten.pid names a live process. */
WL_LOCAL int wheel_pid_alive(void);
/* One autostart attempt; logs a single event=wheel.spawn line. */
WL_LOCAL void wheel_autostart(void (*logf)(const char *format, ...));

#endif
