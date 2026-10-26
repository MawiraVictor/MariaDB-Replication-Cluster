# MariaDB Replication Cluster

A high-availability database setup with one master and two slave nodes, using binary log replication and HAProxy for read/write splitting.

## Architecture
- **Master:** 172.20.10.3
- **Slave 1:** 172.20.10.4
- **Slave 2:** 172.20.10.5

## Components
- **MariaDB Server** (Master/Slave replication)
- **HAProxy** (MySQL load balancing on port 3307)
- **Binlog Format:** Mixed
