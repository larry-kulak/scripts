#!/bin/bash

# install supervisor

# define vars for conf file

susername="user"
spassword="password123"


function get_pip () {

yum install python-pip -y -q

if [ ! -f /etc/supervisord.conf ]
  then 
    supervisord_conf
    pip install supervisor
    mkdir /var/log/supervisor
  else
    echo "supervisord.conf exists skipping install"
fi 

}

function supervisord_conf () {
 cat <<EOM > "/etc/supervisord.conf"
[unix_http_server]
file=/tmp/supervisor.sock   ; (the path to the socket file)
;chmod=0700                 ; socket file mode (default 0700)
;chown=nobody:nogroup       ; socket file uid:gid owner
;username=${susername}      ; (default is no username (open server))
;password=${spassword}      ; (default is no password (open server))

;[inet_http_server]         ; inet (TCP) server disabled by default
;port=127.0.0.1:9001        ; (ip_address:port specifier, *:port for all iface)
;username=${susername}      ; (default is no username (open server))
;password=${spassword}      ; (default is no password (open server))

[supervisord]
logfile=/tmp/supervisord.log ; (main log file;default $CWD/supervisord.log)
logfile_maxbytes=50MB        ; (max main logfile bytes b4 rotation;default 50MB)
logfile_backups=10           ; (num of main logfile rotation backups;default 10)
loglevel=info                ; (log level;default info; others: debug,warn,trace)
pidfile=/tmp/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
nodaemon=false               ; (start in foreground if true;default false)
minfds=1024                  ; (min. avail startup file descriptors;default 1024)
minprocs=200                 ; (min. avail process descriptors;default 200)
;umask=022                   ; (process file creation umask;default 022)
;user=chrism                 ; (default is current user, required if root)
;identifier=supervisor       ; (supervisord identifier, default is 'supervisor')
;directory=/tmp              ; (default is not to cd during start)
;nocleanup=true              ; (don't clean up tempfiles at start;default false)
;childlogdir=/tmp            ; ('AUTO' child log dir, default $TEMP)
;environment=KEY="value"     ; (key value pairs to add to environment)
;strip_ansi=false            ; (strip ansi escape codes in logs; def. false)

; the below section must remain in the config file for RPC
; (supervisorctl/web interface) to work, additional interfaces may be
; added by defining them in separate rpcinterface: sections
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock ; use a unix:// URL  for a unix socket
;serverurl=http://127.0.0.1:9001 ; use an http:// url to specify an inet socket
;username=${susername}              ; should be same as http_username if set
;password=${spassword}                ; should be same as http_password if set
;prompt=mysupervisor         ; cmd line prompt (default "supervisor")
;history_file=~/.sc_history  ; use readline history if available

[fcgi-program:shibauthorizer]
command=/usr/lib64/shibboleth/shibauthorizer
socket=unix:///opt/shibboleth/shibauthorizer.sock
socket_owner=shibd:shibd
socket_mode=0665
user=shibd
stdout_logfile=/var/log/supervisor/shibauthorizer.log
stderr_logfile=/var/log/supervisor/shibauthorizer.error.log

[fcgi-program:shibresponder]
command=/usr/lib64/shibboleth/shibresponder
socket=unix:///opt/shibboleth/shibresponder.sock
socket_owner=shibd:shibd
socket_mode=0665
user=shibd
stdout_logfile=/var/log/supervisor/shibresponder.log
stderr_logfile=/var/log/supervisor/shibresponder.error.log
EOM

}

function setup_supervisor_service () {

 if [ ! -f /etc/init.d/supervisord ]
  then
    cat <<'EOM'> "/etc/init.d/supervisord"
#!/bin/bash
 
. /etc/init.d/functions
 
DAEMON=/usr/bin/supervisord
PIDFILE=/var/run/supervisord.pid
 
[ -x "$DAEMON" ] || exit 0
 
start() {
        echo -n "Starting supervisord: "
        if [ -f $PIDFILE ]; then
                PID=`cat $PIDFILE`
                echo supervisord already running: $PID
                exit 2;
        else
                daemon  $DAEMON --pidfile=$PIDFILE -c /etc/supervisord.conf
                RETVAL=$?
                echo
                [ $RETVAL -eq 0 ] && touch /var/lock/subsys/supervisord
                return $RETVAL
        fi
 
}
 
stop() {
        echo -n "Shutting down supervisord: "
        echo
        killproc -p $PIDFILE supervisord
        echo
        rm -f /var/lock/subsys/supervisord
        return 0
}
 
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status supervisord
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage:  {start|stop|status|restart}"
        exit 1
        ;;
esac
exit $? 
EOM

# make it executable 
chmod 755 /etc/init.d/supervisord

# start service
service supervisord start

fi


} 


function orchestrate () {

 get_pip
 supervisord_conf
 setup_supervisor_service

}


orchestrate

unset redhat_release
unset susername
unset spassword