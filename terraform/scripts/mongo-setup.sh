#!/bin/bash
# =============================================================================
# mongo-setup.sh — Runs as EC2 user_data on first boot
# =============================================================================
# This script:
#   1. Installs MongoDB 4.4 (intentionally outdated — weakness #4)
#   2. Configures authentication
#   3. Creates an admin user
#   4. Sets up daily automated backups to S3
# =============================================================================

set -e  # Exit immediately if any command fails

# Log everything to a file for troubleshooting
exec > /var/log/mongo-setup.log 2>&1
echo "Starting MongoDB setup at $(date)"

# =============================================================================
# STEP 1: Install MongoDB 4.4
# =============================================================================
cat <<'REPO' > /etc/yum.repos.d/mongodb-org-4.4.repo
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
REPO

yum install -y mongodb-org-4.4.29 mongodb-org-server-4.4.29 \
  mongodb-org-shell-4.4.29 mongodb-org-tools-4.4.29

echo "MongoDB 4.4.29 installed"

# =============================================================================
# STEP 2: Configure MongoDB
# =============================================================================
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

# =============================================================================
# STEP 3: Start MongoDB and create admin user
# =============================================================================
systemctl start mongod
systemctl enable mongod

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to start..."
for i in $(seq 1 30); do
  if mongo --eval "db.stats()" > /dev/null 2>&1; then
    echo "MongoDB is ready"
    break
  fi
  sleep 2
done

# Create admin user in the admin database
mongo admin --eval '
  db.createUser({
    user: "${mongo_admin_user}",
    pwd: "${mongo_admin_pass}",
    roles: [
      { role: "root", db: "admin" }
    ]
  })
'
echo "Admin user created"

# Verify authentication works
mongo admin -u "${mongo_admin_user}" -p "${mongo_admin_pass}" --eval '
  db.runCommand({ connectionStatus: 1 })
'
echo "Authentication verified"

# =============================================================================
# STEP 4: Set up automated S3 backups
# =============================================================================
yum install -y aws-cli

cat <<'BACKUP' > /usr/local/bin/mongo-backup.sh
#!/bin/bash
TIMESTAMP=$(date +%%Y%%m%%d_%%H%%M%%S)
BACKUP_DIR="/tmp/mongo-backup-$TIMESTAMP"
ARCHIVE="/tmp/mongo-backup-$TIMESTAMP.tar.gz"

echo "Starting backup at $(date)"

mongodump \
  --username=${mongo_admin_user} \
  --password=${mongo_admin_pass} \
  --authenticationDatabase=admin \
  --out=$BACKUP_DIR

tar -czf $ARCHIVE -C /tmp mongo-backup-$TIMESTAMP

aws s3 cp $ARCHIVE s3://${s3_bucket_name}/backups/mongo-backup-$TIMESTAMP.tar.gz

rm -rf $BACKUP_DIR $ARCHIVE
echo "Backup completed: mongo-backup-$TIMESTAMP.tar.gz"
BACKUP

chmod +x /usr/local/bin/mongo-backup.sh

# Schedule daily backup at 2 AM
echo "0 2 * * * root /usr/local/bin/mongo-backup.sh >> /var/log/mongo-backup.log 2>&1" \
  > /etc/cron.d/mongo-backup

# Run an immediate backup (so there's something to demo in S3)
/usr/local/bin/mongo-backup.sh || echo "Initial backup may fail if no data yet — this is OK"

echo "MongoDB setup complete at $(date)"
