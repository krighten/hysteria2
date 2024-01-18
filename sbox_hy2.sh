#!/bin/bash

# 检测当前用户是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 用户执行此脚本！"
  echo "你可以使用 'sudo -i' 进入 root 用户模式。"
  exit 1
fi

# 生成随机色
random_color() {
  colors=("31" "32" "33" "34" "35" "36" "37")
  echo -e "\e[${colors[$((RANDOM % 7))]}m$1\e[0m"
}

# 更新sing-box
update(){
  # 定义 sing-box 的路径
  SING_BOX_PATH="/usr/bin/sing-box"

  # 获取最新版本号
  VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest \
    | grep tag_name \
    | cut -d ":" -f2 \
    | sed 's/\"//g;s/\,//g;s/\ //g;s/v//')

  # 检查是否成功获取到版本号
  if [ -z "$VERSION" ]; then
      echo "无法获取最新版本号"
      exit 1
  fi

  echo "最新版本号: $VERSION"

  # 如果 sing-box 已经存在
  if [ -f "$SING_BOX_PATH" ]; then
      echo "检测到已存在的 sing-box 文件，准备进行更新..."

      # 获取当前安装的版本号
      CURRENT_VERSION=$("$SING_BOX_PATH" --version | grep -oP '[0-9.]+')
      echo "当前版本号: $CURRENT_VERSION"

      # 比较版本号，如果相同则不需要更新
      if [ "$VERSION" == "$CURRENT_VERSION" ]; then
          echo "已是最新版本，无需更新。"
          exit 0
      fi
  fi

  # 下载新版本
  DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-amd64.tar.gz"
  FILE_NAME="sing-box-${VERSION}-linux-amd64.tar.gz"

  curl -L $DOWNLOAD_URL -o /root/$FILE_NAME
  echo "下载完成: $FILE_NAME"

  # 检查文件是否存在
  if [ ! -f "$FILE_NAME" ]; then
      echo "错误：文件 $FILE_NAME 未找到。"
      exit 1
  fi

  # 解压新版本到 /usr/bin
  tar -zxvf /root/$FILE_NAME --strip-components=1 -C /usr/bin "sing-box-${VERSION}-linux-amd64/sing-box"
  echo "解压完成到 $SING_BOX_PATH"

  # 清理下载的文件
  rm /root/$FILE_NAME
  echo "清理临时文件完成"

  echo "sing-box 更新到最新版本 $VERSION 完成"
}

# 卸载sing-box
remove(){
  systemctl stop sing-box && systemctl disable sing-box && systemctl daemon-reload
  rm -rf /etc/systemd/system/sing-box.service /usr/bin/sing-box /etc/sing-box
  echo -e "$(random_color '卸载已完成。。。')"
  exit 0
}

# 安装sing-box
install(){
  if [ -x "$(command -v apt)" ]; then
    apt -y update && apt -y install wget curl socat grep net-tools
  elif [ -x "$(command -v yum)" ]; then
    yum -y update && yum -y install wget curl socat grep net-tools
  else
    echo "Unsupported package manager."
    exit 1
  fi

  # 使用正则表达式提取版本号
  VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest \
    | grep tag_name \
    | cut -d ":" -f2 \
    | sed 's/\"//g;s/\,//g;s/\ //g;s/v//')

  # 检查是否成功获取到版本号
  if [ -z "$VERSION" ]; then
      echo "无法获取最新版本号"
      exit 1
  fi

  # 构建下载链接
  DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-amd64.tar.gz"

  # 下载文件
  FILE_NAME="sing-box-${VERSION}-linux-amd64.tar.gz"
  curl -L $DOWNLOAD_URL -o /root/$FILE_NAME

  # 检查文件是否存在
  if [ ! -f "/root/$FILE_NAME" ]; then
      echo "错误：文件 $FILE_NAME 未找到。"
      exit 1
  fi

  # 解压文件
  tar -zxvf /root/$FILE_NAME --strip-components=1 -C /usr/bin "sing-box-${VERSION}-linux-amd64/sing-box"
  rm -f /root/$FILE_NAME
  
  # 执行后续操作
  get_port
}

# 获取端口
get_port() {
  while true; do
    echo "$(random_color '请输入端口号（留空默认443，输入0随机2000-60000，你可以输入1-65630指定端口号）: ')"
    read -p "" port

    if [ -z "$port" ]; then
      port=443
      break
    elif [ "$port" -eq 0 ]; then
      port=$((RANDOM % 58001 + 2000))
      break
    elif ! [[ "$port" =~ ^[0-9]+$ ]]; then
      echo "$(random_color '我的动物朋友，请输入数字好吧，请重新输入端口号：')"
      continue
    fi

    # 检查端口是否被占用
    if ! netstat -tuln | grep -q ":$port "; then
      break
    else
      echo "$(random_color '端口已被占用，请重新输入端口号：')"
    fi
  done
  get_ipv4_info
}


# 获取IPV4
get_ipv4_info() {
  ip_address=$(wget -4 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=3 http://ip-api.com/json/) &&
  
  ispck=$(expr "$ip_address" : '.*isp\":[ ]*\"\([^"]*\).*') 

  if echo "$ispck" | grep -qi "cloudflare"; then
    echo "检测到Warp，请输入正确的服务器 IP："
    read new_ip
    ipwan4="$new_ip"
  else
    ipwan4="$(expr "$ip_address" : '.*query\":[ ]*\"\([^"]*\).*')"
  fi
  get_ipv6_info
}

# 获取IPV6
get_ipv6_info() {
  ip_address=$(wget -6 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=3 https://api.ip.sb/geoip)

  # 检查是否成功获取到 IP 地址信息
  if [ -z "$ip_address" ]; then
    echo "无法获取到 IPv6 地址信息"
    ipwan6="" # 如果需要，可以设置为特定的占位符
    get_certificate
    return
  fi

  ispck=$(expr "$ip_address" : '.*isp\":[ ]*\"\([^"]*\).*') 

  if echo "$ispck" | grep -qi "cloudflare"; then
    echo "检测到Warp，请输入正确的服务器 IP："
    read new_ip
    ipwan6="[$new_ip]"
  else
    ipv6_address=$(expr "$ip_address" : '.*ip\":[ ]*\"\([^"]*\).*')
    # 检查是否成功提取到 IPv6 地址
    if [ -z "$ipv6_address" ]; then
      echo "未检测到有效的 IPv6 地址"
      ipwan6="" # 如果需要，可以设置为特定的占位符
    else
      ipwan6="[$ipv6_address]"
    fi
  fi
  get_certificate
}

# 生成证书
generate_certificate() {
    read -p "请输入要用于自签名证书的域名（默认为 bing.com）: " user_domain
    domain_name=${user_domain:-"bing.com"}
    if curl --output /dev/null --silent --head --fail "$domain_name"; then
        openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "/etc/ssl/private/$domain_name.key" -out "/etc/ssl/private/$domain_name.crt" -subj "/CN=$domain_name" -days 36500
        chmod 600 "/etc/ssl/private/$domain_name.key" "/etc/ssl/private/$domain_name.crt"
        echo -e "自签名证书和私钥已生成！"
    else
        echo -e "无效的域名或域名不可用，请输入有效的域名！"
        generate_certificate
    fi
}
get_certificate(){
  generate_certificate

  certificate_path="/etc/ssl/private/$domain_name.crt"
  private_key_path="/etc/ssl/private/$domain_name.key"

  echo -e "证书文件已保存到 /etc/ssl/private/$domain_name.crt"
  echo -e "私钥文件已保存到 /etc/ssl/private/$domain_name.key"

  ovokk="insecure=1&"
  choice1="true"
  get_password
}

# 添加密码
get_password(){
  echo "$(random_color '请输入你的密码（留空将生成随机密码，不超过20个字符）: ')"
  read -p "" password

  if [ -z "$password" ]; then
    password=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9')
  fi
  get_masquerade
}

# 添加Quic混淆地址
get_masquerade(){
  echo "$(random_color '请输入伪装网址（默认https://maimai.sega.jp/）: ')"
  read -p "" masquerade_url

  if [ -z "$masquerade_url" ]; then
    masquerade_url="https://maimai.sega.jp/"
  fi
  config_write
}

# 写入配置文件
config_write(){
  # 定义配置目录和文件路径
  CONFIG_DIR="/etc/sing-box"
  CONFIG_FILE="${CONFIG_DIR}/config.json"

  # 检查配置目录是否存在，如果不存在则创建
  if [ ! -d "$CONFIG_DIR" ]; then
      echo "配置目录 $CONFIG_DIR 不存在，正在创建..."
      mkdir -p "$CONFIG_DIR"
  else
    rm -f /etc/sing-box/config.json
  fi

# 创建服务器配置文件
cat > "$CONFIG_FILE" << EOF
{
    "inbounds": [
        {
            "type": "hysteria2",
            "listen": "::",
            "listen_port": $port,
            "users": [
                {
                    "password": "$password"
                }
            ],
            "masquerade": "$masquerade_url",
            "tls": {
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "/etc/ssl/private/$domain_name.crt",
                "key_path": "/etc/ssl/private/$domain_name.key"
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct"
        }
    ]
}
EOF

  # 定义链接文件路径
  LINK_FILE="/etc/sing-box/link.txt"

  # 检查是否存在 IPv6 地址
  if [ -z "$ipwan6" ]; then
    # 只写入 IPv4 链接
    cat > "$LINK_FILE" << EOF
hysteria2://$password@$ipwan4$domain:$port/?${ovokk}sni=$domain$domain_name#Hysteria2-v4
EOF
  else
    # 写入 IPv4 和 IPv6 链接
    cat > "$LINK_FILE" << EOF
hysteria2://$password@$ipwan4$domain:$port/?${ovokk}sni=$domain$domain_name#Hysteria2-v4
hysteria2://$password@$ipwan6$domain:$port/?${ovokk}sni=$domain$domain_name#Hysteria2-v6
EOF
  fi
  
  # 执行下一步骤
  write_systemd
}

# 设定开机启动
write_systemd(){
cat > "/etc/systemd/system/sing-box.service" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box -C /etc/sing-box run
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload && systemctl enable sing-box && systemctl start sing-box

  # 显示配置
  cat_config
}

# 显示客户端配置
cat_config(){
  echo -e "以下是Hysteria2标准订阅链接"
  cat /etc/sing-box/link.txt
}

# 主界面
welcome(){
  echo "$(random_color '选择一个操作')"
  echo "1. 安装"
  echo "2. 卸载"
  echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
  echo "3. 查看配置"
  echo "4. 退出脚本"
  echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
  echo "5. 更新内核"
}
clear && welcome
read -p "输入操作编号 (1/2/3/4/5): " choice
case $choice in 
  1)
  install
  ;;
  2)
  remove
  ;;
  3)
  cat_config
  ;;
  4)
  exit 1
  ;;
  5)
  update
esac
