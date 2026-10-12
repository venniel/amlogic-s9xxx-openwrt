#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: DIY script (Before updating feeds — modify the default IP, hostname, theme, add/remove packages, etc.)
# Source code repository: https://github.com/openwrt/openwrt / Branch: main
#========================================================================================================================

# Add a custom feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default
# Add the Clashoo feed (mihomo-based proxy LuCI app)
echo "src-git clashoo https://github.com/kenzok8/openwrt-clashoo.git" >> feeds.conf.default

# Remove unnecessary packages
# rm -rf package/utils/{ucode,fbtest}

