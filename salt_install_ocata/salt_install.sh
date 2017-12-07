#/bin/sh

minionip=`ip a | awk 'NR==9 {print $0}' |awk -F/ '{print $1}' |awk '{print $2}'`
materip=$1
salt_mater(){
echo "关闭防火墙和selinux"
systemctl stop firewalld && setenforce 0
sed -i '7 s/enforcing/disabled/'  /etc/selinux/config

echo "配置yum源"
    if [ ! -f /etc/yum.repos.d/saltstack.repo ];then
        echo "[saltstack-repo]" >> /etc/yum.repos.d/saltstack.repo
        echo "name=SaltStack repo for Red Hat Enterprise Linux \$releasever" >> /etc/yum.repos.d/saltstack.repo
        echo "baseurl=https://repo.saltstack.com/yum/redhat/\$releasever/\$basearch/latest" >> /etc/yum.repos.d/saltstack.repo
        echo "enabled=1" >> /etc/yum.repos.d/saltstack.repo
        echo "gpgcheck=1" >> /etc/yum.repos.d/saltstack.repo
        echo "gpgkey=https://repo.saltstack.com/yum/redhat/\$releasever/$basearch/latest/SALTSTACK-GPG-KEY.pub" >> /etc/yum.repos.d/saltstack.repo
        echo "https://repo.saltstack.com/yum/redhat/\$releasever/\$basearch/latest/base/RPM-GPG-KEY-CentOS-7" >> /etc/yum.repos.d/saltstack.repo
    fi

echo "============================="
echo "安装SaltStack存储库和密钥跟解决依赖关系"
echo "============================="

yum -y install https://repo.saltstack.com/yum/redhat/salt-repo-2017.7-1.el7.noarch.rpm && yum clean expire-cache -y && yum upgrade -y && yum -y install epel-release && yum -y install zeromq3 m2crypto python-crypto python-jinja2 python-msgpack python-yaml python-zmq 

echo "salt-master安装"
yum install -y salt-master

sleep 3

echo "开始配置salt-master"
sed -i  '22 s/#//' /etc/salt/master
sed -i  '254a worker_threads: 100' /etc/salt/master
sed -i -e  '304 s/#//' -e '304 s/False/True/' /etc/salt/master
sed -i  '610,612 s/#//' /etc/salt/master
sed -i '612a\  dev:' /etc/salt/master
sed -i '613a\  - /srv/salt/dev' /etc/salt/master
sed -i '983a ret_port: 4506' /etc/salt/master
mkdir -p /srv/salt/
mkdir -p /srv/salt/dev/
chmod -R 755 /srv/

echo "启动salt-master"
systemctl start salt-master
}



salt_minion(){
echo "关闭防火墙和selinux"
systemctl stop firewalld && setenforce 0
sed -i '7 s/enforcing/disabled/'  /etc/selinux/config

echo "配置yum源"
    if [ ! -f /etc/yum.repos.d/saltstack.repo ];then
        echo "[saltstack-repo]" >> /etc/yum.repos.d/saltstack.repo
        echo "name=SaltStack repo for Red Hat Enterprise Linux \$releasever" >> /etc/yum.repos.d/saltstack.repo
        echo "baseurl=https://repo.saltstack.com/yum/redhat/\$releasever/\$basearch/latest" >> /etc/yum.repos.d/saltstack.repo
        echo "enabled=1" >> /etc/yum.repos.d/saltstack.repo
        echo "gpgcheck=1" >> /etc/yum.repos.d/saltstack.repo
        echo "gpgkey=https://repo.saltstack.com/yum/redhat/\$releasever/$basearch/latest/SALTSTACK-GPG-KEY.pub" >> /etc/yum.repos.d/saltstack.repo
        echo "https://repo.saltstack.com/yum/redhat/\$releasever/\$basearch/latest/base/RPM-GPG-KEY-CentOS-7" >> /etc/yum.repos.d/saltstack.repo
    fi

echo "============================="
echo "安装SaltStack存储库和密钥跟解决依赖关系"
echo "============================="

yum -y install https://repo.saltstack.com/yum/redhat/salt-repo-2017.7-1.el7.noarch.rpm && yum clean expire-cache -y && yum upgrade -y && yum -y install epel-release && yum -y install zeromq3 m2crypto python-crypto python-jinja2 python-msgpack python-yaml python-zmq

echo "salt-minionr安装"
yum install -y salt-minion

sleep 3

echo "开始配置salt-minion"
sed -i "16a master: $materip" /etc/salt/minion
sed -i '71 s/#//' /etc/salt/minion
sed -i "104a id: minion_$minionip" /etc/salt/minion
systemctl start salt-minion

echo "salt-minion安装完成，需要将mater重启一下，输入salt-key -L查看当前minion是否成功"

}

echo "salt_install "
echo "1.salt_mater_install"
echo "2.salt_minion_instal"
read -p "请输入数字选项" choise
case "$choise" in 
1)
	salt_mater
	;;
2)	salt_minion
	;;
q|Q)
	exit
	;;
*)
echo "输入有误，请重新输入"
esac 
