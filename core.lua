local MAX_STACK = 10000 -- The maximum stack size accepted by the stack split frame.

-----------------
--END OF CONFIG--
-----------------

function BulkBuyMerchantItem(slot, amount)
	local stackSize = GetMerchantItemMaxStack(slot)
	
	while amount > stackSize do -- Buy as many full stacks as we can
		BuyMerchantItem(slot, stackSize)
		amount = amount - stackSize
	end
	
	if amount > 0 then -- Buy any leftover items
		BuyMerchantItem(slot, amount)
	end
end

local function MerchantItemButton_SplitStack(self, split)
	if self.extendedCost then
		MerchantFrame_ConfirmExtendedBulkItemCost(self, split)
	elseif split > 0 then
		BulkBuyMerchantItem(self:GetID(), split)
	end
end

-- Overwrite the default UI's SplitStack method
-- There are 12 MerchantItemXItemButtons, but the merchant frame only uses the first 10; the others are only used by the buyback window
for i = 1, 10 do
	local button = _G["MerchantItem".. i .."ItemButton"]
	button.SplitStack = MerchantItemButton_SplitStack
end

StaticPopupDialogs["CONFIRM_PURCHASE_TOKEN_ITEM"].OnAccept = function()
	BulkBuyMerchantItem(MerchantFrame.itemIndex, MerchantFrame.count or 1)
end
	
-- Slightly modified version of the default MerchantFrame_ConfirmExtendedItemCost function that calls BulkBuyMerchantItem instead of BuyMerchantItem
function MerchantFrame_ConfirmExtendedBulkItemCost(itemButton, numToPurchase)
	print("itemButton:", itemButton, itemButton:GetName(), "numToPurchase:", numToPurchase)
	local index = itemButton:GetID();
	local itemsString;
	if ( GetMerchantItemCostInfo(index) == 0 ) then
		BulkBuyMerchantItem( itemButton:GetID(), numToPurchase );
		return;
	end
	
	MerchantFrame.itemIndex = index;
	MerchantFrame.count = numToPurchase;
	
	local stackCount = itemButton.count or 1;
	numToPurchase = numToPurchase or stackCount;
	
	local maxQuality = 0;
	local usingCurrency = false;
	for i=1, MAX_ITEM_COST, 1 do
		local itemTexture, costItemCount, itemLink, currencyName = GetMerchantItemCostItem(index, i);
		costItemCount = costItemCount * (numToPurchase / stackCount); -- cost per stack times number of stacks
		if ( itemLink ) then
			local _, _, itemQuality = GetItemInfo(itemLink);
			maxQuality = math.max(itemQuality, maxQuality);
			if ( itemsString ) then
				itemsString = itemsString .. LIST_DELIMITER .. format(ITEM_QUANTITY_TEMPLATE, costItemCount, itemLink);
			else
				itemsString = format(ITEM_QUANTITY_TEMPLATE, costItemCount, itemLink);
			end
		elseif ( currencyName ) then
			usingCurrency = true;
			if ( itemsString ) then
				itemsString = itemsString .. ", |T"..itemTexture..":0:0:0:-1|t ".. format(CURRENCY_QUANTITY_TEMPLATE, costItemCount, currencyName);
			else
				itemsString = " |T"..itemTexture..":0:0:0:-1|t "..format(CURRENCY_QUANTITY_TEMPLATE, costItemCount, currencyName);
			end
		end
	end
	
	if ( not usingCurrency and maxQuality <= LE_ITEM_QUALITY_UNCOMMON ) then
		BulkBuyMerchantItem( itemButton:GetID(), numToPurchase );
		return;
	end
	
	
	local itemName = "YOU HAVE FOUND A BUG!";
	local itemQuality = 1;
	local _;
	local r, g, b = 1, 1, 1;
	if(itemButton.link) then
		itemName, _, itemQuality = GetItemInfo(itemButton.link);
		r, g, b = GetItemQualityColor(itemQuality); 
	elseif(itemName) then		-- This is the case for a currency, which don't support links yet
		itemName = itemButton.name;
		r, g, b = GetItemQualityColor(1); 
	end
	
	StaticPopup_Show("CONFIRM_PURCHASE_TOKEN_ITEM", itemsString, "", {["texture"] = itemButton.texture, ["name"] = itemName, ["color"] = {r, g, b, 1}, ["link"] = itemButton.link, ["index"] = index, ["count"] = numToPurchase});
end

local function MerchantItemButton_OnModifiedClick_Hook(self, button)
	if self.hasStackSplit == 1 then
		UpdateStackSplitFrame(MAX_STACK)
	elseif MerchantFrame.selectedTab == 1 and IsModifiedClick("SPLITSTACK") then
		local _, _, _, stackCount, _, _, extendedCost = GetMerchantItemInfo(self:GetID())
		if stackCount > 1 and extendedCost then return end
		
		OpenStackSplitFrame(MAX_STACK, self, "BOTTOMLEFT", "TOPLEFT")
	end
end

hooksecurefunc("MerchantItemButton_OnModifiedClick", MerchantItemButton_OnModifiedClick_Hook)