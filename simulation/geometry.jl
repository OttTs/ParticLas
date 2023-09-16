struct Line
    point :: Point2{Float64}
    vector :: Vec2{Float64}
end


"""
    intersect(a::Line, b::Line)

Calculates, line a intersects line b.
If they intersect, returns the fraction of the length of line a, where the intersection occurs.
Otherwise, returns nothing
"""
function intersect(a::Line, b::Line)::Union{Nothing, Float64}
    cross(a.vector, b.vector) == 0 && return nothing
    t = (cross(b.point, a.vector) - cross(a.point, a.vector)) / cross(a.vector, b.vector)
    (t < 0 || t > 1) && return nothing
    u = (cross(b.point, b.vector) - cross(a.point, b.vector)) / cross(a.vector, b.vector)
    (u < 0 || u > 1) && return nothing
    return u
end


rangeup(a, b) = a < b ? range(a,b) : range(b,a)