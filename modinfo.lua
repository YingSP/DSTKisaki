--mod基本信息，大部分用于展示在mod信息页面，不影响功能
name = "月社妃-纸上的魔法使"
version = "1.0.0" -- version每次上传模组需要修改
description = "1.0.0测试中"
author = "樱碎片"

--服务器标签
server_filter_tags = {
	"character", "kisaki", "月社妃", "妃"
}

-- API版本，联机必须是10，单机必须是6
api_version = 10
-- 所有客户端需要下载此MOD（服务器MOD）
-- client_only_mode = true(客户端MOD)。all_clients_require_mod = true(纯服务器MOD)
all_clients_require_mod = true
-- mod加载优先级，越大越先加载，需要做mod适配可以填小点
priority = -2100000000
-- 是否兼容联机版
dst_compatible = true
-- 不兼容单机原版
dont_starve_compatible = false
-- 不兼容巨人国DLC，海难DLC，哈姆雷特DLC
reign_of_giants_compatible = false
shipwrecked_compatible = false
hamlet_compatible = false
-- 单机遗留。这是论坛上 mod 主题的 URL地址
forumthread = ""

-- 模组依赖某个模组运行，写workshop编号
-- mod_dependencies = {{
-- 	workshop = ""
-- }}

-- mod图标(显示在列表内的图片)，xml会自己定位到对应的图片文件
icon_atlas = "images/modicon.xml"
icon = "modicon.tex"

-- 通用方法，设置数值表配置构造
-- min最小值，num步数，step步长
local function makeMathConfig(min, num, step)
	local list = {}
	for i = 0, num, 1 do
		local data = min + i * step
		list[i + 1] = {
			description = data .. "",
			data = data
		}
	end
	return list
end

local function makeMathPercentageConfig(min, num, step)
	local list = {}
	for i = 0, num, 1 do
		local data = min + i * step
		list[i + 1] = {
			description = data .. "%",
			data = data / 100
		}
	end
	return list
end

-- 通用方法，设置的标题构造
-- name标题名称
local function makeTitle(name)
	return {
		name = name,
		label = name,
		options = { {
			description = "",
			data = ""
		} },
		default = ""
	}
end

-- MOD设置内容
configuration_options =
{
	makeTitle("基础设置"),
	{
		name = "mod_difficulty",
		label = "模组难度",
		options = {
			{ description = "休闲", data = 1, hover = "人物更容易升级，成长更迅速，毕业强度更高" },
			{ description = "普通", data = 2, hover = "人物成长与其他mod尽量数据平衡" },
			{ description = "生存", data = 3, hover = "人物成长与游戏原版尽量数据平衡" },
			{ description = "挑战", data = 4, hover = "需要对人物与原版机制更了解才能更好的生存" }
		},
		default = 2,
		hover = "MOD难度设置"
	},
	makeTitle("角色基础属性设置"),
	{
		name = "init_health",
		label = "初始血量",
		options = makeMathConfig(10, 18, 5),
		default = 30,
		hover = "月社妃0级时的血量上限"
	},
	{
		name = "init_defense",
		label = "初始减防值",
		options = makeMathPercentageConfig(-100, 30, 5),
		default = -0.8,
		hover = "月社妃0级时的减防值"
	},
	{
		name = "init_fire_damage_range",
		label = "受到火焰伤害倍率",
		options = makeMathPercentageConfig(100, 70, 5),
		default = 4,
		hover = "月社妃受到的火焰伤害倍率"
	},
	{
		name = "init_hunger",
		label = "初始饱食度",
		options = makeMathConfig(40, 32, 5),
		default = 85,
		hover = "月社妃0级时的饱食度上限"
	},
	{
		name = "init_hunger_speed",
		label = "初始饥饿速度",
		options = makeMathPercentageConfig(50, 20, 5),
		default = 1,
		hover = "月社妃饥饿速率"
	},
	{
		name = "init_hsanity",
		label = "初始精神值",
		options = makeMathConfig(80, 24, 5),
		default = 175,
		hover = "月社妃0级时的精神值上限"
	},
	{
		name = "init_hsanity_monster",
		label = "受到疯狂光环的影响",
		options = makeMathPercentageConfig(-100, 60, 5),
		default = 0,
		hover = "月社妃受到怪物SAN值光环的影响比例"
	},
	{
		name = "init_hsanity_lunacy",
		label = "免疫启蒙光环",
		options = {
			{ description = "关闭", data = false, hover = "角色不免疫启蒙光环" },
			{ description = "开启", data = true, hover = "角色免疫启蒙光环" }
		},
		default = true,
		hover = "月社妃是否免疫启蒙光环（会同步免疫双子魔眼的影响）"
	},
	{
		name = "init_hsanity_dark",
		label = "角色受到夜晚SAN值的影响",
		options = makeMathPercentageConfig(-100, 70, 5),
		default = 2,
		hover = "月社妃受到夜晚SAN值光环的影响比例"
	},
	{
		name = "init_damage_proportion",
		label = "角色初始伤害倍率",
		options = makeMathPercentageConfig(0, 20, 5),
		default = 0.3,
		hover = "月社妃0级时的伤害倍率"
	},
	{
		name = "init_speed",
		label = "角色初始移动速度",
		options = makeMathPercentageConfig(75, 50, 1),
		default = 1.08,
		hover = "月社妃初始移动速度"
	},
	{
		name = "init_attack_range",
		label = "角色攻击范围",
		options = makeMathConfig(1, 10, 1),
		default = 3,
		hover = "月社妃攻击范围,威尔逊为2"
	},
	makeTitle("角色特殊能力设置"),
	{
		name = "init_familiar_enable",
		label = "小动物亲和",
		options = {
			{ description = "关闭", data = false, hover = "角色会吓跑小动物" },
			{ description = "开启", data = true, hover = "角色不会吓跑小动物" }
		},
		default = true,
		hover = "月社妃是否会吓跑小动物"
	},
	{
		name = "init_food_hate",
		label = "食物限制",
		options = {
			{ description = "关闭", data = false, hover = "角色可食用非新鲜食物" },
			{ description = "开启", data = true, hover = "角色只能食用新鲜食物" }
		},
		default = true,
		hover = "月社妃能否食用非新鲜食物"
	},
	{
		name = "init_food_like",
		label = "食物喜好",
		options = {
			{ description = "关闭", data = false, hover = "角色喜欢吃的东西不会有加成" },
			{ description = "开启", data = true, hover = "角色喜欢吃的东西会有加成" }
		},
		default = true,
		hover = "月社妃喜欢吃的东西是否会有加成"
	},
	{
		name = "init_science_unlock",
		label = "自带科技一本",
		options = {
			{ description = "否", data = false, hover = "角色初始不带科技一本" },
			{ description = "是", data = true, hover = "角色初始自带科技一本" }
		},
		default = true,
		hover = "月社妃是否初始自带科技一本"
	},
	{
		name = "init_magic_unlock",
		label = "自带魔法一本",
		options = {
			{ description = "否", data = false, hover = "角色初始不带魔法一本" },
			{ description = "是", data = true, hover = "角色初始自带魔法一本" }
		},
		default = true,
		hover = "月社妃是否初始自带魔法一本"
	},
	{
		name = "init_makebook_enable",
		label = "可制作书籍",
		options = {
			{ description = "关闭", data = false, hover = "角色可制作书籍" },
			{ description = "开启", data = true, hover = "角色可制作书籍" }
		},
		default = true,
		hover = "月社妃是否可制作书籍"
	},
	{
		name = "init_read_enable",
		label = "读书能力",
		options = {
			{ description = "关闭", data = false, hover = "角色不可读书" },
			{ description = "开启", data = true, hover = "角色可读书" }
		},
		default = true,
		hover = "月社妃是否可阅读书籍"
	},
	{
		name = "init_bramble_resistant",
		label = "抗荆棘能力",
		options = {
			{ description = "关闭", data = false, hover = "角色受到荆棘伤害" },
			{ description = "开启", data = true, hover = "角色不受荆棘伤害" }
		},
		default = true,
		hover = "月社妃是否会受到荆棘伤害"
	},
	{
		name = "init_delete_curse",
		label = "自动删除诅咒物",
		options = {
			{ description = "关闭", data = false, hover = "角色不删除诅咒物" },
			{ description = "开启", data = true, hover = "角色自动删除诅咒物" }
		},
		default = true,
		hover = "月社妃是否自动删除诅咒物"
	},
	{
		name = "init_sanityaura",
		label = "回san光环",
		options = {
			{ description = "关闭", data = false, hover = "角色附近队友没有回san光环" },
			{ description = "开启", data = true, hover = "角色附近队友有回san光环" }
		},
		default = true,
		hover = "月社妃附近队友是否有回san"
	},
	{
		name = "init_fast_build",
		label = "快速制作",
		options = {
			{ description = "关闭", data = false, hover = "角色制作和威尔逊一致" },
			{ description = "开启", data = true, hover = "角色制作物品加速" }
		},
		default = true,
		hover = "月社妃制作物品加速"
	},
	{
		name = "init_gost_fast",
		label = "灵魂加速",
		options = {
			{ description = "关闭", data = false, hover = "角色死亡后移速不变" },
			{ description = "开启", data = true, hover = "角色死亡后移速加快" }
		},
		default = true,
		hover = "月社妃灵魂状态加速"
	},
	{
		name = "init_stronggr",
		label = "武器不脱手",
		options = {
			{ description = "关闭", data = false, hover = "角色武器会脱手" },
			{ description = "开启", data = true, hover = "角色武器不会脱手" }
		},
		default = true,
		hover = "月社妃是否会因为潮湿等原因脱手"
	},
	{
		name = "init_health_punishment",
		label = "掉血惩罚",
		options = {
			{ description = "关闭", data = false, hover = "角色移动速度不随血量变化" },
			{ description = "开启", data = true, hover = "角色移动速度随血量降低降低" }
		},
		default = true,
		hover = "月社妃移动速度是否随血量降低降低"
	},
	{
		name = "init_sanity_punishment",
		label = "低SAN/高启蒙惩罚",
		options = {
			{ description = "关闭", data = false, hover = "角色随着SAN下降不会影响疯狂光环" },
			{ description = "开启", data = true, hover = "角色随着SAN下降会影响疯狂光环" }
		},
		default = true,
		hover = "月社妃受到疯狂光环的影响是否随SAN降低降低"
	}
}
