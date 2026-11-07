//
// Copyright (c) Uladzislau Nikalayevich <thenormalnij@gmail.com>. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for details.
//

#include "PlayerManagerExtension.h"
#include "../interface/PlayerManager.h"

#include <malloc.h>
#include <cstring>

// Grows the game's player vector (eastl::vector<Player*, allocator_forge>, 2 slots by default).
// The game's allocator_forge is _aligned_malloc/_aligned_free from the UCRT, the same heap this DLL uses,
// so we can reallocate the buffer ourselves. The game always reads the vector through PlayerManager,
// never through a cached pointer, so swapping the buffer is safe.
bool PlayerManagerExtension::EnsurePlayerSlots(size_t count) {
    auto &players = SGG::PlayerManager::Instance()->m_palyers;
    if (players.size() >= count)
        return true;

    struct RawVector {
        SGG::Player **begin;
        SGG::Player **end;
        SGG::Player **capacity;
    };
    static_assert(sizeof(RawVector) == sizeof(players), "Unexpected eastl::vector layout");

    auto *raw = reinterpret_cast<RawVector *>(&players);
    size_t oldSize = raw->end - raw->begin;

    auto **buffer = static_cast<SGG::Player **>(_aligned_malloc(count * sizeof(SGG::Player *), 16));
    if (!buffer)
        return false;

    std::memset(buffer, 0, count * sizeof(SGG::Player *));
    if (raw->begin) {
        std::memcpy(buffer, raw->begin, oldSize * sizeof(SGG::Player *));
        _aligned_free(raw->begin);
    }

    raw->begin = buffer;
    raw->end = buffer + count;
    raw->capacity = buffer + count;
    return true;
}

bool PlayerManagerExtension::AssignGamepad(size_t playerIndex, uint8_t gamepadIndex) {
    if (GetPlayersCount() < playerIndex + 1)
        return false;

    auto *player = SGG::PlayerManager::Instance()->GetPlayer(playerIndex);

    if (!player)
        return false;

    auto *input = GetInput(player->GetControllerIndex());

    if (!input)
        return false;

    input->SetGamepadId(gamepadIndex);

    return true;
}

uint8_t PlayerManagerExtension::GetGamepad(size_t playerIndex) {
    if (GetPlayersCount() < playerIndex + 1)
        return -1;

    auto *player = SGG::PlayerManager::Instance()->GetPlayer(playerIndex);

    if (!player)
        return -1;

    auto *input = GetInput(player->GetControllerIndex());

    if (!input)
        return -1;

    return input->GetGamepadId();
}

bool PlayerManagerExtension::AssignController(SGG::Player *player, uint8_t ccontroler) {
    SGG::PlayerManager::Instance()->AssignController(player, ccontroler);
    return false;
}

bool PlayerManagerExtension::HasPlayer(size_t index) {
    auto *instance = SGG::PlayerManager::Instance();
    if (instance->m_palyers.size() <= index)
        return false;

    return instance->m_palyers[index];
}

// TODO use RemovePlayer from the game
void PlayerManagerExtension::RemovePlayer(size_t index) {
    auto *instance = SGG::PlayerManager::Instance();
    if (instance->m_palyers.size() <= index)
        return;

    auto *player = instance->m_palyers[index];

    if (player) {
        delete player;
        instance->m_palyers[index] = nullptr;
    }
}

SGG::Player *PlayerManagerExtension::CreatePlayer(size_t index) {
    auto *instance = SGG::PlayerManager::Instance();

    if (index >= MAX_PLAYERS)
        return nullptr;

    // The game creates this vector with 2 slots; grow it for players 3 and 4
    if (!EnsurePlayerSlots(index + 1))
        return nullptr;

    if (instance->m_palyers[index] != nullptr)
        return nullptr;

    // One controller slot per player: P1 = 0, P2 = 1, P3 = 2, P4 = 3
    uint8_t controller = static_cast<uint8_t>(index);

    auto player = instance->AddPlayer(index);

    AssignController(player, controller);

    return player;
}

SGG::Player *PlayerManagerExtension::GetPlayer(size_t index) {
    auto *instance = SGG::PlayerManager::Instance();
    if (instance->m_palyers.size() <= index)
        return nullptr;
    return instance->m_palyers[index];
}
SGG::InputHandler *PlayerManagerExtension::GetInput(size_t index) {
    auto *instance = SGG::PlayerManager::Instance();
    if (instance->m_inputMethods.size() <= index)
        return nullptr;
    return instance->m_inputMethods[index];
};

size_t PlayerManagerExtension::GetPlayersCount() const noexcept {
    size_t size = 0;
    for (auto *player : SGG::PlayerManager::Instance()->m_palyers)
        if (player)
            size++;

    return size;
}
