local Badge = require "widgets/badge"
local UIAnim = require "widgets/uianim"
local Text = require "widgets/text"

local RATE_SCALE_ANIM =
{
    [RATE_SCALE.INCREASE_HIGH] = "arrow_loop_increase_most",
    [RATE_SCALE.INCREASE_MED] = "arrow_loop_increase_more",
    [RATE_SCALE.INCREASE_LOW] = "arrow_loop_increase",
    [RATE_SCALE.DECREASE_HIGH] = "arrow_loop_decrease_most",
    [RATE_SCALE.DECREASE_MED] = "arrow_loop_decrease_more",
    [RATE_SCALE.DECREASE_LOW] = "arrow_loop_decrease",
}

-- 三维状态继承Badge，普通UI继承Widget
local KisakiSanityBadge = Class(Badge, function(self, owner)
    -- 调用父类构建方法，
    -- 不使用动画资源（动画资源搞的不好，自定义下，正常之理填动画资源就行），（PS：下次肯定把动画做到一起，垃圾科雷）
    -- 不配置颜色，不配置icon（类似于饥饿值的胃）
    -- 不配置表格动画(饥荒里好像没用)
    -- 背景透明(自定义)，脉冲时不更新(默认都是true)
    Badge._ctor(self, nil, owner, nil, nil, nil, true, true)
    self.owner = owner
    self.percent = 1 -- 显示填充物百分比

    -- 覆盖父类定义，图标底部（不足100%显示的部分）
    self.backing:GetAnimState():SetBank("status_kisaki_sanity")
    self.backing:GetAnimState():SetBuild("status_kisaki_sanity")
    self.backing:GetAnimState():PlayAnimation("bg")

    -- 覆盖父类定义，魔法值变化时填充物变化动画,underNumber定义在Badge内
    self.anim:GetAnimState():SetBank("status_kisaki_sanity")  -- 配置动画的父级节点的名字
    self.anim:GetAnimState():SetBuild("status_kisaki_sanity") -- scml文件的名字
    self.anim:GetAnimState():PlayAnimation("anim")            -- 播放动画
    self.anim:GetAnimState():AnimateWhilePaused(false)        -- 暂停时是否也播放动画
    self.anim:SetScale(1, 1, 1)                               -- 贴图缩放
    self.anim:SetClickable(false)                             -- 是否可点击
    self.anim:GetAnimState():SetPercent("anim", 1)            -- 动画播放百分比，固定帧，不会动

    -- 覆盖父类定义，图标框
    self.circleframe:GetAnimState():SetBank("status_kisaki_sanity")
    self.circleframe:GetAnimState():SetBuild("status_kisaki_sanity")
    self.circleframe:GetAnimState():PlayAnimation("frame")

    -- 箭头动画(使用san值的)
    self.sanityarrow = self.underNumber:AddChild(UIAnim())
    self.sanityarrow:GetAnimState():SetBank("sanity_arrow")
    self.sanityarrow:GetAnimState():SetBuild("sanity_arrow")
    self.sanityarrow:GetAnimState():PlayAnimation("neutral")
    self.sanityarrow:GetAnimState():AnimateWhilePaused(false)
    self.sanityarrow:SetClickable(false)
    self.sanityarrow_oldanim = "neutral"

    -- 移动上去显示数值，父类已经定义好
    -- self.num = self:AddChild(Text(BODYTEXTFONT, 33))
    -- self.num:SetHAlign(ANCHOR_MIDDLE)
    -- self.num:SetPosition(3, 0, 0)
    -- self.num:Hide()

    -- 恢复闪绿色的圈，父类已经定义好
    -- self.pulse = self:AddChild(UIAnim())
    -- self.pulse:GetAnimState():SetBank("pulse")
    -- self.pulse:GetAnimState():SetBuild("hunger_health_pulse")
    -- self.pulse:GetAnimState():AnimateWhilePaused(true)

    -- 受害闪红色的圈，父类已经定义好
    -- self.warning = self:AddChild(UIAnim())
    -- self.warning:GetAnimState():SetBank("pulse")
    -- self.warning:GetAnimState():SetBuild("hunger_health_pulse")
    -- self.warning:GetAnimState():AnimateWhilePaused(not dont_update_while_paused)
    -- self.warning:Hide()

    -- 开始更新
    self:StartUpdating()
end)

---------------------------------------------------------------------------------------------------------------------------------------------------------------

function KisakiSanityBadge:SetPercent(val, max)
    Badge.SetPercent(self, val, max) --调用父类的SetPercent函数
end

function KisakiSanityBadge:SetRate()
    if self.owner == nil or self.owner.replica == nil or self.owner.replica.kisaki_sanity == nil then
        return
    end
    local anim = "neutral"
    local kisaki_sanity = self.owner.replica.kisaki_sanity
    -- 角色睡觉时固定动画
    if self.owner:HasTag("sleeping") and
        kisaki_sanity ~= nil and kisaki_sanity:GetPercent() < 1 then
        anim = "arrow_loop_increase_most"
    else
        -- 按速率取值
        local ratescale = kisaki_sanity:GetRateScale()
        if ratescale == RATE_SCALE.INCREASE_LOW or
            ratescale == RATE_SCALE.INCREASE_MED or
            ratescale == RATE_SCALE.INCREASE_HIGH then
            if kisaki_sanity:GetPercent() < 1 then
                anim = RATE_SCALE_ANIM[ratescale]
            end
        elseif ratescale == RATE_SCALE.DECREASE_LOW or
            ratescale == RATE_SCALE.DECREASE_MED or
            ratescale == RATE_SCALE.DECREASE_HIGH then
            if kisaki_sanity:GetPercent() > 0 then
                anim = RATE_SCALE_ANIM[ratescale]
            end
        end
    end

    -- 配置动画
    if self.sanityarrow_oldanim ~= anim then
        self.sanityarrow:GetAnimState():PlayAnimation(anim, true)
        self.sanityarrow_oldanim = anim
    end
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------

function KisakiSanityBadge:OnUpdate(dt)
    local kisaki_sanity = self.owner.replica.kisaki_sanity
    if TheNet:IsServerPaused() or not kisaki_sanity then return end
    -- 箭头动画
    self:SetRate()
    -- 填充物动画
    self:SetPercent(kisaki_sanity:GetPercent(), kisaki_sanity:GetMax())
end

return KisakiSanityBadge
