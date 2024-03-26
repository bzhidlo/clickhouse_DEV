# Clickhouse Cluster

Clickhouse cluster with 2 shards and 2 replicas built with docker-compose.

Not for production use.

## Run

Run single command, and it will copy configs for each node and
run clickhouse cluster `company_cluster` with docker-compose
```sh
make config up
```

Containers will be available in docker network `172.23.0.0/24`

| Container    | Address
| ------------ | -------
| zookeeper    | 172.23.0.10
| clickhouse01 | 172.23.0.11
| clickhouse02 | 172.23.0.12
| clickhouse03 | 172.23.0.13
| clickhouse04 | 172.23.0.14
| prometheus   | 172.23.0.100
| node-exporter| 172.23.0.101
| grafana      | 172.23.0.102

## Profiles

- `default` - no password
- `admin` - password `123`

## Test it

Login to clickhouse01 console (first node's ports are mapped to localhost)
```sh
clickhouse-client -h localhost
```

Or open `clickhouse-client` inside any container
```sh
docker exec -it clickhouse01 clickhouse-client -h localhost
```

Create a test database and table (sharded and replicated)
```sql
CREATE DATABASE company_db ON CLUSTER 'company_cluster';

CREATE TABLE company_db.events ON CLUSTER 'company_cluster' (
    time DateTime,
    uid  Int64,
    type LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{cluster}/{shard}/table', '{replica}')
PARTITION BY toDate(time)
ORDER BY (uid);

CREATE TABLE company_db.events_distr ON CLUSTER 'company_cluster' AS company_db.events
ENGINE = Distributed('company_cluster', company_db, events, uid);
```

Load some data
```sql
INSERT INTO company_db.events_distr VALUES
    ('2020-01-01 10:00:00', 100, 'view'),
    ('2020-01-01 10:05:00', 101, 'view'),
    ('2020-01-01 11:00:00', 100, 'contact'),
    ('2020-01-01 12:10:00', 101, 'view'),
    ('2020-01-02 08:10:00', 100, 'view'),
    ('2020-01-03 13:00:00', 103, 'view');
```

Check data from the current shard
```sql
SELECT * FROM company_db.events;
```

Check data from all cluster
```sql
SELECT * FROM company_db.events_distr;
```

## Add more nodes

If you need more Clickhouse nodes, add them like this:

1. Add replicas/shards to `config.xml` to the block `company/remote_servers/company_cluster`.
1. Add nodes to `docker-compose.yml`.
1. Add nodes in `Makefile` in `config` target.

## Teardown

Stop and remove containers
```sh
make down
```

Stop and remove containers and volumes and networks


Monitoring
```sh
make after
```

- 1 Create datasource prometheus:9090
- 2 Install plugin Altinity plugin for ClickHouse
- 3 Create datasource  "Altinity plugin for ClickHouse" for any Clickhouse databases [clickhouse01,clickhouse02 ...]
- 4 Import dashboards: 2515 and 13500 and 14432
- 5 Create on all clickhouse hosts distributed table 'CREATE TABLE system.query_log_all AS system.query_log ENGINE = Distributed(company_cluster, system, query_log);'

https://grafana.com/grafana/dashboards/2515-clickhouse-queries/
https://grafana.com/grafana/plugins/vertamedia-clickhouse-datasource/
https://grafana.com/grafana/dashboards/13500-clickhouse-internal-exporter/
https://grafana.com/grafana/dashboards/14432-clickhouse-metrics-on-settings/

# install plugin
curl 'http://admin:admin@127.0.0.1:3000/api/plugins/vertamedia-clickhouse-datasource/install' -X POST \
-H 'content-type: application/json'
# install datasources
for i in $(seq 0 4);do 
jq .[$i] multi_source.json | curl -XPOST -i http://admin:admin@localhost:3000/api/datasources -H "Content-Type: application/json" --data-binary @- ; 
done
# import dashboard 13500
for ii in $(curl 'http://admin:admin@127.0.0.1:3000/api/datasources' -s|jq '.[]|select(.type=="prometheus").uid'); do  ii=$(echo $ii | awk '{gsub("\"","");print}');  curl 'http://admin:admin@127.0.0.1:3000/api/gnet/dashboards/13500' -H 'Accept: application/json, text/plain, */*' -s | jq '.json' | jq '{"dashboard": . }' | jq -r --arg UID "$ii" '.+={"inputs":[{"name":"DS_PROMETHEUS","type":"datasource","pluginId":"vertamedia-clickhouse-datasource","value":$UID}]}' | curl 'http://admin:admin@127.0.0.1:3000/api/dashboards/import' -X POST -H 'content-type: application/json' -d "$(</dev/stdin)" ;  done

# import dashboard 2515
for ii in $(curl 'http://admin:admin@127.0.0.1:3000/api/datasources' -s|jq '.[]|select(.type=="vertamedia-clickhouse-datasource").uid'); do  ii=$(echo $ii | awk '{gsub("\"","");print}');  curl 'http://admin:admin@127.0.0.1:3000/api/gnet/dashboards/2515' -H 'Accept: application/json, text/plain, */*' -s | jq '.json' | awk -v a="$ii" '{gsub("ClickHouse Queries","ClickHouse Queries "a);print}' | jq '{"dashboard": . }' | jq -r --arg UID "$ii" '.+={"inputs":[{"name":"DS_CLICKHOUSE","type":"datasource","pluginId":"vertamedia-clickhouse-datasource","value":$UID}]}' | curl 'http://admin:admin@127.0.0.1:3000/api/dashboards/import' -X POST -H 'content-type: application/json' -d "$(</dev/stdin)" ;  done

