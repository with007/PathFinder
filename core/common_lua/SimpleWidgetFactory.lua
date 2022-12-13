--
-- Author: soul
-- Date: 2021/3/11 17:47:37
-- Brief: 
--

local M = {}
declare("SimpleWidgetFactory", M)
--[[
SimpleWidgetFactory = M
]]

local typeGameObjectTag = typeof(GameObjectTag)

local WidgetNames = requireLua("SimpleWidgetFactoryDefine")

local WidgetClasses = {}
for i = 1, #WidgetNames do
    WidgetClasses[i] = requireLua(WidgetNames[i])
end

local function _get_widget_obj(widgetType)
    local tf = GameRoot._widgetPoolTFs[widgetType]
    if tf.childCount == 0 then
        return nil
    end
    return tf:GetChild(0).gameObject
end

--// 创建 传入组件类型 单个组件数据 选项
function M.createWidget(widgetType, ...)
    local obj = _get_widget_obj(widgetType)
    local lb = nil
    if obj == nil then
        lb = WidgetClasses[widgetType].create(...)
    else
        obj:SetActive(true)
        obj._lb:updateUI(...)
        lb = obj._lb
    end
    
    return lb
end

local function _get_components(parent)
    if parent.transform == nil then
        return {}
    end

    local coms = {}
    local comTags = parent.transform:GetComponentsInChildren(typeGameObjectTag, true)
    for i = 0, comTags.Length - 1 do
        if comTags[i].gameObject ~= parent.gameObject then
            coms[#coms + 1] = comTags[i]
        end
    end

    return coms
end

local function _recyle_widget_obj(widgetType, obj)
    obj.transform:SetParent(GameRoot._widgetPoolTFs[widgetType], false)
    local go = obj.gameObject
    if go._lb and go._lb.onRecycle then
        go._lb:onRecycle()
    end
end

function M.recycleWidgets(parent, tag)
    local coms = _get_components(parent)
    if tag == nil then
        for i = 1, #coms do
            local widgetType = tonumber(coms[i].tag)
            _recyle_widget_obj(widgetType, coms[i])
        end
    else
        for i = 1, #coms do
            local widgetType = tonumber(coms[i].tag)
            if widgetType == tag then
                _recyle_widget_obj(widgetType, coms[i])
            end
        end
    end
end

function M.recycleWidgetBySelf(widget)
    local tagComponent = widget.gameObject:GetComponent(typeGameObjectTag)
    local widgetType = tonumber(tagComponent.tag)
    _recyle_widget_obj(widgetType, widget)
end

function M.findWigets(widgetType, parent)
    local widgets = {}
    local coms = parent.transform:GetComponentsInChildren(typeGameObjectTag, true)
    for i = 0, coms.Length - 1 do
        if tonumber(coms[i].tag) == widgetType then
            widgets[#widgets + 1] = coms[i].gameObject
        end
    end
    return widgets
end