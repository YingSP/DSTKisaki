local assets = {
}

-------------------------------------------------------------------------本地特效---------------------------------------------------------------------------
local function OnRippleAnimOver(inst)
    if inst.pool.invalid then
        inst:Remove()
    else
        inst:Hide()
        table.insert(inst.pool, inst)
    end
end

local function CreateRipple(pool)
    local inst
    if #pool > 0 then
        inst = table.remove(pool)
        inst:Show()
    else
        inst = CreateEntity()

        inst:AddTag("FX")
        inst:AddTag("NOCLICK")
        --[[Non-networked entity]]
        inst.entity:SetCanSleep(false)
        inst.persists = false

        inst.entity:AddTransform()
        inst.entity:AddAnimState()

        inst.AnimState:SetBank("splash_weregoose_fx")
        inst.AnimState:SetBuild("splash_water_drop")
        inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
        inst.AnimState:SetOceanBlendParams(TUNING.OCEAN_SHADER.EFFECT_TINT_AMOUNT)

        inst.pool = pool
        inst:ListenForEvent("animover", OnRippleAnimOver)
    end

    inst.AnimState:PlayAnimation(math.random() < .5 and "no_splash" or "no_splash2")
    local scale = .6 + math.random() * .2
    inst.AnimState:SetScale(math.random() < .5 and -scale or scale, scale)

    return inst
end

local function TryRipple(inst, map)
    if not (inst:HasTag("moving") or
            inst.AnimState:IsCurrentAnimation("appear") or
            inst.AnimState:IsCurrentAnimation("disappear") or
            inst.AnimState:IsCurrentAnimation("lunge_pst")
        ) then
        local x, y, z = inst.Transform:GetWorldPosition()
        if map:IsOceanAtPoint(x, 0, z) then
            CreateRipple(inst.ripple_pool).Transform:SetPosition(x, 0, z)
        end
    end
end

local function OnRemoveEntity(inst)
    for i, v in ipairs(inst.ripple_pool) do
        v:Remove()
    end
    inst.ripple_pool.invalid = true
end


-------------------------------------------------------------------------傀儡逻辑---------------------------------------------------------------------------
-- 免疫碎片伤害
local function nodebrisdmg(inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    return afflicter ~= nil and afflicter:HasTag("quakedebris")
end

-- 傀儡追击逻辑
local COMBAT_MUSHAVE_TAGS = { "_combat", "_health" }
local COMBAT_CANTHAVE_TAGS = { "INLIMBO", "companion" }
local COMBAT_MUSTONEOF_TAGS_AGGRESSIVE = { "monster", "prey", "insect", "hostile", "character", "animal" }
-- 判断友好生物
local function HasFriendlyLeader(inst, target)
    local leader = inst.components.follower.leader
    if leader ~= nil then
        local target_leader = (target.components.follower ~= nil) and target.components.follower.leader or nil

        if target_leader and target_leader.components.inventoryitem then
            target_leader = target_leader.components.inventoryitem:GetGrandOwner()
            -- Don't attack followers if their follow object has no owner
            if target_leader == nil then
                return true
            end
        end

        return leader == target or target:HasTag("player") or                                           -- 不攻击玩家
            (target_leader ~= nil and (target_leader == leader or (target_leader:HasTag("player")))) or -- 不攻击其他玩家的随从
            (target.components.domesticatable and target.components.domesticatable:IsDomesticated()) or -- 不攻击驯化后的生物
            (target.components.saltlicker and target.components.saltlicker.salted)                      -- 主要是针对牛
    end
    return false
end
-- 寻找敌人
local function protectorretargetfn(inst)
    local target = nil

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.SHADOWWAXWELL_PROTECTOR_DEFEND_RADIUS, COMBAT_MUSHAVE_TAGS,
        COMBAT_CANTHAVE_TAGS, COMBAT_MUSTONEOF_TAGS_AGGRESSIVE)
    for _, ent in ipairs(ents) do
        --if protectorretargetfn_test(inst, ent) then
        if ent ~= inst and ent.entity:IsVisible()
            and inst.components.combat:CanTarget(ent)
            and ent.components.minigame_participator == nil
            and not HasFriendlyLeader(inst, ent) then
            target = ent
            break
        end
    end

    return target
end
-- 是否索敌
local function protectorkeeptargetfn(inst, target)
    -- Maintain the target if it is able to.
    return inst.components.combat:CanTarget(target)
        and target.components.minigame_participator == nil
        and not target:HasTag("player")
end

-- 睡觉
local function OnEntitySleep(inst)
    if inst._obliviatetask == nil then
        inst._obliviatetask = inst:DoTaskInTime(TUNING.SHADOWWAXWELL_MINION_IDLE_DESPAWN_TIME, inst.Remove)
    end
end
-- 醒来
local function OnEntityWake(inst)
    if inst._obliviatetask ~= nil then
        inst._obliviatetask:Cancel()
        inst._obliviatetask = nil
    end
end

-- 傀儡消失
local function OnSeekOblivion(inst)
    if inst:IsAsleep() then
        inst:Remove()
        return
    end
    inst.components.timer:StopTimer("obliviate")
    if inst.components.health == nil then
        inst.sg:GoToState("quickdespawn")
    elseif inst.components.health:IsInvincible() then
        inst.components.timer:StartTimer("obliviate", .5)
    else
        inst:StopBrain()
        inst:SetBrain(nil)
        inst.components.health:Kill()
    end
end
local function OnTimerDone(inst, data)
    if data and data.name == "obliviate" then
        OnSeekOblivion(inst)
    end
end

-- 跳舞
local function OnDancingPlayerData(inst, data)
    if data == nil then
        return
    end

    local player = data.inst
    if player == nil or player ~= inst.components.follower:GetLeader() then
        return
    end

    inst._brain_dancedata = data.dancedata
end

-- 被打的时候执行
local function OnAttacked(inst, data)
    if data.attacker ~= nil then
        if data.attacker.components.petleash ~= nil and -- 被主人击杀时掉落噩梦燃料(老版老麦)
            data.attacker.components.petleash:IsPet(inst) then
            if inst.despawnpetloot then
                if inst.components.lootdropper == nil then
                    inst:AddComponent("lootdropper")
                end
                inst.components.lootdropper:SpawnLootPrefab("nightmarefuel", inst:GetPosition())
            end
            data.attacker.components.petleash:DespawnPet(inst)
        elseif data.attacker.components.combat ~= nil then -- 被其他东西打了就索敌他
            inst.components.combat:SuggestTarget(data.attacker)
        end
    end
end

-- 将仇恨转移到人物身上
local function DropAggro(inst)
    local leader = inst.components.follower:GetLeader()
    if leader ~= nil and
        ((leader.components.health ~= nil and leader.components.health:IsDead()) or
            (leader.sg ~= nil and leader.sg:HasStateTag("hiding")) or
            not inst:IsNear(leader, TUNING.SHADOWWAXWELL_PROTECTOR_TRANSFER_AGGRO_RANGE) or
            not leader.entity:IsVisible() or
            leader:HasTag("playerghost")
        ) then
        --dead, hiding, or too far
        leader = nil
    end
    --nil leader will just drop target
    inst:PushEvent("transfercombattarget", leader)
end


-------------------------------------------------------------------------主要实现---------------------------------------------------------------------------
local function MakeMinion(prefab, master_postinit)
    local function shadow_protector_fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()    -- 管理实体的位置、旋转和缩放
        inst.entity:AddAnimState()    -- 控制实体的动画
        inst.entity:AddSoundEmitter() -- 管理实体的声音
        inst.entity:AddNetwork()      -- 网络同步功能

        inst:SetPhysicsRadiusOverride(.5)
        MakeGhostPhysics(inst, 1, inst.physicsradiusoverride)                                                    -- 设置为碰撞体积0.5的幽灵体

        inst.Transform:SetFourFaced(inst)                                                                        -- 锁定动画只有四面
        inst.AnimState:SetBank("wilson")                                                                         -- 使用威尔逊的骨架
        inst.AnimState:OverrideSymbol("fx_wipe", "wilson_fx", "fx_wipe")                                         -- 替换fx_wipe动画
        inst.AnimState:PlayAnimation("minion_spawn")                                                             -- 播放生成动画
        inst.AnimState:SetMultColour(0, 0, 0, .5)                                                                -- 设置半透明
        inst.AnimState:UsePointFiltering(true)                                                                   -- 风格锐化

        inst.AnimState:AddOverrideBuild("lavaarena_shadow_lunge")                                                -- 添加冲刺攻击动画
        inst.AnimState:AddOverrideBuild("waxwell_minion_spawn")                                                  -- 添加生成动画
        inst.AnimState:AddOverrideBuild("waxwell_minion_appear")                                                 -- 添加生成动画

        inst.AnimState:OverrideSymbol("swap_object", "swap_nightmaresword_shadow", "swap_nightmaresword_shadow") -- 替换武器贴图
        inst.AnimState:Hide("ARM_normal")                                                                        -- 影藏部分动画
        inst.AnimState:Hide("HAT")
        inst.AnimState:Hide("HAIR_HAT")

        -- inst:AddTag("shadowminion")            -- 影子随从
        inst:AddTag("NOBLOCK")                 -- 不阻挡船
        inst:AddTag("kisaki_shadow_protector") -- 特定标签

        -- 客户端特效，从原版shadowwaxwell抄的
        if not TheNet:IsDedicated() then
            inst.ripple_pool = {}
            inst:DoPeriodicTask(.6, TryRipple, math.random() * .6, TheWorld.Map)
            inst.OnRemoveEntity = OnRemoveEntity
        end

        -- 客户端同步边界
        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            return inst
        end

        -- 支持配置皮肤
        inst:AddComponent("skinner")
        inst.components.skinner:SetupNonPlayerData()

        -- 暗影傀儡移动
        inst:AddComponent("locomotor")
        inst.components.locomotor.runspeed = TUNING.SHADOWWAXWELL_SPEED * 6 -- 给个八级加速
        inst.components.locomotor:SetTriggersCreep(false)                   -- 免疫粘液
        inst.components.locomotor.pathcaps = { ignorecreep = true }         -- 忽视地形加减速
        inst.components.locomotor:SetSlowMultiplier(.6)                     -- 如果被减速

        -- 暗影傀儡生命
        inst:AddComponent("health")
        inst.components.health:SetMaxHealth(50)
        inst.components.health.nofadeout = true             -- 死亡无淡出动画
        inst.components.health.redirect = nodebrisdmg       -- 免疫碎片伤害
        inst.components.health:SetAbsorptionAmount(0.9)     -- 固定拥有90%的防御
        inst.components.health:SetMaxDamageTakenPerHit(0.5) -- 限伤
        inst.components.health.fire_damage_scale = 0        -- 免火

        -- 暗影傀儡攻击
        inst:AddComponent("combat")
        inst.components.combat.hiteffectsymbol = "torso"                    -- 设置受击部位为躯干
        inst.components.combat:SetRange(2)                                  -- 攻击距离为2
        inst.components.combat:SetDefaultDamage(50)                         -- 默认攻击力
        inst.components.combat:SetAttackPeriod(TUNING.WILSON_ATTACK_PERIOD) -- 两次攻击的最小间隔
        inst.components.combat:SetRetargetFunction(1, protectorretargetfn)  -- 动态索敌
        inst.components.combat:SetKeepTargetFunction(protectorkeeptargetfn) -- 判断是否继续索敌
        inst:AddComponent("planardamage")
        inst.components.planardamage:SetBaseDamage(0)                       -- 位面伤害

        -- 暗影傀儡随从组件
        inst:AddComponent("follower")
        inst.components.follower:KeepLeaderOnAttacked()          -- 永远跟随主人
        inst.components.follower.keepdeadleader = true           -- 永远跟随主人
        inst.components.follower.keepleaderduringminigame = true -- 永远跟随主人

        -- 设置下AI和SG
        local brain = require("brains/kisaki_shadow_protectorbrain")
        inst:SetBrain(brain)
        inst:SetStateGraph("SGkisaki_shadow_protector")

        inst:AddComponent("timer")
        inst.components.timer:StartTimer("obliviate", 120) -- 傀儡持续2分钟
        inst:ListenForEvent("timerdone", OnTimerDone)
        inst:ListenForEvent("attacked", OnAttacked)
        inst:ListenForEvent("dancingplayerdata", function(world, data) OnDancingPlayerData(inst, data) end, TheWorld)
        -- 死亡掉落物品/固定范围限制就不写了

        -- 设置下影人的皮肤
        inst:DoTaskInTime(0, function()
            local player = inst.components.follower:GetLeader()
            inst.AnimState:SetBuild(player and player.AnimState:GetBuild() or "kisaki")
        end)

        -- 随从击杀算做人物击杀
        inst:ListenForEvent("killed", function(inst, data)
            local leader = inst.components.follower:GetLeader()
            if leader and data.victim then
                leader:PushEvent("killed", { victim = data.victim })
            end
        end)
        -- 死亡时把仇恨转移到人物身上
        inst:ListenForEvent("death", DropAggro)

        inst.isgeminishadow = false
        if master_postinit ~= nil then
            master_postinit(inst)
        end

        inst.OnEntitySleep = OnEntitySleep
        inst.OnEntityWake = OnEntityWake
        inst.DropAggro = DropAggro

        return inst
    end
    return Prefab(prefab, shadow_protector_fn)
end

local function settarget(inst, attacker, target, offset)
    if target == nil or attacker == nil then
        inst:Remove()
        return
    end
    inst.AnimState:SetBuild(attacker.AnimState:GetBuild() or "kisaki")
    inst.Transform:SetPosition((target:GetPosition() + (offset or { x = 0, y = 0, z = 0 })):Get())
    inst:FacePoint(target:GetPosition())

    -- 快速生成并播放冲刺动画（从SG抄就行）
    SpawnPrefab("statue_transition_2").Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst.AnimState:SetBankAndPlayAnimation("lavaarena_shadow_lunge", "lunge_pre")
    inst.AnimState:PushAnimation("lunge_loop")
    inst.AnimState:PushAnimation("lunge_pst")
    -- 12帧后开始冲刺
    inst:DoTaskInTime(12 * FRAMES, function(inst)
        inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_nightsword")
        inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_shadow_med_sharp")
        inst.Physics:SetMotorVelOverride(35, 0, 0)
    end)
    -- 17帧时造成伤害
    inst:DoTaskInTime(17 * FRAMES, function(inst)
        if target and target:IsValid() and attacker and attacker:IsValid()
            and target.components.health and not target.components.health:IsDead() and target.components.combat then
            local damage = attacker.components.combat and attacker.components.combat.defaultdamage or 0
            local planardamage = attacker.components.planardamage and attacker.components.planardamage.basedamage or 0
            target.components.combat:GetAttacked(attacker, damage, nil, nil, { planar = planardamage })
        end
    end)
    -- 22帧后停止移动
    inst:DoTaskInTime(22 * FRAMES, function(inst)
        inst.Physics:ClearMotorVelOverride()
    end)
    -- 35帧时消失
    inst:DoTaskInTime(35 * FRAMES, function(inst)
        inst:Remove()
    end)
end

local function shadowlungefn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:SetPhysicsRadiusOverride(.5)
    MakeGhostPhysics(inst, 1, inst.physicsradiusoverride)

    inst.Transform:SetFourFaced(inst)
    inst.AnimState:SetBank("wilson")
    inst.AnimState:SetBuild("kisaki")
    inst.AnimState:OverrideMultColour(0, 0, 0, 0.5)
    inst.AnimState:AddOverrideBuild("lavaarena_shadow_lunge")

    inst.AnimState:OverrideSymbol("swap_object", "swap_nightmaresword_shadow", "swap_nightmaresword_shadow")
    inst.AnimState:Hide("ARM_normal")
    inst.AnimState:Hide("HAT")
    inst.AnimState:Hide("HAIR_HAT")

    inst:AddTag("NOCLICK")
    inst:AddTag("FX")

    -- 客户端同步边界
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end
    -- 好像是特效都会加的东西，代表该特效不是持续的
    inst.persists = false

    inst.settarget = settarget

    return inst
end

local function onhitother(inst, data)
    -- 触发连斩有25SCD
    if data and data.target and GetTime() - inst.kisaki_shadow_five_confluence > 25 then
        inst.kisaki_shadow_five_confluence = GetTime()
        -- 5连斩,每12帧一斩
        for i = 1, 5, 1 do
            inst:DoTaskInTime(12 * FRAMES * i, function(inst)
                SpawnPrefab("kisaki_shadow_protector_confluence_fx"):settarget(inst, data.target,
                    inst.kisaki_shadow_protector_offset[i])
            end)
        end
    end
end

local function geminiprotectorfn(inst)
    inst.isgeminishadow = true
    -- 给个CD
    inst.kisaki_shadow_five_confluence = GetTime()
    -- 从五边形攻击
    if inst.kisaki_shadow_protector_offset == nil then
        inst.kisaki_shadow_protector_offset = {}
        for i = 1, 5, 1 do
            local angle = 2 * math.pi / 5 * i * 2
            inst.kisaki_shadow_protector_offset[i] = Vector3(5 * math.sin(angle), 0, 5 * math.cos(angle))
        end
    end

    inst:ListenForEvent("onhitother", onhitother)
end

return MakeMinion("kisaki_shadow_protector"),
    MakeMinion("kisaki_shadow_protector_gemini", geminiprotectorfn),
    Prefab("kisaki_shadow_protector_confluence_fx", shadowlungefn)
