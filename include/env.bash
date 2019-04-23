
declare -a _env

env-validate() {
	declare var="$1" pattern="$2" patterntext="$3"

	if [[ ${!var} == $pattern ]]; then
		echo "!! Imported variable $var contains $patterntext." | red
		_exit 3
	fi
}

env-import() {
	declare var="$1" default="$2"
	if [[ -z "${!var+x}" ]]; then
		if [[ -z "${2+x}" ]]; then
			echo "!! Imported variable $var must be set in profile or environment." | red
			_exit 2
		else
			export $var="$default"
		fi
	fi
	_env+=($var)
}

env-show() {
	declare desc="Shows relevant environment variables, in human readable format"

    cloudbreak-config
    migrate-config
	local longest=0
	for var in "${_env[@]}"; do
		if [[ "${#var}" -gt "$longest" ]]; then
			longest="${#var}"
		fi
	done
	for var in "${_env[@]}"; do
		printf "%-${longest}s = %s [%s]\n" "$var" "$(_env-description $var)" "${!var}"
	done
}

env-export() {
	declare desc="Shows relevant environment variables, in a machine friendly format."

    # TODO cloudbreak config shouldnt be called here ...
    cloudbreak-config
    migrate-config
	for var in "${_env[@]}"; do
		printf 'export %s=%s\n' "$var" "${!var}"
	done
}

_env-description() {
echo '''
ADDRESS_RESOLVING_TIMEOUT - DNS lookup timeout for internal service discovery
AWS_ACCESS_KEY_ID - Access key of the AWS account
AWS_SECRET_ACCESS_KEY - Secret access key of the AWS account
AZURE_SUBSCRIPTION_ID - Azure subscription ID for interactive login in Web UI
AZURE_TENANT_ID - Azure tenant ID for interactive login in Web UI
CAAS_URL - CAAS API container address with port
CAPTURE_CRON_EXPRESSION - SmartSense bundle generation time interval in Cron format
CBD_CERT_ROOT_PATH - Path where deployer stores Cloudbreak certificates
CBD_TRAEFIK_TLS - Path inside of the Traefik container where TLS files located
CB_AWS_ACCOUNT_ID - ID of AWS account that is configured for the deployment to be used by role based credentials
CB_AWS_CUSTOM_CF_TAGS - Comma separated list of AWS CloudFormation Stack tags
CB_AWS_DEFAULT_CF_TAG - Default tag AWS CloudFormation Stack
CB_AWS_HOSTKEY_VERIFY - Enables host fingerprint verification on AWS
CB_AWS_VPC - Configures the VPC id on AWS if it is the same as provisioned cluster
CB_CLUSTERDEFINITION_AMBARI_DEFAULTS - Comma separated list of the default Ambari cluster definitions what Cloudbreak initialize in database
CB_COMPONENT_CLUSTER_ID - SmartSense component cluster ID
CB_COMPONENT_ID - SmartSense component ID
CB_COMPOSE_PROJECT - Name of the Docker Compose project, will appear in container names too
CB_DB_ENV_DB - Name of the Cloudbreak database
CB_DB_ENV_PASS - Password for the Cloudbreak database authentication
CB_DB_ENV_SCHEMA - Used schema in the Cloudbreak database
CB_DB_ENV_USER - User for the Cloudbreak database authentication
CB_DEFAULT_SUBSCRIPTION_ADDRESS - Address of the default subscription for Cloudbreak notifications
CB_CAPABILITIES - Comma separated list of enabled capabilities
CB_DISABLE_SHOW_CLI - Disables the 'show cli commond' function
CB_DISABLE_SHOW_CLUSTERDEFINITION - Disables the 'show generated cluster definition' function
CB_ENABLEDPLATFORMS - Disables Cloudbreak resource called Platform
CB_ENABLED_LINUX_TYPES - List of enabled OS types from image catalog
CBD_FORCE_START - Disables docker-compose.yml and uaa.yml validation
CB_GCP_HOSTKEY_VERIFY - Enables host fingerprint verification on GCP
CB_HBM2DDL_STRATEGY - Configures hibernate.hbm2ddl.auto in Cloudbreak
CB_HOST_DISCOVERY_CUSTOM_DOMAIN - Custom domain of the provisioned cluster
CB_HOST_ADDRESS - Address of the Cloudbreak backend service
CB_IMAGE_CATALOG_URL - Image catalog url
CB_INSTANCE_NODE_ID - Unique identifier of the Cloudbreak node
CB_INSTANCE_PROVIDER - Cloud provider of the Cloudbreak instance
CB_INSTANCE_REGION - Cloud region of the Cloudbreak instance
CB_INSTANCE_UUID - Unique identifier of Cloudbreak deployment
CB_JAVA_OPTS - Extra Java options for Autoscale and Cloudbreak
CB_AUDIT_FILE_ENABLED - Enable audit log file
CB_KAFKA_BOOTSTRAP_SERVERS - Kafka server endpoints for structured audit logs (eg. server1:123,server2:456)
CB_LOG_LEVEL - Log level of the Cloudbreak service
CB_DEFAULT_GATEWAY_CIDR - Cidr for default security rules
CB_MAX_SALT_NEW_SERVICE_RETRY - Salt orchestrator max retry count
CB_MAX_SALT_NEW_SERVICE_RETRY_ONERROR - Salt orchestrator max retry count in case of error
CB_MAX_SALT_RECIPE_EXECUTION_RETRY - Salt orchestrator max retry count for recipes
CB_PLATFORM_DEFAULT_REGIONS - Comma separated list of default regions by platform (AWS:eu-west-1)
CB_PRODUCT_ID - SmartSense product ID
CB_PORT - Cloudbreak port
CB_SCHEMA_MIGRATION_AUTO - Flag for Cloudbreak automatic database schema update
CB_SMARTSENSE_CONFIGURE - Flag to install and configure SmartSense on cluster nodes
CB_SMARTSENSE_CLUSTER_NAME_PREFIX - SmartSense Cloudbreak cluster name prefix
CB_SMARTSENSE_ID - SmartSense subscription ID
CB_TEMPLATE_DEFAULTS - Comma separated list of the default templates what Cloudbreak initialize in database
CB_UI_MAX_WAIT - Wait timeout for `cbd start-wait` command
CB_LOCAL_DEV_LIST - List of services that will not be created (e.g.: cloudbreak,periscope,datalake,redbeams)
CB_SHOW_TERMINATED_CLUSTERS_ACTIVE - Show terminated clusters
CB_SHOW_TERMINATED_CLUSTERS_DAYS - Days part of timeout to show terminated clusters
CB_SHOW_TERMINATED_CLUSTERS_HOURS - Hours part of timeout to show terminated clusters
CB_SHOW_TERMINATED_CLUSTERS_MINUTES - Minutes part of timeout to show terminated clusters
CERT_VALIDATION - Enables cert validation in Cloudbreak and Autoscale
COMMON_DB - Name of the database container
COMMON_DB_VOL - Name of the database volume
CURL_CONNECT_TIMEOUT - Timeout for curl command
COMPOSE_HTTP_TIMEOUT - Docker Compose execution timeout
DATALAKE_HBM2DDL_STRATEGY - Configures hibernate.hbm2ddl.auto in Datalake
DATALAKE_DB_ENV_DB - Name of the Datalake database
DATALAKE_DB_ENV_PASS - Password for the Datalake database authentication
DATALAKE_DB_ENV_SCHEMA - Used schema in the Datalake database
DATALAKE_DB_ENV_USER - User for the Datalake database authentication
DATALAKE_DB_PORT_5432_TCP_ADDR - Address of the Datalake database
DATALAKE_DB_PORT_5432_TCP_PORT - Port number of the Datalake database
DATALAKE_LOG_LEVEL - Log level of the Datalake service
DATALAKE_SCHEMA_MIGRATION_AUTO - Flag for Datalake automatic database schema update
DATALAKE_SCHEMA_SCRIPTS_LOCATION - Location of Datalake schema update files
DB_DUMP_VOLUME - Name of the database dump volume
DB_MIGRATION_LOG - Database migration log file
DOCKER_CONSUL_OPTIONS - Extra options for Consul
DOCKER_IMAGE_CBD_SMARTSENSE - SmartSense Docker image name
DOCKER_IMAGE_CAAS_MOCK - Caas mock image name
DOCKER_IMAGE_CLOUDBREAK - Cloudbreak Docker image name
DOCKER_IMAGE_CLOUDBREAK_AUTH - Authentication service Docker image name
DOCKER_IMAGE_CLOUDBREAK_PERISCOPE - Autoscale Docker image name
DOCKER_IMAGE_CLOUDBREAK_DATALAKE - Datalake Docker image name
DOCKER_IMAGE_CLOUDBREAK_REDBEAMS - Redbeams Docker image name
DOCKER_IMAGE_CLOUDBREAK_WEB - Web UI Docker image name
DOCKER_TAG_ALPINE - Alpine container version
DOCKER_TAG_CBD_SMARTSENSE - SmartSense container version
DOCKER_TAG_CERT_TOOL - Cert tool container version
DOCKER_TAG_CLOUDBREAK - Cloudbreak container version
DOCKER_TAG_CAAS_MOCK - Caas mock image name
DOCKER_TAG_CONSUL - Consul container version
DOCKER_TAG_HAVEGED - Haveged container version
DOCKER_TAG_MIGRATION - Migration container version
DOCKER_TAG_PERISCOPE - Autoscale container version
DOCKER_TAG_DATALAKE - Datalake container version
DOCKER_TAG_REDBEAMS - Redbeams container version
DOCKER_TAG_POSTGRES - Postgresql container version
DOCKER_TAG_LOGROTATE - Logrotate container version
DOCKER_TAG_REGISTRATOR - Registrator container version
DOCKER_TAG_TRAEFIK - Traefik container version
DOCKER_TAG_UAA - Identity container version
DOCKER_TAG_ULUWATU - Web UI container version
DOCKER_STOP_TIMEOUT - Specify a shutdown timeout in seconds for containers
HTTP_PROXY_HOST - HTTP proxy address
HTTPS_PROXY_HOST - HTTPS proxy address
PROXY_PORT - Proxy port
PROXY_USER - Proxy user (basic auth)
PROXY_PASSWORD - Proxy password (basic auth)
NON_PROXY_HOSTS - Indicates the hosts that should be accessed without going through the proxy. Typically this defines internal hosts. The value of this property is a list of hosts, separated by the "|" character. In addition the wildcard character "*" can be used for pattern matching. For example ”*.foo.com|localhost” will indicate that every hosts in the foo.com domain and the localhost should be accessed directly even if a proxy server is specified. Warning: *.consul should be included!
HTTPS_PROXYFORCLUSTERCONNECTION - if set to true, Cloudbreak will use the proxy to connect Ambari server. Default: false
IDENTITY_DB_NAME - Name of the Identity database
IDENTITY_DB_PASS - Password for the Identity database authentication
IDENTITY_DB_URL - Url for the Identity database connection included the port number
IDENTITY_DB_USER - User for the Identity database authentication
PERISCOPE_HBM2DDL_STRATEGY - Configures hibernate.hbm2ddl.auto in Autoscale
PERISCOPE_DB_ENV_DB - Name of the Autoscale database
PERISCOPE_DB_ENV_PASS - Password for the Autoscale database authentication
PERISCOPE_DB_ENV_SCHEMA - Used schema in the Autoscale database
PERISCOPE_DB_ENV_USER - User for the Autoscale database authentication
PERISCOPE_DB_PORT_5432_TCP_ADDR - Address of the Autoscale database
PERISCOPE_DB_PORT_5432_TCP_PORT - Port number of the Autoscale database
PERISCOPE_LOG_LEVEL - Log level of the Autoscale service
PERISCOPE_SCHEMA_MIGRATION_AUTO - Flag for Autoscale automatic database schema update
PUBLIC_IP - Ip address or hostname of the public interface
REDBEAMS_HBM2DDL_STRATEGY - Configures hibernate.hbm2ddl.auto in Redbeams
REDBEAMS_DB_ENV_DB - Name of the Redbeams database
REDBEAMS_DB_ENV_PASS - Password for the Redbeams database authentication
REDBEAMS_DB_ENV_SCHEMA - Used schema in the Redbeams database
REDBEAMS_DB_ENV_USER - User for the Redbeams database authentication
REDBEAMS_DB_PORT_5432_TCP_ADDR - Address of the Redbeams database
REDBEAMS_DB_PORT_5432_TCP_PORT - Port number of the Redbeams database
REDBEAMS_LOG_LEVEL - Log level of the Redbeams service
REDBEAMS_SCHEMA_MIGRATION_AUTO - Flag for Redbeams automatic database schema update
REDBEAMS_SCHEMA_SCRIPTS_LOCATION - Location of Redbeams schema update files
REST_DEBUG - Enables REST call debug level in Cloudbreak, Autoscale, Datalake, Redbeams
SL_ADDRESS_RESOLVING_TIMEOUT - DNS lookup timeout of Authentication service for internal service discovery
TRAEFIK_MAX_IDLE_CONNECTION - Configures --maxidleconnsperhost for Traefik
PUBLIC_HTTP_PORT - Configures the public http port for Cloudbreak
PUBLIC_HTTPS_PORT - Configures the public https port for Cloudbreak
UAA_CLOUDBREAK_ID - Identity of the Cloudbreak scope in Identity
UAA_CLOUDBREAK_SECRET - Secret of the Cloudbreak scope in Identity
UAA_CLOUDBREAK_SHELL_ID - Identity of the Cloudbreak Shell scope in Identity
UAA_DEFAULT_SECRET - Default secret for all the scopes and encryptions
UAA_SETTINGS_FILE - You can specify custom settings for UAA which will be merged with the default (e.g provide LDAP settings)
UAA_PERISCOPE_ID - Identity of the Autoscale scope in Identity
UAA_PERISCOPE_SECRET - Secret of the Autoscale scope in Identity
UAA_PORT - Identity service public port
UAA_ULUWATU_ID - Identity of the Web UI scope in Identity
UAA_ULUWATU_SECRET - Secret of the Web UI scope in Identity
CAAS_MOCK_CONTAINER_PATH - Default project location in Caas mock container
ULU_HOST_ADDRESS - Web UI host
ULU_NODE_TLS_REJECT_UNAUTHORIZED - Enables self signed certifications in Web UI
ULU_OAUTH_REDIRECT_URI - Authorization page on Web UI
ULU_SUBSCRIBE_TO_NOTIFICATIONS - Flag for automatic subscriptions for CLoudbreak events
VERBOSE_MIGRATION - Flag of verbose database migration
VAULT_BIND_PORT - Bind Port for Vault
CAAS_MOCK_BIND_PORT - Bind Port for Caas Mock
VAULT_CONFIG_FILE - Name of the config file that will be created for Vault
VAULT_DB_SCHEMA - Postgres DB name for storing the secrets
VAULT_DOCKER_IMAGE - Vault Docker image name
VAULT_DOCKER_IMAGE_TAG - Vault Docker image tag
VAULT_UNSEAL_KEYS - Space separated unseal keys for vault
VAULT_AUTO_UNSEAL - If set to true then the Vault root token and unseal key will be saved to the Profile
VAULT_ROOT_TOKEN - Root token to authenticate to Vault

CB_SCHEMA_SCRIPTS_LOCATION - Location of Cloudbreak schema update files
DOCKER_TAG_AMBASSADOR - Ambassador container version for local development
PERISCOPE_SCHEMA_SCRIPTS_LOCATION - Location of Cloudbreak schema update files
REMOVE_CONTAINER - Keeps side effect containers for debug purpose
UAA_SCHEMA_SCRIPTS_LOCATION - Location of Identity schema update files
ULUWATU_VOLUME_HOST - Location of the locally developed Web UI project
CAAS_MOCK_VOLUME_HOST - Location of the locally developed Caas mock

COMPOSE_TLS_VERSION - TLS version used by Docker Compose
DOCKER_NETWORK_NAME - Network name for docker, created by docker-compose

DPS_VERSION - Image tag for DPS containers
DPS_REPO - Location of your DPS repo on host. If it has value, DPS environment will start on your machine.
UMS_HOST - Host address of Altus UMS service
UMS_PORT - Port of Altus UMS service
UMS_ENABLED - Enable UMS, default value is true
CAAS_MOCK - Enables authentication mock
''' | grep "$1 " | sed "s/^.* - //" || echo Deprecated
}
