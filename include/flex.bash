generate-flex-usage() {
    declare desc="Generate Flex related usages."

    cloudbreak-conf-uaa

    local USAGE_PATH="usages/flex/daily"

    if [ $# -eq 1 ]; then
        local PARAMETER=$1
        case $PARAMETER in
            latest)
                USAGE_PATH="usages/flex/latest"
                ;;
            *)
                error "Invalid parameter: $PARAMETER. Supported parameters: latest"
                return 1
                ;;
        esac
    fi

    local CRED="$UAA_FLEX_USAGE_CLIENT_ID:$UAA_FLEX_USAGE_CLIENT_SECRET"
    local CRED_BASE64="$(echo -n "${CRED}"|base64|tr -d '\n')"
    local TOKEN=$(curl -sX POST -H "Authorization: Basic $CRED_BASE64" "${PUBLIC_IP}:${UAA_PORT}/oauth/token?grant_type=client_credentials" | jq '.access_token' -r)
    local USAGE=$(curl -sX GET -H "Authorization: Bearer $TOKEN" "${PUBLIC_IP}:8080/cb/api/v1/${USAGE_PATH}")
    echo ${USAGE#*=}
}