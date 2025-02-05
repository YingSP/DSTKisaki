local easing = require("easing")

local FIRST_CURRENT = 200
local SANE_MIN = 100
local CRAZY_MAX = 101
local FIRST_DAPPERNESS = 100 / 480
local FIRST_RATE_MODIFIER_UP = 1
local FIRST_RATE_MODIFIER_DOWN = 1
local FIRST_DAPPERNESS_MULT = 0.1
local FIRST_AURA_MULT = 0.1
local MOISTURE_SANITY_PENALTY_MAX = -4 -- 角色因为潮湿最大的减魔法光环
local PLAYER_ADD_SPEED = 400 / 480     -- 玩家在周围存在时，给予的回魔法BUFF
local SLEEPING_ADD_SPEED = 100 / 60    -- 玩家在周围存在时，给予的回魔法BUFF
local PLAYER_RANGE = 10                -- 查找玩家的距离
----------------------------------------------------------------------------任务-------------------------------------------------------------------------------

-- 更新逻辑
local function Heal(self, inst)
    if inst:HasTag('playerghost') or not inst.components.kisaki_sanity then return end -- 角色死亡停止
    print("开始更新数据")
    -- 增加值
    local dapper_delta_up = 0
    -- 减少值
    local dapper_delta_down = 0

    -- 处理自带的BUFF影响
    if self.dapperness > 0 then
        dapper_delta_up = dapper_delta_up + self.dapperness
    else
        dapper_delta_down = dapper_delta_down + self.dapperness
    end
    print(string.format("自带BUFF处理后的速率为: %2.2f + %2.2f", dapper_delta_up, dapper_delta_down))

    -- 处理角色装备影响
    for k, v in pairs(self.inst.components.inventory.equipslots) do
        -- 计算装备的SAN值影响光环
        local equippable = v.components.equippable
        if equippable ~= nil then
            local item_dapperness = equippable:GetDapperness(self.inst, false) -- 角色会受到潮湿组件影响的情况下获取san值影响
            if item_dapperness > 0 then
                dapper_delta_up = dapper_delta_up + item_dapperness * self.dapperness_mult
            else
                dapper_delta_down = dapper_delta_down + item_dapperness * self.dapperness_mult
            end
        end
        local kisaki_equippable = v.components.kisaki_equippable                      -- 对应的组件还没实现,TODO
        if kisaki_equippable ~= nil then
            local kisaki_item_dapperness = kisaki_equippable:GetDapperness(self.inst) -- 获取角色专属魔法值恢复影响
            if kisaki_item_dapperness > 0 then
                dapper_delta_up = dapper_delta_up + kisaki_item_dapperness
            else
                dapper_delta_down = dapper_delta_down + kisaki_item_dapperness
            end
        end
    end
    print(string.format("装备处理后的速率为: %2.2f + %2.2f", dapper_delta_up, dapper_delta_down))

    -- 处理角色潮湿值影响
    local moisture = self.inst.components.moisture
    if moisture ~= nil then
        dapper_delta_down = dapper_delta_down + easing.inSine(moisture:GetMoisture(), 0,
            MOISTURE_SANITY_PENALTY_MAX, moisture:GetMaxMoisture())
    end
    print(string.format("角色潮湿处理后的速率为: %2.2f + %2.2f", dapper_delta_up, dapper_delta_down))

    -- 处理周围的SAN值光环和魔法值光环
    local SANITYRECALC_MUST_TAGS = { "sanityaura" }
    local SANITYRECALC_CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO" }
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.SANITY_AURA_SEACH_RANGE, SANITYRECALC_MUST_TAGS,
        SANITYRECALC_CANT_TAGS)
    for i, v in ipairs(ents) do
        -- 不受到自身SAN光环影响
        if v.components.sanityaura ~= nil and v ~= self.inst then
            local aura_val = v.components.sanityaura:GetAura(self.inst)
            if aura_val > 0 then
                dapper_delta_up = dapper_delta_up + aura_val * self.aura_mult
            else
                dapper_delta_down = dapper_delta_down + aura_val * self.aura_mult
            end
        end
        -- 计算魔法值光环
        if v.components.kisaki_sanityaura ~= nil then
            local aura_val = v.components.kisaki_sanityaura:GetAura(self.inst)
            if aura_val > 0 then
                dapper_delta_up = dapper_delta_up + aura_val
            else
                dapper_delta_down = dapper_delta_down + aura_val
            end
        end
    end
    print(string.format("SAN值光环处理后的速率为: %2.2f + %2.2f", dapper_delta_up, dapper_delta_down))

    -- 如果人物在睡觉，快速恢复魔法值
    if inst:HasTag("sleeping") then
        dapper_delta_up = dapper_delta_up + SLEEPING_ADD_SPEED
    end

    -- 周围有玩家时，快速恢复魔法值
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = TheSim:FindEntities(x, y, z, PLAYER_RANGE, { "player" })
    if #players > 1 then
        if PLAYER_ADD_SPEED > 0 then
            dapper_delta_up = dapper_delta_up + PLAYER_ADD_SPEED
        else
            dapper_delta_down = dapper_delta_down + PLAYER_ADD_SPEED
        end
    end
    print(string.format("玩家判断处理后的速率为: %2.2f + %2.2f", dapper_delta_up, dapper_delta_down))

    -- 计算速率
    self.rate = dapper_delta_up * self.rate_modifier_up + dapper_delta_down * self.rate_modifier_down
    print(string.format("最终速率为: %2.2f", self.rate))
    self.ratescale =
        (self.rate > 2 and RATE_SCALE.INCREASE_HIGH) or
        (self.rate > 1 and RATE_SCALE.INCREASE_MED) or
        (self.rate > .01 and RATE_SCALE.INCREASE_LOW) or
        (self.rate < -3 and RATE_SCALE.DECREASE_HIGH) or
        (self.rate < -1 and RATE_SCALE.DECREASE_MED) or
        (self.rate < -.02 and RATE_SCALE.DECREASE_LOW) or
        RATE_SCALE.NEUTRAL
    self:DoDelta(self.rate)
end


----------------------------------------------------------------------------监听-------------------------------------------------------------------------------

local function onmax(self, max)
    self.inst.replica.kisaki_sanity:SetMax(max)
end

local function oncurrent(self, current)
    self.inst.replica.kisaki_sanity:SetCurrent(current)
end

local function onratescale(self, ratescale)
    self.inst.replica.kisaki_sanity:SetRateScale(ratescale)
end

local function onsane(self, sane)
    self.inst.replica.kisaki_sanity:SetIsSane(sane)
end

-- 角色魔法值过低时
local function onbecrazy(self, inst)
    if self.sane then
        return
    else
        -- 扣饥饿值
        local hunger = inst.components.hunger
        if hunger then
            hunger:DoDelta(-hunger.max / 100)
        end
        self.inst:DoTaskInTime(0.3, function() onbecrazy(self, inst) end)
    end
end

-- 角色魔法值从过低状态恢复时
local function onbesane(self, inst)

end

-- 角色复活后如果魔法值太低，则设为最低值
local function onbecamehuman(inst)
    inst:DoTaskInTime(0.1, function()
        if inst.components.kisaki_sanity and inst.components.kisaki_sanity.current < SANE_MIN then
            inst.components.kisaki_sanity.current = SANE_MIN
        end
    end)
end

-- 击杀史诗级生物恢复魔力值
local function onkilled(player, data)
    if data ~= nil and data.victim ~= nil then
        local boss = data.victim
        local kisaki_sanity = player.components.kisaki_sanity
        if kisaki_sanity and boss:HasTag("epic") and boss.components.health then
            print(string.format("击杀恢复: %s %2.2f", boss.prefab, boss.components.health.maxhealth))
            kisaki_sanity:DoDelta(boss.components.health.maxhealth / 40)
        end
    end
end

-- 角色吃东西可以恢复魔力值
local function oneat(player, data)
    local kisaki_sanity = player.components.kisaki_sanity
    if kisaki_sanity and data and data.food and data.food.components.edible then
        local food_edible = data.food.components.edible
        kisaki_sanity:DoDelta(food_edible.hungervalue * 0.05 + food_edible.sanityvalue * 0.15 + food_edible.healthvalue * 0.2)
        if data.food and data.food:HasTag("kisaki_food") then
            player.components.talker:Say("我还想吃点这个！") -- 做了专属料理后再实现，TODO
        end
    end
end

----------------------------------------------------------------------------CLASS-----------------------------------------------------------------------------

local Sanity = Class(function(self, inst)
    self.inst = inst                                             -- 角色
    self.max = TUNING.KISAKI_BOOK_SANITY                         -- 最大值
    self.current = FIRST_CURRENT                                 -- 当前值，初始200
    self.dapperness = FIRST_DAPPERNESS                           -- 角色自带影响自己的光环，N点/秒
    self.rate_modifier_up = FIRST_RATE_MODIFIER_UP               -- 速率倍率，用于实现角色在某些情况下恢复能力更强的功能
    self.rate_modifier_down = FIRST_RATE_MODIFIER_DOWN           -- 速率倍率，用于实现角色在某些情况下受害能力更深的功能
    self.dapperness_mult = FIRST_DAPPERNESS_MULT                 -- 装备的SAN加成影响魔法值比例
    self.aura_mult = FIRST_AURA_MULT                             -- SAN值光环影响魔法值比例
    self.sane = true                                             -- 魔法值是否充盈
    -- self.penalty = 0                                          -- 死亡惩罚影响的上限（黑色部分）
    self.ratescale = RATE_SCALE.NEUTRAL                          -- 速率状态，用于更新动画
    self.rate = 0                                                -- 变化速率，计算和debug用

    inst:DoPeriodicTask(1, function() Heal(self, inst) end, 0.1) -- 延时2s后开始每秒一次的定时任务

    inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman)  -- 监听角色复活
    inst:ListenForEvent("killed", onkilled)                      -- 监听角色击杀
    inst:ListenForEvent("oneat", oneat)                          -- 监听角色吃东西
end, nil, {
    -- 监听数据变化，影响显示的需要同步到客户端
    max = onmax,
    current = oncurrent,
    ratescale = onratescale,
    -- sane = onsane, -- 不做低魔法值动画了，先不同步
})

----------------------------------------------------------------------------GET/SET----------------------------------------------------------------------------

-- 不做校验，可信域内调用
function Sanity:SetMax(amount) self.max = math.max(1, amount) end

function Sanity:SetCurrent(amount) self.current = math.max(0, amount) end

function Sanity:SetDapperness(amount) self.dapperness = amount end

function Sanity:SetRateModifierUp(amount) self.rate_modifier_up = amount end

function Sanity:SetRateModifierDown(amount) self.rate_modifier_down = amount end

function Sanity:SetRateScale(amount) self.ratescale = amount end

function Sanity:SetAuraMult(amount) self.aura_mult = amount end

function Sanity:SetDappernessMult(amount) self.dapperness_mult = amount end

function Sanity:SetIsSane(amount) self.sane = amount end

function Sanity:GetMax() return self.max end

function Sanity:GetCurrent() return self.current end

function Sanity:GetDapperness() return self.dapperness end

function Sanity:GetRateModifierUp() return self.rate_modifier_up end

function Sanity:GetRateModifierDown() return self.rate_modifier_down end

function Sanity:GetRateScale() return self.ratescale end

function Sanity:GetAuraMult() return self.aura_mult end

function Sanity:GetDappernessMult() return self.dapperness_mult end

function Sanity:GetIsSane() return self.sane end

function Sanity:GetDebugString()
    return string.format("当前魔法值信息为：%2.2f / %2.2f 速率： %2.4f. 恢复加成： %2.2f, 降低加成： %2.2f, 魔法是否充盈 %s",
        self.current, self.max, self.rate, self.rate_modifier_up, self.rate_modifier_down,
        self.sane and "true" or "false")
end

function Sanity:IsSane()
    return self.current < SANE_MIN
end

function Sanity:GetPercent()
    return self.current / self.max
end

function Sanity:SetPercent(percent)
    percent = math.clamp(percent, 0, 1);
    self.current = self.max * percent;
end

function Sanity:DoDelta(val)
    print(string.format("开始增加，增加值为: %2.2f", val))
    self.current = math.clamp(self.current + val, 0, self.max) -- 恢复和消耗都不能超出区间
    print(string.format("已增加，当前魔法值为: %2.2f", self.current))
    -- 检查是否魔法值过低
    if self.sane and self.current < SANE_MIN then
        self.sane = false
        self.inst:DoTaskInTime(0.5, function() onbecrazy(self, self.inst) end)
    elseif not self.sane and self.current >= CRAZY_MAX then
        self.sane = true
        self.inst:DoTaskInTime(0.5, function() onbesane(self, self.inst) end)
    end
end

----------------------------------------------------------------------------加载时运行---------------------------------------------------------------------------

function Sanity:OnSave()
    return
    {
        current = self.current,
        max = self.max,
        dapperness = self.dapperness,
        rate_modifier_up = self.rate_modifier_up,
        rate_modifier_down = self.rate_modifier_down,
        dapperness_mult = self.dapperness_mult,
        aura_mult = self.aura_mult
    }
end

function Sanity:OnLoad(data)
    if not data then return end
    self.max = data.max ~= nil and data.max or TUNING.KISAKI_BOOK_SANITY
    if data.current ~= nil then
        self.current = data.current
        self:DoDelta(0)
    end
    self.dapperness = data.dapperness ~= nil and data.dapperness or FIRST_DAPPERNESS
    self.rate_modifier_up = data.rate_modifier_up ~= nil and data.rate_modifier_up or FIRST_RATE_MODIFIER_UP
    self.rate_modifier_down = data.rate_modifier_down ~= nil and data.rate_modifier_down or FIRST_RATE_MODIFIER_DOWN
    self.dapperness_mult = data.dapperness_mult ~= nil and data.dapperness_mult or FIRST_AURA_MULT
    self.dapperness = data.dapperness ~= nil and data.dapperness or FIRST_DAPPERNESS_MULT
end

return Sanity
