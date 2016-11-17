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
  | jq -s .
}
prometheus-monitor-cluster() {
    declare desc="Starts a cluster monitoring with prometheus"

    export TOKEN=$(util-token 2>/dev/null)
    debug "TOKEN=$TOKEN"

    local cluster=$(choose-cluster)
    debug "get node ips from: $cluster"

    local clusterIpsJson=$(get-cluster-ips $cluster)
    debug "clusterIpsJson: $clusterIpsJson"
    
    local clusterIpsYml=$(
      sigil -i '- targets:{{- range $k,$v := stdin | json  }}{{"\n"}}  - {{ $v.PublicIP  }}:9100{{- end }}' <<< "$clusterIpsJson"
    )
    debug "clusterIpsYml=$clusterIpsYml"

    curl $PUBLIC_IP:8500/v1/kv/etc/prometheus/sdiscovery/node_collector.yml -XPUT -d "$clusterIpsYml"


}
