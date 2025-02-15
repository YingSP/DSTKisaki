-- 设计
-- 正常生存活过第一周可升级至25级，进入冬季可升级至50级，春季结束可升级至75级，再次活过冬季可满级
-- 刷经验情况下70天满级
-- 先按以下流程设计经验等级，设个每日经验上限防止刷经验：
-- 正常游玩前7天探图+做移植准备工作+部分建造
-- 7到20天如果下地探图+找远古拿到经验不考虑，正常很低（击杀很麻烦，只能探图和偷东西），如果在家收集材料建家种地
-- 冬天没什么事干，正常会在家发育+种地，有几个BOSS可以打一下
-- 春季角色有几件专属装备后可安稳度过且有自保击杀能力，着手准备暗影线和月亮线，击杀几个BOSS找月岛，
-- 夏季下远古清理暗影线，清理档案馆
-- 第二个秋季和冬季完成清理天体线，击杀月亮系三BOSS，家里完善下，建工厂刷下剩余边角料

local log = require("utils/kisakilogger")

-- lua的表index从1开始
local experience_table = {
    20, 40, 60, 80, 100,
    130, 160, 190, 220, 250,
    290, 330, 370, 410, 450,
    500, 550, 600, 650, 700,
    750, 800, 2147483647
}
local experience_table_total = {}
local KISAKI_LEVEL_MAX = 110
local KISAKI_DEATH_EXP_LOSS = 0.1
local KISAKI_EXP_PRE_DAY_MAX = {
    ["UNDERSTAND_ONESELF"] = 400,
    ["GAZING_AT_STARDUST"] = 600,
    ["KNOW_THE_MANDATE_OF_HEAVEN"] = 800,
    ["ACT_AGAINST_THE_MANDATE_OF_HEAVEN"] = 1000,
    ["THE_PATH_TO_DEIFICATION"] = 1200,
}
-- 小动物列表
local tiny_animal = {
    bee = 1,                 -- 蜜蜂
    killerbee = 1,           -- 杀人蜂
    daywalker = 1,           -- 梦魇猪
    birchnutdrake = 1,       -- 小桦树精
    tentacle_pillar_arm = 1, -- 小触手
    lureplant = 1,           -- 食人花
    eyeplant = 1,            -- 眼球草
    crow = 1,                -- 乌鸦
    robin = 1,               -- 红鸟
    robin_winter = 1,        -- 雪鸟
    canary = 1,              -- 金丝雀
    puffin = 1,              -- 海鸟
    bird_mutant_spitter = 1, -- 畸形鸟
    bird_mutant = 1,         -- 月盲乌鸦

}
-- BOSS列表（这里都击杀一遍且连体BOSS不隔天大概有10000经验）
local boss = {
    leif = 50,                   -- 树精
    leif_sparse = 50,            -- 粗壮树精
    spiderqueen = 50,            -- 蜘蛛女王
    lordfruitfly = 50,           -- 果蝇王
    worm_boss = 100,             -- 洞穴大蠕虫
    eyeofterror = 100,           -- 恐怖之眼
    malbatross = 100,            -- 邪天翁
    moose = 100,                 -- 大鹅
    bearger = 200,               -- 熊大
    deerclops = 200,             -- 巨鹿
    antlion = 200,               -- 蚁狮
    minotaur = 400,              -- 犀牛
    sharkboi = 300,              -- 大霜鲨
    crabking = 400,              -- 帝王蟹
    daywalker = 400,             -- 梦魇疯猪
    daywalker2 = 400,            -- 拾荒疯猪
    twinofterror1 = 600,         -- 激光眼
    twinofterror2 = 600,         -- 魔焰眼
    klaus = 600,                 -- 克劳斯
    dragonfly = 600,             -- 龙蝇
    beequeen = 600,              -- 蜂王
    toadstool = 600,             -- 毒菌蟾蜍
    toadstool_dark = 1000,       -- 悲惨毒菌蟾蜍
    shadow_knight = 600,         -- 暗影骑士
    shadow_bishop = 600,         -- 暗影主教
    shadow_rook = 600,           -- 暗影战车
    stalker_forest = 1,          -- 森林守护者
    stalker = 1,                 -- 地下守护者
    stalker_atrium = 1000,       -- 织影者
    alterguardian_phase1 = 1000, -- 天体英雄一阶段
    alterguardian_phase2 = 1000, -- 天体英雄二阶段
    alterguardian_phase3 = 1000, -- 天体英雄三阶段
    mutateddeerclops = 300,      -- 晶体巨鹿
    mutatedbearger = 300,        -- 装甲熊獾
    mutatedwarg = 100,           -- 附身座狼

}

-------------------------------------------------------------------------初始化数据----------------------------------------------------------------------------

local function init()
    table.insert(experience_table_total, 1)
    for i = 2, 110 do
        table.insert(experience_table_total, experience_table_total[i - 1] + experience_table[math.ceil(i / 5)])
    end
end

----------------------------------------------------------------------------监听-------------------------------------------------------------------------------

local function oncurrent(self, current)
    self.inst.replica.kisaki_level:SetCurrent(current)
end

local function oncurrent_exp(self, current_exp)
    self.inst.replica.kisaki_level:SetCurrentExp(current_exp)
end

local function oncurrent_exp_total(self, current_exp_total)
    self.inst.replica.kisaki_level:SetCurrentExpTotal(current_exp_total)
end

local function oncurrent_today_exp(self, current_today_exp)
    self.inst.replica.kisaki_level:SetCurrentTodayExp(current_today_exp)
end

local function onlevelup_need_exp(self, levelup_need_exp)
    self.inst.replica.kisaki_level:SetLevelUpNeedExp(levelup_need_exp)
end

local function onexp_pre_day_max(self, current)
    self.inst.replica.kisaki_level:SetExpPreDayMax(current)
end

local function onis_today_kill_boss(self, current)
    self.inst.replica.kisaki_level:SetIsTodayKillBoss(current)
end

local function onis_death_punishment(self, current)
    self.inst.replica.kisaki_level:SetIsDeathPunishment(current)
end

-- 新一天重置经验获取限制
local function onnewday(inst)
    local kisaki_level = inst.components.kisaki_level
    if kisaki_level then
        log.declare("角色过夜，等级模块刷新，昨日信息为：\r\n" .. kisaki_level:GetDebugString(), inst.userid)
        kisaki_level.current_today_exp = 0
        kisaki_level.is_today_kill_boss = false
    end
end

-- 角色脱装备刷新
local function onunequip(inst)
    local kisaki_level = inst.components.kisaki_level
    if kisaki_level then
        log.info("角色脱下装备，刷新角色等级模块")
        kisaki_level:Refresh()
    end
end

-- 角色复活时刷新
local function onbecamehuman(inst)
    local kisaki_level = inst.components.kisaki_level
    if kisaki_level then
        log.info("角色死亡复活，刷新角色等级模块")
        kisaki_level:Refresh()
    end
end

-- 角色角色如果死亡，则扣除当前经验值的10%
local function onbecameghost(inst)
    local kisaki_level = inst.components.kisaki_level
    if kisaki_level and kisaki_level.is_death_punishment then
        -- 角色死亡一秒后一般还在播放动画，没什么任务
        inst:DoTaskInTime(1, function()
            log.info("角色死亡，扣除角色当前经验值")
            kisaki_level:SetCurrentExpTotal(kisaki_level:GetCurrentExpTotal() * (1 - KISAKI_DEATH_EXP_LOSS))
            kisaki_level:Refresh()
        end)
    end
end

-- 角色不处于闲置状态就加经验(一天80，算是保底)
local function checkCharacterSG(inst)
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    if not inst.sg:HasStateTag("idle") then
        log.debug("角色不处于闲置状态，增加经验")
        inst.components.kisaki_level:DoDelta(0.15, false)
    end
end

-- 角色陆地钓鱼时（按一条10S算，钓鱼一整天有480经验）
local function onfishingcatch(inst, data)
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    if inst.components.kisaki_level.current >= 50 then return end                     -- 50级后出快速钓鱼工具
    log.info("角色陆地钓鱼，获得经验值")
    inst.components.kisaki_level:DoDelta(10, false)
end

-- 角色海上钓鱼时（按一条45S算，钓鱼一整天有640经验）
local function onfishcaught(inst, data)
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    if inst.components.kisaki_level.current >= 50 then return end                     -- 50级后出采集工具
    log.info("角色海上钓鱼，获得经验值")
    inst.components.kisaki_level:DoDelta(60, false)
end

-- 监听角色工作
local function onfinishedwork(inst, data)
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    if inst.components.kisaki_level.current >= 50 then return end                     -- 50级后这角色也不用手动干这些事了
    if data.target and data.target.components.workable then
        -- 按吴迪一天2400次算，砍树一整天有600经验
        if data.target.components.workable.action == ACTIONS.CHOP then
            log.info("角色砍树，获得经验值")
            inst.components.kisaki_level:DoDelta(0.25, false)
        end
        -- 按一天1000次算，挖矿一整天有600经验
        if data.target.components.workable.action == ACTIONS.MINE then
            log.info("角色挖矿，获得经验值")
            inst.components.kisaki_level:DoDelta(0.6, false)
        end
        -- 按女工一天600次算，挖一天有600经验
        if data.target.components.workable.action == ACTIONS.DIG then
            log.info("角色挖东西，获得经验值")
            inst.components.kisaki_level:DoDelta(1, false)
        end
        -- 按一天300次算，抓一天有600经验
        if data.target.components.workable.action == ACTIONS.NET then
            log.info("角色捕虫，获得经验值")
            inst.components.kisaki_level:DoDelta(2, false)
        end
    end
end

-- 角色采集时（角色有快采，按1秒2次算，采集一整天576经验）
local function onpick(inst, data)
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    -- 采摘的是农场作物(按一天收获600个算)
    if data.object and data.object:HasTag("farm_plant") then
        log.info("角色农场收获，获得经验值")
        inst.components.kisaki_level:DoDelta(1, false)            -- 农场获取经验先不做限制，反正有经验锁
    end
    if inst.components.kisaki_level.current >= 50 then return end -- 50级后出采集工具，采集普通物品不再获得经验
    log.info("角色采摘，获得经验值")
    inst.components.kisaki_level:DoDelta(0.6, false)
end

-- 角色制作可放入背包物品（女工加速制作按1秒2次算，制作一整天576经验）
local function onmake(inst, data)
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    log.info("角色制作小东西，获得经验值")
    inst.components.kisaki_level:DoDelta(0.6, false)
end

-- 角色制作建筑时（按一天造64个算，制作一整天640经验）
local function onbuild(inst, data)
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    log.info("角色制造建筑，获得经验值")
    inst.components.kisaki_level:DoDelta(10, false)
end

-- 角色烹饪时（装个自动做饭mod一天可以造200顿饭，做饭一整天600经验）
local function oncook(inst, data)
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    log.info("角色收获烹饪锅，获得经验值")
    inst.components.kisaki_level:DoDelta(3, false)
end

-- 角色种植（用排队论一天能种800次，种一整天可以获得600经验）
local function ondeployitem(inst, data)
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    log.info("角色种植，获得经验值")
    inst.components.kisaki_level:DoDelta(0.75, false)
end

-- 角色读书（一天读60次都算多的了）
local function onread(inst, data)
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    log.info("角色读书，获得经验值")
    inst.components.kisaki_level:DoDelta(10, false)
end

-- 周围有生物死亡时，角色可获得经验
local function onentitydeath(inst, data)
    log.info("触发角色等级模块内的生物死亡监听")
    if inst:HasTag('playerghost') or not inst.components.kisaki_level then return end -- 角色死亡停止
    if data and data.inst and data.afflicter then
        local the_dead = data.inst                                                    -- 被杀死的对象
        local the_afflicter = data.afflicter                                          -- 造成击杀的事物
        -- 对象必须是被玩家击杀且对象不是玩家，对象死亡时需要在玩家6格地皮以内
        if not the_dead:HasTag("player") and the_afflicter:HasTag("player")
            and not (the_dead.components.kisaki_kill_info and the_dead.components.kisaki_kill_info:GetKiller("kisaki_level" .. inst.userid))
            and the_dead.prefab and the_dead.IsNear and the_dead:IsNear(inst, 24) then
            -- 先判断BOSS
            if the_dead:HasTag("epic") then
                log.info("角色杀死BOSS，获得经验值")
                local val = boss[the_dead.prefab] and boss[the_dead.prefab] or 50
                inst.components.kisaki_level:DoDelta(val, true)
            end
            -- 再计算遍，不能杀了boss没经验
            if the_dead.components.health and the_dead.components.health:GetMaxWithPenalty() > 50 and not tiny_animal[the_dead.prefab] then
                -- 一些小动物没经验
                log.info("角色击杀生物，获得经验值")
                inst.components.kisaki_level:DoDelta(the_dead.components.health:GetMaxWithPenalty() * 0.02, false)
            end
            -- 防止鞭尸
            if not the_dead.components.kisaki_kill_info then
                the_dead:AddComponent("kisaki_kill_info")
            end
            the_dead.components.kisaki_kill_info:SetKiller("kisaki_level" .. inst.userid)
            -- log.debug("击杀的怪物是否有定义的信息：" .. (the_dead.components.kisaki_kill_info:GetKiller("kisaki_level" .. inst.userid) and "true" or "false"))
        end
    end
end

----------------------------------------------------------------------------CLASS-----------------------------------------------------------------------------

local Level = Class(function(self, inst)
    self.inst = inst                                                                       -- 角色
    self.current = 0                                                                       -- 当前等级，初始0
    self.current_exp_total = 0                                                             -- 角色总经验值，用于实现扣除总经验的情况
    self.current_exp = 0                                                                   -- 角色当前经验值
    self.levelup_need_exp = 1                                                              -- 角色当前升级需要的经验
    self.current_today_exp = 0                                                             -- 角色当天获取了多少经验，用于实现经验锁
    self.exp_pre_day_max = 300                                                             -- 角色每天可获得的经验上限
    self.is_today_kill_boss = false                                                        -- 今天是否击杀过BOSS级别生物，用于实现单日首次击杀boss额外获得经验
    self.is_death_punishment = true                                                        -- 是否有死亡惩罚

    init()                                                                                 -- 初始化等级数据

    inst:DoPeriodicTask(0.9, function() checkCharacterSG(inst) end, 10)                    -- 每0.9s监听下角色的SG状态
    inst:ListenForEvent("fishingcollect", onfishingcatch)                                  -- 监听陆地钓鱼
    inst:ListenForEvent("fishcaught", onfishcaught)                                        -- 监听海上钓鱼
    inst:ListenForEvent("working", onfinishedwork)                                         -- 监听工作，劈砍挖捕虫
    inst:ListenForEvent("builditem", onmake)                                               -- 监听制作可放入背包物品
    inst:ListenForEvent("buildstructure", onbuild)                                         -- 监听建造建筑
    inst:ListenForEvent("deployitem", ondeployitem)                                        -- 种植
    inst:ListenForEvent("picksomething", onpick)                                           -- 监听采集
    inst:ListenForEvent("kisaki_cook", oncook)                                             -- 监听烹饪
    inst:ListenForEvent("kisaki_read", onread)                                             -- 监听读书

    inst.kisakiLevelListenEnityDeath = function(world, data) onentitydeath(inst, data) end -- 定义角色方法
    inst:ListenForEvent("entity_death", inst.kisakiLevelListenEnityDeath, TheWorld)        -- 监听周围生物死亡

    inst:ListenForEvent("death", onbecameghost)                                            -- 监听角色死亡

    inst:WatchWorldState("cycles", onnewday)                                               -- 监听新一天到来
    inst:ListenForEvent("unequip", onunequip)                                              -- 卸下装备时刷新角色状态(频率低，问题不大)
    inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman)                            -- 角色复活时刷新角色状态(频率低，问题不大)
end, nil, {
    -- 监听数据变化，影响显示的需要同步到客户端
    current = oncurrent,
    current_exp = oncurrent_exp,
    -- current_exp_total = oncurrent_exp_total,
    -- current_today_exp = oncurrent_today_exp,
    levelup_need_exp = onlevelup_need_exp,
    -- exp_pre_day_max = onexp_pre_day_max,
    -- is_today_kill_boss = onis_today_kill_boss,
    -- is_death_punishment = onis_death_punishment,
})

----------------------------------------------------------------------------GET/SET----------------------------------------------------------------------------

function Level:SetCurrent(amount)
    amount = math.min(math.max(0, amount), KISAKI_LEVEL_MAX)
    self.current_exp_total = amount == 0 and 0 or experience_table_total[amount]
    self:Refresh()
end

function Level:SetCurrentExp(amount) self.current_exp = math.max(0, amount) end

function Level:SetLevelUpNeedExp(amount) self.levelup_need_exp = math.max(0, amount) end

function Level:SetCurrentExpTotal(amount) self.current_exp_total = math.max(0, amount) end

function Level:SetCurrentTodayExp(amount) self.current_today_exp = math.max(0, amount) end

function Level:SetExpPreDayMax(amount) self.exp_pre_day_max = math.max(0, amount) end

function Level:SetIsTodayKillBoss(amount) self.is_today_kill_boss = amount end

function Level:SetIsDeathPunishment(amount) self.is_death_punishment = amount end

function Level:GetCurrent() return self.current end

function Level:GetCurrentExp() return self.current_exp end

function Level:GetLevelupNeedExp() return self.levelup_need_exp end

function Level:GetCurrentExpTotal() return self.current_exp_total end

function Level:GetCurrentTodayExp() return self.current_today_exp end

function Level:GetExpPreDayMax() return self.exp_pre_day_max end

function Level:GetIsTodayKillBoss() return self.is_today_kill_boss end

function Level:GetIsDeathPunishment() return self.is_death_punishment end

function Level:GetDebugString()
    local format = "======================================================================================\r\n"
    format = format .. "当前玩家：%s\r\n"
    format = format .. "等级状态（当前值/最大值）：%2.2f/%2.2f\r\n"
    format = format .. "经验状态（当前等级经验/升级需要经验/当前总经验）：%2.2f/%2.2f/%2.2f\r\n"
    format = format .. "今日经验状态（今日已获取经验/每日最高可获取经验）：%2.2f/%2.2f\r\n"
    format = format .. "其他（今日是否击杀过BOSS/角色死亡是否有惩罚）：%s/%s\r\n"
    format = format .. "======================================================================================"
    local info = string.format(format, self.inst.name, self.current, KISAKI_LEVEL_MAX, self.current_exp,
        self.levelup_need_exp, self.current_exp_total, self.current_today_exp, self.exp_pre_day_max,
        self.is_today_kill_boss and "是" or "否", self.is_death_punishment and "是" or "否")
    return info
end

function Level:GetState()
    return self.current <= 25 and "UNDERSTAND_ONESELF" or (
        self.current <= 50 and "GAZING_AT_STARDUST" or (
            self.current <= 75 and "KNOW_THE_MANDATE_OF_HEAVEN" or (
                self.current <= 100 and "ACT_AGAINST_THE_MANDATE_OF_HEAVEN" or "THE_PATH_TO_DEIFICATION"
            )))
end

function Level:GetPercent()
    return self.current_exp / self.levelup_need_exp
end

------------------------------------------------------------------------------常用方法---------------------------------------------------------------------------

-- 升/降级刷新三维上限
local function onKisakiLevelUp(inst)
    log.info("执行了等级组件内部刷新升级带来增益的方法")
    local kisaki_level = inst.components.kisaki_level
    if kisaki_level then
        -- 获取等级
        local level = kisaki_level.current
        -- 获取原先三维的百分比
        local hunger_percent = inst.components.hunger:GetPercent()
        local health_percent = inst.components.health:GetPercent()
        local sanity_percent = inst.components.sanity:GetPercent()
        if health_percent <= 0 then
            return
        end
        -- 设置三维上限
        inst.components.health:SetMaxHealth(TUNING.KISAKI_HEALTH + level * TUNING.KISAKI_HEALTH_UP)
        inst.components.hunger:SetMax(TUNING.KISAKI_HUNGER + level * TUNING.KISAKI_HUNGER_UP)
        inst.components.sanity:SetMax(TUNING.KISAKI_SANITY + level * TUNING.KISAKI_SANITY_UP)
        -- 设置三维百分比
        inst.components.hunger:SetPercent(hunger_percent)
        inst.components.health:SetPercent(health_percent)
        inst.components.sanity:SetPercent(sanity_percent)
        -- 防御系数
        inst.components.health.externalabsorbmodifiers:SetModifier(inst,
            TUNING.KISAKI_DAMAGE_REDUCTION_RATE + level * TUNING.KISAKI_DAMAGE_REDUCTION_RATE_UP, "kisaki")
        -- 攻击倍率
        inst.components.combat.damagemultiplier = TUNING.KISAKI_DAMANGE_MULTIPLIER +
            level * TUNING.KISAKI_DAMANGE_MULTIPLIER_UP
        -- 如果角色有魔力，再刷新魔力值
        if inst.components.kisaki_magic then
            local kisaki_magic_percent = inst.components.kisaki_magic:GetPercent()
            inst.components.kisaki_magic:SetMax(TUNING.KISAKI_BOOK_SANITY + level * TUNING.KISAKI_BOOK_SANITY_UP)
            inst.components.kisaki_magic:SetPercent(kisaki_magic_percent)
        end
    end
    -- 等级获得的加成刷新后，刷新其他内容
    inst:PushEvent("kisaki_levelup")
end

-- 增加经验
function Level:DoDelta(val, isKillBoss)
    log.debug("执行了等级组件内部增加减少经验的方法")
    if isKillBoss then
        if self.is_today_kill_boss then
            return
        end
        self.is_today_kill_boss = true
    else
        if self.exp_pre_day_max <= self.current_today_exp then
            return
        end
        val = math.min(self.exp_pre_day_max - self.current_today_exp, val)
        self.current_today_exp = self.current_today_exp + val
    end
    self.current_exp_total = self.current_exp_total + val
    self.current_exp = self.current_exp + val
    local isLevelUp = false
    while self.current_exp >= self.levelup_need_exp do
        self.current = math.min(self.current + 1, KISAKI_LEVEL_MAX) -- 升级
        self.current_exp = self.current_exp - self.levelup_need_exp
        self.levelup_need_exp = experience_table[math.ceil((self.current + 1) / 5)]
        isLevelUp = true
    end
    -- 人物升级，刷新下三维
    if isLevelUp then
        onKisakiLevelUp(self.inst)
    end
end

-- 根据经验总值算出当前等级信息
function Level:Refresh()
    log.info("执行了等级组件内部刷新经验值，通过经验值计算等级的方法")
    local exp_total = self.current_exp_total
    -- 重置经验
    if exp_total < 1 then
        self.current = 0
        self.current_exp = 0
        self.current_exp_total = 0
        self.levelup_need_exp = 1
        self.current_today_exp = 0
        self.is_today_kill_boss = false
    elseif experience_table_total[KISAKI_LEVEL_MAX] <= exp_total then
        -- 经验超出
        self.current = KISAKI_LEVEL_MAX
        self.current_exp = 0
        self.current_exp_total = experience_table_total[KISAKI_LEVEL_MAX]
        self.levelup_need_exp = 2147483647
        self.current_today_exp = 0
        self.is_today_kill_boss = true
    else
        -- 计算角色等级（执行次数少，懒得写二分法，直接遍历）
        for i = 1, #experience_table_total do
            local exp_check_total = experience_table_total[i]
            if exp_check_total >= exp_total then
                self.current = exp_check_total == exp_total and i or i - 1
                self.current_exp = (exp_check_total == exp_total) and 0 or (exp_total - experience_table_total[i - 1])
                self.levelup_need_exp = experience_table[math.ceil((self.current + 1) / 5)]
                break
            end
        end
    end
    -- 刷新下三维
    onKisakiLevelUp(self.inst)
end

----------------------------------------------------------------------------加载时运行---------------------------------------------------------------------------

function Level:OnSave()
    log.debug("执行了等级组件内部存储等级数据的方法")
    return
    {
        current_exp_total = self.current_exp_total,
        current_today_exp = self.current_today_exp,
        is_today_kill_boss = self.is_today_kill_boss,
    }
end

function Level:OnLoad(data)
    log.debug("执行了等级组件内部读取等级数据的方法")
    if not data then return end
    self.current_exp_total = data.current_exp_total ~= nil and data.current_exp_total or 0
    self.current_today_exp = data.current_today_exp ~= nil and data.current_today_exp or self.exp_pre_day_max
    -- 布尔类型的最好别三元表达式
    if data.is_today_kill_boss ~= nil then
        self.is_today_kill_boss = data.is_today_kill_boss
    else
        self.is_today_kill_boss = true
    end
    self.exp_pre_day_max = 300
    self.is_death_punishment = true
    self:Refresh()
end

-- 角色数据保存模块调用
Level.OnPlayerSave = Level.OnSave
Level.OnPlayerLoad = Level.OnLoad


return Level
