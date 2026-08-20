extends "res://scripts/battle_demo_database_sequences.gd"

# Canonical database effect layer:
# database mechanics, status helpers and damage-category compatibility.

func _critical_chance(combatant: Dictionary) -> float:
    if bool(combatant.get("db_guaranteed_crit", false)):
        return 1.0
    var chance: float = super._critical_chance(combatant)
    var runtime_value: Variant = _database_active_move.get("runtime", {})
    if runtime_value is Dictionary and bool((runtime_value as Dictionary).get("high_crit", false)):
        chance = maxf(chance, 0.125)
    return chance

func _effect(actor: Dictionary, target: Dictionary, mechanic: Dictionary) -> float:
    var kind: String = str(mechanic.get("kind", ""))
    if kind == "status":
        var status_id: String = str(mechanic.get("status", ""))
        if _database_status_is_blocked(target, status_id):
            _spawn_feedback_label(target, "🛡️ IMMUN", Color("b8d9ff")); return 0.0
    match kind:
        "db_status": return _database_apply_status(target, mechanic)
        "db_chance_mechanic":
            if randf() <= float(mechanic.get("chance", 1.0)):
                var nested_value: Variant = mechanic.get("mechanic", {})
                if nested_value is Dictionary: return _effect(actor, target, nested_value as Dictionary)
            return 0.0
        "db_next_cycle_mod":
            var delta: float = float(actor.get("special", 0))/100.0*float(mechanic.get("multiplier_from_special", -1.0))
            actor["cycle"] = float(actor.get("cycle",1.0))*clampf(1.0+delta,0.45,2.5); return absf(delta)*8.0
        "db_incoming_accuracy":
            var factor: float = float(actor.get("special",0))/100.0*absf(float(mechanic.get("multiplier_from_special",1.0)))
            target["db_incoming_accuracy_mult"] = clampf(1.0+factor if str(mechanic.get("direction",""))=="bonus" else 1.0-factor,0.2,2.5)
            target["db_incoming_accuracy_expires"] = int(target.get("action_serial",0))+3; return factor*8.0
        "db_protect":
            var chain: int = maxi(0,int(actor.get("db_protect_chain",0))); var success_chance: float = pow(1.0/3.0,float(chain)); actor["db_protect_chain"] = chain+1
            if randf() <= success_chance:
                actor["protective_guard"] = true; _spawn_feedback_label(actor,"🛡️ SCHUTZSCHILD",Color("9fe7bd")); return 4.0
            _spawn_feedback_label(actor,"✖ SCHUTZ FEHLGESCHLAGEN",Color("d9a5a5")); return 0.0
        "db_heal_self":
            var percent: float = minf(float(actor.get("special",0)),float(mechanic.get("cap",100.0)))
            var missing: int = maxi(0,int(actor.get("max_hp",1))-int(actor.get("hp",0)))
            var amount: int = mini(missing,maxi(1,int(round(float(actor.get("max_hp",1))*percent/100.0))))
            actor["hp"] = int(actor.get("hp",0))+amount
            if amount>0: _spawn_feedback_label(actor,"💚 +"+str(amount)+" KP",Color("8fe39b"))
            return float(amount)
        "db_team_cleanse":
            if str(mechanic.get("status","")) == str(target.get("major_status","")):
                target["major_status"]=""; target["paralyzed"]=false; target["db_sleep_actions"]=0; return 3.0
            return 0.0
        "db_team_immunity":
            var immunities: Array = target.get("db_status_immunities", [])
            immunities.append({"status":str(mechanic.get("status","major_status")),"expires_after_action":int(target.get("action_serial",0))+maxi(1,int(mechanic.get("duration_actions",3)))})
            target["db_status_immunities"] = immunities; return 3.0
        "db_team_modifier":
            _add_timed_modifier(target,str(mechanic.get("modifier_kind","atb_cycle_mod")),clampf(1.0+float(actor.get("special",0))/100.0*float(mechanic.get("multiplier_from_special",-1.0)),0.25,4.0),str(_database_active_move.get("name","Team-Effekt")),_actor_name(actor)); return 4.0
        "db_redirect": target["db_redirect_expires"] = int(target.get("action_serial",0))+maxi(1,int(mechanic.get("duration_actions",3))); return 4.0
        "db_guaranteed_crit": actor["db_guaranteed_crit"] = true; return 4.0
        "db_equalize_hp":
            var damage: int = maxi(0,int(target.get("hp",0))-int(actor.get("hp",0)))
            if damage>0: target["hp"]=int(target.get("hp",0))-damage; target["alive"]=int(target.get("hp",0))>0
            return float(damage)
        "db_fraction_hp_damage":
            var damage: int = maxi(1,int(floor(float(target.get("hp",0))*float(mechanic.get("fraction",0.5)))))
            damage=mini(damage,int(target.get("hp",0))); target["hp"]=int(target.get("hp",0))-damage; target["alive"]=int(target.get("hp",0))>0; return float(damage)
        "db_on_ko_modifier":
            if not bool(target.get("alive",false)):
                _add_timed_modifier(actor,str(mechanic.get("modifier_kind","outgoing_damage_mod")),clampf(1.0+float(actor.get("special",0))/100.0*float(mechanic.get("multiplier_from_special",3.0)),0.25,4.0),str(_database_active_move.get("name","KO-Bonus")),_actor_name(actor)); return 5.0
            return 0.0
        "db_remove_type_until_next_action":
            var type_id: String = str(mechanic.get("type","")); var types: Array = _type_array(actor.get("types",[]))
            if types.has(type_id): types.erase(type_id); actor["types"]=types; actor["db_removed_type"]=type_id; actor["db_removed_type_until_action"]=int(actor.get("action_serial",0))+1
            return 0.0
        "db_stockpile":
            actor["db_stockpile"] = mini(int(mechanic.get("max",3)),int(actor.get("db_stockpile",0))+1); var stacks: int=int(actor.get("db_stockpile",0))
            _add_timed_modifier(actor,"incoming_damage_mod",clampf(1.0+float(actor.get("special",0))/100.0*-2.0*float(stacks),0.25,4.0),"Horter",_actor_name(actor)); return float(stacks)
        "db_swallow":
            var stacks: int=int(actor.get("db_stockpile",0)); if stacks<=0: return 0.0
            var fractions: Dictionary={1:0.25,2:0.50,3:1.0}; var missing: int=maxi(0,int(actor.get("max_hp",1))-int(actor.get("hp",0)))
            var heal: int=mini(missing,maxi(1,int(round(float(actor.get("max_hp",1))*float(fractions.get(stacks,1.0)))))); actor["hp"]=int(actor.get("hp",0))+heal; actor["db_stockpile"]=0; return float(heal)
        "db_spit_up":
            var stacks: int=int(actor.get("db_stockpile",0)); if stacks<=0: return 0.0
            var damage: int=_damage(actor,target,100*stacks,str(_database_active_move.get("type","normal")),str(_database_active_move.get("category","special")))
            target["hp"]=maxi(0,int(target.get("hp",0))-damage); target["alive"]=int(target.get("hp",0))>0; actor["db_stockpile"]=0; return float(damage)
        "db_cleanse_positive_modifiers": _database_remove_positive_modifiers(target); return 3.0
        "db_block_positive_modifiers": target["db_block_positive_expires"]=int(target.get("action_serial",0))+maxi(1,int(mechanic.get("duration_actions",3))); return 3.0
        "db_clear_all_temporary_modifiers":
            for candidate_value: Variant in combatants:
                if candidate_value is Dictionary: (candidate_value as Dictionary)["timed_modifiers"]=[]
            return 5.0
        "db_break_protect":
            if bool(target.get("protective_guard",false)): target["protective_guard"]=false; return 3.0
            return 0.0
        "db_light_screen":
            var reduction: float=minf(float(actor.get("special",0)),float(mechanic.get("strength_cap",50.0)))/100.0
            target["db_light_screen_reduction"]=reduction; target["db_light_screen_source_id"]=str(actor.get("id","")); target["db_light_screen_expires_source_action"]=int(actor.get("action_serial",0))+maxi(1,int(mechanic.get("duration_actions",3))); return reduction*10.0
        "db_toxic_spikes":
            var enemy_side: String="enemy" if str(actor.get("side",""))=="player" else "player"; var layers_key: String="db_toxic_spikes_"+enemy_side
            set_meta(layers_key,mini(int(mechanic.get("max_layers",2)),int(get_meta(layers_key,0))+1)); return 3.0
        "db_clear_allied_hazards": set_meta("db_toxic_spikes_"+str(actor.get("side","")),0); return 1.0
        "db_berry_interaction": return 0.0
        "db_atb_pause": push_error("ATB-Pause ist in der Datenbank semantisch definiert, aber die Status→Dauer-Kalibrierung fehlt."); return 0.0
        _:
            if kind.begins_with("db_"): push_error("Nicht implementierte Datenbank-Mechanik: "+kind); return 0.0
    if _database_positive_modifier_is_blocked(target, mechanic):
        _spawn_feedback_label(target,"⛔ BUFF BLOCKIERT",Color("e6b3b3")); return 0.0
    return super._effect(actor,target,mechanic)

func _database_apply_status(target: Dictionary, mechanic: Dictionary) -> float:
    if randf()>float(mechanic.get("chance",1.0)): return 0.0
    var status_id: String=str(mechanic.get("status",""))
    if _database_status_is_blocked(target,status_id): return 0.0
    if status_id=="sleep":
        if not str(target.get("major_status","")).is_empty(): return 0.0
        target["major_status"]="sleep"; target["db_sleep_actions"]=randi_range(1,3); return 4.0
    if status_id=="freeze":
        push_warning("Gefrieren wurde ausgelöst, aber eine zentrale Gefrier-Statusregel fehlt; Effekt wird nicht angewendet."); return 0.0
    return 0.0

func _database_status_is_blocked(target: Dictionary, status_id: String) -> bool:
    var immunities_value: Variant=target.get("db_status_immunities",[])
    if not (immunities_value is Array): return false
    var current_action: int=int(target.get("action_serial",0)); var remaining: Array=[]; var blocked: bool=false
    for immunity_value: Variant in immunities_value:
        if not (immunity_value is Dictionary): continue
        var immunity: Dictionary=immunity_value
        if current_action>=int(immunity.get("expires_after_action",0)): continue
        remaining.append(immunity); var status: String=str(immunity.get("status",""))
        if status=="major_status" or status==status_id: blocked=true
    target["db_status_immunities"]=remaining; return blocked

func _database_positive_modifier_is_blocked(target: Dictionary, mechanic: Dictionary) -> bool:
    if int(target.get("action_serial",0))>=int(target.get("db_block_positive_expires",0)): return false
    var kind: String=str(mechanic.get("kind","")); var factor: float=float(mechanic.get("multiplier_from_special",0.0))
    return (kind=="outgoing_damage_mod" and factor>0.0) or (kind=="incoming_damage_mod" and factor<0.0) or (kind=="accuracy_mod" and factor>0.0) or (kind=="atb_cycle_mod" and factor<0.0)

func _database_remove_positive_modifiers(target: Dictionary) -> void:
    var modifiers_value: Variant=target.get("timed_modifiers",[]); if not (modifiers_value is Array): return
    var kept: Array=[]
    for modifier_value: Variant in modifiers_value:
        if not (modifier_value is Dictionary): continue
        var modifier: Dictionary=modifier_value; var kind: String=str(modifier.get("kind","")); var mult: float=float(modifier.get("multiplier",1.0))
        var positive: bool=(kind=="outgoing_damage_mod" and mult>1.0) or (kind=="incoming_damage_mod" and mult>1.0) or (kind=="accuracy_mod" and mult>1.0) or (kind=="atb_cycle_mod" and mult<1.0)
        if not positive: kept.append(modifier)
    target["timed_modifiers"]=kept

func _damage(actor: Dictionary, target: Dictionary, power: int, move_type: String, category: String) -> int:
    var original_special: Variant=actor.get("special",0)
    if category=="special": actor["special"]=actor.get("attack",original_special)
    var damage: int=super._damage(actor,target,power,move_type,category); actor["special"]=original_special
    if damage<=0: return damage
    if category=="special" and _database_light_screen_is_active(target):
        damage=maxi(1,int(round(float(damage)*(1.0-clampf(float(target.get("db_light_screen_reduction",0.0)),0.0,0.5)))))
    return damage

func _database_light_screen_is_active(target: Dictionary) -> bool:
    var source_id: String=str(target.get("db_light_screen_source_id","")); if source_id.is_empty(): return false
    for candidate_value: Variant in combatants:
        if candidate_value is Dictionary:
            var candidate: Dictionary=candidate_value
            if str(candidate.get("id",""))==source_id: return bool(candidate.get("alive",false)) and int(candidate.get("action_serial",0))<int(target.get("db_light_screen_expires_source_action",0))
    return false

func _move_tooltip(move: Dictionary) -> String:
    var base: String=super._move_tooltip(move); var description: String=str(move.get("description","")).strip_edges(); var emoji: String=str(move.get("emoji","")); var source_effect: String=str(move.get("effect_source","")).strip_edges(); var extra: Array[String]=[]
    if not emoji.is_empty() or not description.is_empty(): extra.append((emoji+" "+description).strip_edges())
    if not source_effect.is_empty(): extra.append("Datenbank-Effekt: "+source_effect)
    return base if extra.is_empty() else base+"\n"+"\n".join(extra)
