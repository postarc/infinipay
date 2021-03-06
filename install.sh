#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='ifp.conf'
COIN_DAEMON='ifpd'
CONFIGFOLDER='.ifp'
COIN_CLI='ifp-cli'
COIN_TGZ='https://github.com/infinipay/infinipay/releases/download/v1.0/infinipay.tar.gz'
COIN_ZIP='infinipay.tar.gz'
COIN_NAME='ifp'
COIN_PORT=11425
RPC_PORT=11426
PORT=11425
TRYCOUNT=7
WAITP=10
if [[ "$USER" == "root" ]]; then
        HOMEFOLDER="/root"
 else
        HOMEFOLDER="/home/$USER"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'



while [ -n "$(sudo lsof -i -s TCP:LISTEN -P -n | grep $RPC_PORT)" ]
do
(( RPC_PORT++))
done
echo -e "${GREEN}Free RPCPORT address:$RPC_PORT${NC}"
while [ -n "$(sudo lsof -i -s TCP:LISTEN -P -n | grep $PORT)" ]
do
(( PORT--))
done
echo -e "${GREEN}Free MN port address:$PORT${NC}"

function download_node() {
if [ ! -f "/usr/local/bin/ifpd" ]; then
  echo -e "Download $COIN_NAME"
  cd
  wget -q $COIN_TGZ
  tar xvzf $COIN_ZIP
  rm $COIN_ZIP
  chmod +x $COIN_DAEMON $COIN_CLI
  sudo chown -R root:users /usr/local/bin/
  sudo bash -c "cp $COIN_CLI /usr/local/bin/"
  sudo bash -c "cp $COIN_DAEMON /usr/local/bin/"
  rm $COIN_CLI
  rm $COIN_DAEMON
  #clear
else
  echo -e "${GREEN}Bin files exist. Skipping copy...${NC}"
fi
}


function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
rpcallowip=127.0.0.1
listen=0
server=1
daemon=1
EOF
}

function create_key() {
echo "Input masternode key or ENTER:"
read -e COINKEY
 if [[ -z "$COINKEY" ]]; then
   /usr/local/bin/$COIN_DAEMON -reindex
   sleep $WAITP
    if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
     echo -e "${RED}$COIN_NAME server couldn not start.${NC}"
     exit 1
    fi
  COINKEY=$($COIN_CLI masternode genkey)
  ERROR=$?
  while [ "$ERROR" -gt "0" ] && [ "$TRYCOUNT" -gt "0" ]
  do
  sleep $WAITP
  COINKEY=$($COIN_CLI masternode genkey)
  ERROR=$?
    if [ "$ERROR" -gt "0" ];  then
      echo -e "${GREEN}Wallet not fully loaded. Let us wait and try again to generate the Private Key${NC}"
      
    fi
  TRYCOUNT=$[TRYCOUNT-1]
  done
 /usr/local/bin/$COIN_CLI stop
 fi
#clear
}

function update_config() {
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE

masternode=1
externalip=$NODEIP
bind=$NODEIP
masternodeaddr=$NODEIP:$COIN_PORT
port=$PORT
masternodeprivkey=$COINKEY

addnode=167.114.128.89
addnode=80.211.99.28
addnode=139.162.85.250
addnode=95.179.148.91
addnode=142.44.162.93
addnode=89.46.196.185
addnode=95.164.8.207
addnode=89.36.214.32
addnode=96.79.4.195
addnode=45.76.182.145
addnode=213.175.79.223
EOF
}



function get_ip() {
NODEIP=$(curl -s4 icanhazip.com)
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${GREEN}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
#  exit 1
fi

if [[ $EUID -eq 0 ]]; then
   echo -e "${GREEN}$0 must be run without sudo.${NC}"
   exit 1
fi

if [ ! -n "ps -u $USER | grep $COIN_DAEMON" ] && [ -d "$HOMEFOLDER/$CONFIGFOLDER" ] ; then
  echo -e "${GREEN}$COIN_NAME is already installed.${NC}"
  exit 1
fi
}


function prepare_system() {
echo -e "Installing ${GREEN}$COIN_NAME${NC} Masternode."
sudo apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
sudo apt install -y software-properties-common >/dev/null 2>&1
sudo apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
sudo apt-get update >/dev/null 2>&1
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev  libdb5.3++ libzmq5 unzip | awk '{printf "\r" $0}'
if [ "$?" -gt "0" ];
  then
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban pkg-config libevent-dev libzmq5"
 exit 1
fi

#clear
}

function ifp_autorun() {
#setup cron
cd
mkdir script
echo '#!/bin/bash' > script/start.sh
echo -e "\nif [ -f "$HOMEFOLDER/$CONFIGFOLDER/ifpd.pid" ]; then /usr/local/bin/ifpd -reindex ; else /usr/local/bin/ifpd -daemon ; fi" >> script/start.sh
chmod +x script/start.sh
crontab -l > tempcron
echo -e "SHELL=/bin/bash\nMAILTO=$USER\n\n" >> tempcron
echo -e "@reboot  $HOMEFOLDER/script/start.sh" >> tempcron
crontab tempcron
rm tempcron
}

function important_information() {
 echo
 echo -e "=====================Infinipay====================="
 echo -e "$COIN_NAME Masternode is up and running listening on port ${GREEN}$COIN_PORT${NC}."
 echo -e "Configuration file is: ${GREEN}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "VPS_IP:PORT ${GREEN}$NODEIP:$COIN_PORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${GREEN}$COINKEY${NC}"
 echo -e "=====================Infinipay====================="
 echo -e "Start node: ifpd -daemon"
 echo -e "Stop node: ifp-cli stop"
 echo -e "Block sync status: ifp-cli getinfo"
 echo -e "Node sync status: ifp-cli mnsync status"
 echo -e "Masternode status: ifp-cli masternode status"
}

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  ifp_autorun
  important_information  
}


##### Main #####
#clear
checks
prepare_system
download_node
setup_node
rm -rf infinipay
if [ -n "$(ps -u $USER | grep $COIN_DAEMON)" ]; then
	pID=$(ps -u $USER | grep $COIN_DAEMON | awk '{print $1}')
	kill -9 ${pID}
 fi
sleep 1
$COIN_DAEMON -reindex
