#!/bin/bash
#定义几个颜色
purple()                           #基佬紫
{
    echo -e "\\033[35;1m${*}\\033[0m"
}
tyblue()                           #天依蓝
{
    echo -e "\\033[36;1m${*}\\033[0m"
}
green()                            #原谅绿
{
    echo -e "\\033[32;1m${*}\\033[0m"
}
yellow()                           #鸭屎黄
{
    echo -e "\\033[33;1m${*}\\033[0m"
}
red()                              #姨妈红
{
    echo -e "\\033[31;1m${*}\\033[0m"
}
blue()                             #蓝色
{
    echo -e "\\033[34;1m${*}\\033[0m"
}
check_sudo()
{
    if [ "$SUDO_GID" ] && [ "$SUDO_COMMAND" ] && [ "$SUDO_USER" ] && [ "$SUDO_UID" ]; then
        if [ "$SUDO_USER" = "root" ] && [ "$SUDO_UID" = "0" ]; then
            #it's root using sudo, no matter it's using sudo or not, just fine
            return 0
        fi
        if [ -n "$SUDO_COMMAND" ]; then
            #it's a normal user doing "sudo su", or `sudo -i` or `sudo -s`, or `sudo su acmeuser1`
            echo "$SUDO_COMMAND" | grep -- "/bin/su\$" >/dev/null 2>&1 || echo "$SUDO_COMMAND" | grep -- "/bin/su " >/dev/null 2>&1 || grep "^$SUDO_COMMAND\$" /etc/shells >/dev/null 2>&1
            return $?
        fi
        #otherwise
        return 1
    fi
    return 0
}
if ! check_sudo; then
    yellow "检测到正在使用sudo！"
    yellow "此脚本不支持sudo，请使用root用户运行此脚本"
    exit 1
fi
ask_if()
{
    local choice=""
    while [ "$choice" != "y" ] && [ "$choice" != "n" ]
    do
        tyblue "$1"
        read choice
    done
    [ $choice == y ] && return 0
    return 1
} 
start_menu()
{
check_sudo
echo
tyblue "------------安装/初始化/mariadb添加数据库---------------"
tyblue " 1. 安装并初始化mariadb"
tyblue " 2. 添加数据库和数据库用户并赋予所有权限"
tyblue " 3. 删除数据库,输入数据库名后无确认，谨慎！"
tyblue " 4. 允许root账户登录mariadb，不安全谨慎操作"
red    " 0. 退出脚本"
echo
echo
local choice=""
while [[ ! "$choice" =~ ^(0|[1-4][0-4]*)$ ]] || ((choice>5))
        do
            read -p "您的选择是：" choice
        done
    if [ $choice -eq 1 ]; then
	root_password=""
	while [ -z "$root_password" ]
            do
                read -p "请输入root密码：" root_password
            done
	! ask_if "数据库root密码是\"$root_password\"确定吗？(y/n)" && return 0
        install_mysql
        initialization_mysql
    elif [ $choice -eq 2 ]; then
	mysql_user=""
        while [ -z "$mysql_user" ]
        do
        read -p "请输入mysql普通用户/数据库名:" mysql_user
        done
        mysql_password=""
        while [ -z "$mysql_password" ]
        do
        read -p "请输入mysql普通用户密码:" mysql_password
        done
	! ask_if "数据库/用户\"$mysql_user\"密码\"$mysql_password\"确定吗？(y/n)" && return 0
	    create_mysql
    elif [ $choice -eq 3 ]; then
	mysql_user=""
        while [ -z "$database_name" ]
        do
        read -p "请输入mysql普通用户/数据库名:" database_name
        done
	! ask_if "删除数据库/用户\"$database_name\"确定吗？(y/n)" && return 0
	    delete_database
	elif [ $choice -eq 4 ]; then
	root_password=""
	while [ -z "$root_password" ]
            do
                read -p "请输入root密码：" root_password
            done
	! ask_if "确定运行root用户登陆mysql吗？(y/n)" && return 0
	    allow_root_access
	fi	
}

install_mysql()
{ 
if ! [ -x "$(command -v mysql)" ]; then
red "安装和配置mariadb..."
dnf module install mariadb -y || apt update && apt install mariadb-server -y
systemctl enable mariadb
systemctl start mariadb
else
yellow "检测到mysql已安装，跳过安装"
fi
} 


initialization_mysql()
{
red "初始化mysql,确保没有密码，任何人都无法访问mysql服务器"
mysql -e "UPDATE mysql.user SET Password = PASSWORD('$root_password') WHERE User = 'root'"
 
# Kill the anonymous users
mysql -e "DROP USER IF EXISTS ''@'localhost'"
# Because our hostname varies we'll use some Bash magic here.
mysql -e "DROP USER IF EXISTS ''@'$(hostname)'"
# Kill off the demo database
mysql -e "DROP DATABASE IF EXISTS test"
} 
 
#red "正在创建\"$mysql_user\"数据库..."
 
#mysql -e "CREATE DATABASE IF NOT EXISTS staging"
 
#tyblue "创建数据库..."
 
#mysql -e "CREATE DATABASE IF NOT EXISTS production"
create_mysql() 
{
mysql -e "CREATE DATABASE IF NOT EXISTS $mysql_user"

green "创建用户$mysql_user并授予暂存数据库的所有权限..."
 
mysql -e "CREATE USER IF NOT EXISTS '$mysql_user'@'localhost' IDENTIFIED BY '$mysql_password'"
 
mysql -e "GRANT ALL PRIVILEGES ON $mysql_user.* to '$mysql_user'@'localhost'"

mysql -e "FLUSH PRIVILEGES"
}
allow_root_access()
{
mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$root_password' WITH GRANT OPTION"
mysql -e "FLUSH PRIVILEGES"
}
delete_database()
{ 
red "删除数据库..."
 
mysql -e "DROP DATABASE IF EXISTS $database_name"
mysql -e "DROP USER IF EXISTS '$database_name'@'localhost'"
mysql -e "FLUSH PRIVILEGES"
}
start_menu
