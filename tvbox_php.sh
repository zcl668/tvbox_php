#!/bin/bash
# =========================================
# Termux Nginx+PHP 一键部署面板（彩色状态自检）
# 网站目录固定: /storage/emulated/0/zcl/php
# 不带开机自启
# =========================================

# ===== 配置参数 =====
WEB_DIR="/storage/emulated/0/zcl/php"
NGINX_CONF="$HOME/etc/nginx/nginx.conf"
PORT=8081
# ===================

# ===== 安装依赖 =====
echo -e "\033[1;34m[INFO] 更新环境并安装依赖...\033[0m"
pkg update -y
pkg upgrade -y
pkg install -y php php-fpm nginx curl wget unzip git dialog

# ===== 创建网站目录 =====
mkdir -p "$WEB_DIR"
cd "$WEB_DIR"

# ===== 下载简单彩色面板源码 =====
if [ ! -f "$WEB_DIR/index.php" ]; then
echo -e "\033[1;32m[INFO] 创建管理面板...\033[0m"
cat > index.php <<'EOF'
<?php
function color($text,$color="green"){
    $colors=["green"=>"#2ecc71","red"=>"#e74c3c","yellow"=>"#f1c40f","blue"=>"#3498db"];
    return "<span style='color:".$colors[$color]."'>".$text."</span>";
}

function service_status($name){
    $output = shell_exec("pgrep $name");
    return $output ? color("运行中","green") : color("已停止","red");
}

?>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Termux Nginx PHP 面板</title>
<style>
body{font-family: monospace; background:#222; color:#eee; padding:20px;}
a{color:#3498db; text-decoration:none;}
pre{background:#111; padding:10px;}
button{padding:8px 12px; margin:5px; cursor:pointer;}
</style>
</head>
<body>
<h2>Termux Nginx+PHP 面板</h2>

<p>Nginx 状态: <?php echo service_status("nginx"); ?></p >
<p>PHP-FPM 状态: <?php echo service_status("php-fpm"); ?></p >

<form method="post">
<button name="action" value="start_nginx">启动 Nginx</button>
<button name="action" value="stop_nginx">停止 Nginx</button>
<button name="action" value="start_php">启动 PHP-FPM</button>
<button name="action" value="stop_php">停止 PHP-FPM</button>
</form>

<pre>
<?php
if(isset($_POST['action'])){
    $cmd="";
    switch($_POST['action']){
        case "start_nginx": $cmd="nginx -c $GLOBALS[NGINX_CONF]"; break;
        case "stop_nginx": $cmd="nginx -s stop"; break;
        case "start_php": $cmd="php-fpm -D"; break;
        case "stop_php": $cmd="pkill php-fpm"; break;
    }
    echo "执行命令: $cmd\n";
    echo shell_exec($cmd);
}
?>
</pre>

<h3>存储权限</h3>
<pre>
<?php
echo "Web 目录: <?php echo $WEB_DIR; ?>\n";
echo "可写权限: ".(is_writable('$WEB_DIR')?"是":"否")."\n";
?>
</pre>

</body>
</html>
EOF
fi

# ===== 配置 Nginx =====
echo -e "\033[1;34m[INFO] 配置 Nginx...\033[0m"
mkdir -p $HOME/etc/nginx
cat > $NGINX_CONF <<EOF
worker_processes 1;
events { worker_connections 1024; }
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen $PORT;
        server_name localhost;
        root $WEB_DIR;

        index index.php index.html index.htm;

        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        location ~ \.php\$ {
            include fastcgi_params;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
    }
}
EOF

# ===== 启动服务 =====
echo -e "\033[1;32m[INFO] 启动服务...\033[0m"
php-fpm -D
nginx -c $NGINX_CONF

echo -e "\033[1;33m[INFO] 安装完成！\033[0m"
echo -e "访问地址: \033[1;36mhttp://localhost:$PORT\033[0m"
echo -e "网站目录: $WEB_DIR"
