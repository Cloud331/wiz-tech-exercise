#!/bin/bash
# MongoDB backup script

# Set variables
MONGO_DATABASE="go-mongodb"
MONGO_HOST="localhost"
MONGO_PORT="27017"
MONGO_USER="dbadmin"
MONGO_PASS="dbpassword331"
BACKUP_DIR="/tmp/backup"
TIMESTAMP=$(date +%F-%H%M%S)
S3_BUCKET_NAME="wiz-exercise-db-backups-9540199d"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Run mongodump to create backup
mongodump --host $MONGO_HOST --port $MONGO_PORT --username $MONGO_USER --password $MONGO_PASS --authenticationDatabase admin --db $MONGO_DATABASE --out $BACKUP_DIR/$TIMESTAMP

# Compress backup
tar -czvf $BACKUP_DIR/$TIMESTAMP.tar.gz -C $BACKUP_DIR $TIMESTAMP

# Upload backup to S3
aws s3 cp $BACKUP_DIR/$TIMESTAMP.tar.gz s3://$S3_BUCKET_NAME/backups/$TIMESTAMP.tar.gz

# Remove backup files
rm -rf $BACKUP_DIR/$TIMESTAMP*