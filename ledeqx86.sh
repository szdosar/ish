cd
rm -rf lede
sudo -E apt-get -qq install $(curl -fsSL raw.githubusercontent.com/szdosar/ish/master/depends-ubuntu-2204)
sudo -E apt-get -qq autoremove --purge
sudo -E apt-get -qq clean
git clone https://github.com/coolsnowwolf/lede
cd lede
git reset --hard 9d124b993644b4f77749788936c44ca0c884f184
sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package.git;main' feeds.conf.default
sed -i '$a src-git other https://github.com/Lienol/openwrt-package.git;other' feeds.conf.default
sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;main' feeds.conf.default
sed -i '$a src-git passwall2 https://github.com/xiaorouji/openwrt-passwall2.git' feeds.conf.default
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig
rm .config
wget https://raw.githubusercontent.com/szdosar/Actions-OpenWrt/main/.config
./scripts/feeds update -a -f && ./scripts/feeds install -a -f && make defconfig
make download -j8 && make V=s -j$(nproc)
