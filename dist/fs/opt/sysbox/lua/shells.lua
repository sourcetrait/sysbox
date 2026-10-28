#!/usr/bin/env luajit
-- Emit environment updates for a calling shell; never execute config contents.
-- Lua 5.1 compatible; no modules or subprocesses required.

local windows = package.config:sub(1, 1) == "\\"
local separator = windows and ";" or ":"
local aliases = { nu = "nushell", pwsh = "powershell" }
local supported = { bash = true, zsh = true, fish = true,
                    nushell = true, powershell = true }
local usage = [[Usage: shells.lua <shell> <env|paths> <filename>
Shells: bash, zsh, fish, nushell (nu), powershell (pwsh)

env    Read NAME=value assignments, expanding $NAME, ${NAME}, ${NAME:-default}.
paths  Prepend one directory per line to PATH, preserving order and deduplicating.

Output: shell statements, or a NUON record for Nushell's from nuon | load-env.
Single-quoted input is literal. Blank lines and comments are ignored.
Errors go to stderr with no partial output. See docs/shells.md for import examples.
]]

local function fail(message)
    error(message, 0)
end

local function trim(value)
    return (value:gsub("^[ \t]+", ""):gsub("[ \t]+$", ""))
end

local function identity(name)
    return windows and name:upper() or name
end

local function split_path(value)
    local paths, start = {}, 1
    if value == nil then return paths end
    while true do
        local stop = value:find(separator, start, true)
        paths[#paths + 1] = value:sub(start, stop and stop - 1 or #value)
        if not stop then return paths end
        start = stop + 1
    end
end

local function read_updates(action, filename)
    local file, message = io.open(filename, "rb")
    if not file then fail(message) end
    local content, read_error = file:read("*a")
    file:close()
    if not content then fail(read_error) end
    content = content:gsub("^\239\187\191", "") -- UTF-8 BOM

    local values, order, directories = {}, {}, {}
    local line_number = 0
    local function invalid(message)
        fail(filename .. ":" .. line_number .. ": " .. message)
    end
    local function getenv(name)
        local value = values[identity(name)]
        if value ~= nil then return value end
        value = os.getenv(name)
        if value == nil and windows and name:upper() == "HOME" then
            value = os.getenv("USERPROFILE")
            if value == nil then
                local drive, path = os.getenv("HOMEDRIVE"), os.getenv("HOMEPATH")
                if drive and path then value = drive .. path end
            end
        end
        return value
    end

    local expand
    local function variable(text, start, quoted, depth)
        if text:sub(start + 1, start + 1) ~= "{" then
            local name = text:sub(start + 1):match("^([A-Za-z_][A-Za-z0-9_]*)")
            if not name then return "$", start + 1 end
            local value = getenv(name)
            if value == nil then invalid("undefined variable: " .. name) end
            return value, start + #name + 1
        end
        local cursor, nesting = start + 2, 1
        while cursor <= #text do
            local char = text:sub(cursor, cursor)
            if char == "\\" then
                cursor = cursor + 2
            elseif text:sub(cursor, cursor + 1) == "${" then
                nesting = nesting + 1
                cursor = cursor + 2
            elseif char == "}" then
                nesting = nesting - 1
                if nesting == 0 then break end
                cursor = cursor + 1
            else
                cursor = cursor + 1
            end
        end
        if nesting ~= 0 then invalid("unterminated variable expansion") end
        local body = text:sub(start + 2, cursor - 1)
        local name, suffix = body:match("^([A-Za-z_][A-Za-z0-9_]*)(.*)$")
        if not name or (suffix ~= "" and suffix:sub(1, 2) ~= ":-") then
            invalid("expected ${NAME} or ${NAME:-default}")
        end
        local value = getenv(name)
        if suffix ~= "" and (value == nil or value == "") then
            value = expand(suffix:sub(3), quoted, depth + 1)
        end
        if value == nil then invalid("undefined variable: " .. name) end
        return value, cursor + 1
    end

    expand = function(text, quoted, depth)
        if depth > 32 then invalid("variable defaults nested too deeply") end
        local result, cursor = {}, 1
        local escapes = { n = "\n", r = "\r", t = "\t", ['"'] = '"',
                          ["\\"] = "\\", ["$"] = "$" }
        while cursor <= #text do
            local char = text:sub(cursor, cursor)
            local next_char = text:sub(cursor + 1, cursor + 1)
            if char == "$" then
                local value
                value, cursor = variable(text, cursor, quoted, depth)
                result[#result + 1] = value
            elseif char == "\\" and ((quoted and escapes[next_char])
                    or next_char == "$" or next_char == "#") then
                result[#result + 1] = escapes[next_char] or next_char
                cursor = cursor + 2
            else
                result[#result + 1] = char
                cursor = cursor + 1
            end
        end
        return table.concat(result)
    end

    local function parse_value(text)
        text = trim(text)
        local quote = text:sub(1, 1)
        local value
        if quote == "'" or quote == '"' then
            local cursor = 2
            while cursor <= #text do
                local char = text:sub(cursor, cursor)
                if quote == '"' and char == "\\" then
                    cursor = cursor + 2
                elseif char == quote then
                    break
                else
                    cursor = cursor + 1
                end
            end
            if cursor > #text then invalid("unterminated quoted value") end
            local tail = trim(text:sub(cursor + 1))
            if tail ~= "" and tail:sub(1, 1) ~= "#" then
                invalid("unexpected text after quoted value")
            end
            value = text:sub(2, cursor - 1)
            if quote == '"' then value = expand(value, true, 0) end
        else
            local comment = text:find("[ \t]#")
            if text:sub(1, 1) == "#" then comment = 1 end
            if comment then text = text:sub(1, comment - 1) end
            value = expand(trim(text), false, 0)
        end
        if value:find("\0", 1, true) then invalid("NUL is not allowed in an environment value") end
        return value
    end

    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        line_number = line_number + 1
        line = trim((line:gsub("\r$", "")))
        if line ~= "" and line:sub(1, 1) ~= "#" then
            if action == "env" then
                line = line:gsub("^export[ \t]+", "")
                local name, raw = line:match("^([A-Za-z_][A-Za-z0-9_]*)[ \t]*=(.*)$")
                if not name then invalid("expected NAME=value") end
                local key = identity(name)
                local value = parse_value(raw) -- resolve against the previous value
                if values[key] == nil then order[#order + 1] = name end
                values[key] = value
            else
                local path = parse_value(line)
                if path == "" then invalid("empty PATH entry") end
                if path:find(separator, 1, true) then
                    invalid("expected one directory; entry contains PATH separator " .. separator)
                end
                directories[#directories + 1] = path
            end
        end
    end

    local updates = {}
    if action == "env" then
        for _, name in ipairs(order) do
            -- Nushell uses PATH as a list, including when assigned by an env file.
            local key = windows and name:upper() == "PATH" and "PATH" or name
            updates[#updates + 1] = { key, values[identity(name)] }
        end
    else
        local paths, seen = {}, {}
        local function append(path)
            local key = windows and path:gsub("/", "\\"):lower() or path
            if not seen[key] then
                paths[#paths + 1], seen[key] = path, true
            end
        end
        for _, path in ipairs(directories) do append(path) end
        for _, path in ipairs(split_path(os.getenv("PATH"))) do append(path) end
        updates[1] = { "PATH", paths }
    end
    return updates
end

local function quote_sh(value)
    return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

local function quote_fish(value)
    return "'" .. value:gsub("\\", "\\\\"):gsub("'", "\\'") .. "'"
end

local function quote_powershell(value)
    -- PowerShell recognizes curly single quotes as delimiters too.
    return "'" .. value:gsub("'", "''"):gsub("‘", "‘‘"):gsub("’", "’’") .. "'"
end

local function quote_nuon(value)
    local escapes = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n",
                      ["\r"] = "\\r", ["\t"] = "\\t" }
    return '"' .. value:gsub('[%z\1-\31\127\\"]', function(char)
        return escapes[char] or string.format("\\u{%x}", char:byte())
    end) .. '"'
end

local function emit(shell, updates)
    local output = {}
    for _, update in ipairs(updates) do
        local name, value = update[1], update[2]
        if name == "PATH" and type(value) == "string"
                and (shell == "fish" or shell == "nushell") then
            value = split_path(value)
        end
        if shell == "nushell" then
            if type(value) == "table" then
                local items = {}
                for _, item in ipairs(value) do items[#items + 1] = quote_nuon(item) end
                value = "[" .. table.concat(items, ", ") .. "]"
            else
                value = quote_nuon(value)
            end
            output[#output + 1] = quote_nuon(name) .. ": " .. value
        elseif shell == "fish" then
            if type(value) ~= "table" then value = { value } end
            local items = {}
            for _, item in ipairs(value) do items[#items + 1] = quote_fish(item) end
            output[#output + 1] = "set -gx " .. name .. " " .. table.concat(items, " ")
        else
            if type(value) == "table" then value = table.concat(value, separator) end
            if shell == "powershell" then
                output[#output + 1] = "$env:" .. name .. " = " .. quote_powershell(value)
            else
                output[#output + 1] = "export " .. name .. "=" .. quote_sh(value)
            end
        end
    end
    if shell == "nushell" then return "{" .. table.concat(output, ", ") .. "}\n" end
    return #output > 0 and table.concat(output, "\n") .. "\n" or ""
end

local function main()
    if arg[1] == "--help" or arg[1] == "-h" then return usage end
    local shell, action, filename = aliases[arg[1]] or arg[1], arg[2], arg[3]
    if not supported[shell] or (action ~= "env" and action ~= "paths")
            or not filename or arg[4] then fail(usage) end
    return emit(shell, read_updates(action, filename))
end

local ok, result = pcall(main)
if not ok then
    io.stderr:write("shells.lua: " .. tostring(result) .. "\n")
    os.exit(1)
end
io.write(result)
