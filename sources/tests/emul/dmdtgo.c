#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/wait.h>
#include <limits.h>
extern char **environ;

/* dmdt debug spawn helper (fork emul).
 * Reads a one-line argument string from /proc/boot/eso/bin/apps/dmdt_args
 * ("help", "gs", "sc 4 70", ...). An empty file means "run dmdt with no
 * arguments" (that is how dmdt prints its usage). Key=value tokens after the
 * command are passed through. A leading '-' line means argv[1] is the raw
 * remainder, for dmdt's colon-flag forms. */
int main(int argc, char **argv) {
    (void)argc; (void)argv;
    chdir("/proc/boot/config");

    char *child_argv[17] = { 0 };
    char argbuf[PATH_MAX] = "gs";
    FILE* f = fopen("/proc/boot/eso/bin/apps/dmdt_args","r");
    int ne = 0;
    if (f) {
        size_t n = fread(argbuf, 1, sizeof(argbuf) - 1, f);
        argbuf[n] = 0;
        while (n && (argbuf[n-1]=='\n' || argbuf[n-1]=='\r' || argbuf[n-1]==' '))
            argbuf[--n] = 0;
        fclose(f);
        ne = (n == 0);
    }

    /* split on spaces into tokens */
    int i = 0;
    child_argv[i++] = (char*)"/proc/boot/eso/bin/apps/dmdt";
    if (!ne && argbuf[0]) {
        char *tok = argbuf;
        while (*tok && i < (int)(sizeof(child_argv)/sizeof(child_argv[0])) - 1) {
            child_argv[i++] = tok;
            while (*tok && *tok != ' ') ++tok;
            if (*tok == ' ') *tok++ = 0;
            while (*tok == ' ') ++tok;
        }
    }

    pid_t pid = 0; int status = 0; errno = 0;
    int rc = spawn("/proc/boot/eso/bin/apps/dmdt", 0, 0, NULL, child_argv, environ);
    if (rc < 0) {
        fprintf(stderr, "dmdtgo: spawn of %d args failed (%s):\n", i + (int)ne, strerror(errno));
        for (int j = 0; j < i; ++j) fprintf(stderr, "  argv[%d]=%s\n", j, child_argv[j]);
        return 1;
    }
    waitpid(pid, &status, 0);
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return 1;
}
