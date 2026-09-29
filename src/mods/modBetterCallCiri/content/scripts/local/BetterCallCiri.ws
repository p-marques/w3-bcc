// Better Call Ciri 3.0 - 2026, pMarK

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
		blacklistedItemNames.PushBack('q403_ciri_meteor');
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

// BetterCallCiri: Witcher 3 5.0 integrations. Annotations target the base-game classes.
// Remove the nine obsolete BCC game/ replacement scripts when upgrading.
// Method replacements can still conflict with other mods targeting the same methods.

// BetterCallCiri: private, non-saved fields; type defaults are NULL, false and empty name.

@addField(CR4Game)
private var betterCallCiri : CBetterCallCiri;

@addField(W3ReplacerCiri)
private var betterCallCiriAddedRage : bool; // Default: false.

@addField(CR4GuiSceneController)
private var _pendingEntityAnimation : name; // Default: ''.

// BetterCallCiri: initialize after the original startup, on both new and restored games.
@wrapMethod(CR4Game)
function OnGameStarted(restored : bool)
{
	var handled : bool;
	handled = wrappedMethod(restored);
	betterCallCiri = new CBetterCallCiri in this;
	betterCallCiri.Init();
	return handled;
}

// BetterCallCiri: redirect before the original selects or remembers the glossary page.
@wrapMethod(CR4GlossaryMainMenu)
function OnRequestMenu(MenuName : name, MenuState : string)
{
	if (thePlayer.IsCiri() && MenuName == 'CraftingMenu')
	{
		MenuName = 'GlossaryBestiaryMenu';
		MenuState = "";
	}
	return wrappedMethod(MenuName, MenuState);
}

// BetterCallCiri: an ordinary queued request replaces any earlier animated request.
@wrapMethod(CR4GuiSceneController)
function SetEntityTemplate(entityTemplateAlias : string)
{
	if (_isEntitySpawning)
	{
		_pendingEntityAnimation = '';
	}
	wrappedMethod(entityTemplateAlias);
}

// BetterCallCiri: preserve the original body/sword effect lifecycle, including stopping effects.
@wrapMethod(W3ReplacerCiri)
function EnableRageEffect(enable : bool)
{
	var suppress : bool;
	suppress = theGame.GetBetterCallCiri().GetSuppressRageEffect();
	wrappedMethod(enable && !suppress);
}

// BetterCallCiri: CR4Game.GetBetterCallCiri
@addMethod(CR4Game)
public function GetBetterCallCiri(): CBetterCallCiri
{
	return betterCallCiri;
}

// BetterCallCiri: W3ReplacerCiri.SetupBetterCallCiri
@addMethod(W3ReplacerCiri)
private function SetupBetterCallCiri()
{
	var abilities : array<name>;
	var i : int;

	if(theGame.GameplayFactsQuerySum('BetterCallCiriIsActiveBool') == 2)
	{
		UnblockAction( EIAB_OpenInventory, 'being_ciri' );
		UnblockAction( EIAB_OpenGwint, 'being_ciri' );
		UnblockAction( EIAB_FastTravel, 'being_ciri' );
		UnblockAction( EIAB_Fists, 'being_ciri' );
		UnblockAction( EIAB_OpenMeditation, 'being_ciri' );
		UnblockAction( EIAB_OpenCharacterPanel, 'being_ciri' );
		UnblockAction( EIAB_OpenJournal, 'being_ciri' );
		UnblockAction( EIAB_OpenAlchemy, 'being_ciri' );
		UnblockAction( EIAB_OpenGlossary, 'being_ciri' );
		UnblockAction( EIAB_CallHorse, 'being_ciri' );
		UnblockAction( EIAB_ExplorationFocus, 'being_ciri' );

		abilities.PushBack('Ciri_Q205');
		abilities.PushBack('Ciri_Q305');
		abilities.PushBack('Ciri_Q403');
		abilities.PushBack('Ciri_Q111');
		abilities.PushBack('Ciri_Q501');
		abilities.PushBack('CiriBlink');
		abilities.PushBack('CiriCharge');

		if (theGame.GetBetterCallCiri().GetEnableRageMode())
		{
			abilities.PushBack('Ciri_Rage');
			betterCallCiriAddedRage = true;
		}
		else
		{
			RemoveAbility('Ciri_Rage');
			betterCallCiriAddedRage = false;
		}

		for( i = 0; i < abilities.Size(); i += 1 )
		{
			if(!this.HasAbility(abilities[i]))
			{
				this.AddAbility(abilities[i]);
			}
		}

		if (GetAppearance() != theGame.GetBetterCallCiri().GetDesiredAppearance())
			SetAppearance(theGame.GetBetterCallCiri().GetDesiredAppearance());
	}
}

// BetterCallCiri: CR4GuiSceneController.SetEntityTemplateWithAnimation
@addMethod(CR4GuiSceneController)
public function SetEntityTemplateWithAnimation( entityTemplateAlias : string , animation: name)
{
	var templateResource : CEntityTemplate;

	if ( _isEntitySpawning )
	{
		_entityTemplateAlias = entityTemplateAlias;
		_pendingEntityAnimation = animation;
	}
	else
	{
		templateResource = ( CEntityTemplate )LoadResource( entityTemplateAlias );
		if ( templateResource )
		{
			_isEntitySpawning = true;
			theGame.GetGuiManager().SetSceneEntityTemplate( templateResource , animation);
		}
	}

	_cachedDyes.Clear();
	_appliedDyesPreview.Clear();
	_cachedDyes.Resize( EnumGetMax( 'EEquipmentSlots' ) + 1 );
	_appliedDyesPreview.Resize( EnumGetMax( 'EEquipmentSlots' ) + 1 );
}

// BetterCallCiri: CR4Game.OnPlayerChanged
@replaceMethod(CR4Game)
function OnPlayerChanged()
{
	var i : int;
	var buffs : array<CBaseGameplayEffect>;
	var witcher : W3PlayerWitcher; // BetterCallCiri

	thePlayer.RemoveAllBuffsOfType( EET_Burning );
	thePlayer.RemoveAllBuffsOfType( EET_Frozen );
	thePlayer.RemoveAllBuffsOfType( EET_Bleeding );
	thePlayer.RemoveAllBuffsOfType( EET_SlowdownFrost );
	thePlayer.RemoveAllBuffsOfType( EET_Slowdown );

	buffs = thePlayer.GetBuffs();
	for(i=0; i<buffs.Size(); i+=1)
	{
		buffs[i].ResumeForced();
	}

	GetGameCamera().StopEffect( 'frost' );
	DisableCatViewFx( 1.0f );
	thePlayer.StopEffect('critical_low_health');
	DisableDrunkFx();
	thePlayer.StopEffect('critical_toxicity');

	// BetterCallCiri++
	witcher = GetWitcherPlayer();
	if(witcher)
	{
		betterCallCiri.TransferSavedItemsToGeralt(witcher);
		witcher.UpdateEncumbrance();
	}
	// BetterCallCiri--

	UpdateStatsForDifficultyLevel( GetSpawnDifficultyMode() );

	RemoveAllTimeScales();

	thePlayer.InitRemasterDebugSettings();
}

// BetterCallCiri: W3ReplacerCiri.OnSpawned
@replaceMethod(W3ReplacerCiri)
function OnSpawned( spawnData : SEntitySpawnData )
{

	if ( spawnData.restored && !inputHandler )
	{
		spawnData.restored = false;
	}

	super.OnSpawned( spawnData );

	// RemoveNotNeededWeaponsFromInventory(); // BetterCallCiri

	BlockAction( EIAB_Signs, 'being_ciri' );
	BlockAction( EIAB_OpenInventory, 'being_ciri' );
	BlockAction( EIAB_OpenGwint, 'being_ciri' );
	BlockAction( EIAB_FastTravel, 'being_ciri' );
	BlockAction( EIAB_Fists, 'being_ciri' );
	BlockAction( EIAB_OpenMeditation, 'being_ciri' );
	BlockAction( EIAB_OpenCharacterPanel, 'being_ciri' );
	BlockAction( EIAB_OpenJournal, 'being_ciri' );
	BlockAction( EIAB_OpenAlchemy, 'being_ciri' );
	BlockAction( EIAB_OpenGlossary, 'being_ciri' );
	BlockAction( EIAB_CallHorse, 'being_ciri' );

	SetBehaviorVariable( 'test_ciri_replacer', 1.0f);

	this.DrainStamina(ESAT_FixedValue, 99.f);
	this.AddEffectDefault(EET_StaminaDrain, this, this.GetName());

	isInitialized = true;

	AddAnimEventCallback( 'ActionBlend', 	'OnAnimEvent_ActionBlend' );
	AddAnimEventCallback( 'fx_trail', 		'OnAnimEvent_fx_trail' );
	AddAnimEventCallback( 'rage', 			'OnAnimEvent_rage' );
	AddAnimEventCallback( 'SlideToTarget', 	'OnAnimEvent_SlideToTarget' );

	if ( !bloodExplode )
		bloodExplode = (CEntityTemplate)LoadResource('blood_explode');

	theGame.UpdateStatsForDifficultyLevel( MinDiffMode( theGame.GetDifficultyMode(), EDM_Medium ) );

	if ( spawnData.restored )
	{

		theGame.RemoveTimeScale( 'CiriSpecialAttackHeavy' );
		theGame.RemoveTimeScale( 'CiriPhantom' );
	}

	if ( !this.HasAbility( 'Ciri_CombatRegen' ) )
	{
		this.AddAbility( 'Ciri_CombatRegen' );
	}

	theGame.GameplayFactsRemove( "PlayerIsGeralt" );

	this.SetupBetterCallCiri(); // BetterCallCiri
}

// BetterCallCiri: W3Container.ProcessLoot
@replaceMethod(W3Container)
function ProcessLoot()
{
	var l_mergedContainerEntities 		: array<CGameplayEntity>;
	var l_containerIndex				: int;
	var l_autoCorpseLoot				: bool;

	if(disableLooting)
		return;

	// BetterCallCiri++
	if (usedByCiri)
	{
		if (theGame.GetBetterCallCiri().GetBlockLooting())
		{
			thePlayer.DisplayHudMessage(GetLocStringById(2111738009));
			return;
		}
		skipInventoryPanel = false;
	}
	// BetterCallCiri--

	l_autoCorpseLoot = theGame.GetInGameConfigWrapper().GetVarValue('Accessibility', 'AutoLoot') && (W3ActorRemains)(this) && !HasTag('lootbag');

	// BetterCallCiri: allow Ciri to use the loot popup.
	if(skipInventoryPanel || ((W3Herb)this) || l_autoCorpseLoot)
	{

		if( !thePlayer.IsAnyWeaponHeld() && !thePlayer.IsHoldingItemInLHand() )
			thePlayer.RaiseEvent('LootHerb');

		if (l_autoCorpseLoot && theGame.GetInGameConfigWrapper().GetVarValue('Gameplay', 'LootMergeEnabled'))
		{
			FindGameplayEntitiesInRange(l_mergedContainerEntities, this, 15.0f, 100, '', 0, NULL, 'W3ActorRemains');
			for	( l_containerIndex = 0 ; l_containerIndex < l_mergedContainerEntities.Size(); l_containerIndex += 1 )
			{

				if( !l_mergedContainerEntities[l_containerIndex] || l_mergedContainerEntities[l_containerIndex].HasTag('lootbag') )
				{
					continue;
				}

				((W3Container)l_mergedContainerEntities[l_containerIndex]).TakeAllItems();
				((W3Container)l_mergedContainerEntities[l_containerIndex]).OnContainerClosed();
			}
		}
		else
		{
			TakeAllItems();
			OnContainerClosed();
		}
	}
	else
	{
		ShowLoot();
	}
}

// BetterCallCiri: CR4CommonMenu.OnConfigUI
@replaceMethod(CR4CommonMenu)
function OnConfigUI()
{
	var stateName     : name;
	var menuName      : name;
	var shouldSkipHub : bool;
	var lootPopup	  : CR4LootPopup;

	var initData          : W3MenuInitData;
	var initMapData       : W3MapInitData;
	var initSingleData    : W3SingleMenuInitData;
	var selectionPopupRef : CR4ItemSelectionPopup;

	var i : int;

	if (!thePlayer.IsAlive() || theGame.HasBlackscreenRequested() || theGame.IsFading())
	{
		CloseMenu();
		return true;
	}

	theGame.CreateNoSaveLock( "fullscreen_ui_panels", noSaveLock, false, false );
	theGame.GameplayFactsRemove("closingHubMenu");
	theSound.SoundEvent("system_pause");

	fetchCurrentHotkeys();

	m_initialSelectionsToIgnore = 2;
	m_hideTutorial = true;
	m_forceHideTutorial = false;

	menuName = theGame.GetMenuToOpen();
	if(menuName == '')
	{
		restoreLastOpenMenu = true;
		menuName = thePlayer.GetDefaultCommonMenuSelection();
	}

	shouldSkipHub = menuName != '';

	CheckNpcTags();

	if( isInNpcContext )
	{
		theGame.GameplayFactsAdd("shopMode", 1);
	}
	else
	{
		theGame.GameplayFactsRemove("shopMode");
	}

	lootPopup = (CR4LootPopup)theGame.GetGuiManager().GetPopup('LootPopup');

	if (lootPopup)
	{
		lootPopup.ClosePopup();
	}

	super.OnConfigUI();

	if ((W3ReplacerCiri)thePlayer)
	{
		isCiri = true;
	}
	else
	{
		isCiri = false;
	}

	m_hubEnabled = false;

	GameplayFactsSet("GamePausedNotByUI", (int)theGame.IsGameTimePaused());
	if ( menuName != 'MeditationClockMenu' )
		theGame.Pause("menus");

	m_flashModule = GetMenuFlash();
	m_fxSubMenuClosed 				= m_flashModule.GetMemberFlashFunction( "onSubMenuClosed" );
	m_fxUpdateLevel 				= m_flashModule.GetMemberFlashFunction( "updatePlayerLevel" );
	m_fxUpdateMoney 				= m_flashModule.GetMemberFlashFunction( "updateMoney" );
	m_fxUpdateWeight 				= m_flashModule.GetMemberFlashFunction( "updateWeight" );
	m_fxNavigateNext 				= m_flashModule.GetMemberFlashFunction( "handleForceNextTab" );
	m_fxNavigatePrior 				= m_flashModule.GetMemberFlashFunction( "handleForcePriorTab" );
	m_fxSelectSubMenuTab 			= m_flashModule.GetMemberFlashFunction( "enterCurrentlySelectedTab" );
	m_fxSetShopInventory 			= m_flashModule.GetMemberFlashFunction( "setShopInventory" );
	m_fxUpdateTabEnabled 			= m_flashModule.GetMemberFlashFunction( "updateTabEnabled" );
	m_fxLockOpenTabNavigation 		= m_flashModule.GetMemberFlashFunction( "lockOpenTabNavigation" );
	m_fxBlockMenuClosing 			= m_flashModule.GetMemberFlashFunction( "blockMenuClosing" );
	m_fxBlockHubClosing 			= m_flashModule.GetMemberFlashFunction( "blockHubClosing" );
	m_fxSetInputFeedbackVisibility 	= m_flashModule.GetMemberFlashFunction( "SetInputFeedbackVisibility" );
	m_fxSetPlayerDefailsVis 		= m_flashModule.GetMemberFlashFunction( "setPlayerDetailsVisible" );
	m_fxSetMeditationBackgroundMode	= m_flashModule.GetMemberFlashFunction( "setMeditationBackgroundMode" );
	m_fxSetSelectedTab 				= m_flashModule.GetMemberFlashFunction( "setSelectedTab" );
	m_fxEnterCurrentlySelectedTab 	= m_flashModule.GetMemberFlashFunction( "enterCurrentlySelectedTab" );
	m_fxOnChildMenuConfigured 		= m_flashModule.GetMemberFlashFunction( "onChildMenuConfigured" );
	m_fxUpdateMenuBackgroundImage	= m_flashModule.GetMemberFlashFunction( "updateMenuBackgroundImage" );
	m_fxBlockBackNavigation			= m_flashModule.GetMemberFlashFunction( "blockBackNavigation" );
	m_fxOnTouchBegin				= m_flashModule.GetMemberFlashFunction( "onTouchBegin" );
	m_fxOnTouchEnd					= m_flashModule.GetMemberFlashFunction( "onTouchEnd" );
	m_fxOnTouchMove					= m_flashModule.GetMemberFlashFunction( "onTouchMove" );
	m_fxOnTap						= m_flashModule.GetMemberFlashFunction( "onTap" );
	m_fxSetMenuHubVisibility 		= m_flashModule.GetMemberFlashFunction( "setMenuHubVisibility" );

	stateName = '';
	initData = (W3MenuInitData)GetMenuInitData();
	if (initData)
	{
		stateName = initData.getDefaultState();
	}
	if((W3RadialMenuInitData)initData)
	{
		initFromRadialMenu = true;
	}

	if (theGame.GameplayFactsQuerySum("stashMode") == 1)
	{
		m_hubEnabled = false;
		shouldSkipHub = true;
		DefineMenuItem('InventoryMenu', "panel_title_stash");
	}
	else if( isInNpcContext )
	{
		AddMerchantTagIfMissing_HACK();

		DefineSceneMenuStructure();
	}
	else
	{
		DefineMenuStructure();

		initMapData = (W3MapInitData)initData;
		initSingleData = (W3SingleMenuInitData)initData;

		SetMenuTabeEnable( 'InventoryMenu', false, 'HorseInventory');

		if (menuName == 'MapMenu' && initMapData && ( initMapData.GetTriggeredExitEntity() || initMapData.GetUsedFastTravelEntity() ) )
		{

			m_menuData.Clear();
			DefineMenuItem('MapMenu', "panel_title_fullmap", '', 'FastTravel');

			SetSingleMenuTabEnabled( 'MapMenu' );
			m_hubEnabled = false;
		}

		if( initSingleData )
		{
			if( initSingleData.GetBlockOtherPanels() )
			{
				m_menuData.Clear();

				if (menuName == 'MeditationClockMenu')
				{
					DefineMenuItem('MeditationClockMenu', "panel_name_sleep", '');
				}
				else
				if (menuName == 'GlossaryBooksMenu')
				{
					DefineMenuItem('GlossaryBooksMenu', "books_panel_title", '');
				}

				shouldSkipHub = true;
				m_hubEnabled = false;

				SetSingleMenuTabEnabled( initSingleData.fixedMenuName );
			}

			if( initSingleData.ignoreMeditationCheck )
			{
				isPlayerMeditatingInBed = true;
			}

			if( initSingleData.unlockCraftingMenu )
			{
				m_menuData.Clear();

				DefineMenuItem( 'BlacksmithMenu', "panel_title_blacksmith_disassamble", '', 'Disassemble' );
			}
		}
	}

	DisableNotAllowedTabs();

	if ( restoreLastOpenMenu && !IsMenuTabEnabled( menuName ) )
	{

		if ( IsMenuTabEnabled( 'MapMenu' ) )
		{
			menuName = 'MapMenu';
		}
		else
		{

			for ( i = 0; i < m_menuData.Size(); i += 1 )
			{
				if ( m_menuData[i].Enabled )
				{
					menuName = m_menuData[i].MenuName;
					break;
				}
			}
		}
	}

	if ( !isInNpcContext && menuName != '' && !IsMenuTabEnabled( menuName ) )
	{
		if(IsGlossaryMainSubMenu(menuName))
		{
			menuName = 'GlossaryMainMenu';
		}
		else
		{
			CloseMenu();
			return true;
		}
	}

	UpdateTabs();
	SetMenuBackground();

	if( menuName == '')
	{
		if (stateName != '')
		{
			menuName = GetMenuParentName(stateName);
		}
		else
		{
			menuName = 'MapMenu';
			stateName = 'GlobalMap';

		}
		SetRenderGameWorldOverride(false);
	}
	else if (menuName == 'MeditationClockMenu')
	{
		SetMeditationMode(true, 0, initSingleData);
	}
	else
	{
		SetRenderGameWorldOverride(false);
	}

	if( m_menuData.Size() < 1 )
	{
		m_hubEnabled = false;
		shouldSkipHub = true;

		if (menuName == 'InventoryMenu')
		{
			DefineMenuItem('InventoryMenu', "panel_inventory", '');
		}
	}

	SetupMenu();

	// BetterCallCiri++
	CallSetSelectedTab(menuName, stateName);
	// BetterCallCiri--

	if( shouldSkipHub )
	{
		m_fxEnterCurrentlySelectedTab.InvokeSelf();
	}

	theInput.StoreContext( 'EMPTY_CONTEXT' );

	m_contextManager = new W3ContextManager in this;
	m_contextManager.Init(this);

	m_guiManager.RequestMouseCursor(true);

	if (theInput.IsMousePresent())
	{

		theGame.MoveMouseTo(0.1, 0.48);
	}

	theSound.SoundLoadBank( "gui_ep2.bnk", true );

	selectionPopupRef = (CR4ItemSelectionPopup)theGame.GetGuiManager().GetPopup('ItemSelectionPopup');
	if (selectionPopupRef)
	{
		theGame.ClosePopup('ItemSelectionPopup');
	}

	if( !m_hubEnabled )
	{
		m_fxBlockBackNavigation.InvokeSelf();
	}

	initialMenuOpen = true;
}

// BetterCallCiri: CR4CommonMenu.DefineMenuStructure
@replaceMethod(CR4CommonMenu)
function DefineMenuStructure() : void
{
	var curMenuItem 	: SMenuTab;
	var curMenuSubItems : SMenuTab;

	m_menuData.Clear();
	// BetterCallCiri++

	DefineMenuItem('GlossaryMainMenu', "panel_title_glossary", '');

	if (!isCiri)
	{
		DefineMenuItem('AlchemyMenu', "panel_title_alchemy", '');
	}

	DefineMenuItem('InventoryMenu', "panel_inventory", '', 'CharacterInventory');
	// BetterCallCiri--

	DefineMenuItem('MapMenu', "panel_title_fullmap", '', 'GlobalMap');

	// BetterCallCiri++
	DefineMenuItem('JournalQuestMenu', "panel_title_journal_quest", '');
	// BetterCallCiri--
	if (!isCiri)
	{

		DefineMenuItem('CharacterMenuDupe', "panel_title_character", '');

		DefineMenuItem('MeditationClockMenu', "panel_title_meditation", '');

	}

	CheckTutorialRestrictions();
}

// BetterCallCiri: CR4GlossaryMainMenu.DefineMenuStructure
@replaceMethod(CR4GlossaryMainMenu)
function DefineMenuStructure() : void
{
	var curMenuItem 	: SMenuTab;
	var curMenuSubItems : SMenuTab;

	m_menuData.Clear();
        DefineMenuItem('GlossaryBestiaryMenu', "panel_title_glossary_bestiary",'');
        DefineMenuItem('GlossaryTutorialsMenu', "panel_title_glossary_tutorials",'');
        DefineMenuItem('GlossaryEncyclopediaMenu', "panel_title_glossary_dictionary",'');
        DefineMenuItem('GlossaryBooksMenu', "books_panel_title",'');
        // BetterCallCiri++
        if (!thePlayer.IsCiri())
        {
            DefineMenuItem('CraftingMenu', "panel_title_crafting", '');
        }
        // BetterCallCiri--

}

// BetterCallCiri: CR4InventoryMenu.UpdateEntityTemplate
@replaceMethod(CR4InventoryMenu)
function UpdateEntityTemplate() : void
{
	var templateFilename : string;
	var appearance : name;
	var environmentFilename : string;
	var environmentSunRotation : EulerAngles;
	var cameraLookAt : Vector;
	var cameraRotation : EulerAngles;
	var cameraDistance : float;
	var updateItems : bool;
	var fov : float;

	var guiSceneController : CR4GuiSceneController;

	guiSceneController = theGame.GetGuiManager().GetSceneController();
	if ( !guiSceneController )
	{

		return;
	}

	if ( drawHorse )
	{
		templateFilename             = "HorseForUI";
		appearance                   = '';
		environmentSunRotation.Yaw   = 250;
		environmentSunRotation.Pitch = 10;
		cameraLookAt.Z               = 1;
		cameraRotation.Yaw           = 88.6;
		cameraRotation.Pitch         = 355;
		cameraDistance               = 3.17;
		fov 						 = 35.0f;
		updateItems                  = true;
	}
	else
	{

		templateFilename             = "GeraltForUI";
		appearance                   = '';
		environmentSunRotation.Yaw   = 0;
		environmentSunRotation.Pitch = 0;
		cameraLookAt.Z               = 0.92;
		cameraRotation.Yaw           = 190.71;
		cameraRotation.Pitch         = 5;
		cameraDistance               = 3.2;
		fov							 = 35.0f;
		updateItems                  = true;
	}

	// BetterCallCiri++
	if (thePlayer.IsCiri())
	{
		guiSceneController.SetEntityTemplateWithAnimation( 'Ciri', 'locomotion_idle' );
	}
	else
	{
		guiSceneController.SetEntityTemplate( templateFilename );
	}
	// BetterCallCiri--
	guiSceneController.SetCamera( cameraLookAt, cameraRotation, cameraDistance, fov );
	guiSceneController.SetEnvironmentAndSunRotation( "DefaultEnvironmentForUI", environmentSunRotation );

	guiSceneController.SetEntityAppearance( appearance );
	guiSceneController.SetEntityItems( updateItems );
}

// BetterCallCiri: CR4LootPopup.OnPopupTakeItem
@replaceMethod(CR4LootPopup)
function OnPopupTakeItem( Id : int ) : void
{
	var cachedItemData 		: CLootPopupItemData;
	var containerInv 		: CInventoryComponent;
	var playerInv 			: CInventoryComponent;
	var item 				: SItemUniqueId;
	var invalidatedItems 	: array< SItemUniqueId >;
	var itemName 			: name;
	var itemQuantity, i		: int;
	var category			: name;

	SignalStealingReactionEvent();

	m_indexToSelect = Id;

	playerInv 		= thePlayer.GetInventory(); // BetterCallCiri

	cachedItemData = m_cachedItems[ Id ];

	containerInv = cachedItemData.m_owningContainers[ 0 ].m_container.GetInventory();

	item = cachedItemData.m_owningContainers[ 0 ].m_uniqueId;
	itemName = containerInv.GetItemName(item);
	if( containerInv.ItemHasTag(item, 'HerbGameplay') )
	{
		category 	= 'herb';
	}
	else
	{
		category	= containerInv.GetItemCategory(item);
	}

	for(i = 0; i < cachedItemData.m_owningContainers.Size(); i+=1)
	{
		if( !cachedItemData.m_owningContainers[ i ].m_container )
		{
			continue;
		}

		containerInv = cachedItemData.m_owningContainers[ i ].m_container.GetInventory();
		item = cachedItemData.m_owningContainers[ i ].m_uniqueId;

		itemQuantity 	= containerInv.GetItemQuantity(item);

		containerInv.NotifyItemLooted( item );
		containerInv.GiveItemTo( playerInv, item, itemQuantity, true, false, true );

		cachedItemData.m_owningContainers[ i ].m_container.InformClueStash();
	}

	m_cachedItems.Erase(Id);
	PlayItemEquipSound( category );

	if( m_cachedItems.Size() == 0)
	{
		OnCloseLootWindow();
	}
	else
	{
		m_fxSetSelectionIndex.InvokeSelfOneArg( FlashArgInt( m_indexToSelect ) );
		UpdateFlashObjects();
	}
}

// BetterCallCiri: CR4GuiSceneController.OnGuiSceneEntitySpawned
@replaceMethod(CR4GuiSceneController)
function OnGuiSceneEntitySpawned()
{
	// BetterCallCiri++
	var queuedTemplateAlias : string;
	var queuedAnimation : name;
	// BetterCallCiri--

	_isEntitySpawning = false;

	if ( _entityTemplateAlias != "" )
	{
		// BetterCallCiri++
		queuedTemplateAlias = _entityTemplateAlias;
		queuedAnimation = _pendingEntityAnimation;
		_entityTemplateAlias = "";
		_pendingEntityAnimation = '';

		if ( queuedAnimation != '' )
		{
			SetEntityTemplateWithAnimation( queuedTemplateAlias, queuedAnimation );
		}
		else
		{
			SetEntityTemplate( queuedTemplateAlias );
		}
		// BetterCallCiri--
	}
	else
	{
		if ( _entityAppearance != '' )
		{
			SetEntityAppearance( _entityAppearance );
			_entityAppearance = '';
		}
		if ( _environmentAlias != "" )
		{
			SetEnvironmentAndSunRotation( _environmentAlias, _environmentSunRotation );
			_environmentAlias = "";
		}

		if ( _cameraUpdate )
		{
			_cameraUpdate = false;
			SetCamera( _cameraLookAt, _cameraRotation, _cameraDistance, _fov );
		}

		if ( _updateItems )
		{
			_updateItems = false;
			SetEntityItems( _updateItems );
		}

		if (_updateEntityTransform)
		{
			_updateEntityTransform = false;
			SetEntityTransform( _entityPosition, _entityRotation, _entityScale );
		}
		else
		{

			_entityRotation.Yaw = 0;
			_entityRotation.Pitch = 0;
			_entityRotation.Roll = 0;

			_entityScale.X = 1;
			_entityScale.Y = 1;
			_entityScale.Z = 1;

			SetEntityTransform( _entityPosition, _entityRotation, _entityScale );
		}
	}
}

// BetterCallCiri: CInteractionsManager.GetBlockedActions
@replaceMethod(CInteractionsManager)
function GetBlockedActions( out blockedActions : array< string > )
{
	if(!thePlayer.IsActionAllowed(EIAB_InteractionContainers))
	{
		blockedActions.PushBack( "Loot" );
		blockedActions.PushBack( "Container" );
		blockedActions.PushBack( "Take" );
		blockedActions.PushBack( "GatherHerbs" );
	}

	if ( (W3ReplacerCiri)thePlayer )
	{
		blockedActions.PushBack( "Ignite" );
		blockedActions.PushBack( "Extinguish" );
		// blockedActions.PushBack( "FastTravel" ); // BetterCallCiri
	}

	if ( thePlayer.IsInCombatAction() )
	{
		blockedActions.PushBack( "MountHorse" );
	}
}
