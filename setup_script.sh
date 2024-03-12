#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 USERNAME"
    exit 1
fi

PUBLIC_IPV4=$(dig +short myip.opendns.com @resolver1.opendns.com)
USERNAME=$1
PASSWORD=$(openssl rand -base64 12)

apt-get update

wget https://raw.githubusercontent.com/serverok/squid-proxy-installer/master/squid3-install.sh -O squid3-install.sh
bash squid3-install.sh

/usr/bin/htpasswd -b -c /etc/squid/passwd "$USERNAME" "$PASSWORD"

apt -y install dante-server

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

systemctl enable danted
systemctl enable squid
systemctl start danted
systemctl start squid

echo "Log $PUBLIC_IPV4 $USERNAME:$PASSWORD"
