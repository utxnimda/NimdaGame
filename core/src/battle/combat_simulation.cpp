#include "mygame_core/battle/combat_simulation.h"

#include <algorithm>

namespace mygame_core::battle {

AttackResult resolve_basic_attack(const UnitState& attacker, const UnitState& defender) {
    const int damage = std::max(1, attacker.attack - defender.defense);
    return AttackResult{
        .damage = damage,
        .defender_hp = std::max(0, defender.hp - damage),
    };
}

} // namespace mygame_core::battle
