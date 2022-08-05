#!/bin/bash
echo "Thanks for trying Remotely!"
echo

Args=( "$@" )
ArgLength=${#Args[@]}

for (( i=0; i<${ArgLength}; i+=2 ));
do
    if [ "${Args[$i]}" = "--host" ]; then
        HostName="${Args[$i+1]}"
    elif [ "${Args[$i]}" = "--approot" ]; then
        AppRoot="${Args[$i+1]}"
    fi
done

if [ -z "$AppRoot" ]; then
    read -p "Enter path where the Remotely server files should be installed (typically /var/www/remotely): " AppRoot
    if [ -z "$AppRoot" ]; then
        AppRoot="/var/www/remotely"
    fi
fi

if [ -z "$HostName" ]; then
    read -p "Enter server host (e.g. remotely.yourdomainname.com): " HostName
fi

chmod +x "$AppRoot/Remotely_Server"

echo "Using $AppRoot as the Remotely website's content directory."
sudo apt-get -y install curl


sudo apt-get update
sudo apt-get -y install software-properties-common
sudo apt-get -y install gnupg
sudo apt-get -y install wget
sudo apt-get  update
sudo apt-get -y install apt-transport-https

# Install .NET Core Runtime.

curl -SL -o dotnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/b79c5fa9-a08d-4534-9424-4bacfc3cdc3d/449179d6fe8cda05f52b7be0f6828eb0/aspnetcore-runtime-6.0.7-linux-arm64.tar.gz
sudo mkdir -p /usr/share/dotnet
sudo tar -zxf dotnet.tar.gz -C /usr/share/dotnet
sudo ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

 # Install other prerequisites.
sudo apt-get -y install unzip
sudo apt-get -y install acl
sudo apt-get -y install libc6-dev
sudo apt-get -y install libgdiplus


# Set permissions on Remotely files.
sudo setfacl -R -m u:www-data:rwx $AppRoot
sudo chown -R "$USER":www-data $AppRoot
sudo chmod +x "$AppRoot/Remotely_Server"


# Install Nginx
sudo apt-get update
sudo apt-get  -y install nginx

sudo systemctl start nginx


# Configure Nginx
nginxConfig="

server {
    listen        80;
    server_name   $HostName *.$HostName;
    location / {
        proxy_pass         http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    location /_blazor {	
        proxy_pass http://localhost:5000;	
        proxy_http_version 1.1;	
        proxy_set_header Upgrade \$http_upgrade;	
        proxy_set_header Connection \"upgrade\";	
        proxy_set_header Host \$host;	
        proxy_cache_bypass \$http_upgrade;	
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;	
        proxy_set_header   X-Forwarded-Proto \$scheme;	
    }	
    location /AgentHub {	
        proxy_pass http://localhost:5000;	
        proxy_http_version 1.1;	
        proxy_set_header Upgrade \$http_upgrade;	
        proxy_set_header Connection \"upgrade\";	
        proxy_set_header Host \$host;	
        proxy_cache_bypass \$http_upgrade;	
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;	
        proxy_set_header   X-Forwarded-Proto \$scheme;	
    }	
    location /ViewerHub {	
        proxy_pass http://localhost:5000;	
        proxy_http_version 1.1;	
        proxy_set_header Upgrade \$http_upgrade;	
        proxy_set_header Connection \"upgrade\";	
        proxy_set_header Host \$host;	
        proxy_cache_bypass \$http_upgrade;	
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;	
        proxy_set_header   X-Forwarded-Proto \$scheme;	
    }	
    location /CasterHub {	
        proxy_pass http://localhost:5000;	
        proxy_http_version 1.1;	
        proxy_set_header Upgrade \$http_upgrade;	
        proxy_set_header Connection \"upgrade\";	
        proxy_set_header Host \$host;	
        proxy_cache_bypass \$http_upgrade;	
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;	
        proxy_set_header   X-Forwarded-Proto \$scheme;	
    }
}"

echo "$nginxConfig" > /etc/nginx/sites-available/remotely

ln -s /etc/nginx/sites-available/remotely /etc/nginx/sites-enabled/remotely

# Test config.
sudo nginx -t

# Reload.
sudo nginx -s reload




# Create service.

serviceConfig="[Unit]
Description=Remotely Server

[Service]
WorkingDirectory=$AppRoot
ExecStart=/usr/bin/dotnet $AppRoot/Remotely_Server.dll
Restart=always
# Restart service after 10 seconds if the dotnet service crashes:
RestartSec=10
SyslogIdentifier=remotely
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target"

echo "$serviceConfig" > /etc/systemd/system/remotely.service


# Enable service.
sudo systemctl enable remotely.service
# Start service.
sudo systemctl restart remotely.service


# Install Certbot and get SSL cert.
sudo apt-get -y install certbot python3-certbot-nginx

certbot --nginx