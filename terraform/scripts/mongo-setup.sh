#!/bin/bash
# MongoDB Setup Script
# Runs once on EC2 first boot via user data
# Sets up MongoDB, authentication, and daily backups

set -e
exec > /var/log/mongo-setup.log 2>&1
echo "Starting MongoDB setup at $(date)"

# -------------------------------------------------------
# Step 1: Install MongoDB 4.4
# -------------------------------------------------------
cat <<'REPO' > /etc/yum.repos.d/mongodb-org-4.4.repo
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
REPO

yum install -y mongodb-org-4.4.29 mongodb-org-server-4.4.29 mongodb-org-shell-4.4.29 mongodb-org-tools-4.4.29
echo "MongoDB installed"

# -------------------------------------------------------
# Step 2: Configure MongoDB
# -------------------------------------------------------
cat <<'CONF' > /etc/mongod.conf
storage:
  dbPath: /var/lib/mongo
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
# Step 3: Start MongoDB and create admin user
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
# Step 4: Create the daily backup script
# -------------------------------------------------------
yum install -y aws-cli

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
# Step 5: Schedule daily backup at 2 AM
# -------------------------------------------------------
echo "0 2 * * * root /usr/local/bin/mongo-backup.sh >> /var/log/mongo-backup.log 2>&1" > /etc/cron.d/mongo-backup

# -------------------------------------------------------
# Step 6: Run an initial backup now
# -------------------------------------------------------
/usr/local/bin/mongo-backup.sh || echo "Initial backup may fail if no data yet"

echo "MongoDB setup complete at $(date)"