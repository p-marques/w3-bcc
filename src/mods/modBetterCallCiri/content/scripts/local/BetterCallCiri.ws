// Better Call Ciri 2.x - 2022, pMarK

class CBetterCallCiri {

	private var inGameConfigWrapper : CInGameConfigWrapper;
	private var ciriItems: array<SBCCCachedItem>;
	private var blacklistedItemNames: array<name>;
	private var dlcManager: CDLCManager;
	private var desiredAppearance: name;

	public function Init()
	{
		inGameConfigWrapper = theGame.GetInGameConfigWrapper();

		SetupInputs();

		blacklistedItemNames.PushBack('Zireael Sword');
		blacklistedItemNames.PushBack('Ciri Zireael Sword Scabbard');
	}

	private function SetupInputs()
	{
		theInput.RegisterListener(this, 'OnCommBCToggleReplacer', 'BCToggleReplacer');
		theInput.RegisterListener(this, 'OnCommBCCallHorse', 'BCCallHorse');
	}

	event OnCommBCToggleReplacer(action:SInputAction)
	{
		if(IsPressed(action))
		{
			if(thePlayer.IsCiri())
			{
				SaveCiriItems();

				theGame.GameplayFactsSet('BetterCallCiriIsActiveBool', 1);
				theGame.ChangePlayer("Geralt");
			}
			else
			{
				theGame.GameplayFactsSet('BetterCallCiriIsActiveBool', 2);
				theGame.ChangePlayer("Ciri", GetDesiredAppearance(true));
			}
		}
	}

	event OnCommBCCallHorse(action:SInputAction)
	{
		var path: string;
		var app: name;

		if(IsPressed(action))
		{
			if(!thePlayer.IsInInterior() && !thePlayer.IsInAir())
			{
				theGame.OnSpawnPlayerHorse();
			}
			else
			{
				if(thePlayer.IsInInterior())
					thePlayer.DisplayActionDisallowedHudMessage( EIAB_Undefined, false, true );
				else
					thePlayer.DisplayActionDisallowedHudMessage( EIAB_CallHorse );
			}
		}
	}

	public function GetBlockLooting(): bool
	{
		return inGameConfigWrapper.GetVarValue('BCC', 'lootSwitch');
	}

	public function GetSuppressRageEffect(): bool
	{
		return inGameConfigWrapper.GetVarValue('BCC', 'suppressRageEffect');
	}

	public function GetEnableRageMode(): bool
	{
		return inGameConfigWrapper.GetVarValue('BCC', 'enableRageMode');
	}

	public function GetDesiredAppearance(optional update: bool): name
	{
		if (update)
			UpdateDesiredAppearance();

		return desiredAppearance;
	}

	private function UpdateDesiredAppearance()
	{
		var menu_value: int;
		var isDLCAvailable: bool;

		menu_value = StringToInt(inGameConfigWrapper.GetVarValue('BCC', 'appearance'));
		isDLCAvailable = IsCiriAltAppearanceAvailable();

		switch(menu_value)
		{
			case 0:
				if (isDLCAvailable)
					desiredAppearance = 'ciri_dlc';
				else
					desiredAppearance = 'ciri_player';
				break;
			case 1:
				if (isDLCAvailable)
					desiredAppearance = 'ciri_winter_dlc';
				else
					desiredAppearance = 'ciri_winter';
				break;
			case 2:
				desiredAppearance = 'ciri_player_bandaged';
				break;
		}
	}

	private function IsCiriAltAppearanceAvailable(): bool
	{
		if (!dlcManager)
			dlcManager = theGame.GetDLCManager();

		return dlcManager.IsDLCEnabled('dlc_011_002');
	}

	private function SaveCiriItems()
	{
		var i: int;
		var ciri: W3ReplacerCiri;
		var ciriInventory: CInventoryComponent;
		var items: array<SItemUniqueId>;
		var item: SItemUniqueId;
		var cachedItem: SBCCCachedItem;

		ciri = (W3ReplacerCiri)thePlayer;
		ciriInventory = ciri.GetInventory();

		ciriInventory.GetAllItems(items);

		ciriItems.Clear();
		for (i = 0; i < items.Size(); i += 1)
		{
			item = items[i];

			cachedItem.quantity = ciriInventory.GetItemQuantity(item);

			cachedItem.itemName = ciriInventory.GetItemName(item);

			if (!blacklistedItemNames.Contains(cachedItem.itemName))
			{
				ciriItems.PushBack(cachedItem);
				ciriInventory.RemoveItem(item, cachedItem.quantity);
			}
		}
	}

	public function TransferSavedItemsToGeralt(witcher: W3PlayerWitcher)
	{
		var i: int;
		var inv: CInventoryComponent;

		if (!witcher)
			return;

		inv = witcher.GetInventory();

		for (i = 0; i < ciriItems.Size(); i += 1)
			inv.AddAnItem(ciriItems[i].itemName, ciriItems[i].quantity);
	}
}

struct SBCCCachedItem
{
	var itemName : name;
	var quantity : int;
}