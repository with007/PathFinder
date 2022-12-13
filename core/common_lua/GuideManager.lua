local M = {}

declare("GuideManager", M)

local highLightMap = {}

--引导触发判定总入口
function M.tryStart(param)
    -- 引导禁用
    if M.isForbidGuide() then return end

	local stepId
	for type, newStepId in pairs(P._guideMap) do
	-- 引导已经结束
		if not M.isFinish(newStepId) then
			-- 触发器
			if M.isTrigger(newStepId, param) then
				stepId = newStepId
				break
			end
		end
	end

	-- 正在引导，不触发判定
	if M.isGuiding() and not(stepId and M.getParamJson(M._guideConfig[M._stepId]).isSoft) then
		if M._isWaitTrigger then
			if M.isTrigger(M._stepId, param) then
				M.doAfterTrigger()
				return true
			end
		end
	elseif stepId then
		M.start(stepId)
	end
	return true
end

function M.start(stepId)
	M.finishSoft()
	-- 开始当前引导组的第一步操作
	M._stepId = stepId
	M.step(stepId, true)
end

function M.initGuideId(pbGuideInfo)
	M.finish()

	for type, guideId in pairs(D._initGuideIdMap) do
		P:setGuideId(guideId)
	end
	local guideIds = pbGuideInfo.orderly_guide
	for _, guideId in ipairs(guideIds) do
		P:setGuideId(guideId)
	end
	
	M._stepId = nil

	M._guideConfig = C.getTestType() == 1 and D._guideStepConfigB or D._guideStepConfig
end

----------------------------------Is-------------------------
function M.isForbidGuide()
	if P == nil then
		return true
	end
	if C._isDisableGuide == 1 then
		return true
	end
	if C._config.forbid_guide then
		return true
	end
	return false
end

function M.isFinish(stepId)
	stepId = stepId or M._stepId
	return stepId and M._guideConfig[stepId] == nil
end

function M.isGuiding()
	return M._stepId and M._guideConfig[M._stepId]
end

function M.isTrigger(stepId, param)
	stepId = stepId or M._stepId
	local config = stepId and M._guideConfig[stepId]
	if config then
		local params = GuideManager.getParamJson(config)
		if params.trigger_panel then
			local topPanel = UIManager.getTopPanelID(true)
			if topPanel ~= params.trigger_panel then
				return false
			end
		end
		if params.trigger_guide then
			local type = D.getGuideType(params.trigger_guide)
			if P._guideMap[type] < params.trigger_guide then
				return false
			end
		end
		if params.trigger_condition and params.trigger_condition ~= param then
			return false
		end
		if params.trigger_unlock then
			if not UnlockProxy.checkUnlockById(params.trigger_unlock) then
				return false
			end
		end
	end
	return true
end

--是否满足条件,满足条件则进入下一步
function M.isAchieveCondition(conditionType, ...)
    if M._condition and M._conditionType == conditionType then
        if M._condition(...) then
			if M._conditionCallback then
				M._conditionCallback()
			end
            M.step()
			return true
        end
    end
end

function M.couldGotoBranch()
	if M._branchStepId and not M._enterBranch then
		M._enterBranch = true
		M._prevId = M._stepId -- 记录下跳转前的Id
		M.step(M._branchStepId)
		M._branchStepId = nil
		return
	end
end

function M.isGuidingBtnReceive()
	return M._isGuidingBtnReceive
end

--是否点击到了该按钮，若是则进入下一步(如果没有限制条件)
function M.isClickObject(btn)
	if M._clickInvalid then  --特殊处理,点击无效
		return
	end

	if M.isGuidingBtnReceive() then
		return
	end

	if M._currentBtn == btn then
		if M._condition == nil then
			M.step()
		end
	end
end

local checkByParam = function(param)
	if param == "win" then
		return BN._player._rank == 1
	elseif param == "lose" then
		return BN._player._rank ~= 1
	end
end
function M.getJumpId(config)
	local params = json.decode(config._jumpCondition).conditions
	local type = params.type
	local jumpId = nil
	for i = 1, #params do
		if checkByParam(params[i]) then
			return config._jumpStepId[i]
		end
	end
end

-------------------------Do----------------------------------

function M.finish()
	M.clearSetting()
	M.clearGuideElement()
end

function M.finishSoft()
	if M._stepId then
		local cfg = M._guideConfig[M._stepId]
		if cfg then
			local params = M.getParamJson(cfg)
			if params.isSoft then
				M.step(0)
			end
		end
	end
end

function M.saveGuideStepId(saveId)
	Request.sendReqSaveGuideId(saveId)
end

function M.step(stepId, isStart)
	-- 保证step在引导中执行（由M.start发起）
	if not M.isGuiding() then return end

	--stepId不为空，表示开始当前步骤操作；stepId为空，表示在M._stepId基础上，进入下一步操作；

	if stepId == nil then
		stepId = M._stepId

		-- 在当前步骤结束，准备进入下一步时，记录当前步骤的保存点(如果需要保存)
		local stepConfig = M._guideConfig[stepId]
		local saveId = stepConfig._saveId
		if saveId ~= 0 then
			M.saveGuideStepId(saveId)  --保存guideId
		end
		local nextStepId = stepConfig._nextId
		stepId = nextStepId
  	end

	M._stepId = stepId

	if not AppConst.Release then
		UIManager._lbRoot._guideText.text = "Step ID: ".. stepId
	end
	-- 传入的步骤ID不存在，结束引导
	local config = M._guideConfig[stepId]
	if config == nil then
		return M.finish()
  	end
	
	-- 清除所有设置	-- 清楚引导元素
	M.clearSetting()
	M.clearGuideElement()
	
	if isStart or M.isTrigger(stepId) then
		M.doAfterTrigger()
	else
		M._isWaitTrigger = true
		return
	end
end

function M.doAfterTrigger()
	M._isWaitTrigger = nil
	
	local stepId = M._stepId
	local config = M._guideConfig[stepId]

	lc.logDesignEvent(string.format("Guide:%s", stepId), stepId)

	if config._branchStepId ~= 0 then
		M._branchStepId = config._branchStepId
	end
	
	if config._log == 1 then
		local dictParam = json.encode({id = P._id, rid = C._userRegion._id, strParam = stepId})
		AFSDK.SendDictEvent("e02_tutorial", dictParam)
	end

	if config._jumpCondition ~= "" then
		local jumpId = M.getJumpId(config)
		if jumpId then
			M.step(jumpId)
			return
		end
	end
	if config._forbidClick == 1 then
		M._forbidClick = true   --步骤期间禁止点击
	elseif config._forbidClick == 2 then
		M._forbidClickUntilDoAction = true  --步骤中开始动作前禁止点击
	elseif config._forbidClick == 3 then
		M._forbidClickInBattleScene = true
	end
	
	local params = M.getParamJson(config)
	if params.clickInvalid then
		M._clickInvalid = true
	end
	if params.click_only then
		M._clickOnly = true
	end
	if params.battle_pause then
    	B._battleManager:setPause(true)
	end

	M.tryDoAction(config._delay)
end

function M.tryDoAction(delay)
	M._isWaitAction = true
	if delay and delay ~= 0 then
		lc.setTimer(function()
			M.doAction()
		end, delay * 0.001)
	else
		M.doAction()
	end
end

function M.doAction()
	M._isWaitAction = false
	if not M.isGuiding() then return end

	UIManager.closeTipPanel()
	-- UIManager.closePanelById(PrefabDefine.EmojiTipPanel.id)

	M._forbidClickUntilDoAction = nil

	local config = M._guideConfig[M._stepId]
	M._waitParam = nil

	local action = config._action
	if action == 0 then
		  -- 执行下一步操作
		  M.step()
  	else
		local func = M.ActionFuncs[action]
		if func then
			if not func(config) then
				M.finish()
			end
		end
 	 end
end

-----------------------Clear-------------------------------

function M.clearSetting()
	M._trigger = nil
	M._isWaitTrigger = false
	M._isWaitAction = false

	M._currentBtn    = nil
	M._condition     = nil
	M._trigger       = nil
	M._curObj        = nil

	M._conditionType = nil

	M._taskId        = nil
	M._panelName     = nil
	M._buildingId    = nil
	M._chapterId     = nil
	M._mapId         = nil

	M._clickInvalid  = nil
	M._forbidClick = nil
	M._forbidClickUntilDoAction = nil

	M._clickOnly = nil
	M._inDialog = nil
	M._inDraging = nil

	M._isGuidingBtnReceive = nil
	M._forbidClickInBattleScene = nil

	M._forbidClick = nil
	M._forbidClickUntilDoAction = nil
	M._forbidClickUntilInBattle = nil

	if B._battleManager then
		B._battleManager:setPause(false)
	end
end

function M.clearGuideElement() --清理所有引导元素
	V.getGuideLB():resetUI()
	for k, v in pairs(highLightMap) do
		M.revertHighLightObj(k)
	end
end

-----------------------------Get--------------------------------------
--获取文本id
function M.getTextID(config)
	config = config or M._guideConfig[M._stepId]
	return config._val
end

--获取需要点击的面板
function M.getPanel(config)
	local params = GuideManager.getParamJson(config)
	return params.panel
end

--获取点击对象并设置效果
function M.getClickObjectAndSetEffect(config, action)
	local params = GuideManager.getParamJson(config)
	local btn
	local type = 1  --箭头类型
	local dy = params.dx or 0
	local dx = params.dy or 0
	local setParent = params.setParent
	local isLocal = not setParent
	local isUI
	local effect
	
	local topPanel
	if params.obj then
		topPanel = params.top_panel and UIManager.getCertainPanel(params.top_panel) or UIManager.getTopPanel(true)
		isUI = topPanel ~= B._battleManager._battlePanel
		local obj = topPanel.getBlock and topPanel:getBlock(params) or topPanel[params.obj]
		if params.obj == '_btnReceive' then
			M._isGuidingBtnReceive = true
		end

		type = 2
		M._curObj = obj.gameObject
	end

	if params.arrow_type then
		type = params.arrow_type
	end

	local guideLB = V.getGuideLB()
	if M._curObj then
		if action == M.Action.clickBtn then
			M._currentBtn = M._curObj:GetComponentsInChildren(typeof(UnityEngine.UI.Button), true)[0]

			guideLB:resetUI()
			guideLB:setClipTarget(M._curObj, isUI, config)
			local positions = {}
			local x, y = V.center2UIPos(M._curObj.transform, guideLB.transform, isUI)
			positions[#positions + 1] = Vector3.create(x, y, 0)
			guideLB:showFinger(config, positions)
			
			topPanel:delayCall(function()
				GuideManager.highlightObj(isUI, M._curObj, M._currentBtn)
			end, 0)
			
			if not params.isSoft then
				GuideManager.showDark(isUI, true, params.raycastTarget)
			end

			-- guideLB:showBtnLight(btn)
			-- guideLB:showArrow(btn, type, dx, dy, isLocal, setParent)
			return
		end
	elseif action == M.Action.dialog then

	else
		guideLB:resetUI()
	end
end

function M.getUpStatus(config)
	if config._param ~= "" then
		local params = GuideManager.getParamJson(config)
		if params.need_up then
			return true
		end
	end
	return false
end

----------------------------Set---------------------------

function M.setCondition(config)
	local params = GuideManager.getParamJson(config)
	if params.close_panel then
		M._condition = CondMgr.CondCheck[CondMgr.CondType.close_panel]
		M._conditionType = CondMgr.CondType.close_panel
		M._conditionValue = params.close_panel
	end

	if params.open_panel then
		M._condition = CondMgr.CondCheck[CondMgr.CondType.open_panel]
		M._conditionType = CondMgr.CondType.open_panel
		M._conditionValue = params.open_panel
	end

	if params.temp_booster then
		M._condition = CondMgr.CondCheck[CondMgr.CondType.temp_booster]
		M._conditionType = CondMgr.CondType.temp_booster
		M._conditionValue = params.temp_booster
	end

	if params.wait then
		M._condition = CondMgr.CondCheck[CondMgr.CondType.wait]
		M._conditionType = CondMgr.CondType.wait
		if params.skillId then
			M._skillId = params.skillId
		end
	end

	if params.condition then
		M._condition = CondMgr.CondCheck[CondMgr.CondType.condition]
		M._conditionType = CondMgr.CondType.condition
		M._conditionValue = params.condition
	end

	--(特殊)满足直接进入下一步
	
	if params.star_up then
		M._inStarUpGuiding = true
 	end
end

function M.setSomethingVisible(config)
	local params = GuideManager.getParamJson(config)
	if params.btn then
		local topPanel = params.top_panel and UIManager.getCertainPanel(params.top_panel) or UIManager.getTopPanel(true)
		local btn = topPanel.lb[params.btn]
		btn.gameObject:SetActive(true)
	end
end

---------------------------Action-----------------------------

M.Action = {
	clickBtn         = 10001,

	dialog    = 20001,
	openPanel = 30001,
	closeTopPanel = 30002,
	drag      = 40001,
	display   = 50001,
	changeImg   = 50002,
	jumpBack  = 60001,
	finish    = 70001,
	clear    = 80001,
	wait     = 80002,
	battleConfig = 80003,
	setLine	 = 80004,
	tapSweet = 80005,

	nothing = 99999,
}

M.ActionFuncs = {
	[M.Action.clickBtn] = function(config) --10001
		M.getClickObjectAndSetEffect(config, M.Action.clickBtn)

		M.setCondition(config)
		-- --扫光
		return true
  	end,

	[M.Action.dialog] = function(config)  --20001
		UIManager.closeTipPanel()

		local textId = M.getTextID(config)
		local needConfig = M.getUpStatus(config)

		local guideLB = V.getGuideLB()
		guideLB:showDialog(config)

		M._inDialog = true

		return true
  	end,

	[M.Action.openPanel] = function(config)  --30001
		M.setCondition(config)
		local panelName = M.getPanel(config)
		if panelName == "BattlePanel" then
			B._battleManager:openBattlePanel()
		else
			UIManager.openPanel(PrefabDefine[panelName])
		end
		if not M._condition then
			M.step()
		end
		return true
  	end,

	[M.Action.closeTopPanel] = function(config)  --30002
		local panel = UIManager.getTopPanel(true)
		if panel then
			panel:closePanel()
		end

		M.step()
		return true
  	end,

	[M.Action.display] = function(config)  --50001
		M.setSomethingVisible(config)
		M.step()
		return true
  	end,

	[M.Action.changeImg] = function(config)  --50002
		local params = GuideManager.getParamJson(config)
		local topPanel = params.top_panel and UIManager.getCertainPanel(params.top_panel) or UIManager.getTopPanel(true)
		local btn = topPanel.lb[params.btn]
		local img = btn.transform:GetChild(0).transform:GetComponent("Image")
		img = LuaGO.extendImage(img)
		img:setTPSprite(params.img)
		img:SetNativeSize()

		local pos = ClsFactory.getCls(D.ClassName.Vector2, 0, -20)
		img.transform.anchoredPosition = pos
		ClsFactory.addCls(pos)
		
		M.step()
		return true
  	end,

	[M.Action.jumpBack] = function(config)  --60001
		if M._prevId then
			M.step(M._prevId)
		end
		return true
  	end,

	[M.Action.finish] = function(config)  --70001
		return false
  	end,

	[M.Action.wait] = function(config)  --80002
		local delay = config._delay
		lc.setTimer(function()
			M.step()
		end, delay * 0.001)
		return true
  	end,

	[M.Action.battleConfig] = function(config)  --80003
		B._battleManager:setGuideConfig(config)
		M.setCondition(config)
		if not M._condition then
			M.step()
		end
		return true
  	end,

	[M.Action.setLine] = function(config)  --80004
		B._battleManager:setLine(config)
		M.setCondition(config)
		if not M._condition then
			M.step()
		end
		return true
  	end,

	[M.Action.tapSweet] = function(config)  --80005
		B._battleManager:setTapSweet(config)
		M.setCondition(config)
		local finishCallback = function()
			B._battleManager._guideTapSweetSelected = nil
			B._battleManager._guideTapSweet = nil
		end
		if not M._condition then
			finishCallback()
			M.step()
		else
			M._conditionCallback = finishCallback
		end
		return true
	end,

	[M.Action.nothing] = function(config)  --99999
		M.setCondition(config)
		return true
  	end
}

function M.getGuideBattleConfig()
    if GuideManager.isGuiding() then
        
    end
end
------------------Special------------------------
local jsonCache = {}
function M.getParamJson(config)
	if not config._id then
		jsonCache._defaultConfig = jsonCache._defaultConfig or {}
		return jsonCache._defaultConfig
	end
	jsonCache[config._id] = jsonCache[config._id] or (config._param == "" and {} or json.decode(config._param))
	return jsonCache[config._id]
end

function M.highlightObj(isUI, obj, button, animation)
	if highLightMap[obj] then return end

	local isSweet = obj._isSweet

	if isSweet then
		local x, y, z = lc.getLocalPosition(obj)
		lc.setLocalPosition(obj, x, y, -4)
		highLightMap[obj] = function()
			lc.setLocalPosition(obj, x, y, z)
		end
	else
		animation = animation or obj:GetComponent("Animation")
		local playAutomatically = false
		if animation and animation.playAutomatically then
			playAutomatically = true
			animation.playAutomatically = false
		end

		local parent = isUI and V.getGuideLB()._cloneRoot or B._battleManager._worldCanvasTop
		local cloneObj = GameObject.Instantiate(obj, parent, true)
		local cloneTf = cloneObj.transform

		if playAutomatically then
			animation.playAutomatically = false
		end

		local x, y, z = lc.getLocalPosition(cloneTf)
		lc.setLocalPosition(cloneTf, x, y, 0)
		local sx, sy, sz = lc.getLocalScale(obj)

		local cloneBtn
		local buttons = obj:GetComponentsInChildren(typeof(UnityEngine.UI.Button), true)
		button = button or obj:GetComponent("Button")

		if buttons.Length > 0 then
			local cloneBtns = cloneObj:GetComponentsInChildren(typeof(UnityEngine.UI.Button), true)
			for i = 0, cloneBtns.Length - 1 do
				if buttons[i] ~= button then
					local img = cloneBtns[i]:GetComponent("Image")
					if img then
						img.raycastTarget = false
					end
					local rayCast = cloneBtns[i]:GetComponent("RaycastGraphic")
					if rayCast then
						rayCast.raycastTarget = false
					end
				else
					local callback = function()
						button._clickCallback()
						GuideManager.revertHighLightObj(obj)
					end
					
					if GuideManager._currentBtn == button then
						GuideManager._currentBtn = cloneBtns[i]
					end
					cloneBtn = cloneBtns[i]
					LuaUnity.setClick(cloneBtns[i], callback, D.unpack(button._clickParams))
				end
			end
		end

		local cloneAnim
		if animation then
			cloneAnim = cloneObj:GetComponentsInChildren(typeof(UnityEngine.Animation))[0]
			if animation.isPlaying then
				local animationStatesList = LuaHelper.GetAnimationStates(animation)
				local length = animationStatesList.Count
				for i = 0, length - 1 do
					local animationState = animationStatesList[i]
					local name = animationState.clip.name
					if animation:IsPlaying(name) then
						cloneAnim:Play(name)
						break
					end
				end
			end
		end

		if animation then
			animation.enabled = false
		end
		lc.setLocalScale(obj, 0)

		highLightMap[obj] = function()
			if animation then
				cloneAnim.enabled = false
			end
			GameObject.Destroy(cloneObj)
			lc.setLocalScale(obj, sx, sy, sz)
			if animation then
				animation.enabled = true
			end
		end
	end
end

function M.revertHighLightObj(obj)
	if highLightMap[obj] then
		highLightMap[obj]()
		highLightMap[obj] = nil
		GuideManager.showDark(nil, false)
	end
end

function M.showDark(isUI, isShow, isRaycastTarget)
	if isRaycastTarget == nil then
		isRaycastTarget = true
	end
	if isShow then
		M.showDark(isUI, false)
		if isUI then
			V.getGuideLB():showBg(true)
			V.getGuideLB():setRaycastTarget(isRaycastTarget)
		else
			if B._battleManager and B._battleManager._battlePanel then
				B._battleManager._battlePanel:showTopDark(true, isRaycastTarget)
			end
		end
	else
		V.getGuideLB():showBg(false)
		if B._battleManager and B._battleManager._battlePanel then
			B._battleManager._battlePanel:showTopDark(false)
		end
	end
end

return M