--
-- Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
-- Licensed under the MIT license. See LICENSE file in the project root for details.
--

local SelectedGuiControl = {}

local function GetCurrentControl()
    local isMouseVisible = GetConfigOptionValue { Name = "UseMouse" } or
        not GetConfigOptionValue { Name = "UseGamepadGlyphs" }

    if isMouseVisible then
        return
        {
            Device = "Keyboard",
            ControllerId = -1,
        }
    else
        return
        {
            Device = "Gamepad",
            ControllerId = CoopGetPlayerGamepad(1),
        }
    end
end

local function TostringPlayerConfiguration(playerId)
    if SelectedGuiControl[playerId].Device == "Keyboard" then
        return GetDisplayName { Text = "CoopMenu_KbAndMouse" }
    else
        local index = SelectedGuiControl[playerId].ControllerId
        --return "Gamepad " .. index .. " - " .. CoopGetGamepadName(index)
        return GetDisplayName { Text = "CoopMenu_Gamepad", Param =  index }
    end
end

local MAX_PLAYERS = 4

local MENU_STATE = {
    START = 0;
    PLAYER_ONE_SELECTED = 1,
    -- 2+ players joined: another gamepad joins, Player 1 starts the game
    PLAYERS_JOINING = 2,
    INVALID_STATE_SECOND_KEYBOARD = 3,
    INVALID_STATE_SAME_DEVICE = 4,
    -- MAX_PLAYERS joined: any press starts the game
    PLAYERS_FULL = 5,
}

local CURRENT_MENU_STATE

local function PlayersText()
    local template = GetDisplayName { Text = "CoopMenu_PlayerController" }
    local lines = {}
    for playerId = 1, #SelectedGuiControl do
        local line = string.gsub(template, "%$(%w+)",
            { PlayerIndex = playerId, Controller = TostringPlayerConfiguration(playerId) })
        table.insert(lines, line)
    end
    return table.concat(lines, "\n")
end

local function IsSameDevice(a, b)
    return a.Device == b.Device and a.ControllerId == b.ControllerId
end

local START_BUTTON_MESSAGES = {
    "Let's play",
    "Go, go, go",
    "Start",
    "Let the Carnage Begin!",
    "Next",
    "Let's Roll!",
    "Game On!",
    "Adventure Awaits",
    "Initiate Chaos!",
    "Begin the Hunt!",
    "It's Time to Kick Gum and Chew Ass",
    "Fus Ro Dah!",
    "Let's Cause Trouble",
    "Press Start to Change Everything"
}

MainMenuAPIAddGamemode("Coop", function(name)
    SelectedGuiControl = {}

    local menu = CreateMenuScreen()
    menu:CreateBack(0.8)
    menu:CreateBackground("")
    menu:CreateTitleText()
    menu:SetLowerInputBlock(true)

    menu:CreateCancelButton(function()
        SetTempRuntimeData("Gamemode", nil)
        menu:ExitScreen()
    end)

    local message = CreateGUIComponentTextBox(menu)

    menu:AddReflection("mMessageText", message)

    local btn = CreateGUIComponentButton(menu)

    local function SetStage(state)
        CURRENT_MENU_STATE = state

        if state == MENU_STATE.START then
            message:SetTextLocalizationKey("CoopMenu_StartMessage")
            btn:SetTextLocalizationKey("CoopMenu_P1Press")
        elseif state == MENU_STATE.PLAYER_ONE_SELECTED then
            message:SetText(PlayersText())
            btn:SetTextLocalizationKey("CoopMenu_P2Press")
        elseif state == MENU_STATE.PLAYERS_JOINING then
            message:SetText(PlayersText())
            local template = GetDisplayName { Text = "CoopMenu_JoinOrStart" }
            btn:SetText((string.gsub(template, "%$(%w+)", { PlayerIndex = #SelectedGuiControl + 1 })))
        elseif state == MENU_STATE.PLAYERS_FULL then
            message:SetText(PlayersText())
            btn:SetText(START_BUTTON_MESSAGES[math.random(1, #START_BUTTON_MESSAGES)])
        elseif state == MENU_STATE.INVALID_STATE_SECOND_KEYBOARD then
            message:SetTextLocalizationKey("CoopMenu_ErrP1KBOnly")
            btn:SetTextLocalizationKey("CoopMenu_Again")
        elseif state == MENU_STATE.INVALID_STATE_SAME_DEVICE then
            message:SetTextLocalizationKey("CoopMenu_ErrDeviceCollision")
            btn:SetTextLocalizationKey("CoopMenu_Again")
        else
            message:SetText("Error description is missing :D")
            btn:SetTextLocalizationKey("CoopMenu_Again")
        end
    end

    local function StartGame()
        SetTempRuntimeData("Gamemode", name)
        SetTempRuntimeData("TN_Coop:control", SelectedGuiControl)
        MainMenuOpenProfiles()
    end

    local function StageAfterJoin()
        if #SelectedGuiControl >= MAX_PLAYERS then
            SetStage(MENU_STATE.PLAYERS_FULL)
        else
            SetStage(MENU_STATE.PLAYERS_JOINING)
        end
    end

    SetStage(MENU_STATE.START)

    btn:AddActivationHandler(function()
        if CURRENT_MENU_STATE == MENU_STATE.START then
            SelectedGuiControl = { GetCurrentControl() }
            SetStage(MENU_STATE.PLAYER_ONE_SELECTED)
        elseif CURRENT_MENU_STATE == MENU_STATE.PLAYER_ONE_SELECTED
            or CURRENT_MENU_STATE == MENU_STATE.PLAYERS_JOINING then
            local control = GetCurrentControl()

            -- Player 1 pressing again starts the game (needs at least 2 players)
            if CURRENT_MENU_STATE == MENU_STATE.PLAYERS_JOINING and IsSameDevice(control, SelectedGuiControl[1]) then
                StartGame()
                return
            end

            if control.Device == "Keyboard" then
                SetStage(MENU_STATE.INVALID_STATE_SECOND_KEYBOARD)
                return
            end

            for _, joined in ipairs(SelectedGuiControl) do
                if IsSameDevice(control, joined) then
                    -- An already joined gamepad (not Player 1): ignore the press
                    if CURRENT_MENU_STATE == MENU_STATE.PLAYER_ONE_SELECTED then
                        SetStage(MENU_STATE.INVALID_STATE_SAME_DEVICE)
                    end
                    return
                end
            end

            table.insert(SelectedGuiControl, control)
            StageAfterJoin()
        elseif CURRENT_MENU_STATE == MENU_STATE.PLAYERS_FULL then
            StartGame()
        elseif #SelectedGuiControl >= 2 then
            -- Error while more players were joining: keep the players who already joined
            StageAfterJoin()
        else
            SelectedGuiControl = {}
            SetStage(MENU_STATE.START)
        end
    end)

    menu:AddReflection("mControllerPress", btn)

    menu:LoadDefenitions("../Mods/TN_CoopMod/ControllerSelectionMenuScreen.sjson")
end)
