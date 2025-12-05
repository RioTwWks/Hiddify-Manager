systemctl kill mtproxy.service


ln -sf  $(pwd)/mtproxy.service /etc/systemd/system/mtproxy.service
systemctl enable mtproxy.service
# Set permissions so DynamicUser can read the config file
# Directory must be readable and executable by others for DynamicUser to access files
chmod 755 $(pwd)
chmod 644 *toml* 2>/dev/null || chmod 600 *toml*
# Ensure parent directories are accessible
chmod 755 /opt/hiddify-manager/other/telegram 2>/dev/null || true
chmod 755 /opt/hiddify-manager/other 2>/dev/null || true
systemctl restart mtproxy.service

systemctl status mtproxy --no-pager