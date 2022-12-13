--
-- Author: soul
-- Date: 2021/1/21 11:49:8
-- Brief: 
--

local cache = {}

function memoize(key, func)
    return function (...)
        if cache[key] then
            return cache[key]
        else
            local y = func(...)
            cache[key] = y
            return y
        end
    end
end