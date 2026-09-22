-- 服务端传送工具：门之钥虫洞与法杖的玩家传送。
-- 玩家传送仅接收客户端提交的 userid，目标实体、当前分片和最终落点均由服务端重新确认。

local TeleportUtil = {}

local NOTENTCHECK_CANT_TAGS = { "FX", "INLIMBO" }
local DOOR_SEARCH_RADII = { 3, 5, 7 }
local function noentcheckfn(pt)
    return not TheWorld.Map:IsPointNearHole(pt) and
        #TheSim:FindEntities(pt.x, pt.y, pt.z, 1, nil, NOTENTCHECK_CANT_TAGS) == 0
end

-- 将原版的偏移量搜索统一转换成世界坐标；两种传送各自传入落点规则。
local function FindNearbyPosition(position, angle, radius, attempts, check_los, ignore_walls, checkfn, allow_water, allow_boats)
    local offset = FindWalkableOffset(position, angle, radius, attempts, check_los, ignore_walls,
        checkfn, allow_water, allow_boats)
    return offset ~= nil and position + offset or nil
end

-- 门之钥依次尝试三个距离，找不到时保持原位置。
local function FindDoorPosition(position)
    for _, radius in ipairs(DOOR_SEARCH_RADII) do
        local destination = FindNearbyPosition(position, math.random() * TWOPI, radius + math.random(),
            16, false, true, noentcheckfn, true, true)
        if destination ~= nil then
            return destination
        end
    end
    return position
end

-- 门之钥：在施法者和最近的容器旁各生成一个虫洞落点。
function TeleportUtil.OpenDoor(doer)
    local chest_list = TheWorld.components.kisaki_ents_manager.chest_list
    if not chest_list or not next(chest_list) then return end
    -- 找到离玩家最近的
    local pt = doer:GetPosition()
    local closest_distance = nil
    local closest_chest = nil
    for chest, value in pairs(chest_list) do
        print("当前世界列表里的容器" .. tostring(chest))
        if not closest_distance or chest:GetDistanceSqToPoint(pt) < closest_distance then
            closest_distance = chest:GetDistanceSqToPoint(pt)
            closest_chest = chest
        end
    end
    if not closest_chest then return end
    -- 两端采用相同的虫洞落点策略。
    pt = FindDoorPosition(pt)
    local closest_chest_pt = FindDoorPosition(closest_chest:GetPosition())

    -- 生成虫洞
    local portal = SpawnPrefab("pocketwatch_portal_entrance")
    portal.Transform:SetPosition(pt:Get())
    portal:SpawnExit(closest_chest_pt.recall_worldid, closest_chest_pt.x, closest_chest_pt.y,
        closest_chest_pt.z)
    return true
end

-- 只有手上装备的法杖处于传送状态时，才允许使用玩家传送。
local function GetEquippedTeleportStaff(player)
    local inventory = player.components.inventory
    local staff = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    if staff ~= nil
        and (staff.prefab == "kisaki_magic_staff" or staff.prefab == "kisaki_magic_staff_max")
        and staff.staff_mode == "teleport" then
        return staff
    end
end

-- 在目标附近寻找安全落点。
-- 优先陆地或目标所在的船；施法者可踏水时，才将水面点作为后备落点。
local function FindDestination(target, owner)
    local position = target:GetPosition()
    local map = TheWorld.Map
    local platform = map:GetPlatformAtPoint(position.x, position.z)
    local drownable = owner.components.drownable
    local can_walk_on_water = drownable ~= nil and drownable.enabled == false
    local water_destination
    local function IsSafeDestination(destination)
        return (map:IsPassableAtPoint(destination.x, 0, destination.z, false)
                or (platform ~= nil and map:GetPlatformAtPoint(destination.x, destination.z) == platform))
            and not map:IsGroundTargetBlocked(destination)
            and not map:IsPointNearHole(destination)
    end
    local function IsSafeWaterDestination(destination)
        return not map:IsGroundTargetBlocked(destination)
            and not map:IsPointNearHole(destination)
    end
    for index = 1, 12 do
        local angle = index * TWOPI / 12
        local destination = FindNearbyPosition(position, angle, 2, 1, false, false,
            IsSafeDestination, false, platform ~= nil)
        if destination ~= nil then
            return destination
        end
        if can_walk_on_water and water_destination == nil then
            local offset = FindSwimmableOffset(position, angle, 2, 1, false, false,
                IsSafeWaterDestination, false)
            if offset ~= nil then
                water_destination = position + offset
            end
        end
    end
    if platform ~= nil and not map:IsGroundTargetBlocked(position) then
        return position
    end
    return water_destination
end

-- 失败原因通过施法者的对话框反馈。
local function Say(player, message)
    if player.components.talker ~= nil then
        player.components.talker:Say(message)
    end
end

-- 请求将 player 传送到 userid 对应的玩家附近。
-- LookupPlayerInstByUserID 只查找当前分片的实体，因此跨地上/地下世界会自然失败。
function TeleportUtil.ToPlayer(player, userid)
    if type(userid) ~= "string" or userid == "" or player == nil or not player:IsValid()
        or player.userid == userid or player.sg == nil or player.sg:HasStateTag("busy")
        or (player.components.health ~= nil and player.components.health:IsDead())
        or player:HasTag("playerghost") or GetEquippedTeleportStaff(player) == nil then
        return
    end

    -- 先确认目标存在于当前世界；客户端玩家列表可能包含其他分片的玩家。
    local target = LookupPlayerInstByUserID(userid)
    if target == nil or not target:IsValid() then
        Say(player, STRINGS.KISAKI_MAGIC_STAFF.TARGET_NOT_HERE)
        return
    end
    if FindDestination(target, player) == nil then
        Say(player, STRINGS.KISAKI_MAGIC_STAFF.NO_DESTINATION)
        return
    end

    -- vault_teleport 状态带有渐隐、禁用控制和传送特效。
    -- 回调可能在状态退出时再次触发，所以用 completed 防止重复结算。
    local completed = false
    player.sg:GoToState("vault_teleport", {
        onplayerready = function()
            if completed then
                return
            end
            completed = true

            -- 仍处于 channeling 表示传送被提前打断，不移动也不扣 SAN。
            if player.sg:HasStateTag("channeling") then
                return
            end

            if not player:IsValid() or player:HasTag("playerghost")
                or (player.components.health ~= nil and player.components.health:IsDead())
                or GetEquippedTeleportStaff(player) == nil then
                return
            end
            -- 传送动画期间目标可能离线或切换分片，结算前再次验证。
            local current_target = LookupPlayerInstByUserID(userid)
            if current_target == nil or not current_target:IsValid() then
                Say(player, STRINGS.KISAKI_MAGIC_STAFF.TARGET_NOT_HERE)
                return
            end
            local destination = FindDestination(current_target, player)
            if destination == nil then
                Say(player, STRINGS.KISAKI_MAGIC_STAFF.NO_DESTINATION)
                return
            end

            -- 参考 vault_orb_refined：在抵达点生成特效、移动施法者并重置镜头。
            SpawnPrefab("vault_portal_fx").Transform:SetPosition(destination.x, 0, destination.z)
            if player.Physics ~= nil then
                player.Physics:Teleport(destination.x, 0, destination.z)
            else
                player.Transform:SetPosition(destination.x, 0, destination.z)
            end
            player:SnapCamera()
            player.SoundEmitter:PlaySound("rifts6/vault_portal/teleport_arrive_FX")
            if player.components.sanity ~= nil then
                player.components.sanity:DoDelta(-TUNING.SANITY_HUGE)
            end
        end,
    })
end

return TeleportUtil
