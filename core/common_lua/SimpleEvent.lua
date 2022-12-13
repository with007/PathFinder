--
-- Author: soul
-- Date: 2019/10/8 10:4:23
-- Brief: 
--


local M = {}
declare("SimpleEvent", M)
--[[
SimpleEvent = M
]]

M._dictListeners = {}
M._funcId = 0

M._keeps = {}

function M.on(eventName, func, tag)
    local dictListeners = M._dictListeners
	if not dictListeners[eventName] then
		dictListeners[eventName] = {}
    end

    local listeners = dictListeners[eventName]

    M._funcId = M._funcId + 1

    listeners[#listeners + 1] = {
        M._funcId,
        func,
        tag,
    }

    return M._funcId
end

function M.once(eventName, func)
    M.remove(eventName)
    return M.on(eventName, func, "once")
end

function M.stash(eventName, val1, val2, val3, val4)
    if val1 == nil and val2 == nil and val3 == nil then
        if M._keeps[eventName] then
            return
        end
        M._keeps[eventName] = 1
        return
    end

    M._keeps[eventName] = {val1, val2, val3, val4}
end 

function M.flush()
    for eventName, v in pairs(M._keeps) do
        if type(v) == "number" then
            M.emit(eventName)
        else
            M.emit(eventName, v[1], v[2], v[3], v[4])
        end
    end

    M._keeps = {}
end

function M.emit(eventName, val1, val2, val3, val4)
    local dictListeners = M._dictListeners
    local listeners = dictListeners[eventName]
	if listeners == nil or #listeners == 0 then
		return
    end
    
    local tmp = {}
	for i = 1, #listeners do
		tmp[#tmp + 1] = listeners[i]
    end
    
    for i = 1, #tmp do
        local listener = tmp[i]
        listener[2](val1, val2, val3, val4)
    end
end

function M.remove(funcId)
    local dictListeners = M._dictListeners

    local breakFlag = false
    for eventName, listeners in pairs(dictListeners) do
		for i = #listeners, 1, -1 do
			if listeners[i][1] == funcId then
				table.remove(dictListeners[eventName], i)
				if #dictListeners[eventName] == 0 then
					dictListeners[eventName] = nil
                end
                breakFlag = true
				break
			end
        end
        if breakFlag then
            break
        end
	end
end

function M.removeByName(eventName)
    M._dictListeners[eventName] = nil
end

function M.removeAll()
    M._dictListeners = {}
end