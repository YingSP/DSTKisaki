-- 内置CD
function KisakiCD(ti, real)
    local t = ti
    local last = -ti
    local get = real and GetTimeRealSeconds or GetTime
    return function()
        local ct = get()
        if (ct - t) > last then
            last = ct
            return true
        end
        return false
    end
end

-- UI拖拽相关（代码来自勋章）每次重启都在原地址初始化一下，然后把UI移动到本地存储的位置
local uiloot = {}  -- UI列表，方便重置
local dragpos = {} -- 拖拽坐标，局部变量存储，减少io操作
-- 从本地文件中加载UI点位数据
local function loadDragPos()
    TheSim:GetPersistentString("kisaki_drag_pos", function(load_success, data)
        if load_success and data ~= nil then
            local success, allpos = RunInSandbox(data)
            if success and allpos ~= nil and type(allpos) == "table" then
                for k, v in pairs(allpos) do
                    if dragpos[k] == nil then
                        dragpos[k] = Vector3(v.x or 0, v.y or 0, v.z or 0)
                    end
                end
            end
        end
    end)
end
-- 存储拖拽后坐标
local function saveDragPos(dragtype, pos)
    if next(dragpos) then
        local str = DataDumper(dragpos, nil, true)
        TheSim:SetPersistentString("kisaki_drag_pos", str, false)
    end
end
-- 获取拖拽坐标
function KisakiGetDragPos(dragtype)
    if dragpos[dragtype] == nil then
        loadDragPos()
    end
    return dragpos[dragtype]
end

-- 重置拖拽坐标
function KisakiResetUIPos()
    dragpos = {}
    TheSim:SetPersistentString("kisaki_drag_pos", "", false)
    for k, v in pairs(uiloot) do
        if k.inst and k.inst:IsValid() then
            k:SetPosition(v) -- 重置坐标
        else
            uiloot[k] = nil  -- 失效了的就清掉吧
        end
    end
end

-- 设置UI可拖拽(self,拖拽目标,拖拽标签key,拖拽信息)
function KisakiMakeDragableUI(self, dragtarget, dragtype, dragdata, defaultpos)
    self.kisakicandrag = true         -- 可拖拽标识(防止重复添加拖拽功能)
    uiloot[self] = defaultpos or self:GetPosition() -- 存储UI默认坐标
    -- 设置右键拖拽
    if dragtarget then
        local oldOnControl = dragtarget.OnControl
        dragtarget.OnControl = function(self, control, down, ...)
            local parentwidget = self:GetParent() -- 控制父类的坐标,而不是它自己
            --按下右键可拖动
            if parentwidget and parentwidget.Kisaki_Passive_OnControl then
                parentwidget:Kisaki_Passive_OnControl(control, down)
            end
            if oldOnControl then
                return oldOnControl(self, control, down, ...)
            end
        end
    end
    -- 被控制(控制状态，是否按下)
    function self:Kisaki_Passive_OnControl(control, down)
        if self.focus and control == CONTROL_SECONDARY then
            if down then
                self:KisakiStartDrag()
            else
                self:KisakiEndDrag()
            end
        end
    end

    -- 开始拖动
    function self:KisakiStartDrag()
        if not self.followhandler then
            local mousepos = TheInput:GetScreenPosition()
            self.m_startpos = mousepos           -- 鼠标初始坐标
            self.p_startpos = self:GetPosition() -- 面板初始坐标
            self.followhandler = TheInput:AddMoveHandler(function(x, y)
                self:KisakiSetDragPosition(x, y, 0)
                if not Input:IsMouseDown(MOUSEBUTTON_RIGHT) then
                    self:KisakiEndDrag()
                end
            end)
            self:KisakiSetDragPosition(mousepos)
        end
    end

    -- 停止拖动
    function self:KisakiEndDrag()
        if self.followhandler then
            self.followhandler:Remove()
        end
        self.followhandler = nil
        self.m_startpos = nil
        self.p_startpos = nil
        local newpos = self:GetPosition()
        if dragtype then
            dragpos[dragtype] = newpos --记录记录拖拽后坐标
        end
        saveDragPos()                  --存储坐标
    end

    -- 设置拖拽坐标
    function self:KisakiSetDragPosition(x, y, z)
        local pos
        if type(x) == "number" then
            pos = Vector3(x, y, z)
        else
            pos = x
        end

        local self_scale = self:GetScale()
        local offset = dragdata and dragdata.drag_offset or 1                              -- 偏移修正(容器是0.6)
        local newpos = self.p_startpos + (pos - self.m_startpos) / (self_scale.x / offset) -- 修正偏移值
        self:SetPosition(newpos)                                                           -- 设定新坐标
    end
end

-- 使UI可移动
function KisakiMakeWidgetMovable(s, name, pos, data)
    -- 第一个参数为UI实体 第二个参数为 位置存档的名称 注意如果是一个UI的多个实体 记得不同名称
    -- 第三个参数为默认位置 要求为Vector3 或者为空
    -- 第四个参数为扩展属性 是一个table 或者 nil 描述了实体的对齐的问题
    -- 第五个参数是按键
    s.onikirimovable = {} --初始化表
    local m = s.onikirimovable
    m.nullfn = function() end
    m.name = name or "default" --存储位置名称，默认为"default"
    m.self = s --存储UI实体
    m.downtime = 0 --鼠标按下时间
    m.whiletime = 0.4 --触发拖动的时间阈值
    m.cd = KisakiCD(0.5) --创建一个内置cd，用于限制拖动频率
    m.dpos = pos or Vector3(0, 0, 0) --默认位置向量
    m.pos = pos or Vector3(0, 0, 0) --当前位置向量
    m.ha = data and data.ha or 1 --水平对其
    m.va = data and data.va or 2 --垂直对其

    --从存档中读取位置信息
    m.x, m.y = TheSim:GetScreenSize()
    TheSim:GetPersistentString(m.name, function(load_success, str)
        if load_success then
            local fn = loadstring(str) --将字符串转换为函数
            if type(fn) == "function" then
                m.pos = fn() --调用函数获取位置向量
                if not (type(m.pos) == "table" and m.pos.Get) then
                    m.pos = pos --如果位置不对，则使用默认位置
                end
            end
        end
    end)
    s:SetPosition(m.pos:Get()) --设置UI实体的位置为读取到的位置

    m.OnControl = s.OnControl or m.nullfn
    s.OnControl = function(self, control, down)
        if  self.focus and control == CONTROL_ACCEPT then
            if down then
                if not m.down then
                    m.down = true
                    m.downtime = 0
                end
            else
                if m.down then
                    m.down = false
                    m.OnClick(self) --OnClick方法
                end
            end
        end
        return m.OnControl(self, control, down)
    end
    --重写UI实体的OnRawKey方法，实现快捷键操作
    m.OnRawKey = s.OnRawKey or m.nullfn
    s.OnRawKey = function(self, key, down, ...)
        if s.focus and key == KEY_SPACE and not down and not m.cd() then
            s:SetPosition(m.dpos:Get()) --位置重置为默认位置
            TheSim:SetPersistentString(m.name, string.format(
                                           "return Vector3(%d,%d,%d)",
                                           m.dpos:Get()), false) --重置后的位置存入存档
        end
        return m.OnRawKey(self, key, down, ...)
    end

    m.OnClick = function(self)
        m:StopFollowMouse()
        if m.downtime > m.whiletime then
            local newpos = self:GetPosition()
            if TUNING.FLDEBUGCOMMAND then
                print(s, name, newpos:Get())
            end
            TheSim:SetPersistentString(m.name, string.format(
                                           "return Vector3(%f,%f,%f)",
                                           newpos:Get()), false)
        end
        if m.lastx and m.lasty and s.o_pos then
            s.o_pos = Vector3(m.lastx, m.lasty, 0)
        end
    end

    m.OnUpdate = s.OnUpdate or m.nullfn
    s.OnUpdate = function(self, dt)
        if m.down then if m.whiledown then m.whiledown(self) end end
        return m.OnUpdate(self, dt)
    end
    m.whiledown = function(self)
        m.downtime = m.downtime + 0.033
        if m.downtime > m.whiletime then m.FollowMouse(self) end
    end
    m.UpdatePosition = function(self, x, y)
        local sx, sy = s.parent.GetScale(s.parent):Get()
        local ox, oy = s.parent.GetWorldPosition(s.parent):Get()
        local nx = (x - ox) / sx
        if m.ha == 0 then
            x = x - m.x / 2
            nx = (x - ox) / sx
        elseif m.ha == 2 then
            x = x - m.x
            nx = (x - ox) / sx
        end
        local ny = (y - oy) / sy
        if m.va == 0 then
            y = y - m.y / 2
            ny = (y - oy) / sy
        elseif m.va == 1 then
            y = y - m.y
            ny = (y - oy) / sy
        end
        m.lastx = nx
        m.lasty = ny
        s.SetPosition(self, nx, ny, 0)
    end
    m.FollowMouse = function(self)

        if m.followhandler == nil then
            m.followhandler = TheInput:AddMoveHandler(function(x, y)
                    m.UpdatePosition(self, x, y)
                end)
            local spos = TheInput:GetScreenPosition()
            m.UpdatePosition(self, spos.x, spos.y)
            -- self:SetPosition()
        end
    end
    m.StopFollowMouse = function(self)
        if m.followhandler ~= nil then
            m.followhandler:Remove()
            m.followhandler = nil
        end
    end
    s:StartUpdating()
end

GLOBAL.KisakiCD = KisakiCD
GLOBAL.KisakiMakeDragableUI = KisakiMakeDragableUI               -- 设置UI可拖拽(右键)
GLOBAL.KisakiGetDragPos = KisakiGetDragPos                       -- 获取拖拽UI坐标
GLOBAL.KisakiResetUIPos = KisakiResetUIPos                       -- 重置拖拽UI坐标
GLOBAL.KisakiMakeWidgetMovable = KisakiMakeWidgetMovable         -- 使UI可拖拽(左键)
