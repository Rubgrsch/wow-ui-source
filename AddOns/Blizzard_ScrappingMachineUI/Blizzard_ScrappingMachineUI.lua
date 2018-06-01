ScrappingMachineMixin = {};

function ScrappingMachineMixin:SetupScrapButtonPool()
	self.ItemSlots.scrapButtons:ReleaseAll(); 
	
	local width, height = 53, 53; 
	local columnNum, rowNum = 3, 3; 
	local slotCount = 0; 
	
	for i = 1, columnNum do
		for j = 1, rowNum do
			local button = self.ItemSlots.scrapButtons:Acquire();
			button.SlotNumber = slotCount; 
			slotCount = slotCount + 1; 
			button:SetPoint("BOTTOMLEFT", self.ItemSlots, "BOTTOMLEFT", (i - 1) * (width - i) + 2, (j - 1) * (height - j) + 2);
			button:Show();
		end
	end
end

function ScrappingMachineMixin:ScrapItems()
	C_ScrappingMachineUI.ScrapItems();
end

function ScrappingMachineMixin:UpdateScrapButtonState()
	self.ScrapButton:SetEnabled(C_ScrappingMachineUI.HasScrappableItems()); 
end

function ScrappingMachineMixin:OnLoad()
	self.ItemSlots.scrapButtons = CreateFramePool("BUTTON", self.ItemSlots, "ScrappingMachineItemSlot");
	self:SetupScrapButtonPool(); 
	
	SetPortraitToTexture(self.portrait, "Interface\\Icons\\inv_gizmo_03");
	self.TitleText:SetText(SCRAPPING_MACHINE_TITLE);	
	
	self:RegisterEvent("SCRAPPING_MACHINE_CLOSE");
	self:RegisterEvent("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED");
	self:RegisterEvent("SCRAPPING_MACHINE_SCRAPPING_FINISHED");
	
	self:Show(); 
end

function ScrappingMachineMixin:OnShow()
	self:UpdateScrapButtonState();
	self:RegisterUnitEvent("UNIT_SPELLCAST_START", "player");
	self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player");
	self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player");
end

function ScrappingMachineMixin:OnEvent(event, ...)
	if (event == "SCRAPPING_MACHINE_PENDING_ITEM_CHANGED") then
		self:UpdateScrapButtonState();
	elseif (event == "UNIT_SPELLCAST_START") then
		local unitTag, lineID, spellID = ...;
		if spellID == C_ScrappingMachineUI.GetScrapSpellID() then
			self.scrapCastLineID = lineID;
		end
	elseif (event == "UNIT_SPELLCAST_INTERRUPTED") then
		local unitTag, lineID, spellID = ...;
		if self.scrapCastLineID and self.scrapCastLineID == lineID then
			self.scrapCastLineID = nil;
		end
	elseif (event == "UNIT_SPELLCAST_STOP") then
		local unitTag, lineID, spellID = ...;
		if self.scrapCastLineID and self.scrapCastLineID == lineID then
			C_ScrappingMachineUI.RemoveCurrentScrappingItem();
		end
	elseif (event == "SCRAPPING_MACHINE_CLOSE") then
		HideUIPanel(self);
	elseif (event == "SCRAPPING_MACHINE_SCRAPPING_FINISHED") then 
		C_ScrappingMachineUI.RemoveAllScrapItems();
	end
end

function ScrappingMachineMixin:OnHide()
	C_ScrappingMachineUI.RemoveAllScrapItems();

	self:UnregisterEvent("UNIT_SPELLCAST_START");
	self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED");
	self:UnregisterEvent("UNIT_SPELLCAST_STOP");
	self.scrapCastLineID = nil;
	C_ScrappingMachineUI.CloseScrappingMachine(); 
end

ScrappingMachineItemSlotMixin = {};

function ScrappingMachineItemSlotMixin:RefreshIcon()
	self.itemLocation = C_ScrappingMachineUI.GetCurrentPendingScrapItemLocationByIndex(self.SlotNumber);
	if (not self.itemLocation) then
		self:ClearSlot();
		return;
	end
	
	self.item = Item:CreateFromItemLocation(self.itemLocation);
	if (self.item:IsItemEmpty()) then
		self:ClearSlot();
		return;
	end
	
	self.itemDataLoadedCancelFunc = self.item:ContinueWithCancelOnItemLoad(function()
		local itemName = self.item:GetItemName(); 
		local itemRarity = self.item:GetItemQuality(); 
		local itemTexture = self.item:GetItemIcon(); 
		self.itemLink = self.item:GetItemLink();
		if (itemName) then 
			self.Icon:SetTexture(itemTexture);
			SetItemButtonQuality(self, itemRarity, self.itemLink); 
			self.Icon:Show();
		end		
	end);
end

function ScrappingMachineItemSlotMixin:ClearSlot()
	self.Icon:Hide();
	self.IconBorder:Hide();
	self.IconOverlay:Hide(); 
	self.itemLink = nil;
end

function ScrappingMachineItemSlotMixin:Clear()
	self.itemLocation = nil; 
	self.item = nil; 
	if (self.itemDataLoadedCancelFunc) then
		self.itemDataLoadedCancelFunc();
		self.itemDataLoadedCancelFunc = nil; 
	end
	self.itemName = nil; 
	self.itemRarity = nil;
	self.itemTexture = nil; 
	self.itemLink = nil;
end

function ScrappingMachineItemSlotMixin:OnLoad()
	self:RegisterForClicks("LeftButtonDown");
	self:RegisterForClicks("RightButtonDown");
	self:RegisterForDrag("LeftButton");
	self:RegisterEvent("SCRAPPING_MACHINE_PENDING_ITEM_CHANGED");
end

function ScrappingMachineItemSlotMixin:OnEvent(event, ...)
	if (event == "SCRAPPING_MACHINE_PENDING_ITEM_CHANGED") then
		self:RefreshIcon();
	end
	if (GameTooltip:GetOwner() == self) then
		self:OnMouseEnter();
	end
end

function ScrappingMachineItemSlotMixin:OnClick(button)
	self:Clear(); 
	C_ScrappingMachineUI.RemoveItemToScrap(self.SlotNumber); 
	C_ScrappingMachineUI.DropPendingScrapItemFromCursor(self.SlotNumber);
end

function ScrappingMachineItemSlotMixin:OnDragStart()
	self:OnClick();
end

function ScrappingMachineItemSlotMixin:OnReceiveDrag()
	self:OnClick();
end

function ScrappingMachineItemSlotMixin:OnMouseEnter()
	if (self.itemLink) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetHyperlink(self.itemLink);
	else
		GameTooltip_Hide();
	end
end

function ScrappingMachineItemSlotMixin:OnMouseLeave()
	GameTooltip_Hide();
end