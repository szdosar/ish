git clone https://github.com/coolsnowwolf/lede openwrt
cd openwrt
git reset --hard 77251e963f61f33504d24defef9dcfe1104d0a70
rm -rf ~/rtl8821cu
cp -r package/kernel/rtl8821cu ~/
git reset --hard 9d124b993644b4f77749788936c44ca0c884f184
# 移除 openwrt feeds 自带的核心包
rm -rf feeds/packages/net/{xray-core,v2ray-core}
rm -rf package/kernel/rtw88-usb
mv ~/rtl8821cu package/kernel/
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
# 添加魔法源包
sed -i '$a src-git passwall_packages https://github.com/sbwml/openwrt_helloworld.git' feeds.conf.default
sed -i '$a src-git passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main' feeds.conf.default
sed -i '$a src-git lienol_other https://github.com/Lienol/openwrt-package.git;other' feeds.conf.default
./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig
wget --no-check-certificate -O .config https://raw.githubusercontent.com/szdosar/ish/master/add_passwall2_fix_v2ray-core-for-r2s.config
make defconfig
# 更新 golang 1.22 版本
bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/szdosar/ish/master/update_golang.sh')
# 开始现在并编译
make download -j$(nproc) && make -j$(nproc)
