cd
rm -rf lede
git clone https://github.com/coolsnowwolf/lede
cd lede
cp ../x86/.config .
cp ../feeds.conf.default .
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
./scripts/feeds update -a -f && ./scripts/feeds install -a -f && make defconfig
cp ../x86/.config .
./scripts/feeds update -a -f && ./scripts/feeds install -a -f && make defconfig
make download -j8 && make V=s -j$(nproc)
