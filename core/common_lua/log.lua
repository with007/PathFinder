--
-- Author: Soul
-- Date: 2019-06-12 11:56:25
-- Brief: 
--

--------------------------------
-- color related
--------------------------------

local setColor = function(c) end

local color = {}
color.RED     = 0
color.BLUE    = 0
color.GREEN   = 0
color.PURPLE  = 0
color.YELLOW  = 0
color.CYAN    = 0
color.DEFAULT = 0

local colors = {color.BLUE, color.CYAN, color.GREEN, color.YELLOW, color.RED, color.PURPLE}

function color.colorPrintF(c, str)
    setColor(c)
    _G.print(str)
    setColor(color.DEFAULT)
end


logf = {}

function logf.str(level, tag, fmt, ...)
    return table.concat({
        level,
        "/[",
        string.upper(tostring(tag)),
        "] ",
        string.format(tostring(fmt), ...)
    })
end

function logf.v(tag, fmt, ...)
    if AppConst.Release then
        return
    end
    color.colorPrintF(color.DEFAULT, logf.str("V", tag, fmt, ...))
end

function logf.d(tag, fmt, ...)
    if AppConst.Release then
        return
    end
    color.colorPrintF(colors[1], logf.str("D", tag, fmt, ...))
end

function logf.i(tag, fmt, ...)
    if AppConst.Release then
        return
    end
    color.colorPrintF(colors[3], logf.str("I", tag, fmt, ...))
end

function logf.w(tag, fmt, ...)
    if AppConst.Release then
        return
    end
    color.colorPrintF(colors[4], logf.str("W", tag, fmt, ...))
end

function logf.e(tag, fmt, ...)
    if AppConst.Release then
        return
    end
    color.colorPrintF(colors[5], logf.str("E", tag, fmt, ...))
end

function logf.f(tag, fmt, ...)
    if AppConst.Release then
        return
    end
    color.colorPrintF(colors[6], logf.str("F", tag, fmt, ...))
end


function color.colorPrint(c, str, ...)
    setColor(c)
    _G.print(str, ...)
    setColor(color.DEFAULT)
end

log = {}

function log.str(level, tag)
    return table.concat({
        level,
        "/[",
        string.upper(tostring(tag)),
        "] ",
    })
end

function log.v(tag, ...)
    if AppConst.Release then
        return
    end
    color.colorPrint(color.DEFAULT, log.str("V", tag), ...)
end

function log.d(tag, ...)
    if AppConst.Release then
        return
    end
    color.colorPrint(colors[1], log.str("D", tag), ...)
end

function log.i(tag, ...)
    if AppConst.Release then
        return
    end
    color.colorPrint(colors[3], log.str("I", tag), ...)
end

function log.w(tag, ...)
    if AppConst.Release then
        return
    end
    color.colorPrint(colors[4], log.str("W", tag), ...)
end

function log.e(tag, ...)
    if AppConst.Release then
        return
    end
    color.colorPrint(colors[5], log.str("E", tag), ...)
end

function log.f(tag, ...)
    if AppConst.Release then
        return
    end
    color.colorPrint(colors[6], log.str("F", tag), ...)
end

--[[
    logf.v = function() end
    logf.d = function() end
    logf.i = function() end
    logf.w = function() end
    logf.e = function() end
    logf.f = function() end

--]]

--------------------------------
-- dump related
--------------------------------

local table_format = string.format
local string_len = string.len
local string_rep = string.rep

local function _dump_value(v)
    if type(v) == "string" then
        v = "\"" .. v .. "\""
    end
    return tostring(v)
end

local function dump(value, desciption, nesting)
    if type(nesting) ~= "number" then nesting = 5 end

    local lookup = {}
    local result = {"\n"}
    local traceback = string.split(debug.traceback("", 2), "\n")
    --print("dump from: " .. string.trim(traceback[3]))


    local function _dump(value, desciption, indent, nest, keylen)
        desciption = desciption or "<var>"

        local spc = ""

        if type(keylen) == "number" then
            spc = string_rep(" ", keylen - string_len(_dump_value(desciption)))
        end

        if _dump_value(desciption) == "\"class\"" then
            
        elseif type(value) ~= "table" then
            result[#result +1 ] = table_format("%s%s%s = %s", indent, _dump_value(desciption), spc, _dump_value(value))
        else
            lookup[tostring(value)] = true
            if nest > nesting then
                result[#result +1 ] = table_format("%s%s = *MAX NESTING*", indent, _dump_value(desciption))
            else
                result[#result +1 ] = table_format("%s%s = {", indent, _dump_value(desciption))
                local indent2 = indent.."    "
                local keys = {}
                local keylen = 0
                local values = {}
                for k, v in pairs(value) do
                    keys[#keys + 1] = k
                    local vk = _dump_value(k)
                    local vkl = string_len(vk)
                    if vkl > keylen then keylen = vkl end
                    values[k] = v
                end
                table.sort(keys, function(a, b)
                    if type(a) == "number" and type(b) == "number" then
                        return a < b
                    else
                        return tostring(a) < tostring(b)
                    end
                end)
                for i, k in ipairs(keys) do
                    _dump(values[k], k, indent2, nest + 1, keylen)
                end
                result[#result +1] = table_format("%s}", indent)
            end
        end
    end
    _dump(value, desciption, " ", 1)

    return result
end


local function checkArgType(arg)
    if type(arg) == "table" then
        local result = dump(arg, "table_table", 10)
        if result then
            arg = table.concat(result, "\n")
        else
            arg = ""
        end
    else
        arg = tostring(arg)
    end

    return arg
end

local function concat(...)
    local tb = {}
    for i=1, select('#', ...) do
        local arg = select(i, ...)  

        tb[#tb + 1] = checkArgType(arg)
    end
    return table.concat(tb, "\t")
end

function log.dump(tbl, tag)
    if Application.isMobilePlatform then
        -- return
    end
    print("[LOG DUMP]" ..(tag or ""), concat(tbl))
end

function log.green(...)
    print(string.format("<color=#00FF00>%s</color>", concat(...)))
end

function log.blue(...)
    print(string.format("<color=#00FFFF>%s</color>", concat(...)))
end

function log.w(...)
    print(string.format("<color=#FF00FF>%s</color>", concat(...)))
end


-- local f_name = nil
-- local text_name = nil

-- if Application.isMobilePlatform then
--     f_name = Application.persistentDataPath .."/"..os.date("%y%m%d-%H%M%S", os.time()) ..".log"  
--     text_name = Application.persistentDataPath .."/files.txt"
--     print("text_name2222", text_name)
-- else
--     os.execute("mkdir log\\")
--     f_name = "log/" ..os.date("%y%m%d-%H%M%S", os.time()) ..".log"
--     text_name = "log/files.txt"
--     print("text_name11", text_name)
-- end


-- local f = io.open(text_name, "a+")
-- f:write(f_name .."\n")
-- f:close()

-- function log.write(op, desc)
--     local f = io.open(f_name, "a+")
--     f:write(string.format("[%s] %s: %s\n", os.date("%H:%M:%S", os.time()), op, desc))
--     f:close()
-- end

-- function log.get_files()
--     local f = io.open(text_name, "r")
--     local line = f:read()--读取文件中的单行内容存为另一个变量

--     local str_lines = {}
--     while line do
--         str_lines[#str_lines + 1] = line
--         line = f:read()
--     end

--     return table.concat(str_lines, "\n")
-- end

-- function log.get_log_content(name)
--     if Application.isMobilePlatform then
--         name = Application.persistentDataPath .."/" ..name
--     else
--         name = name
--     end
--     print("name", name)

--     local f = io.open(name, "r")
--     local line = f:read()--读取文件中的单行内容存为另一个变量

--     local str_lines = {}
--     while line do
--         str_lines[#str_lines + 1] = line
--         line = f:read()
--     end

--     return table.concat(str_lines, "\n")
-- end


