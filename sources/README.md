# sources/ — the fork's hook + player sources (consolidated v0.7.0-v0.7.3)

The separate fork repository was retired; this directory is what makes
this Addon self-contained. Everything needed to rebuild the two shipped
binaries (`mod/cluster_aa/libgal_hook.so`, `mod/cluster_aa/stream-player`)
lives here:

- `src/` — the QNX gal-hook sources (`gal_hook.c`, `video_sink_hook.c`,
  `focus_ctl.c`, `vc_player_mgr.c`, `vc_stream_out.c`, `nav_translate.c`,
  `firmware_profiles.h`, ...) — every binary capability shipped since
  v0.5.x: the Hi-res cluster stream (codec enum 2), the cluster menu /
  wheel routing, the IDR pump, the UiConfig wire sender, the view
  ladders with the file-write probes.
- `player/` — the fork player (`opengl_gpu.cc`), the in-cluster menu
  overlay (`menu.h`), the turn-info strip (`turnstrip.h`).
- `carplay/`, `dmdt_flush/` — the CarPlay hook launcher and the dmdt
  flush helper.
- `scripts/`, `swdl/`, `tests/`, `config/`, `tools/`, `docs/` — the
  fork's own support scripts, unit research notes and history
  (`docs/` carries android-auto-research / related-projects /
  car-test-notes).
- `thirdparty/` — `mhi2_altscreen_carplay` (CarPlay cluster hook,
  harman-f), `mib2-android-auto-vc` (VCAndroidAuto.jar), `mib2-toolbox`.
- `build_local.sh` + `BUILD_LOCALLY.md` — how the two binaries are
  rebuilt with the QNX 6.5 ARMv7 toolchain (native, no-container path
  works on this host; the unpacked image root is the prerequisite).

Excluded on purpose: `build/` (reproducible artifacts) and the fork's
`mib-mod/sd-payload/` + `greenmenu/` mirrors (this Addon's `mod/` is the
shipping tree).

Build recipe (summary):
    export PATH=/opt/qnx650/host/linux/x86/usr/bin:$PATH
    export QNX_HOST=/opt/qnx650/host/linux/x86 QNX_TARGET=/opt/qnx650/target/qnx6
    P=arm-unknown-nto-qnx6.5.0eabi
    $P-gcc -O2 -Wall -Wextra -shared -fPIC -I./src -DGAL_HOOK_BUILD='"vX.Y.Z"' \
        sources/src/*.c -Wl,--exclude-libs,ALL -lsocket -o build/libgal_hook.so
    $P-g++ -O2 -Wall -DNDEBUG -I build/ffmpeg-mini -I. player/opengl_gpu.cc -c -o build/opengl_gpu.o
    $P-g++ build/opengl_gpu.o -Wl,--start-group \
        build/ffmpeg-mini/libavformat/libavformat.a build/ffmpeg-mini/libavcodec/libavcodec.a \
        build/ffmpeg-mini/libavutil/libavutil.a -Wl,--end-group \
        -static-libstdc++ -static-libgcc -lEGL -lGLESv2 -lsocket -lm -o build/stream-player
(ffmpeg-mini: the pinned 6.1.5 tree configured for QNX per
BUILD_LOCALLY.md; the .a files are reproducible from the tarball.)

Note the paths above assume the sources/ tree is the working root; the
hook's include paths are relative to `src/`.
