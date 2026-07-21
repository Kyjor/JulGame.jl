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
        # TODO: Implement collider.currentRests = []
        # parent.collider.currentRests = [] needs alloc — leave in Julia if required
    end
    return
end
