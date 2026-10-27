source ../source/prompt.source.nu

$env.config.show_banner = false
$env.config.history = {
    file_format: sqlite
    isolation: true
    sync_on_enter: true
    max_size: 100_000_000
}

$env.PATH = ($env.PATH | append [
  ($env.UENV_USR_ADHOC | path join 'bin')
  ($env.UENV_USR_LOCAL | path join 'bin')
  ($env.UENV_USR_OF    | path join 'cargo/bin')
  ($env.UENV_USR_OF    | path join 'python/bin')
])

$env.GIT_CONFIG_GLOBAL = ($env.UENV_USR_CONFIG | path join 'git' 'gitconfig')
$env.RUSTUP_HOME = ($env.UENV_USR_OF | path join 'rustup')
$env.CARGO_HOME = ($env.UENV_USR_OF | path join 'cargo')

# setup python's env
$env.PYTHONUSERBASE = ($env.HOME | path join '.sys/.python')
$env.PYTHONHISTFILE = ($env.HOME | path join '.sys/.python_history')
$env.PYTHONPYCACHEPREFIX = ($env.XDG_CACHE_HOME | path join 'python')

# setup NPM's user env
$env.npm_config_cache = ($env.HOME | path join '.sys/.npm')
$env.npm_config_userconfig = ($env.HOME | path join '.sys/.npmrc')

# setup nodejs's env
$env.NODE_REPL_HISTORY = ($env.HOME | path join '.sys/.node-repl-history')


$env.COLORTERM = "truecolor"
$env.EDITOR = "hx"



umask rwxr-x--- | ignore
