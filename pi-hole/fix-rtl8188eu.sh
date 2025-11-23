#fixes the rtl8188eu driver for buster (raspbian), since dhcp doesn't recognize the interface
#run this script as root

#adds the following lines to dhcpcd.conf
echo "interface wlan0
env ifwireless=1
env wpa_supplicant_driver=nl80211,wext" >> /etc/dhcpcd.conf

