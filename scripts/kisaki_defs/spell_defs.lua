-- 右键功能：本项目的右键施法函数统一存档于此——
--   法杖右键施法（旅/渡海之诗）：各状态施法函数与统一入口；
--   工具右键种植（《神曲》）：spellcaster 九宫格种植。

-- 传送相关全局函数（FindNearestActiveTelebase 在 prefabs/telebase.lua 中定义
require "prefabs/telebase"
-- 读取文本表
local function Text(key)
    return STRINGS.KISAKI_MAGIC_STAFF ~= nil and STRINGS.KISAKI_MAGIC_STAFF[key] or nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- 法杖右键施法（旅 / 渡海之诗）
-------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
-- 点燃 / 扑灭
------------------------------------------------------------------------------------------------------------------------------

-- 寒冷值增量：与原版 icestaff 一致（普通生物 freezable.resistance 为 1，故一次即冻住）
local ICESTAFF_COLDNESS = 1

-- 点燃（对齐原版 firestaff 的 onattack_red，把那套"攻击即点燃"搬到右键）：
--   1. 可燃的敌人/生物：直接点燃（原版火杖打谁谁着火）
--   2. 营火类建筑：补充一份草作为燃料
--   3. 已是燃烧态则视为无需处理
local function SpellIgnite(inst, target, pos, doer)
    if target == nil or not target:IsValid() then
        return false
    end

    local fueled = target.components.fueled
    local burnable = target.components.burnable

    -- 先处理"营火类以可燃物为燃料的建筑"：与火杖攻击营火一致，补充一份草作为燃料
    if fueled ~= nil and (fueled.fueltype == FUELTYPE.BURNABLE or fueled.secondaryfueltype == FUELTYPE.BURNABLE) then
        if fueled.accepting then
            local fuel = SpawnPrefab("cutgrass")
            if fuel ~= nil then
                if fuel.components.fuel ~= nil and fuel.components.fuel.fueltype == FUELTYPE.BURNABLE then
                    fueled:TakeFuelItem(fuel)
                    return true
                end
                fuel:Remove()
            end
        end
        doer.components.talker:Say(Text("CANT_IGNITE"))
        return false
    end

    if burnable ~= nil then
        if burnable:IsBurning() then
            -- 已经在燃烧，无需处理
            return true
        end

        -- 冰冻中的目标先解冻，再点燃（原版火杖同理）
        if target.components.freezable ~= nil and target.components.freezable:IsFrozen() then
            target.components.freezable:Unfreeze()
        end

        -- canlight = 可燃物；带 combat 的 = 可被点燃的活物（原版的判定条件）
        if burnable.canlight or target.components.combat ~= nil then
            -- 睡眠中的目标被点燃会惊醒（对齐原版 onattack_red）
            if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
                target.components.sleeper:WakeUp()
            end
            -- 被点燃的活物会记住是谁干的（对齐原版 SuggestTarget）
            if target.components.combat ~= nil then
                target.components.combat:SuggestTarget(doer)
            end

            burnable:Ignite(true, doer)
            doer.SoundEmitter:PlaySound("dontstarve/wilson/fireball_explo")
            -- 对齐原版：点燃后补一个 0 伤害的 attacked 事件，让受击表现（闪白/仇恨/成就统计）正常触发
            if target.sg ~= nil and not target.sg:HasStateTag("frozen") then
                target:PushEvent("attacked", { attacker = doer, damage = 0, weapon = inst })
            end
            return true
        end
    end

    doer.components.talker:Say(Text("CANT_IGNITE"))
    return false
end

-- 可被扑灭的召唤星光（对应"唤星"/"唤月"两种状态召出来的光）
local EXTINGUISHABLE_LIGHTS = {
    stafflight = true,
    staffcoldlight = true,
}
-- 冰冻（对齐原版 icestaff 的 onattack_blue，把"攻击即冰冻"搬到右键）：
--   1. 可燃目标：优先扑灭火焰/闷烧（原版冰杖也会先灭火）
--   2. 可被冻结的敌人/生物：累加寒冷值，够则冻住
--   3. 召唤的星光：熄灭表现
-- 不对施法者自己生效：本模组的 can_cast_fn 恒为 true，若不拦会让玩家把自己冻住。
local function SpellFreeze(inst, target, pos, doer)
    if target == nil or not target:IsValid() then
        return false
    end
    if target == doer or target:HasTag("player") then
        -- 冰冻会 StopBrain 并进入 frozen 状态，对玩家是自己把自己控住，直接忽略
        return false
    end

    -- 星光：复刻原版 stafflight 的熄灭表现——停循环音效、播消散动画、1 秒后移除。
    -- _killed 用来阻止它继续随机播放待机动画（原版同名字段）。
    if EXTINGUISHABLE_LIGHTS[target.prefab] then
        if target._killed then
            return false -- 已经在消散中
        end
        target._killed = true
        target.SoundEmitter:KillSound("staff_star_loop")
        target.AnimState:PlayAnimation(target.pst or "disappear")
        target:DoTaskInTime(1, target.Remove)
        doer.SoundEmitter:PlaySound("dontstarve/common/fireOut")
        return true
    end

    -- 火焰/闷烧：与原版冰杖一致，优先扑灭
    local burnable = target.components.burnable
    if burnable ~= nil then
        if burnable:IsBurning() then
            burnable:Extinguish()
            doer.SoundEmitter:PlaySound("dontstarve/common/fireOut")
            return true
        elseif burnable:IsSmoldering() then
            burnable:SmotherSmolder()
            doer.SoundEmitter:PlaySound("dontstarve/common/fireOut")
            return true
        end
    end

    -- 可冻结的敌人/生物：对齐原版 onattack_blue 的收尾处理
    local freezable = target.components.freezable
    if freezable ~= nil then
        -- 已经冻住的不再重复处理
        if freezable:IsFrozen() then
            return true
        end

        -- 睡眠中的目标会被冻醒（对齐原版）
        if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then
            target.components.sleeper:WakeUp()
        end
        -- 被冻的活物会记住是谁干的（对齐原版 SuggestTarget）
        if target.components.combat ~= nil then
            target.components.combat:SuggestTarget(doer)
        end

        -- 原版：先补一个 0 伤害的 attacked 事件，让受击表现正常触发
        if target.sg ~= nil and not target.sg:HasStateTag("frozen") then
            target:PushEvent("attacked", { attacker = doer, damage = 0, weapon = inst })
        end

        freezable:AddColdness(ICESTAFF_COLDNESS)
        freezable:SpawnShatterFX()
        doer.SoundEmitter:PlaySound("dontstarve/wilson/ice_shoot")
        return true
    end

    doer.components.talker:Say(Text("NOTHING_TO_EXTINGUISH"))
    return false
end

------------------------------------------------------------------------------------------------------------------------------
-- 传送：移植原版 telestaff（紫色传送法杖）的随机传送逻辑
------------------------------------------------------------------------------------------------------------------------------
local function getrandomposition(caster, teleportee, target_in_ocean)
    if target_in_ocean then
        local pt = TheWorld.Map:FindRandomPointInOcean(20)
        if pt ~= nil then
            return pt
        end
        local from_pt = teleportee:GetPosition()
        local offset = FindSwimmableOffset(from_pt, math.random() * TWOPI, 90, 16)
            or FindSwimmableOffset(from_pt, math.random() * TWOPI, 60, 16)
            or FindSwimmableOffset(from_pt, math.random() * TWOPI, 30, 16)
            or FindSwimmableOffset(from_pt, math.random() * TWOPI, 15, 16)
        if offset ~= nil then
            return from_pt + offset
        end
        return teleportee:GetPosition()
    else
        local centers = {}
        for _, node in ipairs(TheWorld.topology.nodes) do
            if TheWorld.Map:IsPassableAtPoint(node.x, 0, node.y) and node.type ~= NODE_TYPE.SeparatedRoom then
                table.insert(centers, { x = node.x, z = node.y })
            end
        end
        if #centers > 0 then
            local pos = centers[math.random(#centers)]
            return Point(pos.x, 0, pos.z)
        else
            return caster:GetPosition()
        end
    end
end
local function teleport_end(teleportee, locpos, loctarget, staff)
    if loctarget ~= nil and loctarget:IsValid() and loctarget.onteleto ~= nil then
        loctarget:onteleto()
    end

    if teleportee.components.inventory ~= nil and teleportee.components.inventory:IsHeavyLifting() then
        teleportee.components.inventory:DropItem(
            teleportee.components.inventory:Unequip(EQUIPSLOTS.BODY),
            true,
            true
        )
    end

    -- 防止传送落雷点燃自己（原版处理方式）
    local preventburning = teleportee.components.burnable ~= nil and not teleportee.components.burnable.burning
    if preventburning then
        teleportee.components.burnable.burning = true
    end
    TheWorld:PushEvent("ms_sendlightningstrike", locpos)
    if preventburning then
        teleportee.components.burnable.burning = false
    end

    if teleportee:HasTag("player") then
        teleportee.sg.statemem.teleport_task = nil
        teleportee.sg:GoToState(teleportee:HasTag("playerghost") and "appear" or "wakeup")
        teleportee.SoundEmitter:PlaySound("dontstarve/common/staffteleport")
    else
        teleportee:Show()
        if teleportee.DynamicShadow ~= nil then
            teleportee.DynamicShadow:Enable(true)
        end
        if teleportee.components.health ~= nil then
            teleportee.components.health:SetInvincible(false)
        end
        teleportee:PushEvent("teleported")
    end
end
local function teleport_continue(teleportee, locpos, loctarget, staff)
    if teleportee.Physics ~= nil then
        teleportee.Physics:Teleport(locpos.x, 0, locpos.z)
    else
        teleportee.Transform:SetPosition(locpos.x, 0, locpos.z)
    end
    teleportee:PushEvent("teleport_move")

    if teleportee:HasTag("player") then
        teleportee:SnapCamera()
        teleportee:ScreenFade(true, 1)
        teleportee.sg.statemem.teleport_task = teleportee:DoTaskInTime(1, teleport_end, locpos, loctarget, staff)
    else
        teleport_end(teleportee, locpos, loctarget, staff)
    end
end
local function teleport_start(teleportee, staff, caster, loctarget, target_in_ocean, no_teleport)
    local ground = TheWorld

    -- 尽早确定落点，避免传送目标或祭坛中途发生变化
    local locpos
    if not no_teleport then
        locpos = (teleportee.components.teleportedoverride ~= nil and teleportee.components.teleportedoverride:GetDestPosition())
            or (loctarget == nil and getrandomposition(caster, teleportee, target_in_ocean))
            or (loctarget.teletopos ~= nil and loctarget:teletopos())
            or loctarget:GetPosition()

        if teleportee.components.locomotor ~= nil then
            teleportee.components.locomotor:StopMoving()
        end
    end

    if ground:HasTag("cave") then
        -- 洞穴中有屋顶，魔法落雷无法出现，改为小型地震
        ground:PushEvent("ms_miniquake", { rad = 3, num = 5, duration = 1.5, target = teleportee })
        return
    end

    local is_teleporting_player
    if not no_teleport then
        if teleportee:HasTag("player") then
            is_teleporting_player = true
            teleportee.sg:GoToState("forcetele")
        else
            if teleportee.components.health ~= nil then
                teleportee.components.health:SetInvincible(true)
            end
            if teleportee.DynamicShadow ~= nil then
                teleportee.DynamicShadow:Enable(false)
            end
            teleportee:Hide()
        end
    end

    local preventburning = teleportee.components.burnable ~= nil and not teleportee.components.burnable.burning
    if preventburning then
        teleportee.components.burnable.burning = true
    end
    ground:PushEvent("ms_sendlightningstrike", teleportee:GetPosition())
    if preventburning then
        teleportee.components.burnable.burning = false
    end

    ground:PushEvent("ms_deltamoisture", TUNING.TELESTAFF_MOISTURE)

    if not no_teleport then
        if is_teleporting_player then
            teleportee.sg.statemem.teleport_task = teleportee:DoTaskInTime(3, teleport_continue, locpos, loctarget, staff)
        else
            teleport_continue(teleportee, locpos, loctarget, staff)
        end
    end
end

-- 传送：右键传送别人或自己（SAN 消耗在 SpellDispatch 中统一结算）
local function SpellTeleport(inst, target, pos, doer)
    target = target or doer

    local x, y, z = target.Transform:GetWorldPosition()
    local target_in_ocean = target.components.locomotor ~= nil and target.components.locomotor:IsAquatic()
    local no_teleport = target:HasTag("noteleport") or not IsTeleportLinkingPermittedFromPoint(x, y, z)
    local loctarget
    if not no_teleport then
        loctarget = (target.components.minigame_participator ~= nil and target.components.minigame_participator:GetMinigame())
            or (target.components.teleportedoverride ~= nil and target.components.teleportedoverride:GetDestTarget())
            or (target.components.hitchable ~= nil and target:HasTag("hitched") and target.components.hitchable.hitched)
            or nil

        if loctarget == nil and not target_in_ocean then
            loctarget = FindNearestActiveTelebase(x, y, z, nil, 1, "purplegem")
        end
    end
    teleport_start(target, inst, doer, loctarget, target_in_ocean, no_teleport)
    return true
end

------------------------------------------------------------------------------------------------------------------------------
-- 拆解：移植原版 greenstaff（拆解法杖）逻辑
------------------------------------------------------------------------------------------------------------------------------

local DESTSOUNDS =
{
    { soundpath = "dontstarve/common/destroy_magic",    ing = { "nightmarefuel", "livinglog" } },
    { soundpath = "dontstarve/common/destroy_clothing", ing = { "silk", "beefalowool" } },
    { soundpath = "dontstarve/common/destroy_tool",     ing = { "twigs" } },
    { soundpath = "dontstarve/common/gem_shatter",      ing = { "redgem", "bluegem", "greengem", "purplegem", "yellowgem", "orangegem" } },
    { soundpath = "dontstarve/common/destroy_wood",     ing = { "log", "boards" } },
    { soundpath = "dontstarve/common/destroy_stone",    ing = { "rocks", "cutstone" } },
    { soundpath = "dontstarve/common/destroy_straw",    ing = { "cutgrass", "cutreeds" } },
}
local DESTSOUNDSMAP = {}
for _, v in ipairs(DESTSOUNDS) do
    for _, v2 in ipairs(v.ing) do
        DESTSOUNDSMAP[v2] = v.soundpath
    end
end
local function CheckSpawnedLoot(loot)
    if loot.components.inventoryitem ~= nil then
        loot.components.inventoryitem:TryToSink()
    else
        local lootx, looty, lootz = loot.Transform:GetWorldPosition()
        if ShouldEntitySink(loot, true) or TheWorld.Map:IsPointNearHole(Vector3(lootx, 0, lootz)) then
            SinkEntity(loot)
        end
    end
end
local function SpawnLootPrefab(inst, lootprefab)
    if lootprefab == nil then
        return
    end

    local loot = SpawnPrefab(lootprefab)
    if loot == nil then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()

    if loot.Physics ~= nil then
        local angle = math.random() * TWOPI
        loot.Physics:SetVel(2 * math.cos(angle), 10, 2 * math.sin(angle))

        if inst.Physics ~= nil then
            local len = loot:GetPhysicsRadius(0) + inst:GetPhysicsRadius(0)
            x = x + math.cos(angle) * len
            z = z + math.sin(angle) * len
        end

        loot:DoTaskInTime(1, CheckSpawnedLoot)
    end

    loot.Transform:SetPosition(x, y, z)
    loot:PushEvent("on_loot_dropped", { dropper = inst })
end
local function destroystructure(staff, target, caster)
    local recipe = AllRecipes[target.prefab]
    if recipe == nil or FunctionOrValue(recipe.no_deconstruction, target) then
        return false
    end

    -- 按剩余耐久比例返还材料
    local ingredient_percent =
        ((target.components.finiteuses ~= nil and not FunctionOrValue(recipe.decon_ignores_finiteuses, target) and target.components.finiteuses:GetPercent()) or
            (target.components.fueled ~= nil and target.components.inventoryitem ~= nil and target.components.fueled:GetPercent()) or
            (target.components.armor ~= nil and target.components.inventoryitem ~= nil and target.components.armor:GetPercent()) or
            1
        ) / recipe.numtogive

    if target.components.itemmimic then
        -- 拟态物品不返还材料，直接现出原形
        if caster ~= nil then
            caster.SoundEmitter:PlaySound("dontstarve/creatures/monkey/poopsplat")
        end
        target.components.itemmimic:TurnEvil(caster)
    else
        for _, v in ipairs(recipe.ingredients) do
            if caster ~= nil and DESTSOUNDSMAP[v.type] ~= nil then
                caster.SoundEmitter:PlaySound(DESTSOUNDSMAP[v.type])
            end
            -- 宝石材料不返还（与原版一致），彩虹宝石例外
            if string.sub(v.type, -3) ~= "gem" or string.sub(v.type, -11, -4) == "precious" then
                local amt = v.amount == 0 and 0 or math.max(1, math.ceil(v.amount * ingredient_percent))
                for _ = 1, amt do
                    SpawnLootPrefab(target, v.type)
                end
            end
        end

        if target.components.inventory ~= nil then
            target.components.inventory:DropEverything()
        end
        if target.components.container ~= nil then
            target.components.container:DropEverything(nil, true)
        end
        if target.components.spawner ~= nil and target.components.spawner:IsOccupied() then
            target.components.spawner:ReleaseChild()
        end
        if target.components.occupiable ~= nil and target.components.occupiable:IsOccupied() then
            local item = target.components.occupiable:Harvest()
            if item ~= nil then
                item.Transform:SetPosition(target.Transform:GetWorldPosition())
                item.components.inventoryitem:OnDropped()
            end
        end
        if target.components.trap ~= nil then
            target.components.trap:Harvest()
        end
        if target.components.dryer ~= nil then
            target.components.dryer:DropItem()
        end
        if target.components.harvestable ~= nil then
            target.components.harvestable:Harvest()
        end
        if target.components.stewer ~= nil then
            target.components.stewer:Harvest()
        end
        if target.components.constructionsite ~= nil then
            target.components.constructionsite:DropAllMaterials()
        end
        if target.components.inventoryitemholder ~= nil then
            target.components.inventoryitemholder:TakeItem()
        end

        target:PushEvent("ondeconstructstructure", caster)

        if not target.no_delete_on_deconstruct then
            if target.components.stackable ~= nil then
                -- 可堆叠物品只销毁其中一个
                target.components.stackable:Get():Remove()
            else
                target:Remove()
            end
        end
    end

    if caster ~= nil then
        caster.SoundEmitter:PlaySound("dontstarve/common/staff_dissassemble")
    end
    return true
end

-- 拆解：右键可拆解物品进行拆解（SAN 消耗在 SpellDispatch 中统一结算）
local function SpellDeconstruct(inst, target, pos, doer)
    if target == nil or not target:IsValid() then
        return false
    end
    destroystructure(inst, target, doer)
    return true
end

------------------------------------------------------------------------------------------------------------------------------
-- 瞬移：右键地面瞬移（参考原版 orangestaff 的 blinkstaff 组件效果）
------------------------------------------------------------------------------------------------------------------------------

local function CanBlinkToPosition(doer, pos)
    local x, y, z = pos:Get()
    local map = TheWorld.Map
    if map:IsGroundTargetBlocked(pos) then
        return false
    end
    if map:IsPassableAtPoint(x, y, z) then
        return true
    end
    local drownable = doer.components.drownable
    return drownable ~= nil and drownable.enabled == false
        and map:IsOceanTileAtPoint(x, y, z)
        and not map:IsVisualGroundAtPoint(x, y, z)
end

local function SpellBlink(inst, target, pos, doer)
    if pos == nil or doer == nil or not CanBlinkToPosition(doer, pos) then
        return false
    end

    if doer.components.locomotor ~= nil then
        doer.components.locomotor:Stop()
    end
    doer.Physics:Stop()

    -- 出发点特效与音效
    local x, y, z = doer.Transform:GetWorldPosition()
    SpawnPrefab("sand_puff_large_front").Transform:SetPosition(x, y, z)
    SpawnPrefab("sand_puff_large_back").Transform:SetPosition(x, y - .1, z)
    doer.SoundEmitter:PlaySound("dontstarve/common/staff_blink")

    doer:Hide()
    if doer.DynamicShadow ~= nil then
        doer.DynamicShadow:Enable(false)
    end
    if doer.components.health ~= nil then
        doer.components.health:SetInvincible(true)
    end
    if doer.components.playercontroller ~= nil then
        doer.components.playercontroller:Enable(false)
    end

    doer:DoTaskInTime(.25, function()
        if not doer:IsValid() then
            return
        end
        -- 延迟落点再校验一次，期间地形可能变化（如船开走）
        local px, py, pz = pos:Get()
        if CanBlinkToPosition(doer, pos) then
            doer.Physics:Teleport(px, py, pz)
        end
        doer:Show()
        if doer.DynamicShadow ~= nil then
            doer.DynamicShadow:Enable(true)
        end
        if doer.components.health ~= nil then
            doer.components.health:SetInvincible(false)
        end
        if doer.components.playercontroller ~= nil then
            doer.components.playercontroller:Enable(true)
        end
        -- 落点特效与音效
        local nx, ny, nz = doer.Transform:GetWorldPosition()
        SpawnPrefab("sand_puff_large_front").Transform:SetPosition(nx, ny, nz)
        SpawnPrefab("sand_puff_large_back").Transform:SetPosition(nx, ny - .1, nz)
        doer.SoundEmitter:PlaySound("dontstarve/common/staff_blink")
    end)
    return true
end

------------------------------------------------------------------------------------------------------------------------------
-- 唤星/唤月：右键地面召唤星星/极光（参考 yellowstaff/opalstaff）
------------------------------------------------------------------------------------------------------------------------------

local function MakeLightSpell(lightprefab)
    return function(inst, target, pos, doer)
        pos = pos or (target ~= nil and target:GetPosition() or nil)
        if pos == nil then
            return false
        end
        local light = SpawnPrefab(lightprefab)
        if light == nil then
            return false
        end
        light.Transform:SetPosition(pos:Get())
        return true
    end
end

local SpellStarCall = MakeLightSpell("stafflight")
local SpellMoonCall = MakeLightSpell("staffcoldlight")

------------------------------------------------------------------------------------------------------------------------------
-- 月陨/影默：右键地面召唤一次元素袭击（复用原版投石机元素弹 winona_catapult_projectile）
------------------------------------------------------------------------------------------------------------------------------
local STRIKE_AOE_MULT = 2
local function MakeStrikeSpell(element)
    return function(inst, target, pos, doer)
        pos = pos or (target ~= nil and target:GetPosition() or nil)
        if pos == nil or doer == nil then
            return false
        end

        local rock = SpawnPrefab("winona_catapult_projectile")
        if rock == nil then
            return false
        end
        -- 从施法者位置向落点抛射
        rock.Transform:SetPosition(doer.Transform:GetWorldPosition())
        -- mega = true：超强投石机打击，命中表现与原版"位面袭击"一致，并附带完整衍生效果——
        --   月陨（lunar）：大爆炸特效 + 强力开采破坏范围内可工作物（锤/挖/砍/矿） + 抛飞地面物品 + 相机震动；
        --   影默（shadow）：原地吸收特效 + 在落点留下原版暗影藤蔓陷阱圈。
        -- 以上全部由原版 winona_catapult_projectile 的 OnHit 逻辑自动执行。
        rock:SetElementalRock(element, true)
        rock:SetAoeRadius(TUNING.WINONA_CATAPULT_AOE_RADIUS * STRIKE_AOE_MULT, 0)
        rock.caster = doer -- 记录施法者，供弹体内伤害结算做友军判定
        local px, _, pz = pos:Get()
        rock.components.complexprojectile:Launch(Vector3(px, 0, pz), rock)
        return true
    end
end
local SpellMoonFall = MakeStrikeSpell("lunar")
local SpellShadowFall = MakeStrikeSpell("shadow")

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- 工具右键种植（《神曲》）种植规则配置
-------------------------------------------------------------------------------------------------------------------------------------------------------

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
-- 鼠标所在单格地皮的九宫格点位，与九宫格锄地保持一致。
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

-- 使用原版 spellcaster 的远程快速施法流程，施法范围与旅法杖一致。
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
    return pt ~= nil and doer:GetDistanceSqToPoint(pt) <= TUNING.KISAKI_CASTSPELL_RANGE * TUNING.KISAKI_CASTSPELL_RANGE
        and TheWorld.Map:CanPlantAtPoint(pt.x, pt.y, pt.z)
end

return {
    ---------- 法杖右键施法：法术本体（由法杖的 MODES 决定各状态用哪一个） ----------
    SpellIgnite = SpellIgnite,           -- 点燃
    SpellFreeze = SpellFreeze,           -- 冰冻
    SpellTeleport = SpellTeleport,       -- 传送
    SpellDeconstruct = SpellDeconstruct, -- 拆解
    SpellBlink = SpellBlink,             -- 瞬移
    SpellStarCall = SpellStarCall,       -- 唤星
    SpellMoonCall = SpellMoonCall,       -- 唤月
    SpellMoonFall = SpellMoonFall,       -- 月陨
    SpellShadowFall = SpellShadowFall,   -- 影默

    ---------- 工具右键种植（《神曲》） ----------
    -- 能否种植（右键校验）
    CanPlantNineSeeds = CanPlantNineSeeds,
    -- 九宫格种植（右键施法）
    PlantNineSeeds = PlantNineSeeds,
}
