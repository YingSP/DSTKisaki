-- 薪火：装备在护符栏的多元护符容器。
-- 容器内的护符不会真的写入 Inventory.equipslots，而是作为“虚拟装备”启用：
-- 只复用其已有的装备/卸下回调与被动数值，避免多个物品抢占同一个 NECK 槽位。
local amuletutil = require("utils/amuletutil")

local assets = {
    Asset("ANIM", "anim/kisaki_multivariate_amulet.zip"),
    Asset("ANIM", "anim/ui_kisaki_container_3x2.zip"),
    Asset("ATLAS", "images/inventoryimages/prefabs/kisaki_multivariate_amulet.xml"),
    Asset("IMAGE", "images/inventoryimages/prefabs/kisaki_multivariate_amulet.tex"),
}

-- 收纳在容器内的护符会带上这个 tag
local STORED_TAG = amuletutil.STORED_TAG

---------------------------------------------------------------------辅助方法---------------------------------------------------

-- 判断是否正在被装备着
local function IsOuterEquipped(inst)
    return inst.components.equippable ~= nil
        and inst.components.equippable:IsEquipped()
        and inst.components.inventoryitem ~= nil
        and inst.components.inventoryitem:GetGrandOwner() ~= nil
end
-- 获取当前护符的装备者
local function GetOwner(inst)
    return inst.components.inventoryitem ~= nil and inst.components.inventoryitem:GetGrandOwner() or nil
end

-- 容器内是否已有同 prefab 的护符处于激活状态。不应该有这种情况，兜底方法。
local function HasActivatedPrefab(inst, prefab)
    for activated in pairs(inst._virtual_amulets) do
        if activated.prefab == prefab then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------核心逻辑---------------------------------------------------

-- 刷新移速，暗影等级，回SAN光环，保暖/隔热，防水，防雷，热源/冷源，护甲减伤/位面防御。
-- 特殊 tag 的继承不在本函数：由 hook.lua 的 EquipHasTag 增强在查询时动态覆盖。
local function UpdateInheritedStats(inst, owner)
    local speedmult = 1         -- 移速
    local dapperness = 0        -- 回SAN光环
    local shadowlevel = 0       -- 暗影等级
    local winter_insulation = 0 -- 保暖
    local summer_insulation = 0 -- 隔热
    local waterproofness = 0    -- 防水
    local insulated = false     -- 防雷
    -- 护甲减伤聚合：取容器内最强的吸收率
    local absorption = 0
    -- 位面防御聚合：走相加逻辑
    local planar_defense = 0
    -- heater 聚合的分组累加器：exo = 放热（取暖），endo = 吸热（制冷）
    local exo_heat, exo_mult = 0, 0
    local endo_heat, endo_mult = 0, 0

    -- 开始统计
    local container = inst.components.container
    if container ~= nil then
        -- 用数值 for 循环而非 ipairs，空槽不会截断后续格子的检查。
        for slot = 1, container:GetNumSlots() do
            local item = container:GetItemInSlot(slot)
            if item ~= nil and inst._virtual_amulets[item] then
                local equippable = item.components.equippable
                speedmult = speedmult * (equippable.walkspeedmult or 1)
                dapperness = dapperness + equippable:GetDapperness(owner,
                    owner ~= nil and owner.components.sanity ~= nil and owner.components.sanity.no_moisture_penalty)

                if item.components.shadowlevel ~= nil then
                    shadowlevel = shadowlevel + item.components.shadowlevel:GetCurrentLevel()
                end

                -- 护甲减伤 / 位面防御：只有无限耐久的护甲能进容器（见 amuletutil），
                if item.components.armor ~= nil then
                    absorption = math.max(absorption, item.components.armor.absorb_percent or 0)
                end
                if item.components.planardefense ~= nil then
                    planar_defense = planar_defense + (item.components.planardefense:GetDefense() or 0)
                end

                -- 保暖/隔热：按季节分别累加，与原版 Temperature:GetInsulation 一致。
                if item.components.insulator ~= nil then
                    local value, season = item.components.insulator:GetInsulation()
                    if season == SEASONS.SUMMER then
                        summer_insulation = summer_insulation + value
                    else
                        winter_insulation = winter_insulation + value
                    end
                end

                -- 防水：原版是各装备 Effectiveness 相加，可超过 1（IsWaterproof 判 >= 1）。
                if item.components.waterproofer ~= nil then
                    waterproofness = waterproofness + item.components.waterproofer:GetEffectiveness()
                end

                -- 防雷：原版 IsInsulated 是“任一为真即免疫”的短路语义。
                if not insulated and equippable:IsInsulated() then
                    insulated = true
                end

                -- 热源/冷源（heater）：按放热/吸热分组收集，equippedheatfn 型
                -- （如哑铃的动态值）调用一次取快照，与 insulator 动态值的处理一致。
                local h = item.components.heater
                if h ~= nil then
                    local heat = h.equippedheatfn ~= nil and h.equippedheatfn(item, owner) or h.equippedheat
                    if heat ~= nil then
                        if h:IsEndothermic() then
                            endo_heat = endo_heat + heat * h.carriedheatmultiplier
                            endo_mult = endo_mult + h.carriedheatmultiplier
                        elseif h:IsExothermic() then
                            exo_heat = exo_heat + heat * h.carriedheatmultiplier
                            exo_mult = exo_mult + h.carriedheatmultiplier
                        end
                    end
                end
            end
        end
    end

    -- 开始结算
    local equippable = inst.components.equippable
    equippable.walkspeedmult = math.floor(speedmult * 100 + 0.5) / 100
    equippable.dapperness = dapperness
    equippable.insulated = insulated
    inst.components.shadowlevel:SetDefaultLevel(shadowlevel)
    local insulator = inst.components.insulator
    if summer_insulation > winter_insulation then
        insulator:SetSummer()
        insulator:SetInsulation(summer_insulation)
    else
        insulator:SetWinter()
        insulator:SetInsulation(winter_insulation)
    end
    inst.components.waterproofer:SetEffectiveness(waterproofness)
    inst.components.armor:SetAbsorption(absorption)
    inst.components.planardefense:SetBaseDefense(planar_defense)
    local heater = inst.components.heater
    if endo_mult > 0 and (exo_mult <= 0 or endo_mult >= exo_mult) then
        heater:SetThermics(false, true)
        heater.equippedheat = endo_heat / endo_mult
        heater.carriedheatmultiplier = endo_mult
    elseif exo_mult > 0 then
        heater:SetThermics(true, false)
        heater.equippedheat = exo_heat / exo_mult
        heater.carriedheatmultiplier = exo_mult
    else
        -- 无热源时保持中性：equippedheat 为 nil 时 temperature 会跳过该装备
        heater.equippedheat = nil
        heater.carriedheatmultiplier = 1
    end

    -- 移速组件不会因 walkspeedmult 字段变化自动立刻刷新。
    owner = owner or GetOwner(inst)
    if owner ~= nil and owner.components.locomotor ~= nil then
        owner.components.locomotor:UpdateGroundSpeedMultiplier()
    end
end

-- 使得护符item从owner身上虚拟脱下
-- no_refresh 为真时跳过数据刷新，交给调用方在整批处理结束后统一刷新。
local function DeactivateAmulet(inst, item, owner, no_refresh)
    if item == nil or not inst._virtual_amulets[item] then
        return
    end

    inst._virtual_amulets[item] = nil
    owner = owner or inst._virtual_owner

    if owner == nil or not owner:HasTag("player") then
        return
    end

    local equippable = item.components.equippable
    if equippable ~= nil then
        -- 不调用 Equippable:Unequip：该方法会假定物品真实位于装备栏。
        equippable.isequipped = false
        if equippable.onunequipfn ~= nil and owner ~= nil then
            equippable.onunequipfn(item, owner)
        end
        item:PushEvent("unequipped", { owner = owner, virtual = true })
    end

    if not no_refresh then
        UpdateInheritedStats(inst, owner)
    end
end

-- 使得护符item被虚拟装备在owner身上
-- no_refresh 为真时跳过数据刷新，交给调用方在整批处理结束后统一刷新。
local function ActivateAmulet(inst, item, owner, no_refresh)
    if item == nil or owner == nil or not owner:HasTag("player") or inst._virtual_amulets[item] then
        return
    end

    -- 与容器收纳共用同一套判定：能放进容器就生效。
    if not amuletutil.IsStorableAmulet(item, false) then
        return
    end

    -- 同名护符只让先激活的那个生效，重复的不再叠加。
    if HasActivatedPrefab(inst, item.prefab) then
        return
    end

    local equippable = item.components.equippable
    inst._virtual_amulets[item] = true
    -- 不调用 Equippable:Equip：手动维持最小必要状态，再执行原有回调。
    equippable.isequipped = true
    if equippable.onequipfn ~= nil then
        equippable.onequipfn(item, owner, false)
    end
    item:PushEvent("equipped", { owner = owner, virtual = true })

    if not no_refresh then
        UpdateInheritedStats(inst, owner)
    end
end

-- 按容器当前内容重算所有虚拟装备。不是简单的只计算一个：防止脱下装备导致另一件装备同效果失效问题
local function RecalcAmulets(inst, owner)
    if not IsOuterEquipped(inst) then
        return
    end
    owner = owner or GetOwner(inst)
    if owner == nil or not owner:HasTag("player") then
        return
    end

    inst._virtual_owner = owner
    local container = inst.components.container

    -- 先摘掉所有记录，并逐个执行一次 onunequipfn，让共享状态回到基线。
    local activated = {}
    for item in pairs(inst._virtual_amulets) do
        activated[item] = true
    end
    for item in pairs(activated) do
        DeactivateAmulet(inst, item, owner, true)
    end

    -- 再按容器顺序重新激活。
    for slot = 1, container:GetNumSlots() do
        ActivateAmulet(inst, container:GetItemInSlot(slot), owner, true)
    end

    UpdateInheritedStats(inst, owner)
end

---------------------------------------------------------------------穿脱装备---------------------------------------------------

local function DeactivateAllAmulets(inst, owner)
    --  _virtual_amulets 记录的是“当前确实处于激活态”的集合，更可靠。
    local activated = {}
    for item in pairs(inst._virtual_amulets) do
        activated[item] = true
    end
    for item in pairs(activated) do
        DeactivateAmulet(inst, item, owner, true)
    end
    inst._virtual_owner = nil
    UpdateInheritedStats(inst, owner)
end

local function OnContainerItemGet(inst, data)
    local item = data ~= nil and data.item or nil
    if item ~= nil then
        item:AddTag(STORED_TAG)
    end
    -- 整批重算：新护符可能自带会影响其他护符的共享状态，增量激活无法处理这类互相影响。
    RecalcAmulets(inst)
end

local function OnContainerItemLose(inst, data)
    -- container 的 itemlose 在不同移动路径下可能使用 item 或 prev_item。
    local item = data ~= nil and (data.item or data.prev_item) or nil
    if item ~= nil then
        item:RemoveTag(STORED_TAG)
    end
    -- 关键：不能只卸载这一件。这些护符的 onunequip 会无条件还原玩家身上的共享状态，
    RecalcAmulets(inst)
end

local function OnEquip(inst, owner)
    inst:AddTag("kisaki_multivariate_amulet_equipped")
    inst.components.container:Open(owner)
    RecalcAmulets(inst, owner)
end

local function OnUnequip(inst, owner)
    DeactivateAllAmulets(inst, owner)
    inst:RemoveTag("kisaki_multivariate_amulet_equipped")
    inst.components.container:Close(owner)
end

---------------------------------------------------------------------预制物构建---------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst, "med", nil, 0.75)

    inst.AnimState:SetBank("kisaki_multivariate_amulet")
    inst.AnimState:SetBuild("kisaki_multivariate_amulet")
    inst.AnimState:PlayAnimation("anim")

    inst:AddTag("amulet")
    inst:AddTag("shadowlevel")
    inst:AddTag("kisaki_amulet")
    inst:AddTag("kisaki_multivariate_amulet")
    inst:AddTag("hide_percentage") -- 无限耐久

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddTag("meteor_protection")
    inst:AddTag("nosteal")
    inst:AddTag("NORATCHECK")

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "kisaki_multivariate_amulet"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/prefabs/kisaki_multivariate_amulet.xml"

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.NECK or EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    -- 暗影等级
    inst:AddComponent("shadowlevel")
    inst.components.shadowlevel:SetDefaultLevel(0)
    -- 保暖/隔热与防水
    inst:AddComponent("insulator")
    inst.components.insulator:SetWinter()
    inst.components.insulator:SetInsulation(0)
    inst:AddComponent("waterproofer")
    inst.components.waterproofer:SetEffectiveness(0)
    -- 热源/冷源
    inst:AddComponent("heater")
    -- 护甲减伤 / 位面防御
    inst:AddComponent("armor")
    inst.components.armor:InitIndestructible(0)
    inst:AddComponent("planardefense")
    inst.components.planardefense:SetBaseDefense(0)

    -- 容器，能放别的护符
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("kisaki_multivariate_amulet")
    inst.components.container.acceptsstacks = false

    inst._virtual_amulets = {}
    inst._virtual_owner = nil

    inst:ListenForEvent("itemget", OnContainerItemGet)
    inst:ListenForEvent("itemlose", OnContainerItemLose)
    inst:ListenForEvent("onremove", function()
        DeactivateAllAmulets(inst, inst._virtual_owner or GetOwner(inst))
        -- 容器随护符一起销毁时不一定逐个触发 itemlose，这里兜底摘掉收纳 tag。
        local container = inst.components.container
        for slot = 1, container:GetNumSlots() do
            local item = container:GetItemInSlot(slot)
            if item ~= nil then
                item:RemoveTag(STORED_TAG)
            end
        end
    end)
    inst:DoPeriodicTask(67, UpdateInheritedStats) -- 定时刷一下（主要是保暖）

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("kisaki_multivariate_amulet", fn, assets)
