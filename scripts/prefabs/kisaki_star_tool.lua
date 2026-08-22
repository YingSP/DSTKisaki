local name = "kisaki_star_tool"

local assets = {
    Asset("ANIM", "anim/" .. name .. ".zip"),
    Asset("ATLAS", "images/inventoryimages/prefabs/" .. name .. ".xml"),
    Asset("IMAGE", "images/inventoryimages/prefabs/" .. name .. ".tex"),
}

local prefabs = {
    "farm_soil",
    "cane_victorian_fx",
}

local AUXILIARY_ACTIONS = {
    { action = ACTIONS.HAMMER },
    { action = ACTIONS.DIG,   effectiveness = 10 },
    { action = ACTIONS.NET },
}

local MAX_PLANTS_PER_POINT = 5 -- 每个九宫格点位最多允许重叠种植的植物数量
local PLANT_COUNT_RADIUS = 0.25
local PLANT_COUNT_CANT_TAGS = { "FX", "NOBLOCK", "NOCLICK", "player", "INLIMBO", "_inventoryitem" }

-- 判断物品是否为可种植种子：农田只接收农作物种子，普通地皮同时支持树种和普通可部署植物种子。
local function IsPlantSeed(item, farm_only)
    if item == nil then
        return false
    elseif farm_only then
        return item.components.farmplantable ~= nil
    end

    return item.components.farmplantable == nil and item.components.deployable ~= nil and
        (item.components.plantable ~= nil or item:HasTag("treeseed") or item:HasTag("deployedplant"))
end

-- 从人物物品栏第一格开始查找；空格和非种子物品都会继续检查后续格子。
local function GetFirstPlantSeed(inventory, farm_only)
    for slot = 1, inventory.maxslots do
        local item = inventory:GetItemInSlot(slot)
        if IsPlantSeed(item, farm_only) then
            return item
        end
    end
end

local function GetFarmSoilAtPoint(pt)
    local closest_soil = nil
    local closest_distance = nil
    for _, soil in ipairs(TheSim:FindEntities(pt.x, 0, pt.z, 0.75, { "soil" }, { "NOCLICK", "NOBLOCK" })) do
        local distance = soil:GetDistanceSqToPoint(pt)
        if closest_distance == nil or distance < closest_distance then
            closest_soil = soil
            closest_distance = distance
        end
    end
    return closest_soil
end

-- 统计点位上所有可阻挡实体，兼容无 plant 标签的特殊种子生成物。
local function GetPlantCountAtPoint(pt)
    local count = 0
    for _, plant in ipairs(TheSim:FindEntities(pt.x, 0, pt.z, PLANT_COUNT_RADIUS, nil, PLANT_COUNT_CANT_TAGS)) do
        if plant:GetDistanceSqToPoint(pt) <= PLANT_COUNT_RADIUS * PLANT_COUNT_RADIUS then
            count = count + 1
        end
    end
    return count
end

-- 自定义农作物种植：跳过原版间距检查，首次种植时仍移除对应的耕地实体。
local function PlantFarmSeedDirectly(seed, pt, doer, soil)
    local plant_prefab = FunctionOrValue(seed.components.farmplantable.plant, seed)
    if plant_prefab == nil then
        return false
    end

    local plant = SpawnPrefab(plant_prefab)
    if plant == nil then
        return false
    end

    if soil ~= nil then
        soil:Remove()
    end
    plant.Transform:SetPosition(pt:Get())
    plant:PushEvent("on_planted", { doer = doer, seed = seed, in_soil = true })
    if plant.SoundEmitter ~= nil then
        plant.SoundEmitter:PlaySound("dontstarve/common/plant")
    end
    TheWorld:PushEvent("itemplanted", { doer = doer, pos = pt })
    seed:Remove()
    return true
end

-- 普通种子统一跳过原版空间检测，但仍调用其 ondeploy 保留原有种植效果。
local function DeploySeedDirectly(seed, pt, doer)
    local deployable = seed.components.deployable
    if deployable == nil or deployable.ondeploy == nil then
        return false
    end

    local is_plant = seed:HasTag("deployedplant")
    deployable.ondeploy(seed, pt, doer, 0)
    doer:PushEvent("deployitem", { prefab = seed.prefab })
    if is_plant then
        TheWorld:PushEvent("itemplanted", { doer = doer, pos = pt })
    end
    return true
end

-- 从背包拆出一颗种子后按自定义直种规则处理，避免原版部署间距限制。
local function PlantOneSeed(inventory, seed, pt, doer, farm_only)
    local plant_count = GetPlantCountAtPoint(pt)
    if plant_count >= MAX_PLANTS_PER_POINT then
        return false, "FULL"
    end

    local seed_to_plant = inventory:RemoveItem(seed, false)
    if seed_to_plant == nil then
        return false
    end

    local success = false
    if farm_only then
        if seed_to_plant.components.farmplantable ~= nil then
            success = PlantFarmSeedDirectly(seed_to_plant, pt, doer, GetFarmSoilAtPoint(pt))
        end
    elseif seed_to_plant.components.deployable ~= nil then
        success = DeploySeedDirectly(seed_to_plant, pt, doer)
    end

    -- 种植失败时放回背包，避免因无效点位消耗种子。
    if not success and seed_to_plant:IsValid() then
        inventory:GiveItem(seed_to_plant)
    end
    return success
end

-- 鼠标所在单格地皮的九宫格点位，与万能工具九宫格锄地保持一致。
local function GetNinePlantPoints(pt)
    local x, _, z = TheWorld.Map:GetTileCenterPoint(pt.x, pt.y, pt.z)
    local spacing = 4 / 3
    local points = {}
    for x_offset = -1, 1 do
        for z_offset = -1, 1 do
            table.insert(points, Vector3(x + spacing * x_offset, 0, z + spacing * z_offset))
        end
    end
    return points
end

-- 使用原版 spellcaster 的远程快速施法流程，动作距离与 sorapick 相同（20 格）。
local function PlantNineSeeds(staff, target, pt, doer)
    if doer == nil or pt == nil or doer.components.inventory == nil then
        return
    end

    local inventory = doer.components.inventory
    local farm_only = TheWorld.Map:IsFarmableSoilAtPoint(pt.x, pt.y, pt.z)
    if GetFirstPlantSeed(inventory, farm_only) == nil then
        if doer.components.talker ~= nil then
            doer.components.talker:Say("无可用的种植物")
        end
        return
    end

    local has_full_point = false
    for _, plant_pt in ipairs(GetNinePlantPoints(pt)) do
        local seed = GetFirstPlantSeed(inventory, farm_only)
        if seed == nil then
            break -- 种子不足时，后续点位直接忽略。
        end
        local _, reason = PlantOneSeed(inventory, seed, plant_pt, doer, farm_only)
        has_full_point = has_full_point or reason == "FULL"
    end

    if has_full_point and doer.components.talker ~= nil then
        doer.components.talker:Say("当前地皮已种满")
    end
end

-- 仅允许在可种植陆地施法；种子不足在施法函数内提示，以避免触发默认失败台词。
local function CanPlantNineSeeds(doer, target, pt)
    return pt ~= nil and TheWorld.Map:CanPlantAtPoint(pt.x, pt.y, pt.z)
end

-- 锄头启用时，一次在目标耕地周围生成九块耕地。
local function TillNineSoil(self, pt, doer)
    local x, _, z = TheWorld.Map:GetTileCenterPoint(pt.x, pt.y, pt.z)
    local spacing = 4 / 3
    local tilled = false

    for x_offset = -1, 1 do
        for z_offset = -1, 1 do
            local soil_x = x + spacing * x_offset
            local soil_z = z + spacing * z_offset
            if TheWorld.Map:CanTillSoilAtPoint(soil_x, 0, soil_z, false) then
                TheWorld.Map:CollapseSoilAtPoint(soil_x, 0, soil_z)
                SpawnPrefab("farm_soil").Transform:SetPosition(soil_x, 0, soil_z)
                tilled = true
                if doer ~= nil then
                    doer:PushEvent("tilling")
                end
            end
        end
    end

    return tilled
end

local function EnableFarmTiller(inst)
    if inst.components.farmtiller == nil then
        inst:AddComponent("farmtiller")
        inst.components.farmtiller.Till = TillNineSoil
    end
    inst:AddInherentAction(ACTIONS.TILL)
end

-- 全开状态使用动态名称，关闭辅助功能时还原本地化的默认名称。
local function RefreshName(inst)
    if inst.components.named ~= nil then
        local base_name = STRINGS.NAMES[string.upper(name)]
        inst.components.named:SetName(inst.auxiliary_tools_enabled and (base_name .. "（全开）") or nil)
    end
end

-- 工具组件通过“动作名_tool”标签向客户端提供交互；移除标签即可隐藏对应操作。
local function SetAuxiliaryToolsEnabled(inst, enabled)
    inst.auxiliary_tools_enabled = enabled

    if enabled then
        for _, data in ipairs(AUXILIARY_ACTIONS) do
            inst.components.tool:SetAction(data.action, data.effectiveness)
        end
        EnableFarmTiller(inst)
    else
        for _, data in ipairs(AUXILIARY_ACTIONS) do
            inst:RemoveTag(data.action.id .. "_tool")
        end
        inst:RemoveInherentAction(ACTIONS.TILL)
        if inst.components.farmtiller ~= nil then
            inst:RemoveComponent("farmtiller")
        end
    end

    RefreshName(inst)
end

local function OnUse(inst)
    SetAuxiliaryToolsEnabled(inst, not inst.auxiliary_tools_enabled)

    local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
    if owner ~= nil and owner.components.talker ~= nil then
        owner.components.talker:Say(inst.auxiliary_tools_enabled
            and "已开启锤铲捕锄功能"
            or "已关闭锤铲捕锄功能")
    end

    return false -- 仅切换状态，不进入持续使用状态。
end

local function OnEquip(inst, owner)
    -- 动画包中的 swap_weapon 是手持符号，格式与 mcw_lollipopstaff 一致。
    owner.AnimState:OverrideSymbol("swap_object", name, "swap_weapon")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    -- 装备后添加跟随手持物的星辉特效。
    if inst._equipfx == nil then
        inst._equipfx = SpawnPrefab("cane_victorian_fx")
        if inst._equipfx ~= nil then
            inst._equipfx.entity:AddFollower()
        end
    end
    if inst._equipfx ~= nil then
        inst._equipfx.entity:SetParent(owner.entity)
        inst._equipfx.Follower:FollowSymbol(owner.GUID, "swap_object", 0, -200, 0)
    end
end

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    if inst._equipfx ~= nil then
        inst._equipfx:Remove()
        inst._equipfx = nil
    end
end

local function OnSave(inst, data)
    data.auxiliary_tools_enabled = inst.auxiliary_tools_enabled
end

local function OnPreLoad(inst, data)
    SetAuxiliaryToolsEnabled(inst, data == nil or data.auxiliary_tools_enabled ~= false)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()                     -- 管理实体的位置、旋转和缩放
    inst.entity:AddAnimState()                     -- 控制实体的动画
    inst.entity:AddSoundEmitter()                  -- 管理实体的声音
    inst.entity:AddNetwork()                       -- 网络同步功能
    inst.entity:AddMiniMapEntity()                 -- 世界地图小图标

    MakeInventoryPhysics(inst)                     -- 作为可拾取的物品参与物理碰撞
    MakeInventoryFloatable(inst, "med", nil, 0.75) -- 掉入水中时漂浮
    inst.MiniMapEntity:SetIcon(name .. ".tex")     -- 使用预置物品图标作为地图标记
    inst.AnimState:SetBank(name)                   -- 工具地面动画 Bank
    inst.AnimState:SetBuild(name)                  -- 工具动画材质包
    inst.AnimState:PlayAnimation("anim")           -- 工具地面待机动画

    inst:AddTag(name)                              -- 万能工具标识
    inst:AddTag("tool")                            -- 客户端识别为工具
    inst:AddTag("weapon")                          -- 客户端识别为可攻击武器
    inst:AddTag("hammer")                          -- 可攻击并敲晕鼹鼠
    inst:AddTag("fishingrod")                      -- 客户端提供钓鱼动作
    inst:AddTag("_named")                          -- 允许服务端同步动态物品名称
    inst:AddTag("meteor_protection")               -- 防止被流星破坏
    inst:AddTag("nosteal")                         -- 不可以被猴子偷走
    inst:AddTag("NORATCHECK")                      -- 兼容永不妥协鼠潮计数
    inst.spelltype = "KISAKISTARPLANT"             -- 客户端据此读取 CASTSPELL 的“种植”动作文本

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")   -- 可检查
    inst:AddComponent("named")         -- 全开状态名称后缀
    inst:AddComponent("inventoryitem") -- 可放入背包
    inst.components.inventoryitem.imagename = name
    inst.components.inventoryitem.atlasname = "images/inventoryimages/prefabs/" .. name .. ".xml"

    inst:AddComponent("equippable") -- 可装备到手部
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable.walkspeedmult = 1.25 -- 装备后提升 25% 移速

    inst:AddComponent("weapon")                     -- 用于攻击与敲晕鼹鼠
    inst.components.weapon:SetDamage(1)

    inst:AddComponent("tool")                         -- 多功能工具：砍、挖、开采、锤、铲、捕虫
    inst.components.tool:SetAction(ACTIONS.CHOP, 10)  -- 砍树效率 1000%
    inst.components.tool:SetAction(ACTIONS.MINE, 12)  -- 开采效率 1200%
    inst.components.tool:EnableToughWork(true)        -- 可以敲动梦魇猪柱子等强力开采目标

    inst:AddComponent("fishingrod")                   -- 陆地钓鱼功能
    inst.components.fishingrod:SetWaitTimes(0.1, 0.1) -- 鱼快速上钩
    inst.components.fishingrod:SetStrainTimes(0, 10)

    inst:AddComponent("useableitem") -- 右键切换锤、铲、捕虫、锄头功能
    inst.components.useableitem:SetOnUseFn(OnUse)

    inst:AddComponent("spellcaster") -- 右键远程种植，复用 sorapick 的快速施法动作与范围
    inst.components.spellcaster.canuseonpoint = true
    inst.components.spellcaster.quickcast = true
    inst.components.spellcaster:SetCanCastFn(CanPlantNineSeeds)
    inst.components.spellcaster:SetSpellFn(PlantNineSeeds)
    inst.controller_use_attack_distance = ACTIONS.CASTSPELL.distance

    SetAuxiliaryToolsEnabled(inst, true)

    inst.OnSave = OnSave    -- 保存工具开关状态
    inst.OnPreLoad = OnPreLoad -- 读取后恢复工具开关状态
    inst:ListenForEvent("onremove", function()
        if inst._equipfx ~= nil then
            inst._equipfx:Remove()
        end
    end)
    MakeHauntableLaunch(inst) -- 可作祟

    return inst
end

return Prefab(name, fn, assets, prefabs)
