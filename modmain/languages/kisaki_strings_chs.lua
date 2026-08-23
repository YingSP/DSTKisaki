--------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 配置后缀必须是人物名，大小写敏感
-- 选人页面的描述，如果没配置皮肤则自动加载显示下面的内容，现在一般都使用皮肤，这部分不用看
STRINGS.CHARACTER_NAMES.kisaki = "月社妃" -- 角色名
STRINGS.CHARACTER_TITLES.kisaki = "渴望平凡的少女" -- 角色描述
STRINGS.CHARACTER_DESCRIPTIONS.kisaki = "*拥有将书籍内容变为现实的魔力\n*超凡的智慧" -- 人物能力简述
STRINGS.CHARACTER_QUOTES.kisaki = "\"向神发誓，我赌上一生来爱你！\"" -- 角色语言(选择后在人物模型下方的那句话)
STRINGS.CHARACTER_SURVIVABILITY.kisaki = "这是一场有趣的冒险" -- 生存几率
STRINGS.NAMES.kisaki = "月社妃"
STRINGS.SKIN_NAMES.kisaki = "月社妃"
--------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 模组角色交互原版内容时语句添加
local kisaki_cant_use = "我暂时还不会用这个。"

STRINGS.CHARACTERS.KISAKI = {
    ACTIONFAIL =
    {
        READ =
        {
            GENERIC = "我想还缺点什么。", -- 通用阅读失败时
            NOBIRDS = "我想鸟儿们不是很喜欢这个天气。", -- 读《世界鸟类大全》，天气原因召唤失败
            NOWATERNEARBY = "陆地上可召唤不出鱼来，琉璃。", -- 读《世界鸟类大全》，地形原因召唤失败
            TOOMANYBIRDS = "琉璃，这儿的鸟已经够多了。", -- 读《世界鸟类大全》，鸟太多召唤失败
            WAYTOOMANYBIRDS = "再召唤也不会有更多的鸟出来啦。", -- 读《世界鸟类大全》，鸟太多召唤失败
            NOFIRES = "薇洛并没有在周围点火。", -- 读《意念控火术详解》，周围没有火导致失败
            NOSILVICULTURE = "这光秃秃的一片，没有一颗树。", -- 读《应用造林学》，周围没有树导致失败
            NOHORTICULTURE = "要不要种点东西再试试呢。", -- 读《园艺学》，周围没有农作物导致失败
            NOTENTACLEGROUND = "触手VS地皮，触手败！", -- 读《触手的召唤》，周围没有农作物导致失败
            NOSLEEPTARGETS = "想让我单独给你读睡前故事吗？琉璃", -- 读《睡前故事》，周围没有农作物导致失败
            TOOMANYBEES = "水满则溢，不是吗？", -- 读《养蜂笔记》，周围蜜蜂太多导致失败
            NOMOONINCAVES = "地下可没有月亮，琉璃。", -- 读《月之魔典》，地形原因导致失败
            ALREADYFULLMOON = "已经吃下去的蛋糕可没法再吃下去。", -- 读《月之魔典》，已经是满月导致失败
        }
    },
    DESCRIBE =
    {

    },
    ANNOUNCE_EAT =
    {
        GENERIC = "你也要来点这个吗？",
        PAINFUL = "吃这个可不太好。",
        SPOILED = "吃这个简直是在折磨我！",
        STALE = "你最好丢掉它，而不是让我吃掉。",
        INVALID = "别让我吃这个，琉璃。",
        YUCKY = "求你别让我吃这个！",

        COOKED = kisaki_cant_use,
        DRIED = kisaki_cant_use,
        PREPARED = kisaki_cant_use,
        RAW = kisaki_cant_use,
        SAME_OLD_1 = kisaki_cant_use,
        SAME_OLD_2 = kisaki_cant_use,
        SAME_OLD_3 = kisaki_cant_use,
        SAME_OLD_4 = kisaki_cant_use,
        SAME_OLD_5 = kisaki_cant_use,
        TASTY = kisaki_cant_use,
    }
}

--------------------------------------------------------------------------------------------------------------------------------------------------------------

STRINGS.KISAKI_ACTION = {
    OPENORCLOSEAMULETWITHRIGHT = "开关",
    KISAKITRADER = "给予",
    RECYCLE = "回收",
    KISAKIRUMMAGE = "打开",
    OPENGEMINIAMULET = "已开启双子守护",
    CLOSEGEMINIAMULET = "已关闭双子守护",
    COLLECT = "收集",
    MORE = "更多",
    STORAGE = "快存",
    TIDY = "整理",
    UPGRADE = "升级",
    COLLECTION = "采集",
    FISHING = "捕鱼",
    CONVERSION = "转化",
    WORK = "工作",
    FRESH = "回鲜",
    DURABILITY = "回耐",
    CONSUMEDURABILITY = "消耐",
    FIRE = "魔火",
    DECAY = "腐烂",
    EXTRACT = "提取",
    DISASSEMBLY = "拆解",
    PIGTRADE = "猪王",
    BIRDTRADE = "鸟笼",
    FISHTRADE = "鱼王",
    ANTLIONTRADE = "蚁狮",
    MAPPINGTRADE = "擦纸",
}

--------------------------------------------------------------------------------------------------------------------------------------------------------------

STRINGS.UI.CRAFTING_FILTERS.KISAKI_TALISMAN = "妃的守护命符"
STRINGS.UI.CRAFTING_FILTERS.KISAKI_CHARACTER = "妃的魔法道具"

STRINGS.UI.CRAFTING.NEEDSTECH.KISAKI = "月社妃知道如何制作"
STRINGS.UI.CRAFTING.NEEDSKISAKI_BOOKCRAFT_ONE = "需要幻想图书馆解锁"
STRINGS.UI.CRAFTING.NEEDSKISAKI_SCULPTING_ONE = "需要幻想图书馆的陶轮解锁"

-- 模组物品被原版交互后语句添加
local MSG = {
    kisaki = {
        name = '月社妃',
        desc = '多么坚强的少女',
        kisaki_desc = '另一个我？',
        recipe_desc = '月社妃'
    },
    kisaki_ether = {
        name = "以太",
        desc = "世界的基础能量，听说所有的物品都基于此生成",
        recipe_desc = "从宝石中提取能量"
    },
    kisaki_purplegem_to_ether = {
        name = "以太",
        recipe_desc = "从宝石中提取能量"
    },
    kisaki_goldnugget_to_ether = {
        name = "以太",
        recipe_desc = "使用魔力从万物中提取本源"
    },
    kisaki_ether_bottle = {
        name = "以太球",
        desc = "能量的集合体，好像有些特殊的作用",
        recipe_desc = "有些东西装进容器里才能用"
    },
    kisaki_talisman_aquarius = {
        name = "星灵守护-水瓶",
        desc = "关于炼药的知识，它知道更多",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_pisces = {
        name = "星灵守护-双鱼",
        desc = "鱼儿们更喜欢水",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_aries = {
        name = "星灵守护-白羊",
        desc = "治愈亦或是守护",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_taurus = {
        name = "星灵守护-金牛",
        desc = "它身怀巨力，他刀枪不入",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_gemini = {
        name = "星灵守护-双子",
        desc = "召唤你的半身保护你",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_cancer = {
        name = "星灵守护-巨蟹",
        desc = "两栖动物的优势",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_leo = {
        name = "星灵守护-狮子",
        desc = "狮子的力量与眼睛",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_virgo = {
        name = "星灵守护-处女",
        desc = "仙女的织术",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_libra = {
        name = "星灵守护-天秤",
        desc = "人生并非处处公平，不是吗",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_scorpio = {
        name = "星灵守护-天蝎",
        desc = "冷漠的猎手，于黑夜之中",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_sagittarius = {
        name = "星灵守护-射手",
        desc = "集百家射术之长",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_capricorn = {
        name = "星灵守护-摩羯",
        desc = "他拥有水元素的力量",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_talisman_star = {
        name = "星灵守护-群星",
        desc = "众星之力",
        recipe_desc = "来自星空的记忆"
    },
    kisaki_portable_box = {
        name = "妃的杂物袋",
        desc = "可以拿来存储一些基础物资",
        recipe_desc = "可以拿来存储一些基础物资"
    },
    kisaki_portable_box_chest = {
        name = "妃的杂物袋",
        desc = "可以拿来存储一些基础物资",
        recipe_desc = "可以拿来存储一些基础物资"
    },
    kisaki_magic_box = {
        name = "妃的魔法盒",
        desc = "魔法，无所不能",
        recipe_desc = "使用强大魔法凝聚的盒子"
    },
    kisaki_magic_box_chest = {
        name = "妃的魔法盒",
        desc = "魔法，无所不能",
        recipe_desc = "使用强大魔法凝聚的盒子"
    },
    kisaki_library_box = {
        name = "妃的幻想图书馆",
        desc = "随时随地可以读书是一件幸福的事",
        recipe_desc = "一个便携式书架"
    },
    kisaki_library_box_chest = {
        name = "妃的幻想图书馆",
        desc = "随时随地可以读书是一件幸福的事",
        recipe_desc = "一个便携式书架"
    },
    kisaki_shadow_protector_gemini = {
        name = "暗影守护者",
        desc = "这是一个倒影，来着另一个维度的我",
    },
    kisaki_shadow_protector = {
        name = "暗影守护者",
        desc = "使用暗影的力量构建一个守护者",
    },
}

for k, v in pairs(MSG) do
    if v.name then
        STRINGS.NAMES[string.upper(k)] = v.name
        if v.desc then
            STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(k)] = v.desc
        end
        if v.kisaki_desc then
            STRINGS.CHARACTERS.KISAKI.DESCRIBE[string.upper(k)] = v.kisaki_desc and v.kisaki_desc or v.desc
        end
        if v.recipe_desc then
            STRINGS.RECIPE_DESC[string.upper(k)] = v.recipe_desc
        end
    end
end
