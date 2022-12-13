--
-- Author: soul
-- Date: 2021/7/15 17:26:20
-- Brief: 
--

local opt = {}
declare("opt", opt)

opt.empty_func = function() end
opt.empty_func_true = function() return true end

--//
opt.array_arg1 = {0}
local mt1 = {
    __call = function(t, v1)
        t[1] = v1
        return t
end
}
setmetatable(opt.array_arg1, mt1)

--//
opt.array_arg2 = {0, 0}
local mt2 = {
    __call = function(t, v1, v2)
        t[1] = v1
        t[2] = v2
        return t
    end
}
setmetatable(opt.array_arg2, mt2)

--//
opt.array_arg3 = {0, 0, 0}
local mt3 = {
    __call = function(t, v1, v2, v3)
        t[1] = v1
        t[2] = v2
        t[3] = v3
        return t
    end
}
setmetatable(opt.array_arg3, mt3)

--//
opt.array_arg4 = {0, 0, 0, 0}
local mt4 = {
    __call = function(t, v1, v2, v3, v4)
        t[1] = v1
        t[2] = v2
        t[3] = v3
        t[4] = v4
        return t
    end
}
setmetatable(opt.array_arg4, mt4)

--//
opt.array_arg5 = {0, 0, 0, 0, 0}
local mt5 = {
    __call = function(t, v1, v2, v3, v4, v5)
        t[1] = v1
        t[2] = v2
        t[3] = v3
        t[4] = v4
        t[5] = v5
        return t
    end
}
setmetatable(opt.array_arg5, mt5)

opt.rgba_args = {
    r = 1,
    g = 1,
    b = 1,
    a = 1
}
setmetatable(opt.rgba_args, {
    __call = function(t, r, g, b, a)
        t.r = (r or 255) / 255
        t.g = (g or 255) / 255
        t.b = (b or 255) / 255
        t.a = (a or 255) / 255
        return t
    end
})


return opt