#!/bin/bash

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 USERNAME [--socks5]"
    exit 1
fi

USERNAME=$1
WITH_SOCKS5=false

if [ "$#" -eq 2 ] && [ "$2" == "--socks5" ]; then
    WITH_SOCKS5=true
fi

PUBLIC_IPV4=$(dig +short myip.opendns.com @resolver1.opendns.com)
PASSWORD=$(openssl rand -base64 12 | tr -d '/+=')

apt-get update

echo "Installation de Squid (HTTP Proxy)..."
wget https://raw.githubusercontent.com/serverok/squid-proxy-installer/master/squid3-install.sh -O squid3-install.sh
bash squid3-install.sh

/usr/bin/htpasswd -b -c /etc/squid/passwd "$USERNAME" "$PASSWORD"

systemctl enable squid
systemctl start squid

if [ "$WITH_SOCKS5" = true ]; then
    echo "Installation de Dante (SOCKS5 Proxy)..."
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
    systemctl start danted
fi

echo "========================================"
echo "Proxy HTTP configuré :"
echo "Adresse : $PUBLIC_IPV4"
echo "Port    : 3128"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"

if [ "$WITH_SOCKS5" = true ]; then
    echo "========================================"
    echo "Proxy SOCKS5 configuré :"
    echo "Adresse : $PUBLIC_IPV4"
    echo "Port    : 1080"
    echo "Username: $USERNAME"
    echo "Password: $PASSWORD"
fi

echo "========================================"

echo "Test proxy HTTP..."
HTTP_TEST=$(curl -s --proxy http://$USERNAME:$PASSWORD@$PUBLIC_IPV4:3128 http://www.google.com -o /dev/null -w "%{http_code}")
if [ "$HTTP_TEST" -eq 200 ]; then
    echo "Le proxy HTTP fonctionne correctement."
else
    echo "Échec du test du proxy HTTP, code de réponse : $HTTP_TEST"
fi

if [ "$WITH_SOCKS5" = true ]; then
    echo "Test proxy SOCKS5..."
    SOCKS_TEST=$(curl -s --socks5 $PUBLIC_IPV4:1080 http://www.google.com -o /dev/null -w "%{http_code}")
    if [ "$SOCKS_TEST" -eq 200 ]; then
        echo "Le proxy SOCKS5 fonctionne correctement."
    else
        echo "Échec du test du proxy SOCKS5, code de réponse : $SOCKS_TEST"
    fi
fi

echo "========================================"