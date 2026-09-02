extends Node

# Central mobile-friendly scrolling for every UI surface created at runtime.
# ScrollContainer already implements native touch dragging in Godot. We only
# give it a small deadzone so a tap on a child Button stays a tap, while a real
# finger swipe becomes scrolling. RichTextLabel has an internal scrollbar but
# no ScrollContainer-style content drag, so we add the same gesture there.

const TOUCH_SCROLL_DEADZONE: float = 10.0
const TOUCH_SCROLL_DEADZONE_INT: int = 10
const TOUCH_SCROLL_META: StringName = &"timeflow_touch_scroll_connected"

var _rich_touch_state: Dictionary = {}


func _ready() -> void:
    var tree: SceneTree = get_tree()
    if not tree.node_added.is_connected(_on_node_added):
        tree.node_added.connect(_on_node_added)
    call_deferred("_configure_existing_tree")


func _exit_tree() -> void:
    var tree: SceneTree = get_tree()
    if tree != null and tree.node_added.is_connected(_on_node_added):
        tree.node_added.disconnect(_on_node_added)
    _rich_touch_state.clear()


func _configure_existing_tree() -> void:
    var tree: SceneTree = get_tree()
    if tree == null or tree.root == null:
        return
    _configure_subtree(tree.root)


func _on_node_added(node: Node) -> void:
    # Runtime UIs build most controls after their parent was added. Defer one
    # turn so their child hierarchy exists, then configure the whole new branch.
    call_deferred("_configure_subtree_if_valid", node)


func _configure_subtree_if_valid(node: Node) -> void:
    if node == null or not is_instance_valid(node):
        return
    _configure_subtree(node)


func _configure_subtree(node: Node) -> void:
    _configure_node(node)
    for child: Node in node.get_children():
        _configure_subtree(child)


func _configure_node(node: Node) -> void:
    if node is ScrollContainer:
        var scroll: ScrollContainer = node as ScrollContainer
        scroll.scroll_deadzone = TOUCH_SCROLL_DEADZONE_INT
        return

    if node is RichTextLabel:
        _configure_rich_text(node as RichTextLabel)


func _configure_rich_text(label: RichTextLabel) -> void:
    if label.has_meta(TOUCH_SCROLL_META):
        return
    label.set_meta(TOUCH_SCROLL_META, true)
    label.gui_input.connect(_on_rich_text_gui_input.bind(label))


func _on_rich_text_gui_input(event: InputEvent, label: RichTextLabel) -> void:
    if label == null or not is_instance_valid(label) or not label.scroll_active:
        return

    var label_id: int = label.get_instance_id()

    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event as InputEventScreenTouch
        if touch.pressed:
            _rich_touch_state[label_id] = {
                "index": touch.index,
                "distance": 0.0,
                "dragging": false
            }
            return

        var release_state_value: Variant = _rich_touch_state.get(label_id, {})
        if release_state_value is Dictionary:
            var release_state: Dictionary = release_state_value as Dictionary
            if int(release_state.get("index", -1)) == touch.index:
                if bool(release_state.get("dragging", false)):
                    # A swipe must not become a click/meta activation on release.
                    label.accept_event()
                _rich_touch_state.erase(label_id)
        return

    if not (event is InputEventScreenDrag):
        return

    var drag: InputEventScreenDrag = event as InputEventScreenDrag
    var state_value: Variant = _rich_touch_state.get(label_id, {})
    if not (state_value is Dictionary):
        return
    var state: Dictionary = state_value as Dictionary
    if int(state.get("index", -1)) != drag.index:
        return

    var distance: float = float(state.get("distance", 0.0)) + drag.relative.length()
    state["distance"] = distance
    if not bool(state.get("dragging", false)):
        if distance < TOUCH_SCROLL_DEADZONE:
            _rich_touch_state[label_id] = state
            return
        state["dragging"] = true

    var scrollbar: VScrollBar = label.get_v_scroll_bar()
    if scrollbar == null:
        _rich_touch_state[label_id] = state
        return

    var maximum_scroll: float = maxf(scrollbar.min_value, scrollbar.max_value - scrollbar.page)
    if maximum_scroll <= scrollbar.min_value:
        _rich_touch_state[label_id] = state
        return

    scrollbar.value = clampf(
        scrollbar.value - drag.relative.y,
        scrollbar.min_value,
        maximum_scroll
    )
    _rich_touch_state[label_id] = state
    label.accept_event()
