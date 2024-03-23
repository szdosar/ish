sed -i '$a src-git passwall_packages https://github.com/sbwml/openwrt_helloworld.git;go1.21' feeds.conf.default
sed -i '$a src-git passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main' feeds.conf.default
sed -i '$a src-git lienol_other https://github.com/Lienol/openwrt-package.git;other' feeds.conf.default
./scripts/feeds update -a -f && ./scripts/feeds install -a -f && make defconfig
rm -rf feeds/packages/net/{xray-core,v2ray-core,v2ray-geodata,sing-box}
git clone https://github.com/fw876/helloworld.git package/helloworld
cp -r package/helloworld/{xray-core,v2ray-core} feeds/packages/net/
cp -r feeds/passwall_packages/{v2ray-geodata,sing-box} feeds/packages/net/
rm -rf package/helloworld
./scripts/feeds install -a -f
wget --no-check-certificate -O .config https://raw.githubusercontent.com/szdosar/ish/master/passwall2.config
rm -rf ./tmp
bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/szdosar/ish/master/update_golang.sh')
make download -j$(nproc) && make -j$(nproc)
