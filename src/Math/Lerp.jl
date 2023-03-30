function Lerp(a, b, t)
    t = min(1, t)
    t = max(0, t)
    return ((b-a) * t) + a
end
