local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

-- ============================================
-- FLUID ANIMATION SYSTEM
-- ============================================
local FluidAnim = {
    Tweens = {},
    DefaultDuration = 0.3,
    DefaultStyle = Enum.EasingStyle.Quad,
    DefaultDirection = Enum.EasingDirection.Out
}

function FluidAnim:TweenObject(obj, properties, duration, style, direction)
    duration = duration or self.DefaultDuration
    style = style or self.DefaultStyle
    direction = direction or self.DefaultDirection
    
    -- Cancel existing tween on this object
    if self.Tweens[obj] then
        self.Tweens[obj]:Cancel()
        self.Tweens[obj] = nil
    end
    
    local tween = TweenService:Create(obj, TweenInfo.new(
        duration,
        style,
        direction,
        0,
        false,
        0
    ), properties)
    
    tween:Play()
    self.Tweens[obj] = tween
    
    -- Auto-cleanup
    tween.Completed:Connect(function()
        self.Tweens[obj] = nil
    end)
    
    return tween
end

function FluidAnim:CancelAll()
    for obj, tween in pairs(self.Tweens) do
        tween:Cancel()
    end
    self.Tweens = {}
end

-- ============================================
-- SMOOTH DRAG SYSTEM
-- ============================================
local SmoothDrag = {
    Active = false,
    Dragging = false,
    StartPos = nil,
    CurrentPos = nil,
    TargetPos = nil,
    Velocity = Vector2.new(0, 0),
    Smoothness = 0.15,
    Damping = 0.92,
    MenuObject = nil,
    DragOffset = Vector2.new(0, 0),
    Connection = nil,
    Inertia = false,
    InertiaTimer = nil
}

function SmoothDrag:Start(menu, input)
    if not menu or not input then return end
    if self.Active then return end
    
    self.Active = true
    self.Dragging = true
    self.Inertia = false
    self.MenuObject = menu
    self.StartPos = menu.Position
    self.DragOffset = Vector2.new(
        input.Position.X - menu.AbsolutePosition.X,
        input.Position.Y - menu.AbsolutePosition.Y
    )
    self.Velocity = Vector2.new(0, 0)
    
    if self.InertiaTimer then
        self.InertiaTimer:Disconnect()
        self.InertiaTimer = nil
    end
    
    if not self.Connection then
        self.Connection = RunService.RenderStepped:Connect(function()
            self:Update()
        end)
    end
end

function SmoothDrag:Update()
    if not self.Active then return end
    if not self.MenuObject or not self.MenuObject.Parent then
        self:Stop()
        return
    end
    
    local viewportSize = game:GetService('Workspace').CurrentCamera.ViewportSize
    local menuSize = self.MenuObject.AbsoluteSize
    
    if self.Dragging then
        -- Mouse-based dragging
        local targetX = Mouse.X - self.DragOffset.X
        local targetY = Mouse.Y - self.DragOffset.Y
        
        -- Clamp to viewport
        targetX = math.clamp(targetX, 0, viewportSize.X - menuSize.X)
        targetY = math.clamp(targetY, 0, viewportSize.Y - menuSize.Y)
        
        local currentPos = self.MenuObject.Position
        local targetPos = UDim2.fromOffset(targetX, targetY)
        
        -- Smooth interpolation
        local lerpedX = currentPos.X.Offset + (targetX - currentPos.X.Offset) * self.Smoothness
        local lerpedY = currentPos.Y.Offset + (targetY - currentPos.Y.Offset) * self.Smoothness
        
        self.MenuObject.Position = UDim2.fromOffset(lerpedX, lerpedY)
        
        -- Calculate velocity for inertia
        local velocityX = (targetX - currentPos.X.Offset) * 0.5
        local velocityY = (targetY - currentPos.Y.Offset) * 0.5
        self.Velocity = Vector2.new(velocityX, velocityY)
    elseif self.Inertia then
        -- Inertia mode
        self.Velocity = self.Velocity * self.Damping
        
        if self.Velocity.Magnitude < 0.1 then
            self.Inertia = false
            return
        end
        
        local currentPos = self.MenuObject.Position
        local newX = currentPos.X.Offset + self.Velocity.X
        local newY = currentPos.Y.Offset + self.Velocity.Y
        
        -- Clamp with inertia
        newX = math.clamp(newX, 0, viewportSize.X - menuSize.X)
        newY = math.clamp(newY, 0, viewportSize.Y - menuSize.Y)
        
        -- Smooth deceleration
        local lerpedX = currentPos.X.Offset + (newX - currentPos.X.Offset) * 0.3
        local lerpedY = currentPos.Y.Offset + (newY - currentPos.Y.Offset) * 0.3
        
        self.MenuObject.Position = UDim2.fromOffset(lerpedX, lerpedY)
    end
end

function SmoothDrag:Stop()
    if self.Active and self.Dragging then
        -- Start inertia
        if self.Velocity.Magnitude > 2 then
            self.Inertia = true
            self.Dragging = false
            
            -- Auto-stop inertia after timeout
            if self.InertiaTimer then
                self.InertiaTimer:Disconnect()
            end
            self.InertiaTimer = game:GetService('Debris'):AddItem(Instance.new('BoolValue'), 2)
            self.InertiaTimer.Parent = nil
            task.wait(2)
            self.Inertia = false
            self.Velocity = Vector2.new(0, 0)
        else
            self.Velocity = Vector2.new(0, 0)
        end
    end
    
    self.Active = false
    self.Dragging = false
end

function SmoothDrag:StopFull()
    self.Active = false
    self.Dragging = false
    self.Inertia = false
    self.Velocity = Vector2.new(0, 0)
    self.MenuObject = nil
    
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    
    if self.InertiaTimer then
        self.InertiaTimer:Disconnect()
        self.InertiaTimer = nil
    end
end

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(0, 85, 255);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50);
    TabColor = Color3.fromRGB(35, 35, 35);
    TabHoverColor = Color3.fromRGB(45, 45, 45);
    TabActiveColor = Color3.fromRGB(0, 85, 255);

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;
    
    -- Animation system
    Anim = FluidAnim;
    Drag = SmoothDrag;
    
    -- Tab system
    Tabs = {};
    ActiveTab = nil;
    TabContainer = nil;
    ContentContainer = nil;
};

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();

    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;

    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();

    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;

    table.sort(TeamList, function(str1, str2) return str1 < str2 end);

    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;

    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end;

        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;

    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;

    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;

    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;

    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });

    Library:ApplyTextStroke(_Instance);

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end;

-- ============================================
-- MODIFIED: SMOOTH DRAG ON WINDOW
-- ============================================
function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;

    local dragOffset = Vector2.new(0, 0);
    local isDragging = false;
    local connection = nil;

    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );

            if ObjPos.Y > (Cutoff or 40) then
                return;
            end;

            -- Use smooth drag system
            Library.Drag:Start(Instance, Input);
            
            -- Stop drag on release
            connection = InputService.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == Enum.UserInputType.MouseButton1 then
                    Library.Drag:Stop();
                    if connection then
                        connection:Disconnect();
                        connection = nil;
                    end
                end
            end);
        end;
    end);
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,

        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = Library.ScreenGui,

        Visible = false,
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,

        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    -- Stop drag
    Library.Drag:StopFull();
    
    -- Cancel all animations
    Library.Anim:CancelAll();
    
    -- Unload all of the signals
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

    -- Call our unload callback
    if Library.OnUnload then
        Library.OnUnload()
    end

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

-- ============================================
-- MODIFIED: WINDOW CREATION WITH NEW LAYOUT
-- ============================================
function Library:CreateWindow(Options)
    Options = Options or {};
    Options.Title = Options.Title or 'Linoria';
    Options.Size = Options.Size or UDim2.fromOffset(650, 450);
    Options.Position = Options.Position or UDim2.new(0.5, -325, 0.5, -225);
    Options.TabPadding = Options.TabPadding or 8;

    local Window = {};
    Window.Tabs = {};
    Window.Groups = {};

    local Main = Library:Create('Frame', {
        Name = 'Main',
        BackgroundColor3 = Library.BackgroundColor,
        BorderColor3 = Library.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Size = Options.Size,
        Position = Options.Position;
        Active = true,
        Visible = false,
        ZIndex = 2,
        Parent = Library.ScreenGui,
    });

    Library:AddToRegistry(Main, {
        BackgroundColor3 = 'BackgroundColor';
        BorderColor3 = 'OutlineColor';
    });

    -- Title bar
    local TitleBar = Library:Create('Frame', {
        Name = 'TitleBar';
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Size = UDim2.new(1, 0, 0, 30);
        ZIndex = 3,
        Parent = Main,
    });

    Library:AddToRegistry(TitleBar, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    local TitleLabel = Library:CreateLabel({
        Name = 'Title';
        Size = UDim2.new(1, -35, 1, 0);
        Position = UDim2.new(0, 10, 0, 0);
        Text = Options.Title;
        TextSize = 16;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 4,
        Parent = TitleBar,
    });

    -- Close button
    local CloseButton = Library:Create('TextButton', {
        Name = 'CloseButton';
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Size = UDim2.new(0, 25, 1, 0);
        Position = UDim2.new(1, -25, 0, 0);
        Text = '✕';
        TextColor3 = Library.FontColor;
        TextSize = 14;
        Font = Library.Font;
        ZIndex = 4,
        Parent = TitleBar,
    });

    Library:AddToRegistry(CloseButton, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
        TextColor3 = 'FontColor';
    });

    CloseButton.MouseEnter:Connect(function()
        CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50);
        CloseButton.TextColor3 = Color3.new(1, 1, 1);
    end);

    CloseButton.MouseLeave:Connect(function()
        CloseButton.BackgroundColor3 = Library.MainColor;
        CloseButton.TextColor3 = Library.FontColor;
    end);

    CloseButton.MouseButton1Click:Connect(function()
        Library:Unload();
    end);

    -- Content container (left sidebar + right content)
    local ContentContainer = Library:Create('Frame', {
        Name = 'ContentContainer';
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 30);
        Size = UDim2.new(1, 0, 1, -30);
        ZIndex = 2,
        Parent = Main,
    });

    -- ============================================
    -- SIDEBAR TABS (Left side)
    -- ============================================
    local Sidebar = Library:Create('Frame', {
        Name = 'Sidebar';
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Size = UDim2.new(0, 150, 1, 0);
        Position = UDim2.new(0, 0, 0, 0);
        ZIndex = 3,
        Parent = ContentContainer,
    });

    Library:AddToRegistry(Sidebar, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    -- Tab list container
    local TabList = Library:Create('Frame', {
        Name = 'TabList';
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -40);
        Position = UDim2.new(0, 0, 0, 40);
        ZIndex = 3,
        Parent = Sidebar,
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Padding = UDim.new(0, 2);
        Parent = TabList,
    });

    -- Content area (right side)
    local ContentArea = Library:Create('ScrollingFrame', {
        Name = 'ContentArea';
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 155, 0, 0);
        Size = UDim2.new(1, -155, 1, 0);
        CanvasSize = UDim2.new(0, 0, 0, 0);
        ScrollBarThickness = 6;
        ScrollBarImageColor3 = Library.AccentColor;
        ZIndex = 2,
        Parent = ContentContainer,
    });

    -- Content wrapper for smooth transitions
    local ContentWrapper = Library:Create('Frame', {
        Name = 'ContentWrapper';
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 0);
        ZIndex = 2,
        Parent = ContentArea,
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Padding = UDim.new(0, 8);
        Parent = ContentWrapper,
    });

    -- ============================================
    -- TAB CREATION
    -- ============================================
    function Window:AddTab(Title)
        local Tab = {
            Title = Title;
            Name = Title;
            Groups = {};
            LeftGroups = {};
            RightGroups = {};
            TabBoxes = {};
            Content = nil;
            Button = nil;
            Visible = false;
        };

        -- Create tab button in sidebar
        local TabButton = Library:Create('TextButton', {
            Name = 'TabButton_' .. Title;
            BackgroundColor3 = Library.TabColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 0, 35);
            Text = Title;
            TextColor3 = Library.FontColor;
            TextSize = 14;
            Font = Library.Font;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextYAlignment = Enum.TextYAlignment.Center;
            ZIndex = 4,
            Parent = TabList,
        });

        -- Add icon padding
        local padding = Library:Create('UIPadding', {
            PaddingLeft = UDim.new(0, 12);
            Parent = TabButton;
        });

        Library:AddToRegistry(TabButton, {
            BackgroundColor3 = 'TabColor';
            BorderColor3 = 'OutlineColor';
            TextColor3 = 'FontColor';
        });

        -- Tab content container
        local TabContent = Library:Create('Frame', {
            Name = 'TabContent_' .. Title;
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            ZIndex = 2,
            Parent = ContentWrapper,
            Visible = false,
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Horizontal;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Padding = UDim.new(0, 8);
            HorizontalAlignment = Enum.HorizontalAlignment.Left;
            Parent = TabContent,
        });

        Tab.Content = TabContent;
        Tab.Button = TabButton;
        Window.Tabs[Title] = Tab;
        table.insert(Window.Tabs, Tab);

        -- Tab selection
        TabButton.MouseButton1Click:Connect(function()
            Window:SelectTab(Tab);
        end);

        TabButton.MouseEnter:Connect(function()
            if Tab ~= Window.ActiveTab then
                TabButton.BackgroundColor3 = Library.TabHoverColor;
                Library.Anim:TweenObject(TabButton, {
                    BackgroundColor3 = Library.TabHoverColor,
                }, 0.15);
            end
        end);

        TabButton.MouseLeave:Connect(function()
            if Tab ~= Window.ActiveTab then
                TabButton.BackgroundColor3 = Library.TabColor;
                Library.Anim:TweenObject(TabButton, {
                    BackgroundColor3 = Library.TabColor,
                }, 0.15);
            end
        end);

        -- Auto-select first tab
        if not Window.ActiveTab then
            Window:SelectTab(Tab);
        end

        -- Groupbox creation methods
        function Tab:AddLeftGroupbox(Title)
            local Group = self:CreateGroupbox(Title, 'Left');
            return Group;
        end;

        function Tab:AddRightGroupbox(Title)
            local Group = self:CreateGroupbox(Title, 'Right');
            return Group;
        end;

        function Tab:CreateGroupbox(Title, Side)
            Side = Side or 'Left';
            
            local Groupbox = {};
            Groupbox.Title = Title;
            Groupbox.Side = Side;
            Groupbox.Objects = {};
            
            local Container = Library:Create('Frame', {
                Name = 'Groupbox_' .. Title;
                BackgroundTransparency = 1;
                Size = UDim2.new(0.5, -4, 0, 0);
                ZIndex = 2,
                Parent = Tab.Content,
            });

            local Header = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset,
                Size = UDim2.new(1, 0, 0, 25);
                ZIndex = 3,
                Parent = Container,
            });

            Library:AddToRegistry(Header, {
                BackgroundColor3 = 'MainColor';
                BorderColor3 = 'OutlineColor';
            });

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, -10, 1, 0);
                Position = UDim2.new(0, 5, 0, 0);
                Text = Title;
                TextSize = 14;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 4,
                Parent = Header,
            });

            local Content = Library:Create('Frame', {
                Name = 'Content';
                BackgroundColor3 = Library.BackgroundColor,
                BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset,
                Size = UDim2.new(1, 0, 0, 0);
                Position = UDim2.new(0, 0, 0, 25);
                ZIndex = 2,
                Parent = Container,
            });

            Library:AddToRegistry(Content, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            local Layout = Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Padding = UDim.new(0, 4);
                HorizontalAlignment = Enum.HorizontalAlignment.Center;
                Parent = Content,
            });

            local Padding = Library:Create('UIPadding', {
                PaddingTop = UDim.new(0, 4);
                PaddingBottom = UDim.new(0, 4);
                PaddingLeft = UDim.new(0, 4);
                PaddingRight = UDim.new(0, 4);
                Parent = Content,
            });

            Groupbox.Container = Container;
            Groupbox.Content = Content;
            Groupbox.Layout = Layout;
            Groupbox.Header = Header;

            function Groupbox:AddElement(Element)
                table.insert(Groupbox.Objects, Element);
                self:Resize();
                return Element;
            end;

            function Groupbox:Resize()
                local contentSize = self.Content.AbsoluteSize;
                local children = self.Content:GetChildren();
                
                local height = 0;
                for _, child in ipairs(children) do
                    if child:IsA('GuiObject') and child.Visible then
                        height = height + child.Size.Y.Offset + 4;
                    end
                end
                
                if height > 0 then
                    self.Content.Size = UDim2.new(1, 0, 0, height + 8);
                    self.Container.Size = UDim2.new(0.5, -4, 0, height + 33);
                end
                
                -- Update canvas
                local wrapper = self.Container.Parent.Parent.Parent;
                if wrapper and wrapper:IsA('ScrollingFrame') then
                    local totalHeight = 0;
                    for _, child in ipairs(wrapper:GetChildren()) do
                        if child:IsA('Frame') and child.Visible then
                            totalHeight = totalHeight + child.Size.Y.Offset + 8;
                        end
                    end
                    wrapper.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20);
                end
            end;

            -- Add methods from BaseGroupbox
            for method, func in pairs(BaseGroupbox) do
                Groupbox[method] = function(self, ...)
                    return func(self, ...);
                end;
            end

            -- Store group
            if Side == 'Left' then
                table.insert(Tab.LeftGroups, Groupbox);
            else
                table.insert(Tab.RightGroups, Groupbox);
            end

            return Groupbox;
        end;

        function Tab:AddLeftTabbox()
            -- Tabbox implementation
            local Tabbox = {};
            Tabbox.Tabs = {};
            Tabbox.ActiveTab = nil;
            
            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Size = UDim2.new(0.5, -4, 0, 0);
                ZIndex = 2,
                Parent = Tab.Content,
            });
            
            -- Tab headers
            local HeaderContainer = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, 25);
                ZIndex = 3,
                Parent = Container,
            });
            
            local TabHeaderLayout = Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Padding = UDim.new(0, 2);
                Parent = HeaderContainer,
            });
            
            -- Content
            local TabContent = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor,
                BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset,
                Size = UDim2.new(1, 0, 0, 0);
                Position = UDim2.new(0, 0, 0, 25);
                ZIndex = 2,
                Parent = Container,
            });
            
            Library:AddToRegistry(TabContent, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });
            
            local ContentLayout = Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Padding = UDim.new(0, 4);
                Parent = TabContent,
            });
            
            local function ResizeTabbox()
                local height = 0;
                for _, child in ipairs(TabContent:GetChildren()) do
                    if child:IsA('Frame') and child.Visible then
                        height = height + child.Size.Y.Offset + 4;
                    end
                end
                TabContent.Size = UDim2.new(1, 0, 0, math.max(height, 20) + 8);
                Container.Size = UDim2.new(0.5, -4, 0, height + 33);
            end
            
            function Tabbox:AddTab(Title)
                local Tab = {};
                Tab.Title = Title;
                Tab.Objects = {};
                
                local TabButton = Library:Create('TextButton', {
                    BackgroundColor3 = Library.TabColor,
                    BorderColor3 = Library.OutlineColor,
                    BorderMode = Enum.BorderMode.Inset,
                    Size = UDim2.new(0, 80, 1, 0);
                    Text = Title;
                    TextColor3 = Library.FontColor;
                    TextSize = 13;
                    Font = Library.Font;
                    ZIndex = 4,
                    Parent = HeaderContainer,
                });
                
                Library:AddToRegistry(TabButton, {
                    BackgroundColor3 = 'TabColor';
                    BorderColor3 = 'OutlineColor';
                    TextColor3 = 'FontColor';
                });
                
                local TabContent = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1, 0, 0, 0);
                    ZIndex = 2,
                    Parent = TabContent,
                    Visible = false,
                });
                
                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Padding = UDim.new(0, 4);
                    Parent = TabContent,
                });
                
                Tab.Button = TabButton;
                Tab.Content = TabContent;
                
                TabButton.MouseButton1Click:Connect(function()
                    Tabbox:SelectTab(Tab);
                end);
                
                table.insert(Tabbox.Tabs, Tab);
                
                if not Tabbox.ActiveTab then
                    Tabbox:SelectTab(Tab);
                end
                
                -- Return an object that can add UI elements
                local TabObject = {};
                
                function TabObject:AddToggle(Idx, Info)
                    return AddToggle(TabContent, Idx, Info);
                end
                
                function TabObject:AddSlider(Idx, Info)
                    return AddSlider(TabContent, Idx, Info);
                end
                
                function TabObject:AddDropdown(Idx, Info)
                    return AddDropdown(TabContent, Idx, Info);
                end
                
                function TabObject:AddLabel(Text, DoesWrap)
                    return AddLabel(TabContent, Text, DoesWrap);
                end
                
                function TabObject:AddButton(...)
                    return AddButton(TabContent, ...);
                end
                
                function TabObject:AddDivider()
                    return AddDivider(TabContent);
                end
                
                function TabObject:AddInput(Idx, Info)
                    return AddInput(TabContent, Idx, Info);
                end
                
                function TabObject:AddDependencyBox()
                    return AddDependencyBox(TabContent);
                end
                
                function TabObject:AddColorPicker(Idx, Info)
                    return AddColorPicker(TabContent, Idx, Info);
                end
                
                function TabObject:AddKeyPicker(Idx, Info)
                    return AddKeyPicker(TabContent, Idx, Info);
                end
                
                return TabObject;
            end
            
            function Tabbox:SelectTab(Tab)
                if Tabbox.ActiveTab then
                    Tabbox.ActiveTab.Button.BackgroundColor3 = Library.TabColor;
                    Tabbox.ActiveTab.Content.Visible = false;
                end
                
                Tabbox.ActiveTab = Tab;
                Tab.Button.BackgroundColor3 = Library.AccentColor;
                Tab.Content.Visible = true;
                
                ResizeTabbox();
            end
            
            return Tabbox;
        end;

        function Tab:AddRightTabbox()
            return self:AddLeftTabbox(); -- Same implementation
        end;

        function Tab:AddDependencyBox()
            return AddDependencyBox(self);
        end

        -- Animation when tab is selected
        function Tab:AnimateIn()
            self.Content.Visible = true;
            self.Content.Position = UDim2.new(0, 20, 0, 0);
            self.Content.Transparency = 1;
            
            Library.Anim:TweenObject(self.Content, {
                Position = UDim2.new(0, 0, 0, 0);
                Transparency = 0;
            }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out);
        end

        function Tab:AnimateOut()
            Library.Anim:TweenObject(self.Content, {
                Position = UDim2.new(0, -20, 0, 0);
                Transparency = 1;
            }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In);
            
            task.wait(0.2);
            self.Content.Visible = false;
        end

        return Tab;
    end

    -- ============================================
    -- TAB SELECTION
    -- ============================================
    function Window:SelectTab(Tab)
        if Window.ActiveTab == Tab then return end;
        
        -- Animate out old tab
        if Window.ActiveTab then
            Window.ActiveTab.Button.BackgroundColor3 = Library.TabColor;
            Window.ActiveTab:AnimateOut();
        end
        
        -- Select new tab
        Window.ActiveTab = Tab;
        Tab.Button.BackgroundColor3 = Library.AccentColor;
        
        -- Animate in new tab
        Tab:AnimateIn();
        
        -- Update content area canvas
        task.wait(0.1);
        local wrapper = Tab.Content.Parent;
        if wrapper and wrapper:IsA('ScrollingFrame') then
            local totalHeight = 0;
            for _, child in ipairs(wrapper:GetChildren()) do
                if child:IsA('Frame') and child.Visible then
                    totalHeight = totalHeight + child.Size.Y.Offset + 8;
                end
            end
            wrapper.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20);
        end
        
        Library:UpdateColorsUsingRegistry();
    end

    -- ============================================
    -- WINDOW VISIBILITY
    -- ============================================
    function Window:Show()
        Main.Visible = true;
        Library.Anim:TweenObject(Main, {
            Transparency = 0;
        }, 0.3);
    end

    function Window:Hide()
        Library.Anim:TweenObject(Main, {
            Transparency = 1;
        }, 0.3);
        task.wait(0.3);
        Main.Visible = false;
    end

    function Window:Toggle()
        if Main.Visible then
            self:Hide();
        else
            self:Show();
        end
    end

    -- ============================================
    -- MAKE WINDOW DRAGGABLE
    -- ============================================
    Library:MakeDraggable(Main, 30);

    -- ============================================
    -- KEYBIND TOGGLE
    -- ============================================
    Library.ToggleKeybind = Options.ToggleKeybind;
    
    if Options.ToggleKeybind then
        Library.KeybindToToggle = Options.ToggleKeybind;
    end

    -- ============================================
    -- KEYBIND FRAME
    -- ============================================
    local KeybindFrame = Library:Create('Frame', {
        Name = 'KeybindFrame';
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 10, 1, -30);
        Size = UDim2.new(0, 210, 0, 0);
        ZIndex = 10;
        Parent = Main;
        Visible = false;
    });

    Library:AddToRegistry(KeybindFrame, {
        BackgroundColor3 = 'BackgroundColor';
        BorderColor3 = 'OutlineColor';
    });

    local KeybindContainer = Library:Create('Frame', {
        Name = 'KeybindContainer';
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 0);
        ZIndex = 11;
        Parent = KeybindFrame;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Padding = UDim.new(0, 2);
        Parent = KeybindContainer;
    });

    Library:Create('UIPadding', {
        PaddingTop = UDim.new(0, 6);
        PaddingBottom = UDim.new(0, 6);
        PaddingLeft = UDim.new(0, 6);
        PaddingRight = UDim.new(0, 6);
        Parent = KeybindContainer;
    });

    Library.KeybindFrame = KeybindFrame;
    Library.KeybindContainer = KeybindContainer;

    -- ============================================
    -- WATERMARK
    -- ============================================
    local Watermark = Library:Create('TextLabel', {
        Name = 'Watermark';
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 10, 1, -5);
        Size = UDim2.new(0, 200, 0, 20);
        Text = 'Linoria Lib';
        TextColor3 = Library.FontColor;
        TextSize = 12;
        TextXAlignment = Enum.TextXAlignment.Left;
        Font = Library.Font;
        ZIndex = 10;
        Parent = Main;
        Visible = false;
    });

    Library:AddToRegistry(Watermark, {
        TextColor3 = 'FontColor';
    });

    function Library:SetWatermark(Text)
        Watermark.Text = Text;
    end

    function Library:SetWatermarkVisibility(Visible)
        Watermark.Visible = Visible;
    end

    -- ============================================
    -- NOTIFICATION SYSTEM
    -- ============================================
    function Library:Notify(Text, Duration)
        Duration = Duration or 3;
        
        local Notification = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 250, 0, 40);
            Position = UDim2.new(1, -260, 0, 10);
            ZIndex = 50;
            Parent = Library.ScreenGui;
            Visible = false;
        });

        Library:AddToRegistry(Notification, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Label = Library:CreateLabel({
            Size = UDim2.new(1, -10, 1, 0);
            Position = UDim2.new(0, 5, 0, 0);
            Text = Text;
            TextSize = 14;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextYAlignment = Enum.TextYAlignment.Center;
            ZIndex = 51;
            Parent = Notification;
        });

        -- Animate in
        Notification.Visible = true;
        Notification.Position = UDim2.new(1, 0, 0, 10);
        Notification.Transparency = 1;
        
        Library.Anim:TweenObject(Notification, {
            Position = UDim2.new(1, -260, 0, 10);
            Transparency = 0;
        }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out);
        
        task.wait(Duration);
        
        Library.Anim:TweenObject(Notification, {
            Position = UDim2.new(1, 0, 0, 10);
            Transparency = 1;
        }, 0.3);
        
        task.wait(0.3);
        Notification:Destroy();
    end

    -- ============================================
    -- ADD GROUPBOX METHODS
    -- ============================================
    local BaseGroupbox = {};

    function BaseGroupbox:AddLabel(Text, DoesWrap)
        local Container = self.Content;
        local Label = {};
        Label.Type = 'Label';
        Label.Container = Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Text;
            TextWrapped = DoesWrap or false;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        end

        Label.TextLabel = TextLabel;

        function Label:SetText(Text)
            TextLabel.Text = Text;
            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end
            self:GetParent():Resize();
        end

        function Label:GetParent()
            return self.Container.Parent;
        end

        self:Resize();
        return Label;
    end

    function BaseGroupbox:AddDivider()
        local Container = self.Content;

        local Divider = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, -4, 0, 3);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(Divider, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        self:Resize();
        return Divider;
    end

    function BaseGroupbox:AddButton(Options)
        local Container = self.Content;
        
        local Button = {};
        Button.Type = 'Button';
        Button.Container = Container;
        
        if type(Options) == 'table' then
            Button.Text = Options.Text or 'Button';
            Button.Func = Options.Func or function() end;
            Button.DoubleClick = Options.DoubleClick or false;
            Button.Tooltip = Options.Tooltip;
        else
            Button.Text = select(1, ...);
            Button.Func = select(2, ...) or function() end;
            Button.DoubleClick = false;
        end

        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 25);
            ZIndex = 5;
            Parent = Container;
        });

        local Inner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = Outer;
        });

        Library:AddToRegistry(Outer, {
            BorderColor3 = 'Black';
        });

        Library:AddToRegistry(Inner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local Label = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = Button.Text;
            ZIndex = 6;
            Parent = Inner;
        });

        Library:OnHighlight(Outer, Outer,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        Outer.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if Button.DoubleClick then
                    Label.Text = 'Are you sure?';
                    Label.TextColor3 = Library.RiskColor;
                    task.wait(0.5);
                    Label.Text = Button.Text;
                    Label.TextColor3 = Library.FontColor;
                    return;
                end
                Library:SafeCallback(Button.Func);
            end
        end);

        if Button.Tooltip then
            Library:AddToolTip(Button.Tooltip, Outer);
        end

        Button.Outer = Outer;
        Button.Inner = Inner;
        Button.Label = Label;

        function Button:AddSubButton(Options)
            local SubButton = {};
            
            if type(Options) == 'table' then
                SubButton.Text = Options.Text or 'Sub';
                SubButton.Func = Options.Func or function() end;
                SubButton.DoubleClick = Options.DoubleClick or false;
            else
                SubButton.Text = select(1, ...);
                SubButton.Func = select(2, ...) or function() end;
                SubButton.DoubleClick = false;
            end

            local SubOuter = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0.5, -3, 1, 0);
                Position = UDim2.new(1, 2, 0, 0);
                ZIndex = 5;
                Parent = Outer;
            });

            local SubInner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = SubOuter;
            });

            Library:AddToRegistry(SubOuter, {
                BorderColor3 = 'Black';
            });

            Library:AddToRegistry(SubInner, {
                BackgroundColor3 = 'MainColor';
                BorderColor3 = 'OutlineColor';
            });

            local SubLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 14;
                Text = SubButton.Text;
                ZIndex = 6;
                Parent = SubInner;
            });

            Library:OnHighlight(SubOuter, SubOuter,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            );

            SubOuter.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                    if SubButton.DoubleClick then
                        SubLabel.Text = 'Are you sure?';
                        SubLabel.TextColor3 = Library.RiskColor;
                        task.wait(0.5);
                        SubLabel.Text = SubButton.Text;
                        SubLabel.TextColor3 = Library.FontColor;
                        return;
                    end
                    Library:SafeCallback(SubButton.Func);
                end
            end);

            Outer.Size = UDim2.new(1, -4, 0, 25);
            self:Resize();
            
            return SubButton;
        end

        self:Resize();
        return Button;
    end

    function BaseGroupbox:AddToggle(Idx, Info)
        local Container = self.Content;
        
        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';
            Callback = Info.Callback or function(Value) end;
            Risky = Info.Risky;
            Container = Container;
            Addons = {};
        };

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 16, 0, 16);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = 'Black';
        });

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        });

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 200, 1, 0);
            Position = UDim2.new(1, 8, 0, 0);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleInner;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 160, 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        });

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion);
        end

        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;
            
            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);
            Toggle.Value = Bool;
            Toggle:Display();
            
            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool;
                    Addon:Update();
                end
            end
            
            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value);
                Library:AttemptSave();
            end;
        });

        if Toggle.Risky then
            ToggleLabel.TextColor3 = Library.RiskColor;
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' });
        end

        Toggle:Display();
        Toggles[Idx] = Toggle;
        
        self:Resize();
        return Toggle;
    end

    function BaseGroupbox:AddSlider(Idx, Info)
        local Container = self.Content;
        
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
            Container = Container;
        };

        -- Label
        local Label = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        -- Slider frame
        local SliderFrame = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(SliderFrame, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        -- Fill
        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderFrame;
        });

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = 'AccentColor';
        });

        -- Value label
        local ValueLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = tostring(Info.Default);
            TextXAlignment = Enum.TextXAlignment.Center;
            ZIndex = 7;
            Parent = SliderFrame;
        });

        -- Drag functionality
        local dragging = false;
        SliderFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true;
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local relativeX = Mouse.X - SliderFrame.AbsolutePosition.X;
                    local percent = math.clamp(relativeX / SliderFrame.AbsoluteSize.X, 0, 1);
                    
                    local value = Slider.Min + (Slider.Max - Slider.Min) * percent;
                    value = math.round(value / Slider.Rounding) * Slider.Rounding;
                    value = math.clamp(value, Slider.Min, Slider.Max);
                    
                    Slider.Value = value;
                    Fill.Size = UDim2.new(percent, 0, 1, 0);
                    ValueLabel.Text = tostring(value) .. (Info.Suffix or '');
                    
                    Library:SafeCallback(Slider.Callback, value);
                    Library:SafeCallback(Slider.Changed, value);
                    
                    RenderStepped:Wait();
                end;
                dragging = false;
                Library:AttemptSave();
            end;
        end);

        function Slider:SetValue(Value)
            Value = math.clamp(Value, Slider.Min, Slider.Max);
            Value = math.round(Value / Slider.Rounding) * Slider.Rounding;
            
            Slider.Value = Value;
            local percent = (Value - Slider.Min) / (Slider.Max - Slider.Min);
            Fill.Size = UDim2.new(percent, 0, 1, 0);
            ValueLabel.Text = tostring(Value) .. (Info.Suffix or '');
            
            Library:SafeCallback(Slider.Callback, Value);
            Library:SafeCallback(Slider.Changed, Value);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        Options[Idx] = Slider;
        self:Resize();
        return Slider;
    end

    function BaseGroupbox:AddInput(Idx, Info)
        local Container = self.Content;
        
        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
            Container = Container;
        };

        local Label = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 22);
            ZIndex = 5;
            Parent = Container;
        });

        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        });

        Library:AddToRegistry(TextBoxInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter);
        end

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';
            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 7;
            Parent = TextBoxInner;
        });

        Library:ApplyTextStroke(Box);
        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
        });

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end
            
            if Textbox.Numeric and tonumber(Text) == nil and Text ~= '' then
                return;
            end
            
            Textbox.Value = Text;
            Box.Text = Text;
            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if enter then
                    Textbox:SetValue(Box.Text);
                    Library:AttemptSave();
                end
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Options[Idx] = Textbox;
        self:Resize();
        return Textbox;
    end

    function BaseGroupbox:AddDropdown(Idx, Info)
        local Container = self.Content;
        
        local Dropdown = {
            Values = Info.Values or {};
            Default = Info.Default or 1;
            Multi = Info.Multi or false;
            Type = 'Dropdown';
            Callback = Info.Callback or function(Value) end;
            Container = Container;
            Value = {};
        };

        if Info.SpecialType == 'Player' then
            Dropdown.Values = GetPlayersString();
        elseif Info.SpecialType == 'Team' then
            Dropdown.Values = GetTeamsString();
        end

        -- Label
        local Label = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        -- Dropdown button
        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 22);
            ZIndex = 5;
            Parent = Container;
        });

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter);
        end

        local CurrentLabel = Library:CreateLabel({
            Size = UDim2.new(1, -5, 1, 0);
            Position = UDim2.new(0, 5, 0, 0);
            TextSize = 14;
            Text = '';
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 7;
            Parent = DropdownInner;
        });

        local Arrow = Library:CreateLabel({
            Size = UDim2.new(0, 20, 1, 0);
            Position = UDim2.new(1, -20, 0, 0);
            TextSize = 14;
            Text = '▼';
            TextXAlignment = Enum.TextXAlignment.Center;
            ZIndex = 7;
            Parent = DropdownInner;
        });

        -- Dropdown list
        local ListFrame = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 0, 0, 0);
            ZIndex = 10;
            Parent = Library.ScreenGui;
            Visible = false;
        });

        Library:AddToRegistry(ListFrame, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local ListLayout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Padding = UDim.new(0, 1);
            Parent = ListFrame;
        });

        function Dropdown:UpdateList()
            -- Clear existing items
            for _, child in ipairs(ListFrame:GetChildren()) do
                if child:IsA('TextButton') then
                    child:Destroy();
                end
            end
            
            local height = 0;
            for i, value in ipairs(Dropdown.Values) do
                local isSelected = false;
                if Dropdown.Multi then
                    isSelected = Dropdown.Value[value] or false;
                else
                    isSelected = (Dropdown.Value == value);
                end
                
                local Item = Library:Create('TextButton', {
                    BackgroundColor3 = isSelected and Library.AccentColor or Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Inset;
                    Size = UDim2.new(1, 0, 0, 22);
                    Text = value;
                    TextColor3 = Library.FontColor;
                    TextSize = 13;
                    Font = Library.Font;
                    ZIndex = 11;
                    Parent = ListFrame;
                });
                
                Library:AddToRegistry(Item, {
                    BackgroundColor3 = isSelected and 'AccentColor' or 'MainColor';
                    BorderColor3 = 'OutlineColor';
                    TextColor3 = 'FontColor';
                });
                
                Item.MouseEnter:Connect(function()
                    Item.BackgroundColor3 = Library.TabHoverColor;
                end);
                
                Item.MouseLeave:Connect(function()
                    Item.BackgroundColor3 = isSelected and Library.AccentColor or Library.MainColor;
                end);
                
                Item.MouseButton1Click:Connect(function()
                    if Dropdown.Multi then
                        Dropdown.Value[value] = not Dropdown.Value[value];
                    else
                        Dropdown.Value = value;
                        Dropdown:UpdateList();
                        Dropdown:UpdateDisplay();
                        ListFrame.Visible = false;
                        Library.OpenedFrames[ListFrame] = nil;
                    end
                    Dropdown:UpdateDisplay();
                    Dropdown:UpdateList();
                    Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                    Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
                    Library:AttemptSave();
                end);
                
                height = height + 23;
            end
            
            ListFrame.Size = UDim2.new(0, DropdownOuter.AbsoluteSize.X, 0, height + 4);
            ListFrame.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.AbsoluteSize.Y + 2);
        end

        function Dropdown:UpdateDisplay()
            if Dropdown.Multi then
                local texts = {};
                for value, selected in pairs(Dropdown.Value) do
                    if selected then
                        table.insert(texts, value);
                    end
                end
                CurrentLabel.Text = #texts > 0 and table.concat(texts, ', ') or 'None';
            else
                CurrentLabel.Text = Dropdown.Value or 'None';
            end
        end

        function Dropdown:SetValue(Value)
            if Dropdown.Multi then
                Dropdown.Value = {};
                if type(Value) == 'table' then
                    for key, val in pairs(Value) do
                        Dropdown.Value[key] = val;
                    end
                end
            else
                Dropdown.Value = Value;
            end
            Dropdown:UpdateDisplay();
            Dropdown:UpdateList();
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end

        -- Initialize
        if Dropdown.Multi then
            Dropdown.Value = {};
            if type(Info.Default) == 'table' then
                for key, val in pairs(Info.Default) do
                    Dropdown.Value[key] = val;
                end
            end
        else
            Dropdown.Value = type(Info.Default) == 'number' and Dropdown.Values[Info.Default] or Info.Default;
        end

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListFrame.Visible then
                    ListFrame.Visible = false;
                    Library.OpenedFrames[ListFrame] = nil;
                else
                    Dropdown:UpdateList();
                    ListFrame.Visible = true;
                    Library.OpenedFrames[ListFrame] = true;
                end
            end
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if ListFrame.Visible then
                    local AbsPos, AbsSize = ListFrame.AbsolutePosition, ListFrame.AbsoluteSize;
                    if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                        or Mouse.Y < AbsPos.Y or Mouse.Y > AbsPos.Y + AbsSize.Y then
                        ListFrame.Visible = false;
                        Library.OpenedFrames[ListFrame] = nil;
                    end
                end
            end
        end));

        Dropdown:UpdateDisplay();
        Options[Idx] = Dropdown;
        self:Resize();
        return Dropdown;
    end

    function BaseGroupbox:AddDependencyBox()
        local Container = self.Content;
        
        local Depbox = {
            Dependencies = {};
            Visible = true;
            Container = Container;
            Objects = {};
        };
        
        local Content = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            ZIndex = 5;
            Parent = Container;
        });
        
        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Padding = UDim.new(0, 4);
            Parent = Content;
        });
        
        Depbox.Content = Content;
        Depbox.Layout = Layout;
        
        function Depbox:AddElement(Element)
            table.insert(Depbox.Objects, Element);
            self:Update();
            return Element;
        end
        
        function Depbox:SetupDependencies(Deps)
            Depbox.Dependencies = Deps or {};
            Depbox:Update();
        end
        
        function Depbox:Update()
            local visible = true;
            for _, dep in ipairs(Depbox.Dependencies) do
                local obj = dep[1];
                local requiredValue = dep[2];
                if obj and obj.Type == 'Toggle' then
                    if obj.Value ~= requiredValue then
                        visible = false;
                        break;
                    end
                end
            end
            
            Depbox.Visible = visible;
            Depbox.Content.Visible = visible;
            
            for _, obj in ipairs(Depbox.Objects) do
                if obj and obj.Visible ~= nil then
                    obj.Visible = visible;
                end
            end
            
            if visible then
                Depbox.Content.Size = UDim2.new(1, 0, 0, Depbox.Content.AbsoluteSize.Y);
            else
                Depbox.Content.Size = UDim2.new(1, 0, 0, 0);
            end
            
            Depbox:GetParent():Resize();
        end
        
        function Depbox:GetParent()
            return self.Container.Parent;
        end
        
        function Depbox:AddToggle(Idx, Info)
            Info = Info or {};
            local Toggle = self:AddElement({Type = 'Toggle', Visible = true});
            local result = self:AddElement({
                Type = 'Toggle',
                Value = Info.Default or false,
                Callback = Info.Callback,
                Visible = true
            });
            return result;
        end
        
        function Depbox:AddSlider(Idx, Info)
            Info = Info or {};
            return self:AddElement({Type = 'Slider', Visible = true});
        end
        
        function Depbox:AddDropdown(Idx, Info)
            Info = Info or {};
            return self:AddElement({Type = 'Dropdown', Visible = true});
        end
        
        function Depbox:AddLabel(Text, DoesWrap)
            local Label = BaseGroupbox.AddLabel(Depbox, Text, DoesWrap);
            self:AddElement(Label);
            return Label;
        end
        
        function Depbox:AddDivider()
            local Divider = BaseGroupbox.AddDivider(Depbox);
            self:AddElement(Divider);
            return Divider;
        end
        
        function Depbox:AddDependencyBox()
            local SubDepbox = AddDependencyBox(Depbox);
            self:AddElement(SubDepbox);
            table.insert(Library.DependencyBoxes, SubDepbox);
            return SubDepbox;
        end
        
        table.insert(Library.DependencyBoxes, Depbox);
        self:Resize();
        return Depbox;
    end

    -- Expose groupbox methods
    for method, func in pairs(BaseGroupbox) do
        Window[method] = func;
    end

    -- ============================================
    -- COLOR PICKER (Simplified)
    -- ============================================
    function BaseGroupbox:AddColorPicker(Idx, Info)
        local Container = self.Content;
        
        local ColorPicker = {
            Value = Info.Default or Color3.new(1, 1, 1);
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Callback = Info.Callback or function(Color) end;
            Container = Container;
        };
        
        local Label = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Info.Title or 'Color';
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });
        
        local ColorFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 40, 0, 20);
            ZIndex = 6;
            Parent = Container;
        });
        
        Library:AddToRegistry(ColorFrame, {
            BackgroundColor3 = 'AccentColor';
            BorderColor3 = 'OutlineColor';
        });
        
        function ColorPicker:SetValueRGB(Color)
            ColorPicker.Value = Color;
            ColorFrame.BackgroundColor3 = Color;
            Library:SafeCallback(ColorPicker.Callback, Color);
            Library:SafeCallback(ColorPicker.Changed, Color);
        end
        
        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value);
        end
        
        -- Simple color click to change (simplified)
        ColorFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                -- In a full implementation, this would open a color picker GUI
                -- For simplicity, we'll cycle through some colors
                local colors = {
                    Color3.new(1, 0, 0),
                    Color3.new(0, 1, 0),
                    Color3.new(0, 0, 1),
                    Color3.new(1, 1, 0),
                    Color3.new(1, 0, 1),
                    Color3.new(0, 1, 1)
                }
                local current = 0
                for i, color in ipairs(colors) do
                    if color == ColorPicker.Value then
                        current = i % #colors + 1
                        break
                    end
                end
                ColorPicker:SetValueRGB(colors[current] or colors[1])
                Library:AttemptSave();
            end
        end);
        
        Options[Idx] = ColorPicker;
        self:Resize();
        return ColorPicker;
    end

    -- ============================================
    -- KEY PICKER
    -- ============================================
    function BaseGroupbox:AddKeyPicker(Idx, Info)
        local Container = self.Content;
        
        local KeyPicker = {
            Value = Info.Default or 'None';
            Toggled = false;
            Mode = Info.Mode or 'Toggle';
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            SyncToggleState = Info.SyncToggleState or false;
            Container = Container;
            NoUI = Info.NoUI or false;
        };
        
        local Label = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Info.Text or 'Keybind';
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });
        
        local KeyFrame = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 80, 0, 22);
            ZIndex = 5;
            Parent = Container;
        });
        
        local KeyInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = KeyFrame;
        });
        
        Library:AddToRegistry(KeyInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });
        
        local KeyLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default or 'None';
            TextXAlignment = Enum.TextXAlignment.Center;
            ZIndex = 7;
            Parent = KeyInner;
        });
        
        function KeyPicker:Update()
            if KeyPicker.NoUI then return end
            
            local state = KeyPicker:GetState();
            KeyLabel.Text = KeyPicker.Value .. (KeyPicker.Mode == 'Toggle' and (state and ' ✓' or '') or '');
            KeyInner.BackgroundColor3 = state and Library.AccentColor or Library.MainColor;
            KeyInner.BorderColor3 = state and Library.AccentColorDark or Library.OutlineColor;
            
            Library.RegistryMap[KeyInner].Properties.BackgroundColor3 = state and 'AccentColor' or 'MainColor';
            Library.RegistryMap[KeyInner].Properties.BorderColor3 = state and 'AccentColorDark' or 'OutlineColor';
        end
        
        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then return false end
                local key = KeyPicker.Value;
                if key == 'MB1' then
                    return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1);
                elseif key == 'MB2' then
                    return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[key]);
                end
            else
                return KeyPicker.Toggled;
            end
        end
        
        function KeyPicker:SetValue(Data)
            if type(Data) == 'table' then
                KeyPicker.Value = Data[1] or KeyPicker.Value;
                KeyPicker.Mode = Data[2] or KeyPicker.Mode;
            else
                KeyPicker.Value = Data;
            end
            KeyPicker:Update();
        end
        
        function KeyPicker:OnChanged(Func)
            KeyPicker.Changed = Func;
            Func(KeyPicker.Value);
        end
        
        function KeyPicker:OnClick(Func)
            KeyPicker.Clicked = Func;
        end
        
        local picking = false;
        KeyFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                picking = true;
                KeyLabel.Text = 'Press key...';
                KeyInner.BackgroundColor3 = Color3.fromRGB(50, 50, 50);
                
                local event;
                event = InputService.InputBegan:Connect(function(inp)
                    local key;
                    if inp.UserInputType == Enum.UserInputType.Keyboard then
                        key = inp.KeyCode.Name;
                    elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        key = 'MB1';
                    elseif inp.UserInputType == Enum.UserInputType.MouseButton2 then
                        key = 'MB2';
                    end
                    
                    if key then
                        KeyPicker.Value = key;
                        KeyPicker:Update();
                        Library:SafeCallback(KeyPicker.ChangedCallback, key);
                        Library:SafeCallback(KeyPicker.Changed, key);
                        Library:AttemptSave();
                        event:Disconnect();
                        picking = false;
                    end
                end);
            end
        end);
        
        -- Handle key presses
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if picking then return end
            if KeyPicker.Mode == 'Toggle' then
                local key = KeyPicker.Value;
                if key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                    or key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                    KeyPicker.Toggled = not KeyPicker.Toggled;
                    KeyPicker:Update();
                    Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled);
                    Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled);
                elseif Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == key then
                    KeyPicker.Toggled = not KeyPicker.Toggled;
                    KeyPicker:Update();
                    Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled);
                    Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled);
                end
            end
        end));
        
        KeyPicker:Update();
        Options[Idx] = KeyPicker;
        self:Resize();
        return KeyPicker;
    }

    -- ============================================
    -- INITIALIZATION
    ============================================
    if Options.Center then
        Main.Position = UDim2.new(0.5, -Options.Size.X.Offset/2, 0.5, -Options.Size.Y.Offset/2);
    end
    
    if Options.AutoShow then
        Main.Visible = true;
        Main.Transparency = 0;
    else
        Main.Transparency = 1;
    end

    Window.Frame = Main;
    Window.ContentArea = ContentArea;
    Window.ContentWrapper = ContentWrapper;
    
    -- Keybind toggle
    if Options.ToggleKeybind then
        Library.ToggleKeybind = Options.ToggleKeybind;
    end

    return Window;
end

-- ============================================
-- CLEANUP ON UNLOAD
-- ============================================
Library:GiveSignal(RunService.RenderStepped:Connect(function()
    if Library.Drag and not Library.Drag.Active then
        -- Clean up drag if it's stuck
    end
end))

return Library;
