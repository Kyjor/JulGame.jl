function static_play_animation_once(animator::Ptr{Cvoid}, animation_index::Int32)
    if animator == C_NULL
        return
    end

    a = Ptr{AnimatorLayout}(animator)
    animations = a.animations
    if array_isempty(animations)
        return
    end

    n = array_length(animations)
    if animation_index < Int32(1) || Int64(animation_index) > n
        printf(c"Animation index out of bounds\n")
        return
    end

    data = array_data(Ptr{Cvoid}, animations)
    a.current_animation = unsafe_load(data, Int64(animation_index))
    a.play_once = true
    a.last_frame = Int64(1)
    return
end

function static_force_frame_update(animator::Ptr{Cvoid}, frame_index::Int32)
    if animator == C_NULL
        return
    end

    a = Ptr{AnimatorLayout}(animator)
    current_animation = a.current_animation
    if ptr_is_julia_nothing(current_animation)
        return
    end

    sprite = a.sprite
    if ptr_is_julia_nothing(sprite)
        return
    end

    anim = Ptr{AnimationLayout}(current_animation)

    # if !isempty(framePaths) → imagePath = framePaths[i]
    # Skipped for now: String assign needs write barrier + load_image.
    # frame_paths = anim.frame_paths
    # if !array_isempty(frame_paths)
    #     # TODO: sprite.imagePath = frame_paths[frame_index]
    # end

    frames = anim.frames
    if !array_isempty(frames)
        n = array_length(frames)
        if frame_index >= Int32(1) && Int64(frame_index) <= n
            data = array_data(Vector4i32, frames)
            crop = unsafe_load(data, Int64(frame_index))
            unsafe_store!(Ptr{Vector4i32}(Ptr{UInt8}(sprite) + SPRITE_CROP_OFF), crop)
            unsafe_store!(Ptr{UInt8}(Ptr{UInt8}(sprite) + SPRITE_CROP_TAG_OFF), UNION_TAG_VECTOR4)
        end
    end

    a.last_frame = Int64(frame_index)
    return
end

# Use (Ptr, Int32) like play/force_frame — StaticCompiler miscompiles Ptr+Float64/UInt64
# (loads animator fields from %rsi, which is the integer/time arg, not the pointer).
function static_update(animator::Ptr{Cvoid}, current_render_time::Int32)
    if animator == C_NULL
        return
    end

    a = Ptr{AnimatorLayout}(animator)
    current_animation = a.current_animation
    sprite = a.sprite
    anim = Ptr{AnimationLayout}(current_animation)
    if ptr_is_julia_nothing(current_animation) || anim.animated_fps < Int32(1) || ptr_is_julia_nothing(sprite)
        return
    end

    frames = anim.frames
    frame_paths = anim.frame_paths
    # Match Julia: prefer framePaths length when non-empty, else frames
    frame_count::Int64 = array_isempty(frame_paths) ?
        (array_isempty(frames) ? Int64(0) : array_length(frames)) :
        array_length(frame_paths)
    if frame_count == Int64(0) || (a.play_once && a.last_frame == frame_count)
        return
    end

    t::UInt64 = UInt64(reinterpret(UInt32, current_render_time))
    delta_time::Float64 = Float64(t - a.last_update) / 1000.0
    fps_time::Float64 = 1.0 / Float64(anim.animated_fps)
    frames_to_update::Int64 = unsafe_trunc(Int64, delta_time / fps_time)

    last_frame::Int64 = a.last_frame
    if last_frame == Int64(0)
        last_frame = Int64(1)
        a.last_update = t
    elseif frames_to_update > Int64(0)
        last_frame = last_frame + frames_to_update
        a.last_update = t
    end

    if last_frame > frame_count
        if a.play_once
            last_frame = frame_count
        else
            # ((last_frame - 1) % frame_count) + 1
            last_frame = ((last_frame - Int64(1)) % frame_count) + Int64(1)
        end
    end
    if last_frame == Int64(0)
        last_frame = Int64(1)
    end
    a.last_frame = last_frame

    if !array_isempty(frames) && last_frame >= Int64(1) && last_frame <= frame_count
        data = array_data(Vector4i32, frames)
        crop = unsafe_load(data, last_frame)
        unsafe_store!(Ptr{Vector4i32}(Ptr{UInt8}(sprite) + SPRITE_CROP_OFF), crop)
        unsafe_store!(Ptr{UInt8}(Ptr{UInt8}(sprite) + SPRITE_CROP_TAG_OFF), UNION_TAG_VECTOR4)
    end
    return
end