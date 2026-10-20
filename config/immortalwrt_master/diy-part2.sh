#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: DIY script (After updating feeds — modify the default IP, hostname, theme, add/remove packages, etc.)
# Source code repository: https://github.com/immortalwrt/immortalwrt / Branch: master
#========================================================================================================================

# ------------------------------- Main source configuration -------------------------------
#
# Set the default LAN IP address
default_ip="192.168.1.1"
ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
# Override default IP if a valid custom IP is provided as the first argument
[[ -n "${1}" && "${1}" != "${default_ip}" && "${1}" =~ ${ip_regex} ]] && {
    echo "Modify default IP address to: ${1}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${1}\"}/" package/base-files/*/bin/config_generate
}

# Set the default password for the 'root' user (change empty password to 'password')
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

# Append source repository information to etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEREPO='github.com/immortalwrt/immortalwrt'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='immortalwrt'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEBRANCH='master'" >>package/base-files/files/etc/openwrt_release

# Configure ccache for build acceleration
# Remove existing ccache settings
sed -i '/CONFIG_DEVEL/d' .config
sed -i '/CONFIG_CCACHE/d' .config
# Apply new ccache configuration
if [[ "${2}" == "true" ]]; then
    echo "CONFIG_DEVEL=y" >>.config
    echo "CONFIG_CCACHE=y" >>.config
    echo 'CONFIG_CCACHE_DIR="$(TOPDIR)/.ccache"' >>.config
else
    echo '# CONFIG_DEVEL is not set' >>.config
    echo "# CONFIG_CCACHE is not set" >>.config
    echo 'CONFIG_CCACHE_DIR=""' >>.config
fi
#
# ------------------------------- Main source configuration ends -------------------------------

# ------------------------------- Additional customizations -------------------------------
#
# Add luci-app-amlogic
rm -rf package/luci-app-amlogic
git clone -b main https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic

# Add Clashoo (multi-package repository: clashoo + luci-app-clashoo)
# Clone into package/ instead of adding a feed, so no bogus entry is written
# into the firmware's package source list.
rm -rf package/openwrt-clashoo
git clone --depth 1 https://github.com/kenzok8/openwrt-clashoo.git package/openwrt-clashoo

# Write the default network configuration directly
# [ config_generate ] only generates /etc/config/network when the file does not
# exist, so writing it here makes the settings take effect from the first boot
lan_ip="${1}"
[[ -n "${lan_ip}" && "${lan_ip}" =~ ${ip_regex} ]] || lan_ip="${default_ip}"
mkdir -p files/etc/config
if [[ "${3}" == "true" ]]; then
    echo "Enable bypass router mode default settings."
    # Side-gateway mode: gateway/DNS point to the main router, no DHCPv4.
    # IPv6 stays enabled so this device can still reach IPv6 networks.
    net_extra="	option gateway '192.168.0.1'
	option dns '192.168.0.1'"
    dhcp_lan="	option ignore '1'
	option dhcpv4 'disabled'
	option dhcpv6 'disabled'
	option ra 'disabled'"
    # IPv6 forwarding is enabled by default, which makes the kernel set
    # accept_ra to 0 and ignore the main router's Router Advertisements.
    # Accept RAs explicitly so this single-NIC side gateway obtains a global
    # IPv6 address and a default route from the main router.
    mkdir -p files/etc/sysctl.d
    cat > files/etc/sysctl.d/99-ipv6-accept-ra.conf <<EOF
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.default.accept_ra=2
net.ipv6.conf.br-lan.accept_ra=2
EOF
else
    net_extra="	option ip6assign '60'"
    dhcp_lan="	option dhcpv4 'server'
	option dhcpv6 'server'
	option ra 'server'"
fi
cat > files/etc/config/network <<EOF
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'eth0'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '${lan_ip}'
	option netmask '255.255.255.0'
${net_extra}
EOF
cat > files/etc/config/dhcp <<EOF
config dnsmasq
	option domainneeded '1'
	option boguspriv '1'
	option filterwin2k '0'
	option localise_queries '1'
	option rebind_protection '1'
	option rebind_localhost '1'
	option local '/lan/'
	option domain 'lan'
	option expandhosts '1'
	option nonegcache '0'
	option cachesize '1000'
	option authoritative '1'
	option readethers '1'
	option leasefile '/tmp/dhcp.leases'
	option resolvfile '/tmp/resolv.conf.d/resolv.conf.auto'
	option nonwildcard '1'
	option localservice '1'
	option ednspacket_max '1232'

config dhcp 'lan'
	option interface 'lan'
	option start '100'
	option limit '150'
	option leasetime '12h'
${dhcp_lan}
	option ra_slaac '1'
	list ra_flags 'managed-config'
	list ra_flags 'other-config'
	option ndp 'disabled'

config odhcpd 'odhcpd'
	option maindhcp '0'
	option leasefile '/tmp/hosts/odhcpd'
	option leasetrigger '/usr/sbin/odhcpd-update'
	option loglevel '4'
EOF
#
# Apply patches
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Additional customizations ends -------------------------------
