# 添加魔法源包
sed -i '$a src-git passwall_packages https://github.com/sbwml/openwrt_helloworld.git' feeds.conf.default
sed -i '$a src-git passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main' feeds.conf.default
sed -i '$a src-git lienol_other https://github.com/Lienol/openwrt-package.git;other' feeds.conf.default
# 移除 openwrt feeds 自带的核心包
rm -rf feeds/packages/net/{xray-core,v2ray-core}
./scripts/feeds update -a -f && ./scripts/feeds install -a -f && make defconfig
# 使用我习惯的配置文件
wget --no-check-certificate -O .config https://raw.githubusercontent.com/szdosar/ish/master/passwall2-lite.config
rm -rf ./tmp
# 更新 golang 1.22 版本
bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/szdosar/ish/master/update_golang.sh')
# 开始现在并编译
make download -j$(nproc) && make -j$(nproc)
