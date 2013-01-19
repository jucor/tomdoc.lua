-- helpers
function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

local function newNode()
    return {
        args      = {},
        arg_descs = {},
        example   = {}
    }
end

local res      = io.popen("find " .. table.concat({...}, ' ') .. " -type f")
local target   = string.split(res:read '*a', "\n")
local contents = ""
local results  = {}
local files    = {}
local targets  = {}
local patterns = {
    desc  = "%-%- (%w+): (.+)",
    args  = "%-%- (%w+) %- (.+)",
    eg    = "%-%- Examples",
    code  = "%-%-   (.+)",
    ret   = "%-%- Returns (.-%.)",
    proto = "function (.+)"
}

-- close handle
res:close()

for i,v in ipairs(target) do
    -- only match Lua files
    if v:match '%w-%.lua$' then
        table.insert(targets, v)
    end
end

-- parse files
for _,v in ipairs(targets) do
    -- each node represents a function
    local nodes   = {}
    local current = newNode()
    results[v]    = nodes

    -- parse all lines
    for line in io.lines(v) do
        for routine,pat in pairs(patterns) do
            local capture = {line:match(pat)}

            if capture[1] then
                if routine == "desc" then
                    current.scope = capture[1]
                    current.desc  = capture[2]
                elseif routine == "args" then
                    table.insert(current.args, capture[1])
                    table.insert(current.arg_descs, capture[2])
                elseif routine == "code" then
                    for _,v in ipairs(capture) do
                        table.insert(current.example, v)
                    end
                elseif routine == "ret" then
                    current.ret = capture[1]
                elseif routine == "proto" then
                    current.proto = capture[1]

                    --finalize node
                    table.insert(nodes, current)
                    current = newNode()
                end
            end
        end
    end
end

-- generate markdown
for k,f in pairs(results) do
    for k,node in pairs(f) do
        -- generate proto & desc
        contents = contents .. "### " ..  node.proto .. "\n"
        contents = contents .. (node.desc or "Description not given.") .. "\n"

        -- generate arguments
        if node.args and #node.args > 0 then
            contents = contents .. "\n"
            for i,v in ipairs(node.args) do
                contents = contents .. "* " .. (v .. ' - ' .. node.arg_descs[i]) .. "\n"
            end
        end

        -- generate example block
        if node.example and #node.example > 0 then
            contents = contents .. "\n\t" .. table.concat(node.example, "\n\t") .. "\n"
        end

        -- generate returns
        contents = contents .. "\n"
        contents = contents .. ("Returns " .. (node.ret ~= "" and node.ret or "nil.")) .. "\n"
        contents = contents .. "\n"
    end

    -- add to file list
    files[k] = contents
end

-- output markdown
os.execute 'mkdir doc'

for k,v in pairs(files) do
    local file = io.open('doc/' .. k:match('(%w-)%.lua') .. '.mkd', "w")
    file:write(v)
    file:close()
end
