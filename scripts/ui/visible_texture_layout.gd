extends RefCounted

# Maps the non-transparent pixels of a KEEP_ASPECT_CENTERED TextureRect into
# local control coordinates. Battle sprites can then be aligned by what the
# player sees instead of by inconsistent transparent PNG margins.

static var _used_rect_cache: Dictionary = {}


static func visible_rect(sprite: TextureRect) -> Rect2:
    var fallback := Rect2(Vector2.ZERO, sprite.size)
    var texture: Texture2D = sprite.texture
    if texture == null:
        return fallback

    var texture_size: Vector2 = texture.get_size()
    if texture_size.x <= 0.0 or texture_size.y <= 0.0:
        return fallback

    var scale: float = minf(
        sprite.size.x / texture_size.x,
        sprite.size.y / texture_size.y
    )
    if scale <= 0.0:
        return fallback

    var rendered_size: Vector2 = texture_size * scale
    var rendered_offset: Vector2 = (sprite.size - rendered_size) * 0.5
    # Reading a CompressedTexture2D back into an Image is comparatively costly.
    # Boss formations ask for these bounds on every card refresh, so cache the
    # source-space alpha rectangle once per imported texture instead of doing a
    # full image readback several times per rendered frame.
    var used_rect: Rect2i = _used_rect_for_texture(texture, texture_size)
    if used_rect.size.x <= 0 or used_rect.size.y <= 0:
        return Rect2(rendered_offset, rendered_size)

    var used_x: float = float(used_rect.position.x)
    if sprite.flip_h:
        used_x = texture_size.x - float(used_rect.end.x)

    return Rect2(
        rendered_offset + Vector2(used_x, float(used_rect.position.y)) * scale,
        Vector2(used_rect.size) * scale
    )


static func position_visible_right_of_card(
    area_size: Vector2,
    card_rect: Rect2,
    local_visible_rect: Rect2,
    gap: float
) -> Vector2:
    var desired_y: float = card_rect.get_center().y - local_visible_rect.get_center().y
    var min_y: float = -local_visible_rect.position.y
    var max_y: float = area_size.y - local_visible_rect.end.y
    if min_y <= max_y:
        desired_y = clampf(desired_y, min_y, max_y)

    return Vector2(
        card_rect.end.x + gap - local_visible_rect.position.x,
        desired_y
    )


static func enemy_connector_points(
    card_rect: Rect2,
    sprite_position: Vector2,
    local_visible_rect: Rect2
) -> PackedVector2Array:
    return PackedVector2Array([
        Vector2(card_rect.end.x, card_rect.get_center().y),
        sprite_position + Vector2(
            local_visible_rect.position.x,
            local_visible_rect.get_center().y
        )
    ])


static func visible_foot(sprite_position: Vector2, local_visible_rect: Rect2) -> Vector2:
    return sprite_position + Vector2(
        local_visible_rect.get_center().x,
        local_visible_rect.end.y
    )


static func enemy_forehead_anchor(
    sprite_position: Vector2,
    local_visible_rect: Rect2
) -> Vector2:
    # Enemy sprites face toward the player (right). The anchor follows the
    # visible alpha bounds, so compact and tall Pokemon both receive the anger
    # symbol near the front of the forehead rather than above the box centre.
    return sprite_position + local_visible_rect.position + Vector2(
        local_visible_rect.size.x * 0.66,
        local_visible_rect.size.y * 0.19
    )


static func _used_rect_for_texture(texture: Texture2D, texture_size: Vector2) -> Rect2i:
    var cache_key: String = texture.resource_path
    if cache_key.is_empty():
        cache_key = "instance:%d" % texture.get_instance_id()
    cache_key += "|%dx%d" % [int(texture_size.x), int(texture_size.y)]

    var cached_value: Variant = _used_rect_cache.get(cache_key, null)
    if cached_value is Rect2i:
        return cached_value as Rect2i

    var fallback := Rect2i(Vector2i.ZERO, Vector2i(texture_size))
    var image: Image = texture.get_image()
    if image == null or image.is_empty():
        _used_rect_cache[cache_key] = fallback
        return fallback

    var used_rect: Rect2i = image.get_used_rect()
    if used_rect.size.x <= 0 or used_rect.size.y <= 0:
        used_rect = fallback
    _used_rect_cache[cache_key] = used_rect
    return used_rect
