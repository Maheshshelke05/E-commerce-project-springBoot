#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y openjdk-17-jdk git maven curl

# create app dir
mkdir -p /opt/ecom
chown -R ubuntu:ubuntu /opt/ecom

# create env with DB details
cat > /etc/ecom_env <<EOF
SPRING_DATASOURCE_URL=jdbc:mysql://${rds_endpoint}:3306/${db_name}
SPRING_DATASOURCE_USERNAME=${db_username}
SPRING_DATASOURCE_PASSWORD=${db_password}
EOF
chmod 600 /etc/ecom_env

# clone & build as ubuntu user
sudo -u ubuntu bash -c '
cd /home/ubuntu
if [ -d ecom-app-src ]; then
  cd ecom-app-src
  git pull || true
else
  git clone ${repo_url} ecom-app-src || exit 1
  cd ecom-app-src
fi

# small visible UI change: change <title> if static index exists
if [ -f src/main/resources/static/index.html ]; then
  sed -i "s/<title>.*<\/title>/<title>Deployed-by-Terraform-Jenkins<\/title>/" src/main/resources/static/index.html || true
fi

# build
mvn -DskipTests clean package || exit 1
'

# copy jar
JAR_FILE=$(find /home/ubuntu/ecom-app-src/target -maxdepth 1 -type f -name "*.jar" | head -n1)
if [ -z "$JAR_FILE" ]; then
  echo "ERROR: built jar not found"
  exit 1
fi
cp "$JAR_FILE" /opt/ecom/app.jar
chown root:root /opt/ecom/app.jar
chmod 500 /opt/ecom/app.jar

# create systemd service
cat > /etc/systemd/system/ecom.service <<'SERVICE'
[Unit]
Description=E-commerce Spring Boot Application
After=network.target

[Service]
User=root
EnvironmentFile=/etc/ecom_env
ExecStart=/usr/bin/java -jar /opt/ecom/app.jar --spring.datasource.url=$SPRING_DATASOURCE_URL --spring.datasource.username=$SPRING_DATASOURCE_USERNAME --spring.datasource.password=$SPRING_DATASOURCE_PASSWORD
SuccessExitStatus=143
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable ecom.service
systemctl start ecom.service

# health check (tries)
for i in {1..15}; do
  if curl -sS http://localhost:8080/actuator/health | grep -qi "UP"; then
    echo "Application healthy"
    exit 0
  fi
  sleep 2
done

echo "Application DID NOT become healthy within timeout" >&2
exit 1
