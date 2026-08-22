local Widget = require "widgets/widget"
local UIAnim = require "widgets/uianim"
TextButton = require "widgets/textbutton"

---------------------------------------------------------------------------------------------------------------------------------------------------------------

local function onclickLevel(self, player)
    local kisaki_level = player.replica.kisaki_level
    if kisaki_level and self.cd() then
        TheNet:Say(string.format("我现在%d级  %2.2f%%经验", kisaki_level:GetCurrent(), kisaki_level:GetPercent() * 100), false)
    end
end

local function onclickAchievement(self, player)
    local kisaki_achievement = player.replica.kisaki_achievement
    if kisaki_achievement then
        Networking_Announcement(kisaki_achievement:GetDebugString())
    end
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------

local KisakiInfo = Class(Widget, function(self, owner)
    Widget._ctor(self, "KisakiInfo")
    self.owner = owner

    -- 显示等级文字
    self.kisaki_level = self:AddChild(TextButton())       -- 新增组件
    self.kisaki_level:SetFont(BODYTEXTFONT)               -- 字体
    self.kisaki_level:SetTextSize(32)                     -- 字体大小
    self.kisaki_level:SetTextColour({ 1, 1, 1, .8 })      -- 字体颜色
    self.kisaki_level:SetTextFocusColour({ 1, 1, 1, .8 }) -- 获取焦点时颜色
    self.kisaki_level:SetHAnchor(1)                       -- 水平居中
    self.kisaki_level:SetVAnchor(2)                       -- 垂直居中
    self.kisaki_level:MoveToFront()                       -- 显示在最上方
    self.kisaki_level:SetPosition(240, 80, 0)             -- 配置地点
    -- 点击触发
    self.cd = KisakiCD(60)
    self.kisaki_level:SetOnClick(function() onclickLevel(self, owner) end)

    -- 显示成就文字
    self.kisaki_achievement = self:AddChild(TextButton())       -- 新增组件
    self.kisaki_achievement:SetFont(BODYTEXTFONT)               -- 字体
    self.kisaki_achievement:SetTextSize(32)                     -- 字体大小
    self.kisaki_achievement:SetTextColour({ 1, 1, 1, .8 })      -- 字体颜色
    self.kisaki_achievement:SetTextFocusColour({ 1, 1, 1, .8 }) -- 获取焦点时颜色
    self.kisaki_achievement:SetHAnchor(1)                       -- 水平居中
    self.kisaki_achievement:SetVAnchor(2)                       -- 垂直居中
    self.kisaki_achievement:MoveToFront()                       -- 显示在最上方
    self.kisaki_achievement:SetPosition(240, 150, 0)            -- 配置地点
    -- 点击触发
    self.kisaki_achievement:SetOnClick(function() onclickAchievement(self, owner) end)

    -- 开始更新
    self:StartUpdating()
end
)

---------------------------------------------------------------------------------------------------------------------------------------------------------------

function KisakiInfo:OnUpdate(dt)
    if TheNet:IsServerPaused() then return end
    local kisaki_level = self.owner.replica.kisaki_level
    if kisaki_level then
        local str = "当前等级:LV" .. kisaki_level:GetCurrent()
        str = str .. "\r\n" .. "当前等级状态：" .. kisaki_level:GetCurrentExp() .. "/" .. kisaki_level:GetLevelUpNeedExp()
        self.kisaki_level:SetText(str)
    end
    local kisaki_achievement = self.owner.replica.kisaki_achievement
    if kisaki_achievement then
        local str = "成就"
        self.kisaki_achievement:SetText(str)
    end
end

return KisakiInfo
