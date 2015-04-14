#!/bin/bash

WEBSITE="https://www.ipvanish.com/software/configs"
FOLDER="$HOME/IpVanish"
CONFIG_FILES="$FOLDER/configs"

#Determine which linux distro is in use
if [ -f /etc/debian_version ]; then
	UPDATE="sudo apt-get update"
	REMOVE="sudo apt-get remove --purge -y "
	INSTALL="sudo apt-get install -y"
	PKGS="openvpn"
	ADD_PKGS="dnsutils geoip-bin"
elif [ -f /etc/redhat-release ]; then
	UPDATE="sudo yum update"
	INSTALL="sudo yum install -y"
	REMOVE="sudo yum remove -y "
	PKGS="openvpn"
	ADD_PKGS="geoip bind-utils"
else
	echo " This script is for Debian/Redhat based distributions." 
	echo " We cannot determine your linux distribution."
	echo " Please visit : https://www.ipvanish.com/vpn-setup/"
fi


#pre-configs
preconfig()
{
$UPDATE
$INSTALL $PKGS $ADD_PKGS
mkdir -p $CONFIG_FILES

check_if_already_installed
}

#check if previous version is installed
check_if_already_installed()
{
wget -P $FOLDER $WEBSITE/version -O $FOLDER/downloaded -o $FOLDER/wget.log > $FOLDER/log.out 2>&1
if [ -f $FOLDER/version ]; then
	version=`cat $FOLDER/version`
	downloaded=`cat $FOLDER/downloaded`
	if [ "$((version))" -ge "$((downloaded))" ]; then
		echo "Installed version is same or newer than the one available"
		mv $FOLDER/downloaded $FOLDER/version
		echo "DO you want to continue with the ping test itself? (Y/n)"
		read input
		if [ "$input" == "Y" ] || [ "$input" == "y" ]; then
			ping_test	
		elif [ "$input" == "n" ]; then
			exit 1
		else
			echo "Invalid Option...Exiting!"
			exit 1
		fi
	else
		echo "The version : $downloaded will be fetched from the servers"
		mv $FOLDER/downloaded $FOLDER/version		
	fi
fi

downloadfiles
}

#Download files and populate
downloadfiles()
{
echo "Downloading files and populating...Please wait"
wget -P $FOLDER -r -A "ovpn,crt" -np -nd -e robots=off $WEBSITE/ -o $FOLDER/wget.log > $FOLDER/log.out 2>&1 
mv $FOLDER/*.ovpn $CONFIG_FILES/  >> $FOLDER/log.out 2>&1
echo "Configuration files downloaded"

getserverlist
}

#Getting Server list
getserverlist()
{
echo -n "" > $FOLDER/online_servers
for name in $( ls $CONFIG_FILES/ );
do
	number=`echo $name | grep -o "-" | wc -l`
	server_name=`echo $name | sed -e "s/ovpn/ipvanish.com/" | cut -d "-" -f $number,$((number + 1))` 
	ping_time=`ping -c 3 -w 5 $server_name 2> /dev/null | grep avg | cut -d "/" -f 5`
	ping_time=`printf "%07.3f" $ping_time`
    if [ "$ping_time" != "000.000" ]; then
		echo "PING TIME: $ping_time SERVER: $name" | tee -a $FOLDER/online_servers
	fi
done 

echo "List of online servers is located at $FOLDER/online_servers " 

detectfastest
}

#Get the Fastest Server
detectfastest()
{
sort $FOLDER/online_servers | nl >  $FOLDER/fastest_servers
echo "Here is the list sorted by fastest servers."
cat $FOLDER/fastest_servers

connecttoserver
}

#connect with fastest server.
connecttoserver()
{
echo "Which server do you want to connect to? Insert number. Enter 1 to connect to fastest available server. "
echo "please refer to $CONFIG_FILES/$selected_servers"
read server_number
selected_servers=`cat $FOLDER/fastest_servers | sed -n  "$server_number p" | awk '{print $6}'`
cd $FOLDER/
if [ "$selected_servers" != "" ]; then
	sudo openvpn --config $CONFIG_FILES/$selected_servers
else
	echo "1: $CONFIG_FILES   2: $selected_servers "
	pwd
fi

check_ip_address
}

check_ip_address()
{
check_if_add_pkgs

IPADD=`dig +short myip.opendns.com @resolver1.opendns.com`
echo "$IPADD"	
geoiplookup $IPADD



}

check_if_add_pkgs()
{




#GeT databases for geolite maxmind to narrow down Ip Address to Server Translation
#This database more information rather than just stating name of the country
cd $FOLDER/
echo "Retrieving Database  ..."
wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
wget http://download.maxmind.com/download/geoip/database/asnum/GeoIPASNum.dat.gz
echo "Extracting Database ..."
gunzip GeoIP.dat.gz
gunzip GeoIPASNum.dat.gz
gunzip GeoLiteCity.dat.gz
echo "Updating Database  ..."
sudo cp GeoIP.dat GeoIPASNum.dat GeoLiteCity.dat /usr/share/GeoIP/

}


#now lets decide the control
echo "what you want to do?"
echo "1. Install & Start IpVanish"
echo "2. Update & Start IpVanish "
echo "3. Detect fastest servers & Start IpVanish"
echo "4. Start IpVanish"
echo "5. Remove IpVanish config files."
echo "6. Purge IpVanish Completely. (also removes openvpn, dnsutils/bind-utils, geoip)"
echo "7. Check my IP Address"
echo "8. Exit"

read command_name

case $command_name in 
	1 ) 
		preconfig ;;
	
	2 ) 	
		check_if_already_installed ;;
	
	3 )
		getserverlist ;;
	
	4 ) 
		connecttoserver ;;
	
	5 )
		rm -rf $CONFIG_FILES ;;
	
	6 )
		rm -rf $FOLDER && $REMOVE $PKGS $ADD_PKGS ;;
	
	7 )
		check_ip_address ;;
	8 )
		exit ;;
esac
