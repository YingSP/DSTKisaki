--角色的魔法值
local function KisakiSanityInit(self)
    if self.owner.prefab == "kisaki" then
        -- 获取组件badge
        local KisakiSanityBadge = require("widgets/kisaki_sanitybadge")
        self.kisaki_sanity = self:AddChild(KisakiSanityBadge(self.owner))
        -- 配置显示地点
        self.owner:DoTaskInTime(0.1, function()
            local x1, y1, z1 = self.stomach:GetPosition():Get()
            local x2, y2, z2 = self.brain:GetPosition():Get()
            local x3, y3, z3 = self.heart:GetPosition():Get()
            if y2 == y1 or y2 == y3 then  --开了三维mod
                self.kisaki_sanity:SetPosition(self.stomach:GetPosition() + Vector3(x1 - x2, 0, 0))
            else
                self.kisaki_sanity:SetPosition(self.stomach:GetPosition() + Vector3(x1 - x3, 0, 0))
            end
        end)
        -- 角色死亡影藏
        local old_SetGhostMode = self.SetGhostMode
        function self:SetGhostMode(ghostmode, ...)
            old_SetGhostMode(self, ghostmode, ...)
            if ghostmode then
                if self.kisaki_sanity ~= nil then
                    self.kisaki_sanity:Hide()
                end
            else
                if self.kisaki_sanity ~= nil then
                    self.kisaki_sanity:Show()
                end
            end
        end
    end
end

AddClassPostConstruct("widgets/statusdisplays", KisakiSanityInit)
