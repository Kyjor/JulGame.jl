# (Ptr, Float64, Float64) miscompiles: stores through %rsi and also to (%rdi).
# Pass float bits as Int64 (same pattern as animator Int32 time).
function static_add_velocity(rigidbody::Ptr{Cvoid}, x_bits::Int64, y_bits::Int64)
    if rigidbody == C_NULL
        return
    end

    rb = Ptr{RigidbodyLayout}(rigidbody)
    x::Float64 = reinterpret(Float64, x_bits)
    y::Float64 = reinterpret(Float64, y_bits)
    v = rb.velocity
    rb.velocity = Vector2f(v.x + x, v.y + y)

    if y < 0.0
        rb.grounded = false
        parent_ptr::Ptr{Cvoid} = rb.parent
        if !ptr_is_julia_nothing(parent_ptr)
            ent = Ptr{EntityLayout}(parent_ptr)
            collider::Ptr{Cvoid} = ent.collider
            if !ptr_is_julia_nothing(collider)
                col = Ptr{ColliderLayout}(collider)
                array_empty!(col.currentRests)
            end
        end
    end
    return
end

# dt_bits / gravity_bits are Float64 bit patterns. Writes velocity, acceleration,
# and transform.position in place (no struct return).
function static_apply_forces(rigidbody::Ptr{Cvoid}, dt_bits::Int64, gravity_bits::Int64)
    if rigidbody == C_NULL
        return
    end

    rb = Ptr{RigidbodyLayout}(rigidbody)
    dt::Float64 = reinterpret(Float64, dt_bits)
    gravity::Float64 = reinterpret(Float64, gravity_bits)
    v = rb.velocity
    a = rb.acceleration
    drag::Float64 = rb.drag
    mass::Float64 = rb.mass
    half::Float64 = Float64(0.5)
    gy::Float64 = Float64(0.0)
    if rb.useGravity
        gy = gravity
    end

    nax::Float64 = Float64(0.0) - (half * drag * (v.x * v.x)) / mass
    nay::Float64 = gy - (half * drag * (v.y * v.y)) / mass
    vm_y::Float64 = Float64(1.0)
    if rb.grounded
        vm_y = Float64(0.0)
    end

    parent_ptr::Ptr{Cvoid} = rb.parent
    if !ptr_is_julia_nothing(parent_ptr)
        ent = Ptr{EntityLayout}(parent_ptr)
        transform_ptr::Ptr{Cvoid} = ent.transform
        if !ptr_is_julia_nothing(transform_ptr)
            tf = Ptr{TransformLayout}(transform_ptr)
            pos = tf.position
            npy::Float64 = pos.y + v.y * dt + a.y * (dt * dt * half)
            if rb.grounded
                npy = pos.y
            end
            tf.position = Vector3f(pos.x + v.x * dt + a.x * (dt * dt * half), npy, pos.z)
        end
    end

    rb.velocity = Vector2f(
        (v.x + (a.x + nax) * (dt * half)) * Float64(1.0),
        (v.y + (a.y + nay) * (dt * half)) * vm_y,
    )
    rb.acceleration = Vector2f(nax, nay)
    return
end
