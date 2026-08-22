local Widget = require "widgets/widget"
local Button = require "widgets/button"
---------------------------------------------------------------------------------------------------------------------------------------------------------------

--角色的魔法值UI（这段代码只在客户端执行）
local function KisakiMagicInit(self)
    if self.owner:HasTag("kisaki") then
        -- 获取组件badge
        local KisakiMagicBadge = require("widgets/kisaki_magicbadge")
        self.kisaki_magic = self:AddChild(Button())
        self.kisaki_magic_real = self.kisaki_magic:AddChild(KisakiMagicBadge(self.owner))
        self.kisaki_magic:SetOnClick(function()
            self.kisaki_magic_real.onclick(self.kisaki_magic_real, self.kisaki_magic_real.owner)
        end)
        -- 配置显示地点
        self.owner:DoTaskInTime(0, function()
            local x1, y1, z1 = self.stomach:GetPosition():Get()
            local x2, y2, z2 = self.brain:GetPosition():Get()
            local x3, y3, z3 = self.heart:GetPosition():Get()
            local post
            if y2 == y1 or y2 == y3 then --开了三维mod
                post = self.stomach:GetPosition() + Vector3(x1 - x2, 0, 0)
            else
                post = self.stomach:GetPosition() + Vector3(x1 - x3, 0, 0)
            end
            if post then
                self.kisaki_magic:SetPosition(post)
            end
            -- 使得可以拖拽
            KisakiMakeDragableUI(self.kisaki_magic, self.kisaki_magic_real, "kisaki_magic_badge", { drag_offset = 0.8 })
        end)
        -- 角色死亡影藏
        local old_SetGhostMode = self.SetGhostMode
        function self:SetGhostMode(ghostmode, ...)
            old_SetGhostMode(self, ghostmode, ...)
            if ghostmode then
                if self.kisaki_magic ~= nil then
                    self.kisaki_magic:Hide()
                end
            else
                if self.kisaki_magic ~= nil then
                    self.kisaki_magic:Show()
                end
            end
        end
    end
end
AddClassPostConstruct("widgets/statusdisplays", KisakiMagicInit)

---------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 角色信息UI（这段代码只在客户端执行）
local function AddUserInfoUI(self)
    if self.owner:HasTag("kisaki") then
        -- 获取UI并配置
        local KisakiInfoBadge = require("widgets/kisaki_infobadge")
        self.kisaki_info = self:AddChild(Widget("ROOT"))
        self.kisaki_info_real = self.kisaki_info:AddChild(KisakiInfoBadge(self.owner))
        -- 使得可以拖拽
        KisakiMakeDragableUI(self.kisaki_info, self.kisaki_info_real, "kisaki_info_badge", { drag_offset = 0.8 })
        -- 角色死亡隐藏
        local old_SetGhostMode = self.SetGhostMode
        function self:SetGhostMode(ghostmode, ...)
            old_SetGhostMode(self, ghostmode, ...)
            if ghostmode then
                if self.kisaki_info ~= nil then
                    self.kisaki_info:Hide()
                end
            else
                if self.kisaki_info ~= nil then
                    self.kisaki_info:Show()
                end
            end
        end
    end
end
AddClassPostConstruct("widgets/controls", AddUserInfoUI)
