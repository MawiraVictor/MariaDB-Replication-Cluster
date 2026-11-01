# MariaDB Replication Cluster

A MariaDB high-availability database setup with one master node and two replica (slave) nodes. The cluster uses binary log replication for data synchronization and HAProxy for read balancing across the replicas.

## Architecture

- Master database: `172.20.10.3`
- Replica 1: `172.20.10.4`
- Replica 2: `172.20.10.5`
- HAProxy frontend: `172.20.10.3:3307` (or the host running HAProxy)

## Components

- MariaDB Server
- Master-slave replication
- Binary log (`binlog`) replication
- HAProxy for MySQL read balancing
- Read/write split through a single HAProxy listener

## Project Structure

```text
MariaDB-Replication-Cluster/
├── configs/
│   ├── haproxy.cfg
│   ├── master.cnf
│   └── slave.cnf
├── scripts/
│   ├── change-master.sql
│   └── master-dump.sh
├── README.md
└── LICENSE (if present)
```

## Configuration Files

### Master configuration (`configs/master.cnf`)

```ini
[mysqld]
bind-address = 0.0.0.0
server_id = 1
log_bin = /var/log/mysql/mariadb-bin
binlog_format = mixed
```

This enables binary logging and assigns the master a unique server ID.

### Slave configuration (`configs/slave.cnf`)

```ini
[mysqld]
bind-address = 0.0.0.0
server_id = 2
```

The replica uses a different `server_id` and connects to the master for replication.

### HAProxy configuration (`configs/haproxy.cfg`)

```haproxy
# ---------- MySQL Slave Cluster ----------
frontend mysql_frontend
    bind *:3307
    mode tcp
    option tcplog
    default_backend mysql_slave_backend

backend mysql_slave_backend
    mode tcp
    option mysql-check user haproxy_check
    balance roundrobin
    server slave1 172.20.10.4:3306 check
    server slave2 172.20.10.5:3306 check
```

This routes incoming MySQL traffic to the replicas using round-robin balancing.

## Replication Flow

1. Configure the master with binary logging enabled.
2. Create a replication user on the master.
3. Export a snapshot from the master with `mysqldump --master-data`.
4. Import the dump on the slave.
5. Use `CHANGE MASTER TO` to connect the replica to the master.
6. Start replication on the slave.

## Scripts

### Master dump script (`scripts/master-dump.sh`)

```bash
#!/bin/bash
# Runs on master to create a snapshot for slaves
mysqldump -u root -p --all-databases --master-data > /tmp/master-dump.sql
```

This script creates a backup with replication metadata so a replica can continue from the correct binlog position.

### Slave configuration SQL (`scripts/change-master.sql`)

```sql
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='172.20.10.3',
  MASTER_USER='repl',
  MASTER_PASSWORD='imsrep',
  MASTER_LOG_FILE='mariadb-bin.000006',
  MASTER_LOG_POS=344;
START SLAVE;
```

This configures a replica to connect to the master and start stream replication.

## Setup Steps

### 1. Configure MariaDB on the master

- Set the master configuration using `configs/master.cnf`.
- Restart MariaDB.
- Create a replication user:

```sql
CREATE USER 'repl'@'%' IDENTIFIED BY 'imsrep';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
```

### 2. Create a snapshot for the slave

Run the script on the master:

```bash
bash scripts/master-dump.sh
```

Then copy the dump to the slave and restore it.

### 3. Configure the replica

- Update the server ID in `configs/slave.cnf`.
- Restart MariaDB.
- Load the dump on the replica.
- Run the `CHANGE MASTER TO` command from `scripts/change-master.sql`.

### 4. Start replication

```sql
START SLAVE;
SHOW SLAVE STATUS\G;
```

Check that `Slave_IO_Running` and `Slave_SQL_Running` are both `Yes`.

### 5. Start HAProxy

Use the HAProxy configuration file in `configs/haproxy.cfg` to balance reads across the replicas.

```bash
haproxy -f /etc/haproxy/haproxy.cfg
```

## Verification

To verify replication:

```sql
SHOW MASTER STATUS;
SHOW SLAVE STATUS\G;
```

To test read balancing through HAProxy:

```bash
mysql -h 127.0.0.1 -P 3307 -u root -p
```

## Notes

- This setup is useful for read-heavy workloads where replicas handle SELECT queries.
- Write operations continue to go through the master.
- The design provides improved availability and basic load distribution, but it is not a full production high-availability cluster by itself.
- For production use, additional safeguards such as failover automation, monitoring, backups, and security hardening should be added.

## License

This project is intended for educational and lab-based use. If a LICENSE file is added later, it should be reviewed and applied accordingly.
