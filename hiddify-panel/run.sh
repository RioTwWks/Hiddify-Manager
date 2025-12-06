source ../common/utils.sh
activate_python_venv

echo -n "" >> ../log/system/panel.log
chown hiddify-panel ../log/system/panel.log

chown -R hiddify-panel:hiddify-panel . >/dev/null 2>&1
chmod 600 app.cfg


# set mysql password to flask app config
sed -i '/^SQLALCHEMY_DATABASE_URI/d' app.cfg
if [ -z "${SQLALCHEMY_DATABASE_URI}" ]; then
    if [ -z "${MYSQL_PASS}" ];then
        MYSQL_PASS=$(cat ../other/mysql/mysql_pass)
    fi
    SQLALCHEMY_DATABASE_URI="mysql+mysqldb://hiddifypanel:$MYSQL_PASS@localhost/hiddifypanel?charset=utf8mb4"
fi
echo "SQLALCHEMY_DATABASE_URI ='$SQLALCHEMY_DATABASE_URI'" >>app.cfg

sed -i '/^REDIS_URI/d' app.cfg

# In Docker, REDIS_URI_MAIN and REDIS_URI_SSH are set by docker-init.sh and exported to /etc/environment
# Try to source /etc/environment to get these variables if they're not already set
if [ -f "/etc/environment" ] && [ -z "${REDIS_URI_MAIN}" ]; then
    # Source /etc/environment to get REDIS_URI_MAIN and REDIS_URI_SSH
    set -a
    source /etc/environment 2>/dev/null || true
    set +a
fi

if [ -z "${REDIS_URI_MAIN}" ]; then
    if [ -z "${REDIS_PASS}" ];then
        REDIS_PASS=$(grep '^requirepass' "../other/redis/redis.conf" 2>/dev/null | awk '{print $2}')
    fi
    # Detect if running in Docker (check for HIDDIFY_DISABLE_UPDATE or /.dockerenv)
    if [ -n "${HIDDIFY_DISABLE_UPDATE}" ] || [ -f "/.dockerenv" ]; then
        # In Docker, use 'redis' as hostname (container name)
        REDIS_HOST="redis"
    else
        # Local installation, use localhost
        REDIS_HOST="127.0.0.1"
    fi
    # If REDIS_PASS is empty or not set, use Redis without password
    if [ -n "${REDIS_PASS}" ]; then
        REDIS_URI_MAIN="redis://:${REDIS_PASS}@${REDIS_HOST}:6379/0"
        REDIS_URI_SSH="redis://:${REDIS_PASS}@${REDIS_HOST}:6379/1"
    else
        REDIS_URI_MAIN="redis://${REDIS_HOST}:6379/0"
        REDIS_URI_SSH="redis://${REDIS_HOST}:6379/1"
    fi
fi

echo "REDIS_URI_MAIN = '$REDIS_URI_MAIN'">>app.cfg
echo "REDIS_URI_SSH = '$REDIS_URI_SSH'">>app.cfg



if [ -f "../config.env" ]; then
    # systemctl restart --now mariadb
    # sleep 4
    
    hiddify-panel-cli import-config -c $(pwd)/../config.env
    
    # doesn't load virtual env
    #su hiddify-panel -c "hiddifypanel import-config -c $(pwd)/../config.env"
    
    if [ "$?" == 0 ]; then
        mv ../config.env ../config.env.old
        # echo "temporary disable removing config.env"
    fi
fi
hiddify-panel-cli init-db

systemctl start hiddify-panel.service
systemctl restart hiddify-panel-background-tasks.service

