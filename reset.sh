#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 USERNAME"
    exit 1
fi

USERNAME=$1
PASSWORD=$(openssl rand -base64 12 | tr -d '/+=')
PUBLIC_IPV4=$(dig +short myip.opendns.com @resolver1.opendns.com)

echo "Réinitialisation de la configuration HTTP/SOCKS5..."

systemctl stop squid danted
apt-get purge -y squid dante-server

apt-get update
wget https://raw.githubusercontent.com/serverok/squid-proxy-installer/master/squid3-install.sh -O squid3-install.sh
bash squid3-install.sh

htpasswd -b -c /etc/squid/passwd "$USERNAME" "$PASSWORD"

apt-get install -y dante-server

cat <<EOF > /etc/danted.conf
logoutput: /var/log/danted.log
internal: eth0 port = 1080
external: eth0
clientmethod: none
socksmethod: username
user.privileged: root
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}
client block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error connect disconnect
    socksmethod: username
}
socks block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
EOF

useradd "$USERNAME" --shell /usr/sbin/nologin
echo "$USERNAME:$PASSWORD" | chpasswd

systemctl enable squid danted
systemctl restart squid danted

echo "HTTP Proxy (Squid) configuré."
echo "SOCKS5 Proxy (Dante) configuré."
echo "Accès: $PUBLIC_IPV4 avec l'utilisateur $USERNAME et mot de passe $PASSWORD"
