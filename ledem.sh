./scripts/feeds update -a -f && ./scripts/feeds install -a -f && make defconfig && make menuconfig && make download -j8 && make V=s -j$(nproc)
