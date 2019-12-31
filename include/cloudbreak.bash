
cloudbreak-config() {
  if is_macos; then
    : ${BRIDGE_ADDRESS:=host.docker.internal}
  else
    : ${BRIDGE_ADDRESS:=$(docker run --rm --name=cbreak_cbd_bridgeip --label cbreak.sidekick=true alpine sh -c 'ip ro | grep default | cut -d" " -f 3')}
  fi
  cloudbreak-conf-tags
  cloudbreak-conf-images
  cloudbreak-conf-capabilities
  cloudbreak-conf-cert
  cloudbreak-conf-db
  cloudbreak-conf-defaults
  cloudbreak-conf-autscale
  cloudbreak-conf-cloud-provider
  cloudbreak-conf-rest-client
  cloudbreak-conf-ui
  cloudbreak-conf-host-addr
  cloudbreak-conf-java
  cloudbreak-conf-vault
  cloudbreak-conf-caas
  cloudbreak-conf-proxy
  migrate-config
}


cloudbreak-conf-caas() {
    declare desc="Defines CAAS related configs"

    env-import CAAS_URL "caas-mock:8080"
}

cloudbreak-conf-tags() {
    declare desc="Defines docker image tags"

    env-import DOCKER_NETWORK_NAME default

    env-import DOCKER_TAG_ALPINE 3.8
    env-import DOCKER_TAG_HAVEGED 1.1.0
    env-import DOCKER_TAG_TRAEFIK v1.7.9-alpine
    env-import DOCKER_TAG_CONSUL 1.4.0
    env-import DOCKER_TAG_REGISTRATOR v7
    env-import DOCKER_TAG_AMBASSADOR 0.5.0
    env-import DOCKER_TAG_CERT_TOOL 0.2.0

    env-import DOCKER_TAG_CAAS_MOCK 2.16.0-rc.155
    env-import DOCKER_TAG_PERISCOPE 2.16.0-rc.155
    env-import DOCKER_TAG_CLOUDBREAK 2.16.0-rc.155
    env-import DOCKER_TAG_DATALAKE 2.16.0-rc.155
    env-import DOCKER_TAG_REDBEAMS 2.16.0-rc.155
    env-import DOCKER_TAG_ENVIRONMENT 2.16.0-rc.155
    env-import DOCKER_TAG_FREEIPA 2.16.0-rc.155
    env-import DOCKER_TAG_ULUWATU 2.16.0-rc.155

    env-import DOCKER_TAG_IDBMMS 76df5355c0f5776c2288a38f731cf46c30e9c146
    env-import DOCKER_TAG_ENVIRONMENTS2_API d4f8f7e4106895e3dec7bfd354e4aefb087823c6

    env-import DOCKER_TAG_POSTGRES 9.6.1-alpine
    env-import DOCKER_TAG_LOGROTATE 1.0.1
    env-import DOCKER_TAG_CBD_SMARTSENSE 0.13.4
    env-import DOCKER_TAG_CLUSTER_PROXY 2.1.0.0-154

    env-import DOCKER_IMAGE_CAAS_MOCK docker-private.infra.cloudera.com/cloudera/cloudbreak-mock-caas
    env-import DOCKER_IMAGE_CLOUDBREAK docker-private.infra.cloudera.com/cloudera/cloudbreak
    env-import DOCKER_IMAGE_CLOUDBREAK_WEB docker-private.infra.cloudera.com/cloudera/hdc-web
    env-import DOCKER_IMAGE_CLOUDBREAK_AUTH docker-private.infra.cloudera.com/cloudera/hdc-auth
    env-import DOCKER_IMAGE_CLOUDBREAK_PERISCOPE docker-private.infra.cloudera.com/cloudera/cloudbreak-autoscale
    env-import DOCKER_IMAGE_CLOUDBREAK_DATALAKE docker-private.infra.cloudera.com/cloudera/cloudbreak-datalake
    env-import DOCKER_IMAGE_CLOUDBREAK_REDBEAMS docker-private.infra.cloudera.com/cloudera/cloudbreak-redbeams
    env-import DOCKER_IMAGE_CLOUDBREAK_ENVIRONMENT docker-private.infra.cloudera.com/cloudera/cloudbreak-environment
    env-import DOCKER_IMAGE_CLOUDBREAK_FREEIPA docker-private.infra.cloudera.com/cloudera/cloudbreak-freeipa
    env-import DOCKER_IMAGE_CBD_SMARTSENSE hortonworks/cbd-smartsense

    env-import DOCKER_IMAGE_IDBMMS docker-private.infra.cloudera.com/cloudera/thunderhead-idbrokermappingmanagement
    env-import DOCKER_IMAGE_ENVIRONMENTS2_API docker-private.infra.cloudera.com/cloudera/thunderhead-environments2-api
    env-import DOCKER_IMAGE_CLUSTER_PROXY docker-private.infra.cloudera.com/cloudera/dps-cluster-proxy

    env-import CB_DEFAULT_SUBSCRIPTION_ADDRESS http://uluwatu:3000/notifications

}

cloudbreak-conf-images() {
    declare desc="Defines image catalog urls"

    env-import CB_IMAGE_CATALOG_URL ""
    env-import FREEIPA_IMAGE_CATALOG_URL ""
}

cloudbreak-conf-capabilities() {
    declare desc="Enables capabilities"

    env-import CB_CAPABILITIES ""
    CB_CAPABILITIES=$(echo $CB_CAPABILITIES | awk '{print toupper($0)}')
    env-import INFO_APP_CAPABILITIES "$CB_CAPABILITIES"
}

cloudbreak-conf-db() {
    declare desc="Declares cloudbreak DB config"

    env-import COMMON_DB commondb
    env-import COMMON_DB_VOL common
    env-import CB_DB_ENV_USER "postgres"
    env-import CB_DB_ENV_DB "cbdb"
    env-import CB_DB_ENV_PASS ""
    env-import CB_DB_ENV_SCHEMA "public"
    env-import CB_HBM2DDL_STRATEGY "validate"

    env-import PERISCOPE_DB_ENV_USER "postgres"
    env-import PERISCOPE_DB_ENV_DB "periscopedb"
    env-import PERISCOPE_DB_ENV_PASS ""
    env-import PERISCOPE_DB_ENV_SCHEMA "public"
    env-import PERISCOPE_HBM2DDL_STRATEGY "validate"

    env-import DATALAKE_DB_ENV_USER "postgres"
    env-import DATALAKE_DB_ENV_DB "datalakedb"
    env-import DATALAKE_DB_ENV_PASS ""
    env-import DATALAKE_DB_ENV_SCHEMA "public"
    env-import DATALAKE_HBM2DDL_STRATEGY "validate"

    env-import REDBEAMS_DB_ENV_USER "postgres"
    env-import REDBEAMS_DB_ENV_DB "redbeamsdb"
    env-import REDBEAMS_DB_ENV_PASS ""
    env-import REDBEAMS_DB_ENV_SCHEMA "public"
    env-import REDBEAMS_HBM2DDL_STRATEGY "validate"

    env-import ENVIRONMENT_DB_ENV_USER "postgres"
    env-import ENVIRONMENT_DB_ENV_DB "environmentdb"
    env-import ENVIRONMENT_DB_ENV_PASS ""
    env-import ENVIRONMENT_DB_ENV_SCHEMA "public"
    env-import ENVIRONMENT_HBM2DDL_STRATEGY "validate"

    env-import FREEIPA_DB_ENV_USER "postgres"
    env-import FREEIPA_DB_ENV_DB "freeipadb"
    env-import FREEIPA_DB_ENV_PASS ""
    env-import FREEIPA_DB_ENV_SCHEMA "public"
    env-import FREEIPA_HBM2DDL_STRATEGY "validate"

    env-import IDBMMS_DB_ENV_USER "postgres"
    env-import IDBMMS_DB_ENV_DB "idbmmsdb"
    env-import IDBMMS_DB_ENV_PASS ""
    env-import IDBMMS_DB_PORT_5432_TCP_ADDR "$COMMON_DB"
    env-import IDBMMS_DB_PORT_5432_TCP_PORT "5432"

    env-import CLUSTER_PROXY_DB_ENV_DB "cluster_proxy"
    env-import CLUSTER_PROXY_DB_ENV_USER "postgres"
    env-import CLUSTER_PROXY_DB_ENV_PASS ""

    env-import VAULT_DB_SCHEMA "vault"
}

cloudbreak-conf-cert() {
    declare desc="Declares cloudbreak cert config"
    env-import CBD_CERT_ROOT_PATH "${PWD}/certs"

    env-import CBD_TRAEFIK_TLS "/certs/traefik/client.pem,/certs/traefik/client-key.pem"
}

cloudbreak-conf-defaults() {
    env-import PUBLIC_IP

    if [[ ! -z "$CB_CLUSTERDEFINITION_AMBARI_DEFAULTS"  ]]; then
        env-import CB_CLUSTERDEFINITION_AMBARI_DEFAULTS
    fi;
    env-import CB_CLUSTERDEFINITION_AMBARI_INTERNAL ""
    if [[ ! -z "$CB_TEMPLATE_DEFAULTS" ]]; then
        env-import CB_TEMPLATE_DEFAULTS
    fi;
    if [[ ! -z "$CB_DEFAULT_GATEWAY_CIDR" ]]; then
        env-import CB_DEFAULT_GATEWAY_CIDR
    fi;
    env-import CB_AUDIT_FILE_ENABLED false
    env-import CB_KAFKA_BOOTSTRAP_SERVERS ""
    env-import ADDRESS_RESOLVING_TIMEOUT 120000
    env-import CB_UI_MAX_WAIT 400
    env-import CB_HOST_DISCOVERY_CUSTOM_DOMAIN ""
    env-import CB_SMARTSENSE_CONFIGURE "false"
    env-import TRAEFIK_MAX_IDLE_CONNECTION 100
    env-import CB_AWS_VPC ""
    env-import CB_MAX_SALT_NEW_SERVICE_RETRY 90
    env-import CB_MAX_SALT_NEW_SERVICE_RETRY_ONERROR 10
    env-import CB_MAX_SALT_RECIPE_EXECUTION_RETRY 90
    env-import CB_LOG_LEVEL "DEBUG"
    env-import CB_PORT 8080

    env-import CB_INSTANCE_UUID
    env-import CB_INSTANCE_NODE_ID
    env-validate CB_INSTANCE_UUID *" "* "space"

    env-import CB_SMARTSENSE_ID ""

    env-import DOCKER_STOP_TIMEOUT 60

    env-import PUBLIC_HTTP_PORT 80
    env-import PUBLIC_HTTPS_PORT 443
    env-import CB_SHOW_TERMINATED_CLUSTERS_ACTIVE false
    env-import CB_SHOW_TERMINATED_CLUSTERS_DAYS 7
    env-import CB_SHOW_TERMINATED_CLUSTERS_HOURS 0
    env-import CB_SHOW_TERMINATED_CLUSTERS_MINUTES 0

    env-import CB_LOCAL_DEV_LIST ""
    env-import DPS_VERSION "latest"
    env-import DPS_REPO ""
    env-import UMS_ENABLED "true"
    env-import CAAS_MOCK "true"
    env-import INGRESS_URLS "localhost,manage.dps.local"

    env-import CLOUDBREAK_URL $(service-url cloudbreak "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "http://" "9091" "8080")
    env-import PERISCOPE_URL $(service-url periscope "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "http://" "8085" "8080")
    env-import DATALAKE_URL $(service-url datalake "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "http://" "8086" "8080")
    env-import REDBEAMS_URL $(service-url redbeams "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "http://" "8087" "8080")
    env-import ENVIRONMENT_URL $(service-url environment "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "http://" "8088" "8088")
    env-import FREEIPA_URL $(service-url freeipa "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "http://" "8090" "8080")
    env-import CLUSTER_PROXY_URL "$(service-url cluster-proxy "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "http://" "10180" "10080")/cluster-proxy"
    env-import JAEGER_HOST "$BRIDGE_ADDRESS"

    env-import ENVIRONMENT_HOST $(host-from-url "$ENVIRONMENT_URL")
    env-import FREEIPA_HOST $(host-from-url "$FREEIPA_URL")

    env-import DATALAKE_HOST $(host-from-url "$DATALAKE_URL")
    env-import CLUSTER_PROXY_HOST $(host-from-url "$CLUSTER_PROXY_URL")

    env-import IDBMMS_URL $(service-url idbmms "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "" "8990" "8982")
    env-import IDBMMS_HOST $(host-from-url "$IDBMMS_URL")
    env-import ENVIRONMENTS2_API_URL $(service-url environments2-api "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "http://" "8984" "8982")

    env-import ENVIRONMENT_PORT $(port-from-url "$ENVIRONMENT_URL")
    env-import FREEIPA_PORT $(port-from-url "$FREEIPA_URL")

    env-import DATALAKE_PORT $(port-from-url "$DATALAKE_URL")
    env-import CLUSTER_PROXY_PORT $(port-from-url "$CLUSTER_PROXY_URL")
    env-import ALTUS_TUNNEL_MANAGEMENT_HOST "$BRIDGE_ADDRESS"
    env-import ALTUS_TUNNEL_MANAGEMENT_PORT 9012

    env-import IDBMMS_PORT $(port-from-url "$IDBMMS_URL")
    env-import IDBMMS_HEALTHZ_PORT 8991
    env-import ENVIRONMENTS2_API_HEALTHZ_PORT 8983

    env-import UAA_ULUWATU_SECRET "dummysecret"

    if [[ "$CAAS_MOCK" == "true" ]]; then
        env-import ULUWATU_FRONTEND_RULE "PathPrefix:/"
        env-import CAAS_URL $(service-url auth-mock "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "" "8080" "8080")
        env-import GATEWAY_DEFAULT_REDIRECT_PATH "/environments"
        if [[ "$UMS_ENABLED" == "true" ]]; then
            env-import UMS_HOST $(service-url auth-mock "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "" "" "")
        fi
    else
        env-import GATEWAY_DEFAULT_REDIRECT_PATH "/cloud"
        env-import CAAS_URL $(service-url caas-api "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "" "8080" "10080")
        if [[ "$UMS_ENABLED" == "true" ]]; then
            env-import UMS_HOST $(service-url caas-api "$BRIDGE_ADDRESS" "$CB_LOCAL_DEV_LIST" "" "" "")
        fi
    fi

    env-import UMS_PORT "8982"
    env-import CLUSTERPROXY_ENABLED "true"
}

cloudbreak-conf-autscale() {
    env-import PERISCOPE_LOG_LEVEL "DEBUG"
}

cloudbreak-conf-cloud-provider() {
    declare desc="Defines cloud provider related parameters"

    env-import AWS_ACCESS_KEY_ID ""
    env-import AWS_SECRET_ACCESS_KEY ""
    env-import AWS_GOV_ACCESS_KEY_ID ""
    env-import AWS_GOV_SECRET_ACCESS_KEY ""
    env-import CB_AWS_DEFAULT_CF_TAG ""
    env-import CB_AWS_CUSTOM_CF_TAGS ""

    env-import CB_AWS_HOSTKEY_VERIFY "false"
    env-import CB_GCP_HOSTKEY_VERIFY "false"

    env-import CB_AWS_ACCOUNT_ID ""
}

cloudbreak-conf-rest-client() {
    declare desc="Defines rest client related parameters"

    env-import REST_DEBUG "false"
    env-import CERT_VALIDATION "true"
}

cloudbreak-conf-ui() {
    declare desc="Defines Uluwatu related parameters"

    env-import ULU_HOST_ADDRESS  "https://$PUBLIC_IP:$PUBLIC_HTTPS_PORT"
    env-import ULU_NODE_TLS_REJECT_UNAUTHORIZED "0"
    env-import ULU_SUBSCRIBE_TO_NOTIFICATIONS "true"
}

cloudbreak-conf-host-addr() {
    declare desc="Defines Host address related parameters"

    env-import CB_HOST_ADDRESS  "http://$PUBLIC_IP"
    env-import ENVIRONMENT_HOST_ADDRESS  "http://$PUBLIC_IP"
    env-import FREEIPA_HOST_ADDRESS  "http://$PUBLIC_IP"
    env-import REDBEAMS_HOST_ADDRESS  "http://$PUBLIC_IP"
    env-import PERISCOPE_HOST_ADDRESS  "http://$PUBLIC_IP"
    env-import DATALAKE_HOST_ADDRESS  "http://$PUBLIC_IP"
}

cloudbreak-conf-java() {
    env-import CB_JAVA_OPTS ""
}

cloudbreak-conf-proxy() {
    env-import HTTP_PROXY_HOST ""
    env-import HTTPS_PROXY_HOST ""
    env-import PROXY_PORT ""
    env-import PROXY_USER ""
    env-import PROXY_PASSWORD ""
    env-import NON_PROXY_HOSTS "*.consul"
    env-import HTTPS_PROXYFORCLUSTERCONNECTION "false"
}

cloudbreak-generate-cert() {
    cloudbreak-config
    if [ -f "${CBD_CERT_ROOT_PATH}/traefik/client.pem" ] && [ -f "${CBD_CERT_ROOT_PATH}/traefik/client-key.pem" ]; then
      debug "Cloudbreak certificate and private key already exist, won't generate new ones."
    else
      info "Generating Cloudbreak client certificate and private key in ${CBD_CERT_ROOT_PATH} with ${PUBLIC_IP} into ${CBD_CERT_ROOT_PATH}/traefik."
      mkdir -p "${CBD_CERT_ROOT_PATH}/traefik"
      if is_linux; then
        run_as_user="-u $(id -u $(whoami)):$(id -g $(whoami))"
      fi

      cbd_ca_cert_gen_out=$(mktemp)
      docker run \
          --label cbreak.sidekick=true \
          $run_as_user \
          -v ${CBD_CERT_ROOT_PATH}:/certs \
          ehazlett/certm:${DOCKER_TAG_CERT_TOOL} \
          -d /certs/traefik ca generate -o=local &> $cbd_ca_cert_gen_out || CA_CERT_EXIT_CODE=$? && true;
      if [[ $CA_CERT_EXIT_CODE -ne 0 ]]; then
          cat $cbd_ca_cert_gen_out;
          exit 1;
      fi

      cbd_client_cert_gen_out=$(mktemp)
      docker run \
          --label cbreak.sidekick=true \
          $run_as_user \
          -v ${CBD_CERT_ROOT_PATH}:/certs \
          ehazlett/certm:${DOCKER_TAG_CERT_TOOL} \
          -d /certs/traefik client generate --common-name=${PUBLIC_IP} -o=local &> $cbd_client_cert_gen_out || CLIENT_CERT_EXIT_CODE=$? && true;
      if [[ $CLIENT_CERT_EXIT_CODE -ne 0 ]]; then
         cat $cbd_client_cert_gen_out;
         exit 1;
      fi

      owner=$(ls -od ${CBD_CERT_ROOT_PATH} | tr -s ' ' | cut -d ' ' -f 3)
      [[ "$owner" != "$(whoami)" ]] && sudo chown -R $(whoami):$(id -gn) ${CBD_CERT_ROOT_PATH}
      mv "${CBD_CERT_ROOT_PATH}/traefik/cert.pem" "${CBD_CERT_ROOT_PATH}/traefik/client.pem"
      cat "${CBD_CERT_ROOT_PATH}/traefik/ca.pem" >> "${CBD_CERT_ROOT_PATH}/traefik/client.pem"
      mv "${CBD_CERT_ROOT_PATH}/traefik/key.pem" "${CBD_CERT_ROOT_PATH}/traefik/client-key.pem"
      mv "${CBD_CERT_ROOT_PATH}/traefik/ca.pem" "${CBD_CERT_ROOT_PATH}/traefik/client-ca.pem"
      mv "${CBD_CERT_ROOT_PATH}/traefik/ca-key.pem" "${CBD_CERT_ROOT_PATH}/traefik/client-ca-key.pem"
      debug "Certificates successfully generated."
    fi
}

generate-toml-file-for-localdev() {
    cloudbreak-config

    if ! generate-traefik-check-diff; then
        if [[ "$CBD_FORCE_START" ]]; then
            warn "You have forced to start ..."
        else
            warn "Please check the expected config changes with:"
            echo "  cbd doctor" | blue
            debug "If you want to ignore the changes, set the CBD_FORCE_START to true in Profile"
            _exit 1
        fi
    else
        info "generating traefik.toml"
        generate-toml-file-for-localdev-force
    fi
}

generate-toml-file-for-localdev-force() {
    declare traefikFile=${1:-traefik.toml}
    generate-traefik-toml "$CLOUDBREAK_URL" "$PERISCOPE_URL" "$DATALAKE_URL" "$ENVIRONMENT_URL" "$REDBEAMS_URL" "$FREEIPA_URL" "http://$CAAS_URL" "$CLUSTER_PROXY_URL" "$ENVIRONMENTS2_API_URL" "$CB_LOCAL_DEV_LIST" > "$traefikFile"
}

generate-traefik-check-diff() {
    cloudbreak-config

    local verbose="$1"

    if [ -f traefik.toml ]; then
        local traefik_delme_path=$TEMP_DIR/traefik-delme.toml
        generate-toml-file-for-localdev-force $traefik_delme_path
        if diff $traefik_delme_path traefik.toml &> /dev/null; then
            debug "traefik.toml exists and generate wouldn't change it"
            return 0
        else
            if ! [[ "$regeneteInProgress" ]]; then
                warn "traefik.toml already exists, BUT generate would create a DIFFERENT one!"
                warn "please regenerate it:"
                echo "  cbd regenerate" | blue
            fi

            if [[ "$verbose" ]]; then
                warn "expected change:"
                diff $traefik_delme_path traefik.toml || true
            else
                debug "expected change:"
                (diff $traefik_delme_path traefik.toml || true) | debug-cat
            fi
            return 1
        fi
    else
        generate-toml-file-for-localdev-force
    fi
    return 0

}

generate-caddy-file-for-localdev() {
    info "generating Caddyfile"
    declare caddyFile=${1:-Caddyfile}
    generate-caddy-file "$INGRESS_URLS" > "$caddyFile"
}

util-token() {
    declare desc="Generates an OAuth token with CloudbreakShell scopes"

    cloudbreak-config

    if [ $# -ne 2 ]; then
        error "Invalid parameters, please provide username tenant like this: cbd util token admin@hortonworks.com hortonworks"
    else
        local username=$1
        local tenant=$2
        local TOKEN=$(curl --insecure --silent --cookie-jar - "https://localhost/auth/in?tenant=$tenant&username=$username&redirect_uri=https%3A%2F%2Flocalhost" | tr -d '\n' | awk -F/ '{print $NF}' | awk '{ print $(NF) }')
        echo ${TOKEN}
    fi
}

util-token-debug() {
    declare desc="Opens the browse jwt.io to inspect a newly generated Oauth token."

    local username=$1
    local tenant=$2
    local token="$(util-token $username $tenant)"
    open "http://jwt.io/?value=$token"
}

