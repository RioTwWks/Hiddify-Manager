systemctl kill mtproxy.service

# Ensure tgproxy user exists
if ! id -u tgproxy >/dev/null 2>&1; then
    useradd --no-create-home -s /usr/sbin/nologin tgproxy || true
fi

ln -sf  $(pwd)/mtproxy.service /etc/systemd/system/mtproxy.service
systemctl daemon-reload
systemctl enable mtproxy.service

# Set proper permissions for mtg.toml and mtg binary
chmod 600 *toml* 2>/dev/null || true
chown tgproxy:tgproxy *toml* 2>/dev/null || true
chmod 755 mtg 2>/dev/null || true
chown tgproxy:tgproxy mtg 2>/dev/null || true

# Ensure log directory exists and has proper permissions
mkdir -p /opt/hiddify-manager/log/system
chown tgproxy:tgproxy /opt/hiddify-manager/log/system/telegram.out.log /opt/hiddify-manager/log/system/telegram.err.log 2>/dev/null || true
touch /opt/hiddify-manager/log/system/telegram.out.log /opt/hiddify-manager/log/system/telegram.err.log
chown tgproxy:tgproxy /opt/hiddify-manager/log/system/telegram.out.log /opt/hiddify-manager/log/system/telegram.err.log

systemctl restart mtproxy.service

systemctl status mtproxy --no-pager