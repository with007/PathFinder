local table, string, math = table, string, math
local GameObject, LuaUnity, Types, ResHelper, CNull = GameObject, LuaUnity, Types, ResHelper, CNull
local requireLua = requireLua

local M = {}
declare("UIManager", M)

local UIManagerDefine = requireLua("UIManagerDefine")

local new_table = require("table.new")
local clear_table = require("table.clear")

local _opened_dict = new_table(0, 16)
local _invisibled_dict = new_table(0, 8)
local _pop_positon_dict = new_table(0, 16)

local _panels_list = new_table(16, 0)
local _last_panels_list = new_table(4, 0)

local _widget_pool = {}

-- do not show the same text closely
local lastToastText

-- track block count
local blockCount = 0

--// 频繁会打开的面板，不会真正移除
--// 避免频繁的创建、移除
--// 此类面板在编写时，需要注意移除上次残留的UI
--// 尚未完全测试
local KEEP_PANEL_DICT = UIManagerDefine.KEEP_PANEL_DICT

M.Type = {
    normal          = 0,

    panel_full      = 1,
    panel_modal     = 2,
    panel_top       = 9,

    pool            = 101
}

M.BindObjTypes = {
    tfm = Types.Transform[1],
    btn = Types.Button[1],
    txt = Types.Text[1],
    img = Types.Image[1],
    scr = Types.ScrollRect[1],
    sld = Types.Slider[1],
    inp = Types.InputField[1]
}

M._lbRoot = nil

--// 返回到上个fitpanel
local function _find_last_fit_panels()
    clear_table(_last_panels_list)
    
    local c = #_panels_list
    for i = c, 1, -1 do
        local lb = _panels_list[i]
        if lb.__prefabArg.type == M.Type.panel_full then
            _last_panels_list[#_last_panels_list + 1] = _panels_list[i]
            break

        elseif lb.__prefabArg.type == M.Type.panel_modal then
            _last_panels_list[#_last_panels_list + 1] = _panels_list[i]
        end
    end

    return _last_panels_list
end

local function _get_parent(prefabArg)
    local prefabType = prefabArg.type
    if prefabType == M.Type.panel_full then
        return M._lbRoot._currentCanvasFit

    elseif prefabType == M.Type.panel_modal then
        return M._lbRoot._currentCanvasModal

    elseif prefabType == M.Type.panel_top then
        return M._lbRoot._currentCanvasTop
    end
end

local function _get_widget_obj(widgetId)
    local pool = table.get(_widget_pool, widgetId)
    local widget = pool[#pool]
    if widget and not CNull(widget.gameObject) then
        pool[#pool] = nil
        return widget
    end
end

local function _start_lifecycle(lb)
    if lb.OnEnter then
        lb:OnEnter()
    end

    if lb.__isNotComponent then
        -- simulate life cycle methods
        if lb.Start then lb:Start() end
    end
end

function M.initCanvas(lbRoot)
    M._lbRoot = lbRoot
    M._invisibleRoot = lbRoot._invisiblePool
    M._lbRoot._guideText.gameObject:SetActive(not AppConst.Release)
end

function M.getCanvasSize()
    local canvasTf = M._lbRoot._currentCanvas
    local size = canvasTf.sizeDelta
    return size.x, size.y
end

function M.isPanel(prefabType)
    return prefabType >= M.Type.panel_full and prefabType <= M.Type.panel_top
end

function M.bindObjects(lb, root)
    root = root or lb.gameObject

    local tf = root.transform
    local count = tf.childCount
    local types = M.BindObjTypes
    for i = 0, count - 1 do
        local childTf = tf:GetChild(i)
        local childGo = childTf.gameObject
        local name = childGo.name
        if name[1] == "_" then
            local t = types[name:sub(2, 4)]
            lb[name] = (t and childGo:GetComponent(t) or childGo)
        end

        M.bindObjects(lb, childGo)
    end
end

function M.load(prefabArg, ...)
    local lb
    if prefabArg.__cname then
        -- the panel is based on lua script instead of LuaBehaviour component
        lb = prefabArg
        prefabArg = prefabArg.__prefabArg

        lb.__isNotComponent = true
    end

    local go = LuaUnity.createGameObject(prefabArg, _get_parent(prefabArg))
    if lb == nil then
        lb = go:GetComponent("LuaBehaviour").luaTable
        if lb == nil then
            local child = go.transform:GetChild(0)
            child:SetParent(_get_parent(prefabArg))
            GameObject.Destroy(go)
            go = child.gameObject
            lb = go:GetComponent("LuaBehaviour")
            if _pop_positon_dict[prefabArg.id] then
                _pop_positon_dict[child.name] = _pop_positon_dict[prefabArg.id]
            end
        end
        lb.__prefabArg = prefabArg

    else
        lb.args = {gameObject = go}
    end

    lb.__pid = prefabArg.id

    if lb.__isNotComponent then
        -- call at first load
        lb:Awake()
    end

    if lb.initUI then
        lb:initUI(...)
    end

    _start_lifecycle(lb)
    return lb
end

function M.unload(lb, isDestroy)
    if lb == nil or CNull(lb.gameObject) then return end

    if isDestroy == nil then isDestroy = true end

    if lb.OnExit then
        lb:OnExit()
    end
   
    if isDestroy then
        if lb.__isNotComponent then
            -- simulate life cycle methods
            lb:OnDestroy()
        end

        GameObject.Destroy(lb.gameObject)
        ResHelper.ForceUnloadAssets(lb.__prefabArg.path)
    end
end

function M.openPanel(prefabArg, ...)
    local arg = prefabArg.__prefabArg or prefabArg

    print("openPanel", arg.id)

    local prefabType = arg.type
    if not M.isPanel(prefabType) then
        print(arg.id .." is not a valid PANEL type!")
        return

    elseif prefabType == M.Type.panel_full then
        if _opened_dict[arg.id] then
            print(arg.id .." is opened!")
            return
        end
    end

    local lb = _invisibled_dict[prefabArg.id]
    if lb == nil then
        lb = M.load(prefabArg, ...)

        --pop animation
        local content = lb.transform:Find("content")
        if content ~= nil then
            lc.setLocalScale(content.transform, 0)
            local seq = DOTween.Sequence()
            if not _pop_positon_dict[prefabArg.id] then
                seq:Append(content.transform:DOScale(1.2, 0.2))
            end
            seq:Append(content.transform:DOScale(1, 0.2))

            local black = lb.transform:Find("black")
            if black then
                local blackImg = black:GetComponent("Image")
                if blackImg then
                    local orColor = blackImg.color
                    local color = blackImg.color
                    color.a = 0
                    blackImg.color = color
                    blackImg:DOColor(orColor, 0.3)
                end
                local blackBtn = black:GetComponent("Button")
                if not blackBtn then
                    blackBtn = black.gameObject:AddComponent(typeof(UnityEngine.UI.Button))
                end
                lb:setClick(blackBtn, function()
                    UIManager.closePanel(lb)
                end)
                local pressAction = black:GetComponent("OnButtonPressAction")
                GameObject.Destroy(pressAction)
            end
        end

    else
        lb.transform:SetParent(_get_parent(prefabArg))
        lb._isInvisible = false

        if lb.OnResume then
            lb:OnResume(...)
        end

        _start_lifecycle(lb)
    end

    if prefabType == M.Type.panel_full then
        local panels = _find_last_fit_panels()
        for i = 1, #panels do
            local panel = panels[i]
            panel.transform:SetParent(M._invisibleRoot)
            if panel.OnPause then
                panel:OnPause()
            end
        end
    end

    if _opened_dict[lb.__pid] then
        lb.__prevPanel = _opened_dict[lb.__pid]
    end

    _opened_dict[arg.id] = lb
    _panels_list[#_panels_list + 1] = lb
    return lb
end

function M.closePanelById(pid, destroyFlag)
    print("closePanelById", pid, _opened_dict[pid])
    if _opened_dict[pid] then
        M.closePanel(_opened_dict[pid], destroyFlag)
    end
end

function M.closeTipPanel()
    if UIManager._tipPanel then
        UIManager.closePanel(M._tipPanel)
        UIManager._tipPanel = nil
    end
end

function M.closePanel(panel, destroyFlag)
    if panel == nil or CNull(panel.gameObject) then return end

    local pid = panel.__pid
    local path = panel.__prefabArg.path

    print("closePanel", pid)

    local callBack = function()
        if panel.OnExit then
            panel:OnExit()
        end

        if KEEP_PANEL_DICT[pid] then
            panel._isInvisible = true
            panel.transform:SetParent(M._invisibleRoot)
            _invisibled_dict[pid] = panel
        elseif destroyFlag then
            GameObject.Destroy(panel.gameObject)
            ResHelper.ForceUnloadAssets(path)
        else
    -- #if __WIN32__
            while true do
                if C._config.reloadOpenPanel then
                    GameObject.Destroy(panel.gameObject)
                    ResHelper.ForceUnloadAssets(path) 
                    break
                end
    -- #endif
    
                GameObject.Destroy(panel.gameObject)
                ResHelper.ForceUnloadAssets(path)
                
    -- #if __WIN32__
                break
            end
    -- #endif
        end
    
        _opened_dict[pid] = panel.__prevPanel
        table.erase(_panels_list, panel)
    end

    local openLastPanelCallback = function(firstOpen)
        if firstOpen then
            _opened_dict[pid] = panel.__prevPanel
            table.erase(_panels_list, panel)
        end
        --// 重新上一个隐藏的面板
        if panel.__prefabArg.type == 1 then
            local panels = _find_last_fit_panels()
            for i = #panels, 1, -1 do
                local panel = panels[i]
                panel.transform:SetParent(_get_parent(panel.__prefabArg))
                if firstOpen then
                    panel.transform:SetSiblingIndex(0)
                end
                if panel.OnResume then
                    panel:OnResume()
                end
            end
        end    
    end

    if destroyFlag then
        callBack()
        openLastPanelCallback()
    else
        local content = panel.transform:Find("content")
        if content ~= nil then
            lc.setLocalScale(content.transform, 1)
            local seq = DOTween.Sequence()
            if _pop_positon_dict[panel.__cname] then
                local position = _pop_positon_dict[panel.__cname]
                content:DOMove(position, 0.2):SetEase(DG.Tweening.Ease.OutSine)
            else
                seq:Append(content.transform:DOScale(1.2, 0.2))
            end
            
            seq:Append(content.transform:DOScale(0, 0.2))
            if panel.__prefabArg.delayLastPanel then
                if M._delayLastPanelTime then
                    Timer.Stop(M._delayLastPanelTime)
                    M._delayLastPanelTime = nil
                    seq:AppendCallback(function() 
                        callBack()
                    end)
                else
                    openLastPanelCallback(true)
                    seq:AppendCallback(function() 
                        callBack()
                    end)
                end
            else
                seq:AppendCallback(function() 
                    callBack()
                    openLastPanelCallback()
                end)
            end
            
            local black = panel.transform:Find("black")
            if black then
                local blackImg = black:GetComponent("Image")
                if blackImg then
                    local color = blackImg.color
                    color.a = 0
                    blackImg:DOColor(color, 0.4)
                end
            end
        else
            callBack()
            openLastPanelCallback()
        end
    end
end

function M.clear()
    M.clearCanvas()
end

function M.clearCanvas()
    V.hideTopMaskHoldOn()
    if _opened_dict then
        for key, value in pairs(_opened_dict) do 
            if value.__prefabArg.type ~= 9 then
                M.closePanelById(key, true)
            end
        end
    end
end

function M.getTopPanel(isGetTabArea)
    local panel = B._battleManager._battlePanel and B._battleManager._battlePanel or _panels_list[#_panels_list]
    return isGetTabArea and panel and panel._lbTabArea or panel
end

function M.getTopPanelID(isGetTabArea)
    local topPanel = UIManager.getTopPanel(isGetTabArea)
    if topPanel == nil then return end
    return topPanel.__prefabArg and topPanel.__prefabArg.id or topPanel.__cname
end

function M.getWidget(prefabArg, ...)
    local arg = prefabArg.__prefabArg or prefabArg
    local lb = _get_widget_obj(arg.id)
    if lb == nil then
        lb = M.load(prefabArg, ...)
    else
        lb.gameObject:SetActive(true)

        if lb.updateUI then
            lb:updateUI(...)
        end

        _start_lifecycle(lb)
    end

    return lb
end

function M.recycleWidget(widget)
    if widget.transform.parent == M._lbRoot._widgetPool.transform then return end

    local go = widget.gameObject
    go:SetActive(false)
    LuaUnity.addChildToParent(go, M._lbRoot._widgetPool)
    
    local pool = table.get(_widget_pool, widget.__pid)
    pool[#pool + 1] = widget
end

function M.toast(text)
    if text == lastToastText then
        return
    end

    lastToastText = text
    M.openPanel(requireLua("ToastPanel").create(), text)
end

function M.toastItemLack(id)
    local text = string.formatOrder(STR.NOT_ENOUGH, STR[D._itemConfig[id]._nameSid])
    M.toast(text)
end

function M.showSimpleMsgBox(text, cbOk)
    return M.showMsgBox(STR.MESSAGE, text, cbOk)
end

function M.showMsgBox(title, text, cbOk, cbCancel)
    local msgBox = requireLua("MessageBoxPanel").create():show(title, text)
    msgBox:setCallback(cbOk, cbCancel)
    return msgBox
end

function M.blockTouch(isBlock)
    if isBlock then
        blockCount = blockCount + 1
        M._lbRoot._topMask:SetActive(isBlock)

    else
        blockCount = math.max(blockCount - 1, 0)
        if blockCount == 0 then
            M._lbRoot._topMask:SetActive(isBlock)
        end
    end
end

function M.getCertainPanel(id)
    if id == "BattlePanel" then
        return B._battleManager._battlePanel
    end
    for i = 1, #_panels_list do
        local topPanelArg = _panels_list[i].__prefabArg
        if topPanelArg.id == id then
            return _panels_list[i]
        end
    end
end

function M.isMessageBoxShowing()
    return M._msgBoxPanelLB and not _invisibled_dict[PrefabDefine.MessageBoxPanel.id] and not CNull(M._msgBoxPanelLB.gameObject) and M._msgBoxPanelLB.gameObject.activeSelf
end

function M.checkPanelOpen(prefabArg)
    if _opened_dict[prefabArg.id] then
        return true
    end
    return false
end

function M.openSpecialOfferPanel(position)
    local newBie = ShopProxy.getNewBieGiftBag()
    if not newBie then
        return
    end
    local giftInfo = D._giftBagConfig[newBie.show_id]
    local lb
    local id = tonumber(giftInfo._pict)
    if id == 1 then
        lb = UIManager.openPopPanel(PrefabDefine.SpecialOfferPanel1, position)
        -- lb = UIManager.openPanel(PrefabDefine.SpecialOfferPanel1)
    elseif id == 2 then
        lb = UIManager.openPopPanel(PrefabDefine.SpecialOfferPanel2, position)
        -- lb = UIManager.openPanel(PrefabDefine.SpecialOfferPanel2)
    elseif id == 3 then
        lb = UIManager.openPopPanel(PrefabDefine.SpecialOfferPanel3, position)
        -- lb = UIManager.openPanel(PrefabDefine.SpecialOfferPanel3)
    end
end

function M.openRewardPanel(randomBooster, tempBooster)
    SimpleEvent.emit("reward.close")
    if #tempBooster == 1 then
        local item = D._itemConfig[tempBooster[1]]
        if item then
            if item._quality == D.BoosterQuality.bronze then
                UIManager.openPanel(PrefabDefine.RewardPanelBlue, randomBooster, tempBooster)
            elseif item._quality == D.BoosterQuality.silver then
                UIManager.openPanel(PrefabDefine.RewardPanelPurple, randomBooster, tempBooster)
            elseif item._quality == D.BoosterQuality.gold then
                UIManager.openPanel(PrefabDefine.RewardPanelOrange, randomBooster, tempBooster)
            elseif item._quality == D.BoosterQuality.diamond then
                UIManager.openPanel(PrefabDefine.RewardPanelRed, randomBooster, tempBooster)
            end
        end
    else
        UIManager.openPanel(PrefabDefine.RewardPanel, randomBooster, tempBooster)
    end
end

function M.openPiggyBank(position)
    local pig = PiggyBankProxy.getNormalPiggyBank()
    local pigData = PiggyBankProxy.getNormalPiggyBankData()
    if pigData.progress >= pig._rewardNum[2] then
        UIManager.openPopPanel(PrefabDefine.NormalPiggyBankPopPanel, position)
        -- UIManager.openPanel(PrefabDefine.NormalPiggyBankPopPanel)
    else
        UIManager.openPopPanel(PrefabDefine.NormalPiggyBankPanel, position)
        -- UIManager.openPanel(PrefabDefine.NormalPiggyBankPanel)
    end
end

function M.openPopPanel(prefabArg, position, ...)
    _pop_positon_dict[prefabArg.id] = position
    local lb = UIManager.openPanel(prefabArg, ...)
    if not lb then
        return
    end
    local content = lb.transform:Find("content")
    if content ~= nil then
        lc.setPosition(content, position)
        local centerW, centerH = Screen.width / 2, Screen.height / 2
        content:DOMove(Vector3.static(centerW, centerH, 0), 0.2):SetEase(DG.Tweening.Ease.OutSine)
    end
end

function M.getPopPosition(name)
    return _pop_positon_dict[name]
end

function M.setPopPosition(name, position)
    if not _pop_positon_dict[name] or _pop_positon_dict[name].x ~= position.x or _pop_positon_dict[name].y ~= position.y then
        _pop_positon_dict[name] = Vector3.create(position.x, position.y)
    end
end

return M