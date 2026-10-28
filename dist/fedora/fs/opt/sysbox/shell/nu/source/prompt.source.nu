def __prompt_pwd []: nothing -> string {
    let home = $env.HOME
    let pwd = $env.PWD
    if $pwd == $home { return "~" }
    if $pwd == "/" { return "/" }
    if ($pwd | str starts-with $"($home)/") {
        let comps = ($pwd | str replace $"($home)/" "" | path split | where {|c| $c != "/" })
        if ($comps | length) <= 2 {
            $"~/($comps | str join '/')"
        } else {
            $"($comps | last 2 | str join '/')"
        }
    } else {
        let comps = ($pwd | path split | where {|c| $c != "/" })
        if ($comps | length) <= 2 {
            $"/($comps | str join '/')"
        } else {
            $"($comps | last 2 | str join '/')"
        }
    }
}

def __prompt_git_branch []: nothing -> string {
    match (^git branch --show-current | complete | get stdout | default '' | str trim) {
        '' => '',
        $s => $" \(($s)\)"
    }
}

$env.HOSTNAME = (sys host | get hostname)
$env.PROMPT_COMMAND       = {|| $"(ansi ($env | get -o COLOR_USERNAME | default blue))($env.USER)(ansi ($env | get -o COLOR_HOSTNAME | default grey))@($env.HOSTNAME) (ansi green)(__prompt_pwd)(ansi purple)(__prompt_git_branch)(ansi reset)" }
$env.PROMPT_INDICATOR     = {|| "> " }
$env.PROMPT_COMMAND_RIGHT = {|| "" }
