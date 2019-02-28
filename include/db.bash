db-config() {
    cloudbreak-conf-tags
    cloudbreak-conf-db
    migrate-config
}

db-dump() {
    declare desc="Dumping the specified database"
    declare dbName=${1:-all}

    db-config

    if docker inspect cbreak_${COMMON_DB}_1 &> /dev/null; then
        migrate-startdb
        db-wait-for-db-cont cbreak_${COMMON_DB}_1
    fi

    if [ "$dbName" = "all" ]; then
        for db in $CB_DB_ENV_DB $IDENTITY_DB_NAME $PERISCOPE_DB_ENV_DB $VAULT_DB_SCHEMA $DATALAKE_DB_ENV_DB; do
            db-dump-database $db
        done
    else
        db-dump-database $dbName
    fi
}

db-dump-database() {
    declare dbName=${1:? required: dbName}
    declare desc="Creates an sql dump from the database: $dbName"
    info $desc

    if docker exec cbreak_${COMMON_DB}_1 psql -U postgres -c "\c $dbName;" &>/dev/null; then
        local timeStamp=$(date "+%Y%m%d_%H%M")
        local backupFolder="db_backup"
        local backupLocation=$backupFolder"/"$dbName"_"$timeStamp".dump"
        debug "Creating dump of database: $dbName, into the file: $backupLocation"
        mkdir -p $backupFolder
        docker exec cbreak_${COMMON_DB}_1 pg_dump -Fc -U postgres "$dbName" > "$backupLocation" | debug-cat
    else
        error "The specified database $dbName doesn't exist."
        _exit 1
    fi
}

db-initialize-databases() {
    declare desc="Initialize and migrate databases"
    info $desc

    cloudbreak-config

    migrate-startdb
    db-wait-for-db-cont cbreak_${COMMON_DB}_1

    for db in $CB_DB_ENV_DB $IDENTITY_DB_NAME $PERISCOPE_DB_ENV_DB $VAULT_DB_SCHEMA $DATALAKE_DB_ENV_DB; do
        db-create-database $db
    done

    db-create-vault-schema
    if [[ -n $DPS_REPO ]]; then
        db-initialize-dps
    fi
}

db-create-database() {
    declare desc="Creates new empty database"
    declare newDbName=${1:? required: newDbName}

    if [[ $newDbName != "postgres" ]]; then
        if docker exec cbreak_${COMMON_DB}_1 psql -U postgres -c "\c $newDbName;" &>/dev/null; then
            debug "The database with name $newDbName already exists, no need for creation."
        else
            debug "create new database: $newDbName"
            docker exec cbreak_${COMMON_DB}_1 psql -U postgres -c "create database $newDbName;" | debug-cat
        fi
    fi
}

db-initialize-dps() {
    debug "Initialize dps"
    if docker exec cbreak_${COMMON_DB}_1 psql -U postgres -c "\c dps_core;" &>/dev/null; then
        debug "The dps_core database already exists, no need for creation."
    else
        while read line
        do
            docker exec cbreak_${COMMON_DB}_1 psql -U postgres -v "ON_ERROR_STOP=1" -c "$line" | debug-cat
        done < "$DPS_REPO/resources/dev-setup/init.sql"
    fi
}

db-create-vault-schema() {
    if docker exec cbreak_${COMMON_DB}_1 psql -U postgres -d $VAULT_DB_SCHEMA -c "\d vault_kv_store;" &>/dev/null; then
        debug "Vault tables are already present in schema: $VAULT_DB_SCHEMA"
    else
        debug "Create Vault tables into schema: $VAULT_DB_SCHEMA"
        docker exec cbreak_${COMMON_DB}_1 psql -U postgres -d $VAULT_DB_SCHEMA -c "
        CREATE TABLE vault_kv_store (
            parent_path TEXT COLLATE \"C\" NOT NULL,
            path        TEXT COLLATE \"C\",
            key         TEXT COLLATE \"C\",
            value       BYTEA,
            CONSTRAINT pkey PRIMARY KEY (path, key)
        );
        CREATE INDEX parent_path_idx ON vault_kv_store (parent_path);
        " | debug-cat
    fi
}

db-wait-for-db-cont() {
    declare desc="Wait for db container readiness"
    declare contName=${1:? required db container name}

    debug $desc
    local maxtry=${RETRY:=30}
    #Polling non-loopback port binding due to automatic restart after init https://github.com/docker-library/postgres/issues/146#issuecomment-215856076
    while ! docker exec -i cbreak_${COMMON_DB}_1 netstat -tulpn |grep -i "0 0.0.0.0:5432" &> /dev/null; do
        debug "waiting for DB: $contName to listen on non-loopback interface [tries left: $maxtry] ..."
        maxtry=$((maxtry-1))
        if [[ $maxtry -gt 0 ]]; then
            sleep 1;
        else
            error "The database hasn't started within 30 seconds."
            _exit 1
        fi
    done

    while ! docker exec -i cbreak_${COMMON_DB}_1 pg_isready &> /dev/null; do
        debug "waiting for DB: $contName to be ready [tries left: $maxtry] ..."
        maxtry=$((maxtry-1))
        if [[ $maxtry -gt 0 ]]; then
            sleep 1;
        else
            error "The database hasn't started within 30 seconds."
            _exit 1
        fi
    done
}

db-restore() {
    declare desc="Restoring the specified database from the specified dump file"
    declare dbName=${1:? required: dbName}
    declare dumpFilePath=${2:? required: dumpFilePath}
    info "Restoring database: $dbName from dump, file: $dumpFilePath"

    db-config

    migrate-startdb
    db-wait-for-db-cont cbreak_${COMMON_DB}_1
    db-create-database $dbName

    if [[ -f "$dumpFilePath" ]]; then
        local destFileName=$dbName"-to-restore-"$(date "+%Y%m%d_%H%M")
        debug "copy $dumpFilePath into the container as: $destFileName"
        docker cp $dumpFilePath cbreak_${COMMON_DB}_1:/$destFileName | debug-cat
        debug "Restoring database: $dbName from file: $destFileName with pg_restore."
        docker exec -i cbreak_${COMMON_DB}_1 pg_restore -U postgres -d $dbName $destFileName | debug-cat
    fi
}

cloudbreak-delete-dbs() {
    declare desc="Deletes all cloudbreak db (volume)"

    if [[ "$(docker-compose -p cbreak ps $COMMON_DB | tail -1)" == *"Up"* ]]; then
        error "Database container is running, delete not allowed"
        _exit 1
    fi
    docker volume rm ${CB_COMPOSE_PROJECT}_${COMMON_DB_VOL} 1>/dev/null || :
}