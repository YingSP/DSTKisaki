Assets = {
    -- 选人界面角色名字
    Asset("ATLAS", "images/names_kisaki.xml"),
    -- 选人界面大图
    Asset("ATLAS", "bigportraits/kisaki.xml"),
    Asset("ATLAS", "bigportraits/kisaki_none.xml"),
    -- 角色存档图片
    Asset("ATLAS", "images/saveslot_portraits/kisaki.xml"),
    -- 选人界面小图
    Asset("ATLAS", "images/selectscreen_portraits/kisaki.xml"),
    -- 人物地图图标
    Asset("ATLAS", "images/map_icons/kisaki.xml"),
    -- tab键人物列表显示的头像(正常+鬼魂)
    Asset("ATLAS", "images/avatars/avatar_kisaki.xml"),
    Asset("ATLAS", "images/avatars/avatar_ghost_kisaki.xml"),
    -- 自我审视按钮图片
    Asset("ATLAS", "images/avatars/self_inspect_kisaki.xml"),


    -- 角色组件UI
    Asset('ANIM', 'anim/status_kisaki_sanity.zip'),
}

-- 注册地图图标(还需要在prefeb引用)
AddMinimapAtlas("images/map_icons/kisaki.xml")
