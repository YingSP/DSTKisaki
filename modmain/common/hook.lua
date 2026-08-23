local avatar_name = "kisaki"
local log = require("utils/kisakilogger")
local SourceModifierList = require("util/sourcemodifierlist")
local SpDamageUtil = require("components/spdamageutil")

----------------------------------------------------------------------------组件通信----------------------------------------------------------------------------

AddReplicableComponent("kisaki_magic")       -- 角色魔法值通信
AddReplicableComponent("kisaki_level")       -- 角色等级经验通信
AddReplicableComponent("kisaki_achievement") -- 角色成就信息通信

----------------------------------------------------------------------------预制物修改--------------------------------------------------------------------------

-- 角色默认可听懂鱼人语言
AddPrefabPostInit("merm", function(inst)
    local oldresolvechatterfn = inst.components.talker and inst.components.talker.resolvechatterfn
    if oldresolvechatterfn ~= nil then
        inst.components.talker.resolvechatterfn = function(inst, strid, strtbl)
            if ThePlayer and ThePlayer:HasTag(avatar_name) then
                local stringtable = STRINGS[strtbl:value()]
                if stringtable then
                    if stringtable[strid:value()] ~= nil then
                        return stringtable[strid:value()][1]
                    end
                end
            end
            return oldresolvechatterfn(inst, strid, strtbl)
        end
    else
        log.error("原版鱼人解读语言的方法丢失，请排查！")
    end
end)

-- 天体英雄加tag，实现免疫启蒙光环
local lunacy_sanityaura_prefabs = {
    "alterguardian_phase1",
    "alterguardian_phase2",
    "alterguardian_phase3",
}
if TheNet:GetIsServer() and TUNING.KISAKI_IMMUNITY_AURA_ENABLE then
    for i, prefabname in ipairs(lunacy_sanityaura_prefabs) do
        AddPrefabPostInit(prefabname, function(inst)
            inst:AddTag("kisaki_alterguardian_phase")
        end)
    end
end

----------------------------------------------------------------------------组件修改-----------------------------------------------------------------------------

-- 修改烹饪组件,让收获锅推送一个事件，用于记录角色经验，实现多倍采集
AddComponentPostInit("stewer", function(Stewer)
    local oldHarvest = Stewer.Harvest
    function Stewer:Harvest(harvester, ...)
        -- 已经制作完且有角色拿时，往该角色推一个事件
        if self.done and harvester ~= nil and self.product and harvester:HasTag("kisaki") then
            harvester:PushEvent("kisaki_cook", { product = self.product, prefab = self.inst.prefab })
        end
        if oldHarvest then
            return oldHarvest(self, harvester)
        else
            log.error("原版收获烹饪锅的方法丢失，请排查！")
        end
    end
end)

-- 修改移速组件，原版大力士不减速是通过强壮组件实现的，不能直接拿来用
AddComponentPostInit("locomotor", function(self)
    local oldGetSpeedMultiplier = self.GetSpeedMultiplier
    -- 客户端和服务端用的方法不一样，而且是local的，有点抽象
    if TheWorld.ismastersim then
        self.GetSpeedMultiplier = function(self)
            local player_inventory = self.inst.components.inventory
            if player_inventory and player_inventory:EquipHasTag("kisaki_stronger")
                and not (self.inst.components.rider ~= nil and self.inst.components.rider:IsRiding()) then
                local mult = self:ExternalSpeedMultiplier()
                if player_inventory.isopen then
                    for k, v in pairs(self.inst.components.inventory.equipslots) do
                        if v.components.equippable ~= nil then
                            local item_speed_mult = v.components.equippable:GetWalkSpeedMult()
                            mult = mult * math.max(item_speed_mult, 1)
                        end
                    end
                end
                return mult * (self:TempGroundSpeedMultiplier() or self.groundspeedmultiplier) * self.throttle
            elseif oldGetSpeedMultiplier then
                return oldGetSpeedMultiplier(self)
            end
        end
    else
        self.GetSpeedMultiplier = function(self)
            local player_inventory = self.inst.replica.inventory
            if player_inventory and player_inventory:EquipHasTag("kisaki_stronger")
                and not (self.inst.replica.rider and self.inst.replica.rider:IsRiding()) then
                local mult = self:ExternalSpeedMultiplier()
                for k, v in pairs(player_inventory:GetEquips()) do
                    local inventoryitem = v.replica.inventoryitem
                    if inventoryitem ~= nil then
                        local item_speed_mult = inventoryitem:GetWalkSpeedMult()
                        mult = mult * math.max(item_speed_mult, 1)
                    end
                end
                return mult * (self:TempGroundSpeedMultiplier() or self.groundspeedmultiplier) * self.throttle
            elseif oldGetSpeedMultiplier then
                return oldGetSpeedMultiplier(self)
            end
        end
    end
end)

-- 修改血量组件，实现可加成所有伤害的易伤
AddComponentPostInit("health", function(Health)
    Health.kisaki_takedmg_mult = SourceModifierList(Health.inst, 1, SourceModifierList.multiply) -- 易伤乘算

    local oldDoDelta = Health.DoDelta
    function Health:DoDelta(amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
        if amount < 0 then
            amount = amount * self.kisaki_takedmg_mult:Get()
        end

        return oldDoDelta(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
    end
end)

-- 修改攻击组件，实现独立攻击加成
-- AddComponentPostInit("combat", function(Combat)
--     Combat.kisaki_damagetype_mult = SourceModifierList(Combat.inst, 1, SourceModifierList.multiply) -- 加伤乘算

--     local oldCalcDamage = Combat.CalcDamage
--     function Combat:CalcDamage(target, weapon, multiplier, ...)
--         local damage, spdamage = oldCalcDamage(self, target, weapon, multiplier, ...)
--         if damage > 0 then
--             damage = damage * self.kisaki_damagetype_mult:Get()
--         end
--         if spdamage ~= nil then
--             spdamage = SpDamageUtil.ApplyMult(spdamage, self.kisaki_damagetype_mult:Get())
--         end
--         return damage, spdamage
--     end
-- end)

-- 将魔法值加入到制作配方中
CHARACTER_INGREDIENT.KISAKI_MAGIC = "kisaki_magic"
-- 判断是否是角色属性的方法
local oldIsCharacterIngredient = _G.IsCharacterIngredient
if oldIsCharacterIngredient then
    _G.IsCharacterIngredient = function(ingredienttype)
        if ingredienttype == "kisaki_magic" then
            return true
        end
        return oldIsCharacterIngredient(ingredienttype)
    end
end
-- 修改服务器制作组件
AddComponentPostInit("builder", function(self)
    if not self.inst:HasTag("kisaki") then
        return -1
    end
    -- 判断是否存在该角色属性可以作为制作配方
    local oldHasCharacterIngredient = self.HasCharacterIngredient
    self.HasCharacterIngredient = function(s, ingredient, ...)
        if ingredient.type == CHARACTER_INGREDIENT.KISAKI_MAGIC then
            if self.inst.components.kisaki_magic ~= nil then
                return (self.freebuildmode and 0) or
                    math.ceil(self.inst.components.kisaki_magic.current) >= ingredient.amount,
                    self.inst.components.kisaki_magic.current
            end
        end
        return oldHasCharacterIngredient(s, ingredient, ...)
    end
    -- 制作时消耗人物属性
    local oldRemoveIngredients = self.RemoveIngredients
    self.RemoveIngredients = function(s, ingredients, recname)
        local recipe = AllRecipes[recname]
        if recipe then
            for _, v in pairs(recipe.character_ingredients) do
                if v.type == CHARACTER_INGREDIENT.KISAKI_MAGIC then
                    local current = math.ceil(self.inst.components.kisaki_magic.current)
                    if current >= v.amount and not self.freebuildmode then
                        self.inst.components.kisaki_magic:DoDelta(-v.amount)
                    end
                end
            end
        end
        return oldRemoveIngredients(s, ingredients, recname)
    end
end)
-- 同步修改客户端制作组件
AddClassPostConstruct("components/builder_replica", function(self)
    if not self.inst:HasTag("kisaki") then
        return -1
    end
    -- 制作解锁
    local oldHasCharacterIngredient = self.HasCharacterIngredient
    self.HasCharacterIngredient = function(s, ingredient, ...)
        if self.inst.replica.kisaki_magic.current ~= nil then
            local current = math.ceil(self.inst.replica.kisaki_magic.current:value())
            return (self.classified.isfreebuildmode:value() and 0) or current >= ingredient.amount, current
        end
        return oldHasCharacterIngredient(self, ingredient, ...)
    end
end)

----------------------------------------------------------------------------玩家修改-----------------------------------------------------------------------------
local function KillPet(pet)
    if pet.components.health:IsInvincible() then
        --reschedule
        pet._killtask = pet:DoTaskInTime(.5, KillPet)
    else
        pet.components.health:Kill()
    end
end
local function OnSpawnPet(inst, pet)
    if pet:HasTag("kisaki_shadow_protector") then
        if (inst.components.health:IsDead() or inst:HasTag("playerghost")) and pet._killtask == nil then
            pet._killtask = pet:DoTaskInTime(math.random(), KillPet)
        end
    elseif inst.kisaki_OnSpawnPet ~= nil then
        inst:kisaki_OnSpawnPet(pet)
    end
end
local function OnDespawnPet(inst, pet)
    if pet:HasTag("kisaki_shadow_protector") then
        if not inst.is_snapshot_user_session and pet.sg ~= nil then
            pet.sg:GoToState("quickdespawn")
        else
            pet:Remove()
        end
    elseif inst.kisaki_OnDespawnPet ~= nil then
        inst:kisaki_OnDespawnPet(pet)
    end
end

local function SetOmmateumVision(inst)
    if inst and inst.components.playervision then
        inst.components.playervision:ForceNightVision(inst._kisaki_nightvision:value())
        inst.components.playervision:SetCustomCCTable(inst._kisaki_nightvision:value() and {} or nil)
    end
end

AddPlayerPostInit(function(inst)
    -- 删除生成暗影守护者时的转圈圈特效
    if inst.components.petleash ~= nil then
        inst.kisaki_OnSpawnPet = inst.components.petleash.onspawnfn
        inst.kisaki_OnDespawnPet = inst.components.petleash.ondespawnfn
    else
        inst:AddComponent("petleash")
    end
    inst.components.petleash:SetOnSpawnFn(OnSpawnPet)
    inst.components.petleash:SetOnDespawnFn(OnDespawnPet)
    -- 添加夜视监听
    inst._kisaki_nightvision = net_bool(inst.GUID, "kisaki_nightvision._enabled", "kisaki_nightvision_enableddirty")
    inst:ListenForEvent("kisaki_nightvision_enableddirty", SetOmmateumVision)
    -------------------------------------------------------------------服务器部分修改--------------------------------------------------------------
    if TheWorld.ismastersim then
        -- 霸体
        inst._kisaki_domination = SourceModifierList(inst, false, SourceModifierList.boolean)
        -- 玩家攻击独立增伤
        local kisaki_player_combat = inst.components.combat
        kisaki_player_combat.kisaki_damagetype_mult =
            SourceModifierList(kisaki_player_combat.inst, 1, SourceModifierList.multiply) -- 加伤乘算
        local kisaki_oldCalcDamage = kisaki_player_combat.CalcDamage
        kisaki_player_combat.CalcDamage = function(self, target, weapon, multiplier, ...)
            local damage, spdamage = kisaki_oldCalcDamage(self, target, weapon, multiplier, ...)
            if damage > 0 then
                damage = damage * self.kisaki_damagetype_mult:Get()
            end
            if spdamage ~= nil then
                spdamage = SpDamageUtil.ApplyMult(spdamage, self.kisaki_damagetype_mult:Get())
            end
            return damage, spdamage
        end
        -- 特殊增伤（只增伤普通伤害）
        inst.kisaki_remote_damagetype_mult = SourceModifierList(inst, 0, SourceModifierList.additive) -- 远程武器独立增伤加算
        inst.kisaki_melee_damagetype_mult = SourceModifierList(inst, 0, SourceModifierList.additive)  -- 近战武器独立增伤加算
        local kisaki_oldCustomdamagemultfn = kisaki_player_combat.customdamagemultfn
        kisaki_player_combat.customdamagemultfn = function(player, target, weapon, multiplier, mount, ...)
            local customdamagemult = kisaki_oldCustomdamagemultfn ~= nil and
                kisaki_oldCustomdamagemultfn(player, target, weapon, multiplier, mount, ...) or 1
            if customdamagemult <= 0 or weapon == nil or weapon.components.weapon == nil then
                return customdamagemult
            end
            if weapon.components.weapon.attackrange == nil or weapon.components.weapon.attackrange < 5 then
                return customdamagemult *
                    (player.kisaki_melee_damagetype_mult ~= nil and math.max(1 + player.kisaki_melee_damagetype_mult:Get(), 0) or 1)
            else
                return customdamagemult *
                    (player.kisaki_remote_damagetype_mult ~= nil and math.max(1 + player.kisaki_remote_damagetype_mult:Get(), 0) or 1)
            end
        end
    end
end)

------------------------------------------------------------------------世界组件修改-------------------------------------------------------------------------

-- 世界预制物添加监听，用于实现角色等级等信息保存
local function Onplayerdespawnanddelete(world, data)
    local player = data.player or data
    if player:HasTag("kisaki") then
        local saveinfo = {}
        for k, v in pairs(player.components) do
            if v.OnPlayerSave then
                saveinfo[k] = v:OnPlayerSave()
            end
        end
        log.info("检测到角色消失，将角色数据存储进世界数据，当前玩家为：" .. player.userid)
        TheWorld.components.kisaki_info_save:SetSaveInfo(player.userid, saveinfo)
    end
end
-- 角色数据读取
AddPrefabPostInit("kisaki", function(inst)
    if TheWorld.ismastersim then
        local oldOnKisakiSpawn = inst.OnNewSpawn
        inst.OnNewSpawn = function(player)
            if TheWorld.components.kisaki_info_save and TUNING.KISAKI_DATA_SAVE then
                log.info("检测到玩家出生，从世界数据中读取之前存储的角色数据，当前玩家为：" .. player.userid)
                local saveinfo = TheWorld.components.kisaki_info_save:GetSaveInfo(player.userid)
                if saveinfo then
                    log.debug("从世界组件中拿到了当前玩家的数据")
                    for k, v in pairs(saveinfo) do
                        if player.components[k] and player.components[k].OnPlayerLoad then
                            player.components[k]:OnPlayerLoad(v)
                        end
                    end
                else
                    log.info("当前玩家为首次进入世界，数据设为默认值")
                end
            end
            if oldOnKisakiSpawn then
                return oldOnKisakiSpawn(player)
            end
        end
    end
end)


AddPrefabPostInit("world", function(inst)
    if not TheWorld.ismastersim then
        return
    end
    -- 给服务器世界添加一个组件用于存储信息
    inst:AddComponent("kisaki_info_save")
    -- 角色退出世界时存储信息
    inst:ListenForEvent("ms_playerdespawn", Onplayerdespawnanddelete)
    inst:ListenForEvent("ms_playerdespawnandmigrate", Onplayerdespawnanddelete)
    inst:ListenForEvent("ms_playerdespawnanddelete", Onplayerdespawnanddelete)
end)
