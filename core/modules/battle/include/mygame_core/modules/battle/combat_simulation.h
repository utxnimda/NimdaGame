#pragma once

namespace mygame_core::modules::battle {

struct UnitState {
    int hp = 0;
    int attack = 0;
    int defense = 0;
};

struct AttackResult {
    int damage = 0;
    int defender_hp = 0;
};

AttackResult resolve_basic_attack(const UnitState& attacker, const UnitState& defender);

} // namespace mygame_core::modules::battle
