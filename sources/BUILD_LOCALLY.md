# Building locally without Docker (LXC / TrueNAS / restricted hosts)

`build_local.sh` runs the QNX 6.5 ARMv7 toolchain inside the
`qnx65-armv7-toolchain:8.5` image. On hosts where containers cannot start
(in a TrueNAS LXC, podman's netavark backend fails with
`Sysctl error: Read-only file system` and crun fails with
`controller pids is not available`), build **natively** from the unpacked
image root instead. The toolchain host binaries are plain x86-64 Linux
binaries and run without a container.

## One-time setup on the restricted host

1. **Unpack the image root** (or reuse an existing unpack, e.g. from building
   `profile_check` the earlier way):
   ```sh
   mkdir -p /tmp/qnx-image-root
   podman create --name qxroot localhost/qnx65-armv7-toolchain:8.5 true
   podman export qxroot - | tar -C /tmp/qnx-image-root -xf -
   podman rm -f qxroot
   ```

2. **Match the toolchain's baked prefix.** The GCC driver was configured
   inside the image with `QNX_TARGET=/opt/qnx650/...` and looks there for
   `armle-v7/lib/crt1.o` regardless of the env you export, so:
   ```sh
   ln -sfn /tmp/qnx-image-root/opt/qnx650 /opt/qnx650
   ```

3. **Fix the broken C++ symlinks.** Some unpacks leave `g++`-family entries
   as relative links to `opt/qnx650/...` that resolve to nowhere:
   ```sh
   cd /opt/qnx650/host/linux/x86/usr/bin
   for l in $(find . -maxdepth 1 -type l); do
       t=$(readlink "$l")
       case "$t" in opt/*|* opt/qnx650/*) ln -sfn "$(basename "$t")" "$l" ;; esac
   done
   ```

4. **Smoke test:**
   ```sh
   export PATH=/opt/qnx650/host/linux/x86/usr/bin:$PATH
   export QNX_HOST=/opt/qnx650/host/linux/x86
   export QNX_TARGET=/opt/qnx650/target/qnx6
   arm-unknown-nto-qnx6.5.0eabi-gcc --version    # 8.5.0
   echo 'int main(){return 0;}' > /tmp/t.c
   arm-unknown-nto-qnx6.5.0eabi-gcc -o /tmp/t /tmp/t.c -lsocket
   file /tmp/t    # ELF 32-bit ... ARM, interpreter /usr/lib/ldqnx.so.2
   ```

## Build the player (native, same recipe as build_player())

```sh
P=arm-unknown-nto-qnx6.5.0eabi
FF=<repo>/build/ffmpeg-mini; V=6.1.5
SHA=b8c8e926b948c14df1264cd0beac1c773df9170ac9cac97bdf1275cd3d385902
mkdir -p <repo>/build && cd <repo>/build
[ -f ffmpeg-$V.tar.gz ] || curl -fL -o ffmpeg-$V.tar.gz \
    https://ffmpeg.org/releases/ffmpeg-$V.tar.gz
echo "$SHA  ffmpeg-$V.tar.gz" | sha256sum -c -
mkdir -p $FF && tar xf ffmpeg-$V.tar.gz -C $FF --strip-components=1
cd $FF
./configure --cc=$P-gcc --ar=$P-ar --ld=$P-gcc --nm=$P-nm --ranlib=$P-ranlib \
  --strip=$P-strip --arch=arm --target-os=qnx --disable-asm --disable-debug \
  --enable-cross-compile \
  --extra-cflags="-D_QNX_SOURCE -include stddef.h -march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16" \
  --extra-libs=-lsocket --disable-doc --disable-programs --disable-avdevice \
  --disable-swresample --disable-swscale --disable-postproc --disable-avfilter \
  --disable-everything --enable-decoder=h264 --enable-parser=h264
make -j"$(nproc)"
cd <repo>/player
$P-g++ -O2 -Wall -DNDEBUG -I$FF -I. opengl_gpu.cc -c -o ../build/opengl_gpu.o
$P-g++ ../build/opengl_gpu.o \
  -Wl,--start-group $FF/libavformat/libavformat.a $FF/libavcodec/libavcodec.a \
  $FF/libavutil/libavutil.a -Wl,--end-group \
  -static-libstdc++ -static-libgcc -lEGL -lGLESv2 -lsocket -lm \
  -o ../build/stream-player
$P-strip -s ../build/stream-player
```

Change `player` to `hook` for the same treatment of `libgal_hook.so` /
`libdmdt_flush.so` / `profile_check` (identical command rows inside
`build_local.sh build_hook`).

The recorded first successful native production build of `stream-player`
(zoom + keep-map), with provenance and SHA, lives in `CHANGELOG-fork.md`.
