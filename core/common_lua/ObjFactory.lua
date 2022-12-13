local CNull, RES = CNull, RES
local LuaUnity, GameObject = LuaUnity, GameObject
local string, table = string, table

local M = {}
declare("ObjFactory", M)

M.Type = {
    particle    = 1,
    spine       = 2,

    custom      = 11,
}

local ObjFactoryDefine = requireLua("ObjFactoryDefine")

local __obj_pool = {}

local function _instantiate_obj(path)
    local res = RES:SyncLoadAsset(path, nil, function(res) end)
    return GameObject.Instantiate(res.m_oAssetObject)
end

local function _get_obj(name)
    local objs = __obj_pool[name]
    if objs == nil then
        objs = {}
        __obj_pool[name] = objs
    end
    local obj = objs[#objs]

    if obj and not CNull(obj) then
        objs[#objs] = nil
    end

    return obj
end

function M.createObj(objType, name)
    local obj = _get_obj(name)

    if obj == nil or CNull(obj.gameObject) then
        obj = _instantiate_obj(string.format(ObjFactoryDefine[objType], name))
    end

    if objType == M.Type.spine then
        local skeleton = obj:GetComponent("SkeletonGraphic")
        skeleton:Initialize(true)
        skeleton:AddAnimationCompleteDelegate(function(trackName)
            M.recycleObj(name, obj)
        end)
    end

    obj.gameObject:SetActive(true)
    return obj
end

function M.recycleObj(name, obj)
    obj.gameObject:SetActive(false)
    LuaUnity.addChildToParent(obj, GameRoot._gameObjPool)
    table.insert(__obj_pool[name], obj)
end

function M.cleanObjPool()
    for name, objs in pairs(__obj_pool) do
        for i = #objs, 1, -1 do
            GameObject.Destroy(objs[i].gameObject)
            table.remove(__obj_pool[name])
        end
    end 
end

return M