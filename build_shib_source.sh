#!/usr/bin/env bash

# get epel release in case its missing

function get_epel () {

if [ ! -f /etc/yum.repos.d/epel.repo ]
 then
   yum install epel-release -q -y
 else
   echo "Epel release already installed"
fi

}

# get shib

function get_shib () {

if [ ! -f /etc/yum.repos.d/shibboleth.repo ]
 then
  wget http://download.opensuse.org/repositories/security://shibboleth/RHEL_6/security:shibboleth.repo -O /etc/yum.repos.d/shibboleth.repo
 else
  echo "Shib repo already installed"
fi

}

# install dependencies

mypkgs=(systemd-devel epel-release gcc-c++ rpm-build yum-utils libxerces-c-devel libxml-security-c-devel libxmltooling-devel xmltooling-schemas libsaml-devel opensaml-schemas liblog4shib-devel chrpath boost-devel doxygen unixODBC-devel fcgi-devel httpd-devel redhat-rpm-config pcre-devel zlib-devel libmemcached-devel)

function install_pkgs () {

for pkg in ${mypkgs[@]}
 do
 yum install -y -q ${pkg}
done

}

# compile shib rpm-build

function compile_shib_rpm () {

# test if file is already there
# get os version for epel

if [ ! -f /root/rpmbuild/RPMS/x86_64/shibboleth-2.5.6-3.1.el${rr}.x86_64.rpm ]
  then
  mkdir /tmp/shib
  cd /tmp/shib
  yumdownloader --source shibboleth
  rpmbuild --rebuild shibboleth*.src.rpm --with fastcgi --without builtinapache
  if [[ ${release[0]} =~ ^CentOS ]]
    then 
    yum install -y /root/rpmbuild/RPMS/x86_64/shibboleth-2.5.6-3.1.el${rr}.centos.x86_64.rpm
    else
    yum install -y /root/rpmbuild/RPMS/x86_64/shibboleth-2.5.6-3.1.el${rr}.x86_64.rpm
  fi
  else
    echo "rpm already exists... please remove it and /tmp/shib directory"
fi  

}


function find_redhat_release () {

redhat_release=$(cat /etc/redhat-release)

IFS=' ' read -a release <<< "${redhat_release}"

echo "${release[-2]}"

if [[ ${release[-2]} =~ ^7 ]]
  then 
    rr=7
fi

}


function start_enable_shibd () {

 if [ ${rr} -eq 7 ]
  then
    systemctl enable shibd
    systemctl start shibd
  else
    chkconfig shibd on
    chkconfig shibd start
  fi

}
 

function orchestrate () {

get_epel
get_shib
install_pkgs
find_redhat_release
compile_shib_rpm
start_enable_shibd

}


orchestrate

unset mypkgs
unset redhat_release
















