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
