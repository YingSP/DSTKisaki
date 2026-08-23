require("stategraphs/commonstates")

-------------------------------------------------------------------------特效生成---------------------------------------------------------------------------

local function DetachFX(fx)
    fx.Transform:SetPosition(fx.Transform:GetWorldPosition())
    fx.entity:SetParent(nil)
end

local function DoDespawnFX(inst)
    --shadow_despawn is in the air => detaches from sinking boats
    --shadow_glob_fx is on ground => dies with sinking boats
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx1 = SpawnPrefab("shadow_despawn")
    local fx2 = SpawnPrefab("shadow_glob_fx")
    fx2.AnimState:SetScale(math.random() < .5 and -1.3 or 1.3, 1.3, 1.3)
    local platform = inst:GetCurrentPlatform()
    if platform ~= nil then
        fx1.entity:SetParent(platform.entity)
        fx2.entity:SetParent(platform.entity)
        fx1:ListenForEvent("onremove", function() DetachFX(fx1) end, platform)
        x, y, z = platform.entity:WorldToLocalSpace(x, y, z)
    end
    fx1.Transform:SetPosition(x, y, z)
    fx2.Transform:SetPosition(x, y, z)
end

local function TrySplashFX(inst, size)
    local x, y, z = inst.Transform:GetWorldPosition()
    if TheWorld.Map:IsOceanAtPoint(x, 0, z) then
        SpawnPrefab("ocean_splash_" .. (size or "med") .. tostring(math.random(2))).Transform:SetPosition(x, 0, z)
        return true
    end
end

local function TryStepSplash(inst)
    local t = GetTime()
    if (inst.sg.mem.laststepsplash == nil or inst.sg.mem.laststepsplash + .1 < t) and TrySplashFX(inst) then
        inst.sg.mem.laststepsplash = t
    end
end

local function DoSound(inst, sound)
    inst.SoundEmitter:PlaySound(sound)
end

-------------------------------------------------------------------------AI方法抽取---------------------------------------------------------------------------

local function NotBlocked(pt)
    return not TheWorld.Map:IsGroundTargetBlocked(pt)
end

local function IsNearTarget(inst, target, range)
    return inst:IsNear(target, range + target:GetPhysicsRadius(0))
end

local function IsLeaderNear(inst, leader, target, range)
    --leader is in range of us or our target
    return inst:IsNear(leader, range) or (target ~= nil and IsNearTarget(leader, target, range))
end

local function CheckLeaderShadowLevel(inst, target)
    local level = 0
    local leader = inst.components.follower:GetLeader()
    if leader ~= nil and
        leader.components.inventory ~= nil and
        IsLeaderNear(inst, leader, target, TUNING.SHADOWWAXWELL_PROTECTOR_SHADOW_LEADER_RADIUS)
    then
        for k, v in pairs(EQUIPSLOTS) do
            local equip = leader.components.inventory:GetEquippedItem(v)
            if equip ~= nil and equip.components.shadowlevel ~= nil then
                level = level + equip.components.shadowlevel:GetCurrentLevel()
            end
        end
    end

    --Scale damage
    inst.components.combat:SetDefaultDamage(TUNING.SHADOWWAXWELL_PROTECTOR_DAMAGE +
        level * TUNING.SHADOWWAXWELL_PROTECTOR_DAMAGE_BONUS_PER_LEVEL)
end

-------------------------------------------------------------------------动作处理---------------------------------------------------------------------------

local actionhandlers = {}

-------------------------------------------------------------------------事件处理---------------------------------------------------------------------------

local events =
{
    -- 通用走路处理
    CommonHandlers.OnLocomote(true, false),
    -- 通用死亡处理
    CommonHandlers.OnDeath(),
    -- 被打时候处理
    EventHandler("attacked", function(inst, data)
        if not (inst.components.health:IsDead() or inst.components.health:IsInvincible()) then
            inst.sg:GoToState("disappear", data ~= nil and data.attacker or nil)
        end
    end),
    -- 攻击的时候处理
    EventHandler("doattack", function(inst, data)
        if inst.components.health ~= nil and not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") then
            if inst.components.combat.attackrange == 10 then
                inst.sg:GoToState("lunge_pre", data ~= nil and data.target or nil)
            else
                inst.sg:GoToState("attack", data ~= nil and data.target or nil)
            end
        end
    end),
    -- 跳舞，由AI中PushEvent("dance")触发
    EventHandler("dance", function(inst)
        if not inst.sg:HasStateTag("busy") and (inst._brain_dancedata ~= nil or not inst.sg:HasStateTag("dancing")) then
            inst.sg:GoToState("dance")
        end
    end),
}

-------------------------------------------------------------------------人物状态---------------------------------------------------------------------------

local states =
{
    -- 生成状态
    State {
        name = "spawn",
        tags = { "busy", "noattack", "temp_invincible" },

        onenter = function(inst, mult)
            inst.Physics:Stop()
            ToggleOffCharacterCollisions(inst)
            inst.AnimState:PlayAnimation("minion_spawn")
            mult = mult or (0.8 + math.random() * 0.2)
            inst.AnimState:SetDeltaTimeMultiplier(mult)

            mult = 1 / mult
            inst.sg.statemem.tasks =

            {
                inst:DoTaskInTime(0 * FRAMES * mult, DoSound, "maxwell_rework/shadow_worker/spawn"),
                inst:DoTaskInTime(0 * FRAMES * mult, TrySplashFX),
                inst:DoTaskInTime(20 * FRAMES * mult, TrySplashFX),
                inst:DoTaskInTime(44 * FRAMES * mult, TrySplashFX, "small"),
            }
            inst.sg:SetTimeout(70 * FRAMES * mult)
        end,

        ontimeout = function(inst)
            inst.sg:AddStateTag("caninterrupt")
            ToggleOnCharacterCollisions(inst)
            inst.AnimState:SetDeltaTimeMultiplier(1)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.spawn then
                ToggleOnCharacterCollisions(inst)
                inst.AnimState:SetDeltaTimeMultiplier(1)
            end
            for i, v in ipairs(inst.sg.statemem.tasks) do
                v:Cancel()
            end
        end,
    },

    -- 快速生成状态
    State {
        name = "quickspawn",

        onenter = function(inst)
            SpawnPrefab("statue_transition_2").Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst.sg:GoToState("idle")
        end,
    },

    -- 消失状态
    State {
        name = "quickdespawn",

        onenter = function(inst)
            DoDespawnFX(inst)
            if inst.sg.mem.laststepsplash ~= GetTime() then
                TrySplashFX(inst)
            end
            inst:DropAggro() -- 仇恨转移到主人身上
            inst:Remove()
        end,
    },

    -- 闲置状态
    State {
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst, pushanim)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle_loop", true)
            if inst.components.timer ~= nil and not inst.components.timer:TimerExists("shadowstrike_cd") then
                inst.components.combat:SetRange(10)
            end
        end,
    },

    -- 准备姿势前置状态
    State {
        name = "ready_pre",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("ready_stance_pre")
            if inst.components.timer ~= nil and not inst.components.timer:TimerExists("shadowstrike_cd") then
                inst.components.combat:SetRange(10)
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("ready")
                end
            end),
        },
    },

    -- 准备姿势状态
    State {
        name = "ready",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("ready_stance_loop", true)
        end,

        onupdate = function(inst)
            if not inst.components.combat:HasTarget() then
                inst.sg:GoToState("ready_pst")
            end
        end,
    },

    -- 准备姿势结束状态
    State {
        name = "ready_pst",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("ready_stance_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    -- 奔跑前置状态
    State {
        name = "run_start",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("run_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("run")
                end
            end),
        },

        timeline =
        {
            TimeEvent(1 * FRAMES, TryStepSplash),
            TimeEvent(3 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/maxwell/shadowmax_step")
            end),
        },
    },

    -- 奔跑状态
    State {
        name = "run",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            if not inst.AnimState:IsCurrentAnimation("run_loop") then
                inst.AnimState:PlayAnimation("run_loop", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline =
        {
            TimeEvent(5 * FRAMES, TryStepSplash),
            TimeEvent(7 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/maxwell/shadowmax_step")
                inst.sg.mem.laststepsplash = GetTime()
            end),
            TimeEvent(13 * FRAMES, TryStepSplash),
            TimeEvent(15 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/maxwell/shadowmax_step")
                inst.sg.mem.laststepsplash = GetTime()
            end),
        },

        ontimeout = function(inst)
            inst.sg.statemem.running = true
            inst.sg:GoToState("run")
        end,

        onexit = function(inst)
            if not inst.sg.statemem.running then
                TryStepSplash(inst)
            end
        end,
    },

    -- 奔跑结束状态
    State {
        name = "run_stop",
        tags = { "canrotate", "idle" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("run_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    -- 平A攻击状态
    State {
        name = "attack",
        tags = { "attack", "abouttoattack", "busy" },

        onenter = function(inst, target)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("atk_pre")
            inst.AnimState:PushAnimation("atk", false)

            inst.components.combat:StartAttack()
            if target == nil then
                target = inst.components.combat.target
            end
            if target ~= nil and target:IsValid() then
                inst.sg.statemem.target = target
                inst:ForceFacePoint(target.Transform:GetWorldPosition())
            else
                target = nil
            end
            -- CheckCombatLeader(inst, target) -- 不修改攻速
        end,

        timeline =
        {
            TimeEvent(6 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_nightsword")
            end),
            TimeEvent(8 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("abouttoattack")
                local target = inst.sg.statemem.target
                -- 只有暗影秘典招出来的暗影小人才修改攻击力
                if not inst.isgeminishadow then
                    CheckLeaderShadowLevel(inst, target ~= nil and target:IsValid() and target or nil)
                end
                inst.components.combat:DoAttack(target) --purposely not checking valid for this call
            end),
            TimeEvent(12 * FRAMES, function(inst)       -- Keep FRAMES time synced up with ShouldKiteProtector.
                inst.sg:RemoveStateTag("busy")
            end),
            TimeEvent(13 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("attack")
            end),
            TimeEvent(16 * FRAMES, function(inst)
                if inst.isprotector and inst.components.combat:HasTarget() then
                    inst.sg:GoToState("ready_pre")
                end
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
            end
        end,
    },

    -- 死亡状态
    State {
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            --FixupWorkerCarry(inst, nil)
            inst.AnimState:PlayAnimation("death")
        end,

        timeline =
        {
            TimeEvent(13 * FRAMES, TrySplashFX),
            TimeEvent(38 * FRAMES, TrySplashFX),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    DoDespawnFX(inst)
                    TrySplashFX(inst)
                    inst:Remove()
                end
            end),
        },
    },

    -- 被打了状态
    State {
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            inst:ClearBufferedAction()
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        timeline =
        {
            TimeEvent(3 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },
    },

    -- 被恐惧状态
    State {
        name = "stunned",
        tags = { "busy", "canrotate" },

        onenter = function(inst)
            inst:ClearBufferedAction()
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle_sanity_pre")
            inst.AnimState:PushAnimation("idle_sanity_loop", true)
            inst.sg:SetTimeout(5)
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("idle")
        end,
    },

    -- 跳舞状态
    State {
        name = "dance",
        tags = { "idle", "dancing" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            local ignoreplay = inst.AnimState:IsCurrentAnimation("run_pst")
            if inst._brain_dancedata and #inst._brain_dancedata > 0 then
                for _, data in ipairs(inst._brain_dancedata) do
                    if data.play and not ignoreplay then
                        inst.AnimState:PlayAnimation(data.anim, data.loop)
                    else
                        inst.AnimState:PushAnimation(data.anim, data.loop)
                    end
                end
            else
                -- NOTES(JBK): No dance data do default dance.
                if ignoreplay then
                    inst.AnimState:PushAnimation("emoteXL_pre_dance0")
                else
                    inst.AnimState:PlayAnimation("emoteXL_pre_dance0")
                end
                inst.AnimState:PushAnimation("emoteXL_loop_dance0", true)
            end
            inst._brain_dancedata = nil -- Remove reference no matter what so garbage collector can pick up the memory.
        end,
    },

    -- 跳出状态，不懂，留着
    State {
        name = "jumpout",
        tags = { "busy", "canrotate", "jumping" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("jumpout")
            inst.Physics:SetMotorVel(4, 0, 0)
            inst.Physics:SetCollisionMask(COLLISION.GROUND)
        end,

        timeline =
        {
            TimeEvent(10 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(3, 0, 0)
            end),
            TimeEvent(15 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(2, 0, 0)
            end),
            TimeEvent(15.2 * FRAMES, function(inst)
                inst.sg.statemem.physicson = true
                inst.Physics:SetCollisionMask(
                    COLLISION.WORLD,
                    COLLISION.CHARACTERS,
                    COLLISION.GIANTS
                )
            end),
            TimeEvent(17 * FRAMES, function(inst)
                inst.Physics:SetMotorVel(1, 0, 0)
            end),
            TimeEvent(18 * FRAMES, function(inst)
                inst.Physics:Stop()
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.physicson then
                inst.Physics:SetCollisionMask(
                    COLLISION.WORLD,
                    COLLISION.CHARACTERS,
                    COLLISION.GIANTS
                )
            end
        end,
    },

    -- 消失状态
    State {
        name = "disappear",
        tags = { "busy", "noattack", "temp_invincible", "phasing" },

        onenter = function(inst, attacker)
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()
            ToggleOffCharacterCollisions(inst)
            inst.AnimState:PlayAnimation("disappear")
            if attacker ~= nil and attacker:IsValid() then
                inst.sg.statemem.attackerpos = attacker:GetPosition()
            end
            TrySplashFX(inst, "small")
            inst:DropAggro() -- 仇恨转移到主人身上
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    local theta =
                        inst.sg.statemem.attackerpos ~= nil and
                        inst:GetAngleToPoint(inst.sg.statemem.attackerpos) or
                        inst.Transform:GetRotation()

                    theta = (theta + 165 + math.random() * 30) * DEGREES

                    local pos = inst:GetPosition()
                    pos.y = 0

                    local offs =
                        FindWalkableOffset(pos, theta, 4 + math.random(), 8, false, true, NotBlocked, true, true) or
                        FindWalkableOffset(pos, theta, 2 + math.random(), 6, false, true, NotBlocked, true, true)

                    if offs ~= nil then
                        pos.x = pos.x + offs.x
                        pos.z = pos.z + offs.z
                    end
                    inst.Physics:Teleport(pos:Get())
                    if inst.sg.statemem.attackerpos ~= nil then
                        inst:ForceFacePoint(inst.sg.statemem.attackerpos)
                    end

                    inst.sg.statemem.appearing = true
                    inst.sg:GoToState("appear")
                end
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.appearing then
                ToggleOnCharacterCollisions(inst)
            end
        end,
    },

    -- 消失后重新出现状态
    State {
        name = "appear",
        tags = { "busy", "noattack", "temp_invincible", "phasing" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            ToggleOffCharacterCollisions(inst)
            inst.AnimState:PlayAnimation("appear")
        end,

        timeline =
        {
            TimeEvent(9 * FRAMES, function(inst)
                TrySplashFX(inst, "small")
            end),
            TimeEvent(11 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("temp_invincible")
                inst.sg:RemoveStateTag("phasing")
                ToggleOnCharacterCollisions(inst)
            end),
            TimeEvent(13 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = ToggleOnCharacterCollisions,
    },

    -- 冲刺前置状态
    State {
        name = "lunge_pre",
        tags = { "attack", "busy" },

        onenter = function(inst, target)
            inst:StopBrain()
            inst.components.locomotor:Stop()
            inst.AnimState:SetBankAndPlayAnimation("lavaarena_shadow_lunge", "lunge_pre")

            inst.components.combat:StartAttack()
            if target == nil then
                target = inst.components.combat.target
            end
            if target ~= nil and target:IsValid() then
                inst.sg.statemem.target = target
                inst.sg.statemem.targetpos = target:GetPosition()
                inst:ForceFacePoint(inst.sg.statemem.targetpos:Get())
            else
                target = nil
            end
            -- CheckCombatLeader(inst, target) -- 不修改攻速
        end,

        onupdate = function(inst)
            if inst.sg.statemem.target ~= nil then
                if inst.sg.statemem.target:IsValid() then
                    inst.sg.statemem.targetpos = inst.sg.statemem.target:GetPosition()
                else
                    inst.sg.statemem.target = nil
                end
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg.statemem.lunge = true
                    inst.sg:GoToState("lunge_loop",
                        { target = inst.sg.statemem.target, targetpos = inst.sg.statemem.targetpos })
                end
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.lunge then
                inst.components.combat:CancelAttack()
                inst:RestartBrain()
                inst.AnimState:SetBank("wilson")
            end
        end,
    },

    -- 冲刺状态
    State {
        name = "lunge_loop",
        tags = { "attack", "busy", "noattack", "temp_invincible" },

        onenter = function(inst, data)
            inst.AnimState:PlayAnimation("lunge_loop") --NOTE: this anim NOT a loop yo
            inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_nightsword")
            inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_shadow_med_sharp")
            inst.Physics:ClearCollidesWith(COLLISION.GIANTS)
            ToggleOffCharacterCollisions(inst)
            TrySplashFX(inst)
            inst:DropAggro() -- 仇恨转移到主人身上

            if inst.components.timer ~= nil then
                inst.components.timer:StopTimer("shadowstrike_cd")
                inst.components.timer:StartTimer("shadowstrike_cd", 5) -- 冲刺cd只有5S
            end

            if data ~= nil then
                if data.target ~= nil and data.target:IsValid() then
                    inst.sg.statemem.target = data.target
                    inst:ForceFacePoint(data.target.Transform:GetWorldPosition())
                elseif data.targetpos ~= nil then
                    inst:ForceFacePoint(data.targetpos)
                end
            end
            inst.Physics:SetMotorVelOverride(35, 0, 0)

            inst.sg:SetTimeout(8 * FRAMES)
        end,

        onupdate = function(inst)
            if inst.sg.statemem.attackdone then
                return
            end
            local target = inst.sg.statemem.target
            if target == nil or not target:IsValid() then
                if inst.sg.statemem.animdone then
                    inst.sg.statemem.lunge = true
                    inst.sg:GoToState("lunge_pst")
                    return
                end
                inst.sg.statemem.target = nil
            elseif inst:IsNear(target, 1) then
                local fx = SpawnPrefab(math.random() < .5 and "shadowstrike_slash_fx" or "shadowstrike_slash2_fx")
                local x, y, z = target.Transform:GetWorldPosition()
                fx.Transform:SetPosition(x, y + 1.5, z)
                fx.Transform:SetRotation(inst.Transform:GetRotation())

                -- 只有暗影秘典招出来的暗影小人才修改攻击力
                if not inst.isgeminishadow then
                    CheckLeaderShadowLevel(inst, target ~= nil and target:IsValid() and target or nil)
                end
                inst.components.combat.externaldamagemultipliers:SetModifier(inst,
                    TUNING.SHADOWWAXWELL_SHADOWSTRIKE_DAMAGE_MULT, "shadowstrike")
                inst.components.combat:DoAttack(target)
                --Drop aggro again here, since we're in i-frames, and we might've
                --triggered spawners, and they will be initially targeted on me.
                inst:DropAggro() -- 仇恨转移到主人身上
                if inst.sg.statemem.animdone then
                    inst.sg.statemem.lunge = true
                    inst.sg:GoToState("lunge_pst", target)
                    return
                end
                inst.sg.statemem.attackdone = true
            end
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    if inst.sg.statemem.attackdone or inst.sg.statemem.target == nil then
                        inst.sg.statemem.lunge = true
                        inst.sg:GoToState("lunge_pst", inst.sg.statemem.target)
                        return
                    end
                    inst.sg.statemem.animdone = true
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg.statemem.lunge = true
            inst.sg:GoToState("lunge_pst")
        end,

        onexit = function(inst)
            inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, "shadowstrike")
            inst.components.combat:SetRange(2)
            if not inst.sg.statemem.lunge then
                inst:RestartBrain()
                inst.AnimState:SetBank("wilson")
                inst.Physics:CollidesWith(COLLISION.GIANTS)
                ToggleOnCharacterCollisions(inst)
            end
        end,
    },

    -- 冲刺结束状态
    State {
        name = "lunge_pst",
        tags = { "busy", "noattack", "temp_invincible", "phasing" },

        onenter = function(inst, target)
            inst.AnimState:PlayAnimation("lunge_pst")
            inst.Physics:SetMotorVelOverride(12, 0, 0)
            inst.sg.statemem.target = target
        end,

        onupdate = function(inst)
            inst.Physics:SetMotorVelOverride(inst.Physics:GetMotorVel() * .8, 0, 0)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    local target = inst.sg.statemem.target
                    local pos = inst:GetPosition()
                    pos.y = 0
                    local moved = false
                    if target ~= nil then
                        if target:IsValid() then
                            local targetpos = target:GetPosition()
                            local dx, dz = targetpos.x - pos.x, targetpos.z - pos.z
                            local radius = math.sqrt(dx * dx + dz * dz)
                            local theta = math.atan2(dz, -dx)
                            local offs = FindWalkableOffset(targetpos, theta, radius + 3 + math.random(), 8, false, true,
                                NotBlocked, true, true)
                            if offs ~= nil then
                                pos.x = targetpos.x + offs.x
                                pos.z = targetpos.z + offs.z
                                inst.Physics:Teleport(pos:Get())
                                moved = true
                            end
                        else
                            target = nil
                        end
                    end
                    if not moved and not TheWorld.Map:IsPassableAtPoint(pos.x, 0, pos.z, true) then
                        pos = FindNearbyLand(pos, 1) or FindNearbyLand(pos, 2)
                        if pos ~= nil then
                            inst.Physics:Teleport(pos.x, 0, pos.z)
                        end
                    end

                    if target ~= nil then
                        inst:ForceFacePoint(target.Transform:GetWorldPosition())
                    end

                    inst.sg.statemem.appearing = true
                    inst.sg:GoToState("appear")
                end
            end),
        },

        onexit = function(inst)
            inst:RestartBrain()
            inst.AnimState:SetBank("wilson")
            inst.Physics:CollidesWith(COLLISION.GIANTS)
            if not inst.sg.statemem.appearing then
                ToggleOnCharacterCollisions(inst)
            end
        end,
    },
}

return StateGraph("kisakishadowprotector", states, events, "spawn", actionhandlers)
