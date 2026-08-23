require "behaviours/wander"
require "behaviours/faceentity"
require "behaviours/chaseandattack"
require "behaviours/follow"
require "behaviours/leash"
require "behaviours/runaway"

local KisakiShadowProtectorBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local START_FACE_DIST = 4
local KEEP_FACE_DIST = 8
local KEEP_DANCING_DIST = 2
local AVOID_EXPLOSIVE_DIST = 5
local MIN_FOLLOW_DIST = 0
local TARGET_FOLLOW_DIST = 6
local MAX_FOLLOW_DIST = 8

-------------------------------------------------------------------------辅助方法---------------------------------------------------------------------------

-- 找到主人
local function GetLeader(inst)
    return inst.components.follower.leader
end
-- 找到主人的位置
local function GetLeaderPos(inst)
    return inst.components.follower.leader:GetPosition()
end
-- 主人是否在身边
local function IsNearLeader(inst, dist)
    local leader = GetLeader(inst)
    return leader ~= nil and inst:IsNear(leader, dist)
end

-- 判断是否跟着主人跳舞
local function ShouldDanceParty(inst)
    local leader = GetLeader(inst)
    return leader ~= nil and leader.sg:HasStateTag("dancing")
end
-- 跳舞
local function DanceParty(inst)
    inst:PushEvent("dance")
end

-- 判断是否看主人玩游戏
local function ShouldWatchMinigame(inst)
    if inst.components.follower.leader ~= nil and inst.components.follower.leader.components.minigame_participator ~= nil then
        if inst.components.combat.target == nil or inst.components.combat.target.components.minigame_participator ~= nil then
            return true
        end
    end
    return false
end
-- 获取主人在玩的游戏预制物
local function WatchingMinigame(inst)
    return (inst.components.follower.leader ~= nil and inst.components.follower.leader.components.minigame_participator ~= nil) and
        inst.components.follower.leader.components.minigame_participator:GetMinigame() or nil
end
-- 当前小游戏的观战最小保持距离
local function WatchingMinigame_MinDist(inst)
    local minigame = WatchingMinigame(inst)
    return minigame ~= nil and minigame.components.minigame.watchdist_min or 0
end
-- 当前小游戏的观战理想保持距离
local function WatchingMinigame_TargetDist(inst)
    local minigame = WatchingMinigame(inst)
    return minigame ~= nil and minigame.components.minigame.watchdist_target or 0
end
-- 当前小游戏的观战最大保持距离
local function WatchingMinigame_MaxDist(inst)
    local minigame = WatchingMinigame(inst)
    return minigame ~= nil and minigame.components.minigame.watchdist_max or 0
end

-- 判断是否是爆炸物
local function ShouldAvoidExplosive(target)
    return target.components.explosive == nil
        or target.components.burnable == nil
        or target.components.burnable:IsBurning()
end

-- 拿到可面朝的主人实体
local function GetFaceLeaderFn(inst)
    local target = GetLeader(inst)
    return target ~= nil and target.entity:IsVisible() and inst:IsNear(target, START_FACE_DIST) and target or nil
end
-- 判断是否可以持续面朝主人
local function KeepFaceLeaderFn(inst, target)
    return target.entity:IsVisible() and inst:IsNear(target, KEEP_FACE_DIST)
end

-------------------------------------------------------------------------AI逻辑---------------------------------------------------------------------------

function KisakiShadowProtectorBrain:OnStart()
    -- 每0.25S检查一次是否应该执行跳舞逻辑
    local dance_party = WhileNode(function() return ShouldDanceParty(self.inst) end, "Dance Party",
        PriorityNode({ -- 顺序判断，找到符合的就执行
            -- 将随从限制在主人周围（最大距离/理想距离）
            Leash(self.inst, GetLeaderPos, KEEP_DANCING_DIST, KEEP_DANCING_DIST),
            -- 执行跳舞
            ActionNode(function() DanceParty(self.inst) end),
        }, 0.25))
    -- 每0.25S检查一次主人是否在参加小游戏时，如果是则跟随主人并在一旁看着
    local watch_game = WhileNode(function() return ShouldWatchMinigame(self.inst) end, "Watching Game",
        PriorityNode({ -- 顺序判断，找到符合的就执行
            -- 跟随小游戏装置并保持距离
            Follow(self.inst, WatchingMinigame, WatchingMinigame_MinDist, WatchingMinigame_TargetDist,
                WatchingMinigame_MaxDist),
            -- 离带有minigame_participator标签的预制物至少5，理想7
            RunAway(self.inst, "minigame_participator", 5, 7),
            -- 当小游戏装置存在时，面朝小游戏装置（装置实体/能否继续面朝装置）
            FaceEntity(self.inst, WatchingMinigame, WatchingMinigame),
        }, 0.25))
    -- 远离爆炸物
    local avoid_explosions = RunAway(self.inst,
        { fn = ShouldAvoidExplosive, tags = { "explosive" }, notags = { "INLIMBO" } }, AVOID_EXPLOSIVE_DIST,
        AVOID_EXPLOSIVE_DIST)
    -- 面朝主人
    local face_leader = FaceEntity(self.inst, GetFaceLeaderFn, KeepFaceLeaderFn)

    local root = PriorityNode({
        -- 第一优先级判断是否跳舞
        dance_party,
        -- 第二优先级判断是否观看小游戏
        watch_game,
        -- 第三优先级远离爆炸物
        avoid_explosions,
        -- 当主人在周围时，攻击并追杀目标
        WhileNode(function() return IsNearLeader(self.inst, 12) end, "Leader In Range", ChaseAndAttack(self.inst)),
        -- 跟随主人
        Follow(self.inst, GetLeader, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
        -- 面朝主人
        face_leader,
        -- 在主人周围游荡（不可奔跑）
        Wander(self.inst,
            function() return self.inst:GetPosition() end,
            6,
            nil, nil, nil, nil,
            {
                should_run = false,
                wander_dist = 4,
            }
        )
    }, 0.25)

    self.bt = BT(self.inst, root)
end

return KisakiShadowProtectorBrain
