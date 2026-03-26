#!/bin/bash
# MongoDB Setup Script — Debian 10
# Runs once on EC2 first boot via user data

#Exit script immediately if any command fails
set -e
#Log output (normal and error logs)
exec > /var/log/mongo-setup.log 2>&1
#Put a timestamp on when it started
echo "Starting MongoDB setup at $(date)"

# -------------------------------------------------------
# Step 1: Install MongoDB 4.4
# -------------------------------------------------------
# Because Debian 10 is officially EOL, the org has moved all of the download repos to their archive servers
# so even if you run apt-get update, it will look like there are no servers and finds nothing
echo "deb http://archive.debian.org/debian/ buster main" > /etc/apt/sources.list
echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list
#Disables apt's date validation check, as this will bypass EOL repos
echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

#Update the package list and installs gnupg (used for verifying MongoDB's signing key) and curl downloading files
apt-get update
apt-get install -y gnupg curl

#Add MongoDB key and repo
curl -fsSL https://pgp.mongodb.com/server-4.4.asc | apt-key add -
echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" > /etc/apt/sources.list.d/mongodb-org-4.4.list

#Install pinned versions of MongoDB (latest is 8.0.21)
apt-get update
apt-get install -y mongodb-org=4.4.29 mongodb-org-server=4.4.29 mongodb-org-shell=4.4.29 mongodb-org-tools=4.4.29
echo "MongoDB installed"

# -------------------------------------------------------
# Step 2: Configure MongoDB - write a new config file, stores its data files, listen on all network interfaces, requires authentication
# -------------------------------------------------------
cat <<'CONF' > /etc/mongod.conf
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: 27017
  bindIp: 0.0.0.0
security:
  authorization: enabled
CONF

echo "MongoDB configured"

# -------------------------------------------------------
# Step 3: Start MongoDB and create admin user - starts mongodb, enables auto-start on reboot, creates admin user with root
# -------------------------------------------------------
systemctl start mongod
systemctl enable mongod
sleep 5

mongo admin --eval '
  db.createUser({
    user: "${mongo_admin_user}",
    pwd: "${mongo_admin_pass}",
    roles: [{ role: "root", db: "admin" }]
  })
'
echo "Admin user created"

# -------------------------------------------------------
# Step 4: Install AWS CLI V2 - Because Debian 10 doesn't have the latest AWS CLI, need to use AWS CLI v2 or it won't be able to backup to S3
# -------------------------------------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
sudo ./aws/install

# -------------------------------------------------------
# Step 5: Create the daily backup script - new backup script, timestamp, dumps db to local directory, compresses, uploads to S3, cleans local files
# -------------------------------------------------------
# The VM's IAM instance profile provides the AWS credentials so no keys are needed
cat << 'BACKUP' > /usr/local/bin/mongo-backup.sh
#!/bin/bash
MONGO_DATABASE="go-mongodb"
MONGO_HOST="localhost"
MONGO_PORT="27017"
MONGO_USER="${mongo_admin_user}"
MONGO_PASS="${mongo_admin_pass}"
BACKUP_DIR="/tmp/backup"
TIMESTAMP=$(date +%F-%H%M%S)
S3_BUCKET_NAME="${s3_bucket_name}"

mkdir -p $BACKUP_DIR
mongodump --host $MONGO_HOST --port $MONGO_PORT --username $MONGO_USER --password $MONGO_PASS --authenticationDatabase admin --db $MONGO_DATABASE --out $BACKUP_DIR/$TIMESTAMP
tar -czvf $BACKUP_DIR/$TIMESTAMP.tar.gz -C $BACKUP_DIR $TIMESTAMP
aws s3 cp $BACKUP_DIR/$TIMESTAMP.tar.gz s3://$S3_BUCKET_NAME/backups/$TIMESTAMP.tar.gz
rm -rf $BACKUP_DIR/$TIMESTAMP*
BACKUP

chmod +x /usr/local/bin/mongo-backup.sh

# -------------------------------------------------------
# Step 6: Schedule daily backup at 2 AM
# -------------------------------------------------------
echo "0 2 * * * root /usr/local/bin/mongo-backup.sh >> /var/log/mongo-backup.log 2>&1" > /etc/cron.d/mongo-backup

# -------------------------------------------------------
# Step 7: Run an initial backup now
# -------------------------------------------------------
/usr/local/bin/mongo-backup.sh || echo "Initial backup may fail if no data yet"

echo "MongoDB setup complete at $(date)"