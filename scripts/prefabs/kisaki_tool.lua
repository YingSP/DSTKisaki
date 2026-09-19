-- 本文件承载 kisaki 系列的两把工具：
--   《神曲》kisaki_star_tool —— 无限耐久的全功能工具（砍挖锤铲捕锄 + 九宫格远程种植）。
--   《新生》kisaki_base_tool —— 有耐久的精简版（无种植），耐久耗尽可喂材料恢复。
-- 预制体名沿用历史名称 kisaki_star_tool：改名会导致旧存档中已生成的物品失效，动画与图标资源也按此名称命名。
--
-- 结构对齐 prefabs/kisaki_boxes.lua：公共逻辑写在模块级函数里，
-- 两把工具的差异集中到下方 tool_defs 表，由 MakeTool 工厂统一装配。
local spell_defs = require("kisaki_defs/spell_defs")
local CanPlantNineSeeds = spell_defs.CanPlantNineSeeds
local PlantNineSeeds = spell_defs.PlantNineSeeds

-------------------------------------------------------------------------------------------------------------
-- 工具通用
--------------------------------------------------------------------------------------------------------------

--【辅助功能开关】右键切换：翻转开关、应用动作状态并播报；返回 false 表示不进入持续使用状态。
local function ToggleAuxiliaryTools(inst)
    inst.auxiliary_tools_enabled = not inst.auxiliary_tools_enabled
    inst.apply_tool_state(inst)

    local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
    if owner ~= nil and owner.components.talker ~= nil then
        owner.components.talker:Say(inst.auxiliary_tools_enabled
            and "已开启锤铲捕锄功能"
            or "已关闭锤铲捕锄功能")
    end

    return false
end
--【辅助功能名称】“全开”动态名称：开启辅助功能时显示“（全开）”后缀，关闭时还原本地化的默认名称。
local function RefreshToolName(inst, name)
    if inst.components.named ~= nil then
        local display_name = STRINGS.NAMES[string.upper(name)]
        inst.components.named:SetName(inst.auxiliary_tools_enabled and (display_name .. "（全开）") or nil)
    end
end

--【九宫格锄地】两把工具共用：一次在目标地皮周围生成九块耕地。
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
-- 给工具挂上九宫格锄地的 farmtiller 组件与锄地动作。
local function EnableFarmTiller(inst)
    if inst.components.farmtiller == nil then
        inst:AddComponent("farmtiller")
        inst.components.farmtiller.Till = TillNineSoil
    end
    inst:AddInherentAction(ACTIONS.TILL)
end
-- 卸下九宫格锄地能力。
local function DisableFarmTiller(inst)
    inst:RemoveInherentAction(ACTIONS.TILL)
    if inst.components.farmtiller ~= nil then
        inst:RemoveComponent("farmtiller")
    end
end

-- 按列表批量注册工作动作。
local function ApplyActions(inst, action_list)
    for _, data in ipairs(action_list) do
        inst.components.tool:SetAction(data.action, data.effectiveness)
    end
end

-- 按列表批量摘掉工作动作的 "xxx_tool" 标签。
local function RemoveActions(inst, action_list)
    for _, data in ipairs(action_list) do
        inst:RemoveTag(data.action.id .. "_tool")
    end
end

--【捕虫网能力】按需增删 fishingrod 组件与标签（《新生》在耐久耗尽时也要摘掉它）。
local function SetFishingRodEnabled(inst, enabled)
    if enabled then
        if inst.components.fishingrod == nil then
            inst:AddComponent("fishingrod")
        end
        inst:AddTag("fishingrod")
    else
        if inst.components.fishingrod ~= nil then
            inst:RemoveComponent("fishingrod")
        end
        inst:RemoveTag("fishingrod")
    end
end

--【工具状态刷新】 算出本刻工作能力是否可用
local function RefreshToolState(inst)
    local tool = inst.components.tool
    if tool == nil then
        return
    end

    -- 耐久等额外门槛：缺省（无限耐久工具）恒为可用。
    local active = inst.active_fn == nil or inst.active_fn(inst)
    local enabled = active and inst.auxiliary_tools_enabled

    -- 基础动作不随开关变化，但耐久耗尽时要摘掉，否则客户端仍显示可砍可挖。
    if inst.base_actions ~= nil then
        if active then
            ApplyActions(inst, inst.base_actions)
        else
            RemoveActions(inst, inst.base_actions)
        end
    end

    if enabled then
        ApplyActions(inst, inst.aux_actions)
        EnableFarmTiller(inst)
    else
        RemoveActions(inst, inst.aux_actions)
        DisableFarmTiller(inst)
    end

    if inst.manage_fishingrod then
        SetFishingRodEnabled(inst, enabled)
    end

    RefreshToolName(inst, inst.def_name)
end

--------------------------------------------------------------------------------------------------------------------------------
-- 工具统一定义与装配
--------------------------------------------------------------------------------------------------------------------------------

--【实体搭建】两把工具共用的网络侧实体结构、漂浮表现与通用标签。
local function SetupCommonToolEntity(inst, name, def)
    inst.entity:AddTransform()                       -- 管理实体的位置、旋转和缩放
    inst.entity:AddAnimState()                       -- 控制实体的动画
    inst.entity:AddSoundEmitter()                    -- 管理实体的声音
    inst.entity:AddNetwork()                         -- 网络同步功能
    inst.entity:AddMiniMapEntity()                   -- 世界地图小图标

    MakeInventoryPhysics(inst)                       -- 作为可拾取的物品参与物理碰撞
    MakeInventoryFloatable(inst, "med", nil, 0.75)   -- 掉入水中时漂浮
    inst.MiniMapEntity:SetIcon(name .. ".tex")       -- 使用物品图标作为地图标记
    inst.AnimState:SetBank(def.bank or name)         -- 工具地面动画 Bank
    inst.AnimState:SetBuild(def.build or name)       -- 工具动画材质包
    inst.AnimState:PlayAnimation(def.anim or "idle") -- 工具地面待机动画

    inst:AddTag(name)                                -- 工具标识
    inst:AddTag("tool")                              -- 客户端识别为工具
    inst:AddTag("weapon")                            -- 客户端识别为可攻击武器
    inst:AddTag("hammer")                            -- 武器攻击可敲晕鼹鼠（原版按攻击武器的 hammer 标签判定）
    inst:AddTag("fishingrod")                        -- 客户端提供钓鱼动作
    inst:AddTag("_named")                            -- 允许服务端同步动态物品名称
    -- 免疫“鱼把钓竿拖走”。《神曲》没有 finiteuses，本来就不会被拖走；《新生》有耐久，必须靠这个 tag 豁免。
    inst:AddTag("kisaki_immune_rod_loss")
    if def.tags then
        for _, tag in ipairs(def.tags) do
            inst:AddTag(tag)
        end
    end

    -- 客户端侧额外初始化（《神曲》据此读取 CASTSPELL 的“种植”动作文本）
    if def.entity_postinit then
        def.entity_postinit(inst)
    end
end

--【装备特效】装备：替换手持贴图，并挂上跟随手持物的星辉特效。
local function EquipHeldTool(inst, owner, name)
    -- 动画包中的 swap_weapon 是手持符号。
    owner.AnimState:OverrideSymbol("swap_object", name, "swap_weapon")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

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

-- 卸下：还原手臂动画并摘除星辉特效。
local function UnequipHeldTool(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")

    if inst._equipfx ~= nil then
        inst._equipfx:Remove()
        inst._equipfx = nil
    end
end

-- 实体移除时清理星辉特效，作为 onremove 监听复用。
local function CleanupEquipFx(inst)
    if inst._equipfx ~= nil then
        inst._equipfx:Remove()
    end
end

-- 开关状态存档：保存。
local function SaveToggleState(inst, data)
    data.auxiliary_tools_enabled = inst.auxiliary_tools_enabled
end

-- 开关状态存档：读取后经各工具自己的 apply_tool_state 恢复动作状态。
local function PreLoadToggleState(inst, data)
    inst.auxiliary_tools_enabled = data == nil or data.auxiliary_tools_enabled ~= false
    inst.apply_tool_state(inst)
end

-- 工具统一定义方法
local function MakeTool(name, def)
    -- 导入动画
    local assets = {
        Asset("ANIM", "anim/" .. name .. ".zip"),
        Asset("ATLAS", "images/inventoryimages/prefabs/" .. name .. ".xml"),
        Asset("IMAGE", "images/inventoryimages/prefabs/" .. name .. ".tex"),
    }
    if def.assets then
        for i, v in ipairs(def.assets) do
            table.insert(assets, Asset("ANIM", "anim/" .. v .. ".zip"))
        end
    end

    local function fn()
        local inst = CreateEntity()

        SetupCommonToolEntity(inst, name, def)

        inst:AddTag("meteor_protection") -- 防止被流星破坏
        inst:AddTag("nosteal")           -- 不可以被猴子偷走
        inst:AddTag("NORATCHECK")        -- mod兼容：永不妥协。该道具不算鼠潮分

        inst.entity:SetPristine()        -- 设置为初始状态
        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")   -- 可检查
        inst:AddComponent("named")         -- 全开状态名称后缀
        inst:AddComponent("inventoryitem") -- 可放入背包
        inst.components.inventoryitem.imagename = def.image or name
        inst.components.inventoryitem.atlasname = def.atlas or ("images/inventoryimages/prefabs/" .. name .. ".xml")

        inst:AddComponent("equippable") -- 可装备到手部
        inst.components.equippable:SetOnEquip(function(inst_, owner) EquipHeldTool(inst_, owner, name) end)
        inst.components.equippable:SetOnUnequip(UnequipHeldTool)
        inst.components.equippable.walkspeedmult = def.walkspeedmult or 1 -- 装备后的移速倍率

        inst.def_name = name
        inst.active_fn = def.active_fn                 -- 是否可用
        inst.manage_fishingrod = def.manage_fishingrod -- 钓鱼是否可用
        inst.base_actions = def.base_actions           -- 基础功能
        inst.aux_actions = def.aux_actions             -- 可切换功能
        inst.apply_tool_state = RefreshToolState

        -- 额外执行方法
        if def.master_postinit then
            def.master_postinit(inst)
        end

        RefreshToolState(inst)              -- 首次应用：按 enable 状态与耐久门槛注册工作动作

        inst.OnSave = SaveToggleState       -- 保存工具开关状态
        inst.OnPreLoad = PreLoadToggleState -- 读取后恢复工具开关状态

        inst:ListenForEvent("onremove", CleanupEquipFx)
        MakeHauntableLaunch(inst) -- 可作祟

        return inst
    end

    return Prefab(name, fn, assets, def.prefabs)
end

--------------------------------------------------------------------------------------------------------------------------------
-- 工具列表
--------------------------------------------------------------------------------------------------------------------------------

local tool_defs = {}
-- 《新生》
local BASE_MAX_USES = 2500
-- 各工作动作的单次耐久消耗：砍1 / 镐6 / 铲8 / 锤8 / 捕虫60 / 九宫格锄地72
local BASE_USE_CONSUMPTION = {
    [ACTIONS.CHOP] = 1,
    [ACTIONS.MINE] = 6,
    [ACTIONS.DIG] = 8,
    [ACTIONS.HAMMER] = 8,
    [ACTIONS.NET] = 60,
    [ACTIONS.TILL] = 72,
}
local BASE_FISH_CONSUMPTION = 33 -- 每钓上一次的耐久消耗，与原版钓竿一样在收取时扣
-- 耐久恢复材料白名单：单件回复量
local REPAIR_MATERIALS = {
    twigs = 50,
    cutgrass = 50,
    flint = 50,
    rocks = 50,
    silk = 100,
    goldnugget = 100,
}
local function BaseHasUses(inst)
    return inst.components.finiteuses ~= nil and inst.components.finiteuses:GetUses() > 0
end
-- 仅接受白名单材料，且耐久未满。
local function BaseRepairAcceptTest(inst, item)
    if item == nil or REPAIR_MATERIALS[item.prefab] == nil or inst.components.finiteuses == nil then
        return false
    end
    return inst.components.finiteuses:GetUses() < inst.components.finiteuses.total
end
-- 吃材料回耐久：整除时恰好补满；不能整除时向下取整留缺口；缺口不足单份时吃 1 个按缺口封顶；材料不够有多少吃多少。
local function BaseRepairOnAccept(inst, giver, item)
    local finiteuses = inst.components.finiteuses
    local worth = item ~= nil and REPAIR_MATERIALS[item.prefab] or nil
    if finiteuses == nil or worth == nil or giver == nil then
        return
    end

    local missing = finiteuses.total - finiteuses:GetUses()
    if missing <= 0 then
        return
    end

    local stacksize = item.components.stackable ~= nil and item.components.stackable.stacksize or 1
    local count = missing % worth == 0 and missing / worth or math.floor(missing / worth)
    count = math.max(count, 1)                    -- 缺口不足单份时至少吃 1 个
    count = math.min(count, stacksize)            -- 材料不够时有多少吃多少
    local uses = math.min(count * worth, missing) -- 回复量按缺口封顶，永不超上限

    -- 引擎整叠收走材料，吃不完的部分重新生成并退还
    if stacksize > count then
        local excess = SpawnPrefab(item.prefab)
        if excess ~= nil then
            if excess.components.stackable ~= nil then
                excess.components.stackable:SetStackSize(stacksize - count)
            end
            giver.components.inventory:GiveItem(excess, nil, giver:GetPosition())
        end
    end

    finiteuses:SetUses(finiteuses:GetUses() + uses)

    if giver.components.talker ~= nil then
        giver.components.talker:Say(string.format("耐久恢复了%d点（当前%d/%d）",
            uses, finiteuses:GetUses(), finiteuses.total))
    end
end
-- 拒绝时说明原因：满耐久或材料不在白名单。
local function BaseRepairOnRefuse(inst, giver, item)
    if giver == nil or giver.components.talker == nil then
        return
    end

    local finiteuses = inst.components.finiteuses
    if finiteuses ~= nil and finiteuses:GetUses() >= finiteuses.total then
        giver.components.talker:Say("耐久已满，不需要恢复。")
        return
    end

    local material_names = {}
    for prefab in pairs(REPAIR_MATERIALS) do
        table.insert(material_names, STRINGS.NAMES[string.upper(prefab)] or prefab)
    end
    table.sort(material_names)
    giver.components.talker:Say("需要 " .. table.concat(material_names, "、") .. " 来恢复耐久。")
end
tool_defs.kisaki_base_tool = {
    prefabs = {
        "farm_soil",
        "cane_victorian_fx",
    },
    anim = "idle",       -- 导出工程中的地面待机动画名为 idle
    walkspeedmult = 1.1, -- 装备后提升 10% 移速
    -- 基础动作不随开关变化，只受耐久门槛影响（效率对齐原版斧、镐）
    base_actions = TUNING.BASE_BASE_ACTIONS,
    aux_actions = TUNING.BASE_AUXILIARY_ACTIONS, -- 辅助功能组（右键切换）
    manage_fishingrod = true,                    -- 耐久耗尽时连钓鱼能力一并摘掉
    active_fn = BaseHasUses,                     -- 耐久为 0 则全部工作动作不可用
    master_postinit = function(inst)
        inst:AddComponent("weapon")              -- 用于攻击与敲晕鼹鼠
        inst.components.weapon:SetDamage(20)

        inst:AddComponent("tool")       -- 多功能工具：砍、挖、开采，效率与原版一致
        inst:AddComponent("finiteuses") -- 原版耐久组件
        inst.components.finiteuses:SetMaxUses(BASE_MAX_USES)
        inst.components.finiteuses:SetUses(BASE_MAX_USES)
        for action, consumption in pairs(BASE_USE_CONSUMPTION) do
            inst.components.finiteuses:SetConsumption(action, consumption)
        end
        -- 耐久耗尽不销毁物品（不挂 SetOnFinished），只禁用工作动作；武器攻击不扣耐久
        inst.components.finiteuses:SetIgnoreCombatDurabilityLoss(true)

        inst:AddComponent("shaver")     -- 剃刀功能（刮牛毛等），独立动作不消耗耐久

        inst:AddComponent("fishingrod") -- 陆地钓鱼，数值与原版钓竿一致
        inst.components.fishingrod:SetWaitTimes(4, 40)
        inst.components.fishingrod:SetStrainTimes(0, 5)
        inst:ListenForEvent("fishingcollect", function(inst_) -- 钓上东西才扣耐久，与原版钓竿一致
            if BaseHasUses(inst_) then
                inst_.components.finiteuses:Use(BASE_FISH_CONSUMPTION)
            end
        end)

        inst:AddComponent("useableitem") -- 右键切换锤、铲、捕虫、锄头功能
        inst.components.useableitem:SetOnUseFn(ToggleAuxiliaryTools)

        inst:AddComponent("trader") -- 手持基础材料右键给予可恢复耐久
        -- 基础材料没有 tradable 标签，必须挂 alltrader 才能对所有手持物提供给予动作
        inst.components.trader.acceptnontradable = true
        inst.components.trader:SetAcceptStacks() -- 允许整叠喂食
        inst.components.trader:SetAcceptTest(BaseRepairAcceptTest)
        inst.components.trader.onaccept = BaseRepairOnAccept
        inst.components.trader.onrefuse = BaseRepairOnRefuse

        inst:ListenForEvent("percentusedchange", RefreshToolState) -- 耐久变化时刷新工作状态

        inst.auxiliary_tools_enabled = true
    end,
}

-- 《神曲》
tool_defs.kisaki_star_tool = {
    prefabs = {
        "farm_soil",
        "cane_victorian_fx",
    },
    anim = "anim",
    walkspeedmult = 1.25,                  -- 装备后提升 25% 移速
    entity_postinit = function(inst)
        inst.spelltype = "KISAKISTARPLANT" -- 客户端据此读取 CASTSPELL 的“种植”动作文本
    end,
    base_actions = TUNING.STAR_BASE_ACTIONS,
    aux_actions = TUNING.STAR_AUXILIARY_ACTIONS, -- 辅助功能组（右键切换）
    -- 无限耐久：无耐久门槛（active_fn 缺省恒为真），钓鱼能力常驻不随开关增删
    master_postinit = function(inst)
        inst:AddComponent("weapon") -- 用于攻击与敲晕鼹鼠
        inst.components.weapon:SetDamage(20)

        inst:AddComponent("tool")                         -- 多功能工具：砍、挖、开采、锤、铲、捕虫
        inst.components.tool:EnableToughWork(true)        -- 可以敲动梦魇猪柱子等强力开采目标

        inst:AddComponent("shaver")                       -- 剃刀功能（刮牛毛等），独立动作不消耗任何资源

        inst:AddComponent("fishingrod")                   -- 陆地钓鱼功能
        inst.components.fishingrod:SetWaitTimes(0.1, 0.1) -- 鱼快速上钩
        inst.components.fishingrod:SetStrainTimes(0, 10)

        inst:AddComponent("spellcaster") -- 右键远程种植
        inst.components.spellcaster.canuseonpoint = true
        inst.components.spellcaster.quickcast = true
        inst.components.spellcaster:SetCanCastFn(CanPlantNineSeeds)
        inst.components.spellcaster:SetSpellFn(PlantNineSeeds)
        inst.controller_use_attack_distance = ACTIONS.CASTSPELL.distance

        inst:AddComponent("useableitem") -- 右键切换锤、铲、捕虫、锄头功能
        inst.components.useableitem:SetOnUseFn(ToggleAuxiliaryTools)

        inst.auxiliary_tools_enabled = true
    end
}

local tools = {}
for k, v in pairs(tool_defs) do
    local item = MakeTool(k, v)
    if item then
        table.insert(tools, item)
    end
end
return unpack(tools)
