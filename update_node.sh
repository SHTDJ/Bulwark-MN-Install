#!/bin/bash

TARBALLURL="https://github.com/bulwark-crypto/Bulwark/releases/download/1.2.3/bulwark-1.2.3.0-linux64.tar.gz"
TARBALLNAME="bulwark-1.2.3.0-linux64.tar.gz"
BWKVERSION="1.2.3.0"

CHARS="/-\|"

clear
echo "This script will update your masternode to version 1.2.3."
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER=`ps u $(pgrep bulwarkd) | grep bulwarkd | cut -d " " -f 1`
USERHOME=`eval echo "~$USER"`

echo "Shutting down masternode..."
if [ -e /etc/systemd/system/bulwarkd.service ]; then
  systemctl stop bulwarkd
else
  su -c "bulwark-cli stop" $USER
fi

echo "Installing Bulwark 1.2.3..."
mkdir ./bulwark-temp && cd ./bulwark-temp
wget $TARBALLURL
tar -xzvf $TARBALLNAME && mv bin bulwark-$BWKVERSION
yes | cp -rf ./bulwark-$BWKVERSION/bulwarkd /usr/local/bin
yes | cp -rf ./bulwark-$BWKVERSION/bulwark-cli /usr/local/bin
cd ..
rm -rf ./bulwark-temp

if [ -e /usr/bin/bulwarkd ];then rm -rf /usr/bin/bulwarkd; fi
if [ -e /usr/bin/bulwark-cli ];then rm -rf /usr/bin/bulwark-cli; fi
if [ -e /usr/bin/bulwark-tx ];then rm -rf /usr/bin/bulwark-tx; fi

sed -i '/^addnode/d' $USERHOME/.bulwark/bulwark.conf

echo "Restarting Bulwark daemon..."
if [ -e /etc/systemd/system/bulwarkd.service ]; then
  systemctl start bulwarkd
else
  cat > /etc/systemd/system/bulwarkd.service << EOL
[Unit]
Description=bulwarkd
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/bulwarkd -conf=${USERHOME}/.bulwark/bulwark.conf -datadir=${USERHOME}/.bulwark
ExecStop=/usr/local/bin/bulwark-cli -conf=${USERHOME}/.bulwark/bulwark.conf -datadir=${USERHOME}/.bulwark stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
  sudo systemctl enable bulwarkd
  sudo systemctl start bulwarkd
fi
clear

echo "Your masternode is syncing. Please wait for this process to finish."

until su -c "bulwark-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 2
    echo -en "${CHARS:$i:1}" "\r"
  done
done

su -c "bulwark-cli masternode status" $USER

echo "" && echo "Masternode update completed." && echo ""
