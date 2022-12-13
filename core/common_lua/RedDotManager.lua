local type, string, table = type, string, table
local CNull = CNull

local M = {}
declare("RedDotManager", M)

function M.init(cfg)
    M.config = cfg
    M.paths = {}
end

function M.add(obj, path, updateFlag)
    M.paths[path] = obj
    if updateFlag then
        M.update(path)
    end
end

function M.getFlag(cfgNode)
    local flag
    if type(cfgNode) == "function" then
        return cfgNode()

    else
        for _, node in pairs(cfgNode) do
            if type(node) == "function" then
                flag = node()
                if flag then return true end

            else
                flag = M.getFlag(node)
                if flag then return true end
            end
        end
    end

    return flag
end

local function updateFlag(path, flag)
    if flag == nil then
        local parts = string.split(path, ".")
        local cfgNode = table.walk(M.config, unpack(parts))
        flag = M.getFlag(cfgNode)
    end

    local obj = M.paths[path]
    if obj and not CNull(obj) and not CNull(obj.gameObject) then
        LuaUnity.setRedFlag(obj,flag)
    end

    return flag
end

function M.update(path)
    if C._config.localBattle then
        return
    end
    local parts = string.split(path, ".")

    local flag, path = updateFlag(path), parts[1]
    if flag then
        for i = 2, #parts do
            path = string.format("%s.%s", path, parts[i])
            updateFlag(path, flag)
        end

    else
        for i = 2, #parts do
            path = string.format("%s.%s", path, parts[i])
            updateFlag(path)
        end
    end
end

return M