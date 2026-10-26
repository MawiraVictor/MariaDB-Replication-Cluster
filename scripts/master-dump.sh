#!/bin/bash
# Runs on master to create a snapshot for slaves
mysqldump -u root -p --all-databases --master-data > /tmp/master-dump.sql
