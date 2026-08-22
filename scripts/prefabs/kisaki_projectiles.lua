local LUNAR_BOMB_RANGE = TUNING.BOMB_LUNARPLANT_RANGE
local GROUND_ITEM_MUST_TAGS = { "_inventoryitem" }

-- 为单个转化成功的物品添加闪亮特效。
local function SpawnTransformFx(x, y, z)
    local fx = SpawnPrefab("fx_book_light")
    if fx then
        fx.Transform:SetPosition(x, y, z)
    end
end

-- 转化单个地面物品。延时执行前会再次校验，避免转化已经被拾取或移走的物品。
local function TransformGroundItem(item)
    local item_transform_list = TUNING.KISAKI_ITEM_TRANSFORM_LIST
    if not (item and item:IsValid() and not item:IsInLimbo()) then
        return false
    end

    local inventoryitem = item.components.inventoryitem
    local transform_prefab = item_transform_list[item.prefab]
    -- IsInLimbo / IsHeld 可排除容器、背包和装备栏内的物品，只处理落在地上的物品。
    if not (transform_prefab and inventoryitem and not inventoryitem:IsHeld()) then
        return false
    end

    local item_x, item_y, item_z = item.Transform:GetWorldPosition()
    local count = item.components.stackable and item.components.stackable:StackSize() or 1
    local transformed_item = SpawnPrefab(transform_prefab)
    if transformed_item == nil then
        return false
    end

    -- 先成功创建目标物品，再删除原物品，防止配置名错误时丢失原物品。
    item:Remove()
    while transformed_item do
        local stackable = transformed_item.components.stackable
        if stackable then
            local stack_size = math.min(count, stackable.maxsize)
            stackable:SetStackSize(stack_size)
            count = count - stack_size
        else
            count = count - 1
        end
        transformed_item.Transform:SetPosition(item_x, item_y, item_z)

        if count > 0 then
            transformed_item = SpawnPrefab(transform_prefab)
        else
            transformed_item = nil
        end
    end
    SpawnTransformFx(item_x, item_y, item_z)
    return true
end

-- 在落点附近筛选地面物品，分批随机执行转化，降低同帧压力。
local function TransformGroundItems(x, y, z, range)
    local items = TheSim:FindEntities(x, y, z, range, GROUND_ITEM_MUST_TAGS, { "INLIMBO" })
    local transform_items = {}
    local item_transform_list = TUNING.KISAKI_ITEM_TRANSFORM_LIST
    for _, item in ipairs(items) do
        local inventoryitem = item.components.inventoryitem
        if inventoryitem and not inventoryitem:IsHeld() and item_transform_list[item.prefab] then
            table.insert(transform_items, item)
        end
    end

    if #transform_items > 0 then
        -- 首个物品立即转化，剩余物品在 0~0.33 秒内分散处理。
        TransformGroundItem(table.remove(transform_items, math.random(#transform_items)))
        if #transform_items > 0 then
            local timevar = 1 - 1 / (#transform_items + 1)
            for _, item in ipairs(transform_items) do
                item:DoTaskInTime(timevar * math.random() / 3, TransformGroundItem)
            end
        end
    end
end

-- 修复枯萎植物，并将可移植的普通植物恢复为野生状态，后续无需再次施肥。
local function RestorePlant(inst)
    if not (inst and inst:IsValid() and not inst:IsInLimbo()) then
        return false
    end
    local restored = false
    local pickable = inst.components.pickable
    if pickable and (pickable.transplanted or pickable:IsBarren()) then
        pickable.transplanted = false
        if pickable:IsBarren() then
            pickable:MakeEmpty()
        end
        pickable.cycles_left = pickable.max_cycles
        restored = true
    end
    -- 棱镜模组的一代作物：解除腐烂并恢复生长计时。
    local perennialcrop = inst.components.perennialcrop
    if perennialcrop and perennialcrop.isrotten then
        perennialcrop:SetStage(perennialcrop.stage, perennialcrop.ishuge, false, true, false)
        if perennialcrop.timedata and perennialcrop.timedata.paused then
            perennialcrop.timedata.left = nil
            perennialcrop.timedata.start = nil
            perennialcrop.timedata.all = nil
        else
            perennialcrop:StartGrowing()
        end
        restored = true
    end
    -- 棱镜模组的二代作物：解除腐烂并重新进入生长流程。
    local perennialcrop2 = inst.components.perennialcrop2
    if perennialcrop2 and perennialcrop2.isrotten then
        perennialcrop2:SetStage(perennialcrop2.stage, false, false)
        perennialcrop2:StartGrowing()
        restored = true
    end
    if restored then
        local x, y, z = inst.Transform:GetWorldPosition()
        local fx = SpawnPrefab("crab_king_shine")
        if fx then
            fx.Transform:SetPosition(x, y, z)
        end
    end
    return restored
end

-- 处理落点范围内的枯萎植物及棱镜作物。
local GARDENING_CANT_TAGS = { "pickable", "stump", "INLIMBO", "soil", "FX", "DECOR", "NOCLICK", "NOBLOCK",
    "player", "companion", "smallcreature", "_inventoryitem", "catchable", "burnt" }
local function RestorePlants(x, y, z, range)
    local plants = TheSim:FindEntities(x, y, z, range, nil, GARDENING_CANT_TAGS)
    if #plants > 0 then
        RestorePlant(table.remove(plants, math.random(#plants)))
        if #plants > 0 then
            local timevar = 1 - 1 / (#plants + 1)
            for i, v in ipairs(plants) do
                v:DoTaskInTime(timevar * math.random(), RestorePlant)
            end
        end
    end
end

-- 以太瓶落地：播放月亮植物炸弹的落点特效，并转化范围内地面物品；不造成伤害。
local function OnEtherBottleHit(inst, attacker, target)
    local x, y, z = inst.Transform:GetWorldPosition()
    TransformGroundItems(x, y, z, LUNAR_BOMB_RANGE)
    RestorePlants(x, y, z, LUNAR_BOMB_RANGE)

    local fx = SpawnPrefab("bomb_lunarplant_explode_fx")
    if fx then
        fx.Transform:SetPosition(x, y, z)
    end
    inst:Remove()
end

local function OnEtherBottleThrown(inst, attacker)
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.Physics:SetMass(1)
    inst.Physics:SetFriction(0)
    inst.Physics:SetDamping(0)
    inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
    inst.Physics:SetCollisionMask(COLLISION.GROUND, COLLISION.OBSTACLES, COLLISION.ITEMS)
    inst.Physics:SetCapsule(.2, .2)
end

-- 原版月亮植物炸弹的鼠标指针范围和有效落点判断。
local function ReticuleTargetFn()
    local player = ThePlayer
    local ground = TheWorld.Map
    local pos = Vector3()
    for range = 6.5, 3.5, -.25 do
        pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(range, 0, 0)
        if ground:IsPassableAtPoint(pos:Get()) and not ground:IsGroundTargetBlocked(pos) then
            return pos
        end
    end
    return pos
end

local function MakeProjectile(name, def)
    -- 导入动画
    local assets = def.assets or {
        Asset("ANIM", "anim/" .. name .. ".zip"),
        Asset("ATLAS", "images/inventoryimages/prefabs/" .. name .. ".xml"),
        Asset("IMAGE", "images/inventoryimages/prefabs/" .. name .. ".tex")
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()                       -- 管理实体的位置、旋转和缩放
        inst.entity:AddAnimState()                       -- 控制实体的动画
        inst.entity:AddSoundEmitter()                    -- 管理实体的声音
        inst.entity:AddNetwork()                         -- 网络同步功能

        MakeInventoryPhysics(inst)                       -- 为实体添加物理特性，使其能够作为物品被玩家拾取和携带。
        MakeInventoryFloatable(inst, "med", nil, 0.75)   -- 为实体添加浮力特性，使其能够在水中漂浮。

        inst.AnimState:SetBank(def.bank or name)         -- 地上动画
        inst.AnimState:SetBuild(def.build or name)       -- 材质包，就是anim里的zip包
        inst.AnimState:PlayAnimation(def.anim or "idle") -- 默认播放哪个动画

        inst.Transform:SetTwoFaced()
        -- complexprojectile / weapon 标签需要在 SetPristine 前添加，供客户端识别投掷能力。
        inst:AddTag("projectile")
        inst:AddTag("complexprojectile")
        inst:AddTag("weapon")

        inst:AddComponent("reticule") -- 投掷范围
        inst.components.reticule.twinstickcheckscheme = true
        inst.components.reticule.twinstickmode = 1
        inst.components.reticule.twinstickrange = 8
        inst.components.reticule.targetfn = ReticuleTargetFn
        inst.components.reticule.ease = true

        -- 添加标签
        inst:AddTag("kisaki_projectile")
        if def.tags then
            for _, tag in pairs(def.tags) do
                inst:AddTag(tag)
            end
        end
        -- 额外执行方法
        if def.eneity_postinit then
            def.eneity_postinit(inst)
        end

        inst.entity:SetPristine() -- 设置为初始状态
        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddTag("meteor_protection")   -- 防止被流星破坏
        inst:AddTag("nosteal")             -- 不可以被猴子偷走
        inst:AddTag("NORATCHECK")          -- mod兼容：永不妥协。该道具不算鼠潮分

        inst:AddComponent("inspectable")   -- 可检查
        inst:AddComponent("inventoryitem") -- 可放入背包
        inst.components.inventoryitem.imagename = def.image or name
        inst.components.inventoryitem.atlasname = def.atlas or ("images/inventoryimages/prefabs/" .. name .. ".xml")

        inst:AddComponent("stackable") -- 可堆叠
        inst.components.stackable.maxsize = def.maxsize or TUNING.STACK_SIZE_PELLET

        inst:AddComponent("tradable")          -- 可交易
        inst:AddComponent("locomotor")
        inst:AddComponent("complexprojectile") -- 投掷物
        inst.components.complexprojectile:SetHorizontalSpeed(15)
        inst.components.complexprojectile:SetGravity(-35)
        inst.components.complexprojectile:SetLaunchOffset(Vector3(.25, 1, 0))
        inst.components.complexprojectile:SetOnLaunch(OnEtherBottleThrown)
        inst.components.complexprojectile:SetOnHit(def.onhit)
        -- 伤害固定为 0；weapon 组件仅用于启用原版投掷操作。
        inst:AddComponent("weapon")
        inst.components.weapon:SetDamage(0)
        inst.components.weapon:SetRange(8, 10)
        inst:AddComponent("equippable")
        inst.components.equippable.equipstack = true -- 装备的时候可堆叠

        MakeHauntableLaunch(inst)                    -- 可作祟

        -- 额外执行方法
        if def.master_postinit then
            def.master_postinit(inst)
        end

        -- 保存读取
        if def.onsave then
            inst.OnSave = def.onsave
        end
        if def.onload then
            inst.OnLoad = def.onload
        end
        if def.onpreload then
            inst.OnPreLoad = def.onpreload
        end

        return inst
    end

    return Prefab(name, fn, assets, def.prefabs)
end

local projectile_defs = {} -- 投掷物列表

-- 以太瓶
projectile_defs.kisaki_ether_bottle = {
    onhit = OnEtherBottleHit,
    prefabs = { "bomb_lunarplant_explode_fx", "crab_king_shine", "fx_book_light", "reticule", "reticuleaoe", "reticuleaoeping" },
}

local projectiles = {}
for k, v in pairs(projectile_defs) do
    table.insert(projectiles, MakeProjectile(k, v))
end
return unpack(projectiles)
