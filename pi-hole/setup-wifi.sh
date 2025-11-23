#this script is used to setup wifi on a raspberry pi, using the wpa_supplicant.conf file
#run this script as root

#read the wifi country code from the user
echo "Enter the country code for your wifi card"
read countrycode
#set the wifi country code
echo "country=$countrycode" >> /etc/wpa_supplicant/wpa_supplicant.conf
#read the wifi SSID from the user
echo "Enter the SSID of your wifi network"
read ssid
#read the wifi password from the user
echo "Enter the password of your wifi network"
read password
#add the wifi network to the wpa_supplicant.conf file
echo "network={
    ssid=\"$ssid\"
    psk=\"$password\"
    }" >> /etc/wpa_supplicant/wpa_supplicant.conf