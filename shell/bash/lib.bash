
cfg() {
    local name
    name="${1:?name is required}"
    local cfgfile="$REPO_DIR/shell/cfg/$name"
    if [[ ! -f "$cfgfile" ]]; then
        echo -e "error: config not found: $cfgfile"
        exit 1
    fi

    cat "$cfgfile"
}
