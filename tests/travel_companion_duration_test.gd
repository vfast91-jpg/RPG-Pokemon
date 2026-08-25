extends SceneTree

const RouteScript = preload("res://scripts/demo_route_travel_companion_duration_v1.gd")

var failures: Array[String] = []


func _init() -> void:
    _test_initial_duration_and_single_stage_tick()
    _test_same_stage_never_ticks_twice()
    _test_departure_after_thirty_completed_stages()
    _test_staggered_companions_leave_independently()
    _test_existing_duration_is_never_reset()
    _test_pending_companion_starts_with_full_duration()

    if failures.is_empty():
        print("PASS: travel companion duration tests")
        quit(0)
        return

    for failure: String in failures:
        push_error(failure)
    quit(1)


func _new_route() -> Node:
    return RouteScript.new()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _test_initial_duration_and_single_stage_tick() -> void:
    var route: Node = _new_route()
    route.team = [{"name": "Pikachu"}]

    var departed: Array[String] = route._advance_companion_durations_to_stage(1)
    _expect(departed.is_empty(), "Stage 1 must not remove a new companion.")
    _expect(int(route.team[0].get("travel_stages_remaining", -1)) == 30, "A new companion must start at 30 stages.")

    departed = route._advance_companion_durations_to_stage(2)
    _expect(departed.is_empty(), "Entering stage 2 must not remove the companion.")
    _expect(int(route.team[0].get("travel_stages_remaining", -1)) == 29, "Completing stage 1 must consume exactly one stage.")
    route.free()


func _test_same_stage_never_ticks_twice() -> void:
    var route: Node = _new_route()
    route.team = [{"name": "Bisasam", "travel_stages_remaining": 12}]
    route._companion_duration_checkpoint_stage = 8

    route._advance_companion_durations_to_stage(8)
    route._advance_companion_durations_to_stage(8)
    _expect(int(route.team[0].get("travel_stages_remaining", -1)) == 12, "Repeated UI redraws on one stage must not consume duration.")
    route.free()


func _test_departure_after_thirty_completed_stages() -> void:
    var route: Node = _new_route()
    route.team = [{"name": "Glumanda"}]

    route._advance_companion_durations_to_stage(1)
    var departed: Array[String] = route._advance_companion_durations_to_stage(30)
    _expect(departed.is_empty(), "A starter must still be present during stage 30.")
    _expect(int(route.team[0].get("travel_stages_remaining", -1)) == 1, "A starter must have one shared stage left on stage 30.")

    departed = route._advance_companion_durations_to_stage(31)
    _expect(departed == ["Glumanda"], "A starter must leave when entering stage 31 after 30 completed stages.")
    _expect(route.team.is_empty(), "Expired companion must be removed from the team.")
    route.free()


func _test_staggered_companions_leave_independently() -> void:
    var route: Node = _new_route()
    route.team = [
        {"name": "Schiggy", "travel_stages_remaining": 1},
        {"name": "Pikachu", "travel_stages_remaining": 7}
    ]
    route._companion_duration_checkpoint_stage = 20

    var departed: Array[String] = route._advance_companion_durations_to_stage(21)
    _expect(departed == ["Schiggy"], "Only the companion whose duration reaches zero may leave.")
    _expect(route.team.size() == 1, "One non-expired companion must remain.")
    _expect(str(route.team[0].get("name", "")) == "Pikachu", "The correct staggered companion must remain.")
    _expect(int(route.team[0].get("travel_stages_remaining", -1)) == 6, "Remaining companions must tick down by the same completed stage.")
    route.free()


func _test_existing_duration_is_never_reset() -> void:
    var route: Node = _new_route()
    var member: Dictionary = {"name": "Evoli", "travel_stages_remaining": 9}
    route._ensure_member_companion_duration(member)
    _expect(int(member.get("travel_stages_remaining", -1)) == 9, "Existing duration must survive evolution/save-style dictionary updates.")
    route.free()


func _test_pending_companion_starts_with_full_duration() -> void:
    var route: Node = _new_route()
    route.pending_capture = {"name": "Abra"}
    route._ensure_pending_companion_duration()
    _expect(int(route.pending_capture.get("travel_stages_remaining", -1)) == 30, "A newly found pending companion must receive 30 stages before joining.")
    route.free()
