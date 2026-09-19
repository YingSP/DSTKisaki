-- 旅的武器抛射物：由 weapon 组件发射、直线追踪、命中后在附近目标间弹射的弹体。
-- 这里是武器攻击发射的弹体（projectile 组件），两者的组件与用法都不同。
-- 目前只有一种：
--   kisaki_brilliance_projectile —— 原版辉光弹 brilliance_projectile_fx 的变种，
--   使用自己的动画资源（anim/kisaki_brilliance_projectile.zip），逻辑与原版一致，
--   只有弹射次数改由投掷者手持的旅解锁状态决定（未解锁"月陨"不弹射）。

-- 弹射目标筛选：与原版辉光弹一致，排除墙体、玩家、友方等
local BOUNCE_MUST_TAGS = { "_combat" }
local BOUNCE_NO_TAGS = { "INLIMBO", "wall", "notarget", "player", "companion", "flight", "invisible", "noattack", "hiding" }

-- 丢失目标时播放消散动画后移除
local function PlayAnimAndRemove(inst, anim)
    inst.AnimState:PlayAnimation(anim)
    if not inst.removing then
        inst.removing = true
        inst:ListenForEvent("animover", inst.Remove)
    end
end

local function MakeProjectile(name, def)
    local build = def.build or name          -- 动画 build（同时作为 bank，动画包与 zip 同名）
    local speed = def.speed or 15            -- 飞行速度
    local bounce_range = def.bounce_range or 12
    local bounce_speed = def.bounce_speed or 10
    local hitfx = def.hitfx or "brilliance_projectile_blast_fx"

    -- 在落点附近寻找下一个弹射目标（优先敌对、优先最近没打过的目标），逻辑与原版一致
    local function TryBounce(inst, x, z, attacker, target)
        if attacker == nil or not attacker:IsValid() or attacker.components.combat == nil then
            inst:Remove()
            return
        end

        local newtarget, newrecentindex, newhostile
        for _, v in ipairs(TheSim:FindEntities(x, 0, z, bounce_range, BOUNCE_MUST_TAGS, BOUNCE_NO_TAGS)) do
            if v ~= target and v.entity:IsVisible()
                and not (v.components.health ~= nil and v.components.health:IsDead())
                and attacker.components.combat:CanTarget(v)
                and not attacker.components.combat:IsAlly(v) then
                local vhostile = v:HasTag("hostile")
                local vrecentindex
                if inst.recenttargets ~= nil then
                    for i, recent in ipairs(inst.recenttargets) do
                        if v == recent then
                            vrecentindex = i
                            break
                        end
                    end
                end
                if inst.initial_hostile and not vhostile and vrecentindex == nil and v.components.locomotor == nil then
                    -- 首次攻击的是敌对目标时，跳过没打过的、不会移动的非敌对目标
                elseif newtarget == nil then
                    newtarget, newrecentindex, newhostile = v, vrecentindex, vhostile
                elseif vhostile and not newhostile then
                    newtarget, newrecentindex, newhostile = v, vrecentindex, vhostile
                elseif vhostile or not newhostile then
                    if vrecentindex == nil then
                        if newrecentindex ~= nil or (newtarget.prefab ~= target.prefab and v.prefab == target.prefab) then
                            newtarget, newrecentindex, newhostile = v, vrecentindex, vhostile
                        end
                    elseif newrecentindex ~= nil and vrecentindex < newrecentindex then
                        newtarget, newrecentindex, newhostile = v, vrecentindex, vhostile
                    end
                end
            end
        end

        if newtarget ~= nil then
            -- 找到目标：传送到落点后重新投掷
            inst.Physics:Teleport(x, 0, z)
            inst:Show()
            inst.components.projectile:SetSpeed(bounce_speed)
            if inst.recenttargets ~= nil then
                if newrecentindex ~= nil then
                    table.remove(inst.recenttargets, newrecentindex)
                end
                table.insert(inst.recenttargets, target)
            else
                inst.recenttargets = { target }
            end
            inst.components.projectile:SetBounced(true)
            inst.components.projectile.overridestartpos = Vector3(x, 0, z)
            inst.components.projectile:Throw(inst.owner, newtarget, attacker)
        else
            -- 范围内没有有效目标，直接消失
            inst:Remove()
        end
    end

    local function OnHit(inst, attacker, target)
        local blast = SpawnPrefab(hitfx)
        local x, y, z
        if target ~= nil and target:IsValid() then
            local radius = target:GetPhysicsRadius(0) + .2
            local angle = (inst.Transform:GetRotation() + 180) * DEGREES
            x, y, z = target.Transform:GetWorldPosition()
            x = x + math.cos(angle) * radius + GetRandomMinMax(-.2, .2)
            y = GetRandomMinMax(.1, .3)
            z = z - math.sin(angle) * radius + GetRandomMinMax(-.2, .2)
            if blast.PushFlash ~= nil then
                blast:PushFlash(target)
            end
        else
            x, y, z = inst.Transform:GetWorldPosition()
        end
        blast.Transform:SetPosition(x, y, z)

        -- bounces 语义是"剩余的总伤害次数"，大于 1 才继续弹射
        if inst.bounces ~= nil and inst.bounces > 1
            and attacker ~= nil and attacker:IsValid() and attacker.components.combat ~= nil then
            inst.bounces = inst.bounces - 1
            inst.Physics:Stop()
            inst:Hide()
            inst:DoTaskInTime(.1, TryBounce, x, z, attacker, target)
        else
            inst:Remove()
        end
    end

    local function OnMiss(inst, attacker, target)
        if not inst.AnimState:IsCurrentAnimation("disappear") then
            PlayAnimAndRemove(inst, "disappear")
        end
    end

    -- 投掷时决定本次的弹射次数。只认首次投掷：Projectile:Throw 在每次弹射（TryBounce 重新 Throw）
    -- 都会再次触发 onthrown，若每次都改写 bounces，计数会被重置回满值而变成无限弹射。
    local function OnThrown(inst, owner, target, attacker)
        inst.owner = owner
        if inst.bounces == nil then
            inst.bounces = def.bounces_fn ~= nil and def.bounces_fn(inst, target, attacker) or 1
            inst.initial_hostile = target ~= nil and target:IsValid() and target:HasTag("hostile")
        end
    end

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()      -- 管理实体的位置、旋转和缩放
        inst.entity:AddAnimState()      -- 控制实体的动画
        inst.entity:AddPhysics()        -- 投射物飞行需要物理
        inst.entity:AddNetwork()        -- 网络同步功能

        MakeInventoryPhysics(inst)      -- 基础物理参数（与原版投射物一致）
        RemovePhysicsColliders(inst)    -- 飞行途中不与其他实体发生物理碰撞

        inst:AddTag("FX")
        inst:AddTag("NOCLICK")

        inst.AnimState:SetBank(build)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation("idle_loop", true)
        inst.AnimState:SetSymbolMultColour("light_bar", 1, 1, 1, .5)
        inst.AnimState:SetSymbolBloom("light_bar")
        inst.AnimState:SetSymbolBloom("glow")
        inst.AnimState:SetLightOverride(.5)

        -- projectile（由 projectile 组件添加）放进 pristine，供客户端识别
        inst:AddTag("projectile")

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("projectile")
        inst.components.projectile:SetSpeed(speed)
        inst.components.projectile:SetRange(25)
        inst.components.projectile:SetOnThrownFn(OnThrown)
        inst.components.projectile:SetOnHitFn(OnHit)
        inst.components.projectile:SetOnMissFn(OnMiss)

        inst.persists = false
        return inst
    end

    return Prefab(name, fn, { Asset("ANIM", "anim/" .. build .. ".zip") }, def.prefabs or { hitfx })
end

local projectile_defs = {}

-- 旅普通攻击的辉光弹（原版 brilliance_projectile_fx 的变种）
projectile_defs.kisaki_brilliance_projectile = {
    -- 动画包（zip 名、bank、build 三者同名）。新动画还没编译好之前，
    -- 可临时改成 "brilliance_projectile_fx" 先复用原版动画，行为完全一致。
    build = "kisaki_brilliance_projectile",
    -- 弹射次数由投掷者手持的旅解锁状态决定
    bounces_fn = function(inst, target, attacker)
        local staff = attacker ~= nil and attacker:IsValid() and attacker.components.inventory ~= nil
            and attacker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
        return staff ~= nil and staff:HasTag("kisaki_staff_unlock_moonfall") and 6 or 1
    end,
}

local projectiles = {}
for prefab_name, def in pairs(projectile_defs) do
    table.insert(projectiles, MakeProjectile(prefab_name, def))
end
return unpack(projectiles)
