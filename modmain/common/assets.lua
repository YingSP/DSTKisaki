local avatar_name = "kisaki"

Assets = {
    -- 选人界面角色名字
    Asset("ATLAS", "images/names_" .. avatar_name .. ".xml"),
    -- 选人界面大图
    Asset("ATLAS", "bigportraits/" .. avatar_name .. ".xml"),
    Asset("ATLAS", "bigportraits/" .. avatar_name .. "_none.xml"),
    -- 角色存档图片
    Asset("ATLAS", "images/saveslot_portraits/" .. avatar_name .. ".xml"),
    -- 选人界面小图
    Asset("ATLAS", "images/selectscreen_portraits/" .. avatar_name .. ".xml"),
    -- 人物地图图标
    Asset("ATLAS", "images/map_icons/" .. avatar_name .. ".xml"),
    -- tab键人物列表显示的头像(正常+鬼魂)
    Asset("ATLAS", "images/avatars/avatar_" .. avatar_name .. ".xml"),
    Asset("ATLAS", "images/avatars/avatar_ghost_" .. avatar_name .. ".xml"),
    -- 自我审视按钮图片
    Asset("ATLAS", "images/avatars/self_inspect_" .. avatar_name .. ".xml"),

    -- 角色组件UI
    Asset('ANIM', 'anim/status_kisaki_sanity.zip'),
}

-- 注册地图图标(还需要在prefeb引用)
AddMinimapAtlas("images/map_icons/" .. avatar_name .. ".xml")

local widgets = {
    "kisaki_magic",
    "kisaki_character",
}
for key, value in pairs(widgets) do
    table.insert(Assets, Asset("IMAGE", "images/inventoryimages/widget/" .. value .. ".tex"))
    table.insert(Assets, Asset("ATLAS", "images/inventoryimages/widget/" .. value .. ".xml"))
end