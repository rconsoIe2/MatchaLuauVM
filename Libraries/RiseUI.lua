local env = nil
pcall(function() env = (getfenv and getfenv()) or _G end)
if type(env) ~= "table" then env = {} end

local shared = type(shared) == "table" and shared or {}

local function safeWriteGlobal(key, value)
	pcall(function() env[key] = value end)
	pcall(function() getgenv()[key] = value end)
	pcall(function() _G[key] = value end)
	pcall(function() shared[key] = value end)
end

local function safeReadGlobal(key)
	local v
	pcall(function() v = getgenv()[key] end); if v ~= nil then return v end
	pcall(function() v = _G[key] end);        if v ~= nil then return v end
	pcall(function() v = shared[key] end);    if v ~= nil then return v end
	pcall(function() v = env[key] end);       return v
end

local function hostFn(name, fallback)
	local f = env[name]
	if type(f) ~= "function" then pcall(function() f = _G[name] end) end
	if type(f) ~= "function" then return fallback end
	return f
end

local iskeypressed   = hostFn("iskeypressed",   function() return false end)
local ismouse1pressed = hostFn("ismouse1pressed", function() return false end)
local clock          = os and os.clock or hostFn("tick", function() return 0 end)

local instanceId = {}
safeWriteGlobal("RiseInstanceId", instanceId)

local RiseUI = {}
RiseUI.__index = RiseUI

local Theme = {
	Background      = Color3.fromRGB(16, 16, 22),
	Elevated        = Color3.fromRGB(24, 24, 32),
	Stroke          = Color3.fromRGB(45, 45, 58),
	Accent          = Color3.fromRGB(132, 84, 255),
	AccentSecondary = Color3.fromRGB(0, 210, 255),
	TextPrimary     = Color3.fromRGB(240, 240, 245),
	TextSecondary   = Color3.fromRGB(140, 140, 155),
	Shadow          = Color3.fromRGB(0, 0, 0),
	Success         = Color3.fromRGB(80, 220, 150),
}

local WINDOW_RADIUS  = 10
local CARD_RADIUS    = 7
local ELEMENT_RADIUS = 4

RiseUI.ToggleKey = 0xA1
RiseUI.ToggleKeyName = "Right-Shift"
RiseUI.Visible = true
RiseUI.LastToggleState = false

local activeNotifications = {}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return Color3.new(lerp(c1.R, c2.R, t), lerp(c1.G, c2.G, t), lerp(c1.B, c2.B, t))
end

local function getMousePos()
	local camera = workspace.CurrentCamera
	if camera then
		local mouse = game:GetService("Players").LocalPlayer:GetMouse()
		if mouse then
			return Vector2.new(mouse.X, mouse.Y)
		end
	end
	return Vector2.new(0, 0)
end

local function isMouseInArea(pos, size)
	local mp = getMousePos()
	return mp.X >= pos.X and mp.X <= pos.X + size.X and mp.Y >= pos.Y and mp.Y <= pos.Y + size.Y
end

local function getVirtualKeyCode(key)
	local char = key:lower()
	if char == "a" then return 0x41
	elseif char == "b" then return 0x42
	elseif char == "c" then return 0x43
	elseif char == "d" then return 0x44
	elseif char == "e" then return 0x45
	elseif char == "f" then return 0x46
	elseif char == "g" then return 0x47
	elseif char == "h" then return 0x48
	elseif char == "i" then return 0x49
	elseif char == "j" then return 0x4A
	elseif char == "k" then return 0x4B
	elseif char == "l" then return 0x4C
	elseif char == "m" then return 0x4D
	elseif char == "n" then return 0x4E
	elseif char == "o" then return 0x4F
	elseif char == "p" then return 0x50
	elseif char == "q" then return 0x51
	elseif char == "r" then return 0x52
	elseif char == "s" then return 0x53
	elseif char == "t" then return 0x54
	elseif char == "u" then return 0x55
	elseif char == "v" then return 0x56
	elseif char == "w" then return 0x57
	elseif char == "x" then return 0x58
	elseif char == "y" then return 0x59
	elseif char == "z" then return 0x5A
	end
	return nil
end

local function newRoundedRect(radius, zBase)
	zBase = zBase or 1
	local self = {
		radius = radius,
		vRect = Drawing.new("Square"),
		hRect = Drawing.new("Square"),
		corners = {
			Drawing.new("Circle"),
			Drawing.new("Circle"),
			Drawing.new("Circle"),
			Drawing.new("Circle"),
		},
	}

	self.vRect.Filled = true
	self.hRect.Filled = true
	self.vRect.ZIndex = zBase
	self.hRect.ZIndex = zBase

	for _, c in ipairs(self.corners) do
		c.Filled = true
		c.NumSides = 24
		c.Radius = radius
		c.ZIndex = zBase
	end

	function self:Set(pos, size, color, visible, transparency)
		transparency = transparency or 0
		local r = self.radius

		self.vRect.Position = pos + Vector2.new(r, 0)
		self.vRect.Size = Vector2.new(math.max(size.X - r * 2, 0), size.Y)
		self.vRect.Color = color
		self.vRect.Transparency = 1 - transparency
		self.vRect.Visible = visible

		self.hRect.Position = pos + Vector2.new(0, r)
		self.hRect.Size = Vector2.new(size.X, math.max(size.Y - r * 2, 0))
		self.hRect.Color = color
		self.hRect.Transparency = 1 - transparency
		self.hRect.Visible = visible

		local offsets = {
			Vector2.new(r, r),
			Vector2.new(size.X - r, r),
			Vector2.new(r, size.Y - r),
			Vector2.new(size.X - r, size.Y - r),
		}
		for i, c in ipairs(self.corners) do
			c.Position = pos + offsets[i]
			c.Color = color
			c.Transparency = 1 - transparency
			c.Visible = visible
		end
	end

	function self:SetZIndex(z)
		self.vRect.ZIndex = z
		self.hRect.ZIndex = z
		for _, c in ipairs(self.corners) do c.ZIndex = z end
	end

	function self:Destroy()
		self.vRect:Remove()
		self.hRect:Remove()
		for _, c in ipairs(self.corners) do c:Remove() end
	end

	return self
end

function RiseUI:Notify(title, text, duration)
	duration = duration or 4

	local notif = {
		title = title or "Notification",
		text = text or "",
		duration = duration,
		spawnTime = clock(),
		drawingObjects = {},
	}

	notif.shadow = newRoundedRect(CARD_RADIUS, 98)
	notif.card = newRoundedRect(CARD_RADIUS, 99)
	notif.accent = newRoundedRect(3, 100)

	local titleTxt = Drawing.new("Text")
	titleTxt.Text = notif.title
	titleTxt.Size = 14
	titleTxt.Font = 1
	titleTxt.Color = Theme.TextPrimary
	titleTxt.Visible = true
	titleTxt.ZIndex = 102

	local bodyTxt = Drawing.new("Text")
	bodyTxt.Text = notif.text
	bodyTxt.Size = 12
	bodyTxt.Color = Theme.TextSecondary
	bodyTxt.Visible = true
	bodyTxt.ZIndex = 102

	notif.titleTxt = titleTxt
	notif.bodyTxt = bodyTxt

	table.insert(activeNotifications, notif)
end

task.spawn(function()
	while true do
		local camera = workspace.CurrentCamera
		if camera then
			local screenSize = camera.ViewportSize
			local startX = screenSize.X - 270
			local startY = screenSize.Y - 80

			local currentTime = clock()
			local aliveNotifs = {}

			for i, notif in ipairs(activeNotifications) do
				local age = currentTime - notif.spawnTime
				if age < notif.duration then
					table.insert(aliveNotifs, notif)

					local size = Vector2.new(250, 58)
					local currentY = startY - ((i - 1) * 70)
					local pos = Vector2.new(startX, currentY)

					local alpha = 1
					if age < 0.25 then
						alpha = age / 0.25
					elseif age > notif.duration - 0.35 then
						alpha = (notif.duration - age) / 0.35
					end
					alpha = math.clamp(alpha, 0, 1)

					local slide = (1 - alpha) * 20
					pos = pos + Vector2.new(slide, 0)

					notif.shadow:Set(pos + Vector2.new(3, 4), size, Theme.Shadow, true, alpha * 0.35)
					notif.card:Set(pos, size, Theme.Elevated, true, alpha)
					notif.accent:Set(pos, Vector2.new(4, size.Y), Theme.Accent, true, alpha)

					notif.titleTxt.Position = pos + Vector2.new(14, 9)
					notif.titleTxt.Transparency = 1 - alpha
					notif.bodyTxt.Position = pos + Vector2.new(14, 29)
					notif.bodyTxt.Transparency = 1 - alpha
				else
					notif.shadow:Destroy()
					notif.card:Destroy()
					notif.accent:Destroy()
					notif.titleTxt:Remove()
					notif.bodyTxt:Remove()
				end
			end
			activeNotifications = aliveNotifs
		end
		task.wait()
	end
end)

local function hideElementVisuals(el)
	if el.type == "Toggle" then
		el.box:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)
		el.checkA.Visible = false
		el.checkB.Visible = false
	elseif el.type == "Slider" then
		el.track:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)
		el.fill:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Accent, false)
		el.thumb.Visible = false
		el.thumbRing.Visible = false
	elseif el.type == "Dropdown" then
		el.open = false
		el.box:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)
		el.valueTxt.Visible = false
		el.arrow.Visible = false
		for _, row in ipairs(el.rows) do
			row.bg:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)
			row.txt.Visible = false
		end
	elseif el.type == "Category" then
		el.box:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)
		el.arrow.Visible = false
		for _, subEl in ipairs(el.elements) do
			local subLbl = subEl.drawingObjects[1]
			if subLbl then subLbl.Visible = false end
			if subEl.bindLbl then subEl.bindLbl.Visible = false end
			hideElementVisuals(subEl)
		end
	end
end

local function createToggleHelper(tab, parentElements, text, default, callback)
	local toggle = {
		type = "Toggle",
		text = text,
		state = default or false,
		displayState = default and 1 or 0,
		callback = callback,
		keybind = nil,
		keybindCode = nil,
		keybindMode = "Hold",
		lastKeybindState = false,
		drawingObjects = {},
	}

	local lbl = Drawing.new("Text")
	lbl.Text = text
	lbl.Size = 13
	lbl.Color = Theme.TextPrimary
	lbl.Visible = false
	lbl.ZIndex = 5

	local box = newRoundedRect(ELEMENT_RADIUS, 5)

	local checkA = Drawing.new("Line")
	checkA.Thickness = 2
	checkA.Color = Color3.fromRGB(15, 15, 20)
	checkA.Visible = false
	checkA.ZIndex = 6

	local checkB = Drawing.new("Line")
	checkB.Thickness = 2
	checkB.Color = Color3.fromRGB(15, 15, 20)
	checkB.Visible = false
	checkB.ZIndex = 6

	table.insert(toggle.drawingObjects, lbl)
	table.insert(tab.drawingObjects, lbl)
	toggle.box = box
	toggle.checkA = checkA
	toggle.checkB = checkB

	function toggle:AddKeybind(key, mode)
		toggle.keybind = key:lower()
		toggle.keybindCode = getVirtualKeyCode(key)
		toggle.keybindMode = mode or "Hold"

		local bindLbl = Drawing.new("Text")
		bindLbl.Text = "[" .. key:upper() .. "]"
		bindLbl.Size = 11
		bindLbl.Color = Theme.TextSecondary
		bindLbl.Visible = false
		bindLbl.ZIndex = 5
		table.insert(toggle.drawingObjects, bindLbl)
		table.insert(tab.drawingObjects, bindLbl)
		toggle.bindLbl = bindLbl

		return toggle
	end

	table.insert(parentElements, toggle)
	return toggle
end

local function createSliderHelper(tab, parentElements, text, default, min, step, max, suffix, callback)
	local realDefault = default
	local realMin = min
	local realStep = step
	local realMax = max
	local realSuffix = suffix
	local realCallback = callback

	if type(realSuffix) == "function" then
		realCallback = realSuffix
		realSuffix = ""
	end
	if type(realMax) == "function" then
		realCallback = realMax
		realMin = default
		realMax = min
		realDefault = step
		realStep = 1
		realSuffix = ""
	end
	if type(realStep) == "function" then
		realCallback = realStep
		realStep = 1
	end

	local slider = {
		type = "Slider",
		text = text,
		value = realDefault or realMin,
		min = realMin,
		max = realMax,
		step = realStep or 1,
		suffix = realSuffix or "",
		callback = realCallback,
		dragging = false,
		drawingObjects = {},
	}

	local lbl = Drawing.new("Text")
	lbl.Text = text .. ": " .. tostring(slider.value) .. slider.suffix
	lbl.Size = 13
	lbl.Color = Theme.TextPrimary
	lbl.Visible = false
	lbl.ZIndex = 5

	local track = newRoundedRect(2, 5)
	local fill = newRoundedRect(2, 6)

	local thumb = Drawing.new("Circle")
	thumb.Filled = true
	thumb.Radius = 6
	thumb.NumSides = 16
	thumb.Color = Theme.TextPrimary
	thumb.Visible = false
	thumb.ZIndex = 7

	local thumbRing = Drawing.new("Circle")
	thumbRing.Filled = false
	thumbRing.Thickness = 2
	thumbRing.Radius = 7
	thumbRing.NumSides = 16
	thumbRing.Color = Theme.Accent
	thumbRing.Visible = false
	thumbRing.ZIndex = 7

	table.insert(slider.drawingObjects, lbl)
	table.insert(tab.drawingObjects, lbl)
	slider.track = track
	slider.fill = fill
	slider.thumb = thumb
	slider.thumbRing = thumbRing

	table.insert(parentElements, slider)
	return slider
end

local function createDropdownHelper(tab, parentElements, text, options, default, callback)
	if type(default) == "function" then
		callback = default
		default = options and options[1] or ""
	end

	local dropdown = {
		type = "Dropdown",
		text = text,
		options = options or {},
		value = default or (options and options[1]) or "",
		open = false,
		callback = callback,
		drawingObjects = {},
		rows = {},
	}

	local lbl = Drawing.new("Text")
	lbl.Text = text
	lbl.Size = 13
	lbl.Color = Theme.TextPrimary
	lbl.Visible = false
	lbl.ZIndex = 5

	local box = newRoundedRect(ELEMENT_RADIUS, 5)

	local valueTxt = Drawing.new("Text")
	valueTxt.Text = tostring(dropdown.value)
	valueTxt.Size = 12
	valueTxt.Color = Theme.TextSecondary
	valueTxt.Visible = false
	valueTxt.ZIndex = 6

	local arrow = Drawing.new("Text")
	arrow.Text = "v"
	arrow.Size = 12
	arrow.Color = Theme.TextSecondary
	arrow.Visible = false
	arrow.ZIndex = 6

	table.insert(dropdown.drawingObjects, lbl)
	table.insert(tab.drawingObjects, lbl)
	dropdown.box = box
	dropdown.valueTxt = valueTxt
	dropdown.arrow = arrow

	for _, optionText in ipairs(dropdown.options) do
		local rowBg = newRoundedRect(ELEMENT_RADIUS, 200)
		local rowTxt = Drawing.new("Text")
		rowTxt.Text = tostring(optionText)
		rowTxt.Size = 12
		rowTxt.Color = Theme.TextPrimary
		rowTxt.Visible = false
		rowTxt.ZIndex = 201

		table.insert(dropdown.rows, { bg = rowBg, txt = rowTxt, value = optionText })
	end

	table.insert(parentElements, dropdown)
	return dropdown
end

function RiseUI:CreateWindow(config)
	local window = {
		title = config.title or "Window",
		size = config.size or Vector2.new(560, 400),
		position = Vector2.new(100, 100),
		tabs = {},
		activeTab = nil,
		dragging = false,
		dragOffset = Vector2.new(0, 0),
		globalDrawingObjects = {},
	}

	local shadow = newRoundedRect(WINDOW_RADIUS + 2, 0)
	local body = newRoundedRect(WINDOW_RADIUS, 1)

	local outline = Drawing.new("Square")
	outline.Filled = false
	outline.Thickness = 1
	outline.Color = Theme.Stroke
	outline.Visible = true
	outline.ZIndex = 2

	local titleDivider = newRoundedRect(1, 3)
	local sideDivider = newRoundedRect(1, 3)

	local titleText = Drawing.new("Text")
	titleText.Text = window.title
	titleText.Color = Theme.TextPrimary
	titleText.Size = 16
	titleText.Font = 1
	titleText.Visible = true
	titleText.ZIndex = 4

	local titleDot = Drawing.new("Circle")
	titleDot.Filled = true
	titleDot.Radius = 3
	titleDot.NumSides = 12
	titleDot.Color = Theme.Accent
	titleDot.Visible = true
	titleDot.ZIndex = 4

	table.insert(window.globalDrawingObjects, outline)
	window.roundedParts = { shadow = shadow, body = body, titleDivider = titleDivider, sideDivider = sideDivider }
	table.insert(window.globalDrawingObjects, titleText)
	table.insert(window.globalDrawingObjects, titleDot)

	RiseUI:Notify(window.title, "Press " .. RiseUI.ToggleKeyName .. " to toggle UI", 5)

	function window:Tab(name)
		local tab = {
			name = name,
			sections = { Left = {}, Right = {} },
			drawingObjects = {},
			scrollOffset = 0,
		}

		local tabBtn = Drawing.new("Text")
		tabBtn.Text = name
		tabBtn.Size = 14
		tabBtn.Color = Theme.TextSecondary
		tabBtn.Visible = true
		tabBtn.ZIndex = 5

		local indicator = newRoundedRect(2, 5)

		table.insert(window.tabs, { tab = tab, btn = tabBtn, indicator = indicator })
		if not window.activeTab then window.activeTab = tab end

		function tab:Section(secName, side)
			local section = {
				name = secName,
				side = side or "Left",
				elements = {},
				drawingObjects = {},
			}

			local secTitle = Drawing.new("Text")
			secTitle.Text = secName:upper()
			secTitle.Size = 11
			secTitle.Color = Theme.AccentSecondary
			secTitle.Visible = false
			secTitle.ZIndex = 5

			local secUnderline = newRoundedRect(1, 5)

			table.insert(section.drawingObjects, secTitle)
			table.insert(tab.drawingObjects, secTitle)
			section.underline = secUnderline

			function section:Toggle(text, default, callback)
				return createToggleHelper(tab, section.elements, text, default, callback)
			end

			function section:Slider(text, default, min, step, max, suffix, callback)
				return createSliderHelper(tab, section.elements, text, default, min, step, max, suffix, callback)
			end

			function section:Dropdown(text, options, default, callback)
				return createDropdownHelper(tab, section.elements, text, options, default, callback)
			end

			function section:Category(name)
				local category = {
					type = "Category",
					name = name,
					open = false,
					elements = {},
					drawingObjects = {},
				}

				local lbl = Drawing.new("Text")
				lbl.Text = name
				lbl.Size = 13
				lbl.Font = 1
				lbl.Color = Theme.TextPrimary
				lbl.Visible = false
				lbl.ZIndex = 5

				local box = newRoundedRect(ELEMENT_RADIUS, 4)

				local arrow = Drawing.new("Text")
				arrow.Text = "v"
				arrow.Size = 12
				arrow.Color = Theme.TextSecondary
				arrow.Visible = false
				arrow.ZIndex = 5

				table.insert(category.drawingObjects, lbl)
				table.insert(tab.drawingObjects, lbl)
				category.box = box
				category.arrow = arrow

				function category:Toggle(text, default, callback)
					return createToggleHelper(tab, category.elements, text, default, callback)
				end

				function category:Slider(text, default, min, step, max, suffix, callback)
					return createSliderHelper(tab, category.elements, text, default, min, step, max, suffix, callback)
				end

				function category:Dropdown(text, options, default, callback)
					return createDropdownHelper(tab, category.elements, text, options, default, callback)
				end

				table.insert(section.elements, category)
				return category
			end

			table.insert(tab.sections[section.side], section)
			return section
		end

		return tab
	end

	task.spawn(function()
		local lastMouseState = false
		local lastScrollStateUp = false
		local lastScrollStateDown = false

		while true do
			local menuTogglePressed = iskeypressed(RiseUI.ToggleKey)
			if menuTogglePressed and not RiseUI.LastToggleState then
				RiseUI.Visible = not RiseUI.Visible
			end
			RiseUI.LastToggleState = menuTogglePressed

			for _, obj in ipairs(window.globalDrawingObjects) do
				obj.Visible = RiseUI.Visible
			end
			for _, tabData in ipairs(window.tabs) do
				tabData.btn.Visible = RiseUI.Visible
			end
			if not RiseUI.Visible then
				window.roundedParts.shadow:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Shadow, false)
				window.roundedParts.body:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Background, false)
				window.roundedParts.titleDivider:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Accent, false)
				window.roundedParts.sideDivider:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)

				for _, tabData in ipairs(window.tabs) do
					tabData.indicator:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Accent, false)
					for _, obj in ipairs(tabData.tab.drawingObjects) do
						obj.Visible = false
					end
					for _, secList in pairs(tabData.tab.sections) do
						for _, sec in ipairs(secList) do
							sec.underline:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)
							for _, el in ipairs(sec.elements) do
								hideElementVisuals(el)
							end
						end
					end
				end

				for _, tabData in ipairs(window.tabs) do
					for _, secList in pairs(tabData.tab.sections) do
						for _, sec in ipairs(secList) do
							local function processBinds(elements)
								for _, el in ipairs(elements) do
									if el.type == "Toggle" and el.keybindCode then
										local isPressed = iskeypressed(el.keybindCode)
										if el.keybindMode == "Hold" then
											if isPressed ~= el.state then
												el.state = isPressed
												if el.callback then el.callback(el.state) end
											end
										elseif el.keybindMode == "Toggle" then
											if isPressed and not el.lastKeybindState then
												el.state = not el.state
												if el.callback then el.callback(el.state) end
											end
										end
										el.lastKeybindState = isPressed
									elseif el.type == "Category" then
										processBinds(el.elements)
									end
								end
							end
							processBinds(sec.elements)
						end
					end
				end
				task.wait()
				continue
			end

			local currentMouseState = ismouse1pressed()
			local mouseClicked = currentMouseState and not lastMouseState
			local mousePos = getMousePos()

			if mouseClicked and isMouseInArea(window.position, Vector2.new(window.size.X, 30)) then
				window.dragging = true
				window.dragOffset = mousePos - window.position
			end
			if not currentMouseState then
				window.dragging = false
			end
			if window.dragging then
				window.position = mousePos - window.dragOffset
			end

			window.roundedParts.shadow:Set(window.position + Vector2.new(4, 6), window.size, Theme.Shadow, true, 0.45)
			window.roundedParts.body:Set(window.position, window.size, Theme.Background, true)
			outline.Position = window.position
			outline.Size = window.size
			outline.Visible = true

			titleDot.Position = window.position + Vector2.new(16, 16)
			titleText.Position = window.position + Vector2.new(26, 8)

			window.roundedParts.titleDivider:Set(
				window.position + Vector2.new(12, 32),
				Vector2.new(window.size.X - 24, 2),
				Theme.Stroke,
				true
			)
			window.roundedParts.sideDivider:Set(
				window.position + Vector2.new(140, 42),
				Vector2.new(2, window.size.Y - 52),
				Theme.Stroke,
				true
			)

			local currentScrollUp = iskeypressed(0x21)
			local currentScrollDown = iskeypressed(0x22)
			
			if window.activeTab and isMouseInArea(window.position + Vector2.new(142, 42), Vector2.new(window.size.X - 152, window.size.Y - 52)) then
				if currentScrollUp and not lastScrollStateUp then
					window.activeTab.scrollOffset = math.clamp(window.activeTab.scrollOffset - 24, 0, 2000)
				elseif currentScrollDown and not lastScrollStateDown then
					window.activeTab.scrollOffset = math.clamp(window.activeTab.scrollOffset + 24, 0, 2000)
				end
			end
			
			lastScrollStateUp = currentScrollUp
			lastScrollStateDown = currentScrollDown

			local tabY = 46
			for _, tabData in ipairs(window.tabs) do
				local tab = tabData.tab
				local btn = tabData.btn
				local isActive = window.activeTab == tab
				btn.Position = window.position + Vector2.new(26, tabY)

				if isActive then
					btn.Color = Theme.TextPrimary
					tabData.indicator:Set(window.position + Vector2.new(14, tabY + 2), Vector2.new(4, 14), Theme.Accent, true)
				else
					tabData.indicator:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Accent, false)
					if isMouseInArea(btn.Position, Vector2.new(110, 20)) then
						btn.Color = Theme.TextPrimary
						if mouseClicked then
							window.activeTab = tab
						end
					else
						btn.Color = Theme.TextSecondary
					end
				end
				tabY = tabY + 26
			end

			local viewTop = window.position.Y + 42
			local viewBottom = window.position.Y + window.size.Y - 10

			for _, tabData in ipairs(window.tabs) do
				local tab = tabData.tab
				local isCurrent = (window.activeTab == tab)

				if not isCurrent then
					for _, obj in ipairs(tab.drawingObjects) do
						obj.Visible = false
					end
					for _, secList in pairs(tab.sections) do
						for _, sec in ipairs(secList) do
							sec.underline:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)
							for _, el in ipairs(sec.elements) do
								hideElementVisuals(el)
							end
						end
					end
				else
					local maxCalculatedY = 50

					local function layoutColumn(sections, xOffset, dryRun)
						local y = 50 - tab.scrollOffset
						for _, sec in ipairs(sections) do
							local renderTitle = (y >= 50 - tab.scrollOffset)
							local titleObj = sec.drawingObjects[1]
							
							local actualY = window.position.Y + y
							local titleVisible = not dryRun and (actualY >= viewTop and actualY <= viewBottom - 16)
							
							if titleObj then
								if titleVisible then
									titleObj.Position = window.position + Vector2.new(xOffset, y)
									titleObj.Visible = true
									sec.underline:Set(window.position + Vector2.new(xOffset, y + 16), Vector2.new(34, 2), Theme.AccentSecondary, true)
								else
									if not dryRun then
										titleObj.Visible = false
										sec.underline:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)
									end
								end
								y = y + 24
							end

							local function renderElementList(elements, indent)
								for _, el in ipairs(elements) do
									local itemY = window.position.Y + y
									
									if el.type == "Toggle" then
										local elHeight = 24
										local isWithinBounds = (itemY >= viewTop and itemY + elHeight <= viewBottom)
										
										if isWithinBounds and not dryRun then
											local lbl = el.drawingObjects[1]
											local bind = el.bindLbl
											lbl.Visible = true
											lbl.Position = window.position + Vector2.new(xOffset + indent, y)

											local target = el.state and 1 or 0
											el.displayState = lerp(el.displayState, target, 0.35)

											local textWidth = lbl.TextBounds and lbl.TextBounds.X or (#el.text * 7)
											local boxPos = window.position + Vector2.new(xOffset + indent + textWidth + 14, y - 1)
											local boxSize = Vector2.new(16, 16)
											local boxColor = lerpColor(Theme.Stroke, Theme.Accent, el.displayState)
											el.box:Set(boxPos, boxSize, boxColor, true)

											if el.displayState > 0.15 then
												el.checkA.From = boxPos + Vector2.new(3, 8)
												el.checkA.To = boxPos + Vector2.new(6, 12)
												el.checkB.From = boxPos + Vector2.new(6, 12)
												el.checkB.To = boxPos + Vector2.new(13, 4)
												el.checkA.Transparency = 1 - el.displayState
												el.checkB.Transparency = 1 - el.displayState
												el.checkA.Visible = true
												el.checkB.Visible = true
											else
												el.checkA.Visible = false
												el.checkB.Visible = false
											end

											local clickWidth = textWidth + 14 + boxSize.X
											if mouseClicked and isMouseInArea(lbl.Position, Vector2.new(clickWidth, 16)) then
												el.state = not el.state
												if el.callback then el.callback(el.state) end
											end

											if bind then
												bind.Visible = true
												bind.Position = boxPos + Vector2.new(22, 1)
											end
										else
											if not dryRun then hideElementVisuals(el) if el.drawingObjects[1] then el.drawingObjects[1].Visible = false end if el.bindLbl then el.bindLbl.Visible = false end end
										end
										y = y + 24
									elseif el.type == "Slider" then
										local elHeight = 40
										local isWithinBounds = (itemY >= viewTop and itemY + elHeight <= viewBottom)

										if isWithinBounds and not dryRun then
											local lbl = el.drawingObjects[1]
											lbl.Visible = true
											lbl.Position = window.position + Vector2.new(xOffset + indent, y)

											local trackPos = window.position + Vector2.new(xOffset + indent, y + 20)
											local trackSize = Vector2.new(160 - indent, 4)
											el.track:Set(trackPos, trackSize, Theme.Stroke, true)

											local percent = (el.value - el.min) / (el.max - el.min)
											el.fill:Set(trackPos, Vector2.new(trackSize.X * percent, trackSize.Y), Theme.Accent, true)

											local thumbPos = trackPos + Vector2.new(trackSize.X * percent, trackSize.Y / 2)
											el.thumb.Position = thumbPos
											el.thumb.Visible = true
											el.thumbRing.Position = thumbPos
											el.thumbRing.Visible = true

											if currentMouseState and (el.dragging or (mouseClicked and isMouseInArea(trackPos - Vector2.new(0, 6), trackSize + Vector2.new(0, 12)))) then
												el.dragging = true
												local relX = math.clamp(mousePos.X - trackPos.X, 0, trackSize.X)
												local rawVal = el.min + ((relX / trackSize.X) * (el.max - el.min))
												local exactVal = math.round(rawVal / el.step) * el.step
												exactVal = math.clamp(exactVal, el.min, el.max)

												if exactVal ~= el.value then
													el.value = exactVal
													lbl.Text = el.text .. ": " .. tostring(el.value) .. el.suffix
													if el.callback then el.callback(el.value) end
												end
											end
											if not currentMouseState then
												el.dragging = false
											end
										else
											if not dryRun then hideElementVisuals(el) if el.drawingObjects[1] then el.drawingObjects[1].Visible = false end end
										end
										y = y + 40
									elseif el.type == "Dropdown" then
										local boxSize = Vector2.new(190 - indent, 26)
										local expandedHeight = boxSize.Y + 18 + (el.open and (#el.options * 24) or 0)
										local isWithinBounds = (itemY >= viewTop and itemY + 44 <= viewBottom)

										if isWithinBounds and not dryRun then
											local lbl = el.drawingObjects[1]
											lbl.Visible = true
											lbl.Position = window.position + Vector2.new(xOffset + indent, y)

											local boxPos = window.position + Vector2.new(xOffset + indent, y + 18)
											el.box:Set(boxPos, boxSize, Theme.Elevated, true)

											el.valueTxt.Position = boxPos + Vector2.new(10, 7)
											el.valueTxt.Text = tostring(el.value)
											el.valueTxt.Visible = true

											el.arrow.Position = boxPos + Vector2.new(boxSize.X - 22, 7)
											el.arrow.Text = el.open and "^" or "v"
											el.arrow.Visible = true

											if mouseClicked and isMouseInArea(boxPos, boxSize) then
												el.open = not el.open
											end

											if el.open then
												for i, row in ipairs(el.rows) do
													local rowPos = boxPos + Vector2.new(0, boxSize.Y + (i - 1) * 24)
													local rowSize = Vector2.new(boxSize.X, 24)
													
													if rowPos.Y >= viewTop and rowPos.Y + rowSize.Y <= viewBottom then
														local hovered = isMouseInArea(rowPos, rowSize)
														local rowColor = hovered and Theme.Accent or Theme.Elevated

														row.bg:Set(rowPos, rowSize, rowColor, true)
														row.txt.Position = rowPos + Vector2.new(10, 5)
														row.txt.Visible = true

														if mouseClicked and hovered then
															el.value = row.value
															el.open = false
															if el.callback then el.callback(el.value) end
														end
													else
														row.bg:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)
														row.txt.Visible = false
													end
												end
												y = y + ( #el.rows * 24 )
											else
												for _, row in ipairs(el.rows) do
													row.bg:Set(Vector2.new(0, 0), Vector2.new(0, 0), Theme.Stroke, false)
													row.txt.Visible = false
												end
											end
										else
											if not dryRun then hideElementVisuals(el) if el.drawingObjects[1] then el.drawingObjects[1].Visible = false end end
										end

										y = y + 18 + boxSize.Y
									elseif el.type == "Category" then
										local boxSize = Vector2.new(190 - indent, 24)
										local isWithinBounds = (itemY >= viewTop and itemY + boxSize.Y <= viewBottom)

										if isWithinBounds and not dryRun then
											local lbl = el.drawingObjects[1]
											lbl.Visible = true
											lbl.Position = window.position + Vector2.new(xOffset + indent + 8, y + 5)

											local boxPos = window.position + Vector2.new(xOffset + indent, y)
											el.box:Set(boxPos, boxSize, Theme.Elevated, true)

											el.arrow.Position = boxPos + Vector2.new(boxSize.X - 20, 5)
											el.arrow.Text = el.open and "^" or "v"
											el.arrow.Visible = true

											if mouseClicked and isMouseInArea(boxPos, boxSize) then
												el.open = not el.open
											end
										else
											if not dryRun then
												hideElementVisuals(el)
												if el.drawingObjects[1] then el.drawingObjects[1].Visible = false end
											end
										end

										y = y + boxSize.Y + 6

										if el.open then
											renderElementList(el.elements, indent + 12)
										else
											if not dryRun then
												for _, subEl in ipairs(el.elements) do
													local subLbl = subEl.drawingObjects[1]
													if subLbl then subLbl.Visible = false end
													if subEl.bindLbl then subEl.bindLbl.Visible = false end
													hideElementVisuals(subEl)
												end
											end
										end
									end
								end
							end

							renderElementList(sec.elements, 0)
							y = y + 16
						end
						
						local totalYReached = y + tab.scrollOffset
						if totalYReached > maxCalculatedY then
							maxCalculatedY = totalYReached
						end
					end

					layoutColumn(tab.sections.Left, 160, true)
					layoutColumn(tab.sections.Right, 360, true)

					local maxScrollPossible = math.max(0, maxCalculatedY - (window.size.Y - 60))
					tab.scrollOffset = math.clamp(tab.scrollOffset, 0, maxScrollPossible)

					layoutColumn(tab.sections.Left, 160, false)
					layoutColumn(tab.sections.Right, 360, false)
				end
			end

			for _, tabData in ipairs(window.tabs) do
				for _, secList in pairs(tabData.tab.sections) do
					for _, sec in ipairs(secList) do
						local function processAllBinds(elements)
							for _, el in ipairs(elements) do
								if el.type == "Toggle" and el.keybindCode then
									local isPressed = iskeypressed(el.keybindCode)
									if el.keybindMode == "Hold" then
										if isPressed ~= el.state then
											el.state = isPressed
											if el.callback then el.callback(el.state) end
										end
									elseif el.keybindMode == "Toggle" then
										if isPressed and not el.lastKeybindState then
											el.state = not el.state
											if el.callback then el.callback(el.state) end
										end
									end
									el.lastKeybindState = isPressed
								elseif el.type == "Category" then
									processAllBinds(el.elements)
								end
							end
						end
						processAllBinds(sec.elements)
					end
				end
			end

			lastMouseState = currentMouseState
			task.wait()
		end
	end)

	return window
end

safeWriteGlobal("RiseUI", RiseUI)
return RiseUI
