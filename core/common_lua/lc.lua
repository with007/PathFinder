local lc = {}
declare("lc", lc)

local math, type, string, io, os, setmetatable, tonumber = math, type, string, io, os, setmetatable, tonumber
local Application, DOTween = Application, DOTween
local LuaHelper, Util, Vector3, Color = LuaHelper, Util, Vector3, Color
local Timer, Time, ServerTimestamp = Timer, Time, ServerTimestamp

if Application.isMobilePlatform then
    lc._isMobile = true
    if AppConst.Platform == AppConst.ios then
        lc._isiOS = true
    else
        lc._isAndroid = true
    end
else
    lc._isMobile = false
end

-- 0: low, 1: high
lc.FrameRateHigh    = 60
lc.FrameRateLow     = 30
lc.GraphicsQuality  = 2
if lc._isAndroid then
    local gpuMemorySize = UnityEngine.SystemInfo.graphicsMemorySize
    if gpuMemorySize < 512 then
        lc.GraphicsQuality = 0
    elseif gpuMemorySize <= 1024 and Screen.width >= 1080 then
        lc.GraphicsQuality = 1
    end
end
Application.targetFrameRate = lc.GraphicsQuality >= 1 and lc.FrameRateHigh or lc.FrameRateLow
if lc.GraphicsQuality <= 1 then
    local rate = 0.75
    local dstWidth = 1080 * rate
    if Screen.width > dstWidth then
        Screen.SetResolution(1080 * rate, dstWidth * Screen.height / Screen.width, true)
    end
end

function lc.appendFunctions(dest, ori)
    for k, v in pairs(ori) do
        dest[k] = v
    end
end

-- convert all types to string including dump table
local tostring = tostring
function lc.tostring(var, depth, prefix)
    prefix = prefix or ""

    if type(var) ~= "table" then
        return prefix..tostring(var)

    else
        if var.__cname == "list" then
            return lc.tostring(var:values())

        else
            local str = ""
            if depth ~= 0 then
                local prefix_next, isFirst = prefix .. ", ", true
                str = str ..prefix .. "{"
                for k, v in pairs(var) do
                    str = str ..(isFirst and "" or prefix_next) .. k .. " = "
                    isFirst = false

                    if type(v) ~= "table" or (type(depth) == "number" and depth <= 1) then
                        if type(v) == "boolean" then
                            str = str .. (v and 'true' or 'false')
                        elseif type(v) == "function" then
                            str = str .."Func"
                        else
                            str = str .. tostring(v)
                        end
                    else
                        if depth == nil then
                            str = str .. lc.tostring(v, nil, prefix_next)
                        else
                            str = str .. lc.tostring(v, depth - 1, prefix_next)
                        end
                    end
                end
                str = str ..(prefix .. "}")
            end

            return str
        end
    end
end

--// 单位ms
function lc.getTimeEndArgs(dt)
    if dt < 0 then 
        return 0, 0, 0, 0
    end

    dt = dt / 1000
    local hour   = math.floor(dt / 3600)
    local day = math.floor(hour / 24)
    hour = hour - day * 24
    local minute = math.floor(dt % 3600 / 60)
    local second = math.floor(dt % 3600 % 60)

    return day, hour, minute, second
end

function lc.getTimeAgoArgs(dt, maxDay)
    local dt = dt / 1000

    if dt <= 1 then
        return 0
    end

    local day = math.floor(dt / 24 / 3600)
    if day > 0 then
        if maxDay and day > maxDay then
            return 1, maxDay
        else
            return 2, day
        end
    end

    local hour = math.floor(dt / 3600)
    if hour > 0 then
        return 3, hour
    end

    local minute = math.floor(dt / 60)
    if minute > 0 then
        return 4, minute
    end

    return 5, dt
end


function lc.getDeviceInfoString()
    return Util.GetDeviceInfo()
end

function lc.getUdid()
    if GMTools.settings.udid then
        return GMTools.settings.udid
    end
    
    if lc._isMobile then
        return Util.GetUDID()
    else
        return C._config.udid
    end
end

function lc.getChannelName()
    local appId = C._appId

    if appId == "10001" then
        return "DEV"
    elseif appId == "10002" then
        return "DEV"
    elseif appId == "10003" then
        return "ALPHA"
    end

    if lc._isMobile then
        if lc._isiOS then
            return "APPSTORE"
        else
            return "GOOGLEPLAY"
        end
    else
        return "DEV"
    end
end

function lc.openUrl(url)
    LuaHelper.OpenUrl(url)
end

---// 单位s
function lc.getRealtimeSinceStartup()
    return Time.realtimeSinceStartup
end

--// 单位s
function lc.getTimestamp()
    if P and P._serverTime then
        return P._serverTime + lc.getRealtimeSinceStartup() - P._serverBaseTime
    else
        return ServerTimestamp.GetServerTimestamp()
    end
end

--// 单位s
function lc.getDayBeginTimestamp(day, timestamp)
    day = day or 0
    timestamp = timestamp or lc.getTimestamp()
    timestamp = timestamp - timestamp % 864000 + (day or 0) * 864000
    return timestamp
end

function lc.addLongPress(objInst, delegate, agrs)
    local listener = objInst.gameObject:GetComponent("LongPressEventListener")
    if listener == nil then
        listener = objInst.gameObject:AddComponent(typeof(LongPressEventListener))
    end
    listener:UnlistenAll()
    listener.onLongPress:AddListener(function()
        if delegate.onLongPress then
            delegate:onLongPress(agrs)
        end
    end)
end

function lc.addListeners(objInst, delegate, agrs)
    local listener = objInst.gameObject:GetComponent("InputEventListener")
    if listener == nil then
        listener = objInst.gameObject:AddComponent(typeof(InputEventListener))
    end

    listener:UnlistenAll()

    listener.onBeginDrag:AddListener(function(eventData)
        if delegate.onTouchBegan then
            delegate:onTouchBegan(eventData, agrs)
        end
    end)

    listener.onDrag:AddListener(function(eventData)
        if delegate.onTouchMoved then
            delegate:onTouchMoved(eventData, agrs)
        end
    end)

    listener.onEndDrag:AddListener(function(eventData)
        if delegate.onTouchEnded then
            delegate:onTouchEnded(eventData, agrs)
        end
    end)

    -- listener.onPointUp:AddListener(function(eventData)
    --     if delegate.onPointUp then
    --         delegate:onPointUp(eventData, agrs)
    --     end
    -- end)

    -- listener.onPointDown:AddListener(function(eventData)
    --     if delegate.onPointDown then
    --         delegate:onPointDown(eventData, agrs)
    --     end
    -- end)

    -- listener.onPointEnter:AddListener(function(eventData)
    --     if delegate.onPointEnter then
    --         delegate:onPointEnter(eventData, agrs)
    --     end
    -- end)

    -- listener.onPointExit:AddListener(function(eventData)
    --     if delegate.onPointExit then
    --         delegate:onPointExit(eventData, agrs)
    --     end
    -- end)

    -- listener.onLongPress:AddListener(function()
    --     if delegate.onLongPress then
    --         delegate:onLongPress(agrs)
    --     end
    -- end)
end

function lc.screenPosToUIPos(objInst, position, camera)
    return Util.ScreenPosToUIPos(objInst.transform, position, camera)
end

function lc.containPoint(objInst, point)
    return lc.containPointByRect(objInst:rect(), point)
end

function lc.containPointByRect(rect, point)
    if (point.x >= rect.x) and (point.x <= rect.x + rect.width) and
        (point.y >= rect.y) and (point.y <= rect.y + rect.height) then
        return true
    end

    return false
end

function lc.objIntersectsObj(obj1, obj2)
    return lc.rectIntersectsRect(obj1:rect(), obj2:rect())
end

function lc.rectIntersectsRect( rect1, rect2 )
    local intersect = not ( rect1.x > rect2.x + rect2.width or
                    rect1.x + rect1.width < rect2.x         or
                    rect1.y > rect2.y + rect2.height        or
                    rect1.y + rect1.height < rect2.y )

    return intersect
end

function lc.covert2NodePos(out, obj, dest, point)
    local wp = obj.transform:TransformPoint(point or Vector3.static(0, 0, 0))
    local p = dest.transform:InverseTransformPoint(wp)

    out:Add(p)
end

function lc.formatFloat(val, precision)
    if math.floor(val) == val then
        return tostring(val)
    end

    precision = precision or 2
    val = math.round(val, precision)

    local fmt = string.format("%%.%df", precision)
    local str = string.format(fmt, val)

    local len = str:len()
    local ch = str[len]
    while ch ~= '.' and tonumber(ch) == 0 do
        len = len - 1
        ch = str[len]
    end

    if ch == '.' then
        len = len - 1
    end

    return str:sub(1, len)
end

function lc.isFileExist(name)
    local f = io.open(name, "rb")
    if f then f:close() end
    return f ~= nil
end

function lc.clr(r, g, b, a)
    local clr

    if g then
        if b then
            clr = {r = r, g = g, b = b, a = a}
        else
            clr = {r = r, g = r, b = r, a = g}
        end

    else
        clr = {r = r, g = r, b = r}
    end

    clr.r = clr.r / 255
    clr.g = clr.g / 255
    clr.b = clr.b / 255
    clr.a = (clr.a and clr.a / 255 or 1)

    -- must set metatable to Color for tolua type checking
    setmetatable(clr, Color)

    return clr
end

lc.cRed 	    = lc.clr(255, 0, 0)
lc.cGreen	    = lc.clr(0, 255, 0)
lc.cBlue	    = lc.clr(0, 0, 255)
lc.cWhite	    = lc.clr(255)
lc.cBlack	    = lc.clr(0)
lc.cYellow	    = lc.clr(255, 255, 0)
lc.cCyan	    = lc.clr(0, 255, 255)
lc.cMagenta	    = lc.clr(255, 0, 255)
lc.cGray	    = lc.clr(128, 128, 128)
lc.cDarkGray	= lc.clr(64, 64, 64)

function lc.setSize(obj, w, h)
    local tf = obj.transform or obj
    local size = tf.sizeDelta
    if w then size.x = w end
    if h then size.y = h end
    tf.sizeDelta = size
end

function lc.sequence(...)
    local arg = {...}
    
    local seq = DOTween.Sequence()
    for i = 1, #arg do
        local tween = arg[i]
        if type(tween) == "function" then
            seq:AppendCallback(tween)

        elseif type(tween) == "number" then
            seq:AppendInterval(tween)

        else
            seq:Append(tween)
        end
    end

    return seq
end

function lc.delayFunc(dt, callback, carryArgs)
    lc.sequence(dt, function() callback(carryArgs) end)
end

function lc.runStringCode(code)
    if #code == 0 then
        return "[ERROR] Empty code!"
    end

    local ok, ret = pcall(function()
        local chunk, err = loadstring(code)
        if chunk == nil then
            return string.format( "parse patch error: %s",err)
        end
        return chunk()
    end)

    if ok then
        return ret ~= nil and tostring(ret) or 'execute ok'
    else
        return ret
    end
end

function lc.random(...)
    return math.random(...)
end

function lc.randomMgr(seed)
    -- evenly distributed random number generator
    -- the larger the range, the greater the frequency of occurrence of a single number
    -- and the even distribution can still be maintained within a certain range
    local mgr = {}

    mgr.seed = function(mgr, seed)
        mgr._seed = seed or math.floor(os.clock() * 1000)
        mgr._nextSeed = mgr._seed
    end

    mgr.get = function(mgr, m, n)
        if m == nil and n == nil then
            -- generate from [0, 1) float
            local base, a, b = 256, 17, 139
            local seed = mgr._nextSeed
            local t1 = a * seed + b
            seed = t1 - math.floor(t1 / base) * base
            mgr._nextSeed = seed
            return seed / base

        else
            -- generate from [m, n] integer
            if n == nil then
                m = 1
                n = m
            end

            n = n + 1       -- make sure contains n
            return math.floor(m + (n - m) * mgr:get())
        end
    end

    mgr:seed(seed)
    return mgr
end

function lc.setInterval(callback, n)
    local timer = nil
    timer = Timer.New(function() 
        callback()
        if timer then
            timer.loop = 0x8ffffffff
        end
    end, n, 0x8ffffffff, true)
    timer:Start()
    return timer
end

function lc.setTimer(callback, n)
    local timer = nil
    timer = Timer.New(function() 
        callback()
    end, n, 1)
    timer:Start()
    return timer
end

function lc.stopTimer(timer)
    if timer == nil then
        return
    end
    timer:Stop()
end

function lc.stopTimers(timers)
    if timers == nil then
        return
    end
    for i = 1, #timers do
        lc.stopTimer(timers[i])
    end
end

function lc.autoDestroyParticle(userdata)
    LuaHelper.AutoDestroyParticle(userdata)
end

function lc.logDesignEvent(eventName, value)
    LuaHelper.LogDesignEvent(eventName, value)
end
function lc.logBusinessEvent(currency, amount, itemType, itemId, cartType)
    LuaHelper.LogBusinessEvent(currency, amount, itemType, itemId, cartType)
end
function lc.logAdEvent(adAction, adType, adSdkName, adPlacement, duration)
    LuaHelper.LogAdEvent(adAction, adType, adSdkName, adPlacement, duration)
end
function lc.logAFEvent(eventName, value)
    LuaHelper.LogAFEvent(eventName, value)
end