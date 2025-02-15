local avatar_name = "kisaki"
local log = require("utils/kisakilogger")

----------------------------------------------------------------------------组件通信----------------------------------------------------------------------------

AddReplicableComponent("kisaki_magic") -- 角色魔法值通信
AddReplicableComponent("kisaki_level") -- 角色等级经验通信

------------------------------------------------------------------------角色换人信息保存-------------------------------------------------------------------------

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
-- 角色保存的东西集中写在这，组件内只实现保存方法
AddPrefabPostInit("world", function(inst)
    if inst.ismastersim then
        -- 给服务器世界添加一个组件用于存储信息
        inst:AddComponent("kisaki_info_save")
        -- 角色退出世界时存储信息
        inst:ListenForEvent("ms_playerdespawn", Onplayerdespawnanddelete)
        inst:ListenForEvent("ms_playerdespawnandmigrate", Onplayerdespawnanddelete)
        inst:ListenForEvent("ms_playerdespawnanddelete", Onplayerdespawnanddelete)
    end
end)
-- 角色数据读取
AddPrefabPostInit("kisaki", function(inst)
    if TheWorld.ismastersim then
        local oldOnSoraSpawn = inst.OnNewSpawn
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
            if oldOnSoraSpawn then
                return oldOnSoraSpawn(player)
            end
        end
    end
end)

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
local function ttyx_add_tag(inst)
    inst:AddTag("kisaki_alterguardian_phase")
end
if TheNet:GetIsServer() and TUNING.KISAKI_IMMUNITY_AURA_ENABLE then
    AddPrefabPostInit("alterguardian_phase1", ttyx_add_tag)
    AddPrefabPostInit("alterguardian_phase2", ttyx_add_tag)
    AddPrefabPostInit("alterguardian_phase3", ttyx_add_tag)
end

----------------------------------------------------------------------------组件修改-----------------------------------------------------------------------------

--修改烹饪组件,让收获锅推送一个事件，用于记录角色经验，实现多倍采集
AddComponentPostInit("stewer", function(stewer)
    local oldHarvest = stewer.Harvest
    stewer.Harvest = function(self, harvester)
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
