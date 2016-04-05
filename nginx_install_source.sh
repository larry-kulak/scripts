#!/bin/bash
# Define Vars

nginx_install_d="/etc/nginx"
nginx_install_version="1.9.12"
nginx_user="nginx"
nginx_group="nginx"
nginx_user_uid=497
nginx_user_gid=524
hmnmv="v0.29"

pkgs=(gcc gcc-c++ make zlib-devel pcre-devel pcre-devel openssl-devel git wget nano tar autoconf automake initscripts rpm-build epel-release fcgi-devel spawn-fcgi )


function install_deps () {

# lets loop through array and get packages installed

for pkg in ${pkgs[@]}
do
yum install ${pkg} -y -q
done
}

# get nginx 
function get_nginx () {
if [ ! -d /tmp/nginx-${nginx_install_version} ]
then
cd /tmp
wget http://nginx.org/download/nginx-${nginx_install_version}.tar.gz
tar -xvf nginx-${nginx_install_version}.tar.gz
else
echo "already downloaded"
fi
}

# get modules for nginx nginx_headers nginx_http_shibboleth 

function get_modules () {

if [ ! -d /tmp/headers-more-nginx-module-0.29 ]
 then
  cd /tmp
    wget https://github.com/openresty/headers-more-nginx-module/archive/${hmnmv}.tar.gz
    tar xvf ${hmnmv}.tar.gz
  else
    echo "version of headers-more-nginx-module v ${hmnmv} already there"
fi

if [ ! -d /tmp/nginx-http-shibboleth ]
  then
    git clone https://github.com/nginx-shib/nginx-http-shibboleth.git
  else
    echo "shibboleth dir already exists"
  fi

}


# compile nginx module

function compile_nginx () {

# check if already compiled

if [ ! -f /usr/sbin/nginx ]
  then
    cd /tmp/nginx-${nginx_install_version}

./configure \
  --user=${nginx_user}                          \
  --group=${nginx_group}                         \
  --prefix=${nginx_install_d}                  \
  --sbin-path=/usr/sbin/nginx           \
  --conf-path=/etc/nginx/nginx.conf     \
  --pid-path=/var/run/nginx.pid         \
  --lock-path=/var/run/nginx.lock       \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --with-http_gzip_static_module        \
  --with-http_stub_status_module        \
  --with-http_ssl_module                \
  --with-pcre                           \
  --with-file-aio                       \
  --with-http_realip_module             \
  --add-module=../nginx-http-shibboleth/\
  --add-module=../headers-more-nginx-module-0.29

cd /tmp/nginx-${nginx_install_version}
make
make install

else
  echo "looks like nginx is already compiled"
fi
}

# add nginx user and group

function add_user_group () {

 # check if group is already there

 #nginx_g=$(cat /etc/group | cut -d: -f1 | grep nginx )
 #
 #if [ "${nginx_g}" = "nginx" ]
 # then 
 #   echo "group already there"
 # else
 #   groupadd -g ${nginx_user_gid} ${nginx_group}
 #fi

 # check if nginx user is already there

 nginx_u=$(cat /etc/passwd | cut -d: -f1 | grep nginx )
  
  if [ "${nginx_u}" = "nginx" ]
    then 
     echo "user already there skipping"
    else 
      useradd -c "Nginx Service Account" -r -u ${nginx_user_uid} -s /bin/bash ${nginx_user}
      #usermod -g ${nginx_group} ${nginx_user}
    fi
}

# get rhel release

function find_redhat_release () {

redhat_release=$(cat /etc/redhat-release)

IFS=' ' read -a release <<< "${redhat_release}"

#echo "${release[-2]}"

if [[ ${release[-2]} =~ ^7 ]]
  then 
    release=7
fi

}

# setup service

function setup_nginx_service () {

if [ ! -f /etc/init.d/nginx ]
  then
    cat <<'AOT' > "/etc/init.d/nginx"
#!/bin/bash
#
# nginx - this script starts and stops the nginx daemon
# chkconfig:   - 85 15
# description:  NGINX is an HTTP(S) server, HTTP(S) reverse \
#               proxy and IMAP/POP3 proxy server
# processname: nginx
# config:      /etc/nginx/nginx.conf
# config:      /etc/sysconfig/nginx
# pidfile:     /var/run/nginx.pid

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ "$NETWORKING" = "no" ] && exit 0

nginx="/usr/sbin/nginx"
prog=$(basename $nginx)

NGINX_CONF_FILE="/etc/nginx/nginx.conf"

[ -f /etc/sysconfig/nginx ] && . /etc/sysconfig/nginx

lockfile=/var/lock/subsys/nginx

make_dirs() {
   # make required directories
   user=`$nginx -V 2>&1 | grep "configure arguments:" | sed 's/[^*]*--user=\([^ ]*\).*/\1/g' -`
   if [ -z "`grep $user /etc/passwd`" ]; then
       useradd -M -s /bin/nologin $user
   fi
   options=`$nginx -V 2>&1 | grep 'configure arguments:'`
   for opt in $options; do
       if [ `echo $opt | grep '.*-temp-path'` ]; then
           value=`echo $opt | cut -d "=" -f 2`
           if [ ! -d "$value" ]; then
               # echo "creating" $value
               mkdir -p $value && chown -R $user $value
           fi
       fi
   done
}

start() {
    [ -x $nginx ] || exit 5
    [ -f $NGINX_CONF_FILE ] || exit 6
    make_dirs
    echo -n $"Starting $prog: "
    daemon $nginx -c $NGINX_CONF_FILE
    retval=$?
    echo
    [ $retval -eq 0 ] && touch $lockfile
    return $retval
}

stop() {
    echo -n $"Stopping $prog: "
    killproc $prog -QUIT
    retval=$?
    echo
    [ $retval -eq 0 ] && rm -f $lockfile
    return $retval
}

restart() {
    configtest || return $?
    stop
    sleep 1
    start
}

reload() {
    configtest || return $?
    echo -n $"Reloading $prog: "
    killproc $nginx -HUP
    RETVAL=$?
    echo
}

force_reload() {
    restart
}

configtest() {
  $nginx -t -c $NGINX_CONF_FILE
}

rh_status() {
    status $prog
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}

case "$1" in
    start)
        rh_status_q && exit 0
        $1
        ;;
    stop)
        rh_status_q || exit 0
        $1
        ;;
    restart|configtest)
        $1
        ;;
    reload)
        rh_status_q || exit 7
        $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 0
            ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}"
        exit 2
esac
AOT

# change to execute
chmod +x /etc/init.d/nginx

# create service based on os_version

if [ ${release} -eq 7  ]
  then
    systemctl enable nginx
    systemctl start nginx
  else
    chkconfig nginx on
    service nginx start
  fi
fi

}

# call all the functions
function orchestrate () {

install_deps
get_nginx
get_modules
compile_nginx
add_user_group
find_redhat_release
setup_nginx_service

}

orchestrate


# destroy vars
unset release
unset nginx_u
unset nginx_g 
unset nginx_install_d
unset nginx_install_version
unset nginx_user
unset nginx_group
unset nginx_user_uid
unset nginx_user_gid
unset hmnmv
