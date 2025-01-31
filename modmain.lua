-- 饥荒联机版的lua版本为5.1.4，注意不要使用过高版本开发
-- 全局代理。任何全局变量的访问都会被重定向到GLOBAL的全局表中的相应条目。
GLOBAL.setmetatable(env, {
    __index = function(t, k)
        return GLOBAL.rawget(GLOBAL, k)
    end
})

-- 导入模组常用方法
modimport("modmain/utils/api")
-- 导入皮肤api
modimport("modmain/framework/skinapi")
-- 加载角色全局配置
modimport("modmain/common/tuning")
-- 加载模组动画/声音资源
modimport("modmain/common/assets")
-- 定义物品制作配方
modimport("modmain/common/recipes")
-- 模组背包(箱子)定义
modimport("modmain/common/containers")
-- 加载角色语句
modimport("modmain/languages/kisaki_strings_chs")
-- 加载模组特效
modimport("modmain/common/fx")
-- 加载模组UI
modimport("modmain/common/ui")
-- 修改原版组件/预制物逻辑
modimport("modmain/common/hook")
-- 加载模组预制物
modimport("modmain/common/prefabs")


-- 添加角色(无皮肤定义)
AddModCharacter("kisaki", "FEMALE") --MALE男, FEMALE女, ROBOT机器人, NEUTRAL中性, PLURAL双性
