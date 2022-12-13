local string, table, math, bit, type = string, table, math, bit, type
local setmetatable, getmetatable = setmetatable, getmetatable

function declare(name, initval)
    rawset(_G, name, initval)
    return rawget(_G, name)
end

function clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

-- create an standard class
function class(classname, super)
    local superType = type(super)
    local cls

    if superType ~= "function" and superType ~= "table" then
        superType = nil
        super = nil
    end

    if superType == "function" or (super and super.__ctype == 1) then
        -- inherited from native C++ Object
        cls = {}

        if superType == "table" then
            -- copy fields from super
            for k,v in pairs(super) do cls[k] = v end
            cls.__create = super.__create
            cls.super    = super
            
        else
            cls.__create = super
        end

        cls.__ctype = 1

        function cls.new(...)
            local instance = cls.__create(...)
            -- copy fields from class to native object
            for k,v in pairs(cls) do instance[k] = v end
            instance.class = cls
            if instance.ctor then instance:ctor(...) end
            return instance
        end

    else
        -- inherited from Lua Object
        if super then
            cls = {}
            setmetatable(cls, {__index = super})
            cls.super = super

        else
            cls = {}
        end

        cls.__ctype = 2 -- lua
        cls.__index = cls

        function cls.new(...)
            local instance = setmetatable({}, cls)
            instance.class = cls
            if instance.ctor then instance:ctor(...) end
            return instance
        end
    end

    cls.create = cls.new
    cls.__cname = classname

    cls.is = function(cls, name)
        return cls.__cname == name
    end

    -- Support extend exist enumerations
    cls.enum = function(name, enums)
        local tb = cls[name]
        if tb == nil then
            tb = enums
            cls[name] = tb

        else
            for k, v in pairs(enums) do
                assert(tb[k] == nil)
                tb[k] = v
            end
        end
        return tb
    end

    if classname and classname ~= "" then
        declare(classname, cls)
    end

    -- return supers
    local supers = {}
    while super and type(super) == "table" do
        supers[#supers + 1] = super
        super = super.super
    end

    return cls, unpack(supers)
end

--#if __DEBUG__
local __create_cnts = {}
--#endif

-- create an simple class which can not be inherited
function simpleclass(classname, maxCnt)
--#if __DEBUG__
    maxCnt = maxCnt or 100
--#endif

    local cls = {ctor = opt.empty_func, init = opt.empty_func}
    cls.__cname = classname
    cls.__index = cls
    cls.__call = function(t, ...)
        t:init(...)
        return t
    end

    function cls.new(...)
--#if __DEBUG__
        if C and C._config and C._config.checkClassPool == 1 then
            if classname then
                if __create_cnts[classname] == nil then
                    __create_cnts[classname] = 0
                end
                __create_cnts[classname] = __create_cnts[classname] + 1
                if __create_cnts[classname] > maxCnt then
                    log.w(string.format("注意！注意！注意！%s 新建数量超过%d次。", classname or "", __create_cnts[classname]))
                end
            end
        end
--#endif    
        local instance = setmetatable({}, cls)
        instance:ctor(...)
        return instance
    end

    cls.create = cls.new

    if classname and classname ~= "" then
        declare(classname, cls)
    end

    return cls
end

function handler(obj, method, args)
    return function(...)
        return method(obj, ..., args)
    end
end

local globalId = 0
function unid(base)
    if base == nil then
        globalId = globalId + 1
        return globalId

    else
        base._unid = (base._unid or 0) + 1
        return base._unid
    end
end

--[[--
string extensions
--]]--
local string = string

-- Directly get char by pos from string using []
getmetatable("").__index = function(str, i)
    if type(i) == 'number' then
        return string.sub(str, i, i)
    else
        return string[i]
    end
end

string.formatnumberabbr = function(num)
    local formatted = tostring(num)

    if string.len(formatted) > 10 then
        formatted = string.sub(formatted, 1, -10) .."G"
    elseif string.len(formatted) > 7 then
        formatted = string.sub(formatted, 1, -7) .."M"
    elseif string.len(formatted) > 4 then
        formatted = string.sub(formatted, 1, -4) .."K"
    end
    return formatted
end

-- 使用{x}格式来格式化字符串，与C#，Python等语言用法相同。x从1开始，表示第一格参数
-- 在多语言翻译中，会出现语序不同的问题，当格式化参数超过1个的时候，最好使用此方法
string.formatOrder = function(fmt, ...)
    local args = {...}
    local argc = #args

    local tonumber = tonumber
    local function func(k)
        local index = tonumber(k)        
        if index >= 0 or index <= argc then
            return tostring(args[index])
        else
            return ""
        end
    end
    
    return string.gsub(fmt, "{(%d)}", func)
end

-- 去掉字符串首位空白字符
string.trim = function(str)
    return string.gsub(str, "^%s*(.-)%s*$", "%1")
end

-- 去掉字符串首位空白字符
string.trimAll = function(str)
    return string.gsub(str, "%s*(.-)%s*", "%1")
end

-- 判断是否有前缀
string.hasPrefix = function(str, prefix)
    return str:find(prefix) == 1
end

-- 判断是否有后缀
string.hasSuffix = function(str, suffix)
    return suffix == "" or str:sub(-#suffix) == suffix
end

string.utfstrlen = function(str)
    local len = #str;
    local left = len;
    local cnt = 0;
    local arr={0,0xc0,0xe0,0xf0,0xf8,0xfc};
    while left ~= 0 do
        local tmp=string.byte(str,-left);
        if not tmp then break end
        local i=#arr;
        while arr[i] do
            if tmp>=arr[i] then left=left-i;break;end
            i=i-1;
        end
        cnt=cnt+1;
    end
    return cnt;
end

string.toArray = function(str)
    local t = {}
    for i = 1, #str do
        local curByte = string.byte(str, i)
        local step = 0
        if curByte > 0 and curByte <= 127 then
            step = 1
        elseif curByte >= 192 and curByte < 223 then
            step = 2
        elseif curByte >= 224 and curByte < 239 then
            step = 3
        elseif curByte >= 240 and curByte <= 247 then
            step = 4
        end
        local newStr = string.sub(str, i, i + step - 1)
        if newStr ~= "" then
            t[#t + 1] = newStr
        end
        i = i + step - 1
    end
    return t
end

string.toUnicode = function(convertStr)
    if type(convertStr)~="string" then
        return convertStr
    end
    local resultStr={}
    local i=1
    local num1=string.byte(convertStr,i)
    
    while num1~=nil do
        local tempVar1,tempVar2
        if num1 >= 0x00 and num1 <= 0x7f then
            tempVar1=num1
            tempVar2=0
        elseif bit.band(num1,0xe0)== 0xc0 then
            local t1 = 0
            local t2 = 0
            t1 = bit.band(num1,bit.rshift(0xff,3))
            i=i+1
            num1=string.byte(convertStr,i)
            t2 = bit.band(num1,bit.rshift(0xff,2))
            tempVar1=bit.bor(t2,bit.lshift(bit.band(t1,bit.rshift(0xff,6)),6))
            tempVar2=bit.rshift(t1,2)
        elseif bit.band(num1,0xf0)== 0xe0 then
            local t1 = 0
            local t2 = 0
            local t3 = 0
            t1 = bit.band(num1,bit.rshift(0xff,3))
            i=i+1
            num1=string.byte(convertStr,i)
            t2 = bit.band(num1,bit.rshift(0xff,2))
            i=i+1
            num1=string.byte(convertStr,i)
            t3 = bit.band(num1,bit.rshift(0xff,2))
            tempVar1=bit.bor(bit.lshift(bit.band(t2,bit.rshift(0xff,6)),6),t3)
            tempVar2=bit.bor(bit.lshift(t1,4),bit.rshift(t2,2))
        elseif bit.band(num1,0xf8)== 0xf0 then
            i=i+3
        elseif bit.band(num1,0xfc)== 0xf8 then
            i=i+4
        elseif bit.band(num1,0xfe)== 0xfc then
            i=i+5
        end
        if tempVar1 ~= nil then
            resultStr[#resultStr + 1] = bit.lshift(tempVar2, 8) + tempVar1
        end

        i=i+1
        num1=string.byte(convertStr,i)
    end
    return resultStr
end

string.subUTF8String = function(str, start, len)
    local firstResult = ""
    local strResult = ""
    local maxLen = string.len(str)
    start = start - 1
    --find startPos
    local preSite = 1
    if start > 0 then
        for i = 1, maxLen do
            local s_dropping = string.byte(str, i)
            if not s_dropping then
                local s_str = string.sub(str, preSite, i - 1)
                preSite = i + 1
                break
            end

            if s_dropping < 128 or (i + 1 - preSite) == 3 then
                local s_str = string.sub(str, preSite, i)
                preSite = i + 1
                firstResult = firstResult..s_str
                local curLen = string.utfstrlen(firstResult)
                if (curLen == start) then
                    break
                end
            end
        end
    end
    
    --subString
    preSite = string.len(firstResult) + 1
    local startC = preSite
    for i = startC, maxLen do
        local s_dropping = string.byte(str, i)
        if not s_dropping then
            local s_str = string.sub(str, preSite, i - 1)
            preSite = i
            strResult = strResult..s_str
            return strResult
        end

        if s_dropping < 128 or (i + 1 - preSite) == 3 then
            local s_str = string.sub(str, preSite, i)
            preSite = i + 1
            strResult = strResult..s_str
            local curLen = string.utfstrlen(strResult)
            if (curLen == len) then
                return strResult
            end
        end
    end
    
    return strResult
end

--将英文换行空格转换为不换行空格（Unity） 空格后是非英文字母时，替换英文空格为\u{00A0}，使其不会强制换行
string.transferredSpace = function(str)
    local content = ""
    for i = 1, string.len(str) do
        local curByte = string.byte(str, i)
        if curByte == 32 then -- 空格
            local nextByte = string.byte(str, i + 1)
            if nextByte and nextByte > 127 then
                content = content .. "\u{00A0}"
            else
                content = content .. string.sub(str, i, i)
            end
        else
            content = content .. string.sub(str, i, i)
        end
    end
    return content
end

--[[--
table extensions
--]]--

-- calculate the valid index of the given table array
-- return the last index if over length and reverse for the negative index
local function calcIndex(tb, index)
    local len = #tb
    if index > len then
        index = len

    else
        if index < 0 then
            index = len + (index + 1)
        end
    
        index = math.max(index, 1)
    end
    return index
end

-- 获得或者创建指定名称的表
table.get = function(tb, name, val)
    local t = tb[name]
    if t == nil then
        t = val or table.new(4, 0)
        tb[name] = t
    end
    return t
end

-- 获得表中有效项的数量
table.count = function(tbl, cond)
    if tbl.len then
        return tbl.len
    end
    local count = 0
    for _, v in pairs(tbl) do
        if cond == nil or cond(v) then
            count = count + 1
        end
    end
    return count
end

-- 查找符合要求的值或者条件的项
table.find = function(tb, cond)
    if type(cond) == "function" then
        for k, v in pairs(tb) do
            if cond(v) then
                return k, v
            end
        end
    else
        for k, v in pairs(tb) do
            if v == cond then
                return k, v
            end
        end
    end
end

table.findArray = function(tb, cond)
    if type(cond) == "function" then
        for i = 1, #tb do
            if cond(tb[i]) then
                return i, tb[i]
            end
        end

    else
        for i = 1, #tb do
            if tb[i] == cond then
                return i, tb[i]
            end
        end
    end
end

-- 合并两个map类型的表格
table.merge = function(tb, mergeTb)
    if mergeTb == nil then return tb end

    for k, v in pairs(mergeTb) do
        tb[k] = v
    end
end

-- 数组附加数组
table.append = function(tb, append, times)
    if append == nil then return tb end

    while times > 0 do
        local index = #tb
        if type(append) == "number" then
            tb[index + 1] = append

        else
            for i = 1, #append do
                tb[index + 1] = append[i]
                index = index + 1
            end
        end

        times = times - 1
    end

    return tb
end

table.split = function(tbl, num)
    local out = {}
    local t = {}
    for i = 1, #tbl do
        if i % num == 1 then
            t = {}
            out[#out + 1] = t
        end
            
        t[#t + 1] = tbl[i]
    end
    return out
end

-- convert table(map or array) to a new array
-- if col is specified, the converted array is 2d
table.toarray = function(tb, cond, col)
    local arr = table.new(4, 0)
    for k, v in pairs(tb) do
        if type(cond) == "function" then
            v = cond(arr, k, v, col)
        end
        
        if v ~= nil then
            if col then
                local row = arr:get("_row")
                if #row < col then
                    row[#row + 1] = v
                else
                    arr[#arr + 1] = row
                    arr._row = table.new{v}
                end

            else
                arr[#arr + 1] = v
            end
        end
    end

    if arr._row then
        arr[#arr + 1] = arr._row
        arr._row = nil
    end

    return arr
end

-- convert multi-dimensional array to map
table.tomap = function(tb, cond, map)
    map = map or table.new(0, 4)
    for i = 1, #tb do
        local ele = tb[i]
        if type(ele) == "table" then
            ele:tomap(cond, map)

        else
            if cond then
                if type(cond) == "function" then
                    cond(map, ele)

                else
                    -- cond is a key(not "id") of element
                    map[ele[cond]] = ele
                end

            else
                map[ele.id] = ele
            end
        end
    end
    return map
end

-- 随机打乱长度为len范围内的表元素
table.upset = function(tb, len, randomMgr)
    len = len or #tb
    if len > 1 then
        local newIndex = randomMgr and randomMgr:get(len) or math.random(len)
        local val = tb[newIndex]
        tb[newIndex] = tb[len]
        tb[len] = val

        table.upset(tb, len - 1)
    end
end

-- 获得数组指定位置得值，如果超过最大长度，则返回最后一个值。负数则表示反向，-1返回最后一项
table.at = function(tb, index)
    return tb[calcIndex(tb, index or 1)]
end

-- 多层变量访问，处理中间层为nil的情况
-- a._b._c._d -> walk(a, "_b", "_c", "_d")
table.walk = function(tb, ...)
    if tb == nil then return end
    
    local path = {...}
    local pathLen = #path
    for i = 1, pathLen do
        tb = tb[path[i]]
        if tb == nil then
            return nil
        end
    end

    return tb
end

-- 根据条件擦除表中的元素
table.erase = function(tb, cond)
    local index = table.find(tb, cond)
    if index then
        if type(index) == "number" then
            table.remove(tb, index)
        else
            tb[index] = nil
        end
        return true
    end
end

-- 表截取
table.sub = function(tb, startIndex, endIndex)
    local sub = table.new(4, 0)
    startIndex, endIndex = calcIndex(tb, startIndex or 1), calcIndex(tb, endIndex or -1)
    if startIndex <= endIndex then
        local index = 1
        for i = startIndex, endIndex do
            sub[index] = tb[i]
            index = index + 1
        end
    end

    return sub
end

-- 逆序表中元素
table.reverse = function(tb, i, j)
    i, j = i or 1, j or #tb
    while i < j do
        tb[i], tb[j] = tb[j], tb[i]
        i, j = i + 1, j - 1
    end
end

-- rotate the array elements in loop like std::rotate
table.rotate = function(tb, i, j, k)
    local reverse = table.reverse
    reverse(tb, i, k)
    reverse(tb, i, k - j + 1)
    reverse(tb, k - j + 2, k)
end

-- shift is a more common usage of table rotation. Positive number for counterclockwise
table.shift = function(tb, num)
    if num ~= 0 then
        local len = #tb
        if num > 0 then
            table.rotate(tb, 1, num + 1, len)
        else
            table.rotate(tb, 1, num + len + 1, len)
        end
    end
end

table.removeByValue = function(tab, value)
    local isRemoved = false
    local insertIndex, length = 1, #tab
    for i = 1, length do
        local val = tab[i]
        if val ~= value then
            tab[insertIndex] = val
            insertIndex = insertIndex + 1
        else
            isRemoved = true
        end
    end
    for i = insertIndex, length do tab[i] = nil end
    return isRemoved
end

table.removeByCondition = function(tab, func)
    local isRemoved = false
    local insertIndex, length = 1, #tab
    for i = 1, length do
        local val = tab[i]
        if not func(val, i) then
            tab[insertIndex] = val
            insertIndex = insertIndex + 1
        else
            isRemoved = true
        end
    end
    for i = insertIndex, length do tab[i] = nil end
    return isRemoved
end

--[[--
math extensions
--]]--
local mathFloor, mathCeil = math.floor, math.ceil

math.round = function(val, precision)
    if precision then
        precision = math.pow(10, precision)
        val = mathFloor(val * precision + 0.5) / precision

    else
        val = mathFloor(val + 0.5)
    end

    return val
end

-- replacement of math.floor with precision
math.floor = function(val, precision)
    if precision then
        val = math.round(val, precision)
    end

    return mathFloor(val)
end

-- replacement of math.ceil with precision
math.ceil = function(val, precision)
    if precision then
        val = math.round(val, precision)
    end

    return mathCeil(val)
end

-- get number sign
math.sign = function(val)
    return val > 0 and 1 or (val < 0 and -1 or 0)
end

-- 同时限制数值的最小值和最大值
math.limit = function(val, min, max)
    if min then
        if val < min then val = min end
    end

    if max then
        if val > max then val = max end
    end

    return val
end

-- convert the number to the nearest even number
math.even = function(val, isDown)
    local i, f = math.modf(val / 2)
    if f == 0 then return val end

    i = i + i
    return isDown and i or i + 2
end

-- calculate distance between two points
math.distance = function(p1, p2)
    return math.sqrt((p1.x - p2.x) ^ 2 + (p1.y - p2.y) ^ 2)
end

-- customized random generator
math.randomer = function(seed)
    local mgr = {_seed = seed or math.floor(os.time() * 1000)}
    mgr._nextSeed = mgr._seed

    mgr.get = function(mgr, m, n)
        if m == nil and n == nil then
            local base, a, b = 256, 17, 139
            local seed = mgr._nextSeed
            local t1 = a * seed + b
            seed = t1 - math.floor(t1 / base) * base
            mgr._nextSeed = seed
            return seed / base

        else
            if n == nil then
                n = m
                m = 1
            end

            -- Make sure to generate max "n", we should add 1 here
            local val = math.floor(m + (n + 1 - m) * mgr:get())
            if val < m then
                return m
            elseif val > n then
                return n
            end

            return val
        end
    end

    return mgr
end

-- random by given weights and return the index
math.randomWeight = function(weights, totalWeight)
    if totalWeight == nil then    
        for i = 1, #weights do
            totalWeight = totalWeight + weights[i]
        end
    end

    local randWeight = math.random(totalWeight)
    for i = 1, #weights do
        randWeight = randWeight - weights[i]
        if randWeight <= 0 then
            return i
        end
    end
    return #weights
end

-- #if __DEBUG__
function print_memory()
    print(collectgarbage("count") / 1024)
end

function lua_gc()
    collectgarbage("collect")
end

function snapshot1()
    collectgarbage("collect")
    local mri = require("snapshot.MemoryReferenceInfo")
    mri.m_cMethods.DumpMemorySnapshot("./", "1-Before", -1)
end

function snapshot2()
    collectgarbage("collect")
    local mri = require("snapshot.MemoryReferenceInfo")
    mri.m_cMethods.DumpMemorySnapshot("./", "1-After", -1)
end

function snapshot3()
    local mri = require("snapshot.MemoryReferenceInfo")
    mri.m_cMethods.DumpMemorySnapshotComparedFile("./", "Compared", -1, 
        "./LuaMemRefInfo-All-[1-Before].txt", 
        "./LuaMemRefInfo-All-[1-After].txt")
end

function snapshot()
    local snapshotLuaMemory = require("snapshot.snapshot_dump")
    snapshotLuaMemory()
end

-- #endif