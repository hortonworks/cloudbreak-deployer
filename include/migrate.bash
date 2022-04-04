
migrate-config() {
    declare desc="Defines env variables for migration"

    env-import DOCKER_TAG_MIGRATION 1.0.0
    env-import CB_SCHEMA_SCRIPTS_LOCATION "container"
    env-import CB_SCHEMA_MIGRATION_AUTO true
    env-import PERISCOPE_SCHEMA_SCRIPTS_LOCATION "container"
    env-import PERISCOPE_SCHEMA_MIGRATION_AUTO true
    env-import DATALAKE_SCHEMA_SCRIPTS_LOCATION "container"
    env-import DATALAKE_SCHEMA_MIGRATION_AUTO true
    env-import REDBEAMS_SCHEMA_SCRIPTS_LOCATION "container"
    env-import REDBEAMS_SCHEMA_MIGRATION_AUTO true
    env-import ENVIRONMENT_SCHEMA_SCRIPTS_LOCATION "container"
    env-import ENVIRONMENT_SCHEMA_MIGRATION_AUTO true
    env-import FREEIPA_SCHEMA_SCRIPTS_LOCATION "container"
    env-import FREEIPA_SCHEMA_MIGRATION_AUTO true
    env-import DB_MIGRATION_LOG "db_migration.log"
    env-import VERBOSE_MIGRATION false
}

create-migrate-log() {
    rm -f ${DB_MIGRATION_LOG}
    touch ${DB_MIGRATION_LOG}
}

migrate-startdb() {
    compose-up --no-recreate $COMMON_DB
}

migrateDebug() {
    declare desc="Prints to migrate log file and to stderr"
    echo "[MIGRATE] $*" | tee -a "$DB_MIGRATION_LOG" | debug-cat
}

migrateError() {
    echo "[ERROR] $*" | tee -a "$DB_MIGRATION_LOG" | red 1>&2
}

migrate-execute-mybatis-migrations() {
    local docker_image_name=$1 && shift
    local service_name=$1 && shift
    local container_name=$(compose-get-container $COMMON_DB)
    migrateDebug "Migration command on $service_name with params: '$*' will be executed on container: $container_name"
    if [[ ! "$container_name" ]]; then
        migrateError "DB container with matching name is not running. Expected name: .*$service_name.*"
        return 1
    fi
    local scripts_location=$1 && shift
    migrateDebug "Scripts location:  $scripts_location"
    if [ "$scripts_location" = "container" ]; then
        migrateDebug "Schema will be extracted from image:  $docker_image_name"
        local scripts_location=$(pwd)/.schema/$service_name
        rm -rf $scripts_location
        mkdir -p $scripts_location
        docker run --label cbreak.sidekick=true --entrypoint bash -v $scripts_location:/migrate/scripts $docker_image_name -c "cp -r /schema/* /migrate/scripts/"
    fi
    local migration_command=$1
    local new_scripts_location=$scripts_location"/app"
    if [[ "$migration_command" = "up" ]]; then
        new_scripts_location=$scripts_location"/mybatis"
    fi
    migrateDebug "Scripts location:  $new_scripts_location"
    local migrateResult=$(docker run \
        --rm \
        --net "$CB_COMPOSE_PROJECT"_"$DOCKER_NETWORK_NAME" \
        -e DB_ENV_POSTGRES_SCHEMA=$service_name \
        -e DB_PORT_5432_TCP_ADDR=$COMMON_DB \
        -e DB_PORT_5432_TCP_PORT=5432 \
        --label cbreak.sidekick=true \
        -v $new_scripts_location:/migrate/scripts \
        docker-private.infra.cloudera.com/cloudera_thirdparty/mybatis/mybatis-migrations:$DOCKER_TAG_MIGRATION "$@" \
      | tee -a "$DB_MIGRATION_LOG")

    if ${VERBOSE_MIGRATION}; then
        warn "$migrateResult";
    fi

    if grep -q "MyBatis Migrations SUCCESS" <<< "${migrateResult}"; then
        info "Migration SUCCESS: $service_name $@"
    else
        error "Migration failed: $service_name $@"
        error "See logs in: $DB_MIGRATION_LOG"
    fi
}

migrate-one-db() {
    local service_name=$1 && shift

    case $service_name in
        cbdb)
            local scripts_location=${CB_SCHEMA_SCRIPTS_LOCATION}
            local docker_image_name=${DOCKER_IMAGE_CLOUDBREAK}:${DOCKER_TAG_CLOUDBREAK}
            ;;
        periscopedb)
            local scripts_location=${PERISCOPE_SCHEMA_SCRIPTS_LOCATION}
            local docker_image_name=${DOCKER_IMAGE_CLOUDBREAK_PERISCOPE}:${DOCKER_TAG_PERISCOPE}
            ;;
        datalakedb)
            local scripts_location=${DATALAKE_SCHEMA_SCRIPTS_LOCATION}
            local docker_image_name=${DOCKER_IMAGE_CLOUDBREAK_DATALAKE}:${DOCKER_TAG_DATALAKE}
            ;;
        redbeamsdb)
            local scripts_location=${REDBEAMS_SCHEMA_SCRIPTS_LOCATION}
            local docker_image_name=${DOCKER_IMAGE_CLOUDBREAK_REDBEAMS}:${DOCKER_TAG_REDBEAMS}
            ;;
        environmentdb)
            local scripts_location=${ENVIRONMENT_SCHEMA_SCRIPTS_LOCATION}
            local docker_image_name=${DOCKER_IMAGE_CLOUDBREAK_ENVIRONMENT}:${DOCKER_TAG_ENVIRONMENT}
            ;;
        freeipadb)
            local scripts_location=${FREEIPA_SCHEMA_SCRIPTS_LOCATION}
            local docker_image_name=${DOCKER_IMAGE_CLOUDBREAK_FREEIPA}:${DOCKER_TAG_FREEIPA}
            ;;
        consumptiondb)
            local scripts_location=${CONSUMPTION_SCHEMA_SCRIPTS_LOCATION}
            local docker_image_name=${DOCKER_IMAGE_CLOUDBREAK_CONSUMPTION}:${DOCKER_TAG_CONSUMPTION}
            ;;
        *)
            migrateError "Invalid database service name: $service_name. Supported databases: cbdb, periscopedb, datalakedb, redbeamsdb, environmentdb and freeipadb"
            return 1
            ;;
    esac

    migrateDebug "Script location: $scripts_location"
    migrateDebug "Docker image name: $docker_image_name"
    migrate-execute-mybatis-migrations $docker_image_name $service_name $scripts_location "$@"
}

execute-migration() {
    if [ $# -eq 0 ]; then
        migrate-one-db cbdb up
        migrate-one-db cbdb pending
        migrate-one-db periscopedb up
        migrate-one-db periscopedb pending
        migrate-one-db datalakedb up
        migrate-one-db datalakedb pending
        migrate-one-db redbeamsdb up
        migrate-one-db redbeamsdb pending
        migrate-one-db environmentdb up
        migrate-one-db environmentdb pending
        migrate-one-db freeipadb up
        migrate-one-db freeipadb pending
        migrate-one-db consumptiondb up
        migrate-one-db consumptiondb pending
    else
        if [[ "$2" == "new" ]]; then
            case $1 in
                cbdb)
                    if [[ "$CB_SCHEMA_SCRIPTS_LOCATION" == "container" && "$CB_LOCAL_DEV_LIST" == *"cloudbreak"* ]]; then
                        migrateError "CB_SCHEMA_SCRIPTS_LOCATION environment variable must be set and pointing to the cloudbreak project's schema location"
                        _exit 127
                    fi
                    ;;
                periscopedb)
                    if [[ "$PERISCOPE_SCHEMA_SCRIPTS_LOCATION" == "container" && "$CB_LOCAL_DEV_LIST" == *"periscope"* ]]; then
                        migrateError "PERISCOPE_SCHEMA_SCRIPTS_LOCATION environment variable must be set and pointing to the autoscale project's schema location"
                        _exit 127
                    fi
                    ;;
                datalakedb)
                    if [[ "$DATALAKE_SCHEMA_SCRIPTS_LOCATION" == "container" && "$CB_LOCAL_DEV_LIST" == *"datalake"* ]]; then
                        migrateError "DATALAKE_SCHEMA_SCRIPTS_LOCATION environment variable must be set and pointing to the datalake project's schema location"
                        _exit 127
                    fi
                    ;;
                redbeamsdb)
                    if [[ "$REDBEAMS_SCHEMA_SCRIPTS_LOCATION" == "container" && "$CB_LOCAL_DEV_LIST" == *"redbeams"* ]]; then
                        migrateError "REDBEAMS_SCHEMA_SCRIPTS_LOCATION environment variable must be set and pointing to the redbeams project's schema location"
                        _exit 127
                    fi
                    ;;
                environmentdb)
                    if [[ "$ENVIRONMENT_SCHEMA_SCRIPTS_LOCATION" == "container" && "$CB_LOCAL_DEV_LIST" == *"environment"* ]]; then
                        migrateError "ENVIRONMENT_SCHEMA_SCRIPTS_LOCATION environment variable must be set and points to the autoscale project's schema location"
                        _exit 127
                    fi
                    ;;
                freeipadb)
                    if [[ "$FREEIPA_SCHEMA_SCRIPTS_LOCATION" == "container" && "$CB_LOCAL_DEV_LIST" == *"freeipa"* ]]; then
                        migrateError "FREEIPA_SCHEMA_SCRIPTS_LOCATION environment variable must be set and pointing to the freeipa project's schema location"
                        _exit 127
                    fi
                    ;;
                consumptiondb)
                    if [[ "$CONSUMPTION_SCHEMA_SCRIPTS_LOCATION" == "container" && "$CB_LOCAL_DEV_LIST" == *"consumption"* ]]; then
                        migrateError "CONSUMPTION_SCHEMA_SCRIPTS_LOCATION environment variable must be set and pointing to the freeipa project's schema location"
                        _exit 127
                    fi
                    ;;
                *)
                    migrateError "Invalid database service name: $1. Supported databases: cbdb, periscopedb, datalakedb, redbeamsdb, environmentdb, freeipadb and consumptiondb"
                    return 1
                    ;;
            esac
        fi

        VERBOSE_MIGRATION=true
        migrate-one-db "$@"
    fi
}

migrate() {
    create-migrate-log
    migrate-startdb
    execute-migration
    if grep "MyBatis Migrations FAILURE" "$DB_MIGRATION_LOG" ; then
        error "Migration is failed, please check the log: $DB_MIGRATION_LOG"
        _exit 127
    fi
}

migrate-startdb-cmd() {
    declare desc="Starts the DB containers"

    deployer-generate
    migrate-startdb
}

migrate-cmd() {
    declare desc="Executes the db migration"
    debug "migrate-cmd"

    cloudbreak-config
    migrate-config
    migrate-startdb
    compose-generate-yaml
    execute-migration "$@"
}
