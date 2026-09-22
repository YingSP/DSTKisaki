----------------------------------------------------------------------------CLASS-----------------------------------------------------------------------------

--[[[组件] kisaki_world_data —— 世界侧共享数据仓库
[位置] world 实体（仅服务端），hook.lua 的 AddPrefabPostInit("world") 挂载
[开关] TUNING.KISAKI_CONTAINER_LEVEL_SHARE，false 则不挂载，容器各自记录
[数据] self.datas[数据类型][键] = 值
       box_level[容器名][升级项] = 进度    如 box_level.kisaki_magic_box.fresh = 5
[接口] 通用层   SetData / GetData / GetDataValue         直接覆盖，不取高
       容器层   Set/Get/Merge/SyncContainerLevel        一律取高（单调增）
[关联] kisaki_boxes.lua          魔法盒/图书馆，读写进度（4 个合并时机见该文件头）
       containers.lua            魔法盒升级按钮 magicboxupgrade
       hook.lua                 OnKisakiContainerLevelChanged 监听刷新
       rpc.lua                  container_level_sync 分片同步
[tuning] KISAKI_CONTAINER_LEVEL_SHARE / _SYNC / _BOXES

[设计-取高] 容器升级进度天然单调增（吃材料累加，只解锁不回退），所以一律取高。
            取高让推送/合并幂等且可交换 → 不需要版本号、时间戳、主从仲裁；
            重复收到同一份、乱序到达、两分片同时升级都不会错，且必然收敛。
            这也是"断线期间升的级能靠容器带过去"的前提。

[设计-广播] SetContainerLevel 有提升时自动 OnContainerLevelChanged → 推
            kisaki_container_level_changed 事件（本世界刷新全部容器）+ 推其他分片。
            没提升直接 return false 不广播，事件链必然终止（防循环的关键）。

[设计-跨分片] 在线时靠 RPC 实时推；对面不在线时游戏静默丢弃，不影响正确性。
              正确性靠容器自己携带：跨世界时容器在目标分片重新 spawn → OnPreLoad
              注入数据 → SyncContainerLevel 双向取高，把容器带的高值写进目标世界。
]]
local WorldData = Class(function(self, inst)
    self.inst = inst
    self.datas = {
        box_level = {}, -- datas.box_level[容器名][升级项] = 进度
    }
end)

----------------------------------------------------------------------------GET/SET-----------------------------------------------------------------------------

-- [接口-通用] 读取某类数据的全部内容（逐层副本）
function WorldData:GetData(datatype)
    local t = self.datas[datatype]
    if t == nil then
        return nil
    end
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            local sub = {}
            for k2, v2 in pairs(v) do
                sub[k2] = v2
            end
            copy[k] = sub
        else
            copy[k] = v
        end
    end
    return copy
end

-- [接口-通用] 写入：直接覆盖不取高，供"当前值"这类可增可减的数据
function WorldData:SetData(datatype, key, value)
    if self.datas[datatype] == nil then
        self.datas[datatype] = {}
    end
    self.datas[datatype][key] = value
end

function WorldData:GetDataValue(datatype, key)
    local t = self.datas[datatype]
    return t ~= nil and t[key] or nil
end

----------------------------------------------------------------------------容器升级进度-----------------------------------------------------------------------------

-- [接口-容器] 读取某容器的整份进度（副本）
function WorldData:GetContainerLevels(boxname)
    local box = self.datas.box_level[boxname]
    if box == nil then
        return nil
    end
    local copy = {}
    for k, v in pairs(box) do
        copy[k] = v
    end
    return copy
end

function WorldData:GetContainerLevel(boxname, key)
    local box = self.datas.box_level[boxname]
    return box ~= nil and box[key] or 0
end

-- [接口-容器] 写入进度：取高；返回是否有提升。有提升自动广播（唯一广播入口）
function WorldData:SetContainerLevel(boxname, key, value)
    value = value or 0
    local box = self.datas.box_level[boxname]
    if box == nil then
        box = {}
        self.datas.box_level[boxname] = box
    end
    local old = box[key]
    if old ~= nil and old >= value then
        return false -- 没有提升：不广播、不刷容器，循环在此终止
    end
    box[key] = value
    self:OnContainerLevelChanged(boxname)
    return true
end

-- [接口-容器] 批量取高合并；返回是否有提升。用于分片同步、容器加载时合并
function WorldData:MergeContainerLevels(boxname, levels)
    if type(levels) ~= "table" then
        return false
    end
    local changed = false
    for key, value in pairs(levels) do
        if type(key) == "string" and type(value) == "number" then
            if self:SetContainerLevel(boxname, key, value) then -- 不能短路，每项都要合并
                changed = true
            end
        end
    end
    return changed
end

----------------------------------------------------------------------------常用方法-----------------------------------------------------------------------------

-- [广播] 有提升时：推 kisaki_container_level_changed 事件 + 推其他分片
-- [注意] 对面分片不在线时 SendModRPCToShard 会被游戏静默丢弃，不影响正确性
function WorldData:OnContainerLevelChanged(boxname)
    self.inst:PushEvent("kisaki_container_level_changed", { boxname = boxname })
    if TUNING.KISAKI_CONTAINER_LEVEL_SYNC then
        SendModRPCToShard(GetShardModRPC("kisaki", "container_level_sync"), nil,
            DataDumper(self:GetData("box_level"), nil, true))
    end
end

-- [接口-容器] 把世界进度合并进容器实体，双向取高
-- [注意] 必须双向：容器可能带着别处升的级迁移过来，单向投影会把高值抹掉
function WorldData:SyncContainerLevel(inst, boxname)
    if inst == nil or boxname == nil then
        return false
    end
    local changed = false
    local function mergeNum(key)
        local container_val = inst[key .. "num"] or 0
        local world_val = self:GetContainerLevel(boxname, key)
        inst[key .. "num"] = math.max(container_val, world_val)
        if container_val > world_val and self:SetContainerLevel(boxname, key, container_val) then
            changed = true
        end
    end
    if boxname == "kisaki_magic_box" then
        for i, data in ipairs(TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST) do
            inst[data.action .. "neednum"] = inst[data.action .. "neednum"] or data.neednum
            mergeNum(data.action)
        end
    elseif boxname == "kisaki_library_box" then
        for i, data in ipairs(TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST) do
            mergeNum(data.id)
        end
    end
    return changed
end

----------------------------------------------------------------------------加载时运行-----------------------------------------------------------------------------

-- [存档] 整张 datas 一起存读，新增数据类型不用改这里
function WorldData:OnSave()
    return
    {
        datas = self.datas,
    }
end

function WorldData:OnLoad(data)
    if not data then return end
    if data.datas ~= nil then
        self.datas = data.datas
    elseif data.box_level ~= nil then
        self.datas = { box_level = data.box_level } -- [兼容] 旧存档：box_level 在顶层
    else
        self.datas = {}
    end
    if self.datas.box_level == nil then -- [兜底] 补齐种类，避免读取处判空
        self.datas.box_level = {}
    end
end

return WorldData
