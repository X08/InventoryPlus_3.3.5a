--[[ InventoryPlus by X08 | Dreamwind (Chromiecraft-EU)
     Tabs: magnet tabs on the side of the default bag frames, "+" tab, category picker, hover highlight. ]]

local BT = _G.InventoryPlus
local TAB_W, TAB_H, PLUS_W, GAP = 30, 30, 22, 3
local PAD, OVERLAP = 6, 3

-- every default bag frame (shown or not)
local function EachBagFrame(fn)
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local f = _G["ContainerFrame" .. i]
        if f then fn(f) end
    end
end

-- fn(button, bag, slot) for every item button of a bag frame
local function EachItemButton(frame, fn)
    local bag, name = frame:GetID(), frame:GetName()
    for i = 1, (GetContainerNumSlots(bag) or 0) do
        local b = _G[name .. "Item" .. i]
        if b then fn(b, bag, b:GetID()) end
    end
end
local FADE_TIME = 0.25

-- ============================================================ geometry
-- offsets (frame-local units) of the item grid relative to the bag frame, measured live so it
-- works whatever the frame's real width/art offsets are.
local function Geometry(frame)
    local name = frame:GetName()
    local fl, ft, fr = frame:GetLeft(), frame:GetTop(), frame:GetRight()
    if not (fl and ft and fr) then return end
    local minL, maxR, maxT
    for i = 1, (GetContainerNumSlots(frame:GetID()) or 0) do
        local b = _G[name .. "Item" .. i]
        if b and b:IsShown() then
            local l, r, t = b:GetLeft(), b:GetRight(), b:GetTop()
            if l and r and t then
                minL = minL and math.min(minL, l) or l
                maxR = maxR and math.max(maxR, r) or r
                maxT = maxT and math.max(maxT, t) or t
            end
        end
    end
    if not minL then return end
    return minL - fl, maxR - fr, maxT - ft
end

-- ============================================================ tab buttons
local function CreateTabButton(holder)
    local b = CreateFrame("Button", nil, holder)
    b:SetWidth(TAB_W); b:SetHeight(TAB_H)
    b:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    b:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER", 0, 0)
    b.icon:SetWidth(TAB_W - 10); b.icon:SetHeight(TAB_H - 10)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b:SetScript("OnEnter", function(self)
        if self.def then BT:SetHover(self.def.cats) end
        if self.isPlus and self.SetPlusColor then self:SetPlusColor(1, 0.95, 0.45) end
        GameTooltip:SetOwner(self, BT.db.side == "LEFT" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
        if self.isPlus then
            GameTooltip:AddLine("Add a tab", 1, 1, 1)
            GameTooltip:AddLine("Pick which item types belong in this bag.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Shift-click: open " .. (BT.db.optOpen == "warehouse" and "the Warehouse" or "the options"), 0.5, 0.8, 0.5)
        else
            GameTooltip:AddLine(BT:TabName(self.def), 1, 0.82, 0)
            GameTooltip:AddLine("Holds: " .. BT:CatList(self.def.cats), 0.8, 0.8, 0.8, true)
            if self.def.exclusive then
                GameTooltip:AddLine("Exclusive: other items are moved out of this bag", 1, 0.6, 0.3, true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Left-click: gather items here and sort", 0.5, 0.8, 0.5)
            GameTooltip:AddLine("Shift-click: sort this bag only", 0.5, 0.8, 0.5)
            GameTooltip:AddLine("Right-click: edit tab", 0.5, 0.8, 0.5)
            GameTooltip:AddLine("Drag onto another bag: move the tab and its items", 0.5, 0.8, 0.5)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        BT:SetHover(nil)
        if self.isPlus and self.SetPlusColor then self:SetPlusColor(1, 0.82, 0) end
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self, button)
        if self.isPlus then
            if IsShiftKeyDown() then
                if BT.Options then
                    BT.Options:Show(BT.db.optOpen == "warehouse" and "warehouse" or nil, nil, self.bag)
                end
            else
                BT:ShowPicker(self.bag, nil, self)
            end
        elseif button == "RightButton" then
            BT:ShowPicker(self.bag, self.def, self)
        elseif IsShiftKeyDown() then
            BT:After(function() BT:SortBag(self.bag) end); BT:Kick()
        else
            BT:GatherTab(self.bag, self.def, true)
        end
    end)
    -- dragging a tab onto another bag moves it (the items follow)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        if self.isPlus or not self.def then return end
        GameTooltip:Hide()
        BT:StartTabDrag(self)
    end)
    b:SetScript("OnDragStop", function(self) BT:StopTabDrag() end)
    return b
end

local function PlaceTab(b)
    b:ClearAllPoints()
    if BT.db.side == "LEFT" then
        b:SetPoint("TOPRIGHT", b.holderFrame, "TOPLEFT", b.baseX, b.baseY)
    else
        b:SetPoint("TOPLEFT", b.holderFrame, "TOPRIGHT", b.baseX, b.baseY)
    end
end

-- tabs fade in when a bag opens (or when a tab has just been moved onto a bag)
local function StartFade(h)
    h.animT = 0
    h:SetAlpha(0)
    h:SetScript("OnUpdate", h.OnAnim)
end

local function GetHolder(frame)
    if frame.btHolder then return frame.btHolder end
    local h = CreateFrame("Frame", nil, frame)
    h:SetAllPoints(frame)
    h:SetFrameLevel(frame:GetFrameLevel() + 6)
    h.tabs = {}
    h.animT = FADE_TIME
    h.OnAnim = function(self, elapsed)
        self.animT = self.animT + elapsed
        local p = math.min(1, self.animT / FADE_TIME)
        self:SetAlpha(p)
        if p >= 1 then self:SetScript("OnUpdate", nil) end
    end
    h:SetScript("OnShow", function(self)
        if BT.db and BT.db.anim then StartFade(self) else self:SetAlpha(1) end
    end)
    frame.btHolder = h
    return h
end

function BT:LayoutFrame(frame)
    if not frame or not self.db then return end
    local bag = frame:GetID()
    local h = GetHolder(frame)
    if bag < 0 or bag > 11 or not self:IsUsableBag(bag) or not frame:IsShown() then h:Hide(); return end
    local xl, xr, yt = Geometry(frame)
    if not xl then h:Hide(); return end
    h:Show()
    local db = self.db
    local x = (db.side == "LEFT") and (xl - PAD + OVERLAP) or (xr + PAD - OVERLAP)
    x = x + db.offsetX
    local y = yt - 2 + db.offsetY
    local tabs = self:GetTabs(bag) or {}
    for i, def in ipairs(tabs) do
        local b = h.tabs[i]
        if not b then b = CreateTabButton(h); h.tabs[i] = b end
        b.holderFrame, b.bag, b.def, b.isPlus = frame, bag, def, false
        b:SetAlpha(1)
        local icon, color = self:TabIcon(def)
        b.icon:SetTexture(icon)
        b:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        b.count:SetText(self:CountInBag(bag, def.cats))
        b:SetWidth(TAB_W); b:SetHeight(TAB_H)
        b.baseX, b.baseY = x, y - (i - 1) * (TAB_H + GAP)
        PlaceTab(b)
        b:Show()
    end
    for i = #tabs + 1, #h.tabs do h.tabs[i]:Hide() end

    if db.showPlus and #tabs < BT.MAX_TABS then
        local pb = h.plus
        if not pb then pb = CreateTabButton(h); h.plus = pb end
        pb.holderFrame, pb.bag, pb.def, pb.isPlus = frame, bag, nil, true
        pb.icon:SetTexture(nil); pb.count:SetText("")
        if not pb.barH then      -- a thick golden plus, drawn from two bars (no texture file to go missing)
            pb.barH = pb:CreateTexture(nil, "ARTWORK")
            pb.barH:SetWidth(12); pb.barH:SetHeight(4); pb.barH:SetPoint("CENTER", 0, 0)
            pb.barV = pb:CreateTexture(nil, "ARTWORK")
            pb.barV:SetWidth(4); pb.barV:SetHeight(12); pb.barV:SetPoint("CENTER", 0, 0)
            pb.SetPlusColor = function(self, r, g, b)
                self.barH:SetTexture(r, g, b, 1); self.barV:SetTexture(r, g, b, 1)
            end
            pb:SetPlusColor(1, 0.82, 0)
        end
        pb:SetWidth(PLUS_W); pb:SetHeight(PLUS_W)
        pb:SetBackdropBorderColor(0.6, 0.5, 0.15, 1)
        pb.baseX = x + (db.side == "LEFT" and 2 or -2)
        pb.baseY = y - #tabs * (TAB_H + GAP)
        PlaceTab(pb)
        pb:Show()
    elseif h.plus then
        h.plus:Hide()
    end
end

function BT:RefreshTabs()
    EachBagFrame(function(f)
        if f:IsShown() then self:LayoutFrame(f); self:MarkFrame(f) end
    end)
    self:ApplyHighlight()
end

-- ============================================================ hover highlight / dim
BT.hoverCats = nil

local function GlowFor(btn)
    if btn.btGlow then return btn.btGlow end
    local g = btn:CreateTexture(nil, "OVERLAY")
    g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    g:SetBlendMode("ADD")
    g:SetPoint("CENTER", btn, "CENTER", 0, 0)
    g:SetWidth(btn:GetWidth() * 1.85); g:SetHeight(btn:GetHeight() * 1.85)
    g:Hide()
    btn.btGlow = g
    return g
end

local function ApplyButton(btn, bag, slot)
    local cats = BT.hoverCats
    if not cats then
        btn:SetAlpha(1)
        if btn.btGlow then btn.btGlow:Hide() end
        return
    end
    local link = GetContainerItemLink(bag, slot)
    local cat = link and BT:Classify(link, bag, slot)
    if cat and BT:Matches(cats, cat) then
        btn:SetAlpha(1)
        local g = GlowFor(btn)
        local c = BT.CAT[cat].color
        g:SetVertexColor(c[1], c[2], c[3], 0.9)
        g:Show()
    else
        btn:SetAlpha(BT.db.dimAlpha)
        if btn.btGlow then btn.btGlow:Hide() end
    end
end

-- tiny gold pin on ignored items
local function MarkButton(btn, bag, slot)
    local link = BT.db.ignoreMark and GetContainerItemLink(bag, slot)
    if link and BT:IsIgnored(link) then
        if not btn.ipMark then
            local m = btn:CreateTexture(nil, "OVERLAY")
            m:SetWidth(7); m:SetHeight(7); m:SetPoint("TOPLEFT", 3, -3)
            m:SetTexture(1, 0.82, 0, 0.95)
            btn.ipMark = m
        end
        btn.ipMark:Show()
    elseif btn.ipMark then
        btn.ipMark:Hide()
    end
end

function BT:MarkFrame(frame) EachItemButton(frame, MarkButton) end

local function ApplyFrame(frame) EachItemButton(frame, ApplyButton) end

function BT:ApplyHighlight()
    EachBagFrame(function(f) if f:IsShown() then ApplyFrame(f) end end)
    if BankFrame and BankFrame:IsShown() then
        for i = 1, (NUM_BANKGENERIC_SLOTS or 28) do
            local b = _G["BankFrameItem" .. i]
            if b then ApplyButton(b, -1, b:GetID()) end
        end
    end
end

function BT:SetHover(cats)
    self.hoverCats = cats
    self:ApplyHighlight()
end

-- ============================================================ category picker (add / edit a tab)
local picker
local PW, ROWS, COLS, ROWH, COLW = 404, 8, 2, 22, 180

-- what the tree currently shows: top-level categories, plus the sub-categories of the opened ones
local function PickerRows(p)
    local rows = {}
    for _, c in ipairs(BT.CATS) do
        if not c.parent then
            rows[#rows + 1] = c
            if BT.SUBS[c.key] and p.open[c.key] then
                for _, sk in ipairs(BT.SUBS[c.key]) do rows[#rows + 1] = BT.CAT[sk] end
            end
        end
    end
    return rows
end

local function UpdatePicker(p)
    local rows = PickerRows(p)
    FauxScrollFrame_Update(p.scroll, #rows, ROWS * COLS, ROWH)
    local off = FauxScrollFrame_GetOffset(p.scroll)
    for i, r in ipairs(p.rows) do
        local c = rows[i + off]
        if c then
            r.catKey = c.key
            local isSub = c.parent ~= nil
            local inherited = isSub and p.cats[c.parent]       -- the parent is ticked: everything below is in
            r.check:ClearAllPoints()
            r.check:SetPoint("LEFT", isSub and 36 or 18, 0)
            r.label:SetWidth(isSub and 108 or 126)
            r.check:SetChecked((p.cats[c.key] or inherited) and true or false)
            if inherited then r.check:Disable() else r.check:Enable() end
            r.label:SetText(c.label)
            r.label:SetTextColor(c.color[1], c.color[2], c.color[3])
            if BT.SUBS[c.key] then
                r.exp:Show(); r.exp.text:SetText(p.open[c.key] and "-" or "+")
            else
                r.exp:Hide()
            end
            r:Show()
        else
            r:Hide()
        end
    end
end

local function BuildPicker()
    local p = CreateFrame("Frame", "InventoryPlusPicker", UIParent)
    p:SetWidth(PW); p:SetFrameStrata("DIALOG"); p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    p:Hide()
    tinsert(UISpecialFrames, "InventoryPlusPicker")
    p.open, p.cats = {}, {}

    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.title:SetPoint("TOP", 0, -14)

    local lbl = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", 20, -38); lbl:SetText("Name (optional)")
    p.name = CreateFrame("EditBox", "InventoryPlusPickerName", p, "InputBoxTemplate")
    p.name:SetWidth(PW - 56); p.name:SetHeight(20); p.name:SetAutoFocus(false)
    p.name:SetPoint("TOPLEFT", 26, -54)
    p.name:SetMaxLetters(24)
    p.name:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)

    local top = -86
    local sf = CreateFrame("ScrollFrame", "InventoryPlusPickerScroll", p, "FauxScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, top); sf:SetWidth(COLS * COLW + 4); sf:SetHeight(ROWS * ROWH)
    sf:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROWH, function() UpdatePicker(p) end)
    end)
    p.scroll = sf
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, delta)
        local sb = _G["InventoryPlusPickerScrollScrollBar"]
        sb:SetValue(sb:GetValue() - delta * ROWH * 2)
    end)

    p.rows = {}
    for i = 1, ROWS * COLS do
        local r = CreateFrame("Frame", nil, p)
        local col, line = math.floor((i - 1) / ROWS), (i - 1) % ROWS      -- fills the left column first
        r:SetWidth(COLW - 4); r:SetHeight(ROWH)
        r:SetPoint("TOPLEFT", 14 + col * COLW, top - line * ROWH)
        r.exp = CreateFrame("Button", nil, r)
        r.exp:SetWidth(18); r.exp:SetHeight(18); r.exp:SetPoint("LEFT", 0, 0)
        r.exp.text = r.exp:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        r.exp.text:SetPoint("CENTER", 0, 0)
        r.exp.row = r
        r.exp:SetScript("OnClick", function(self)
            local k = self.row.catKey
            p.open[k] = (not p.open[k]) or nil
            UpdatePicker(p)
        end)
        local n = "InventoryPlusPickerRow" .. i
        local cb = CreateFrame("CheckButton", n, r, "UICheckButtonTemplate")
        cb:SetWidth(22); cb:SetHeight(22)
        cb:SetHitRectInsets(0, -100, 0, 0)          -- the label counts as part of the button
        cb.row = r
        r.check = cb
        r.label = _G[n .. "Text"]
        r.label:SetFontObject(GameFontHighlightSmall)
        cb:SetScript("OnClick", function(self)
            p.cats[self.row.catKey] = self:GetChecked() and true or nil
            UpdatePicker(p)
        end)
        cb:SetScript("OnEnter", function(self)
            local def = BT.CAT[self.row.catKey]
            if not def then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(def.full, def.color[1], def.color[2], def.color[3])
            if def.prof then GameTooltip:AddLine("Professions: " .. def.prof, 0.7, 0.7, 0.7, true) end
            GameTooltip:AddLine(def.hint or "", 0.9, 0.9, 0.9, true)
            if BT.SUBS[def.key] then
                GameTooltip:AddLine("Ticking this includes all of its sub-categories. Use +/- to pick single ones.", 0.5, 0.8, 0.5, true)
            end
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p.rows[i] = r
    end

    local y = top - ROWS * ROWH - 8
    p.excl = CreateFrame("CheckButton", "InventoryPlusPickerExclusive", p, "UICheckButtonTemplate")
    p.excl:SetWidth(24); p.excl:SetHeight(24); p.excl:SetPoint("TOPLEFT", 14, y)
    p.excl:SetHitRectInsets(0, -200, 0, 0)
    local et = _G["InventoryPlusPickerExclusiveText"]
    et:SetText("Exclusive bag"); et:SetFontObject(GameFontNormalSmall)
    p.excl:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Exclusive bag", 1, 0.82, 0)
        GameTooltip:AddLine("Only the item types on this bag's tabs may live here. Everything else is moved to your other bags, which are filled first. Strangers only stay here when no other slot is free.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    p.excl:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y = y - 30

    p.save = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.save:SetWidth(84); p.save:SetHeight(22); p.save:SetPoint("TOPLEFT", 16, y)
    p.remove = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.remove:SetWidth(84); p.remove:SetHeight(22); p.remove:SetPoint("LEFT", p.save, "RIGHT", 6, 0)
    p.remove:SetText("Remove")
    p.cancel = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.cancel:SetWidth(84); p.cancel:SetHeight(22); p.cancel:SetPoint("LEFT", p.remove, "RIGHT", 6, 0)
    p.cancel:SetText("Cancel")
    p:SetHeight(-y + 22 + 16)

    p.cancel:SetScript("OnClick", function() p:Hide() end)
    p.save:SetScript("OnClick", function()
        if not next(p.cats) then BT:Print("pick at least one item type"); return end
        local name = strtrim(p.name:GetText() or "")
        if name == "" then name = nil end
        local copy = {}
        for k in pairs(p.cats) do copy[k] = true end
        for k in pairs(copy) do                      -- a ticked parent already covers its sub-categories
            local par = BT.PARENT[k]
            if par and copy[par] then copy[k] = nil end
        end
        local excl = p.excl:GetChecked() and true or nil
        if p.def then
            p.def.cats, p.def.name, p.def.exclusive = copy, name, excl
        else
            local tabs = BT:GetTabs(p.bag, true)
            if #tabs >= BT.MAX_TABS then BT:Print("a bag can hold " .. BT.MAX_TABS .. " tabs"); return end
            tinsert(tabs, { cats = copy, name = name, exclusive = excl })
        end
        p:Hide()
        BT:OnTabsChanged()
        if excl then BT:After(function() BT:CleanBag(p.bag) end); BT:Kick() end
    end)
    p.remove:SetScript("OnClick", function()
        if p.def then
            local tabs = BT:GetTabs(p.bag)
            for i, d in ipairs(tabs) do if d == p.def then tremove(tabs, i); break end end
            if #tabs == 0 then BT.chardb.bags[p.bag] = nil end
        end
        p:Hide()
        BT:OnTabsChanged()
    end)
    return p
end

function BT:ShowPicker(bag, def, anchor)
    picker = picker or BuildPicker()
    picker.bag, picker.def, picker.cats, picker.open = bag, def, {}, {}
    if def then
        for k in pairs(def.cats) do
            picker.cats[k] = true
            if BT.PARENT[k] then picker.open[BT.PARENT[k]] = true end      -- show the sub-categories this tab uses
        end
    end
    picker.excl:SetChecked(def and def.exclusive and true or false)
    picker.name:SetText(def and def.name or "")
    picker.title:SetText((def and "Edit tab" or "New tab") .. " - " .. self:BagLabel(bag))
    picker.save:SetText(def and "Save" or "Add")
    if def then picker.remove:Show() else picker.remove:Hide() end
    -- scroll so the first category this tab uses is in view
    local first = 0
    for i, c in ipairs(PickerRows(picker)) do
        if picker.cats[c.key] then first = i - 1; break end
    end
    local sb = _G["InventoryPlusPickerScrollScrollBar"]
    if sb then sb:SetValue(math.max(0, first - 1) * ROWH) end
    UpdatePicker(picker)
    picker:ClearAllPoints()
    if anchor then
        if self.db.side == "LEFT" then picker:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0)
        else picker:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0) end
    else
        picker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    picker:Show()
end

-- ============================================================ dragging a tab to another bag
local ghost

local function ValidTarget(f)
    local d = BT.dragging
    if not d or not f or not f:IsShown() then return false end
    local bag = f:GetID()
    return bag ~= d.bag and BT:Domain(bag) == BT:Domain(d.bag) and BT:IsUsableBag(bag)
end

local function DropOverlay(f)
    local h = f.btHolder
    if not h then return end
    if not h.drop then
        h.drop = h:CreateTexture(nil, "OVERLAY")
        h.drop:SetAllPoints(f)
        h.drop:SetTexture(1, 0.82, 0, 0.18)
        h.drop:Hide()
    end
    return h.drop
end

local function TargetUnderMouse()
    local found
    EachBagFrame(function(f)
        if not found and ValidTarget(f) and MouseIsOver(f) then found = f end
    end)
    return found
end

function BT:StartTabDrag(tab)
    if self.dragging then return end
    self.dragging = { def = tab.def, bag = tab.bag }
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetFrameStrata("TOOLTIP"); ghost:SetWidth(TAB_W); ghost:SetHeight(TAB_H)
        ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
        ghost.icon:SetAllPoints(ghost); ghost.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        ghost:SetScript("OnUpdate", function(self)
            local x, y = GetCursorPosition()
            local s = UIParent:GetEffectiveScale()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
            local over = TargetUnderMouse()
            EachBagFrame(function(f)
                local o = DropOverlay(f)
                if o then if f == over then o:Show() else o:Hide() end end
            end)
        end)
    end
    ghost.icon:SetTexture((BT:TabIcon(tab.def)))
    ghost:Show()
    tab:SetAlpha(0.35)
end

function BT:StopTabDrag()
    local d = self.dragging
    if not d then return end
    local target = TargetUnderMouse()
    self.dragging = nil
    if ghost then ghost:Hide() end
    EachBagFrame(function(f)
        local o = f.btHolder and f.btHolder.drop
        if o then o:Hide() end
    end)
    if target and self:MoveTab(d.def, d.bag, target:GetID()) then
        for _, f in ipairs({ target }) do          -- let the tab snap onto its new bag
            if f.btHolder and self.db.anim then
                StartFade(f.btHolder)
            end
        end
    end
    self:RefreshTabs()
end

function BT:OnTabsChanged()
    self:RefreshTabs()
    if self.Options and self.Options.Refresh then self.Options:Refresh() end
end

-- ============================================================ hooks
BT:OnInit(function()
    hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
        BT:LayoutFrame(frame)
        if BT.hoverCats then ApplyFrame(frame) end
    end)
    hooksecurefunc("ContainerFrame_Update", function(frame)
        if frame:IsShown() then BT:MarkFrame(frame) end
        if frame.btHolder and frame:IsShown() then BT:LayoutFrame(frame) end
        if BT.hoverCats then ApplyFrame(frame) end
    end)

    -- Alt-click an item in a bag: add it to / remove it from the ignore list
    local lastToggle = 0
    local function AltClick(self, button)
        if button ~= "LeftButton" or not IsAltKeyDown() or IsShiftKeyDown() or IsControlKeyDown() then return end
        if GetTime() - lastToggle < 0.2 then return end      -- both Blizzard handlers may fire for one click
        local bag, slot = self:GetParent():GetID(), self:GetID()
        local link = GetContainerItemLink(bag, slot)
        local id = BT.ItemID(link)
        if not id then return end
        lastToggle = GetTime()
        local on = not BT.db.ignore[id]
        BT:SetIgnored(id, on)
        BT:Print((on and "ignoring " or "no longer ignoring ") .. link .. (on and " (never moved, sorted or deleted)" or ""))
    end
    if ContainerFrameItemButton_OnModifiedClick then hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", AltClick) end
    if ContainerFrameItemButton_OnClick then hooksecurefunc("ContainerFrameItemButton_OnClick", AltClick) end

    -- make room between bag columns so side tabs do not sit on top of the neighbouring bag
    if updateContainerFrameAnchors then
        hooksecurefunc("updateContainerFrameAnchors", function()
            if not BT.db.pushColumns then return end
            local list = ContainerFrame1 and ContainerFrame1.bags
            if not list then return end
            local extra = TAB_W + 6
            local col = -1
            for _, fname in ipairs(list) do
                local f = _G[fname]
                if f and f:IsShown() then
                    local point, rel, relPoint, x, y = f:GetPoint(1)
                    if rel == UIParent or rel == f:GetParent() then
                        col = col + 1
                        local shift = (BT.db.side == "LEFT") and (col * extra) or ((col + 1) * extra)
                        f:SetPoint(point, rel, relPoint, x - shift, y)
                    end
                end
            end
        end)
    end
end)
