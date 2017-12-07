# Konjak
The project includes: Openstack control node deployment using Shell and Saltstack for semi-automated deployment of Openstack compute nodes

使用说明：
本项目采用的方法是预配置相关配置文件对原配置文件进行替换进行部署，主要用来一键部署，按照Openstack官方文档进行部署。

其中saltstack自动部署脚本为salt_install.sh
Openstack控制节点自动部署脚本为openstack_ocata_controller.sh
Openstack计算节点自动部署脚本为openstack_ocata_compute.sh
