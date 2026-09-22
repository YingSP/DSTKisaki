local Wheel = require "widgets/wheel"
local PlayerBadge = require "widgets/playerbadge"

-- 按 V 切换显示的玩家选择轮盘。
-- 轮盘只负责展示客户端玩家列表和提交 userid，传送是否合法由服务端判断。
local PlayerTeleportWheel = Class(Wheel, function(self, owner)
    Wheel._ctor(self, "KisakiPlayerTeleportWheel", owner, { ignoreleftstick = true })
    self.OnExecute = function(wheel)
        wheel:Close()
    end
    self.OnCancel = self.OnExecute
    self.refresh_time = 0
    self.is_active = false
end)

-- 客户端只检查当前装备和模式，用于决定是否显示轮盘。
-- 服务端仍会对这些条件进行独立校验，不能把客户端判断当作权限验证。
local function GetStaff(owner)
    local inventory = owner.replica.inventory
    local staff = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    return staff ~= nil
        and (staff.prefab == "kisaki_magic_staff" or staff.prefab == "kisaki_magic_staff_max")
        and staff:HasTag("kisaki_staff_mode_teleport")
end

-- 轮盘只能在游戏 HUD 中打开，避免覆盖法术书/指令轮盘或其他前端界面。
function PlayerTeleportWheel:CanOpen()
    local owner = self.owner
    return owner ~= nil and owner:IsValid() and ThePlayer == owner
        and owner.HUD ~= nil and TheFrontEnd:GetActiveScreen() == owner.HUD
        and not TheInput:ControllerAttached()
        and not owner:HasTag("playerghost")
        and owner.HUD.controls ~= nil
        and not owner.HUD.controls.spellwheel:IsOpen()
        and not owner.HUD.controls.commandwheel:IsOpen()
        and GetStaff(owner)
end

-- 使用 Tab 玩家列表相同的数据源。
-- 专用服务器占位项没有实际玩家实体，因此不放入可选择列表。
local function GetPlayerData(owner)
    local players = {}
    for _, client in ipairs(TheNet:GetClientTable() or {}) do
        if client.userid ~= nil and client.userid ~= "" and client.userid ~= owner.userid
            and (TheNet:GetServerIsClientHosted() or client.performance == nil) then
            table.insert(players, client)
        end
    end
    return players
end

-- 玩家列表变化检测：玩家加入、离开、换角色或头像信息更新时重建轮盘。
local function GetSignature(players)
    local parts = {}
    for _, client in ipairs(players) do
        table.insert(parts, table.concat({
            client.userid or "", client.prefab or "", client.name or "",
            client.base_skin or "", tostring(client.userflags or 0),
            tostring(client.colour and client.colour[1] or ""),
        }, ":"))
    end
    return table.concat(parts, "|")
end

-- 根据当前玩家列表构建轮盘条目和头像框。
function PlayerTeleportWheel:Refresh(players)
    self.signature = GetSignature(players)
    local items = {}
    for _, client in ipairs(players) do
        local userid = client.userid
        local prefab = client.prefab or client.lobbycharacter or ""
        local colour = client.colour or DEFAULT_PLAYER_COLOUR
        local ishost = client.performance ~= nil
        local userflags = client.userflags or 0
        local base_skin = client.base_skin
        table.insert(items, {
            label = client.name or "",
            atlas = "images/global.xml",
            normal = "square.tex",
            hit_radius = 38,
            postinit = function(button)
                button.image:SetSize(76, 76)
                button:SetImageNormalColour(0, 0, 0, 0)
                button:SetImageFocusColour(0, 0, 0, 0)
                local badge = button:AddChild(PlayerBadge(prefab, colour, ishost, userflags))
                badge:Set(prefab, colour, ishost, userflags, base_skin)
                badge:SetScale(.7)
            end,
            -- 点击头像时只发送 userid，不发送客户端坐标。
            execute = function()
                if self.is_active and self:CanOpen() then
                    SendModRPCToServer(MOD_RPC["kisaki"]["MagicStaffPlayerTeleport"], userid)
                end
            end,
        })
    end

    if self:IsOpen() then
        Wheel.Close(self)
    end
    if #items == 0 then
        self:StartUpdating()
        return
    end
    -- 每圈最多放置 10 个头像，人数较多时向外增加一圈。
    self:SetItems(items, 125, 129)
    for index, item in ipairs(items) do
        local ring = math.floor((index - 1) / 10)
        local ring_index = (index - 1) % 10
        local ring_count = math.min(10, #items - ring * 10)
        local angle = ring_index * TWOPI / ring_count
        item.pos_dir = Vector3(math.sin(angle), math.cos(angle), 0)
        item.pos = item.pos_dir * (125 + ring * 95)
        item.focus_pos = item.pos_dir * (129 + ring * 95)
    end
    self:Open()
    self:StartUpdating()
end

-- 轮盘展开期间监测装备、界面和玩家列表变化。
function PlayerTeleportWheel:OnUpdate(dt)
    if not self:CanOpen() then
        self:Close()
        return
    end

    self.refresh_time = self.refresh_time + dt
    if self.refresh_time >= .3 then
        self.refresh_time = 0
        local players = GetPlayerData(self.owner)
        if self.signature ~= GetSignature(players) then
            self:Refresh(players)
        end
    end
end

-- 每次按 V 切换展开/关闭，键盘自动重复由按键映射拦截。
function PlayerTeleportWheel:TogglePlayers()
    if self.is_active then
        self:Close()
        return
    end
    if self:CanOpen() then
        self.is_active = true
        self:SetScale(TheFrontEnd:GetProportionalHUDScale())
        self:Refresh(GetPlayerData(self.owner))
    end
end

-- 再按 V、选中头像、法杖卸下或界面切换时关闭轮盘。
function PlayerTeleportWheel:Close()
    self.is_active = false
    Wheel.Close(self)
    self:StopUpdating()
end

return PlayerTeleportWheel
