#!/bin/bash
#配置前首先确保你的各个节点都有部署saltstack,计算节点之间需要做互信（虚拟机的热迁移需要）
#默认为双计算几点，如果有更多节点则修改脚本进行添加，下边的hosts文件部分也需要修改。
#请确保salt_install_ocata在/root目录下,请禁用compute的epel源
#如果在物理机上安装，请将nova_compute_old_phy.conf修改为nova_compute_old.conf
#请手动修改/etc/hosts文件，使得控制节点可以直接ping通compute主机名
CONTROLLER=10.22.4.51

COMPUTE01=10.22.4.50
RABBIT_PASS=123456
PLACEMENT_PASS=123456
NEUTRON_PASS=123456
NOVA_PASS=123456
PROVIDER_INTERFACE_NAME=enp0s10 #CONTROLLER的Provider网卡名

#COMPUTE02=10.22.4.52
#PROVIDER_INTERFACE_NAME2=enp0s10
#COMPUTE03=10.22.4.53
#PROVIDER_INTERFACE_NAME3=enp0s10
#COMPUTE04=10.22.4.54
#PROVIDER_INTERFACE_NAME4=enp0s10
#COMPUTE05=10.22.4.55
#PROVIDER_INTERFACE_NAME5=enp0s10



timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp yes
echo "时区已选择Asia/Shanghai，同步时间开启"

salt '*' cmd.run 'setenforce 0'
salt '*' cmd.run 'systemctl stop firewalld'
salt '*' cmd.run 'systemctl disable firewalld'

cp -f /etc/hosts /srv/salt
salt '*' cp.get_file salt://hosts /etc/hosts
echo "已同步minion节点和master节点hosts文件"

salt '*' cmd.run 'yum install -y chrony'
salt '*' cmd.run 'timedatectl set-timezone Asia/Shanghai'
salt '*' cmd.run 'timedatectl set-ntp yes'
cp $HOME/salt_install_ocata/chrony.conf /srv/salt
salt '*' cp.get_file salt://chrony.conf /etc/chrony.conf
salt '*' cmd.run 'systemctl enable chronyd.service'
salt '*' cmd.run 'systemctl start chronyd.service'
#由于有可能由于网络原因导致chrony同步时间不生效，为确保时间同步这里手动同步一次。
TIME=`date +%m%d%H%M%Y`
echo "时间同步完成"
salt '*' cmd.run "date $TIME"
echo "开始更新minion软件包"
salt '*' cmd.run 'yum upgrade -y'
echo "已同步最新软件包，开始安装openstack-ocata源"
salt '*' cmd.run 'yum install -y centos-release-openstack-ocata'
echo "安装完成，开始获取软件包列表"
salt '*' cmd.run 'yum clean all'
salt '*' cmd.run 'yum list'
echo "开始安装计算组件"
salt '*' cmd.run 'yum install -y openstack-nova-compute'
echo "计算组件安装完毕"
echo "开始安装网络组件"
salt '*' cmd.run 'yum install -y openstack-neutron-linuxbridge ebtables ipset'
echo "网络组件安装完毕"

echo "正在修改并分发COMPUTE01计算服务配置文件"

#MANAGEMENT_INTERFACE_IP_ADDRESS为管理网络IP地址
#PROVIDER_INTERFACE_NAME为公有网络网卡名
#OVERLAY_INTERFACE_IP_ADDRESS为管理网络IP地址

MANAGEMENT_INTERFACE_IP_ADDRESS=$COMPUTE01
MANAGEMENT_INTERFACE_IP_ADDRESS_2=$COMPUTE02

sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/nova_compute_old.conf > /srv/salt/nova.conf
sed -i "s/MANAGEMENT_INTERFACE_IP_ADDRESS/$MANAGEMENT_INTERFACE_IP_ADDRESS/g" /srv/salt/nova.conf
sed -i "s/PLACEMENT_PASS/$PLACEMENT_PASS/g" /srv/salt/nova.conf
sed -i "s/NOVA_PASS/$NOVA_PASS/g" /srv/salt/nova.conf
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /srv/salt/nova.conf
salt "minion_$COMPUTE01" cp.get_file salt://nova.conf /etc/nova/nova.conf
echo "COMPUTE01计算服务配置文件修改完成"

#echo "正在修改并分发COMPUTE02计算服务配置文件"
#sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/nova_compute_old.conf > /srv/salt/nova.conf
#sed -i "s/MANAGEMENT_INTERFACE_IP_ADDRESS/$MANAGEMENT_INTERFACE_IP_ADDRESS_2/g" /srv/salt/nova.conf
#sed -i "s/PLACEMENT_PASS/$PLACEMENT_PASS/g" /srv/salt/nova.conf
#sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /srv/salt/nova.conf
#sed -i "s/NOVA_PASS/$NOVA_PASS/g" /srv/salt/nova.conf
#salt "minion_$COMPUTE02" cp.get_file salt://nova.conf /etc/nova/nova.conf
#echo "COMPUTE02计算服务配置文件修改完成"

#MANAGEMENT_INTERFACE_IP_ADDRESS_3=$COMPUTE03
#echo "正在修改并分发COMPUTE03计算服务配置文件"
#sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/nova_compute_old.conf > /srv/salt/nova.conf
#sed -i "s/MANAGEMENT_INTERFACE_IP_ADDRESS/$MANAGEMENT_INTERFACE_IP_ADDRESS_3/g" /srv/salt/nova.conf
#sed -i "s/PLACEMENT_PASS/$PLACEMENT_PASS/g" /srv/salt/nova.conf
#sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /srv/salt/nova.conf
#sed -i "s/NOVA_PASS/$NOVA_PASS/g" /srv/salt/nova.conf
#salt "minion_$COMPUTE03" cp.get_file salt://nova.conf /etc/nova/nova.conf

#MANAGEMENT_INTERFACE_IP_ADDRESS_4=$COMPUTE04
#echo "正在修改并分发COMPUTE04计算服务配置文件"
#sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/nova_compute_old.conf > /srv/salt/nova.conf
#sed -i "s/MANAGEMENT_INTERFACE_IP_ADDRESS/$MANAGEMENT_INTERFACE_IP_ADDRESS_4/g" /srv/salt/nova.conf
#sed -i "s/PLACEMENT_PASS/$PLACEMENT_PASS/g" /srv/salt/nova.conf
#sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /srv/salt/nova.conf
#sed -i "s/NOVA_PASS/$NOVA_PASS/g" /srv/salt/nova.conf
#salt "minion_$COMPUTE04" cp.get_file salt://nova.conf /etc/nova/nova.conf

#MANAGEMENT_INTERFACE_IP_ADDRESS_5=$COMPUTE03
#echo "正在修改并分发COMPUTE05计算服务配置文件"
#sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/nova_compute_old.conf > /srv/salt/nova.conf
#sed -i "s/MANAGEMENT_INTERFACE_IP_ADDRESS/$MANAGEMENT_INTERFACE_IP_ADDRESS_5/g" /srv/salt/nova.conf
#sed -i "s/PLACEMENT_PASS/$PLACEMENT_PASS/g" /srv/salt/nova.conf
#sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /srv/salt/nova.conf
#sed -i "s/NOVA_PASS/$NOVA_PASS/g" /srv/salt/nova.conf
#salt "minion_$COMPUTE05" cp.get_file salt://nova.conf /etc/nova/nova.conf

salt '*' cmd.run 'systemctl enable libvirtd.service openstack-nova-compute.service'
salt '*' cmd.run 'systemctl restart libvirtd.service openstack-nova-compute.service'
salt '*' cmd.run 'systemctl status libvirtd.service openstack-nova-compute.service'


OVERLAY_INTERFACE_IP_ADDRESS=$COMPUTE01
echo "正在修改并分发COMPUTE01网络服务配置文件"
sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/neutron.conf > /srv/salt/neutron.conf
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /srv/salt/neutron.conf
salt "minion_$COMPUTE01" cp.get_file salt://neutron.conf /etc/neutron/neutron.conf
sed  "s/PROVIDER_INTERFACE_NAME/$PROVIDER_INTERFACE_NAME/g" $HOME/salt_install_ocata/linuxbridge_agent.ini > /srv/salt/linuxbridge_agent.ini
sed -i "s/OVERLAY_INTERFACE_IP_ADDRESS/$OVERLAY_INTERFACE_IP_ADDRESS/g" /srv/salt/linuxbridge_agent.ini
salt "minion_$COMPUTE01" cp.get_file salt://linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini



#OVERLAY_INTERFACE_IP_ADDRESS2=$COMPUTE02
#echo "正在修改并分发COMPUTE02网络服务配置文件"
#sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/neutron.conf > /srv/salt/neutron.conf
#sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /srv/salt/neutron.conf
#salt "minion_$COMPUTE02" cp.get_file salt://neutron.conf /etc/neutron/neutron.conf
#sed  "s/PROVIDER_INTERFACE_NAME/$PROVIDER_INTERFACE_NAME2/g" $HOME/salt_install_ocata/linuxbridge_agent.ini > /srv/salt/linuxbridge_agent.ini
#sed -i "s/OVERLAY_INTERFACE_IP_ADDRESS/$OVERLAY_INTERFACE_IP_ADDRESS2/g" /srv/salt/linuxbridge_agent.ini
#salt "minion_$COMPUTE02" cp.get_file salt://linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini

#OVERLAY_INTERFACE_IP_ADDRESS3=$COMPUTE03
#echo "正在修改并分发COMPUTE03网络服务配置文件"
#sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/neutron.conf > /srv/salt/neutron.conf
#sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /srv/salt/neutron.conf
#salt "minion_$COMPUTE03" cp.get_file salt://neutron.conf /etc/neutron/neutron.conf
#sed  "s/PROVIDER_INTERFACE_NAME/$PROVIDER_INTERFACE_NAME3/g" $HOME/salt_install_ocata/linuxbridge_agent.ini > /srv/salt/linuxbridge_agent.ini
#sed -i "s/OVERLAY_INTERFACE_IP_ADDRESS/$OVERLAY_INTERFACE_IP_ADDRESS3/g" /srv/salt/linuxbridge_agent.ini
#salt "minion_$COMPUTE03" cp.get_file salt://linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini

#OVERLAY_INTERFACE_IP_ADDRESS4=$COMPUTE04
#echo "正在修改并分发COMPUTE04网络服务配置文件"
#sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/neutron.conf > /srv/salt/neutron.conf
#sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /srv/salt/neutron.conf
#salt "minion_$COMPUTE04" cp.get_file salt://neutron.conf /etc/neutron/neutron.conf
#sed  "s/PROVIDER_INTERFACE_NAME/$PROVIDER_INTERFACE_NAME4/g" $HOME/salt_install_ocata/linuxbridge_agent.ini > /srv/salt/linuxbridge_agent.ini
#sed -i "s/OVERLAY_INTERFACE_IP_ADDRESS/$OVERLAY_INTERFACE_IP_ADDRESS4/g" /srv/salt/linuxbridge_agent.ini
#salt "minion_$COMPUTE04" cp.get_file salt://linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini

#OVERLAY_INTERFACE_IP_ADDRESS5=$COMPUTE05
#echo "正在修改并分发COMPUTE05网络服务配置文件"
#sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/neutron.conf > /srv/salt/neutron.conf
#sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /srv/salt/neutron.conf
#salt "minion_$COMPUTE05" cp.get_file salt://neutron.conf /etc/neutron/neutron.conf
#sed  "s/PROVIDER_INTERFACE_NAME/$PROVIDER_INTERFACE_NAME5/g" $HOME/salt_install_ocata/linuxbridge_agent.ini > /srv/salt/linuxbridge_agent.ini
#sed -i "s/OVERLAY_INTERFACE_IP_ADDRESS/$OVERLAY_INTERFACE_IP_ADDRESS5/g" /srv/salt/linuxbridge_agent.ini
#salt "minion_$COMPUTE05" cp.get_file salt://linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini

salt '*' cmd.run 'systemctl restart openstack-nova-compute.service'
salt '*' cmd.run 'systemctl enable neutron-linuxbridge-agent.service'
salt '*' cmd.run 'systemctl restart neutron-linuxbridge-agent.service'
salt '*' cmd.run 'systemctl status neutron-linuxbridge-agent.service'