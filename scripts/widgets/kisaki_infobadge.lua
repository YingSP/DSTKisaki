local Widget = require "widgets/widget"
local UIAnim = require "widgets/uianim"
TextButton = require "widgets/textbutton"

---------------------------------------------------------------------------------------------------------------------------------------------------------------

local function onclick(self, player)
    local kisaki_level = player.replica.kisaki_level
    if kisaki_level and self.cd() then
        TheNet:Say(string.format("我现在%d级  %2.2f%%经验", kisaki_level:GetCurrent(), kisaki_level:GetPercent() * 100), false)
    end
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------

local KisakiInfo = Class(Widget,
    function(self, owner)
        Widget._ctor(self, "KisakiLevel")
        self.owner = owner
        -- 显示文字
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
        self.kisaki_level:SetOnClick(function() onclick(self, owner) end)
        -- 开始更新
        self:StartUpdating()
    end
)

---------------------------------------------------------------------------------------------------------------------------------------------------------------

function KisakiInfo:OnUpdate(dt)
    local kisaki_level = self.owner.replica.kisaki_level
    if TheNet:IsServerPaused() or not kisaki_level then return end
    local str = "当前等级:LV" .. kisaki_level:GetCurrent()
    str = str .. "\r\n" .. "当前等级状态：" .. kisaki_level:GetCurrentExp() .. "/" .. kisaki_level:GetLevelUpNeedExp()
    self.kisaki_level:SetText(str)
end

return KisakiInfo
