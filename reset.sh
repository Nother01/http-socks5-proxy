#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Veuillez exécuter ce script en tant que root."
    exit 1
fi

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 USERNAME"
    exit 1
fi

USERNAME=$1

echo "Suppression des services Squid et Dante..."

systemctl stop squid danted

systemctl disable squid danted

apt-get purge -y squid dante-server

rm -rf /etc/squid
rm -rf /etc/danted.conf
rm -rf /var/log/danted.log
rm -rf /etc/systemd/system/squid.service
rm -rf /etc/systemd/system/danted.service

if id "$USERNAME" &>/dev/null; then
    userdel -r "$USERNAME"
    echo "Utilisateur $USERNAME supprimé."
else
    echo "Utilisateur $USERNAME n'existe pas."
fi

echo "HTTP (Squid) et SOCKS5 (Dante) supprimés avec succès."
