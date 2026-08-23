local manager
local chest
local items_list = TUNING.KISAKI_SPACE_CHEST_ITEMS

----------------------------------------------------------------------------方法-------------------------------------------------------------------------------

-- 计算箱子的科技反鲜等
local function ResetChestData(inst)
    local magic_data_changed = false
    local library_data_changed = false
    local kisaki_magic_box = inst.components.container:GetItemInSlot(241)
    local is_valid_box = kisaki_magic_box and kisaki_magic_box.prefab == "kisaki_magic_box"
    for i, data in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
        local action = data.action
        local key = action .. "num"
        local value = is_valid_box and kisaki_magic_box[key] or 0
        if inst[key] ~= value then
            inst[key] = value
            magic_data_changed = true
        end
    end

    local kisaki_library_box = inst.components.container:GetItemInSlot(242)
    is_valid_box = kisaki_library_box and kisaki_library_box.prefab == "kisaki_library_box"
    for i, data in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
        local key = data.id .. "num"
        local value = is_valid_box and kisaki_library_box[key] or 0
        if inst[key] ~= value then
            inst[key] = value
            library_data_changed = true
        end
    end
    if magic_data_changed then
        inst.addpreserver()
        inst.addrestorationdurability()
    end
    if library_data_changed then
        local trees, tags, addhermitcrabshop, addwanderingtradershop, removed_trees, removed_tags = inst
            .libraryBoxRefresh()
        for kisaki_space_chest, value in pairs(manager.chest_list) do
            if not (kisaki_space_chest and value) then
                manager.chest_list[kisaki_space_chest] = nil
            end
            if kisaki_space_chest and value and kisaki_space_chest.components.craftingstation and kisaki_space_chest.components.prototyper then
                local original_trees = kisaki_space_chest.components.prototyper.trees
                for levelname in pairs(removed_trees) do
                    original_trees[levelname] = nil
                end
                for levelname, level in pairs(trees) do
                    original_trees[levelname] = level
                end
                for _, tag in ipairs(removed_tags) do
                    kisaki_space_chest:RemoveTag(tag)
                end
                for _, tag in ipairs(tags) do
                    if not kisaki_space_chest:HasTag(tag) then
                        kisaki_space_chest:AddTag(tag)
                    end
                end
                local craftingstation = kisaki_space_chest.components.craftingstation
                if addhermitcrabshop then
                    craftingstation:LearnItem("supertacklecontainer", "hermitshop_supertacklecontainer")
                    craftingstation:LearnItem("winter_ornament_boss_pearl", "hermitshop_winter_ornament_boss_pearl")
                    craftingstation:LearnItem("winter_ornament_boss_hermithouse",
                        "hermitshop_winter_ornament_boss_hermithouse")
                else
                    craftingstation:ForgetItem("supertacklecontainer")
                    craftingstation:ForgetItem("winter_ornament_boss_pearl")
                    craftingstation:ForgetItem("winter_ornament_boss_hermithouse")
                end
                if addwanderingtradershop then
                    craftingstation:LearnItem("gears", "wanderingtradershop_gears")
                    craftingstation:LearnItem("flint", "wanderingtradershop_flint")
                    craftingstation:LearnItem("pigskin", "wanderingtradershop_pigskin")
                    craftingstation:LearnItem("livinglog", "wanderingtradershop_livinglog")
                    craftingstation:LearnItem("redgem", "wanderingtradershop_redgem")
                    craftingstation:LearnItem("bluegem", "wanderingtradershop_bluegem")
                    craftingstation:LearnItem("cutgrass", "wanderingtradershop_cutgrass")
                    craftingstation:LearnItem("twigs", "wanderingtradershop_twigs")
                    craftingstation:LearnItem("cutreeds", "wanderingtradershop_cutreeds")
                    craftingstation:LearnItem("moonglass", "wanderingtradershop_moonglass")
                else
                    craftingstation:ForgetItem("gears")
                    craftingstation:ForgetItem("flint")
                    craftingstation:ForgetItem("pigskin")
                    craftingstation:ForgetItem("livinglog")
                    craftingstation:ForgetItem("redgem")
                    craftingstation:ForgetItem("bluegem")
                    craftingstation:ForgetItem("cutgrass")
                    craftingstation:ForgetItem("twigs")
                    craftingstation:ForgetItem("cutreeds")
                    craftingstation:ForgetItem("moonglass")
                end
            end
        end
    end
end

-- 整理箱子里物品
local function ChestTidy(inst)
    local items = {}
    for slot, item in pairs(inst.components.container.slots) do
        if item and item.prefab ~= items_list[slot] and items_list[slot] ~= "" then
            inst.components.container.ignoreoverstacked = true
            item = inst.components.container:RemoveItemBySlot(slot)
            inst.components.container.ignoreoverstacked = false
            table.insert(items, item)
        end
    end
    for i = 1, #items do
        inst.components.container:GiveItem(items[i])
    end
end

-- 刷新下全图物品标记
local function TryMarkEnt(inst)
    inst.KisakiCollectSkip = nil
    if not inst.replica then
        inst.KisakiCollectSkip = true
        return
    end
    if not inst.replica.inventoryitem then
        inst.KisakiCollectSkip = true
        return
    end
    if inst.components.projectile and (inst.components.projectile.target or inst.components.projectile.dest) then -- 投射物
        inst.KisakiCollectSkip = true
        return
    end
    if inst:IsInLimbo() then -- 不可见实体
        inst.KisakiCollectSkip = true
        return
    end
    if inst.components.health and inst.components.health:IsDead() then -- 已经死了
        inst.KisakiCollectSkip = true
        return
    end
end
local function UpdateAllEnts()
    for k, prefab in pairs(Ents) do
        TryMarkEnt(prefab)
    end
end

-- 整理一下箱子需要收集的物品
local function UpdateCollectList(inst)
    local collectlist = {}
    for slot, item in pairs(inst.components.container.slots) do
        if slot <= 240 and item and item.prefab then
            -- print("我需要收集以下内容:" .. STRINGS.NAMES[string.upper(item.prefab)])
            collectlist[item.prefab] = 1
        end
    end
    inst.collectlist = collectlist
end

-- 全图收集
local function catch(inst)
    if inst:IsValid() and not inst:IsInLimbo() and inst.components.inventoryitem and
        not inst.components.inventoryitem.owner and not (inst.components.health and inst.components.health:IsDead()) then
        return true
    end
    return false
end
local function CollectEnts(inst)
    -- 暂停收集状态下不能收集
    if manager:IsStop() then
        return
    end
    -- 开始收集
    local collectlist = inst.collectlist
    for k, prefab in pairs(Ents) do
        if not prefab.KisakiCollectSkip and collectlist[prefab.prefab] and catch(prefab) and inst.components.container:CanAcceptCount(prefab) > 0 then
            -- print("以下物品进行收集:" .. STRINGS.NAMES[string.upper(prefab.prefab)])
            inst.components.container:GiveItem(prefab)
        end
    end
end

-- 进行一次全图收集
local function CollectItem(inst)
    if manager:IsStop() then
        return
    end
    if manager.UpdateAllEntsCD() then
        UpdateAllEnts()
    end
    -- 看下容器内有的物品，统计收集的目录
    UpdateCollectList(inst)
    -- 将全图的物品收集起来
    CollectEnts(inst)
end

local function UpdateAllChest()
    if chest == nil or chest.components.container == nil or manager.chest_list == nil or next(manager.chest_list) == nil then
        return
    end
    ResetChestData(chest)
    if manager:IsStop() then
        return
    end
    if manager.CollectEntssCD() then
        -- print("准备开始收集")
        CollectItem(chest)
    end
end

----------------------------------------------------------------------------CLASS-----------------------------------------------------------------------------

local Manager = Class(function(self, inst)
    self.inst = inst
    manager = self
    self.chest_list = {}
    self.stoptime = 0
    self.collectCD = 10
    self.CollectEntssCD = KisakiCD(math.max(self.collectCD, 3))
    self.UpdateAllEntsCD = KisakiCD(math.max(self.collectCD * 2, 10))
    self.UpdateAllChestTask = inst:DoPeriodicTask(1, UpdateAllChest)
end)

----------------------------------------------------------------------------注册-----------------------------------------------------------------------------

local function OnOpen(inst, event)
end
local function OnClose(inst, event)
    local doer = event and event.doer
    ChestTidy(chest)
    ResetChestData(inst)
    if not (doer and doer:HasTag("player") and inst.components.container) then
        return
    end
    inst:DoTaskInTime(0, function()
        CollectItem(inst)
    end)
end
local function OnChestRemove(inst)
    manager:UnRegisterChest(inst)
end
local function OnItemGet(inst, data)
end
local function OnItemLose(inst, data)
end

function Manager:RegisterChest(kisaki_space_chest)
    chest = kisaki_space_chest
    kisaki_space_chest.collectlist = {}
    kisaki_space_chest:ListenForEvent("onopen", OnOpen)
    kisaki_space_chest:ListenForEvent("onclose", OnClose)
    kisaki_space_chest:ListenForEvent("onremove", OnChestRemove)
    kisaki_space_chest:ListenForEvent("itemget", OnItemGet)
    kisaki_space_chest:ListenForEvent("itemlose", OnItemLose)
    kisaki_space_chest.components.container.OnRemoveFromEntity = function(...)
        self:UnRegisterChest(kisaki_space_chest)
    end
end

function Manager:UnRegisterChest(kisaki_space_chest)
    kisaki_space_chest.collectlist = nil
    kisaki_space_chest:RemoveEventCallback("onopen", OnOpen)
    kisaki_space_chest:RemoveEventCallback("onclose", OnClose)
    kisaki_space_chest:RemoveEventCallback("itemget", OnItemGet)
    kisaki_space_chest:RemoveEventCallback("itemlose", OnItemLose)
    chest = nil
end

function Manager:RegisterOriginalChest(kisaki_space_chest)
    self.chest_list[kisaki_space_chest] = 1
end

function Manager:UnRegisterOriginalChest(kisaki_space_chest)
    self.chest_list[kisaki_space_chest] = nil
end

function Manager:IsStop()
    if self.stoptime < 0 then
        return true
    elseif self.stoptime == 0 then
        return false
    else
        return self.stoptime > GetTime()
    end
end

function Manager:Stop(time)
    if time == nil or time < 0 then
        self.stoptime = -1
    else
        self.stoptime = GetTime() + time
    end
end

function Manager:Control(cycle)
    if cycle == nil or cycle < 3 then
        return
    end
    self.collectCD = cycle
    self.CollectEntssCD = KisakiCD(math.max(self.collectCD, 3))
    self.UpdateAllEntsCD = KisakiCD(math.max(self.collectCD * 2, 10))
end

function Manager:Collect()
    if manager:IsStop() or chest == nil or chest.components.container == nil then
        return
    end
    CollectItem(chest)
end

----------------------------------------------------------------------------保存读取-----------------------------------------------------------------------------

function Manager:OnSave()
    return
    {
        stoptime = self.stoptime,
        collectCD = self.collectCD,
    }
end

function Manager:OnLoad(data)
    if not data then return end
    if data.stoptime == nil or data.stoptime < 0 then
        self.stoptime = -1
    end
    self:Control(data.collectCD)
end

return Manager
