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
      env-import ULUWATU_VOLUME_CONTAINER /hortonworks-cloud-web
    else
      env-import ULUWATU_VOLUME_CONTAINER /tmp/null
    fi

    if [[ "$CAAS_MOCK_VOLUME_HOST" != "/dev/null" ]]; then
      env-import CAAS_MOCK_VOLUME_CONTAINER "${CAAS_MOCK_CONTAINER_PATH}"
    else
      env-import CAAS_MOCK_VOLUME_CONTAINER /tmp/null
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

compose-up() {
    if [[ "$FORCE_BUILD" == "true" ]]; then
        dockerCompose up --build -d "$@"
    else
        dockerCompose up -d "$@"
    fi
}

compose-kill() {
    declare desc="Kills and removes all cloudbreak related containers"

    dockerCompose stop --timeout ${DOCKER_STOP_TIMEOUT}
    dockerCompose rm -f

    docker rm -f cbreak_cloudbreak-1 2> /dev/null || :
    docker rm -f cbreak_periscope_1 2> /dev/null || :
    docker rm -f cbreak_datalake_1 2> /dev/null || :
    docker rm -f cbreak_redbeams_1 2> /dev/null || :
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

compose-generate-yaml-force() {
    declare composeFile=${1:? required: compose file path}
    debug "Generating docker-compose yaml: ${composeFile} ..."
    if [[ -z "$AWS_SECRET_ACCESS_KEY" && -n "$AWS_SECRET_KEY"  ]]; then
        debug "AWS_SECRET_ACCESS_KEY is not set, fall back to deprecated AWS_SECRET_KEY"
        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
    fi
    env-export | generate-compose-yaml > ${composeFile}
}
