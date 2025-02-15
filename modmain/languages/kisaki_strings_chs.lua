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

-- 模组物品被原版交互后语句添加
local MSG = {
    kisaki = {
        name = '月社妃',
        desc = '多么坚强的少女',
        kisaki_desc = '另一个我？',
        recipe_desc = '月社妃'
    }
}

for k, v in pairs(MSG) do
    if v.name then
        STRINGS.NAMES[string.upper(k)] = v.name
        if v.desc then
            STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(k)] = v.desc
        end
        if v.kisaki_desc then
            STRINGS.CHARACTERS.KISAKI.DESCRIBE[string.upper(k)] = v.kisaki_desc
        end
        if v.recipe_desc then
            STRINGS.RECIPE_DESC[string.upper(k)] = v.recipe_desc
        end
    end
end
