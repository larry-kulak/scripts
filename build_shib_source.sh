#!/usr/bin/env bash

# get epel release in case its missing


osarch=$(uname -i)


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

yum install -y -q wget
 
if [ ! -f /etc/yum.repos.d/shibboleth.repo ]
 then
  wget http://download.opensuse.org/repositories/security://shibboleth/${repo_path}/security:shibboleth.repo -O /etc/yum.repos.d/shibboleth.repo
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

if [ ! -f /root/rpmbuild/RPMS/${osarch}/shibboleth-2.5.6-3.1.el${rr}.${osarch}.rpm ]
  then
  mkdir /tmp/shib
  cd /tmp/shib
  yumdownloader --source shibboleth
  rpmbuild --rebuild shibboleth*.src.rpm --with fastcgi --without builtinapache
  #if [[ ${release[0]} =~ ^CentOS ]]
  # then 
    yum install -y /root/rpmbuild/RPMS/${osarch}/shibboleth-2.5.6-3.1.${osarch}.rpm
  #  else
  #  yum install -y /root/rpmbuild/RPMS/${osarch}/shibboleth-2.5.6-3.1.el${rr}.${osarch}.rpm
  #fi
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
  else 
    rr=6
fi

if [[ ${release[0]} =~ ^CentOS ]]
  then
  os="CentOS"
  if [[ ${rr} -eq 6 ]]
    then
      repo_path="CentOS_CentOS-${rr}"
      # echo "$repo_path"
  elif [[ ${rr} -eq 7 ]]
    then
      repo_path="${os}_${rr}"
  fi   
elif [[ ${release[0]} =~ ^Red ]]
  then
  os="RHEL"
  # since there is no shib for version 7 as per isntructions we need to use CentOS7
  if [[ ${rr } -eq 7 ]]
    then
      repo_path="CentOS_${rr}"
   elif [[ ${rr} -eq 6 ]]
     then
      repo_path="${os}_${rr}"
   fi
fi

echo ${repo_path}

}


function start_enable_shibd () {

 if [ ${rr} -eq 7 ]
  then
    systemctl enable shibd
    systemctl start shibd
  else
    chkconfig shibd on
    service shibd start
  fi

}
 

function orchestrate () {

find_redhat_release
get_shib
get_epel
install_pkgs
compile_shib_rpm
start_enable_shibd

}


orchestrate

unset mypkgs
unset redhat_release
unset repo_path
