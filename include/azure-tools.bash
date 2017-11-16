azure-configure-arm() {
    declare desc="Configure new ARM application"
    docker run -it hortonworks/cloudbreak-azure-cli-tools:1.8 configure-arm "$@"
}
