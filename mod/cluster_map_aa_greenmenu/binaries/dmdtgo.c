#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/wait.h>
extern char **environ;
int main(int argc, char **argv) {
    (void)argc; (void)argv;
    chdir("/proc/boot/config");
    char *child_argv[4] = { 0 };
    child_argv[0] = (char*)"/proc/boot/eso/bin/apps/dmdt";
    char argbuf[256] = "gs";
    FILE* f = fopen("/proc/boot/eso/bin/apps/dmdt_args","r");
    if (f) {
        size_t n = fread(argbuf, 1, sizeof(argbuf) - 1, f);
        argbuf[n] = 0;
        /* strip trailing newline/space */
        while (n && (argbuf[n-1]=='\n' || argbuf[n-1]=='\r' || argbuf[n-1]==' '))
            argbuf[--n] = 0;
        fclose(f);
    }
    child_argv[1] = argbuf;
    pid_t pid = 0;
    int status = 0;
    errno = 0;
    int rc = spawn("/proc/boot/eso/bin/apps/dmdt", 0, 0, NULL, child_argv, environ);
    if (rc < 0) {
        fprintf(stderr, "dmdtgo: spawn failed (%s)\n", strerror(errno));
        return 1;
    }
    waitpid(pid, &status, 0);
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return 1;
}
