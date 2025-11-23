
# Usage function
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script interactively installs Pi-hole and PiVPN on a Raspberry Pi."
    echo "It can also configure WiFi, fix the rtl8188eu driver, and reset network services."
    echo "Run this script as root."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
    echo ""
    echo "During execution, you will be prompted to:"
    echo "  - Configure WiFi (runs setup-wifi.sh)"
    echo "  - Fix rtl8188eu driver (runs fix-rtl8188eu.sh)"
    echo "  - Reset dhcpcd, wpa_supplicant, and wifi interface"
    echo "  - Install Pi-hole (via official installer)"
    echo "  - Install PiVPN (via official installer)"
    echo ""
    echo "Example:"
    echo "  sudo $0"
}

# Parse arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi


#ask the user if they want to configure wifi
echo "Do you want to configure wifi? (y/n)"
read wifi
if [ $wifi = "y" ]
then
    #run the setup-wifi script
    chmod +x ./setup-wifi.sh
    ./setup-wifi.sh
fi


#ask the user if they wish to fix the rtl8188eu driver
echo "Do you wish to fix the rtl8188eu driver? (y/n)"
read fixdriver
if [ $fixdriver = "y" ]
then
    chmod +x ./fix-rtl8188eu.sh
    #run the fix-rtl8188eu script
    ./fix-rtl8188eu.sh
fi


#ask the user if they wish to reset dhcpcd, wpa_supplicant, and hostapd
echo "Do you wish to reset dhcpcd, wpa_supplicant, and the wifi interface (y/n)"
read reset
if [ $reset = "y" ]
then
    #restart the dhcpcd service
    systemctl restart dhcpcd

    #restart the wpasupplicant service
    systemctl restart wpa_supplicant

    #reset the wifi interface
    wpa_cli -i wlan0 reconfigure
fi



#print the wifi ip address
echo "Your wifi ip address is:"
ip addr show wlan0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1

#ask the user if he wants to install pi-hole
echo "Do you want to install pi-hole? (y/n)"
read pihole
if [ $pihole = "y" ]
then
    #install pi-hole
    curl -sSL https://install.pi-hole.net | bash
fi

#ask the user if he wants to install pivpn
echo "Do you want to install pivpn? (y/n)"
read pivpn
if [ $pivpn = "y" ]
then
    #install pivpn
    curl -L https://install.pivpn.io | bash
fi
