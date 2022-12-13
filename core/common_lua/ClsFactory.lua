--
-- Author: soul
-- Date: 2021/7/21 17:3:3
-- Brief: 
--

local M = {}
declare("ClsFactory", M)

--[[
ClsFactory = M
]]

M.ClassName = {
    Vector2 = "Vector2",
    Vector3 = "Vector3",
    Quaternion = "Quaternion",
    XNumber = "XNumber",
}

local __clses = {}
local __caches = {}
local __counts = {}
local __objsInFrame = {}
local __objsInFrameCount = 0

local function _create_cls(name, ...)
    local cls = __clses[name]
    if cls == nil then
        --// 改用懒加载方式，新增类时，无需改该模块
        cls = _G[name]
        __clses[name] = cls
    end

    return cls.create(...)
end

local function _get_cls(name)
    local cache = __caches[name]
    if cache == nil then
        return nil
    end

    local cls = cache[#cache]
    if cls then
        cache[#cache] = nil
    end

    return cls
end

function M.getCls(name, ...)
--#if __DEBUG__
    if C and C._config and C._config.checkClassPool == 1 then
        if __counts[name] ~= nil and __counts[name] >= 50 then
            log.green(string.format("[%s] new", name))
        end
    end
--#endif

    local cls = _get_cls(name)
    if cls == nil then
--#if __DEBUG__
        if C and C._config and C._config.checkClassPool == 1 then
            __counts[name] = (__counts[name] or 0) + 1
            if __counts[name] >= 50 then
                log.w(string.format("注意！注意！注意！%s 新建数量已有%d次", name, __counts[name]))
            end
        end
--#endif

        cls = _create_cls(name, ...)
    else
        cls:init(...)
    end
    
    return cls
end

function M.getClsAutoRecycle(...)
    local cls = M.getCls(...)
    __objsInFrameCount = __objsInFrameCount + 1
    __objsInFrame[__objsInFrameCount] = cls
    return cls
end

function M.addCls(cls)
    local cache = __caches[cls.__cname]
    if cache == nil then
        __caches[cls.__cname] = {cls}
    else
        cache[#cache + 1] = cls
    end
end

M.recycleCls = M.addCls

--// 此函数会新创建一个副本
function M.createCls(name, ...)
    return _create_cls(name, ...)
end

function M.autoRecycle()
    for i = 1, __objsInFrameCount do
        M.addCls(__objsInFrame[i])
    end
    __objsInFrameCount = 0
end

return M