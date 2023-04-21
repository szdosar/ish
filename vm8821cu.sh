cd
rm -rf /workdir/openwrt
sudo -E apt-get -qq install $(curl -fsSL raw.githubusercontent.com/szdosar/ish/master/depends-ubuntu-2204)
sudo -E apt-get -qq autoremove --purge
sudo -E apt-get -qq clean
git clone https://github.com/coolsnowwolf/lede openwrt
cd openwrt
git reset --hard 77251e963f61f33504d24defef9dcfe1104d0a70
sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git' feeds.conf.default
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small' feeds.conf.default
sed -i 's/192.168.1.1/192.168.3.254/g' package/base-files/files/bin/config_generate
./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig
rm .config
wget https://raw.githubusercontent.com/szdosar/ish/master/rtl8821cu.config
mv rtl8821cu.config .config
./scripts/feeds update -a -f && ./scripts/feeds install -a -f && make defconfig
make download -j8 && make V=s -j$(nproc)
