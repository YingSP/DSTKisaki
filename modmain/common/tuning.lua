-- 模组配置
TUNING.KISAKI_DATA_SAVE = GetModConfigData("mod_data_save")                         --  角色换人不丢失数据
TUNING.KISAKI_RECIPES_SHARE = GetModConfigData("mod_recipes_share")                 --  角色通用道具配方共享
-- 人物基础配置
TUNING.KISAKI_HEALTH = GetModConfigData("init_health")                              --  初始生命值
TUNING.KISAKI_HEALTH_UP = GetModConfigData("init_health_up")                        --  角色升级生命值上限提升
TUNING.KISAKI_DAMAGE_REDUCTION_RATE = GetModConfigData("init_defense")              --  角色自带减伤率
TUNING.KISAKI_DAMAGE_REDUCTION_RATE_UP = GetModConfigData("init_defense_up")        --  角色升级减防率提升
TUNING.KISAKI_HUNGER = GetModConfigData("init_hunger")                              --  初始饥饿值
TUNING.KISAKI_HUNGER_UP = GetModConfigData("init_hunger_up")                        --  角色升级饥饿值上限提升
TUNING.KISAKI_HUNGER_RATE = GetModConfigData("init_hunger_speed")                   --  角色饥饿速率
TUNING.KISAKI_SANITY = GetModConfigData("init_hsanity")                             --  初始SAN值
TUNING.KISAKI_SANITY_UP = GetModConfigData("init_hsanity_up")                       --  角色升级SAN值上限提升
TUNING.KISAKI_MONSTER_SANITY_MULT = GetModConfigData("init_hsanity_monster")        --  怪物对角色的san值影响系数
TUNING.KISAKI_IMMUNITY_AURA_ENABLE = GetModConfigData("init_hsanity_lunacy")        --  角色免疫月灵对角色的san值影响
TUNING.KISAKI_NIGHT_SANITY_MULT = GetModConfigData("init_hsanity_dark")             --  夜晚对角色的san值影响系数
TUNING.KISAKI_BOOK_SANITY = GetModConfigData("init_book_sanity")                    --  角色初始魔法值
TUNING.KISAKI_BOOK_SANITY_UP = GetModConfigData("init_book_sanity_up")              --  角色升级魔法值上限提升
TUNING.KISAKI_DAMANGE_MULTIPLIER = GetModConfigData("init_damage_proportion")       --  角色伤害倍率
TUNING.KISAKI_DAMANGE_MULTIPLIER_UP = GetModConfigData("init_damage_proportion_up") --  角色升级提升的伤害倍率
TUNING.KISAKI_MOVE_SPEED = GetModConfigData("init_speed")                           --  角色移速倍率
TUNING.KISAKI_HIT_RANGE = GetModConfigData("init_attack_range")                     --  角色攻击范围
TUNING.KISAKI_FIRE_DAMAGE = GetModConfigData("init_fire_damage_range")              --  角色受到火焰伤害倍率
-- 角色特殊能力配置
TUNING.KISAKI_IS_FAMILIAR = GetModConfigData("init_familiar_enable")                --  角色是否不会吓跑小动物
TUNING.KISAKI_IS_FOOD_HATE = GetModConfigData("init_food_hate")                     --  角色是否只能食用新鲜食物
TUNING.KISAKI_IS_FOOD_LIKE = GetModConfigData("init_food_like")                     --  角色吃喜欢吃的食物是否有加成
TUNING.KISAKI_SCIENCE_UNLOCK = GetModConfigData("init_science_unlock")              --  角色是否自带科技一本
TUNING.KISAKI_MAGIC_UNLOCK = GetModConfigData("init_magic_unlock")                  --  角色是否自带魔法一本
TUNING.KISAKI_MAKEBOOK_ENABLE = GetModConfigData("init_makebook_enable")            --  角色是否能制作书籍
TUNING.KISAKI_READ_ENABLE = GetModConfigData("init_read_enable")                    --  角色初始自带读书能力
TUNING.KISAKI_BRAMBLE_RESISTANT = GetModConfigData("init_bramble_resistant")        --  角色是否抗荆棘
TUNING.KISAKI_DELETE_CURSE = GetModConfigData("init_delete_curse")                  --  角色自动删除身上的诅咒物
TUNING.KISAKI_SANITYAURA = GetModConfigData("init_sanityaura")                      --  角色自带回SAN光环
TUNING.KISAKI_DEAD_DROP_DISABLE = GetModConfigData("init_dead_drop_disable")        --  角色死亡不掉落
TUNING.KISAKI_DEAD_SPAWN_PROP = GetModConfigData("init_dead_spawn_prop")            --  角色死亡掉落复活道具
TUNING.KISAKI_GOST_FAST = GetModConfigData("init_gost_fast")                        --  角色死亡后速度加快
TUNING.KISAKI_STRONGGER = GetModConfigData("init_stronggr")                         --  角色不会因为潮湿等原因武器脱手
TUNING.KISAKI_HEALTH_PUNISHMENT = GetModConfigData("init_health_punishment")        --  角色掉血惩罚
TUNING.KISAKI_SANITY_PUNISHMENT = GetModConfigData("init_sanity_punishment")        --  角色低SAN惩罚
-- 妃的魔法盒相关
TUNING.KISAKI_BOX_COLLECT_SCOPE = 45
TUNING.KISAKI_BOX_COLLECT_FISH_SCOPE = 16
TUNING.KISAKI_BOX_COLLECTION_FISH_SCOPE = 32
TUNING.KISAKI_BOX_WORK_SCOPE = 16
TUNING.KISAKI_CONSUME_MAGIC_ENABLE = true
TUNING.KISAKI_CONSUME_HUNGER_ENABLE = true
TUNING.KISAKI_CONSUME_SANITY_ENABLE = true
TUNING.KISAKI_CONSUME_HEALTH_ENABLE = true
TUNING.KISAKI_COLLECT_CONSUME = 5
TUNING.KISAKI_COLLECT_MAX = 25
TUNING.KISAKI_FISH_CONSUME = 10
TUNING.KISAKI_FISH_MAX = 15
TUNING.KISAKI_CONVERSION_CONSUME = 10
TUNING.KISAKI_CONVERSION_MAX = 15
TUNING.KISAKI_WORK_CONSUME = 5
TUNING.KISAKI_WORK_MAX = 100
TUNING.KISAKI_FRESH_CONSUME = 5
TUNING.KISAKI_FRESH_MAX = 25
TUNING.KISAKI_DURABILITY_CONSUME = 100
TUNING.KISAKI_DURABILITY_MAX = 1
TUNING.KISAKI_CONSUMEDURABILITY_CONSUME = 100
TUNING.KISAKI_CONSUMEDURABILITY_MAX = 1
TUNING.KISAKI_DECAY_CONSUME = 5
TUNING.KISAKI_DECAY_MAX = 25
TUNING.KISAKI_COLLECTION_CONSUME = 2
TUNING.KISAKI_COLLECTION_MAX = 65
TUNING.KISAKI_EXTRACT_CONSUME = 1
TUNING.KISAKI_DISASSEMBLY_CONSUME = 100
TUNING.KISAKI_DISASSEMBLY_MAX = 1
-- 全图收集开关
TUNING.KISAKI_COLLECT_ALL_ITEM_SCOPE = GetModConfigData("collect_all_item_scope")
-- 角色技能树内容
TUNING.KISAKI_FSAT_BUILD = GetModConfigData("init_fast_build")   --  角色自带快速制作
-- 模组开发者配置
TUNING.KISAKI_LOGLEVEL = GetModConfigData("developer_log_level") --  日志打印最低级别
TUNING.KISAKI_DEBUGER = GetModConfigData("developer_debug_cmd")  --  模组控制台命令启用

TUNING.KISAKI_CANT_EAT_TAGS = {
	"stale", "spoiled", "monstermeat"
} --  spoiled红色新鲜度食物，stale黄色新鲜度食物，fresh绿色新鲜度食物，monstermeat怪物肉
TUNING.KISAKI_CANT_EAT_FOOD = {
	["spoiled_food"] = true,
	["rottenegg"] = true,
	["spoiled_fish"] = true,
	["spoiled_fish_small"] = true
} --  spoiled_food腐烂食物,rottenegg腐烂鸟蛋,spoiled_fish变质的鱼，spoiled_fish_small变质小鱼块
TUNING.CURSELIST = {
	["cursed_monkey_token"] = true
}                                   --  会自动删除的诅咒列表
TUNING.KISAKI_GOST_MOVE_SPEED = 1.8 --  角色死亡后移速倍率
-- 升级魔法盒的物品
TUNING.KISAKI_MAGIC_BOX_FUNCTION_LIST = {
	-- 采集
	{ action = "collection", name = "物品采集", needprefab = "orangeamulet", neednum = 1, },
	-- 捕鱼
	{ action = "fish", name = "海上捞鱼", needprefab = "ocean_trawler_kit", neednum = 10, },
	-- 摸鱼
	{ action = "catchfish", name = "陆地摸鱼", needprefab = "fishingrod", neednum = 50, },
	-- 回鲜
	{ action = "fresh", name = "物品返鲜", needprefab = "blueamulet", neednum = 1, },
	-- 返鲜
	{ action = "preserver", name = "容器自动返鲜(前置物品返鲜)", needprefab = "saltrock", neednum = 20, },
	-- 回耐
	{ action = "durability", name = "物品回耐", needprefab = "greenamulet", neednum = 5, },
	-- 消耐
	{ action = "consumedurability", name = "耐久消耗", needprefab = "purpleamulet", neednum = 5, },
	-- 自动回耐
	{ action = "autodurability", name = "容器自动回耐(前置物品回耐)", needprefab = "opalpreciousgem", neednum = 5, },
	-- 火焰
	{ action = "fire", name = "火焰魔法", needprefab = "charcoal", neednum = 50, },
	-- 腐烂
	{ action = "decay", name = "物品腐烂", needprefab = "spoiled_food", neednum = 50, },
	-- 工作
	{ action = "work", name = "快速工作", needprefab = "multitool_axe_pickaxe", neednum = 1, },
	-- 提取
	{ action = "extract", name = "以太提取", needprefab = "kisaki_ether_bottle", neednum = 5, },
	-- 转换
	{ action = "conversion", name = "物品转换", needprefab = "kisaki_ether", neednum = 999, },
	-- 拆解
	{ action = "disassembly", name = "批量拆解", needprefab = "greenstaff", neednum = 5, },
	-- 猪王交易
	{ action = "pigtrade", name = "猪王交易", needprefab = "goldnugget", neednum = 50, },
	-- 鸟笼交易
	{ action = "birdtrade", name = "鸟笼交易", needprefab = "bird_egg", neednum = 50, },
	-- 鱼人王交易
	{ action = "fishtrade", name = "鱼王交易", needprefab = "pondfish", neednum = 50, },
	-- 蚁狮交易
	{ action = "antliontrade", name = "蚁狮交易", needprefab = "townportaltalisman", neednum = 50, },
	-- 制图桌擦纸
	{ action = "mappingtrade", name = "快速擦纸", needprefab = "compass", neednum = 1, },
	-- 无消耗
	{ action = "noconsume", name = "功能无耗", needprefab = "skeletonhat", neednum = 1, },
}
-- 升级幻想图书馆的物品
TUNING.KISAKI_LIBRARY_BOX_FUNCTION_LIST = {
	-- 书本回耐久加速
	{ id = "fast", name = "回耐加速", levels = {}, needprefab = "opalpreciousgem", neednum = 1, },
	-- 二本
	{ id = "science", name = "炼金科技", levels = { SCIENCE = 2 }, needprefab = "gears", neednum = 2, },
	-- 四本
	{ id = "magic", name = "魔法科技", levels = { MAGIC = 3 }, needprefab = "purplegem", neednum = 1, },
	-- 月亮科技
	{ id = "celestial", name = "月亮科技", levels = { CELESTIAL = 3 }, tags = { "celestial_station" }, needprefab = "moonglass", neednum = 20, },
	-- 远古科技
	{ id = "ancient", name = "远古科技", levels = { ANCIENT = 4 }, tags = { "ancient_station" }, needprefab = "thulecite_pieces", neednum = 20, },
	-- 暗影术基座
	{ id = "shadowforging", name = "暗影科技", levels = { SHADOWFORGING = 2 }, tags = { "shadow_forge" }, needprefab = "horrorfuel", neednum = 5 },
	-- 辉煌铁匠铺
	{ id = "lunarforging", name = "辉煌科技", levels = { LUNARFORGING = 2 }, tags = { "lunar_forge" }, needprefab = "purebrilliance", neednum = 5, },
	-- 陶轮
	{ id = "sculpting", name = "陶轮科技", levels = { KISAKI_SCULPTING = 1 }, needprefab = "fossil_piece", neednum = 1, },
	-- 智囊团
	{ id = "seafaring", name = "航海科技", levels = { SEAFARING = 2 }, needprefab = "driftwood_log", neednum = 10, },
	-- 制图桌
	{ id = "cartography", name = "制图科技", levels = { CARTOGRAPHY = 2 }, needprefab = "compass", neednum = 1, },
	-- 钓鱼容器
	{ id = "fishing", name = "钓鱼科技", levels = { FISHING = 1 }, needprefab = "feather_robin", neednum = 10, },
	-- 调料站
	{ id = "foodprocessing", name = "调料科技", levels = { FOODPROCESSING = 1 }, needprefab = "spice_sugar", neednum = 10, },
	-- 蟹奶奶
	{ id = "hermitcrabshop", name = "瓶子交易", levels = { HERMITCRABSHOP = 7 }, needprefab = "winter_ornament_boss_pearl", neednum = 1, },
	-- 流浪商人
	{ id = "wanderingtradershop", name = "流浪商人", levels = { WANDERINGTRADERSHOP = 2 }, needprefab = "ash", neednum = 20, },
	-- 友善兔王
	{ id = "rabbitkingshop", name = "友善兔王", levels = { RABBITKINGSHOP = 2 }, needprefab = "carrot", neednum = 20, },
	-- 锯马
	{ id = "carpentry", name = "锯马科技", levels = { CARPENTRY = 3 }, tags = { "carpentry_station" }, needprefab = "flint", neednum = 20, },
	-- 老瓦科技
	{ id = "wagpunk_workstation", name = "老瓦科技", levels = { WAGPUNK_WORKSTATION = 2 }, needprefab = "wagpunk_bits", neednum = 10, },
	-- 土地夯实器
	{ id = "turfcrafting", name = "地皮科技", levels = { TURFCRAFTING = 2, MASHTURFCRAFTING = 2 }, needprefab = "turf_carpetfloor", neednum = 3, },
}
-- 物品转换表
TUNING.KISAKI_ITEM_TRANSFORM_LIST = {
	flint = "rocks",
	rocks = "nitre",
	nitre = "flint",
	goldnugget = "lucky_goldnugget",
	lucky_goldnugget = "goldnugget",
	moonglass = "moonrocknugget",
	moonrocknugget = "thulecite_pieces",
	thulecite_pieces = "moonglass",
	palmcone_scale = "driftwood_log",
	driftwood_log = "palmcone_scale",
	twigs = "cutgrass",
	cutgrass = "twigs",
	transistor = "gears",
	gears = "wagpunk_bits",
	wagpunk_bits = "transistor",
	bluegem = "redgem",
	redgem = "bluegem",
	orangegem = "yellowgem",
	yellowgem = "greengem",
	greengem = "orangegem",
	horrorfuel = "purebrilliance",
	purebrilliance = "horrorfuel",
	voidcloth = "lunarplant_husk",
	lunarplant_husk = "voidcloth",
	feather_crow = "feather_robin",
	feather_robin = "feather_robin_winter",
	feather_robin_winter = "feather_canary",
	feather_canary = "feather_crow",
	goose_feather = "malbatross_feather",
	malbatross_feather = "goose_feather",
	berries = "berries_juicy",
	berries_juicy = "berries",
	slurtleslime = "glommerfuel",
	glommerfuel = "phlegm",
	phlegm = "slurtleslime",
	marble = "marblebean",
	marblebean = "townportaltalisman",
	townportaltalisman = "marble",
	horn = "walrus_tusk",
	walrus_tusk = "lightninggoathorn",
	lightninggoathorn = "horn",
	boneshard = "houndstooth",
	houndstooth = "boneshard",
	silk = "beefalowool",
	beefalowool = "manrabbit_tail",
	manrabbit_tail = "beardhair",
	beardhair = "silk",
	mosquitosack = "spidergland",
	spidergland = "mosquitosack",
	tentaclespots = "pigskin",
	pigskin = "cookiecuttershell",
	cookiecuttershell = "tentaclespots",
	stinger = "slurtle_shellpieces",
	slurtle_shellpieces = "stinger",
	spoiled_food = "poop",
	poop = "guano",
	guano = "ash",
	ash = "spoiled_food",
	spoiled_fish = "compost",
	compost = "rottenegg",
	rottenegg = "spoiled_fish",
	green_cap = "blue_cap",
	blue_cap = "red_cap",
	red_cap = "moon_cap",
	moon_cap = "green_cap",
	spore_tall = "spore_medium",
	spore_medium = "spore_small",
	spore_small = "spore_tall",
	milkywhites = "goatmilk",
	goatmilk = "butter",
	butter = "milkywhites",
	oceanfish_small_7_inv = "oceanfish_small_8_inv",
	oceanfish_small_8_inv = "oceanfish_small_6_inv",
	oceanfish_small_6_inv = "oceanfish_medium_8_inv",
	oceanfish_medium_8_inv = "oceanfish_small_7_inv",
	pondeel = "pondfish",
	fishmeat_small = "froglegs",
	froglegs = "fishmeat_small",
	petals = "petals_evil",
	petals_evil = "petals",
	lightbulb = "seeds",
	seeds = "petals",
	butterfly = "moonbutterfly",
	moonbutterfly = "butterflywings",
	butterflywings = "moonbutterflywings",
	moonbutterflywings = "butterfly",
	crow = "robin",
	robin = "robin_winter",
	robin_winter = "canary",
	canary = "crow",
	dug_berrybush = "dug_berrybush2",
	dug_berrybush2 = "dug_berrybush_juicy",
	dug_berrybush_juicy = "dug_berrybush",
	acorn = "pinecone",
	pinecone = "twiggy_nut",
	twiggy_nut = "acorn",
	ancienttree_gem_sapling_item = "ancienttree_nightvision_sapling_item",
	ancienttree_nightvision_sapling_item = "ancienttree_gem_sapling_item",
}
-- 夜莺与黄昏之诗
TUNING.KISAKI_SPACE_CHEST_ITEMS = {
	"cutgrass", "twigs", "cutreeds", "log",
	"driftwood_log", "palmcone_scale", "charcoal", "lucky_goldnugget",
	"rocks", "flint", "goldnugget", "nitre",
	"marble", "moonglass", "moonrocknugget", "saltrock",
	"townportaltalisman", "gears", "wagpunk_bits", "trinket_6",
	"boards", "rope", "cutstone", "papyrus",
	"transistor", "waxpaper", "lifeinjector", "gunpowder",
	"ancientfruit_gem", "fossil_piece", "wintersfeastfuel", "waterplant_bomb",
	"pinecone", "palmcone_seed", "acorn", "seeds",
	"twiggy_nut", "marblebean", "lureplantbulb", "rock_avocado_fruit_sprout",
	"bluegem", "redgem", "purplegem", "orangegem",
	"yellowgem", "greengem", "opalpreciousgem", "dreadstone",
	"thulecite", "thulecite_pieces", "livinglog", "nightmarefuel",
	"horrorfuel", "lunarplant_husk", "purebrilliance", "voidcloth",
	"pigskin", "silk", "spidergland", "walrus_tusk",
	"beefalowool", "manrabbit_tail", "coontail", "tentaclespots",
	"feather_canary", "feather_crow", "feather_robin", "feather_robin_winter",
	"houndstooth", "boneshard", "lightninggoathorn", "stinger",
	"mosquitosack", "slurper_pelt", "slurtle_shellpieces", "beardhair",
	"honeycomb", "cookiecuttershell", "glommerfuel", "slurtleslime",
	"spidereggsack", "dragon_scales", "minotaurhorn", "deerclops_eyeball",
	"goose_feather", "furtuft", "bearger_fur", "phlegm",
	"steelwool", "malbatross_feather", "bootleg", "shroom_skin",
	"mandrake", "rock_avocado_fruit", "fireflies", "messagebottleempty",
	"ash", "poop", "guano", "spoiled_food",
	"rottenegg", "spoiled_fish", "spoiled_fish_small", "mitegland",
	"smallmeat", "meat", "plantmeat", "drumstick",
	"monstermeat", "fishmeat_small", "fishmeat", "froglegs",
	"trunk_summer", "trunk_winter", "batwing", "batnose",
	"bird_egg", "tillweed", "forgetmelots", "firenettles",
	"berries", "berries_juicy", "wormlight", "wormlight_lesser",
	"red_cap", "green_cap", "blue_cap", "moon_cap",
	"butterfly", "moonbutterfly", "butterflywings", "moonbutterflywings",
	"bee", "killerbee", "mosquito", "honey",
	"petals", "petals_evil", "moon_tree_blossom", "cactus_flower",
	"cave_banana", "fig", "carrot", "kelp",
	"butter", "goatmilk", "milkywhites", "royal_jelly",
	"moonglass_charged", "moonstorm_spark", "ancientfruit_nightvision", "barnacle",
	"lightbulb", "snowball_item", "ice", "bullkelp_root",
	"tree_rock_seed", "spore_medium", "spore_small", "spore_tall"
}
for i = 1, 80 do
	table.insert(TUNING.KISAKI_SPACE_CHEST_ITEMS, "")
end
table.insert(TUNING.KISAKI_SPACE_CHEST_ITEMS, "kisaki_magic_box")
table.insert(TUNING.KISAKI_SPACE_CHEST_ITEMS, "kisaki_library_box")

-- 初始物品
TUNING.KISAKI_STARTING_ITEMS = {
	papyrus = {
		num = 4,
		moditem = false
	}
	-- ['goldnugget'] = {
	-- 	num = 4, -- 数量
	-- 	moditem = false, -- 是否为mod物品
	-- 	-- img = {atlas = 'images/inventoryimages/goldnugget.xml', image = 'goldnugget.tex'},
	-- }
}

TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.KISAKI = {}
for k, v in pairs(TUNING.KISAKI_STARTING_ITEMS) do
	if v.moditem then
		TUNING.STARTING_ITEM_IMAGE_OVERRIDE[v] = {
			atlas = v.img and v.img.atlas or "images/inventoryimages/" .. k .. ".xml",
			image = v.img and v.img.image or k .. ".tex",
		}
	end
	for i = 1, v.num do
		table.insert(TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.KISAKI, k)
	end
end
