-- 人物MOD固定写法，导入角色基础模板，需要自定义什么就直接覆盖原有属性/方法
local MakePlayerCharacter = require("prefabs/player_common")

local easing = require("easing")

local avatar_name = "kisaki"
local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset('ANIM', 'anim/' .. avatar_name .. '.zip'),
    Asset('ANIM', 'anim/ghost_' .. avatar_name .. '_build.zip')
}

---------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 与人物相关的物品都需要在这里列出
local prefabs = {}
-- 初始物品，从配置项取值
local start_inv = TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.KISAKI
-- 下面的写法不生效，有点奇怪
-- for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
-- 	start_inv[string.lower(k)] = v.KISAKI
-- end
-- -- 固定写法
-- prefabs = FlattenTree({ prefabs, start_inv }, true)

---------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 这个函数将在服务器和客户端都会执行(一般用于添加小地图标签等动画文件或者需要主客机都执行的组件)
local common_postinit = function(inst)
    -- 固定先添加角色标签
    inst:AddTag(avatar_name)
    -- 角色可造书
    if TUNING.KISAKI_MAKEBOOK_ENABLE then inst:AddTag("bookbuilder") end
    -- 角色可读书
    if TUNING.KISAKI_READ_ENABLE then inst:AddTag("reader") end
    -- 不会吓跑小动物，会吓跑鸟（不会吓跑鸟但是不能直接捡起鸟是什么debuff）
    if TUNING.KISAKI_IS_FAMILIAR then inst:RemoveTag("scarytoprey") end
    -- 角色武器不脱手
    if TUNING.KISAKI_STRONGGER then inst:AddTag("stronggrip") end
    -- 角色闲置动画
    inst.AnimState:AddOverrideBuild("player_idles_wendy")
    -- 角色的地图图标
    inst.MiniMapEntity:SetIcon(avatar_name .. ".tex")
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 角色免疫启蒙光环
local function KisakiLunacyImmunityInit(inst)
    if TUNING.KISAKI_IMMUNITY_AURA_ENABLE then
        inst.components.sanity.sanity_aura_immunities = TUNING
            .KISAKI_IMMUNITY_AURA_TAG -- 定制光环抵抗，加入特定TAG抵抗特定光环
    end
end

-- 读书后如果san值处于崩溃则立即生成影怪
local SHADOWCREATURE_MUST_TAGS = { "shadowcreature", "_combat", "locomotor" }
local SHADOWCREATURE_CANT_TAGS = { "INLIMBO", "notaunt" }
local function OnKisakiReadFn(inst, book)
    if inst.components.sanity:IsInsane() then
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 16, SHADOWCREATURE_MUST_TAGS, SHADOWCREATURE_CANT_TAGS)
        if #ents < TUNING.BOOK_MAX_SHADOWCREATURES then
            TheWorld.components.shadowcreaturespawner:SpawnShadowCreature(inst)
        end
    end
end

-- 角色读书
local function KisakiReadInit(inst)
    if TUNING.KISAKI_READ_ENABLE then
        inst:AddComponent("reader")                        -- 人物可读书
        inst.components.reader:SetOnReadFn(OnKisakiReadFn) -- 读书后影怪骚扰
    end
end

-- 角色科技
local function KisakiBuildInit(inst)
    if TUNING.KISAKI_SCIENCE_UNLOCK then inst.components.builder.science_bonus = 1 end -- 人物自带科技一本
    if TUNING.KISAKI_MAGIC_UNLOCK then inst.components.builder.magic_bonus = 2 end     -- 人物自带魔法一本
end

-- 角色食物喜恶
local function KisakiFoodInit(inst)
    -- 只吃新鲜食物，不吃带怪物肉词条的食物
    if TUNING.KISAKI_IS_FOOD_HATE then
        local oldPrefersToEat = inst.components.eater.PrefersToEat
        inst.components.eater.PrefersToEat = function(self, food)
            -- 检查食物名字
            if food and food.prefab and TUNING.KISAKI_CANT_EAT_FOOD[food.prefab] then
                return false
            end
            -- 检查食物tag
            for i, v in ipairs(TUNING.KISAKI_CANT_EAT_TAGS) do
                if food and food:HasTag(v) then
                    return false
                end
            end
            -- 检查原版逻辑
            return oldPrefersToEat(self, food)
        end
    end
    -- 吃好东西类食物特殊加成，也可以拿来做debuff，比如吃东西不回血
    if TUNING.KISAKI_IS_FOOD_LIKE then
        inst.components.eater.custom_stats_mod_fn = function(inst, health_delta, hunger_delta, sanity_delta, food, feeder)
            local LIKE_FOOD_TYPE = { FOODTYPE.GOODIES }
            for i, v in ipairs(LIKE_FOOD_TYPE) do
                if food and food:HasTag("edible_" .. v) then
                    health_delta = math.min((health_delta or 0) * 1.3, (health_delta or 0) + 15)
                    hunger_delta = math.min((hunger_delta or 0) * 1.3, (hunger_delta or 0) + 15)
                    sanity_delta = math.min((sanity_delta or 0) * 1.3, (sanity_delta or 0) + 15)
                end
            end
            return health_delta, hunger_delta, sanity_delta
        end
    end
end

-- 角色抗荆棘
local function KisakiPlantAffinityInit(inst)
    if TUNING.KISAKI_BRAMBLE_RESISTANT then
        -- local范围内修改判断装备栏tag的方法，默认给角色穿上荆棘甲
        local oldEquipHasTag = inst.components.inventory.EquipHasTag
        local moretag = {
            bramble_resistant = true
        }
        inst.components.inventory.EquipHasTag = function(self, tag)
            return moretag[tag] or oldEquipHasTag(self, tag)
        end
    end
end

-- 角色抗诅咒
local function KisakiNeverMonkey(inst)
    -- 修改诅咒组件，阻止变猴
    inst.components.cursable.ApplyCurse = function(self, item, curse, ...)
        -- 诅咒饰品放入角色容器时会执行
        if TUNING.KISAKI_DELETE_CURSE and item and TUNING.CURSELIST[item.prefab] then
            -- 如果可堆叠
            if item.components.stackable then
                -- 延时0.5S删掉，不然会没法统计到刚进入背包的诅咒物
                inst:DoTaskInTime(0.5, function()
                    -- self.inst.components.talker:Say("我被诅咒了，诅咒物是" .. item.prefab)
                    self.inst.components.inventory:ConsumeByName(item.prefab, item.components.stackable:StackSize())
                end)
            else
                inst:DoTaskInTime(0.5, function()
                    self.inst.components.inventory:ConsumeByName(item.prefab)
                end)
            end
        end
    end
    -- 删除诅咒的方法不需要实现
    inst.components.cursable.RemoveCurse = function()
    end
    -- 角色永远不能被诅咒，正常只实现这个就够
    inst.components.cursable.IsCursable = function()
        return false
    end
end

-- 角色SAN光环
local function KisakiSanityaura(inst)
    if TUNING.KISAKI_SANITYAURA then
        inst:AddComponent("sanityaura") --SAN光环组件
        inst.components.sanityaura.aurafn = function() return 1 / 12 end
    end
end

-- 角色快速制作
local function KisakiFastBuild(inst)
    if TUNING.KISAKI_FSAT_BUILD then
        -- 原版女工快速制作+暴食模式下快速工作
        inst:AddTag("quagmire_fasthands")
        inst:AddTag("fastbuilder")
    end
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 刷新角色移速
local function refreshKisakiSpeed(inst)
    if inst.components.locomotor then
        local kisaki_speed = inst:HasTag('playerghost')
            and
            (TUNING.KISAKI_GOST_FAST and TUNING.KISAKI_GOST_MOVE_SPEED or TUNING.KISAKI_MOVE_SPEED)
            or
            (TUNING.KISAKI_HEALTH_PUNISHMENT and
                TUNING.KISAKI_MOVE_SPEED * easing.inSine(inst.components.health:GetPercent(), 0.5, 1, 1) or
                TUNING.KISAKI_MOVE_SPEED)
        inst.components.locomotor:SetExternalSpeedMultiplier(inst, "kisaki", kisaki_speed)
        -- inst.components.talker:Say("我的速度调整了，当前为" .. kisaki_speed)
    end
end

-- 刷新角色勇敢值（低理智状态下更害怕怪物）
local function refreshKisakiCourage(inst)
    if inst.components.sanity and not inst:HasTag('playerghost') then
        local kisaki_sanity_percent = inst.components.sanity:GetPercent()
        local kisaki_neg_aura_mult_add = 8
        -- 判断理智值状态，不同模式有不同的判断
        if inst.components.sanity.mode == 0 then -- SAN值模式，SANITY_MODE_INSANITY
            if not TUNING.KISAKI_SANITY_PUNISHMENT or kisaki_sanity_percent > 0.5 then
                kisaki_neg_aura_mult_add = 0
            elseif kisaki_sanity_percent > 0.3 then
                kisaki_neg_aura_mult_add = 1
            elseif kisaki_sanity_percent > 0.15 then
                kisaki_neg_aura_mult_add = 2
            elseif kisaki_sanity_percent > 0.1 then
                kisaki_neg_aura_mult_add = 4
            end
        else -- 启蒙模式，SANITY_MODE_LUNACY
            if not TUNING.KISAKI_SANITY_PUNISHMENT or kisaki_sanity_percent < 0.5 then
                kisaki_neg_aura_mult_add = 0
            elseif kisaki_sanity_percent < 0.7 then
                kisaki_neg_aura_mult_add = 1
            elseif kisaki_sanity_percent < 0.85 then
                kisaki_neg_aura_mult_add = 2
            elseif kisaki_sanity_percent < 0.9 then
                kisaki_neg_aura_mult_add = 4
            end
        end
        inst.components.sanity.neg_aura_mult = TUNING.KISAKI_MONSTER_SANITY_MULT + kisaki_neg_aura_mult_add
    end
end

-- 角色复活
local function onbecamehuman(inst)
    -- 角色复活后重设速度
    inst:DoTaskInTime(0.1, refreshKisakiSpeed)
end

-- 角色死亡
local function onbecameghost(inst)
    if TUNING.KISAKI_GOST_FAST then
        inst:DoTaskInTime(0.1, refreshKisakiSpeed)
    end
    -- 在角色死亡地点生成物品，延时生成对上动画，监听ms_becameghost上下洞穴重新进游戏会重新生成
    if TUNING.KISAKI_DEAD_SPAWN_PROP then
        inst:DoTaskInTime(2, function()
            local x, y, z = inst.Transform:GetWorldPosition()
            local prefab = SpawnPrefab("amulet") -- 复活道具还没做，TODO
            if prefab ~= nil then
                prefab.Transform:SetPosition(x, y, z)
            end
        end)
    end
end

-- 角色加载
local function OnKisakiLoad(inst)
    -- 刷新下速度
    refreshKisakiSpeed(inst)
end

-- 角色通过绚丽之门进入世界
local function OnKisakiNewSpawn(inst)
    OnKisakiLoad(inst)
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 这里的的函数只在主机执行(一般组件之类的都写在这里)
local master_postinit = function(inst)
    -- 人物音效
    inst.soundsname = "wendy"
    -- 人物闲置时动作（温蒂）
    inst.customidleanim = "idle_wendy"
    -- 人物死亡动画（旺达）
    -- inst.deathanimoverride = "death_wanda"

    -- 三维相关
    inst.components.health:SetMaxHealth(TUNING.KISAKI_HEALTH)
    inst.components.health.fire_damage_scale = TUNING
        .KISAKI_FIRE_DAMAGE                                                                                         -- 人物受到火焰伤害更高，默认角色为1
    inst.components.health.externalabsorbmodifiers:SetModifier(inst, TUNING.KISAKI_DAMAGE_REDUCTION_RATE, "kisaki") -- 人物自带防御系数，默认0
    inst.components.hunger:SetMax(TUNING.KISAKI_HUNGER)
    inst.components.hunger:SetRate(TUNING.WILSON_HUNGER_RATE * TUNING.KISAKI_HUNGER_RATE)                           -- 饥饿速度，默认一天75
    inst.components.hunger:SetKillRate(TUNING.KISAKI_HEALTH / TUNING.STARVE_KILL_TIME)                              -- 饥饿归零后掉血速率，角色血上限较少时最好设置下，默认为1
    inst.components.sanity:SetMax(TUNING.KISAKI_SANITY)
    inst.components.sanity.neg_aura_mult = TUNING
        .KISAKI_MONSTER_SANITY_MULT -- 减SAN光环对角色SAN值的影响系数，默认1
    inst.components.sanity.night_drain_mult = TUNING
        .KISAKI_NIGHT_SANITY_MULT   -- 夜晚对角色SAN值的影响系数，默认1
    KisakiLunacyImmunityInit(inst)  -- 角色免疫启蒙光环


    -- 伤害倍率
    inst.components.combat.damagemultiplier = TUNING.KISAKI_DAMANGE_MULTIPLIER
    -- 移动速度
    -- inst.components.locomotor.walkspeed = TUNING.KISAKI_WALK_SPEED -- 4 is base
    -- inst.components.locomotor.runspeed = TUNING.KISAKI_RUN_SPEED -- 6 is base
    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "kisaki", TUNING.KISAKI_MOVE_SPEED)
    -- 攻击相关
    inst.components.combat.attackrange = TUNING.KISAKI_HIT_RANGE -- 攻击范围，默认是2
    inst.components.combat.hitrange = TUNING.KISAKI_HIT_RANGE    -- 攻击可以打到的范围，默认是2

    -- 特殊能力
    KisakiReadInit(inst)          -- 角色读书能力
    KisakiBuildInit(inst)         -- 角色科技初始解锁
    KisakiFoodInit(inst)          -- 角色食物喜恶
    KisakiPlantAffinityInit(inst) -- 角色抗荆棘能力
    KisakiNeverMonkey(inst)       -- 角色抵抗诅咒饰品，不设开关
    KisakiSanityaura(inst)        -- 角色拥有一个每分钟回40点的回san光环（加了个原版怪物才有的组件）
    KisakiFastBuild(inst)         -- 角色快采集

    -- 监听各种事件
    inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman) -- 监听角色复活
    inst:ListenForEvent("death", onbecameghost)        -- 监听角色死亡
    inst:ListenForEvent("healthdelta", refreshKisakiSpeed)      -- 监听角色血量变化
    inst:ListenForEvent("sanitydelta", refreshKisakiCourage)    -- 监听角色理智值变化
    inst.skeleton_prefab = nil                                  -- 角色死亡无骨架，掉落其他物品

    -- 角色特殊内容
    inst:AddComponent("kisaki_sanity") -- 角色魔法值

    -- 角色上下洞穴，结束游戏后重新进入游戏
    inst.OnLoad = OnKisakiLoad
    -- 绚丽之门进入世界
    inst.OnNewSpawn = OnKisakiNewSpawn
end
---------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 选人界面人物皮肤，参考SORA代码
local function MakeKISAKISkin(name, data, free)
    -- 赋予皮肤默认值
    local d = {}
    d.rarity = '经典' -- 珍惜度 官方不存在的珍惜度则直接覆盖字符串
    d.rarityorder = 90 -- 珍惜度的排序 用于按优先级排序 基本没啥用
    d.raritycorlor = { 102 / 255, 0 / 255, 204 / 255, 1 } -- {R,G,B,A}
    d.release_group = -1009 -- 皮肤的发布组，随便搞个数字
    d.skin_tags = { 'BASE', avatar_name, 'CHARACTER' } -- 皮肤标签
    d.skins = { -- 皮肤动画资源，assets加载后定义
        normal_skin = name,
        ghost_skin = 'ghost_' .. avatar_name .. '_build'
    }
    d.share_bigportrait_name = avatar_name .. '_none' -- 选人界面角色名图片名
    d.FrameSymbol = 'Reward'                          -- 选人图标边框
    -- 隐藏皮肤定义
    if not free then
        -- 检查本地缓存内数据
        d.checkfn = KISAKI_API.KISAKISkinCheckFn             -- TODO，未实现
        -- 调用服务器数据
        d.checkclientfn = KISAKI_API.KISAKISkinCheckClientFn -- TODO，未实现
    end
    -- data内数据覆盖初始值，或新增值
    for k, v in pairs(data) do
        d[k] = v
    end
    -- 创建人物皮肤
    KISAKI_API.MakeCharacterSkin(avatar_name, name, d)
end
-- 不准备做隐藏皮肤，方法暂时留着
function MakeKISAKIFreeSkin(name, data)
    MakeKISAKISkin(name, data, true)
end

-- 默认皮肤
MakeKISAKIFreeSkin(avatar_name .. '_none', {
    name = "渴望平凡的少女", -- 皮肤的名称
    des = "*拥有将书籍内容变为现实的魔力\n*超凡的智慧", -- 皮肤界面的描述
    quotes = "\"向神发誓，我赌上一生来爱你！\"", -- 选人界面的描述
    skins = { normal_skin = avatar_name, "ghost_" .. avatar_name .. "_build" },
    build_name_override = avatar_name
})
---------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 创建人物预制物
return MakePlayerCharacter(avatar_name, prefabs, assets, common_postinit, master_postinit, start_inv)
