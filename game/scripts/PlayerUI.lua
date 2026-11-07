-- This files has modifed Super Giant Games code
-- Not licensed

-- Combat HUD (health, life pips, cast ammo, gun, wrath meter) for players 2-4.
-- Player 1 uses the game's own HUD in the bottom-left corner.
-- Every additional player gets its own instance, mirrored into the bottom-right corner:
-- P2 in the lowest row, P3 above it, P4 above P3 (Config.PlayerHudRowSpacing apart).

---@type CoopPlayers
local CoopPlayers = ModRequire "CoopPlayers.lua"
---@type CoopModConfig
local Config = ModRequire "config.lua"

---@class PlayerUi
local PlayerUi = {}

PlayerUi.MaxPlayers = 4

---@type table<number, PlayerUiInstance>
local instances = {}

---@param playerId number
---@return PlayerUiInstance
local function New(playerId)
    ---@class PlayerUiInstance
    local Ui = {}

    local ScreenAnchorsPlayer = {}
    Ui.ScreenAnchors = ScreenAnchorsPlayer
    Ui.PlayerId = playerId

    -- Vertical offset of this player's HUD row (0 for P2, negative = higher on screen)
    local offsetY = -(playerId - 2) * (Config.PlayerHudRowSpacing or 140)
    Ui.OffsetY = offsetY
    local baseY = ScreenHeight + offsetY

    local function GetHero()
        return CoopPlayers.GetHero(playerId)
    end

    function Ui.ShowHealthUI()
        if not ConfigOptionCache.ShowUIAnimations then
            return
        end

        if ScreenAnchorsPlayer.HealthBack ~= nil then
            return
        end

        local posX = ScreenWidth - 500

        -- The corner shadow only fits the lowest row
        if ScreenAnchorsPlayer.Shadow == nil and offsetY == 0 then
            ScreenAnchorsPlayer.Shadow = CreateScreenObstacle({
                Name = "BlankObstacle",
                Group = "Combat_UI_Backing",
                X = ScreenWidth,
                Y = ScreenHeight
            })
            SetAnimation({ Name = "BarShadow", DestinationId = ScreenAnchorsPlayer.Shadow })
            SetScaleX({ Ids = { ScreenAnchorsPlayer.Shadow }, Fraction = -1 })
        end

        ScreenAnchorsPlayer.HealthBack = CreateScreenObstacle({
            Name = "BlankObstacle",
            Group = "Combat_UI",
            X = posX - (10 - CombatUI.FadeDistance.Health),
            Y = baseY - 50
        })

        ScreenAnchorsPlayer.HealthRally = CreateScreenObstacle({
            Name = "BlankObstacle",
            Group = "Combat_UI",
            X = posX - (10 - CombatUI.FadeDistance.Health),
            Y = baseY - 50
        })

        ScreenAnchorsPlayer.HealthFill = CreateScreenObstacle({
            Name = "BlankObstacle",
            Group = "Combat_UI",
            X = posX - (10 - CombatUI.FadeDistance.Health),
            Y = baseY - 50
        })

        ScreenAnchorsPlayer.HealthFlash = CreateScreenObstacle({
            Name = "BlankObstacle",
            Group = "Combat_UI",
            X = posX - (10 - CombatUI.FadeDistance.Health),
            Y = baseY - 50
        })

        ScreenAnchorsPlayer.StoredAmmo = ScreenAnchorsPlayer.StoredAmmo or {}
        ScreenAnchorsPlayer.SelfStoredAmmo = ScreenAnchorsPlayer.SelfStoredAmmo or {}

        Ui.RecreateLifePips()

        CreateTextBox(MergeTables({
            Id = ScreenAnchorsPlayer.HealthBack,
            OffsetX = -90,
            OffsetY = -13,
            Font = "AlegreyaSansSCBold",
            FontSize = 24,
            ShadowRed = 0.1,
            ShadowBlue = 0.1,
            ShadowGreen = 0.1,
            OutlineColor = { 0.113, 0.113, 0.113, 1 },
            OutlineThickness = 1,
            ShadowAlpha = 1.0,
            ShadowBlur = 0,
            ShadowOffsetY = 2,
            ShadowOffsetX = 0,
            Justification = "Left",
        }, LocalizationData.UIScripts.HealthUI))

        SetAnimation({ Name = "HealthBar", DestinationId = ScreenAnchorsPlayer.HealthBack })

        local frameTarget = 1 - (CurrentRun.Hero.Health / CurrentRun.Hero.MaxHealth)
        SetAnimation({ Name = "HealthBarFill", DestinationId = ScreenAnchorsPlayer.HealthFill, FrameTarget = frameTarget, Instant = true, Color =
        Color.Black })
        SetAnimation({ Name = "HealthBarFillWhite", DestinationId = ScreenAnchorsPlayer.HealthRally, FrameTarget = frameTarget, Instant = true, Color =
        Color.RallyHealth })

        Ui.UpdateHealthUI()

        if CurrentRun.CurrentRoom.LoadedAmmo then
            for i = 1, CurrentRun.CurrentRoom.LoadedAmmo do
                local offsetX = 600 + 380 -- Some random shit
                local ammoOffsetY = -50
                offsetX = offsetX + (#ScreenAnchorsPlayer.SelfStoredAmmo * 22)
                local screenId = CreateScreenObstacle({ Name = "BlankObstacle", Group = "Combat_UI", DestinationId =
                ScreenAnchorsPlayer.HealthBack, X = 10 + offsetX, Y = baseY - 50 + ammoOffsetY })
                SetThingProperty({ Property = "SortMode", Value = "Id", DestinationId = screenId })
                table.insert(ScreenAnchorsPlayer.SelfStoredAmmo, screenId)
                SetAnimation({ Name = "AmmoEmbeddedInEnemyIcon", DestinationId = screenId })
            end
        end

        FadeObstacleIn({ Id = ScreenAnchorsPlayer.HealthBack, Duration = CombatUI.FadeInDuration, IncludeText = true, Distance =
        CombatUI.FadeDistance.Health, Direction = 0 })
        FadeObstacleIn({ Id = ScreenAnchorsPlayer.HealthRally, Duration = CombatUI.FadeInDuration, IncludeText = false, Distance =
        CombatUI.FadeDistance.Health, Direction = 0 })
        FadeObstacleIn({ Id = ScreenAnchorsPlayer.HealthFill, Duration = CombatUI.FadeInDuration, IncludeText = false, Distance =
        CombatUI.FadeDistance.Health, Direction = 0 })
        FadeObstacleIn({ Id = ScreenAnchorsPlayer.HealthFlash, Duration = CombatUI.FadeInDuration, IncludeText = false, Distance =
        CombatUI.FadeDistance.Health, Direction = 0 })
        if ScreenAnchorsPlayer.BadgeId ~= nil then
            FadeObstacleIn({ Id = ScreenAnchorsPlayer.BadgeId, Duration = CombatUI.FadeInDuration, IncludeText = false, Distance =
            CombatUI.FadeDistance.Health, Direction = 0 })
        end
    end

    function Ui.UpdateHealthUI()
        local unit = GetHero()
        if unit == nil then return; end

        local currentHealth = unit.Health
        local maxHealth = unit.MaxHealth

        if currentHealth == nil or maxHealth == nil or unit.RallyHealth == nil then
            return
        end

        local rallyHealth = unit.RallyHealth.Store
        if ScreenAnchorsPlayer.HealthBack ~= nil then
            ModifyTextBox({ Id = ScreenAnchorsPlayer.HealthBack, Text = "UI_PlayerHealth", LuaKey = "TempTextData", LuaValue = { Current = math.ceil(currentHealth), Maximum = math.ceil(maxHealth) }, AutoSetDataProperties = false })
        end

        if ScreenAnchorsPlayer.HealthFill ~= nil then
            SetAnimationFrameTarget({ Name = "HealthBarFill", Fraction = 1 - (currentHealth) / maxHealth, DestinationId =
            ScreenAnchorsPlayer.HealthFill })
        end
        if ScreenAnchorsPlayer.HealthRally ~= nil then
            SetAnimationFrameTarget({ Name = "HealthBarFillWhite", Fraction = 1 - (currentHealth + rallyHealth) / maxHealth, DestinationId =
            ScreenAnchorsPlayer.HealthRally })
        end
        unit.RallyHealth.Cache =
        {
            CurrentHealth = currentHealth,
            MaxHealth = maxHealth
        }
    end

    function Ui.UpdateRallyHealthUI()
        local unit = GetHero()
        if unit == nil or unit.RallyHealth == nil or ScreenAnchorsPlayer.HealthRally == nil then return; end

        local rallyHealth = unit.RallyHealth.Store
        local currentHealth = unit.Health
        local maxHealth = unit.MaxHealth
        if unit.RallyHealth.Cache ~= nil then
            currentHealth = unit.RallyHealth.Cache.CurrentHealth
            maxHealth = unit.RallyHealth.Cache.MaxHealth
        end

        SetAnimationFrameTarget({
            Name = "HealthBarFillWhite",
            Fraction = 1 - (currentHealth + rallyHealth) / maxHealth,
            DestinationId = ScreenAnchorsPlayer.HealthRally
        })
    end

    function Ui.HideHealthUI()
        if ScreenAnchorsPlayer.HealthBack == nil then
            return
        end
        local healthIds = { "HealthBack", "HealthFill", "HealthFlash", "HealthRally", "BadgeId" }
        local healthAnchorIds = {}
        for i, id in pairs(healthIds) do
            table.insert(healthAnchorIds, ScreenAnchorsPlayer[id])
        end
        for i, id in pairs(ScreenAnchorsPlayer.LifePipIds or {}) do
            table.insert(healthAnchorIds, id)
        end

        for i, id in pairs(ScreenAnchorsPlayer.SelfStoredAmmo or {}) do
            table.insert(healthAnchorIds, id)
        end

        ScreenAnchorsPlayer.HealthBack = nil
        ScreenAnchorsPlayer.HealthFill = nil
        ScreenAnchorsPlayer.HealthFlash = nil
        ScreenAnchorsPlayer.HealthRally = nil
        ScreenAnchorsPlayer.LifePipIds = nil
        ScreenAnchorsPlayer.SelfStoredAmmo = nil
        ScreenAnchorsPlayer.BadgeId = nil

        HideObstacle({ Ids = healthAnchorIds, IncludeText = true, FadeTarget = 0, Duration = CombatUI.FadeDuration, Angle = 180, Distance =
        CombatUI.FadeDistance.Health })

        wait(CombatUI.FadeDuration, RoomThreadName)

        Destroy({ Ids = healthAnchorIds })
    end

    function Ui.DestroyHealthUI()
        local ids = CombineTables({
            ScreenAnchorsPlayer.HealthBack,
            ScreenAnchorsPlayer.HealthFill,
            ScreenAnchorsPlayer.HealthFlash,
            ScreenAnchorsPlayer.HealthRally,
            },
            ScreenAnchorsPlayer.LifePipIds
            )

        if not IsEmpty(ids) then
            Destroy({ Ids = ids })
        end
        ScreenAnchorsPlayer.HealthBack = nil
        ScreenAnchorsPlayer.HealthFill = nil
        ScreenAnchorsPlayer.HealthFlash = nil
        ScreenAnchorsPlayer.HealthRally = nil
        ScreenAnchorsPlayer.LifePipIds = nil
        ScreenAnchorsPlayer.BadgeId = nil
    end

    function Ui.UpdateLifePips()
        local unit = GetHero()
        if not unit or not ScreenAnchorsPlayer.LifePipIds or not unit.LastStands then
            return
        end

        for i, lifePipId in pairs(ScreenAnchorsPlayer.LifePipIds) do
            local lastStandData = unit.LastStands[i]
            if lastStandData then
                SetAnimation({ Name = lastStandData.Icon, DestinationId = lifePipId })
            else
                if unit.IsDead then
                    if IsMetaUpgradeActive("ExtraChanceReplenishMetaUpgrade") then
                        SetAnimation({ Name = "ExtraLifeReplenish", DestinationId = lifePipId })
                    else
                        SetAnimation({ Name = "ExtraLifeZag", DestinationId = lifePipId })
                    end
                else
                    SetAnimation({ Name = "ExtraLifeEmpty", DestinationId = lifePipId })
                end
            end
        end
    end

    -- Life pip X position, mirrored from the game's `70 + i * 32`
    function Ui.LifePipX(vanillaX)
        return (ScreenWidth - 80) - (vanillaX - 70)
    end

    function Ui.RecreateLifePips()
        if ScreenAnchorsPlayer.LifePipIds then
            Destroy { Ids = ScreenAnchorsPlayer.LifePipIds }
        end

        ScreenAnchorsPlayer.LifePipIds = {}

        local unit = GetHero()
        if unit == nil then return; end

        local numLastStands = 0
        if unit.IsDead then
            numLastStands = TableLength(unit.LastStands) + GetNumMetaUpgradeLastStands()
        elseif unit.MaxLastStands then
            numLastStands = unit.MaxLastStands
        end

        for i = 1, numLastStands do
            local obstacleId = CreateScreenObstacle({ Name = "BlankObstacle", Group = "Combat_UI", X = Ui.LifePipX(70 + i * 32), Y =
            baseY - 95 })
            SetAnimation({ Name = "ExtraLifeEmpty", DestinationId = obstacleId })
            table.insert(ScreenAnchorsPlayer.LifePipIds, obstacleId)
        end
        Ui.UpdateLifePips()
    end

    -- Ammo
    function Ui.ShowAmmoUI()
        if ScreenAnchorsPlayer.AmmoIndicatorUI ~= nil then
            return
        end
        local poxX = ScreenWidth - 512 - 150
        ScreenAnchorsPlayer.AmmoIndicatorUI = CreateScreenObstacle({ Name = "BlankObstacle", Group = "Combat_UI", X = poxX, Y =
        baseY - 62 })
        SetAnimation({ Name = "AmmoIndicatorIcon", DestinationId = ScreenAnchorsPlayer.AmmoIndicatorUI })
        CreateTextBox(MergeTables({
            Id = ScreenAnchorsPlayer.AmmoIndicatorUI,
            OffsetX = 24,
            OffsetY = -2,
            Font = "AlegreyaSansSCBold",
            FontSize = 24,
            ShadowRed = 0.1,
            ShadowBlue = 0.1,
            ShadowGreen = 0.1,
            OutlineColor = { 0.113, 0.113, 0.113, 1 },
            OutlineThickness = 1,
            ShadowAlpha = 1.0,
            ShadowBlur = 0,
            ShadowOffsetY = 2,
            ShadowOffsetX = 0,
            Justification = "Left",
        }, LocalizationData.UIScripts.AmmoUI))
        thread(Ui.UpdateAmmoUI)

        FadeObstacleIn({ Id = ScreenAnchorsPlayer.AmmoIndicatorUI, Duration = CombatUI.FadeInDuration, IncludeText = true, Distance =
        CombatUI.FadeDistance.Ammo, Direction = 0 })
    end

    function Ui.UpdateAmmoUI()
        local hero = GetHero()

        if ScreenAnchorsPlayer.AmmoIndicatorUI == nil or not hero then
            return
        end
        local ammoData =
        {
            Current = GetWeaponProperty{ Id = hero.ObjectId, WeaponName = "RangedWeapon", Property = "Ammo" },
            Maximum = GetWeaponMaxAmmo{ Id = hero.ObjectId, WeaponName = "RangedWeapon" }
        }

        if ammoData.Current == nil then
            -- The player wasn't initialized yet
            return
        end

        PulseText({ Id = ScreenAnchorsPlayer.AmmoIndicatorUI, ScaleTarget = 1.04, ScaleDuration = 0.05, HoldDuration = 0.05, PulseBias = 0.02 })
        ModifyTextBox({ Id = ScreenAnchorsPlayer.AmmoIndicatorUI, Text = "UI_AmmoText", OffsetY = -2, LuaKey = "TempTextData", LuaValue =
        ammoData, AutoSetDataProperties = false, })
    end

    function Ui.HideAmmoUI()
        if ScreenAnchorsPlayer.AmmoIndicatorUI == nil then
            return
        end
        ScreenAnchorsPlayer.AmmoIndicatorUIReloads = ScreenAnchorsPlayer.AmmoIndicatorUIReloads or {}

        local ids = CombineTables({ ScreenAnchorsPlayer.AmmoIndicatorUI }, ScreenAnchorsPlayer.AmmoIndicatorUIReloads)

        for i, reloadId in pairs(ids) do
            HideObstacle({ Id = reloadId, IncludeText = true, Distance = CombatUI.FadeDistance.Ammo, Angle = 180, Duration =
            CombatUI.FadeDuration, SmoothStep = true })
        end
        ScreenAnchorsPlayer.AmmoIndicatorUI = nil
        ScreenAnchorsPlayer.AmmoIndicatorUIReloads = nil

        wait(CombatUI.FadeDuration, RoomThreadName)

        Destroy({ Ids = ids })
    end

    local reloadPosX = ScreenWidth - 494 - 150

    function Ui.StartAmmoReloadPresentation(delay)
        ScreenAnchorsPlayer.AmmoIndicatorUIReloads = ScreenAnchorsPlayer.AmmoIndicatorUIReloads or {}
        local reloadTimer = delay
        if IsEmpty(ScreenAnchorsPlayer.AmmoIndicatorUIReloads) then
            local id = CreateScreenObstacle({ Name = "BlankObstacle", Group = "Combat_Menu", Y = baseY - 70, X = reloadPosX +
            40 * #ScreenAnchorsPlayer.AmmoIndicatorUIReloads })
            SetAnimation({ Name = "AmmoReloadTimer", DestinationId = id, PlaySpeed = 100 / reloadTimer })
            SetColor({ Id = ScreenAnchorsPlayer.AmmoIndicatorUI, Color = { 0.5, 0.5, 0.5, 1.0 } })
            table.insert(ScreenAnchorsPlayer.AmmoIndicatorUIReloads, id)
        else
            local id = CreateScreenObstacle({ Name = "BlankObstacle", Group = "Combat_Menu", Y = baseY - 62 + 35, X = reloadPosX +
            40 * #ScreenAnchorsPlayer.AmmoIndicatorUIReloads })
            SetAnimation({ Name = "AmmoMultipleReloadTimer", DestinationId = id, PlaySpeed = 100 / reloadTimer })
            SetColor({ Id = ScreenAnchorsPlayer.AmmoIndicatorUI, Color = { 0.5, 0.5, 0.5, 1.0 } })
            table.insert(ScreenAnchorsPlayer.AmmoIndicatorUIReloads, id)
        end
    end

    function Ui.EndAmmoReloadPresentation()
        if IsEmpty(ScreenAnchorsPlayer.AmmoIndicatorUIReloads) then
            return
        end

        SetColor({ Id = ScreenAnchorsPlayer.AmmoIndicatorUI, Color = { 1.0, 1.0, 1.0, 1.0 } })
        CreateAnimation({ DestinationId = ScreenAnchorsPlayer.AmmoIndicatorUI, Name = "AmmoReloadFinishedFlare" })
        table.remove(ScreenAnchorsPlayer.AmmoIndicatorUIReloads, 1)

        local destroyIds = {}
        for i, id in pairs(ScreenAnchorsPlayer.AmmoIndicatorUIReloads) do
            local targetId = SpawnObstacle({ Name = "InvisibleTarget", OffsetX = reloadPosX + 40 * (i - 1), OffsetY =
            baseY - 62 + 40, Group = "Standing" })
            Move({ Id = id, DestinationId = targetId, Duration = 0.25 })
            table.insert(destroyIds, targetId)
        end
        PlaySound({ Name = "/SFX/BloodstoneAmmoRecharged", Id = CurrentRun.Hero.ObjectId })
        Destroy({ Ids = destroyIds })
    end

    function Ui.DestroyAmmoUI()
        if ScreenAnchorsPlayer.AmmoIndicatorUI == nil then
            return
        end
        Destroy({ Id = ScreenAnchorsPlayer.AmmoIndicatorUI })
        if ScreenAnchorsPlayer.AmmoIndicatorUIReloads then
            Destroy({ Ids = ScreenAnchorsPlayer.AmmoIndicatorUIReloads })
        end
        ScreenAnchorsPlayer.AmmoIndicatorUI = nil
        ScreenAnchorsPlayer.AmmoIndicatorUIReloads = nil
    end

    -- Gun

    function Ui.ShowGunUI(gunData)
        if not CurrentRun.Hero.Weapons.GunWeapon then
            return
        end
        if ScreenAnchorsPlayer.GunUI ~= nil then
            return
        end

        if ScreenAnchorsPlayer.Shadow ~= nil then
            SetScaleX({ Id = ScreenAnchorsPlayer.Shadow, Fraction = -1.3 })
        end

        ScreenAnchorsPlayer.GunUI = CreateScreenObstacle({
            Name = "BlankObstacle",
            Group = "Combat_UI",
            X = ScreenWidth - GunUI.StartX - 64 - 100,
            Y = GunUI.StartY + offsetY
        })

        if HeroHasTrait("GunLoadedGrenadeTrait") then
            SetAnimation({ Name = "GunLaserIndicatorIcon", DestinationId = ScreenAnchorsPlayer.GunUI })
        else
            SetAnimation({ Name = "GunAmmoIndicatorIcon", DestinationId = ScreenAnchorsPlayer.GunUI })
        end

        local offsetX = 20
        CreateTextBox(MergeTables({
                Id = ScreenAnchorsPlayer.GunUI,
                OffsetX = offsetX,
                OffsetY = -2,
                Font = "AlegreyaSansSCBold",
                FontSize = 24,
                ShadowRed = 0.1,
                ShadowBlue = 0.1,
                ShadowGreen = 0.1,
                OutlineColor = { 0.113, 0.113, 0.113, 1 },
                OutlineThickness = 1,
                ShadowAlpha = 1.0,
                ShadowBlur = 0,
                ShadowOffsetY = 2,
                ShadowOffsetX = 0,
                Justification = "Left",
            },
            LocalizationData.UIScripts.GunUI))
        thread(Ui.UpdateGunUI)

        FadeObstacleIn({
            Id = ScreenAnchorsPlayer.GunUI,
            Duration = CombatUI.FadeInDuration,
            IncludeText = true,
            Distance =
                CombatUI.FadeDistance.Ammo,
            Direction = 0
        })
    end

    function Ui.UpdateGunUI(triggerArgs)
        if ScreenAnchorsPlayer.GunUI == nil then
            return
        end
        triggerArgs = triggerArgs or {}
        local ammoData =
        {
            Current = triggerArgs.Ammo or
                GetWeaponProperty({ Id = CurrentRun.Hero.ObjectId, WeaponName = "GunWeapon", Property = "Ammo" }),
            Maximum = triggerArgs.MaxAmmo or GetWeaponMaxAmmo({ Id = CurrentRun.Hero.ObjectId, WeaponName = "GunWeapon" })
        }

        if ammoData.Current == nil then
            -- No longer carrying gun
            return
        end

        PulseText({ Id = ScreenAnchorsPlayer.GunUI, ScaleTarget = 1.04, ScaleDuration = 0.05, HoldDuration = 0.05, PulseBias = 0.02 })
        if ammoData.Current > 0 then
            ModifyTextBox({ Id = ScreenAnchorsPlayer.GunUI, Text = "UI_GunText", Color = Color.White, ColorDuration = 0.04 })
        else
            ModifyTextBox({ Id = ScreenAnchorsPlayer.GunUI, Text = "UI_GunText", Color = Color.Red, ColorDuration = 0.04 })
        end

        ModifyTextBox({ Id = ScreenAnchorsPlayer.GunUI, Text = "UI_GunText", FadeTarget = 1 })
        if HeroHasTrait("GunInfiniteAmmoTrait") or HeroHasTrait("GunLoadedGrenadeInfiniteAmmoTrait") then
            ModifyTextBox({
                Id = ScreenAnchorsPlayer.GunUI,
                Text = "UI_Gun_Text_Infinity",
                OffsetY = -2,
                LuaKey = "TempTextData",
                LuaValue =
                    ammoData,
                AutoSetDataProperties = false,
            })
        else
            ModifyTextBox({
                Id = ScreenAnchorsPlayer.GunUI,
                Text = "UI_GunText",
                OffsetY = -2,
                LuaKey = "TempTextData",
                LuaValue =
                    ammoData,
                AutoSetDataProperties = false,
            })
        end
        if HeroHasTrait("GunLoadedGrenadeTrait") then
            SetAnimation({ Name = "GunLaserIndicatorIcon", DestinationId = ScreenAnchorsPlayer.GunUI })
        else
            SetAnimation({ Name = "GunAmmoIndicatorIcon", DestinationId = ScreenAnchorsPlayer.GunUI })
        end
    end

    function Ui.HideGunUI()
        if ScreenAnchorsPlayer.GunUI == nil then
            return
        end

        local id = ScreenAnchorsPlayer.GunUI
        HideObstacle({
            Id = id,
            IncludeText = true,
            Distance = CombatUI.FadeDistance.Ammo,
            Angle = 180,
            Duration = CombatUI
                .FadeDuration,
            SmoothStep = true
        })

        ScreenAnchorsPlayer.GunUI = nil

        wait(CombatUI.FadeDuration, RoomThreadName)
        Destroy({ Id = id })
        ModifyTextBox({ Id = id, FadeTarget = 0, FadeDuration = 0, AutoSetDataProperties = false, })
    end

    function Ui.DestroyGunUI()
        if ScreenAnchorsPlayer.GunUI == nil then
            return
        end
        Destroy({ Id = ScreenAnchorsPlayer.GunUI })
        ScreenAnchorsPlayer.GunUI = nil
    end

    -- Super meter (God aid)

    local function GetSuperFillPercent(i, superMeterPoints)
        local hero = CurrentRun.Hero
        if superMeterPoints <= (i - 1) * hero.SuperCost then
            return 0
        end
        if hero.SuperMeterLimit < hero.SuperCost * i and i == math.ceil(hero.SuperMeterLimit / hero.SuperCost) then
            return math.min(1, (superMeterPoints - (i - 1) * hero.SuperCost) / (hero.SuperMeterLimit % hero.SuperCost))
        end
        return math.min(1, (superMeterPoints - (i - 1) * hero.SuperCost) / hero.SuperCost)
    end

    function Ui.ShowSuperMeter()
        if not IsSuperValid() then
            return
        end

        if ScreenAnchorsPlayer.SuperMeterIcon ~= nil then
            -- Already visible
            return
        end

        local posX = ScreenWidth - 500 + 20

        ScreenAnchorsPlayer.SuperMeterIcon = CreateScreenObstacle{
            Name = "BlankObstacle",
            Group = "Combat_UI",
            X = posX - (10 - CombatUI.FadeDistance.Super),
            Y = baseY - 10
        }

        ScreenAnchorsPlayer.SuperMeterCap = CreateScreenObstacle{
            Name = "BlankObstacle",
            Group = "Combat_Menu",
            X = posX - (10 - CombatUI.FadeDistance.Super),
            Y = baseY - 10
        }

        ScreenAnchorsPlayer.SuperMeterHint = CreateScreenObstacle{
            Name = "BlankObstacle",
            X = posX - 10,
            Y = baseY - 10,
            Group = "Combat_Menu_Additive"
        }

        SetAnimation({ Name = "WrathBar", DestinationId = ScreenAnchorsPlayer.SuperMeterIcon })

        if HasHeroTraitValue("SuperMeterCap") then
            SetAnimation({ Name = "WrathBarRegenCap", DestinationId = ScreenAnchorsPlayer.SuperMeterCap })
        end

        local superMeterPoints = CurrentRun.Hero.SuperMeter or 0

        if CurrentRun.Hero.SuperMeter == CurrentRun.Hero.SuperMeterLimit and IsSuperAvailable(CurrentRun.Hero) and CanCommenceSuper() then
            SetAnimation({ Name = "WrathBarFullFx", DestinationId = ScreenAnchorsPlayer.SuperMeterHint })
        end

        ScreenAnchorsPlayer.SuperPipBackingIds = {}
        ScreenAnchorsPlayer.SuperPipIds = {}
        local pipXSize = SuperUI.PipXWidth * CurrentRun.Hero.SuperCost / SuperUI.BaseMoveThreshold
        for i = 1, math.ceil(CurrentRun.Hero.SuperMeterLimit / CurrentRun.Hero.SuperCost) do
            table.insert(ScreenAnchorsPlayer.SuperPipBackingIds,
                CreateScreenObstacle{
                    Name = "BlankObstacle",
                    Group = "Combat_UI",
                    X = posX + SuperUI.PipXStart + (i - 1) * pipXSize - CombatUI.FadeDistance.Super + 20,
                    Y = SuperUI.PipY + offsetY }
            )
            table.insert(ScreenAnchorsPlayer.SuperPipIds,
                CreateScreenObstacle{
                    Name = "BlankObstacle",
                    Group = "Combat_Menu_Additive",
                    X = posX + SuperUI.PipXStart + (i - 1) * pipXSize - CombatUI.FadeDistance.Super + 20,
                    Y = SuperUI.PipY + offsetY
                }
            )
            Ui.UpdateSuperUIComponent(i, GetSuperFillPercent(i, superMeterPoints))
        end

        UpdateSuperMeterUI()

        FadeObstacleIn({ Id = ScreenAnchorsPlayer.SuperMeterIcon, Duration = CombatUI.FadeInDuration, IncludeText = true, Distance =
        CombatUI.FadeDistance.Super, Direction = 0 })
        FadeObstacleIn({ Id = ScreenAnchorsPlayer.SuperMeterCap, Duration = CombatUI.FadeInDuration, IncludeText = true, Distance =
        CombatUI.FadeDistance.Super, Direction = 0 })
        for i, pipId in pairs(ScreenAnchorsPlayer.SuperPipIds) do
            FadeObstacleIn({ Id = pipId, Duration = CombatUI.FadeInDuration, IncludeText = false, Distance = CombatUI
            .FadeDistance.Super, Direction = 0 })
        end
        for i, pipId in pairs(ScreenAnchorsPlayer.SuperPipBackingIds) do
            FadeObstacleIn({ Id = pipId, Duration = CombatUI.FadeInDuration, IncludeText = false, Distance = CombatUI
            .FadeDistance.Super, Direction = 0 })
        end
    end

    function Ui.HideSuperMeter()
        if ScreenAnchorsPlayer.SuperMeterIcon == nil then
            -- Already hidden
            return
        end

        HideObstacle({ Id = ScreenAnchorsPlayer.SuperMeterIcon, IncludeText = true, Distance = CombatUI.FadeDistance.Super, Angle = 180, Duration =
        CombatUI.FadeDuration, SmoothStep = true })
        HideObstacle({ Id = ScreenAnchorsPlayer.SuperMeterCap, IncludeText = true, Distance = CombatUI.FadeDistance.Super, Angle = 180, Duration =
        CombatUI.FadeDuration, SmoothStep = true })

        for i, pipId in pairs(ScreenAnchorsPlayer.SuperPipIds) do
            Move({ Id = pipId, Distance = CombatUI.FadeDistance.Super, Angle = 180, Duration = CombatUI.FadeDuration, SmoothStep = true })
            SetAlpha({ Id = pipId, Fraction = 0, Duration = CombatUI.FadeDuration })
        end

        for i, pipId in pairs(ScreenAnchorsPlayer.SuperPipBackingIds) do
            Move({ Id = pipId, Distance = CombatUI.FadeDistance.Super, Angle = 180, Duration = CombatUI.FadeDuration, SmoothStep = true })
            SetAlpha({ Id = pipId, Fraction = 0, Duration = CombatUI.FadeDuration })
        end

        local ids = CombineTables(ScreenAnchorsPlayer.SuperPipIds, ScreenAnchorsPlayer.SuperPipBackingIds) or {}
        table.insert(ids, ScreenAnchorsPlayer.SuperMeterIcon)
        table.insert(ids, ScreenAnchorsPlayer.SuperMeterCap)
        table.insert(ids, ScreenAnchorsPlayer.SuperMeterHint)

        ScreenAnchorsPlayer.SuperMeterIcon = nil
        ScreenAnchorsPlayer.SuperMeterCap = nil
        ScreenAnchorsPlayer.SuperMeterHint = nil
        ScreenAnchorsPlayer.SuperPipIds = nil
        ScreenAnchorsPlayer.SuperPipBackingIds = nil

        wait(CombatUI.FadeDuration, RoomThreadName)

        Destroy({ Ids = ids })
    end

    function Ui.DestroySuperMeter()
        local ids = CombineTables(ScreenAnchorsPlayer.SuperPipIds, ScreenAnchorsPlayer.SuperPipBackingIds) or {}
        table.insert(ids, ScreenAnchorsPlayer.SuperMeterIcon)
        table.insert(ids, ScreenAnchorsPlayer.SuperMeterCap)
        table.insert(ids, ScreenAnchorsPlayer.SuperMeterHint)
        if not IsEmpty(ids) then
            Destroy({ Ids = ids })
        end
        ScreenAnchorsPlayer.SuperMeterIcon = nil
        ScreenAnchorsPlayer.SuperMeterCap = nil
        ScreenAnchorsPlayer.SuperMeterHint = nil
        ScreenAnchorsPlayer.SuperPipIds = nil
        ScreenAnchorsPlayer.SuperPipBackingIds = nil
    end

    function Ui.UpdateSuperUIComponent(index, filled)
        if not CurrentRun.Hero.SuperCost or not ScreenAnchorsPlayer.SuperPipBackingIds then
            return
        end
        --- leave this

        local animationName = "WrathPipEmpty"
        if filled >= 1 then
            animationName = "WrathPipFull"
        elseif filled > 0 then
            animationName = "WrathPipPartial"
        end

        SetAnimation({ Name = "WrathPipEmpty", DestinationId = ScreenAnchorsPlayer.SuperPipBackingIds[index] })
        SetAnimation({ Name = animationName, DestinationId = ScreenAnchorsPlayer.SuperPipIds[index] })
        local baseFraction = CurrentRun.Hero.SuperCost / SuperUI.BaseMoveThreshold * 1.0

        if CurrentRun.Hero.SuperMeterLimit < CurrentRun.Hero.SuperCost * index then
            baseFraction = (CurrentRun.Hero.SuperMeterLimit % CurrentRun.Hero.SuperCost) / SuperUI.BaseMoveThreshold * 1.0
        end
        SetScaleX({ Id = ScreenAnchorsPlayer.SuperPipBackingIds[index], Fraction = baseFraction, Duration = 0 })
        SetScaleX({ Id = ScreenAnchorsPlayer.SuperPipIds[index], Fraction = baseFraction * filled, Duration = 0 })
    end

    function Ui.UpdateSuperMeterUIReal()
        if not CurrentRun.Hero.SuperCost then
            return
        end
        --- leave this

        if ScreenAnchorsPlayer.SuperMeterIcon == nil then
            return
        end

        local superMeterPoints = CurrentRun.Hero.SuperMeter or 0

        for i = 1, TableLength(ScreenAnchorsPlayer.SuperPipBackingIds) do
            Ui.UpdateSuperUIComponent(i, GetSuperFillPercent(i, superMeterPoints))
        end
        ModifyTextBox({ Id = ScreenAnchorsPlayer.SuperMeterIcon, Text = "UI_SuperText", LuaKey = "TempTextData", LuaValue = { Current = math.floor(superMeterPoints), Maximum = CurrentRun.Hero.SuperMeterLimit } })

        UIScriptsDeferred.SuperMeterDirty = false
    end

    function Ui.Refresh()
        Ui.UpdateHealthUI()
        Ui.RecreateLifePips()
        Ui.UpdateAmmoUI()
    end

    return Ui
end

---@param playerId number
---@return PlayerUiInstance?
function PlayerUi.Get(playerId)
    if not playerId or playerId < 2 or playerId > PlayerUi.MaxPlayers then
        return nil
    end
    local ui = instances[playerId]
    if not ui then
        ui = New(playerId)
        instances[playerId] = ui
    end
    return ui
end

--- HUD of an additional player's hero; nil for player 1 and non-player tables
---@param hero table?
---@return PlayerUiInstance?
function PlayerUi.ForHero(hero)
    if not hero or hero == CoopPlayers.GetMainHero() then
        return nil
    end
    return PlayerUi.Get(CoopPlayers.GetPlayerByHero(hero))
end

--- Calls fun(ui, hero, playerId) for every additional player that has a hero
---@param fun fun(ui: PlayerUiInstance, hero: table, playerId: number)
function PlayerUi.ForEachPlayer(fun)
    for playerId = 2, PlayerUi.MaxPlayers do
        local hero = CoopPlayers.GetHero(playerId)
        if hero then
            fun(PlayerUi.Get(playerId), hero, playerId)
        end
    end
end

--- Calls fun(ui) for every HUD instance that was created, with or without a hero.
--- Use it for hide/destroy calls, so nothing is left on screen.
---@param fun fun(ui: PlayerUiInstance)
function PlayerUi.ForEachInstance(fun)
    for playerId = 2, PlayerUi.MaxPlayers do
        local ui = instances[playerId]
        if ui then
            fun(ui)
        end
    end
end

function PlayerUi.Refresh()
    PlayerUi.ForEachPlayer(function(ui)
        ui.Refresh()
    end)
end

return PlayerUi
