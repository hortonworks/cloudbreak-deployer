init() {
    debug prometheus init ...
}

generate_prometheus_config() {
    mkdir -p prometheus/etc/sdiscovery
    mkdir -p prometheus/etc/rules
    mkdir -p prometheus/data

    cat > prometheus/etc/prometheus.yml << EOF
global:
  scrape_interval:     15s # By default, scrape targets every 15 seconds.
  evaluation_interval: 15s # By default, scrape targets every 15 seconds.
rule_files:
   - "/etc/prometheus/rules/*.rule"

scrape_configs:
    #   - job_name: 'jmx_resourcemanager'
    #     file_sd_configs:
    #     - files:
    #       - /etc/prometheus/sdiscovery/jmx_resourcemanager_collector.json
    #   - job_name: 'jmx_nodemanager'
    #     file_sd_configs:
    #     - files:
    #       - /etc/prometheus/sdiscovery/jmx_nodemanager_collector.json
    #   - job_name: 'jmx_namenode'
    #     file_sd_configs:
    #     - files:
    #       - /etc/prometheus/sdiscovery/jmx_namenode_collector.json
    #   - job_name: 'jmx_datanode'
    #     file_sd_configs:
    #     - files:
    #       - /etc/prometheus/sdiscovery/jmx_datanode_collector.json
    #   - job_name: 'jmx_zookeeper_server'
    #     file_sd_configs:
    #     - files:
    #       - /etc/prometheus/sdiscovery/jmx_zookeeper_server_collector.json
  - job_name: 'node'
    file_sd_configs:
    - files:
      - /etc/prometheus/sdiscovery/node_collector.yml
    # - /etc/prometheus/sdiscovery/node_collector.json
    #   - job_name: 'process'
    #     file_sd_configs:
    #     - files:
    #       - /etc/prometheus/sdiscovery/process_collector.json
EOF

    cat > prometheus/etc/sdiscovery/node_collector.yml <<EOF
- targets: []
EOF
}


prometheus-generate-node-exporter-config() {
    declare desc="Generates node-exporter config yaml"
    declare cluster=${1:? required cluster name}
    hdc describe-cluster instances --cluster-name "$cluster"  \
        | sigil -f node_collector.tmpl PORT=9100 \
        > prometheus/etc/sdiscovery/node_collector.yml
}

