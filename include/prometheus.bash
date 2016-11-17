init() {
    debug prometheus init ...

}

choose-cluster() {
  local clusters=$(curl -sk \
        -H "Authorization: Bearer $TOKEN" \
        https://$PUBLIC_IP/cb/api/v1/stacks/user/ \
            | jq .[].name -r
  )
  PS3="Your choice: "
  select cluster in $clusters; do
      debug selected cluster: $cluster
      break
  done
  echo $cluster
}

get-cluster-ips() {
  declare cluster=${1:? required clusterName}

   curl -s -H "Authorization: Bearer $TOKEN"  -k https://$PUBLIC_IP/cb/api/v1/stacks/user/$cluster \
  | jq '{"PublicIP": .instanceGroups[].metadata[].publicIp}' \
  | jq -s -c .
}

prometheus-generate-targets-yaml() {
    declare desc="Genberates tagets yml, and loads it into consul"
    declare clusterIpsJson=${1:?required} port=${2:?required} path=${3:?required}

    local clusterIpsYml=$(
      sigil -i '- targets:{{- range $k,$v := stdin | json  }}{{"\n"}}  - {{ $v.PublicIP  }}:{{$PORT}}{{- end }}' PORT=$port <<< "$clusterIpsJson"
    )
    debug "clusterIpsYml=$clusterIpsYml"

    curl $PUBLIC_IP:8500/v1/kv/${path} -XPUT -d "$clusterIpsYml"


}

get-cluster-master_ip() {
  declare cluster=${1:? required clusterName}
   curl -s -H "Authorization: Bearer $TOKEN"  -k https://$PUBLIC_IP/cb/api/v1/stacks/user/$cluster \
  | jq '{"PublicIP": .instanceGroups[].metadata[] | select(.instanceGroup=="master").publicIp}' \
  | jq -s -c .
}
get-cluster-slave_ip() {
  declare cluster=${1:? required clusterName}
   curl -s -H "Authorization: Bearer $TOKEN"  -k https://$PUBLIC_IP/cb/api/v1/stacks/user/$cluster \
  | jq '{"PublicIP": .instanceGroups[].metadata[] | select(.instanceGroup=="slave_1").publicIp}' \
  | jq -s -c .
}

prometheus-monitor-cluster() {
    declare desc="Starts a cluster monitoring with prometheus"

    export TOKEN=$(util-token 2>/dev/null)
    debug "TOKEN=$TOKEN"

    local cluster=$(choose-cluster)
    debug "get node ips from: $cluster"

    local clusterIpsJson=$(get-cluster-ips $cluster)
    debug "clusterIpsJson: $clusterIpsJson"

    local clusterMasterIpsJson=$(get-cluster-master_ip $cluster)
    debug "clusterMasterIpsJson: $clusterMasterIpsJson"
    local clusterSlaveIpsJson=$(get-cluster-slave_ip $cluster)
    debug "clusterSlaveIpsJson: $clusterSlaveIpsJson"
    prometheus-generate-targets-yaml "$clusterIpsJson" 9100 etc/prometheus/sdiscovery/node_collector.yml
    prometheus-generate-targets-yaml "$clusterMasterIpsJson" 20101 etc/prometheus/sdiscovery/jmx_resourcemanager.yml
    prometheus-generate-targets-yaml "$clusterSlaveIpsJson" 20102 etc/prometheus/sdiscovery/jmx_nodemanager.yml
    prometheus-generate-targets-yaml "$clusterMasterIpsJson" 20103 etc/prometheus/sdiscovery/jmx_namenode.yml

    prometheus-generate-targets-yaml "$clusterIpsJson" 9246 etc/prometheus/sdiscovery/process.yml



}
