
log-init() {
    debug "logging init"
    mkdir -p ./logconfig
    generate-logstash-configs logconfig/logstash.conf logconfig/logstash.yaml
}

generate-logstash-configs() {
    declare logstashFile=${1:? required: logstash config file path}
    declare logstashYml=${2:? required: logstash config file path}

    debug "Generating logstash config: ${logstashFile} ..."

    cat > ${logstashFile} << EOF
    input {
      udp {
        port  => 9600
        codec => json
      }
      tcp {
        port  => 9600
        codec => json
      }
    }

    filter {
      if [docker][name] =~ "cbreak_identity_1" { mutate { add_field => { "[@metadata][image_type]" => "cb-uaa" } } }
      else if [docker][name] =~ "cbreak_cloudbreak_1" { mutate { add_field => { "[@metadata][image_type]" => "cb" } } }
      else if [docker][name] =~ "cbreak_uluwatu_1" { mutate { add_field => { "[@metadata][image_type]" => "cb-web" } } }
      else if [docker][name] =~ "cbreak_sultans_1" { mutate { add_field => { "[@metadata][image_type]" => "cb-auth" } } }
      else if [docker][name] =~ "cbreak_commondb_1" { mutate { add_field => { "[@metadata][image_type]" => "commondb" } } }
      else if [docker][name] =~ "cbreak_consul_1" { mutate { add_field => { "[@metadata][image_type]" => "consul" } } }
      else if [docker][name] =~ "cbreak_traefik_1" { mutate { add_field => { "[@metadata][image_type]" => "traefik" } } }
      else if [docker][name] =~ "cbreak_periscope_1" { mutate { add_field => { "[@metadata][image_type]" => "as" } } }
      else if [docker][name] =~ "cbreak_haveged_1" { mutate { add_field => { "[@metadata][image_type]" => "haveged" } } }
      else if [docker][name] =~ "cbreak_mail_1" { mutate { add_field => { "[@metadata][image_type]" => "mail" } } }
      else if [docker][name] =~ "cbreak_registrator_1" { mutate { add_field => { "[@metadata][image_type]" => "registrator" } } }
      else if [docker][name] =~ "cbreak_smartsense_1" { mutate { add_field => { "[@metadata][image_type]" => "smartsense" } } }
      else if [docker][name] =~ "cbreak_logspout_1" { mutate { add_field => { "[@metadata][image_type]" => "logspout" } } }
      else if [docker][name] =~ "cbreak_logstash_1" { mutate { add_field => { "[@metadata][image_type]" => "logstash" } } }
      else if [docker][name] =~ "cbreak_logrotate_1" { mutate { add_field => { "[@metadata][image_type]" => "logrotate" } } }
      else { drop { } }

      if [@metadata][image_type] == "cb" {
        grok {
          match => [ 
            "message", "%{DATA:time} \[%{DATA:thread}\] %{DATA:method} %{LOGLEVEL:loglevel} %{DATA:class} - \[owner:%{DATA:owner}\] \[type:%{DATA:type}\] \[id:%{DATA:id}\] \[name:%{DATA:name}\] %{GREEDYDATA:logmessage}"
          ]
          keep_empty_captures => true
        }
        mutate { remove_field => "[message]" }
      }
    }

    output {
      file {
       path => [ "\${LOGSTASH_OUTPUT_PATH}/%{[@metadata][image_type]}.log" ]
      }
    }
EOF

    debug "Generating logstash config: ${logstashYml} ..."

    cat > ${logstashYml} << EOF
    ---
    http.host: "0.0.0.0"
    path.config: /usr/share/logstash/config
    xpack.monitoring.enabled: false
EOF
}
