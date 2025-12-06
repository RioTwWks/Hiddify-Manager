#!/bin/bash

mkdir /hiddify-data/ssl/
rm -rf /opt/hiddify-manager/log/*.lock

# Check and set REDIS_URI_MAIN
if [ -z "$REDIS_URI_MAIN" ]; then
  if [ -n "$REDIS_PASSWORD" ] && [ "$REDIS_PASSWORD" != "your-strong-password" ]; then
  export REDIS_URI_MAIN="redis://:${REDIS_PASSWORD}@redis:6379/0"
  else
    # Redis without password
    export REDIS_URI_MAIN="redis://redis:6379/0"
  fi
fi

# Check and set REDIS_URI_SSH
if [ -z "$REDIS_URI_SSH" ]; then
  if [ -n "$REDIS_PASSWORD" ] && [ "$REDIS_PASSWORD" != "your-strong-password" ]; then
    export REDIS_URI_SSH="redis://:${REDIS_PASSWORD}@redis:6379/1"
  else
    # Redis without password
    export REDIS_URI_SSH="redis://redis:6379/1"
  fi
fi

# Export variables to environment file so they're available to all processes
# This ensures hiddify-panel/run.sh can access them
echo "export REDIS_URI_MAIN=\"$REDIS_URI_MAIN\"" >> /etc/environment
echo "export REDIS_URI_SSH=\"$REDIS_URI_SSH\"" >> /etc/environment

# Check and set SQLALCHEMY_DATABASE_URI
if [ -z "$SQLALCHEMY_DATABASE_URI" ]; then
  if [ -z "$MYSQL_PASSWORD" ]; then
    echo "One of the env variables MYSQL_PASSWORD or SQLALCHEMY_DATABASE_URI must be set"
    exit 1
  fi
  export SQLALCHEMY_DATABASE_URI="mysql+mysqldb://hiddifypanel:${MYSQL_PASSWORD}@mariadb/hiddifypanel?charset=utf8mb4"
fi


cd $(dirname -- "$0")

# Check systemctl is setup correctly for docker.
systemctl is-active --quiet hiddify-panel
if [ $? -ne 0 ]; then
  echo "systemctl returned non-zero exit code. Re install systemctl..."
  cp other/docker/* /usr/bin/
  systemctl restart hiddify-panel
fi

DO_NOT_INSTALL=true ./install.sh docker --no-gui $@

# Fix package hashes and install missing components after installation
echo "Applying post-installation fixes..."

# Fix singbox hash in packages.lock if it's outdated
if grep -q "singbox|1.8.8.h4|amd64.*7f1eae5d24543d91e0a2183aa5b63a256cc5b16874a1f8a5937860e882799c34" common/packages.lock 2>/dev/null; then
  echo "Updating singbox hash in packages.lock..."
  sed -i "s|7f1eae5d24543d91e0a2183aa5b63a256cc5b16874a1f8a5937860e882799c34|298a6073500c708f056132d75bc06b50dbdcb84c413fd6c1132b7c71164016b3|" common/packages.lock
fi

# Install singbox if missing
if [ ! -f singbox/sing-box ]; then
  echo "Installing singbox..."
  cd singbox && rm -f sb.zip && bash install.sh >/dev/null 2>&1 && cd ..
fi

# Create symlink for sing-box if missing
if [ ! -f /usr/bin/sing-box ] && [ -f singbox/sing-box ]; then
  echo "Creating sing-box symlink..."
  ln -sf /opt/hiddify-manager/singbox/sing-box /usr/bin/sing-box
fi

# Fix obfs-server path in service file if needed
if [ -f /etc/systemd/system/hiddify-ss-faketls.service ] && grep -q "^ExecStart=obfs-server" /etc/systemd/system/hiddify-ss-faketls.service; then
  echo "Fixing obfs-server path in hiddify-ss-faketls.service..."
  sed -i "s|^ExecStart=obfs-server|ExecStart=/usr/bin/obfs-server|" /etc/systemd/system/hiddify-ss-faketls.service
fi

# Install ssh-liberty-bridge if missing
if [ ! -f other/ssh/ssh-liberty-bridge ]; then
  echo "Installing ssh-liberty-bridge..."
  cd other/ssh
  curl -sL -o ssh-liberty-bridge "https://github.com/RioTwWks/ssh-liberty-bridge/releases/download/v1.3.0/ssh-liberty-bridge-amd64" 2>/dev/null || \
    wget -q -O ssh-liberty-bridge "https://github.com/RioTwWks/ssh-liberty-bridge/releases/download/v1.3.0/ssh-liberty-bridge-amd64" 2>/dev/null
  if [ -f ssh-liberty-bridge ]; then
    chmod +x ssh-liberty-bridge
    chown liberty-bridge:liberty-bridge ssh-liberty-bridge 2>/dev/null || true
  fi
  cd ../..
fi

# Start singbox manually if not running (systemd doesn't work well in Docker)
# Kill any existing singbox processes first
pkill -9 sing-box 2>/dev/null || true
sleep 1

# Start singbox and wait for it to be ready
if [ -f /usr/bin/sing-box ] || [ -f singbox/sing-box ]; then
  echo "Starting singbox manually..."
  cd singbox
  nohup /usr/bin/sing-box run -C /opt/hiddify-manager/singbox/configs > /tmp/singbox.log 2>&1 &
  cd ..
  
  # Wait for singbox to start listening on port 10086
  echo "Waiting for singbox to start..."
  for i in {1..30}; do
    if netstat -tln 2>/dev/null | grep -q ":10086 " || ss -tln 2>/dev/null | grep -q ":10086 "; then
      echo "Singbox is ready on port 10086"
      break
    fi
    sleep 1
  done
fi

./status.sh --no-gui

echo Hiddify is started!!!! in 5 seconds you will see the system logs
sleep 5
tail -f /opt/hiddify-manager/log/system/*