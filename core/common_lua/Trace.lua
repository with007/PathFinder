--
-- Author: soul
-- Date: 2022/5/16 15:12:38
-- Brief: 
--

local M = {}
declare("Trace", M)
--[[
Trace = M  
]]

local GA_NewDesignEvent   = GameAnalyticsSDK.GameAnalytics.NewDesignEvent
local GA_NewAdEvent       = GameAnalyticsSDK.GameAnalytics.NewAdEvent
local GA_NewBusinessEvent = GameAnalyticsSDK.GameAnalytics.NewBusinessEvent
local GA_NewResourceEvent = GameAnalyticsSDK.GameAnalytics.NewResourceEvent
local GA_NewProgressionEvent = GameAnalyticsSDK.GameAnalytics.NewProgressionEvent

local GA_Progress_Fail = GameAnalyticsSDK.GAProgressionStatus.Fail
local GA_Progress_Start     = GameAnalyticsSDK.GAProgressionStatus.Start
local GA_Progress_Complete  = GameAnalyticsSDK.GAProgressionStatus.Complete
local GA_Progress_Undefined  = GameAnalyticsSDK.GAProgressionStatus.Undefined




local GA_RewardedVideo    = GameAnalyticsSDK.GAAdType.RewardedVideo

local GA_AdAction_Clicked        = GameAnalyticsSDK.GAAdAction.Clicked
local GA_AdAction_RewardReceived = GameAnalyticsSDK.GAAdAction.RewardReceived
local GA_AdAction_Show           = GameAnalyticsSDK.GAAdAction.Show
local GA_AdAction_FailedShow     = GameAnalyticsSDK.GAAdAction.FailedShow

local SDKFlowType = GameAnalyticsSDK.GAResourceFlowType

local GA_FlowType_Sink   = SDKFlowType.Sink
local GA_FlowType_Source = SDKFlowType.Source

local AF_sendEvent = AppsFlyerSDK.AppsFlyer.sendEvent
local Fire_sendEvent = Firebase.Analytics.FirebaseAnalytics.LogEvent

local Dictionary_string_string = System.Collections.Generic.Dictionary_string_object

-- local List_Firebase_Analytics_Parameter = System.Collections.Generic.List_Firebase_Analytics_Parameter
-- local Firebase_Analytics_Parameter = Firebase.Analytics.Parameter

local launch_log_count = {
    [1] = true,
    [2] = true,
    [5] = true,
    [10] = true,
}

if not Application.isMobilePlatform then 
    AF_sendEvent = function() end
    -- Fire_sendEvent = function() end
end

function M.Frie_traceParamter(key, tbl)
    LuaHelper.LogFireEvent(key, tbl)
end

function M.GA_traceDesignEvent(key)
    GA_NewDesignEvent(key, 0)
    
    key = string.gsub(key, ":", "_")
    Fire_sendEvent(key)
end

function M.GA_traceProgressionEvent(type, str)
    GA_NewProgressionEvent(type, str)
end

function M.GA_traceAdEvent(adUnitId, action)
    GameAnalyticsSDK.GameAnalytics.NewAdEvent(action, GA_RewardedVideo, "MAX" , adUnitId)
end


-----------------------------------------Universal relate----------------------------------------
---
function M.traceDesign(str, ...)
    if P._activityMode > 0 then
        local index = string.find(str, ":")
        if index and index > 0 and string.find(str, "Event") == nil then
            str = string.gsub(str,":", "_Event:")
        end
    end
    local str = string.format(str, ...)
    M.GA_traceDesignEvent(str)
end


function M.traceShopClick(id)
    Trace.traceDesign("Shop:%s_%s", P:getModeTraceName(), id)
end

---
-- 当天登录次数 Launch:{Count}
function M.traceLaunchCount()
    local cnt = P:getTodayLaunchCount()
    M.GA_traceDesignEvent(string.format("Launch:%d", cnt))
    -- if launch_log_count[cnt] then
    --     M.GA_traceDesignEvent(string.format("Launch:%d", cnt))
    -- end
    -- M.AF_traceRerention()
end

-- -- 通关时间计算 PassTime:{IslandID}:{Count}
-- function M.traceIslandPassTime()
--     local IslandID = P:getIslandIndex()
--     local d, h, m, s = lc.getTimeEndArgs(math.floor(C.getCurTime() - P._playerIsland._firstLandTime))
--     local CompleteTime = string.format("%dD%dH%dM%dS", d, h, m, s)

--     local str = string.format("PassTime:%d:%s", IslandID, CompleteTime)
--     log.blue(str)
--     M.GA_traceDesignEvent(str)
-- end

-----------------------------------------Guide relate--------------------------------------------
--引导打点GuideStep:{ID}
function M.traceGuideStep(currStep)
    M.GA_traceDesignEvent(string.format("GuideStep:%d", currStep))
end

-----------------------------------------Island relate--------------------------------------------

--玩家驻留状态
-- PlayerStay:{IslandID}:{LastStayAreaID}:{YellowGridNum}:{WorkerLevel}
-- function M.traceLastStayAreaID()
--     local IslandID = P:getIslandIndex()
--     local LastStayAreaID = P._playerIsland._areaIndex
--     local YellowGridNum = P._playerIsland:getLeftYellowGridNum()
--     local WorkerLevel = P._playerIsland:getWorkersLevelStr()

--     local str = string.format("PlayerStay:%d:%d:%d:%s",IslandID, LastStayAreaID, YellowGridNum, WorkerLevel)
--     -- local str = string.format("PlayerStay..%d_%d",IslandID, LastStayAreaID)
--     -- M.GA_traceProgressionEvent(GA_Progress_Fail, str)

--     M.GA_traceDesignEvent(str)
-- end


-- 通关状态
-- PassStatus:{IslandID}:{YellowGridNum}:{WorkerLevel}
-- function M.traceIslandLevel()
--     local IslandID = P:getIslandIndex()
--     local YellowGridNum = P._playerIsland:getLeftYellowGridNum()
--     local WorkerLevel = P._playerIsland:getWorkersLevelStr()

--     local str = string.format("PassStatus:%d:%d:%s",IslandID,  YellowGridNum, WorkerLevel)
--     -- M.GA_traceProgressionEvent(GA_Progress_Complete, str)
--     M.AF_traceStage(IslandID)
--     M.GA_traceDesignEvent(str)

-- end

-- 砍树开始{TargetType}：1树，2森林，3码头
-- TargetStart:{IslandID-AreaID-GridID}
function M.traceCutTreeStart(tree)
    local IslandID = P:getTraceIslandIndex()
    local AreaId = P._playerIsland._areaIndex
    local GridId = tree._id

    local str = string.format("%sStart:%s_%s_%s", tree:toTraceName(), IslandID,  AreaId, GridId)
    if P._activityMode == 0 and P:getIslandIndex() > 10 and tree._treeType == D.TreeType.tree then
        return
    end
    M.GA_traceDesignEvent(str)
end

-- 砍树结束{TargetType}：1树，2森林，3码头
-- TargetEnd:{IslandID-AreaID-GridID}
function M.traceCutTreeDown(tree)
    local IslandID = P:getTraceIslandIndex()
    local AreaId = P._playerIsland._areaIndex
    local GridId = tree._id
    local str = string.format("%sEnd:%s_%s_%s", tree:toTraceName(), IslandID,  AreaId, GridId)
    if P._activityMode == 0 and P:getIslandIndex() > 10 and tree._treeType == D.TreeType.tree then
        return
    end
    M.GA_traceDesignEvent(str)
end

-----------------------------------------Cut Tree relate--------------------------------------------

M.worker_getType = {
    ["buy"] = 1,
    ["box"] = 2,
    ["monster"] = 3,
    ["tent"] = 4,
    ["merge"] = 5
}

-- 获得伐木工
-- {Type}:1购买，2木箱，3野兽，4帐篷，5合成
-- WorkerGet:{IslandID-AreaID}:{WorkerLevel}:{Type}
-- function M.traceWorkerGet(level, getType)
--     local IslandID = P:getIslandIndex()
--     local AreaId = P._playerIsland._areaIndex
--     local WorkerLevel = level

--     M.GA_traceDesignEvent(string.format("WorkerGet:%d_%d:%d:%d", P:getIslandIndex(), AreaId,  WorkerLevel, getType))
-- end

--野兽状态
-- BeastKill:{IslandID-AreaID-GridID}
function M.traceBeastStatus(EventName, beast)
    local IslandID = P:getTraceIslandIndex()
    local AreaId = P._playerIsland._areaIndex
    local GridId = beast._id 

    M.GA_traceDesignEvent(string.format("%s:%s_%s_%s", EventName, IslandID, AreaId, GridId))
end

-----------------------------------------Res   relate--------------------------------------------
local res_name = {
    [20000] = "gem",
    [20001] = "coin",
    [20002] = "crystal",
    [20003] = "energy",
    [20004] = "advExp",
    [20010] = "superGene",
    [20011] = "normalKey",
    [20012] = "advancedKey",
    [20013] = "revivalCoin",
    [20021] = "weaponDesign",
    [20022] = "carrierDesign",
    [20023] = "headgearDesign",
    [20024] = "stapleFoodDesign",
    [20025] = "beverageDesign",
    [20026] = "snackDesign",
    [20030] = "oneHCoin",
}

function M.traceResChanged(itemId, amount, logWay, isSub, totalNum)
    if res_name[itemId] == nil then
        return
    end
    -- #if __DEBUG__
        assert(logWay ~= nil, "资源logway缺失")
    -- #endif
    logWay = logWay or D.logWay.unknow
    local flowType = (isSub and GA_FlowType_Sink or GA_FlowType_Source)
    GA_NewResourceEvent(flowType, res_name[itemId], amount, res_name[itemId], logWay)
    -- M.AF_traceResource(res_name[itemId], isSub and 2 or 1, amount, totalNum, logWay)
end

-- 飞锯获得 Flysaw_Get:{IslandID-AreaID}:{FlysawLevel}:{Type}
-- 飞锯砍树消耗 Flysaw_Consum:{IslandID-AreaID-GridID}:{FlysawLevel}:{TreeLevel}
-- function M.traceSawChanged(isSub, FlysawLevel, getTypeOrtreeLevel, gridIndex)
--     local IslandID = P:getIslandIndex()
--     local AreaId = P._playerIsland._areaIndex

--     if isSub then
--         M.GA_traceDesignEvent(string.format("Flysaw_Consum:%d_%d_%d:%d:%d",IslandID, AreaId, gridIndex, FlysawLevel, getTypeOrtreeLevel))
--     else
--         M.GA_traceDesignEvent(string.format("Flysaw_Get:%d_%d:%d:%d",IslandID, AreaId, FlysawLevel, getTypeOrtreeLevel))
--     end
-- end

-- 帐篷获得 Tent_Get:{IslandID-AreaID}
-- 帐篷消耗 Tent_Consum:{IslandID-AreaID}
-- 木箱获得	Woodenchest_Get:{IslandID-AreaID}
-- 木箱消耗	Woodenchest_Consum:{IslandID-AreaID}
-- function M.traceTimingRewardChanged(isSub, type)
--     local IslandID = P:getIslandIndex()
--     local AreaId = P._playerIsland._areaIndex
--     local eventName
--     if isSub then
--         eventName = "_Consum"
--     else
--         eventName = "_Get"
--     end

--     if type == D.TimingReward.BonusBox then
--         eventName = "Woodenchest"..eventName
--         M.GA_traceDesignEvent(string.format("%s:%d_%d",eventName, IslandID, AreaId))
--     elseif type == D.TimingReward.Tent then
--         eventName = "Tent"..eventName
--         M.GA_traceDesignEvent(string.format("%s:%d_%d",eventName, IslandID, AreaId))
--     end
-- end

-- -- 码头 WharfUpgrade:{IslandID}:{WharfLevel}
-- function M.traceWharfLevel()
--     local IslandID = P:getIslandIndex()
--     local wharfLevel = P._playerIsland._islandWharfSys:getCurrWharfLevel()
--     M.AF_traceUpgrade("wharfIn", wharfLevel)
--     M.GA_traceDesignEvent(string.format("WharfUpgrade:%d:%d",IslandID, wharfLevel))
-- end


------------------------------------------------------------------------------------------------------------------------------------old trace


-------------------------------------------Ad  relate---------------------------------------------

function M.traceAdClicked(adUnitId)
    -- M.GA_traceAdEvent(D.ADName[adUnitId], GA_AdAction_Clicked)
    M.AF_traceKey("e03_clickreward")
    M.AF_traceAd("click", D.ADName[adUnitId])
end

function M.traceAdRewardReceived(adUnitId)
    -- M.GA_traceAdEvent(D.ADName[adUnitId], GA_AdAction_RewardReceived)
    M.AF_traceKey("e03_receviedreward")
end

--@adName 字符串事件名称
function M.traceAdShow(adName)
    -- M.GA_traceAdEvent(D.ADName[adUnitId], GA_AdAction_Show)
    M.AF_traceAd("rewarded", adName)
end

--@adName 字符串事件名称
function M.traceAdFail(adName)
    -- M.GA_traceAdEvent(D.ADName[adUnitId], GA_AdAction_FailedShow)
    M.AF_traceAd("e_ad_fail", adName)
end

function M.traceIapPurchased(iapId)
    local iapCfg = D._iapConfig[iapId]
    local dollorNum = iapCfg._USD
    GA_NewBusinessEvent("USD", dollorNum * 100, "default", "ShopIAP_"..iapCfg._event, "shop")
end

-- AppFlyer打点
function M.AF_traceEvent(eventName, data)
    data = data or {}
    local param = Dictionary_string_string.New()
    for _, info in ipairs(data) do
        -- print("logAppsFlyerEvent------", eventName, info._key, info._value)
        param:Add(info._key, info._value)
    end
    -- print("logAppsFlyerEvent------", eventName)
    AF_sendEvent(eventName, param)
end

local emptyDict = Dictionary_string_string.New()

function M.AF_traceKey(eventName)
    AF_sendEvent(eventName, emptyDict)
end

local e_stage_values = {
    {_key = "stageId", _value = 0},
    {_key = "version", _value = 0},
}

function M.AF_traceStage(stage)
    e_stage_values[1]._value = stage or P:getIslandIndex()
    e_stage_values[2]._value = Client.getVersion()
    M.AF_traceEvent("e_stage", e_stage_values)
end

local e_upgrade_values = {
    {_key = "stageId", _value = 0},
    {_key = "version", _value = 0},
    {_key = "target", _value = 0},
    {_key = "level", _value = 0},
}

function M.AF_traceUpgrade(target, level)
    e_upgrade_values[1]._value = P:getIslandIndex()
    e_upgrade_values[2]._value = Client.getVersion()
    e_upgrade_values[3]._value = target
    e_upgrade_values[4]._value = level
    M.AF_traceEvent("e_upgrade", e_upgrade_values)
end

local e_ad_values = {
    {_key = "stageId", _value = 0},
    {_key = "version", _value = 0},
    {_key = "type", _value = 0},
    {_key = "placement", _value = 0},
}
function M.AF_traceAd(type, placement)
    e_ad_values[1]._value = P:getIslandIndex()
    e_ad_values[2]._value = Client.getVersion()
    e_ad_values[3]._value = type
    e_ad_values[4]._value = placement
    M.AF_traceEvent("e_ad", e_ad_values)
end

local e_resource_values = {
    {_key = "stageId", _value = 0},
    {_key = "version", _value = 0},
    {_key = "resourceId", _value = 0},
    {_key = "type", _value = 0},
    {_key = "num", _value = 0},
    {_key = "totalNum", _value = 0},
    {_key = "placement", _value = 0},
}
function M.AF_traceResource(resourceId, type, num, totalNum, placement)
    e_resource_values[1]._value = P:getIslandIndex()
    e_resource_values[2]._value = Client.getVersion()
    e_resource_values[3]._value = resourceId
    e_resource_values[4]._value = type
    e_resource_values[5]._value = num
    e_resource_values[6]._value = totalNum
    e_resource_values[7]._value = placement
    M.AF_traceEvent("e_resource", e_resource_values)
end

local e_session_values = {
    {_key = "type", _value = 0},
    {_key = "elapsedTime", _value = 0},
}
function M.AF_traceSession(type, elapsedTime)
    e_session_values[1]._value = type
    e_session_values[2]._value = elapsedTime
    M.AF_traceEvent("e_session", e_session_values)
end

local e_ad_revenue_values = {
    {_key = "type", _value = 0},
    {_key = "revenue", _value = 0},
    {_key = "network", _value = ""},
}

function M.AF_traceAdRevenue(type, revenue, network)
    e_ad_revenue_values[1]._value = type
    e_ad_revenue_values[2]._value = revenue
    e_ad_revenue_values[3]._value = network
    M.AF_traceEvent("e_ad_revenue", e_ad_revenue_values)
end


local af_purchase_values = {
    {_key = "af_currency", _value = "USD"},
    {_key = "af_quantity", _value = 1},
    {_key = "af_revenue", _value = 0},
}

local e_purchase_values = {
    {_key = "stageId", _value = 0},
    {_key = "version", _value = 0},
    {_key = "money", _value = 0},
    {_key = "purchase", _value = ""},
}

function M.AF_tracePurchase(price, productName)
    af_purchase_values[3]._value = price
    M.AF_traceEvent("af_purchase", af_purchase_values)

    e_purchase_values[1]._value = P:getIslandIndex()
    e_purchase_values[2]._value = Client.getVersion()
    e_purchase_values[3]._value = price
    e_purchase_values[4]._value = productName
    M.AF_traceEvent("e_purchase", e_purchase_values)
end

function M.AF_traceRerention()
    local days = lc.getIntKeyValue("launch.days.continuous", 1)

    local nowDayOffset = Client.getDayOffset()
    local lastDayOffset = lc.getIntKeyValue("last.launch.time", nowDayOffset)

    lc.setIntKeyValue("last.launch.time", nowDayOffset)

    if (nowDayOffset - lastDayOffset) == 1 then
        days = days + 1
        lc.setIntKeyValue("launch.days.continuous", days)
    end

    if days == 3 then
        M.AF_traceKey("e05_login3")
    elseif days == 7 then
        M.AF_traceKey("e05_login7")
    end
end

local af_order_values = {
    {_key = "stageId", _value = 0},
    {_key = "version", _value = 0},
    {_key = "orderId", _value = 0},
    {_key = "status", _value = "begin"},
    {_key = "type", _value = 0},
}

function M.traceOrder(orderId, status, type)
    af_order_values[1]._value = P:getIslandIndex()
    af_order_values[2]._value = Client.getVersion()
    af_order_values[3]._value = orderId
    af_order_values[4]._value = status
    af_order_values[5]._value = type
    M.AF_traceEvent("e_order", af_order_values)
end

local af_activity_values = {
    {_key = "stageId", _value = 0},
    {_key = "version", _value = 0},
    {_key = "EventId", _value = 0},
    {_key = "PlayTime", _value = 0},
    {_key = "StartTime", _value = 0},
    {_key = "Star", _value = 0},
    {_key = "Rank", _value = 0},
    {_key = "GoldenAxe", _value = 0},
}

function M.traceActivity()
    if P._activityMode > 0 then
        af_activity_values[1]._value = P:getIslandIndex()
        af_activity_values[2]._value = Client.getVersion()
        af_activity_values[3]._value = P._playerActivity._activityIndex
        af_activity_values[4]._value = math.ceil(P._playerIsland._activityPlayTime/60)
        af_activity_values[5]._value = math.ceil((C.getCurTime() - P._playerActivity._activityStartTimestamp)/60)
        af_activity_values[6]._value = P._playerActivity:getPlayerStarCount()
        af_activity_values[7]._value = P._playerActivity:getPlayerRankValue()
        af_activity_values[8]._value = P._playerActivity:getPlayerKeyCount()
        M.AF_traceEvent("e_activity", af_activity_values)
        print("traceActivity", unpack(af_activity_values))
    end
end

function M.logBusiness(eventName, data)
    data = data or {}
    M.AF_traceEvent(eventName, data)
end

function M.logDesign(eventName)
    M.GA_traceDesignEvent(eventName)
end