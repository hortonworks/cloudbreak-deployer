cloudbreak-conf-vault() {
    env-import VAULT_BIND_PORT "8200"
    env-import CAAS_MOCK_BIND_PORT "10080"
    env-import VAULT_CONFIG_FILE "vault-config.hcl"
    env-import VAULT_DB_SCHEMA "vault"
    env-import VAULT_DOCKER_IMAGE "vault"
    env-import VAULT_DOCKER_IMAGE_TAG "1.0.1"
    env-import VAULT_UNSEAL_KEYS ""
    env-import VAULT_AUTO_UNSEAL "false"
    env-import VAULT_ROOT_TOKEN ""
}

generate_vault_check_diff() {
    cloudbreak-config

    local verbose="$1"

    if [ -f $VAULT_CONFIG_FILE ]; then
        local vault_delme_path=$TEMP_DIR/vault-delme.hcl
        generate-vault-config-force $vault_delme_path
        if diff $vault_delme_path $VAULT_CONFIG_FILE &> /dev/null; then
            debug "$VAULT_CONFIG_FILE exists and generate wouldn't change it"
            return 0
        else
            if ! [[ "$regeneteInProgress" ]]; then
                warn "$VAULT_CONFIG_FILE already exists, BUT generate would create a DIFFERENT one!"
                warn "please regenerate it:"
                echo "  cbd regenerate" | blue
            fi

            if [[ "$verbose" ]]; then
                warn "expected change:"
                diff $vault_delme_path $VAULT_CONFIG_FILE || true
            else
                debug "expected change:"
                (diff $vault_delme_path $VAULT_CONFIG_FILE || true) | debug-cat
            fi
            return 1
        fi
    else
        generate-vault-config-force $VAULT_CONFIG_FILE
    fi
    return 0

}

generate-vault-config() {
    cloudbreak-config

    if ! generate_vault_check_diff; then
        if [[ ! "$CBD_FORCE_START" ]]; then
            warn "Please check the expected config changes with:"
            echo "  cbd doctor" | blue
            debug "If you want to ignore the changes, set the CBD_FORCE_START to true in Profile"
            _exit 1
        fi
    else
        info "generating $VAULT_CONFIG_FILE"
        generate-vault-config-force $VAULT_CONFIG_FILE
    fi
}

generate-vault-config-force() {
    cloudbreak-config

    declare vaultFile=${1:? required: vault config file path}

    debug "Generating Vault config: ${vaultFile} ..."
    cat > ${vaultFile} << EOF
storage "postgresql" {
  connection_url = "postgres://$CB_DB_ENV_USER:$CB_DB_ENV_PASS@$COMMON_DB:5432/$VAULT_DB_SCHEMA?sslmode=disable"
}

listener "tcp" {
 address     = "0.0.0.0:8200"
 tls_disable = 1
}

disable_mlock = true
ui = true
EOF
}

start_vault() {
    compose-up --no-recreate vault
}

init_vault() {
    cloudbreak-config
    start_vault

    local vault_endpoint="http://vault:$VAULT_BIND_PORT"

    local maxtry=${RETRY:=30}
    while ! get-vault-status | jq -r .initialized &>/dev/null; do
        debug "Waiting for Vault to start [tries left: $maxtry]."
        maxtry=$((maxtry-1))
        if [[ $maxtry -gt 0 ]]; then
            sleep 1;
        else
            error "Vault did not start within 30 seconds."
            _exit 1
        fi
    done
    debug "Vault has started"

    set +e
    vaultStatus=$(get-vault-status)
    set -e

    debug "Vault status: $vaultStatus"
    initialized=$(echo $vaultStatus | jq .initialized)
    if [[ "$initialized" == "false" ]]; then
        debug "Vault is not initialized yet, initialize now.."
        initLog=$(docker run \
            --net "$CB_COMPOSE_PROJECT"_"$DOCKER_NETWORK_NAME" \
            --rm \
            -e VAULT_ADDR=$vault_endpoint \
            --entrypoint /bin/sh \
            $VAULT_DOCKER_IMAGE:$VAULT_DOCKER_IMAGE_TAG -c 'vault operator init -key-shares=1 -key-threshold=1 -format=json')


        rootToken=$(echo $initLog | jq '.root_token' -r)
        append-variable-to-profile VAULT_ROOT_TOKEN "$rootToken"
        info "$CBD_PROFILE has been updated with the Vault root token"

        unsealKeys=$(echo $initLog | jq '.unseal_keys_b64[0]' -r)
        if [[ "$VAULT_AUTO_UNSEAL" == "true" ]]; then
            append-variable-to-profile VAULT_UNSEAL_KEYS "$unsealKeys"
            info "$CBD_PROFILE has been updated with the Vault unseal keys"

            vault-unseal $unsealKeys
        else
            warn "Vault auto unseal is disabled so please save the keys in order to use Vault."
            warn "Each time you restart CBD you must unseal Vault with the unseal key."
            warn "You can enable Vault auto unseal by putting the following in your $CBD_PROFILE file"
            warn "export VAULT_AUTO_UNSEAL=true"
            warn "export VAULT_UNSEAL_KEYS=$unsealKeys"
        fi
        load-profile
        deployer-regenerate
    else
        debug "Vault is already initialized"
        if [[ "$VAULT_AUTO_UNSEAL" == "true" ]]; then
            if [[ -z $VAULT_UNSEAL_KEYS ]]; then
                warn "Vault is initialized, but the unseal keys are not provided in the Profile. Please include them in the VAULT_UNSEAL_KEYS var or manually unseal Vault."
            else
                vault-unseal $VAULT_UNSEAL_KEYS
            fi
        else
            warn "Vault auto unseal is disabled so please unseal Vault now in order to use it."
        fi
    fi

    create-token-file

    if [[ "$(get-vault-status | jq -r .sealed 2>/dev/null)" == "false" ]]; then
        debug "Checking kv engine version"
        local secretStoreVersion=$(docker run \
                --net "$CB_COMPOSE_PROJECT"_"$DOCKER_NETWORK_NAME" \
                --rm \
                -e VAULT_TOKEN=$VAULT_ROOT_TOKEN \
                -e VAULT_ADDR=$vault_endpoint \
                --entrypoint /bin/sh \
                $VAULT_DOCKER_IMAGE:$VAULT_DOCKER_IMAGE_TAG -c "vault secrets list -format=json" | jq -r '.["secret/"].options.version')

        if [[ "$secretStoreVersion" == "1" ]] || [[ "$secretStoreVersion" == "null" ]]; then
            debug "Converting kv engine $secretStoreVersion to v2"
            docker run \
                --net "$CB_COMPOSE_PROJECT"_"$DOCKER_NETWORK_NAME" \
                --rm \
                -e VAULT_TOKEN=$VAULT_ROOT_TOKEN \
                -e VAULT_ADDR=$vault_endpoint \
                --entrypoint /bin/sh \
                $VAULT_DOCKER_IMAGE:$VAULT_DOCKER_IMAGE_TAG -c "vault kv enable-versioning secret/"
        fi
    else
        warn "Vault is sealed, please unseal it and execute the following command: vault kv enable-versioning secret/"
    fi
}

get-vault-status() {
    echo $(docker run \
        --net "$CB_COMPOSE_PROJECT"_"$DOCKER_NETWORK_NAME" \
        --rm \
        -e VAULT_ADDR=$vault_endpoint \
        --entrypoint /bin/sh \
        $VAULT_DOCKER_IMAGE:$VAULT_DOCKER_IMAGE_TAG -c 'vault status -format=json 2>/dev/null')
}

vault-unseal() {
    declare desc="Unseal Vault from $CBD_PROFILE file or argument"

    cloudbreak-config

    declare vault_unseal_keys=${1:-$VAULT_UNSEAL_KEYS}
    if [[ -z "$vault_unseal_keys" ]]; then
        warn "Vault unseal key is not in your $CBD_PROFILE file"
        warn "Please provide it with: export VAULT_UNSEAL_KEYS=mykey"
        warn "or provide it as an argument for this command"
        _exit 1
    fi

    local vault_endpoint="http://vault:$VAULT_BIND_PORT"

    docker run \
        --net "$CB_COMPOSE_PROJECT"_"$DOCKER_NETWORK_NAME" \
        --rm \
        -e VAULT_ADDR=$vault_endpoint \
        -e VAULT_UNSEAL_KEYS=$vault_unseal_keys \
        --entrypoint /bin/sh \
        $VAULT_DOCKER_IMAGE:$VAULT_DOCKER_IMAGE_TAG -c 'vault operator unseal $VAULT_UNSEAL_KEYS' | debug-cat
    info "Vault is unsealed"
}

vault-status() {
    declare desc="Shows the status of Vault in json format"

    cloudbreak-config

    local vault_endpoint="http://vault:$VAULT_BIND_PORT"

    docker run \
        --net "$CB_COMPOSE_PROJECT"_"$DOCKER_NETWORK_NAME" \
        --rm \
        -e VAULT_ADDR=$vault_endpoint \
        --entrypoint /bin/sh \
        $VAULT_DOCKER_IMAGE:$VAULT_DOCKER_IMAGE_TAG -c 'vault status -format=json'
}

cloudbreak-delete-vault-data() {
    cloudbreak-conf-vault

    remove-variable-from-profile VAULT_UNSEAL_KEYS
    remove-variable-from-profile VAULT_ROOT_TOKEN

    rm -rf $VAULT_CONFIG_FILE
}

create-token-file() {
    mkdir -p ./etc
    # token file is needed for Audit Service with a UUID inside it. This is temporary until Thunderhead codebase is updated to accept real root tokens.
    uuidgen > "./etc/vault-dev-root-token.txt"
}
