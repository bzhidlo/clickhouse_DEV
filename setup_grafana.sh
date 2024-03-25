#!/bin/bash

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

# import dashboard 14432
