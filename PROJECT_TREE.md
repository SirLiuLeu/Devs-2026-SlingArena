# Project Tree

## Runtime UI Hierarchy

Documented UI paths are owned by `ProjectTreeSpec.lua`; dynamic generated slots/templates are kept only where runtime logic resolves them. Entries are sorted A-Z by sibling name.

```
StarterGui
├─ DailyLoginUI
│  ├─ MainPanel
│  │  ├─ Content
│  │  │  ├─ Day7Big
│  │  │  └─ LeftGrid
│  │  └─ Header
│  │     └─ CloseButton
│  └─ Overlay
├─ InventoryUI
│  └─ Root
│     ├─ BodyEquipment
│     │  ├─ Footer
│     │  │  └─ CapacityLabel
│     │  ├─ GridContainer
│     │  └─ RightPanel
│     │     ├─ ActionButtons
│     │     │  ├─ DeleteButton
│     │     │  └─ EquipButton
│     │     ├─ SelectedName
│     │     └─ Stats
│     │        ├─ Damage
│     │        ├─ HP
│     │        ├─ Range
│     │        └─ Regen
│     ├─ BodyItems
│     │  ├─ GridContainer
│     │  └─ RightPanel
│     │     ├─ ActionButtons
│     │     │  └─ UseButton
│     │     ├─ SelectedName
│     │     └─ Stats
│     │        ├─ ItemStat1
│     │        ├─ ItemStat2
│     │        └─ ItemStat3
│     ├─ BodyLauncher
│     │  ├─ Footer
│     │  │  └─ CapacityLabel
│     │  ├─ GridContainer
│     │  └─ RightPanel
│     │     ├─ ActionButtons
│     │     │  ├─ DeleteButton
│     │     │  └─ EquipButton
│     │     ├─ SelectedName
│     │     └─ Stats
│     │        ├─ Damage
│     │        ├─ HP
│     │        ├─ Range
│     │        └─ Regen
│     ├─ Header
│     │  └─ CloseButton
│     └─ Tabs
│        ├─ EquipmentTab
│        ├─ ItemsTab
│        └─ LauncherTab
├─ LauncherUI
│  ├─ CancelZone
│  │  └─ IconX
│  ├─ ChargeBar
│  │  └─ Fill
│  └─ JoystickRoot
│     ├─ Base
│     ├─ CooldownOverlay
│     │  ├─ LeftHalf
│     │  │  └─ Clip
│     │  │     └─ Fill
│     │  └─ RightHalf
│     │     └─ Clip
│     │        └─ Fill
│     ├─ CooldownText
│     ├─ DirectionIndicator
│     └─ Thumb
├─ MainHUD
│  └─ Root
│     ├─ BuffContainer
│     │  ├─ DamageBuff
│     │  │  └─ ValueText
│     │  ├─ ExpBuff
│     │  │  └─ ValueText
│     │  └─ HPRecovery
│     │     └─ Time
│     ├─ Diamond
│     │  └─ Value
│     ├─ ExpProress
│     │  ├─ ExpBar
│     │  │  └─ ExpBarFill
│     │  ├─ ExpValueLabel
│     │  └─ LevelOnBarLabel
│     ├─ Home
│     ├─ LeftMenu
│     │  ├─ DailyButton
│     │  ├─ InventoryButton
│     │  ├─ OnlineRewardButton
│     │  ├─ QuestButton
│     │  ├─ SettingButton
│     │  ├─ ShopButton
│     │  └─ TabScore
│     ├─ ProgressPoint
│     └─ QuickHP
│        ├─ Overlay
│        ├─ Quantity
│        └─ Time
├─ MatchScoreboardUI
│  ├─ MainPanel
│  │  ├─ Header
│  │  │  └─ CloseButton
│  │  └─ PlayerList
│  │     └─ PlayerRowTemplate_MatchScoreboardUI
│  └─ Overlay
├─ MatchSummaryUI
│  └─ MainPanel
│     ├─ Header
│     │  └─ CloseButton
│     └─ Table
│        └─ PlayerList
├─ MatchUI
│  └─ RootFrame
│     ├─ AlivePlayersLabel
│     ├─ StatusLabel
│     ├─ TimerLabel
│     └─ WinnerPopup
├─ OnlineRewardUI
│  └─ Root
│     ├─ Content
│     ├─ Footer
│     │  ├─ ClaimAll
│     │  └─ SkipAll
│     └─ Header
│        └─ CloseButton
├─ QuestUI
├─ SettingsUI
├─ ShopUI
│  └─ Main
│     ├─ Buttons
│     │  ├─ Dinamonds
│     │  ├─ Items
│     │  └─ Launcher
│     ├─ Close
│     ├─ Dinamonds
│     │  └─ Content
│     │     └─ ScrollingFrame
│     ├─ Items
│     │  └─ Content
│     │     └─ ScrollingFrame
│     └─ Launcher
│        └─ Content
│           └─ ScrollingFrame
├─ SpinUI
│  └─ Root
│     ├─ Buttons
│     │  ├─ Spin1
│     │  └─ Spin2
│     ├─ CloseButton
│     └─ WheelContainer
│        ├─ GachaWheel
│        └─ Pointer
└─ UnitTestUI
   └─ RootFrame
      ├─ DebugReset
      ├─ EndRoundButton
      ├─ JoinButton
      ├─ LeaveButton
      ├─ Plus1Minute
      └─ StartSafeZoneButton
```

## Source Files

Generated from the repository contents. Entries are sorted alphabetically A-Z at every displayed level. Runtime-created Roblox instances that are required by code remain documented in `ProjectTreeSpec.lua`.

```
src
├─ GuidesForUI
│  ├─ ArenaUISetupGuide.md
│  └─ FoodSpawnDeveloperGuide.md
├─ ReplicatedStorage
│  ├─ Assets
│  │  ├─ EffectVfx
│  │  │  └─ init.meta.json
│  │  ├─ FoodModels
│  │  │  └─ init.meta.json
│  │  ├─ Launchers
│  │  │  └─ init.meta.json
│  │  └─ init.meta.json
│  ├─ Client
│  │  ├─ Controllers
│  │  │  ├─ DailyLoginUIController.lua
│  │  │  ├─ InventoryUIController.lua
│  │  │  ├─ LeaderboardWorldUIController.lua
│  │  │  ├─ MatchScoreboardUIController.lua
│  │  │  ├─ MatchSummaryUIController.lua
│  │  │  ├─ OnlineRewardUIController.lua
│  │  │  ├─ QuestUIController.lua
│  │  │  ├─ ShopUIController.lua
│  │  │  ├─ SpinUIController.lua
│  │  │  ├─ ToastUIController.lua
│  │  │  └─ UIController.lua
│  │  └─ Services
│  │     ├─ DailyLoginLogicService.lua
│  │     ├─ HudDataService.lua
│  │     ├─ InventoryDataProvider.lua
│  │     ├─ LobbyClientService.lua
│  │     ├─ MatchScoreboardDataService.lua
│  │     ├─ MatchSummaryDataService.lua
│  │     ├─ MockData.lua
│  │     ├─ MockInventoryData.lua
│  │     ├─ MockPlayerData.lua
│  │     ├─ OnlineRewardLogicService.lua
│  │     ├─ QuestLogicService.lua
│  │     └─ ShopLogicService.lua
│  ├─ LauncherArenaRemotes
│  │  ├─ AbilityTrigger.model.json
│  │  ├─ ApplyKnockback.model.json
│  │  ├─ ApplySelfBounce.model.json
│  │  ├─ AttributeUpgrade.model.json
│  │  ├─ CancelCharge.model.json
│  │  ├─ ClientDoLaunch.model.json
│  │  ├─ ClockSyncRequest.model.json
│  │  ├─ ClockSyncResponse.model.json
│  │  ├─ ConsumeHpPotion.model.json
│  │  ├─ DebugResetLauncher.model.json
│  │  ├─ DebugSpawnFood.model.json
│  │  ├─ EndRound.model.json
│  │  ├─ EquipEquipment.model.json
│  │  ├─ EquipLauncher.model.json
│  │  ├─ GameplayFeedback.model.json
│  │  ├─ GlobalTop100Update.model.json
│  │  ├─ JoinArena.model.json
│  │  ├─ KnockbackReplication.model.json
│  │  ├─ LaunchVelocityReport.model.json
│  │  ├─ LeaveArena.model.json
│  │  ├─ MatchScoreboardUpdate.model.json
│  │  ├─ MatchStateUpdate.model.json
│  │  ├─ MatchSummaryUpdate.model.json
│  │  ├─ MoveRequest.model.json
│  │  ├─ Notification.model.json
│  │  ├─ Plus1Minute.model.json
│  │  ├─ PopupMessage.model.json
│  │  ├─ PrestigeReset.model.json
│  │  ├─ PurchaseMatchBuff.model.json
│  │  ├─ PurchaseRespawn.model.json
│  │  ├─ QuestClaim.model.json
│  │  ├─ QuestUpdate.model.json
│  │  ├─ ReleaseCharge.model.json
│  │  ├─ ReportCollision.model.json
│  │  ├─ ReportFoodHit.model.json
│  │  ├─ ReportLaunchStopped.model.json
│  │  ├─ RequestEquipmentGrant.model.json
│  │  ├─ RequestLaunch.model.json
│  │  ├─ RequestRespawn.model.json
│  │  ├─ RoundResult.model.json
│  │  ├─ SetPlayerMode.model.json
│  │  ├─ StartCharge.model.json
│  │  ├─ StartSafeZone.model.json
│  │  ├─ StateUpdate.model.json
│  │  ├─ TeleportRequest.model.json
│  │  ├─ ToggleSpecialUpgrade.model.json
│  │  ├─ UIStateUpdate.model.json
│  │  ├─ UnequipEquipment.model.json
│  │  ├─ UpgradeEquipment.model.json
│  │  ├─ VelocityCorrection.model.json
│  │  └─ ZoneUpdate.model.json
│  ├─ Shared
│  │  ├─ Config
│  │  │  ├─ AbilityConfig.lua
│  │  │  ├─ BalanceConfig.lua
│  │  │  ├─ EquipmentConfig.lua
│  │  │  ├─ EquipmentUpgradeConfig.lua
│  │  │  ├─ GachaRewardConfig.lua
│  │  │  ├─ GameConfig.lua
│  │  │  ├─ ItemConfig.lua
│  │  │  ├─ LauncherAnimationIds.lua
│  │  │  ├─ LauncherConfig.lua
│  │  │  ├─ LevelConfig.lua
│  │  │  ├─ NotificationConfigData.lua
│  │  │  ├─ PhysicsConfig.lua
│  │  │  ├─ QuestConfig.lua
│  │  │  ├─ RankConfig.lua
│  │  │  ├─ SafeZoneConfig.lua
│  │  │  └─ TrapConfig.lua
│  │  ├─ Constants
│  │  │  ├─ GameStates.lua
│  │  │  └─ LauncherUiConstants.lua
│  │  ├─ Types
│  │  │  ├─ CombatTypes.lua
│  │  │  └─ PlayerState.lua
│  │  ├─ Utils
│  │  │  ├─ CollisionResponse.lua
│  │  │  ├─ CombatCollision.lua
│  │  │  ├─ EquipmentStatResolver.lua
│  │  │  ├─ GachaSpinLogic.lua
│  │  │  ├─ LauncherCooldownService.lua
│  │  │  ├─ LauncherStatResolver.lua
│  │  │  ├─ LauncherUiState.lua
│  │  │  ├─ PathResolver.lua
│  │  │  ├─ PawnLocator.lua
│  │  │  ├─ RewardRoller.lua
│  │  │  ├─ StatusEffectVfx.lua
│  │  │  ├─ VelocityDecay.lua
│  │  │  └─ WaitForUI.lua
│  │  ├─ ProjectTreeSpec.lua
│  │  └─ RemoteContracts.lua
│  └─ init.meta.json
├─ ServerScriptService
│  ├─ Config
│  │  └─ FoodConfig.lua
│  ├─ Services
│  │  ├─ DataProviders
│  │  │  ├─ MockData.lua
│  │  │  └─ MockProvider.lua
│  │  ├─ EquipmentAbilityService
│  │  │  └─ EquipmentAbilityService.lua
│  │  ├─ EquipmentEffectService
│  │  │  ├─ EquipmentEffects
│  │  │  │  ├─ EffectUtil.lua
│  │  │  │  ├─ ExpBonus.lua
│  │  │  │  ├─ Fire.lua
│  │  │  │  ├─ Magnet.lua
│  │  │  │  ├─ NoOp.lua
│  │  │  │  ├─ Petrify.lua
│  │  │  │  ├─ Poison.lua
│  │  │  │  ├─ Shield.lua
│  │  │  │  ├─ Slow.lua
│  │  │  │  ├─ SmokeBomb.lua
│  │  │  │  ├─ Stun.lua
│  │  │  │  └─ Titan.lua
│  │  │  └─ EquipmentEffectService.lua
│  │  ├─ EquipmentService
│  │  │  └─ EquipmentService.lua
│  │  ├─ Helpers
│  │  │  ├─ CollisionValidation.lua
│  │  │  └─ HitCooldownDedupe.lua
│  │  ├─ Infrastructure
│  │  │  ├─ EventBus.lua
│  │  │  ├─ RateLimiter.lua
│  │  │  └─ ServiceRegistry.lua
│  │  ├─ LauncherAbilityService
│  │  │  ├─ Abilities
│  │  │  │  ├─ Stealth.lua
│  │  │  │  ├─ Stun.lua
│  │  │  │  └─ Vacuum.lua
│  │  │  └─ LauncherAbilityService.lua
│  │  ├─ LauncherService
│  │  │  ├─ LauncherMovement.lua
│  │  │  ├─ LauncherService.lua
│  │  │  └─ LaunchMotionModel.lua
│  │  ├─ PlayerService
│  │  │  ├─ AnimationController.lua
│  │  │  └─ PlayerService.lua
│  │  ├─ Shared
│  │  │  └─ BaseAbility.lua
│  │  ├─ CollisionService.lua
│  │  ├─ DamagePipelineService.lua
│  │  ├─ FlagService.lua
│  │  ├─ FoodService.lua
│  │  ├─ GrowthService.lua
│  │  ├─ IDataProvider.lua
│  │  ├─ LeaderboardService.lua
│  │  ├─ MapService.lua
│  │  ├─ MonetizationService.lua
│  │  ├─ NotificationService.lua
│  │  ├─ PlayerDataService.lua
│  │  ├─ PlayerStateService.lua
│  │  ├─ ProgressPointService.lua
│  │  ├─ QuestService.lua
│  │  ├─ RoundService.lua
│  │  ├─ SafeZoneService.lua
│  │  ├─ TeamService.lua
│  │  └─ TrapService.lua
│  ├─ Tests
│  │  ├─ CoreLoopTests.server.lua
│  │  ├─ EquipmentFoundationTests.server.lua
│  │  ├─ GachaSpinLogicTests.server.lua
│  │  ├─ InventorySystemTests.server.lua
│  │  ├─ OnlineRewardLogicTests.server.lua
│  │  ├─ RewardGenerationTests.server.lua
│  │  └─ ShopDailyUiLogicTests.server.lua
│  └─ Main.server.lua
├─ StarterGui
│  ├─ DailyLoginUI.model.json.cailon
│  ├─ init.meta.json
│  └─ ItemSlotTemplate_InventoryUI.model.json.cailon
├─ StarterPlayer
│  └─ StarterPlayerScripts
│     ├─ Components
│     │  ├─ AttributePanel.lua
│     │  ├─ BuffPanel.lua
│     │  ├─ ChargeBar.lua
│     │  ├─ CooldownComponent.lua
│     │  ├─ DiamondDisplay.lua
│     │  ├─ HealthBar.lua
│     │  ├─ HUD.lua
│     │  ├─ LeaderboardUI.lua
│     │  ├─ RespawnPanel.lua
│     │  └─ SkillButton.lua
│     ├─ CameraController.client.lua
│     ├─ CollisionClientScanner.client.lua
│     ├─ FoodWorldUI.client.lua
│     ├─ InputController.client.lua
│     ├─ KnockbackReplicationClient.client.lua
│     ├─ LauncherUIController.client.lua
│     ├─ LaunchImpulseClient.client.lua
│     ├─ PlayerModeController.client.lua
│     ├─ SafeZoneVisualizer.client.lua
│     └─ UIBinder.client.lua
└─ Workspace
   ├─ init.meta.json
   └─ LauncherWorldUI.model.json.cailon
```
