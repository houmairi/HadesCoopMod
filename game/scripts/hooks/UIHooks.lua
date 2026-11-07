--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

---@type PlayerUi
local PlayerUi = ModRequire "../PlayerUI.lua"
---@type CombinedTraitsUI
local CombinedTraitsUI = ModRequire "../CombinedTraitsUI.lua"
---@type CoopPlayers
local CoopPlayers = ModRequire "../CoopPlayers.lua"
---@type HeroContext
local HeroContext = ModRequire "../HeroContext.lua"
---@type HookUtils
local HookUtils = ModRequire "../HookUtils.lua"
---@type RunEx
local RunEx = ModRequire "../RunEx.lua"

---@class UIHooks
local UIHooks = {}

---@private
---@param hero table?
function UIHooks.ShouldBeUiVisibleFor(hero)
    return hero and (RunEx.IsRunEnded() or not hero.IsDead)
end

---@private
---@param funcName string
function UIHooks.CreateSimpleHook(funcName)
    local orig = _G[funcName]
    _G[funcName] = function(...)
        local args = table.pack(...)
        local mainHero = CoopPlayers.GetMainHero()
        HeroContext.RunWithHeroContext(mainHero, orig, ...)
        PlayerUi.ForEachPlayer(function(ui, hero)
            HeroContext.RunWithHeroContext(hero, ui[funcName], table.unpack(args, 1, args.n))
        end)
    end
end

---@private
---@param funcName string
function UIHooks.SimpleHookWithVisibilityCheck(funcName)
    local orig = _G[funcName]
    _G[funcName] = function(...)
        local args = table.pack(...)
        local mainHero = CoopPlayers.GetMainHero()
        if UIHooks.ShouldBeUiVisibleFor(mainHero) then
            HeroContext.RunWithHeroContext(mainHero, orig, ...)
        end
        PlayerUi.ForEachPlayer(function(ui, hero)
            if UIHooks.ShouldBeUiVisibleFor(hero) then
                HeroContext.RunWithHeroContext(hero, ui[funcName], table.unpack(args, 1, args.n))
            end
        end)
    end
end

--- Runs a hide/destroy function on every additional player's HUD
---@private
---@param funcName string
---@param inThread boolean? the function waits for a fade out
function UIHooks.ForAllAdditionalUis(funcName, inThread)
    return function()
        PlayerUi.ForEachInstance(function(ui)
            if inThread then
                thread(ui[funcName])
            else
                ui[funcName]()
            end
        end)
    end
end

--- HUD of the hero in the current hero context; nil for player 1
---@private
---@return PlayerUiInstance?
function UIHooks.GetCurrentAdditionalUi()
    return PlayerUi.ForHero(HeroContext.GetCurrentHeroContext())
end

---@private
function UIHooks.SimpleCurrentTraitWrapper(funcName)
    HookUtils.wrap(funcName, function(baseFun, ...)
        HeroContext.RunWithHeroContext(CombinedTraitsUI.GetCurrentTraitHero(), baseFun, ...)
    end)
end

function UIHooks.InitHooks()
    -- Health
    UIHooks.SimpleHookWithVisibilityCheck("ShowHealthUI")

    UIHooks.CreateSimpleHook("UpdateHealthUI")
    HookUtils.onPostFunction("DestroyHealthUI", UIHooks.ForAllAdditionalUis("DestroyHealthUI"))
    HookUtils.onPreFunction("HideHealthUI", UIHooks.ForAllAdditionalUis("HideHealthUI", true))
    HookUtils.onPostFunction("UpdateRallyHealthUI", UIHooks.ForAllAdditionalUis("UpdateRallyHealthUI"))

    -- LifePipIds
    UIHooks.CreateSimpleHook("RecreateLifePips")

    HookUtils.wrap("UpdateLifePips", function(basefun, unit)
        local mainHero = CoopPlayers.GetMainHero()
        if not mainHero or not unit or mainHero == unit then
            basefun(mainHero)
        end
        local ui = PlayerUi.ForHero(unit)
        if ui then
            ui.UpdateLifePips()
        elseif unit ~= mainHero then
            UIHooks.ForAllAdditionalUis("UpdateLifePips")()
        end
    end)

    local _AddLastStand = AddLastStand
    AddLastStand = function(args)
        local ui = PlayerUi.ForHero((args and args.Unit) or HeroContext.GetCurrentHeroContext())
        local pipsBackup = ScreenAnchors.LifePipIds
        local _CreateScreenObstacle = CreateScreenObstacle
        if ui then
            ScreenAnchors.LifePipIds = ui.ScreenAnchors.LifePipIds
            -- Move new life pips to this player's HUD row
            CreateScreenObstacle = function(obstacleArgs)
                obstacleArgs.X = ui.LifePipX(obstacleArgs.X)
                obstacleArgs.Y = obstacleArgs.Y + ui.OffsetY
                return _CreateScreenObstacle(obstacleArgs)
            end
        end

        _AddLastStand(args)

        if ui then
            ScreenAnchors.LifePipIds = pipsBackup
            CreateScreenObstacle = _CreateScreenObstacle
        end
    end

    -- Ammo (red crystrals)
    UIHooks.SimpleHookWithVisibilityCheck("ShowAmmoUI")
    HookUtils.onPreFunction("HideAmmoUI", UIHooks.ForAllAdditionalUis("HideAmmoUI", true))
    HookUtils.onPreFunction("DestroyAmmoUI", UIHooks.ForAllAdditionalUis("DestroyAmmoUI"))

    HookUtils.wrap("StartAmmoReloadPresentation", function(baseFun, delay)
        local ui = UIHooks.GetCurrentAdditionalUi()
        if ui then
            ui.StartAmmoReloadPresentation(delay)
        else
            baseFun(delay)
        end
    end)

    HookUtils.wrap("EndAmmoReloadPresentation", function(baseFun)
        local ui = UIHooks.GetCurrentAdditionalUi()
        if ui then
            ui.EndAmmoReloadPresentation()
        else
            baseFun()
        end
    end)

    local _UpdateAmmoUI = UpdateAmmoUI
    UpdateAmmoUI = function()
        local mainHero = CoopPlayers.GetMainHero()
        if HeroContext.IsHeroContextExplicit() then
            local ui = UIHooks.GetCurrentAdditionalUi()
            if ui then
                ui.UpdateAmmoUI()
            else
                _UpdateAmmoUI()
            end
        else
            HeroContext.RunWithHeroContext(mainHero, function()
                _UpdateAmmoUI()
                UIHooks.ForAllAdditionalUis("UpdateAmmoUI")()
            end)
        end
    end

    HookUtils.wrap("AddAmmoPresentation", function(baseFun, ...)
        local ui = PlayerUi.ForHero(CurrentRun.Hero)
        if ui then
            thread(ui.UpdateAmmoUI)

            CreateAnimation({ Name = "QuickFlashRedSmall", DestinationId = CurrentRun.Hero.ObjectId, OffsetZ = -90 })

            if ui.ScreenAnchors.AmmoIndicatorUI ~= nil then
                ModifyTextBox({ Id = ui.ScreenAnchors.AmmoIndicatorUI, ColorTarget = Color.White, ColorDuration = 0.5, AutoSetDataProperties = false, })
                thread(PulseText,
                    { ScreenAnchorReference = "AmmoIndicatorUI", ScaleTarget = 1.3, ScaleDuration = 0.125, HoldDuration = 0.1, PulseBias = 0.2 })
            end
        else
            baseFun(...);
        end
    end)

    -- Gun
    UIHooks.SimpleHookWithVisibilityCheck("ShowGunUI")

    local _HideGunUI = HideGunUI
    HideGunUI = function()
        local mainHero = CoopPlayers.GetMainHero()
        HeroContext.RunWithHeroContext(mainHero, _HideGunUI)
        PlayerUi.ForEachPlayer(function(ui, hero)
            HeroContext.RunWithHeroContext(hero, ui.HideGunUI)
        end)
    end

    local _UpdateGunUI = UpdateGunUI
    UpdateGunUI = function()
        local mainHero = CoopPlayers.GetMainHero()

        if HeroContext.IsHeroContextExplicit() then
            local currentHero = HeroContext.GetCurrentHeroContext()
            if mainHero == currentHero then
                HeroContext.RunWithHeroContext(mainHero, _UpdateGunUI)
            else
                local ui = PlayerUi.ForHero(currentHero)
                if ui then
                    HeroContext.RunWithHeroContext(currentHero, ui.UpdateGunUI)
                end
            end
        else
            HeroContext.RunWithHeroContext(mainHero, _UpdateGunUI)
            PlayerUi.ForEachPlayer(function(ui, hero)
                HeroContext.RunWithHeroContext(hero, ui.UpdateGunUI)
            end)
        end
    end

    EquipPlayerWeaponPresentation = function(weaponData, args)
        wait(0.02)
        -- TODO: Fix hero here, maybe
        PlaySound({ Name = "/SFX/Menu Sounds/WeaponEquipChunk", Id = CurrentRun.Hero.ObjectId })
        if not args.SkipEquipLines then
            thread(PlayVoiceLines, weaponData.EquipVoiceLines, false)
        end

        local function hasHeroWeaponWithIcon(hero)
            for weaponName in pairs(hero.Weapons) do
                if WeaponData[weaponName].ActiveReloadTime then
                    return true
                end
            end
            return false
        end

        local hero = CoopPlayers.GetMainHero()
        local execFun = hasHeroWeaponWithIcon(hero) and ShowGunUI or _HideGunUI
        thread(function()
            HeroContext.RunWithHeroContext(hero, execFun)
        end)

        PlayerUi.ForEachPlayer(function(ui, additionalHero)
            local fun = hasHeroWeaponWithIcon(additionalHero) and ui.ShowGunUI or ui.HideGunUI
            thread(function()
                HeroContext.RunWithHeroContext(additionalHero, fun)
            end)
        end)
    end

    HookUtils.onPostFunction("DestroyGunUI", UIHooks.ForAllAdditionalUis("DestroyGunUI"))

    -- Super meter (God aid)
    UIHooks.SimpleHookWithVisibilityCheck("ShowSuperMeter")
    UIHooks.SimpleHookWithVisibilityCheck("UpdateSuperMeterUIReal")
    UIHooks.CreateSimpleHook("DestroySuperMeter")
    UIHooks.CreateSimpleHook("HideSuperMeter")

    -- Called by the game's own ShowSuperMeter/UpdateSuperMeterUIReal for player 1.
    -- Additional players' HUDs update their pips themselves.
    local _UpdateSuperUIComponent = UpdateSuperUIComponent
    UpdateSuperUIComponent = function(...)
        local ui = UIHooks.GetCurrentAdditionalUi()
        if ui then
            ui.UpdateSuperUIComponent(...)
        elseif ScreenAnchors.SuperPipBackingIds then
            HeroContext.RunWithHeroContext(CoopPlayers.GetMainHero(), _UpdateSuperUIComponent, ...)
        end
    end

    -- Traits
    HookUtils.onPreFunction("ShowAdvancedTooltip", CombinedTraitsUI.ChangeHeroInTraitsMenu)
    HookUtils.onPreFunction("TraitUIActivateTrait", CombinedTraitsUI.ChangeHeroInTraitsMenu)
    HookUtils.onPreFunction("TraitUIDeactivateTrait", CombinedTraitsUI.ChangeHeroInTraitsMenu)
    HookUtils.onPreFunction("TraitUICreateComponent", CombinedTraitsUI.ChangeHeroInTraitsMenu)
    HookUtils.onPreFunction("TraitUIUpdateText", CombinedTraitsUI.ChangeHeroInTraitsMenu)
    HookUtils.onPreFunction("TraitUIRemove", CombinedTraitsUI.ChangeHeroInTraitsMenu)
    HookUtils.onPreFunction("TraitUICreateText", CombinedTraitsUI.ChangeHeroInTraitsMenu)
    HookUtils.onPreFunction("UpdateTraitNumber", CombinedTraitsUI.ChangeHeroInTraitsMenu)
    HookUtils.onPreFunction("UpdateAdditionalTraitHint", CombinedTraitsUI.ChangeHeroInTraitsMenu)
    HookUtils.onPreFunction("TraitUIActivateTraits", CombinedTraitsUI.ChangeHeroInTraitsMenu)

    UIHooks.SimpleCurrentTraitWrapper("CloseAdvancedTooltipScreen")
    UIHooks.SimpleCurrentTraitWrapper("PinTraitDetails")

    -- Etc
    local _PulseText = PulseText
    PulseText = function(args)
        local ui = args.ScreenAnchorReference and UIHooks.GetCurrentAdditionalUi()
        if ui then
            local idOnPlayerUi = ui.ScreenAnchors[args.ScreenAnchorReference]
            if idOnPlayerUi then
                args.Id = idOnPlayerUi
            end
        end

        _PulseText(args)
    end

    HookUtils.onPostFunction("ShowUseButton", function(objectId, useTarget)
        if HeroContext.GetDefaultHero() ~= HeroContext.GetCurrentHeroContext() then
            Move({ Id = ScreenAnchors.UsePrompts[objectId], DestinationId = ScreenAnchors.UsePrompts[objectId], OffsetY = -50 })
        end
    end)
end

return UIHooks