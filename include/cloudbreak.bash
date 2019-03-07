
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
  cloudbreak-conf-uaa
  cloudbreak-conf-cloud-provider
  cloudbreak-conf-rest-client
  cloudbreak-conf-ui
  cloudbreak-conf-java
  cloudbreak-conf-vault
  cloudbreak-conf-caas
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
    env-import DOCKER_TAG_UAA 3.6.5-pgupdate
    env-import DOCKER_TAG_AMBASSADOR 0.5.0
    env-import DOCKER_TAG_CERT_TOOL 0.2.0

    env-import DOCKER_TAG_CAAS_MOCK 2.10.0-dev.624
    env-import DOCKER_TAG_PERISCOPE 2.10.0-dev.624
    env-import DOCKER_TAG_CLOUDBREAK 2.10.0-dev.624
    env-import DOCKER_TAG_DATALAKE 2.10.0-dev.624
    env-import DOCKER_TAG_ULUWATU 2.10.0-dev.624

    env-import DOCKER_TAG_POSTGRES 9.6.1-alpine
    env-import DOCKER_TAG_LOGROTATE 1.0.1
    env-import DOCKER_TAG_CBD_SMARTSENSE 0.13.4

    env-import DOCKER_IMAGE_CAAS_MOCK hortonworks/cloudbreak-mock-caas
    env-import DOCKER_IMAGE_CLOUDBREAK hortonworks/cloudbreak
    env-import DOCKER_IMAGE_CLOUDBREAK_WEB hortonworks/hdc-web
    env-import DOCKER_IMAGE_CLOUDBREAK_AUTH hortonworks/hdc-auth
    env-import DOCKER_IMAGE_CLOUDBREAK_PERISCOPE hortonworks/cloudbreak-autoscale
    env-import DOCKER_IMAGE_CLOUDBREAK_DATALAKE hortonworks/cloudbreak-datalake
    env-import DOCKER_IMAGE_CBD_SMARTSENSE hortonworks/cbd-smartsense

    env-import CB_DEFAULT_SUBSCRIPTION_ADDRESS http://uluwatu:3000/notifications

}

cloudbreak-conf-images() {
    declare desc="Defines image catalog urls"

    env-import CB_IMAGE_CATALOG_URL ""
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

    env-import IDENTITY_DB_URL "${COMMON_DB}:5432"
    env-import IDENTITY_DB_NAME "uaadb"
    env-import IDENTITY_DB_USER "postgres"
    env-import IDENTITY_DB_PASS ""

    env-import VAULT_DB_SCHEMA "vault"
}

cloudbreak-conf-cert() {
    declare desc="Declares cloudbreak cert config"
    env-import CBD_CERT_ROOT_PATH "${PWD}/certs"

    env-import CBD_TRAEFIK_TLS "/certs/traefik/client.pem,/certs/traefik/client-key.pem"
}

cloudbreak-conf-uaa() {
    env-import UAA_PORT 8089

    env-import UAA_SETTINGS_FILE uaa-changes.yml

    env-import UAA_DEFAULT_SECRET
    env-validate UAA_DEFAULT_SECRET *" "* "space"

    env-import UAA_CLOUDBREAK_ID cloudbreak
    env-import UAA_CLOUDBREAK_SECRET $UAA_DEFAULT_SECRET
    env-validate UAA_CLOUDBREAK_SECRET *" "* "space"

    env-import UAA_PERISCOPE_ID periscope
    env-import UAA_PERISCOPE_SECRET $UAA_DEFAULT_SECRET
    env-validate UAA_PERISCOPE_SECRET *" "* "space"

    env-import UAA_DATALAKE_ID datalake
    env-import UAA_DATALAKE_SECRET $UAA_DEFAULT_SECRET
    env-validate UAA_DATALAKE_SECRET *" "* "space"

    env-import UAA_ULUWATU_ID uluwatu
    env-import UAA_ULUWATU_SECRET $UAA_DEFAULT_SECRET
    env-validate UAA_ULUWATU_SECRET *" "* "space"

    env-import UAA_CLOUDBREAK_SHELL_ID cloudbreak_shell
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

    env-import CB_LOCAL_DEV "false"
    env-import DPS_VERSION "latest"
    env-import DPS_REPO ""

    if [[ "$CB_LOCAL_DEV" == "true" ]]; then
        env-import CLOUDBREAK_URL "http://$BRIDGE_ADDRESS:9091"
        env-import PERISCOPE_URL "http://$BRIDGE_ADDRESS:8085"
        env-import DATALAKE_URL "http://$BRIDGE_ADDRESS:8086"
    else
        env-import CLOUDBREAK_URL "http://cloudbreak:8080"
        env-import PERISCOPE_URL "http://periscope:8080"
        env-import DATALAKE_URL "http://datalake:8080"
    fi

    if [[ -z "$DPS_REPO" ]]; then
        env-import ULUWATU_FRONTEND_RULE "PathPrefix:/"
        env-import CAAS_URL "caas-api:8080"
    else
        env-import ULUWATU_FRONTEND_RULE "PathPrefixStrip:/cloud"
        env-import CAAS_URL "caas-api:10080"
    fi
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
    env-import CB_HOST_ADDRESS  "http://$PUBLIC_IP"
    env-import ULU_NODE_TLS_REJECT_UNAUTHORIZED "0"
    env-import ULU_SUBSCRIBE_TO_NOTIFICATIONS "true"
}

cloudbreak-conf-java() {
    env-import CB_JAVA_OPTS ""
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
    if [[ "$CB_LOCAL_DEV" == "true" ]]; then
        cat > traefik.toml << EOF
[file]

[backends]
    [backends.cloudbreak]
        [backends.cloudbreak.servers]
            [backends.cloudbreak.servers.server0]
            url = "$CLOUDBREAK_URL"
    [backends.datalake]
        [backends.datalake.servers]
            [backends.datalake.servers.server0]
            url = "$DATALAKE_URL"
    [backends.periscope]
        [backends.periscope.servers]
            [backends.periscope.servers.server0]
            url = "$PERISCOPE_URL"

[frontends]
    [frontends.cloudbreak-frontend]
    backend = "cloudbreak"
        [frontends.cloudbreak-frontend.routes.frontendrule]
        rule = "PathPrefix:/cb/"
        priority = 100
    [frontends.datalake-frontend]
    backend = "datalake"
        [frontends.datalake-frontend.routes.frontendrule]
        rule = "PathPrefix:/dl/"
        priority = 100
    [frontends.periscope-frontend]
    backend = "periscope"
        [frontends.periscope-frontend.routes.frontendrule]
        rule = "PathPrefix:/as/"
        priority = 100
EOF
    else
        echo "" > traefik.toml
    fi
}

generate-uaa-check-diff() {
    local verbose="$1"

    if [ -f uaa.yml ]; then
        local uaa_delme_path=$TEMP_DIR/uaa-delme.yml
        generate-uaa-config-force $uaa_delme_path
        if diff $uaa_delme_path uaa.yml &> /dev/null; then
            debug "uaa.yml exists and generate wouldn't change it"
            return 0
        else
            if ! [[ "$regeneteInProgress" ]]; then
                warn "uaa.yml already exists, BUT generate would create a DIFFERENT one!"
                warn "please regenerate it:"
                echo "  cbd regenerate" | blue
            fi

            if [[ "$verbose" ]]; then
                warn "expected change:"
                diff $uaa_delme_path uaa.yml || true
            else
                debug "expected change:"
                (diff $uaa_delme_path uaa.yml || true) | debug-cat
            fi
            return 1
        fi
    else
        generate-uaa-config-force uaa.yml
    fi
    return 0

}

generate-uaa-config() {
    cloudbreak-config

    if ! generate-uaa-check-diff; then
        if [[ "$CBD_FORCE_START" ]]; then
            warn "You have forced to start ..."
        else
            warn "Please check the expected config changes with:"
            echo "  cbd doctor" | blue
            debug "If you want to ignore the changes, set the CBD_FORCE_START to true in Profile"
            _exit 1
        fi
    else
        info "generating uaa.yml"
        if [ -f "$UAA_SETTINGS_FILE" ]; then
            info "apply custom uaa settings from file: $UAA_SETTINGS_FILE"
        fi
        generate-uaa-config-force uaa.yml
    fi
}

generate-uaa-config-force() {
    declare uaaFile=${1:? required: uaa config file path}

    debug "Generating Identity server config: ${uaaFile} ..."

    cat > ${uaaFile} << EOF
spring_profiles: postgresql

database:
  driverClassName: org.postgresql.Driver
  url: jdbc:postgresql://\${IDENTITY_DB_URL}/\${IDENTITY_DB_NAME}
  username: \${IDENTITY_DB_USER}
  password: \${IDENTITY_DB_PASS}
  maxactive: 200

zones:
 internal:
   hostnames:
     - ${PUBLIC_IP}
     - node1.node.dc1.consul
     - identity

oauth:
  client:
    override: true
    autoapprove:
      - ${UAA_CLOUDBREAK_SHELL_ID}
  clients:
    ${UAA_ULUWATU_ID}:
      id: ${UAA_ULUWATU_ID}
      secret: '$(escape-string-yaml $UAA_ULUWATU_SECRET \')'
      authorized-grant-types: authorization_code,client_credentials
      scope: cloudbreak.blueprints,cloudbreak.credentials,cloudbreak.stacks,cloudbreak.templates,cloudbreak.networks,cloudbreak.securitygroups,openid,cloudbreak.usages.global,cloudbreak.usages.account,cloudbreak.usages.user,cloudbreak.events,periscope.cluster,cloudbreak.recipes,cloudbreak.blueprints.read,cloudbreak.templates.read,cloudbreak.credentials.read,cloudbreak.recipes.read,cloudbreak.networks.read,cloudbreak.securitygroups.read,cloudbreak.stacks.read,cloudbreak.sssdconfigs,cloudbreak.sssdconfigs.read,cloudbreak.platforms,cloudbreak.platforms.read
      authorities: cloudbreak.subscribe
      redirect-uri: ${ULU_OAUTH_REDIRECT_URI}
    ${UAA_CLOUDBREAK_ID}:
      id: ${UAA_CLOUDBREAK_ID}
      secret: '$(escape-string-yaml $UAA_CLOUDBREAK_SECRET \')'
      authorized-grant-types: client_credentials
      scope: scim.read
      authorities: uaa.resource,scim.read
    ${UAA_PERISCOPE_ID}:
      id: ${UAA_PERISCOPE_ID}
      secret: '$(escape-string-yaml $UAA_PERISCOPE_SECRET \')'
      authorized-grant-types: client_credentials
      scope: none
      authorities: cloudbreak.autoscale,uaa.resource,scim.read
    ${UAA_CLOUDBREAK_SHELL_ID}:
      id: ${UAA_CLOUDBREAK_SHELL_ID}
      authorized-grant-types: implicit
      scope: cloudbreak.networks,cloudbreak.securitygroups,cloudbreak.templates,cloudbreak.blueprints,cloudbreak.credentials,cloudbreak.stacks,cloudbreak.events,cloudbreak.usages.global,cloudbreak.usages.account,cloudbreak.usages.user,cloudbreak.recipes,openid,cloudbreak.blueprints.read,cloudbreak.templates.read,cloudbreak.credentials.read,cloudbreak.recipes.read,cloudbreak.networks.read,cloudbreak.securitygroups.read,cloudbreak.stacks.read,cloudbreak.sssdconfigs,cloudbreak.sssdconfigs.read,cloudbreak.platforms,cloudbreak.platforms.read,periscope.cluster
      authorities: uaa.none
      redirect-uri: http://cloudbreak.shell
EOF

    if [ -f "$UAA_SETTINGS_FILE" ]; then
        yq m -i -x ${uaaFile} ${UAA_SETTINGS_FILE}
    fi
}

util-token() {
    declare desc="Generates an OAuth token with CloudbreakShell scopes"

    cloudbreak-config

    if [ $# -ne 2 ]; then
        error "Invalid parameters, please provide username tenant like this: cbd util token admin@hortonworks.com hortonworks"
    else
        local username=$1
        local tenant=$2
        local TOKEN=$(curl -skX GET \
        "https://${PUBLIC_IP}/oidc/authorize?tenant=$tenant&username=$username")
        echo ${TOKEN#*=}
    fi
}

util-token-debug() {
    declare desc="Opens the browse jwt.io to inspect a newly generated Oauth token."

    local token="$(util-token)"
    open "http://jwt.io/?value=$token"
}

util-local-dev() {
    declare desc="Stops cloudbreak and periscope container, and starts an ambassador for cbreak and periscope in IntelliJ (def cb: port:9090, peri: port: 8085)"
    declare port=${1:-9091}

    cloudbreak-config

    debug stopping original cloudbreak container
    dockerCompose stop --timeout ${DOCKER_STOP_TIMEOUT} cloudbreak 2> /dev/null || :
    dockerCompose stop --timeout ${DOCKER_STOP_TIMEOUT} periscope 2> /dev/null || :
    dockerCompose stop --timeout ${DOCKER_STOP_TIMEOUT} datalake 2> /dev/null || :
}
