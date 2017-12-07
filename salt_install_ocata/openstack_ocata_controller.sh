#!/bin/bash
#请赋予本脚本755的权限
#请关闭防火墙和selinux，如有需要请在安装完成后手动启动防火墙并开放指定端口
#开始安装请确认脚本变量修改正确，禁用epel源（enable=0）


CONTROLLER_MANAGEMENT_INTERFACE_IP_ADDRESS=10.22.4.51 #CONTROLLER的管理IP
PROVIDER_INTERFACE_NAME=enp0s10 #CONTROLLER的PROVIDER网络网卡名
OVERLAY_INTERFACE_IP_ADDRESS=10.22.4.51 #CONTROLLER的OVERLAY网络IP
METADATA_SECRET=aabbcc #元数据密令（neutron组件）
DB_USER=root #数据库拥有创建用户和授权权限的用户
DB_PASS=123456 #$DB_USER的密码
RABBIT_PASS=123456 #RABBIT_PASS为RabbitMQ密码
KEYSTONE_DBPASS=123456 #认证服务用户数据库密码
GLANCE_DBPASS=123456 #镜像服务用户数据库密码
GLANCE_PASS=123456 #镜像服务用户密码
NOVA_API_DBPASS=123456 #nova-api用户数据库密码
NOVA_DBPASS=123456 #nova用户数据库密码
NOVA_PASS=123456 #nova用户密码
PLACEMENT_PASS=123456 #placement用户密码
NOVA_CELL0_DBPASS=123456 #nova_cell0用户数据库密码
NEUTRON_DBPASS=123456 #neutron服务数据库密码
NEUTRON_PASS=123456 #neutron用户密码
ADMIN_PASS=123456 #ADMIN用户密码
DEMO_PASS=123456 #DEMO用户密码

echo "========================================================================================================================="
echo "执行安装前请检查脚本内用户账户和密码设置以及权限，为保证安装顺利进行，请赋予本脚本755权限,按下空格将在5秒倒计时后开始安装"
echo "========================================================================================================================="

a()
{
  for i in `seq -w 50 -1 0`
  do

  echo -ne "\b\b$i"
  sleep 0.1
  done
  echo ""

}

read -n 1 -p "[ Press Space ] " space
[[ "$space" = "" ]] && a

openstack_env(){
echo "开始安装openstack底层环境"
echo "安装网络时间服务"
yum install -y chrony >> /dev/null 2>&1
cp $HOME/salt_install_ocata/chrony_controller.conf /etc/chrony.conf
systemctl enable chronyd.service >> /dev/null 2>&1
systemctl start chronyd.service >> /dev/null 2>&1
systemctl status chronyd.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "网络时间服务安装完成";
	else
		echo "网络时间服务安装出错，请检查后重新尝试"
		exit 1;
fi
echo "开始安装openstack库和客户端"
yum install -y centos-release-openstack-ocata >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "openstack库安装完成，执行更新server软件（该步骤可能耗时较长）";
	else
		echo "openstack库安装出错，请检查后重新尝试"
		exit 1;
fi
yum upgrade -y >> /dev/null 2>&1
yum install -y python-openstackclient >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "openstack客户端安装完成";
	else
		echo "openstack客户端安装出错，请检查后重新尝试"
		exit 1;
fi
echo "开始安装数据库（MariaDB，MariaDB体积较大，安装时间可能较长）"
yum install -y mariadb mariadb-server python2-PyMySQL >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "MariaDB安装完成，尝试配置并启动";
	else
		echo "MariaDB安装出错，请检查后重新尝试"
		exit 1;
fi
sed  "s/CONTROLLER_MANAGEMENT_INTERFACE_IP_ADDRESS/$CONTROLLER_MANAGEMENT_INTERFACE_IP_ADDRESS/g" $HOME/salt_install_ocata/openstack.cnf > /etc/my.cnf.d/openstack.cnf
systemctl enable mariadb.service >> /dev/null 2>&1
systemctl start mariadb.service >> /dev/null 2>&1
systemctl status mariadb.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "MariaDB已启动，请根据提示配置向导"
		read -p "请选择您是否需要配置向导(Y.是，other.否)：" input
		case $input in
			Y)
				echo "请根据提示进行配置（注意设置的密码与shell中保持一致）"
				mysql_secure_installation;
				;;
			*)
				echo "你已选择不需要，跳过配置向导"
				;;
		esac
	else
		echo "MariaDB启动出错，请检查配置"
		exit 1;
fi
echo "开始安装消息队列RabbitMQ"
yum install -y rabbitmq-server >> /dev/null 2>&1 
systemctl enable rabbitmq-server.service >> /dev/null 2>&1
systemctl start rabbitmq-server.service >> /dev/null 2>&1 
systemctl status rabbitmq-server.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "RabbitMQ安装启动完成，配置中";
	else
		echo "RabbitMQ安装出错，请检查后重新尝试"
		exit 1;
fi
rabbitmqctl add_user openstack $RABBIT_PASS >> /dev/null 2>&1
rabbitmqctl set_permissions openstack ".*" ".*" ".*" >> /dev/null 2>&1
echo "配置完成，开始部署Memcached"
yum install -y memcached python-memcached >/dev/null >> /dev/null 2>&1
cp $HOME/salt_install_ocata/memcached /etc/sysconfig/memcached
systemctl enable memcached.service >> /dev/null 2>&1
systemctl start memcached.service >> /dev/null 2>&1
systemctl status memcached.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "Memcache安装启动完成，结束openstack环境安装";
	else
		echo "Memcache启动出错，请检查后重新尝试"
		exit 1;
fi
}


#这里为安装openstack组件创建数据库身份并授予相应权限
openstack_sql(){
read -p "请选择您是否需要创建数据库身份并授权(Y.是；如已创建，请输入任意非Y选项,请注意大小写)：" database_pass
case $database_pass in
Y)
	echo "开始配置openstack需要的数据库身份并授权"
	echo "验证$DB_USER是否可以正常登陆数据库"
	mysql -u$DB_USER -p$DB_PASS -e "show databases;"  >> /dev/null 2>&1
	if [ $? -eq 0 ];
		then
			echo "验证完成，$DB_USER可以正常登陆数据库";
		else
			echo "登陆数据库存在问题，请检查后重新尝试。安装中止"
			exit 1;
	fi
	mysql -u$DB_USER -p$DB_PASS -e "CREATE DATABASE keystone;" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'controller' IDENTIFIED BY '$KEYSTONE_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';" >> /dev/null 2>&1
	
	mysql -u$DB_USER -p$DB_PASS -e "CREATE DATABASE glance;" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'controller' IDENTIFIED BY '$GLANCE_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';" >> /dev/null 2>&1
	
	mysql -u$DB_USER -p$DB_PASS -e "CREATE DATABASE nova_api;" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_API_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'controller' IDENTIFIED BY '$NOVA_API_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_API_DBPASS';" >> /dev/null 2>&1
	
	mysql -u$DB_USER -p$DB_PASS -e "CREATE DATABASE nova;" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'controller' IDENTIFIED BY '$NOVA_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';" >> /dev/null 2>&1
	
	mysql -u$DB_USER -p$DB_PASS -e "CREATE DATABASE nova_cell0;" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_CELL0_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'controller' IDENTIFIED BY '$NOVA_CELL0_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_CELL0_DBPASS';" >> /dev/null 2>&1
	
	mysql -u$DB_USER -p$DB_PASS -e "CREATE DATABASE neutron;"
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'controller' IDENTIFIED BY '$NEUTRON_DBPASS';" >> /dev/null 2>&1
	mysql -u$DB_USER -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';" >> /dev/null 2>&1
	
	;;
*)
	echo "你已选择不需要，跳过配置数据库身份和授权步骤"
	;;
esac
echo "完成数据库用户身份创建和授权"
}


#这里开始安装keystone
openstack_keystone(){
echo "开始安装认证组件keystone"
yum install -y openstack-keystone httpd mod_wsgi >> /dev/null 2>&1
sed  "s/KEYSTONE_DBPASS/$KEYSTONE_DBPASS/g" $HOME/salt_install_ocata/keystone.conf > /etc/keystone/keystone.conf
echo "安装配置keystone完成，导入数据中"
su -s /bin/sh -c "keystone-manage db_sync" keystone >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "数据导入完成，初始化Fernet key";
	else
		echo "导入数据错误，请检查用户密码是否正确"
		exit 1;
fi
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "fernet_setup初始化完成，初始化credential_setup"
		keystone-manage credential_setup --keystone-user keystone --keystone-group keystone >> /dev/null 2>&1
		if [ $? -eq 0 ];
			then
				echo "credential_setup初始化完成，开始keystone引导";
			else
				echo "credential_setup初始化出错，请检查"
				exit 1;
		fi;
	else
		echo "fernet_setup初始化出错，请检查"
		exit 1;
fi
keystone-manage bootstrap --bootstrap-password $ADMIN_PASS --bootstrap-admin-url http://controller:35357/v3/ --bootstrap-internal-url http://controller:5000/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "keystone引导完成，配置 Apache HTTP 服务器";
	else
		echo "keystone引导错误，请检查ADMIN_PASS是否配置正确"
		exit 1;
fi
cp $HOME/salt_install_ocata/httpd.conf /etc/httpd/conf/httpd.conf
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
systemctl enable httpd.service >> /dev/null 2>&1
systemctl start httpd.service >> /dev/null 2>&1
systemctl status httpd.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "Apache HTTP 服务器配置完成";
	else
		echo "Apache HTTP 服务器启动出错，请检查原因并确认关闭防火墙和selinux"
		exit 1;
fi
#调用脚本使用admin身份进行部署
sed "s/ADMIN_PASS/$ADMIN_PASS/g" $HOME/salt_install_ocata/admin-openrc > $HOME/admin-openrc
sed "s/DEMO_PASS/$DEMO_PASS/g" $HOME/salt_install_ocata/demo-openrc > $HOME/demo-openrc
#创建域、项目、用户和角色
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
echo "创建域、项目、用户和角色"
openstack project create --domain default --description "Service Project" service >> /dev/null 2>&1
openstack project create --domain default --description "Demo Project" demo >> /dev/null 2>&1
echo "现在创建demo用户，您需要为demo用户输入密码，请与DEMO_PASS(您的设置为$DEMO_PASS)保持一致"
openstack user create --domain default  --password-prompt demo
openstack role create user >> /dev/null 2>&1
openstack role add --project demo --user demo user >> /dev/null 2>&1
echo "开始执行验证操作，请输入密码以确认是否成功获得认证令牌"
cp $HOME/salt_install_ocata/keystone-paste.ini /etc/keystone/keystone-paste.ini
unset OS_AUTH_URL OS_PASSWORD
openstack --os-auth-url http://controller:35357/v3 --os-project-domain-name default --os-user-domain-name default  --os-project-name admin --os-username admin token issue
if [ $? -eq 0 ];
	then
		echo "admin用户成功获取认证令牌，获取demo认证令牌"
		openstack --os-auth-url http://controller:5000/v3 --os-project-domain-name default --os-user-domain-name default --os-project-name demo --os-username demo token issue
		if [ $? -eq 0 ];
			then
				echo "demo用户成功获取令牌，keystone安装结束，开始安装glance";
			else
				echo "demo用户获取令牌出错，请检查密码是否正确或存在其他问题"
				exit 1;
		fi;
	else
		echo "admin用户获取令牌出错，请检查密码是否正确或存在其他问题"
		exit 1;
fi
}


#这里开始安装glance
openstack_glance(){
source $HOME/admin-openrc
echo "现在创建glance用户，您需要为glance用户输入密码，请与GLANCE_PASS(您的设置为 $GLANCE_PASS )保持一致"
openstack user create --domain default --password-prompt glance
echo "创建glance项目、角色、API端点和服务实体"
openstack role add --project service --user glance admin >> /dev/null 2>&1
openstack service create --name glance --description "OpenStack Image" image >> /dev/null 2>&1
openstack endpoint create --region RegionOne image public http://controller:9292 >> /dev/null 2>&1
openstack endpoint create --region RegionOne image internal http://controller:9292 >> /dev/null 2>&1
openstack endpoint create --region RegionOne image admin http://controller:9292 >> /dev/null 2>&1
echo "安装配置glance"
yum install -y openstack-glance >> /dev/null 2>&1
sed  "s/GLANCE_DBPASS/$GLANCE_DBPASS/g" $HOME/salt_install_ocata/glance-api.conf > /etc/glance/glance-api.conf
sed -i "s/GLANCE_PASS/$GLANCE_PASS/g" /etc/glance/glance-api.conf
sed  "s/GLANCE_DBPASS/$GLANCE_DBPASS/g" $HOME/salt_install_ocata/glance-registry.conf > /etc/glance/glance-registry.conf
sed -i "s/GLANCE_PASS/$GLANCE_PASS/g" /etc/glance/glance-registry.conf
echo "glance安装完成，开始导入数据"
su -s /bin/sh -c "glance-manage db_sync" glance >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "数据导入完成，开始启动glance-api服务";
	else
		echo "数据导入出错，请执行su -s /bin/sh -c "glance-manage db_sync" glance检查后重新尝试"
		exit 1;
fi
systemctl enable openstack-glance-api.service openstack-glance-registry.service >> /dev/null 2>&1
systemctl start openstack-glance-api.service openstack-glance-registry.service >> /dev/null 2>&1
systemctl status openstack-glance-api.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "glance-api服务启动成功，开始启动glance-registry"
		systemctl status openstack-glance-registry.service
		if [ $? -eq 0 ];
			then
				echo "glance-registry服务启动成功，开始创建镜像";
			else
				echo "glance-registry服务启动出错，请执行journalctl -r -u openstack-glance-registry.service检查"
				exit 1;
		fi;
	else
		echo "glance-api服务启动出错，请执行journalctl -r -u openstack-glance-api.service检查"
		exit 1;
fi
cd $HOME
cp $HOME/salt_install_ocata/cirros-0.3.5-x86_64-disk.img $HOME
openstack image create "cirros" --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public
if [ $? -eq 0 ];
	then
		echo "镜像创建完成";
	else
		echo "创建镜像出错，请尝试手动创建以排除错误"
		exit 1;
fi
openstack image list >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "glance服务安装完毕，开始安装nova服务";
	else
		echo "无法查看镜像列表，请排除错误后重新尝试"
		exit 1;
fi
}


#这里开始安装nova服务
openstack_nova(){
source $HOME/admin-openrc
echo "现在创建nova服务，您需要为nova服务输入密码，请与NOVA_PASS(您的设置为$NOVA_PASS)保持一致"
openstack user create --domain default --password-prompt nova
echo "创建glance项目、角色、API端点和服务实体"
openstack role add --project service --user nova admin >> /dev/null 2>&1
openstack service create --name nova --description "OpenStack Compute" compute >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1 >> /dev/null 2>&1
		openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1 >> /dev/null 2>&1
		openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1 >> /dev/null 2>&1
		if [ $? -eq 0 ];
			then
				echo "现在创建placement服务，您需要为placement服务输入密码，请与PLACEMENT_PASS(您的设置为$PLACEMENT_PASS)保持一致"
				openstack service create --name placement --description "Placement API" placement
				if [ $? -eq 0 ];
					then
						echo "placement服务创建完成，开始创建用户身份"
						openstack user create --domain default --password-prompt placement >> /dev/null 2>&1
						if [ $? -eq 0 ];
							then
								echo "用户身份创建完成，开始添加角色"
								openstack role add --project service --user placement admin; >> /dev/null 2>&1
							else
								echo "创建时发生错误，请检查后重试"
								#exit 1;
						fi;
					else
						echo "创建时发生错误，请检查后重试"
						#exit 1;
				fi;
				openstack endpoint create --region RegionOne placement public http://$CONTROLLER_MANAGEMENT_INTERFACE_IP_ADDRESS:8778 >> /dev/null 2>&1
				openstack endpoint create --region RegionOne placement internal http://$CONTROLLER_MANAGEMENT_INTERFACE_IP_ADDRESS:8778 >> /dev/null 2>&1
				openstack endpoint create --region RegionOne placement admin http://$CONTROLLER_MANAGEMENT_INTERFACE_IP_ADDRESS:8778 >> /dev/null 2>&1;
			else
				echo "创建时发生错误，请检查后重试"
				#exit 1;
		fi;
	else
		echo "创建时发生错误，请检查后重试"
		#exit 1;
fi
yum install -y openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "安装完成，开始进行配置";
	else
		echo "安装出现错误，请检查后重试"
		exit 1;
fi
sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/nova_controller.conf > /etc/nova/nova.conf
sed -i "s/NOVA_DBPASS/$NOVA_DBPASS/g" /etc/nova/nova.conf
sed -i "s/CONTROLLER_MANAGEMENT_INTERFACE_IP_ADDRESS/$CONTROLLER_MANAGEMENT_INTERFACE_IP_ADDRESS/g" /etc/nova/nova.conf
sed -i "s/NOVA_PASS/$NOVA_PASS/g" /etc/nova/nova.conf
sed -i "s/PLACEMENT_PASS/$PLACEMENT_PASS/g" /etc/nova/nova.conf
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /etc/nova/nova.conf
sed -i "s/METADATA_SECRET/$METADATA_SECRET/g" /etc/nova/nova.conf
cat $HOME/salt_install_ocata/nova-placement-api.conf >> /etc/httpd/conf.d/00-nova-placement-api.conf
systemctl restart httpd >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo 'httpd重启成功，Populate the nova-api database'
		su -s /bin/sh -c "nova-manage api_db sync" nova >> /dev/null 2>&1
		if [ $? -eq 0 ];
			then
				echo "Populate the nova-api database完成，开始Register cell0 database数据"
				su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova >> /dev/null 2>&1
				if [ $? -eq 0 ];
					then
						echo 'Register cell0 database数据完成，开始创建cell1'
						su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova >> /dev/null 2>&1
						if [ $? -eq 0 ];
							then
								echo '创建cell1完成，开始Populate the nova database'
								su -s /bin/sh -c "nova-manage db sync" nova; >> /dev/null 2>&1
								if [ $? -eq 0 ];
									then
										echo 'Populate the nova database完成，开始进行验证'
										nova-manage cell_v2 list_cells; >> /dev/null 2>&1
									else
										echo 'Populate the nova database错误，执行nova-manage cell_v2 list_cells检查问题原因'
										exit 1;
								fi;
							else
								echo '执行su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova检查原因'
								exit 1;
						fi;
					else
						echo 'Register cell0 database出错，请执行su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova检查问题原因'
						exit 1;
				fi;
			else
				echo 'Populate the nova-api database失败，请检查后重试'
				exit 1;
		fi;
	else
		echo '尝试对httpd服务进行重新启动失败，请检查原因后重新尝试'
		exit 1;
fi
if [ $? -eq 0 ];
	then
		echo "验证完成，开始启动服务"
		systemctl enable openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service >> /dev/null 2>&1
		systemctl start openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service >> /dev/null 2>&1;
	else
		echo "验证发现错误，请检查后重试"
		exit 1;
fi
systemctl status openstack-nova-api.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "openstack-nova-api.service启动成功";
	else
		echo "openstack-nova-api.service启动失败，由于脚本缺陷，这里可以暂时跳过";
fi
systemctl status openstack-nova-consoleauth.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "openstack-nova-consoleauth.service启动成功";
	else
		echo "openstack-nova-consoleauth.service启动失败，请检查"
		exit 1;
fi
systemctl status openstack-nova-scheduler.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "openstack-nova-scheduler.service启动成功";
	else
		echo "openstack-nova-scheduler.service启动失败，请检查"
		exit 1;
fi
systemctl status openstack-nova-conductor.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "openstack-nova-conductor.service启动成功";
	else
		echo "openstack-nova-conductor.service启动失败，请检查"
		exit 1;
fi
systemctl status openstack-nova-novncproxy.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "openstack-nova-novncproxy.service启动成功，开始安装neutron服务";
	else
		echo "openstack-nova-novncproxy.service启动失败，请检查"
		exit 1;
fi
}


#这里开始安装neutron服务
openstack_neutron(){
source $HOME/admin-openrc
echo "现在创建neutron服务，您需要为neutron服务输入密码，请与NEUTRON_PASS(您的设置为$NEUTRON_PASS)保持一致"
openstack user create --domain default --password-prompt neutron
echo "创建neutron项目、角色、API端点和服务实体"
openstack role add --project service --user neutron admin >> /dev/null 2>&1
openstack service create --name neutron --description "OpenStack Networking" network >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		openstack endpoint create --region RegionOne network public http://controller:9696 >> /dev/null 2>&1
		openstack endpoint create --region RegionOne network internal http://controller:9696 >> /dev/null 2>&1
		openstack endpoint create --region RegionOne network admin http://controller:9696 >> /dev/null 2>&1;
	else
		echo "创建时发生错误，请检查后重试"
		exit 1;
fi
echo "开始安装neutron服务软件"
yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge ebtables >> /dev/null 2>&1
echo "安装完毕，开始配置"
sed  "s/RABBIT_PASS/$RABBIT_PASS/g" $HOME/salt_install_ocata/neutron_controller.conf > /etc/neutron/neutron.conf
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" /etc/neutron/neutron.conf
sed -i "s/NEUTRON_DBPASS/$NEUTRON_DBPASS/g" /etc/neutron/neutron.conf
sed -i "s/NOVA_PASS/$NOVA_PASS/g" /etc/neutron/neutron.conf
cp $HOME/salt_install_ocata/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
sed  "s/PROVIDER_INTERFACE_NAME/$PROVIDER_INTERFACE_NAME/g" $HOME/salt_install_ocata/linuxbridge_agent.ini > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "s/OVERLAY_INTERFACE_IP_ADDRESS/$OVERLAY_INTERFACE_IP_ADDRESS/g" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
cp $HOME/salt_install_ocata/l3_agent.ini /etc/neutron/l3_agent.ini
cp $HOME/salt_install_ocata/dhcp_agent_controller.ini /etc/neutron/dhcp_agent.ini
sed  "s/METADATA_SECRET/$METADATA_SECRET/g" $HOME/salt_install_ocata/metadata_agent.ini > /etc/neutron/metadata_agent.ini
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
echo "同步数据库中"
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		"数据同步完成，重启nova-api服务"
		systemctl restart openstack-nova-api.service >> /dev/null 2>&1;
	else
		echo "数据同步时发生问题，请检查后重新尝试"
		exit 1;
fi
if [ $? -eq 0 ];
	then
		echo "启动neutron服务"
		systemctl enable neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-l3-agent.service >> /dev/null 2>&1
		systemctl start neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-l3-agent.service >> /dev/null 2>&1;
	else
		echo "nova-api重启失败，检查后重新尝试"
		exit 1;
fi
systemctl status neutron-server.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "neutron-server.service启动成功";
	else
		echo "neutron-server.service启动失败，请检查"
		exit 1;
fi
systemctl status neutron-linuxbridge-agent.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "neutron-linuxbridge-agent.service启动成功";
	else
		echo "neutron-linuxbridge-agent.service启动失败，请检查"
		exit 1;
fi
systemctl status neutron-dhcp-agent.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "neutron-dhcp-agent.service启动成功";
	else
		echo "neutron-dhcp-agent.service启动失败，请检查"
		exit 1;
fi
systemctl status neutron-metadata-agent.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "neutron-metadata-agent.service启动成功";
	else
		echo "neutron-metadata-agent.service启动失败，请检查"
		exit 1;
fi
systemctl status neutron-l3-agent.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "neutron-l3-agent.service启动成功";
	else
		echo "neutron-l3-agent.service启动失败，请检查"
		exit 1;
fi
echo "以下为目前的节点状态"
openstack network agent list
}


#开始配置dashboard
openstack_horizon(){
sleep 5
echo "开始安装dashboard"
yum install -y openstack-dashboard >> /dev/null 2>&1
cp $HOME/salt_install_ocata/local_settings /etc/openstack-dashboard/local_settings
echo "重新启动httpd和memcached已使安装生效"
systemctl restart httpd.service memcached.service >> /dev/null 2>&1
systemctl status httpd.service >> /dev/null 2>&1
if [ $? -eq 0 ];
	then
		echo "httpd.service启动成功";
	else
		echo "httpd.service启动失败，请检查"
		exit 1;
fi
systemctl status memcached.service
if [ $? -eq 0 ];
	then
		echo "memcached.service启动成功";
	else
		echo "memcached.service启动失败，请检查"
		exit 1;
fi
echo "dashboard安装完成，浏览器访问http:$OVERLAY_INTERFACE_IP_ADDRESS/dashboard"
}

echo "请输入数字以选择安装模块"
echo "1.安装Openstack底层环境"
ehco "2.创建相应数据库用户以及授权"
ehco "3.安装认证组件Keystone"
ehco "4.安装镜像组件Glance"
ehco "5.安装计算组件Nova"
ehco "6.安装网络组件Neutron"
echo "7.配置控制台Horizon"
echo "输入q或者Q结束安装"
read -p "请输入数字选项" choise
case "$choise" in
1)
    openstack_env
    ;;
2)
    openstack_sql
    ;;
3)
    openstack_keystone
	;;
4)
    openstack_glance
	;;
5)
    openstack_nova
	;;
6)
    openstack_neutron
	;;
7)
    openstack_horizon
	;;
q|Q)
    exit
	echo "结束安装，ByeBye~"
    ;;
*)
echo "输入有误，请重新输入"
esac

