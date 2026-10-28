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
  ($env.UENV_USR_OF    | path join 'cargo'  'bin')
  ($env.UENV_USR_OF    | path join 'python' 'bin')
])

$env.EDITOR = "hx"
$env.COLORTERM = "truecolor"

$env.GIT_CONFIG_GLOBAL = ($env.UENV_USR_CONFIG | path join 'git' 'config')

$env.RUSTUP_HOME = ($env.UENV_USR_OF | path join 'rustup')
$env.CARGO_HOME = ($env.UENV_USR_OF | path join 'cargo')
$env.CARGO_TARGET_DIR = ($env.UENV_USR_CACHE | path join 'cargo' 'target')

$env.PYTHONUSERBASE = ($env.UENV_USR_OF | path join 'python')
$env.PYTHONHISTFILE = ($env.UENV_USR_CACHE | path join 'python' 'history')
$env.PYTHONPYCACHEPREFIX = ($env.UENV_USR_CACHE | path join 'python')

$env.npm_config_cache = ($env.UENV_USR_OF | path join 'npm')
$env.npm_config_userconfig = ($env.UENV_USR_CONFIG | path join 'npm' 'npm.rc')
$env.NODE_REPL_HISTORY = ($env.UENV_USR_CACHE | path join 'nodejs' 'history')
