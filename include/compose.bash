compose-init() {
    if (docker-compose --version 2>&1| grep -q 1.2.0); then
        echo "* removing old docker-compose binary" | yellow
        rm -f .deps/bin/docker-compose
    fi
    deps-require docker-compose 1.23.2
    env-import CB_COMPOSE_PROJECT cbreak
    env-import COMPOSE_HTTP_TIMEOUT 120
    env-import DOCKER_STOP_TIMEOUT 60
    env-import ULUWATU_VOLUME_HOST /dev/null
    env-import CAAS_MOCK_VOLUME_HOST /dev/null
    env-import CAAS_MOCK_CONTAINER_PATH /mock-caas.jar

    if [[ "$ULUWATU_VOLUME_HOST" != "/dev/null" ]]; then
      ULUWATU_VOLUME_CONTAINER=/hortonworks-cloud-web
    else
      ULUWATU_VOLUME_CONTAINER=/tmp/null
    fi

    if [[ "$CAAS_MOCK_VOLUME_HOST" != "/dev/null" ]]; then
      CAAS_MOCK_VOLUME_CONTAINER=${CAAS_MOCK_CONTAINER_PATH}
    else
      CAAS_MOCK_VOLUME_CONTAINER=/tmp/null
    fi
}

dockerCompose() {
    debug "docker-compose -p ${CB_COMPOSE_PROJECT} $@"
    docker-compose -p ${CB_COMPOSE_PROJECT} "$@"
}

compose-ps() {
    declare desc="docker-compose: List containers"

    dockerCompose ps
}

compose-pull() {
    declare desc="Pulls service images"
    cloudbreak-conf-tags

    [ -f docker-compose.yml ] || deployer-generate

    dockerCompose pull
}

compose-pull-parallel() {
    declare desc="Pulls service images parallel"
    cloudbreak-conf-tags

    [ -f docker-compose.yml ] || deployer-generate
    sed -n "s/.*image://p" docker-compose.yml|sort -u|xargs -n1 -P 20 docker pull
}

compose-up() {
    dockerCompose up -d "$@"
}

compose-kill() {
    declare desc="Kills and removes all cloudbreak related container"

    dockerCompose stop --timeout ${DOCKER_STOP_TIMEOUT}
    dockerCompose rm -f

    docker rm -f cloudbreak-proxy 2> /dev/null || :
    docker rm -f periscope-proxy 2> /dev/null || :
    docker rm -f datalake-proxy 2> /dev/null || :
}

util-cleanup() {
    declare desc="Removes all exited containers and old cloudbreak related images"

    if [ ! -f docker-compose.yml ]; then
      error "docker-compose.yml file does not exists"
      _exit 126
    fi

    compose-remove-exited-containers

    local all_images=$(docker images | grep -v "<none>"| sed "s/ \+/ /g"|cut -d' ' -f 1,2|tr ' ' : | tail -n +2)
    local keep_images=$(sed -n "s/.*image://p" docker-compose.yml)
    local images_to_delete=$(compose-get-old-images <(echo $all_images) <(echo $keep_images))
    if [ -n "$images_to_delete" ]; then
      info "Found old/different versioned images based on docker-compose.yml file: $images_to_delete"
      docker rmi $images_to_delete
    else
      info "Not found any different versioned images (based on docker-compose.yml). Skip cleanup"
    fi
}

compose-get-old-images() {
    declare desc="Retrieve old images"
    declare all_images="${1:? required: all images}"
    declare keep_images="${2:? required: keep images}"
    local all_imgs=$(cat $all_images) keep_imgs=$(cat $keep_images)
    contentsarray=()
    for versionedImage in $keep_imgs
      do
        image_name="${versionedImage%:*}"
        image_version="${versionedImage#*:}"
        remove_images=$(echo $all_imgs | tr ' ' "\n" | grep "$image_name:" | grep -v "$image_version")
        if [ -n "$remove_images" ]; then
          contentsarray+="${remove_images[@]} "
        fi
    done
    echo ${contentsarray%?}
}

compose-remove-exited-containers() {
    declare desc="Remove exited containers"
    local exited_containers=$(docker ps --all -q -f status=exited)
    if [ -n "$exited_containers" ]; then
      info "Remove exited docker containers"
      docker rm $exited_containers;
    fi
}

compose-get-container() {
    declare desc=""
    declare service="${1:? required: service name}"
    dockerCompose ps -q "${service}"
}

compose-logs() {
    declare desc='Follow all logs. Starts from begining. Separate service names by space to filter, e.g. "cbd logs cloudbreak uluwatu"'

    disable_cbd_output_copy_to_log

    dockerCompose logs -f "$@"
}

compose-logs-tail() {
    declare desc='Same as "logs" but doesnt includes previous messages'

    disable_cbd_output_copy_to_log

    dockerCompose logs -f --tail=1 "$@"
}

compose-generate-check-diff() {
    cloudbreak-config
    setup_proxy_environments
    local verbose="$1"

    if [ -f docker-compose.yml ]; then
        local compose_delme_path=$TEMP_DIR/docker-compose-delme.yml
         compose-generate-yaml-force $compose_delme_path
         if diff $compose_delme_path docker-compose.yml &>/dev/null; then
             debug "docker-compose.yml already exist, and generate wouldn't change it."
             return 0
        else
            if ! [[ "$regeneteInProgress" ]]; then
                warn "docker-compose.yml already exists, BUT generate would create a DIFFERENT one!"
                warn "please regenerate it:"
                echo "  cbd regenerate" | blue
            fi
            if [[ "$verbose" ]]; then
                warn "expected change:"
                diff $compose_delme_path docker-compose.yml || true
            else
                debug "expected change:"
                (diff $compose_delme_path docker-compose.yml || true) | debug-cat
            fi

            if [[ !"$CBD_FORCE_START" ]]; then
                return 1
            fi
        fi
    fi
    return 0
}

compose-generate-yaml() {
    declare desc="Generating docker-compose.yml based on Profile settings"

    cloudbreak-config
    setup_proxy_environments

    if ! compose-generate-check-diff; then
        if [[ "$CBD_FORCE_START" ]]; then
            warn "You have forced to start ..."
        else
            warn "Please check the expected config changes with:"
            echo "  cbd doctor" | blue
            debug "If you want to ignore the changes, set the CBD_FORCE_START to true in Profile"
            _exit 1
        fi
    else
        info "generating docker-compose.yml"
        compose-generate-yaml-force docker-compose.yml
        docker-compose -f docker-compose.yml config 1> /dev/null
    fi
}

escape-string-compose-yaml() {
    declare desc="Escape compose yaml string by delimiter type"
    : ${2:=required}
    local in=$1
    local delimiter=$2

    if [[ $delimiter == "'" ]]; then
        out=`echo $in | sed -e "s/'/''/g" -e 's/[$]/$$/g'`
    elif [[ $delimiter == '"' ]]; then
		out=`echo $in | sed -e 's/\\\\/\\\\\\\/g' -e 's/"/\\\"/g' -e 's/[$]/$$/g'`
    else
        out="$in"
    fi

    echo $out
}

compose-generate-yaml-force() {
    declare composeFile=${1:? required: compose file path}
    debug "Generating docker-compose yaml: ${composeFile} ..."
    if [[ -z "$AWS_SECRET_ACCESS_KEY" && -n "$AWS_SECRET_KEY"  ]]; then
        debug "AWS_SECRET_ACCESS_KEY is not set, fall back to deprecated AWS_SECRET_KEY"
        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
    fi
    cat > ${composeFile} <<EOF
version: '3'
volumes:
    $COMMON_DB_VOL:
networks:
    $DOCKER_NETWORK_NAME:
        driver: bridge
services:
    traefik:
        ports:
            - "8081:8080"
            - $PUBLIC_HTTP_PORT:80
            - $PUBLIC_HTTPS_PORT:443
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock
            - $CBD_CERT_ROOT_PATH/traefik:/certs/traefik
            - ./logs/traefik:/opt/traefik/log/
            - ./traefik.toml:/etc/traefik/traefik.toml 
        networks:
        - $DOCKER_NETWORK_NAME
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        image: traefik:$DOCKER_TAG_TRAEFIK
        restart: on-failure
        command: --debug --api --rest --ping --metrics --InsecureSkipVerify=true \
            --defaultEntryPoints=http,https \
            --entryPoints='Name:http Address::80 Redirect.EntryPoint:https' \
            --entryPoints='Name:https Address::443 TLS:$CBD_TRAEFIK_TLS' \
            --maxidleconnsperhost=$TRAEFIK_MAX_IDLE_CONNECTION \
            --traefiklog.filepath=/opt/traefik/log/traefik.log \
            --accessLog.filePath=/opt/traefik/log/access.log \
            --docker

    caas-mock:
        image: $DOCKER_IMAGE_CAAS_MOCK:$DOCKER_TAG_CAAS_MOCK
        restart: on-failure
        volumes:
        - $CAAS_MOCK_VOLUME_HOST:$CAAS_MOCK_VOLUME_CONTAINER
        networks:
        - $DOCKER_NETWORK_NAME
        ports: 
        - "$CAAS_MOCK_BIND_PORT:8080"
        labels:
        - traefik.frontend.rule=PathPrefix:/auth,/oidc,/idp,/caas
        - traefik.port=8080
        - traefik.backend=caas-backend
        - traefik.frontend.priority=100
      
    haveged:
        labels:
        - traefik.enable=false
        privileged: true
        networks:
        - $DOCKER_NETWORK_NAME
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        image: hortonworks/haveged:$DOCKER_TAG_HAVEGED

    logsink:
        labels:
        - traefik.enable=false
        ports:
            - 3333
        volumes:
            - ./logs:/tmp
        networks:
        - $DOCKER_NETWORK_NAME
        image: hortonworks/socat:1.0.0
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        command: socat -u TCP-LISTEN:3333,reuseaddr,fork OPEN:/tmp/cbreak.log,creat,append

    logspout:
        labels:
        - traefik.enable=false
        ports:
            - 8000:80
        environment:
            - DEBUG=true
            - LOGSPOUT=ignore
            - "RAW_FORMAT={{.Container.Name}} | {{.Data}}\n"
        volumes:
        - /var/run/docker.sock:/var/run/docker.sock
        networks:
        - $DOCKER_NETWORK_NAME
        entrypoint: ["/bin/sh"]
        command: -c 'sleep 1; (ROUTE_URIS=\$\$LOGSINK_PORT_3333_TCP /bin/logspout) & LSPID=\$\$!; trap "kill \$\$LSPID; wait \$\$LSPID" SIGINT SIGTERM; wait \$\$LSPID'
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        image: hortonworks/logspout:v3.2.2

    logrotate:
        environment:
            - "CRON_EXPR=0 * * * *"
            - "LOGROTATE_LOGFILES=/var/log/cloudbreak-deployer/*.log /var/log/cloudbreak-deployer/*/*.log"
            - LOGROTATE_FILESIZE=10M
        volumes:
            - ./logs:/var/log/cloudbreak-deployer
        networks:
        - $DOCKER_NETWORK_NAME
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        image: hortonworks/logrotate:$DOCKER_TAG_LOGROTATE

    $COMMON_DB:
        labels:
        - traefik.enable=false
        privileged: true
        ports:
            - "5432:5432"
        volumes:
            - "$COMMON_DB_VOL:/var/lib/postgresql/data"
        networks:
        - $DOCKER_NETWORK_NAME
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        image: postgres:$DOCKER_TAG_POSTGRES
        entrypoint: ["/bin/bash"]
        command: -c 'cd /var/lib/postgresql; touch .ash_history .psql_history; chown -R postgres:postgres /var/lib/postgresql; (/docker-entrypoint.sh postgres -c max_connections=300) & PGPID="\$\$!"; echo "PGPID \$\$PGPID"; trap "kill \$\$PGPID; wait \$\$PGPID" SIGINT SIGTERM; cd /var/lib/postgresql; (tail -f .*history) & wait "\$\$PGPID"'

    vault:
        labels:
        - traefik.port=8200
        - traefik.frontend.rule=PathPrefixStrip:/vault
        - traefik.backend=vault
        - traefik.frontend.priority=100
        ports:
        - $VAULT_BIND_PORT:8200
        environment:
        - SKIP_SETCAP=true
        volumes:
        - ./$VAULT_CONFIG_FILE:/vault/config/$VAULT_CONFIG_FILE
        networks:
        - $DOCKER_NETWORK_NAME
        image: $VAULT_DOCKER_IMAGE:$VAULT_DOCKER_IMAGE_TAG
        restart: on-failure
        command: server

    identity:
        labels:
        - traefik.port=8080
        - traefik.frontend.rule=PathPrefix:/identity/check_token,/identity/oauth,/identity/Users,/identity/login.do,/identity/Groups;PathPrefixStrip:/identity
        - traefik.backend=identity-backend
        - traefik.frontend.priority=100
        ports:
            - $UAA_PORT:8080
        environment:
            - http_proxy=$HTTP_PROXY
            - https_proxy=$HTTPS_PROXY
            - IDENTITY_DB_URL
            - IDENTITY_DB_NAME
            - IDENTITY_DB_USER
            - IDENTITY_DB_PASS
        volumes:
        - ./uaa.yml:/uaa/uaa.yml
        - ./logs/identity:/tomcat/logs/
        networks:
        - $DOCKER_NETWORK_NAME
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        image: hortonworks/cloudbreak-uaa:$DOCKER_TAG_UAA

    uluwatu:
        environment:
            - http_proxy=$HTTP_PROXY
            - https_proxy=$HTTPS_PROXY
            - ULU_OAUTH_REDIRECT_URI
            - ULU_OAUTH_CLIENT_ID=$UAA_ULUWATU_ID
            - 'ULU_OAUTH_CLIENT_SECRET=$(escape-string-compose-yaml $UAA_ULUWATU_SECRET \')'
            - ULU_HOST_ADDRESS
            - NODE_TLS_REJECT_UNAUTHORIZED=$ULU_NODE_TLS_REJECT_UNAUTHORIZED
            - ULU_HWX_CLOUD_DEFAULT_ARM_VIRTUAL_NETWORK_ID
            - ULU_ADDRESS_RESOLVING_TIMEOUT
            - "ULU_IDENTITY_ADDRESS=http://identity:8080"
            - "ULU_CLOUDBREAK_ADDRESS=$CLOUDBREAK_URL"
            - "ULU_PERISCOPE_ADDRESS=$PERISCOPE_URL"
            - ULU_SUBSCRIBE_TO_NOTIFICATIONS
            - AWS_INSTANCE_ID
            - AWS_ACCOUNT_ID
            - AWS_AMI_ID
            - AZURE_TENANT_ID
            - AZURE_SUBSCRIPTION_ID
            - AWS_ACCESS_KEY_ID
            - AWS_SECRET_ACCESS_KEY
            - CAAS_ENABLED=true
        labels:
        - traefik.frontend.rule=PathPrefix:/
        - traefik.port=3000
        - traefik.backend=uluwatu-backend
        - traefik.frontend.priority=5
        ports:
            - 3000:3000
        volumes:
            - $ULUWATU_VOLUME_HOST:$ULUWATU_VOLUME_CONTAINER
        networks:
        - $DOCKER_NETWORK_NAME
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        image: $DOCKER_IMAGE_CLOUDBREAK_WEB:$DOCKER_TAG_ULUWATU

EOF

    if [[ "$CB_LOCAL_DEV" == "false" ]]; then
        cat >> ${composeFile} <<EOF
    cloudbreak:
        environment:
            - AWS_ACCESS_KEY_ID
            - AWS_SECRET_ACCESS_KEY
            - AWS_GOV_ACCESS_KEY_ID
            - AWS_GOV_SECRET_ACCESS_KEY
            - "http_proxy=$HTTP_PROXY"
            - "https_proxy=$HTTPS_PROXY"
            - 'CB_JAVA_OPTS=$(escape-string-compose-yaml "$CB_JAVA_OPTS" \')'
            - "HTTPS_PROXYFORCLUSTERCONNECTION=$HTTPS_PROXYFORCLUSTERCONNECTION"
            - "CB_CLIENT_ID=$UAA_CLOUDBREAK_ID"
            - 'CB_CLIENT_SECRET=$(escape-string-compose-yaml $UAA_CLOUDBREAK_SECRET \')'
            - CB_CLUSTERDEFINITION_AMBARI_DEFAULTS
            - CB_CLUSTERDEFINITION_AMBARI_INTERNAL
            - CB_TEMPLATE_DEFAULTS
            - CB_HBM2DDL_STRATEGY
            - CB_CAPABILITIES
            $( if [[ -n "$INFO_APP_CAPABILITIES" ]]; then echo "- INFO_APP_CAPABILITIES"; fi )
            - "ENDPOINTS_AUTOCONFIG_ENABLED=false"
            - "ENDPOINTS_DUMP_ENABLED=false"
            - "ENDPOINTS_TRACE_ENABLED=false"
            - "ENDPOINTS_CONFIGPROPS_ENABLED=false"
            - "ENDPOINTS_METRICS_ENABLED=false"
            - "ENDPOINTS_MAPPINGS_ENABLED=false"
            - "ENDPOINTS_BEANS_ENABLED=false"
            - "ENDPOINTS_ENV_ENABLED=false"
            - "CB_ADDRESS_RESOLVING_TIMEOUT"
            - "CB_IDENTITY_SERVER_URL=http://identity:8080"
            - "CB_DB_PORT_5432_TCP_ADDR=$COMMON_DB"
            - "CB_DB_PORT_5432_TCP_PORT=5432"
            - CB_DB_ENV_USER
            - CB_DB_ENV_PASS
            - CB_DB_ENV_DB
            - CB_DB_ENV_SCHEMA
            - CB_SCHEMA_SCRIPTS_LOCATION
            - CB_SCHEMA_MIGRATION_AUTO
            - CB_AWS_HOSTKEY_VERIFY
            - CB_GCP_HOSTKEY_VERIFY
            - REST_DEBUG
            - CB_AWS_DEFAULT_CF_TAG
            - CB_AWS_CUSTOM_CF_TAGS
            - CERT_VALIDATION
            - CB_HOST_DISCOVERY_CUSTOM_DOMAIN
            - CB_SMARTSENSE_CONFIGURE
            - CB_SMARTSENSE_ID
            - CB_PLATFORM_DEFAULT_REGIONS
            - CB_DEFAULT_SUBSCRIPTION_ADDRESS
            $( if [[ -n "$CB_IMAGE_CATALOG_URL" ]]; then echo "- CB_IMAGE_CATALOG_URL"; fi )
            - CB_AWS_VPC
            - CB_ENABLEDPLATFORMS
            - CB_ENABLED_LINUX_TYPES
            - CB_MAX_SALT_NEW_SERVICE_RETRY
            - CB_MAX_SALT_NEW_SERVICE_RETRY_ONERROR
            - CB_MAX_SALT_RECIPE_EXECUTION_RETRY
            - CB_INSTANCE_UUID
            - CB_INSTANCE_NODE_ID
            - CB_INSTANCE_PROVIDER
            - CB_INSTANCE_REGION
            - CB_PRODUCT_ID
            - CB_COMPONENT_ID
            - CB_COMPONENT_CREATED
            - CB_COMPONENT_CLUSTER_ID
            - CB_LOG_LEVEL
            - CB_DEFAULT_GATEWAY_CIDR
            $( if [[ "$CB_AUDIT_FILE_ENABLED" = true ]]; then echo "- CB_AUDIT_FILEPATH=/cloudbreak-log/cb-audit.log"; fi )
            $( if [[ -n "$CB_KAFKA_BOOTSTRAP_SERVERS" ]]; then echo "- CB_KAFKA_BOOTSTRAP_SERVERS"; fi )
            - CB_DISABLE_SHOW_CLI
            - CB_DISABLE_SHOW_CLUSTERDEFINITION
            - SMARTSENSE_UPLOAD_HOST
            - SMARTSENSE_UPLOAD_USERNAME
            - SMARTSENSE_UPLOAD_PASSWORD
            - CB_AWS_ACCOUNT_ID
            - VAULT_ADDR=vault
            - VAULT_PORT=$VAULT_BIND_PORT
            - VAULT_ROOT_TOKEN=$VAULT_ROOT_TOKEN
            - "CAAS_URL=$CAAS_URL"
        labels:
        - traefik.port=8080
        - traefik.frontend.rule=PathPrefix:/cb/
        - traefik.backend=cloudbreak-backend
        - traefik.frontend.priority=10
        ports:
            - $CB_PORT:8080
        volumes:
            - "$CBD_CERT_ROOT_PATH:/certs"
            - /dev/urandom:/dev/random
            - ./logs/cloudbreak:/cloudbreak-log
            - ./etc/:/etc/cloudbreak
        networks:
        - $DOCKER_NETWORK_NAME
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        image: $DOCKER_IMAGE_CLOUDBREAK:$DOCKER_TAG_CLOUDBREAK
        command: bash

    datalake:
        environment:
            - http_proxy=$HTTP_PROXY
            - https_proxy=$HTTPS_PROXY
            - CERT_VALIDATION
            - REST_DEBUG
            - 'DATALAKE_JAVA_OPTS=$(escape-string-compose-yaml "$DATALAKE_JAVA_OPTS" \')'
            - DATALAKE_HBM2DDL_STRATEGY
            - "DATALAKE_DB_PORT_5432_TCP_ADDR=$COMMON_DB"
            - "DATALAKE_DB_PORT_5432_TCP_PORT=5432"
            - DATALAKE_DB_ENV_USER
            - DATALAKE_DB_ENV_PASS
            - DATALAKE_DB_ENV_DB
            - DATALAKE_DB_ENV_SCHEMA
            - DATALAKE_CLIENT_ID=$UAA_DATALAKE_ID
            - DATALAKE_HOSTNAME_RESOLUTION=public
            - DATALAKE_ADDRESS_RESOLVING_TIMEOUT
            - "DATALAKE_CLOUDBREAK_URL=$CLOUDBREAK_URL"
            - DATALAKE_SCHEMA_SCRIPTS_LOCATION
            - DATALAKE_SCHEMA_MIGRATION_AUTO
            - DATALAKE_INSTANCE_NODE_ID=$CB_INSTANCE_NODE_ID
            - DATALAKE_LOG_LEVEL
        labels:
            - traefik.port=8080
            - traefik.frontend.rule=PathPrefix:/dl/
            - traefik.backend=datalake-backend
            - traefik.frontend.priority=10
        ports:
            - 8086:8080
        volumes:
            - "$CBD_CERT_ROOT_PATH:/certs"
            - /dev/urandom:/dev/random
            - ./logs/datalake:/datalake-log
            - ./etc/:/etc/datalake
        networks:
        - $DOCKER_NETWORK_NAME
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        image: $DOCKER_IMAGE_CLOUDBREAK_DATALAKE:$DOCKER_TAG_DATALAKE
        command: bash
        
    periscope:
        environment:
            - http_proxy=$HTTP_PROXY
            - https_proxy=$HTTPS_PROXY
            - PERISCOPE_HBM2DDL_STRATEGY
            - "PERISCOPE_DB_PORT_5432_TCP_ADDR=$COMMON_DB"
            - "PERISCOPE_DB_PORT_5432_TCP_PORT=5432"
            - PERISCOPE_DB_ENV_USER
            - PERISCOPE_DB_ENV_PASS
            - PERISCOPE_DB_ENV_DB
            - PERISCOPE_DB_ENV_SCHEMA
            - "HTTPS_PROXYFORCLUSTERCONNECTION=$HTTPS_PROXYFORCLUSTERCONNECTION"
            - 'CB_JAVA_OPTS=$(escape-string-compose-yaml "$CB_JAVA_OPTS" \')'
            - PERISCOPE_CLIENT_ID=$UAA_PERISCOPE_ID
            - 'PERISCOPE_CLIENT_SECRET=$(escape-string-compose-yaml $UAA_PERISCOPE_SECRET \')'
            - PERISCOPE_HOSTNAME_RESOLUTION=public
            - ENDPOINTS_AUTOCONFIG_ENABLED=false
            - ENDPOINTS_DUMP_ENABLED=false
            - ENDPOINTS_TRACE_ENABLED=false
            - ENDPOINTS_CONFIGPROPS_ENABLED=false
            - ENDPOINTS_METRICS_ENABLED=false
            - ENDPOINTS_MAPPINGS_ENABLED=false
            - ENDPOINTS_BEANS_ENABLED=false
            - ENDPOINTS_ENV_ENABLED=false
            - PERISCOPE_ADDRESS_RESOLVING_TIMEOUT
            - "PERISCOPE_CLOUDBREAK_URL=$CLOUDBREAK_URL"
            - PERISCOPE_IDENTITY_SERVER_URL=http://identity:8080
            - PERISCOPE_SCHEMA_SCRIPTS_LOCATION
            - PERISCOPE_SCHEMA_MIGRATION_AUTO
            - PERISCOPE_INSTANCE_NODE_ID=$CB_INSTANCE_NODE_ID
            - PERISCOPE_LOG_LEVEL
            - REST_DEBUG
            - CERT_VALIDATION
            - CB_DEFAULT_SUBSCRIPTION_ADDRESS
            - VAULT_ADDR=vault
            - VAULT_PORT=$VAULT_BIND_PORT
            - VAULT_ROOT_TOKEN=$VAULT_ROOT_TOKEN
            - "CAAS_URL=$CAAS_URL"
        labels:
        - traefik.port=8080
        - traefik.frontend.rule=PathPrefix:/as/
        - traefik.backend=periscope-backend
        - traefik.frontend.priority=10
        ports:
            - 8085:8080
        volumes:
            - "$CBD_CERT_ROOT_PATH:/certs"
            - ./logs/autoscale:/autoscale-log
            - /dev/urandom:/dev/random
        networks:
        - $DOCKER_NETWORK_NAME
        logging:
            options:
                max-size: "10M"
                max-file: "5"
        image: $DOCKER_IMAGE_CLOUDBREAK_PERISCOPE:$DOCKER_TAG_PERISCOPE
EOF
    fi
}
