GLOBAL.KISAKI_API = env

local moddir = KnownModIndex:GetModsToLoad(true)
local enablemods = {}

for k, dir in pairs(moddir) do
    local info = KnownModIndex:GetModInfo(dir)
    local name = info and info.name or "unknow"
    enablemods[dir] = name
end
-- MOD是否开启
function IsModEnable(name)
    for k, v in pairs(enablemods) do
        if v and (k:match(name) or v:match(name)) then return true end
    end
    return false
end

-- 获取开启的服务器模组列表
function ModList()
    return enablemods
end

--添加临时标签
function AddMedalTag(owner, tag)
    owner.kisaki_temp_tag = owner.kisaki_temp_tag or {}
    --添加标签时进行计数,防止由于勋章、装备的穿脱导致角色身上原本拥有的标签被移除掉
    if owner:HasTag(tag) then
        owner.kisaki_temp_tag[tag] = (owner.kisaki_temp_tag[tag] or 1) + 1
    else
        owner.kisaki_temp_tag[tag] = 1
        owner:AddTag(tag)
    end
end

--移除临时标签
function RemoveMedalTag(owner, tag)
    if owner.kisaki_temp_tag and owner.kisaki_temp_tag[tag] then
        owner.kisaki_temp_tag[tag] = owner.kisaki_temp_tag[tag] > 1 and owner.kisaki_temp_tag[tag] - 1 or nil
        if owner.kisaki_temp_tag[tag] == nil then
            owner:RemoveTag(tag)
        end
    else
        owner:RemoveTag(tag)
    end
end

--是否是临时组件
function IsMedalTempCom(owner, com)
    return com ~= nil and owner.kisaki_temp_com_table and owner.kisaki_temp_com_table[com]
end

--添加临时组件
function AddMedalComponent(owner, com)
    owner.medal_com = owner.medal_com or {}
    --添加组件时进行计数,防止由于勋章、装备的穿脱导致角色身上原本拥有的组件被移除掉
    if owner.components[com] then
        owner.kisaki_temp_com[com] = (owner.kisaki_temp_com[com] or 1) + 1
    else
        owner.kisaki_temp_com[com] = 1
        owner:AddComponent(com)
        --临时组件组
        owner.kisaki_temp_com_table = owner.kisaki_temp_com_table or {}
        owner.kisaki_temp_com_table[com] = true
    end
end

--移除临时组件
function RemoveMedalComponent(owner, com)
    if owner.kisaki_temp_com and owner.kisaki_temp_com[com] then
        owner.kisaki_temp_com[com] = owner.kisaki_temp_com[com] > 1 and owner.kisaki_temp_com[com] - 1 or nil
        if owner.kisaki_temp_com[com] == nil then
            owner:RemoveComponent(com)
            if IsMedalTempCom(owner, com) then
                owner.kisaki_temp_com_table[com] = nil
            end
        end
    else
        owner:RemoveComponent(com)
    end
end
