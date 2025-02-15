-- 模组配置
TUNING.KISAKI_DATA_SAVE = GetModConfigData("mod_data_save")                         --  角色换人不丢失数据
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
-- 角色技能树内容
TUNING.KISAKI_FSAT_BUILD = GetModConfigData("init_fast_build")                      --  角色自带快速制作
-- 模组开发者配置
TUNING.KISAKI_LOGLEVEL = GetModConfigData("developer_log_level")                    --  日志打印最低级别
TUNING.KISAKI_DEBUGER = GetModConfigData("developer_debug_cmd")                     --  模组控制台命令启用


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
}                                 --  会自动删除的诅咒列表
TUNING.KISAKI_GOST_MOVE_SPEED = 5 --  角色死亡后移速倍率
-- 当预制物有以下tag时，免疫他的光环
TUNING.KISAKI_IMMUNITY_AURA_TAG = {
	["brightmare"] = true,              -- 虚影
	["kisaki_alterguardian_phase"] = true, -- 天体英雄
	["repairable_moon_altar"] = true    -- 天体裂隙
}

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
