local M = {}

declare("CondMgr", M)

--[[--
配表类型：[S
配表写法：{"form": 101, "hero_level": 20} | {"form":101, "vip_level":3}
在101界面，英雄等级达到20级或vip等级达到3级，触发引导

cond参数结构：
table数组
{
		{form = 101, hero_level = 20},
		{form = 101, vip_level = 3}
}

只要数组中其中一个条件满足即可
--]]--

function M.isConditionArrayMet(conds)
    for i = 1, #conds do
    	if M.isConditionMet(conds[i]) then
      		return true
      	end
    end
  	return false
end

function M.isConditionMet(cond)
  	for k, v in pairs(cond) do
        if not M.CondCheck[k](v) then return false end
    end
  	return true
end

M.CondType = {
	close_panel 	= 2,
	open_panel 		= 3,
	temp_booster 	= 4,
	condition		= 5,
    
	wait = 11,
}

M.CondCheck = {
	[M.CondType.close_panel] = function(panelName)
		return panelName == GuideManager._conditionValue
    end,

	[M.CondType.open_panel] = function(panelName)
		return panelName == GuideManager._conditionValue
    end,

	[M.CondType.temp_booster] = function(booster)
		return booster == P._tempBooster
    end,

	[M.CondType.wait] = function()
		return true
    end,

	[M.CondType.condition] = function(val)
		return val == GuideManager._conditionValue
    end,
}

return M