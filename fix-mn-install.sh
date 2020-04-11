#!/bin/bash
#
# FIX Masternode Install Script to be run on Ubuntu and similar linux

# Project Name
PROJECT="fix"
PORT=17464

# Project Name uppercase
PROJ_U=${PROJECT^^}

GITHUB_REPO="NewCapital/"$PROJ_U"-Core"
GITHUB_URL="https://github.com/"$GITHUB_REPO

RELEASE_URL=$(curl -Ls -o /dev/null -w %{url_effective} $GITHUB_URL/releases/latest)
RELASE_TAG="${RELEASE_URL##*/}"
VERSION="${RELASE_TAG##${PROJECT}_v}"

LOGFILENAME=$PROJECT"-mn-install.log"

# Wallet (daemon) link
WALLETLINK=$GITHUB_URL"/releases/download/"$PROJECT"_v"$VERSION"/"$PROJECT"-"$VERSION"-MN-x86_64-linux-gnu.tar.gz"
# Snapshot file name
SNAPSHOTFNAME="snapshot.zip"
# Snapshot link
SNAPSHOTLINK=$GITHUB_URL"/releases/download/"$PROJECT"_v"$VERSION"/"$SNAPSHOTFNAME

DATADIRNAME="."$PROJECT											#datadir name
DAEMONFILE=$PROJECT"d"											#daemon file name
CLIFILE=$PROJECT"-cli"											#cli file name
CONF_FILE=$PROJECT".conf"										#conf file name
SERVICEFILE="/etc/systemd/system/"$PROJ_U".service"				#service file name

function print_welcome() {
    echo -e "  This script is for fresh installed Ubuntu.\n It will install ${PROJ_U} masternode, version ${VERSION}\n"
    echo -e "  ${RED}WARNING: Running this script will overwrite existing installation!${NC}\n"
    read -n1 -p " Press any key to continue or CTRL+C to exit ... " confirmtxt
    echo -e "  Starting new installation now...\n\n"
}

function install_updates_and_firewall() {
	echo -n "Do you want to install all needed updates and firewall settings (no if you did it before)? [y/n]: "
	read -n1  DOSETUP
	if [[ $DOSETUP =~ "y" ]] || [[ $DOSETUP =~ "Y" ]] ; then
		sudo apt-get update
		sudo apt-get -y upgrade
		sudo apt-get -y dist-upgrade

		sudo apt-get install -y ufw
		sudo ufw allow ssh/tcp
		sudo ufw limit ssh/tcp
		sudo ufw logging on
		sudo ufw allow 22
		sudo ufw allow $PORT
		echo "y" | sudo ufw enable
		sudo ufw status
	fi
}

function download_mn_wallet(){
	WALLETFILENAME="${WALLETLINK##*/}"
	echo -en "\n Downloading wallet ${WALLETFILENAME} \r"
	cd ~ && wget $WALLETLINK &>>${LOGFILE}
	[ $? -eq 0 ] && ec=0 || ec=1
	[ $ec -eq 0 ] && echo -en $STATUS0 || echo -en $STATUS1
}

function unzip_mn_wallet(){
	echo -e " Unzippinging the wallet \r"
	tar -xvzf $WALLETFILENAME
	[ $? -eq 0 ] && ec=0 || ec=1
	[ $ec -eq 0 ] && echo -en $STATUS0 || echo -en $STATUS1
}

function delete_downloaded_file(){
	echo -e " Deleting the file $WALLETFILENAME \r"
	rm $WALLETFILENAME
	[ $? -eq 0 ] && ec=0 || ec=1
	[ $ec -eq 0 ] && echo -en $STATUS0 || echo -en $STATUS1
}

function install_unzip_if_needed(){
	if ! [ -x "$(command -v unzip)" ];
	then
		echo -en "\n Installing unzip \r"
		sudo apt install unzip
		[ $? -eq 0 ] && ec=0 || ec=1
		[ $ec -eq 0 ] && echo -en $STATUS0 || echo -en $STATUS1
	fi
}

function install_snapshot(){
	install_unzip_if_needed
	#Change directiory to the DATA FOLDER
	mkdir -p $DATADIRNAME
	
	#Download snapshot file
	echo -en "\n Downloading snapshot ${SNAPSHOTFNAME} \r"
	cd ~ && wget $SNAPSHOTLINK &>>${LOGFILE}
	[ $? -eq 0 ] && ec=0 || ec=1
	if [[ $ec -eq 0 ]]
	then
		echo -en $STATUS0
	else
		echo -en "Snapshot not found. "$STATUS1
		return 1
	fi
		
	#Unzip snapshot file
	echo -e " Unzippinging the snapshot into $DATADIRNAME\r"
	unzip $SNAPSHOTFNAME -d $DATADIRNAME
	[ $? -eq 0 ] && ec=0 || ec=1
	[ $ec -eq 0 ] && echo -en $STATUS0 || echo -en $STATUS1
	
	#Delete the snapshot zip file
	rm $SNAPSHOTFNAME
}

function create_config_file(){
	IP=$(hostname -I | cut -d " " -f1)
	echo "Start configuring your masternodes..."
	echo "Your recognised IP address is:$IP"
	#sudo hostname -I | cut -d " " -f1
	echo -n "Is this the IP you wish to use for MasterNode ? [y/n]: "
	
	read -n1 IPDEFAULT
	
	if [[ $IPDEFAULT =~ "y" ]] || [[ $IPDEFAULT =~ "Y" ]] ; then
		echo -e "\nGreat! IP: $IP will be used"
	else
		echo -e "\nType the custom IP of this node, followed by [ENTER]:"
		read IP
		echo "Great! IP: $IP will be used"
	fi
	
	echo "Enter masternode private key for this node"
	echo -e "Hint: you can get private key in QTWallet => Tools => Debug Console, open console and run command \"masternode genkey\"\nInsert the new Masternoe Key: "
	read PRIVKEY
	CONF_DIR=~/$DATADIRNAME\/
	IP=$(hostname -I | cut -d " " -f1)
	mkdir -p $CONF_DIR
	[ $? -eq 0 ] && ec=0 || ec=1
	[ $ec -eq 0 ] && echo -en $STATUS0 || echo -en $STATUS1
	
	echo "Creating config file"
	echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >			$CONF_DIR/$CONF_FILE
	echo "rpcpassword=passw"`shuf -i 100000-10000000 -n 1` >>	$CONF_DIR/$CONF_FILE
	echo "rpcallowip=127.0.0.1" >>								$CONF_DIR/$CONF_FILE
	echo "server=1" >>											$CONF_DIR/$CONF_FILE
	echo "daemon=1" >>											$CONF_DIR/$CONF_FILE
	echo "logtimestamps=1" >>									$CONF_DIR/$CONF_FILE
	echo "maxconnections=256" >>								$CONF_DIR/$CONF_FILE
	echo "masternode=1" >>										$CONF_DIR/$CONF_FILE
	echo "externalip=$IP" >>									$CONF_DIR/$CONF_FILE
	echo "masternodeprivkey=$PRIVKEY" >>						$CONF_DIR/$CONF_FILE
}

function create_service_config_file(){
	echo "Creating service file"
	
	echo "[Unit]" > 								$SERVICEFILE
	echo "Description=${PROJ_U} service" >>			$SERVICEFILE
	echo "After=network.target" >>					$SERVICEFILE
	echo "[Service]" >>								$SERVICEFILE
	echo "User=root" >>								$SERVICEFILE
	echo "Group=root" >>							$SERVICEFILE
	echo "Type=forking" >>							$SERVICEFILE
	echo "ExecStart=/root/${DAEMONFILE} -daemon" >> $SERVICEFILE
	echo "ExecStop=/root/${CLIFILE} stop" >>		$SERVICEFILE
	echo "Restart=always" >>						$SERVICEFILE
	echo "PrivateTmp=true" >>						$SERVICEFILE
	echo "TimeoutStopSec=60s" >>					$SERVICEFILE
	echo "TimeoutStartSec=10s" >>					$SERVICEFILE
	echo "StartLimitInterval=120s" >>				$SERVICEFILE
	echo "StartLimitBurst=5" >>						$SERVICEFILE
	echo "[Install]" >>								$SERVICEFILE
	echo "WantedBy=multi-user.target" >>			$SERVICEFILE
}

function create_service_and_enable_autostart(){
	echo "Starting $PROJ_U.service"
	systemctl start $PROJ_U.service
	[ $? -eq 0 ] && ec=0 || ec=1
	[ $ec -eq 0 ] && echo -en $STATUS0 || echo -en $STATUS1
	echo "Enabling $PROJ_U.service"
	systemctl enable $PROJ_U.service
	[ $? -eq 0 ] && ec=0 || ec=1
	[ $ec -eq 0 ] && echo -en $STATUS0 || echo -en $STATUS1
}

function show_service_status(){
	echo "Show status: "
	systemctl status $PROJ_U.service
}


function print_devsupport_exit() {
	echo -e "\n Thank you for using this script.\n"
    echo -e "\n${GREEN} Your masternode configured\n"
	echo -e "You can check the sync status by running command: ${CLIFILE} getblockcount\n"
    echo " Exiting now..."
    exit 0
}


# constants / gui
    BLUE="\033[0;34m"
    PURPLE="\033[0;35m"
    GREEN="\033[0;32m"
    RED="\033[0;31m"
    ITA="\033[3m"
    NC="\033[0m" # Text Reset
    portlist=()

# main procedure
    #SCRIPTPATH=$(readlink -f $0)
    LOGFILE=$HOME/$LOGFILENAME
    cols=$(tput cols)
    if [ $cols -ge 100 ]; then cols=100; fi
    mv=$(expr $cols - 11)
    STATUSX="\033[${mv}C "
    STATUS1="\033[${mv}C [${RED} FAILED ${NC}]\n"   #[ FAILED ]
    STATUS0="\033[${mv}C [ ${GREEN} DONE ${NC} ]\n" #[  DONE  ]
    STATUS2="\033[${mv}C [${NC}  SKIP  ${NC}]\n"   #[ FAILED ]
#
# 1. Welcome screen
	print_welcome
# 2. Install Updates and Firewall
	install_updates_and_firewall
# 3. download new daemon & unzip & delete file in the end
	download_mn_wallet
	unzip_mn_wallet
	delete_downloaded_file
# 4.Download snapshot zip file, install and delete after
	install_snapshot
# 5.Create configuration file
	create_config_file
# 6.Create service: create file, enable & start service, show status
	create_service_config_file
	create_service_and_enable_autostart
	show_service_status
# 7.Finish
	print_devsupport_exit

