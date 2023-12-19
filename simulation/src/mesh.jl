"""
Needs: Line, rangeup


Constructors:
    SimulationMesh(n_cells, length, cellsize, cells) -> SimulationMesh
    Wall(a::Point2f, b::Point2f)


Functions:
    N_walls_per_cell(mesh::SimulationMesh) -> Int64
    reset!(mesh::SimulationMesh)
    index(point, mesh::SimulationMesh) -> NTuple{2, Int64}
    index(point, oldindex, mesh::SimulationMesh) -> NTuple{2, Int64}
    addwall!(mesh::SimulationMesh, a::Point2f, b::Point2f)

"""
struct Wall
    line :: Line
    normal :: Vec3{Float64}
end
function Wall(a, b)
    line = Line(a, b - a)
    length = √((b[1] - a[1])^2 + (b[2] - a[2])^2)
    normal = Vec3{Float64}((a[2] - b[2]) / length, (b[1] - a[1]) / length, 0)
    return Wall(line, normal)
end


mutable struct Cell
    walls :: Vector{Wall}
    n_walls :: Int64

    density :: Float64
    velocity :: Point3{Float64}
    temperature :: Float64
    collision_probability :: Float64
    most_probable_velocity :: Float64
    ratio :: Float64
    new_velocity :: Point3{Float64}
end
Cell(max_walls) = Cell(Vector{Wall}(undef, max_walls), 0, 0, Point3{Float64}(0), 0, 0, 0, 0, Point3{Float64}(0))


struct SimulationMesh
    n_cells :: NTuple{2, Int64}
    length :: NTuple{2, Float64}
    cellsize :: NTuple{2, Float64}

    cells :: Matrix{Cell}
    max_walls :: Int64
end
SimulationMesh(length::NTuple, n_cells::NTuple, max_walls) = SimulationMesh(
        n_cells,
        length,
        length ./ n_cells,
        [Cell(max_walls) for i in 1:n_cells[1], j in 1:n_cells[2]],
        max_walls
)


N_walls_per_cell(mesh::SimulationMesh) = size(mesh.walls, 3)


function reset!(mesh::SimulationMesh)
    for cell in mesh.cells
        cell.n_walls = 0
    end
end


function index(point, mesh::SimulationMesh)
    p1, p2 = point
    s1, s2 = mesh.cellsize
    return (ceil(Int64, p1 / s1), ceil(Int64, p2 / s2))
end


function index(point, oldindex, mesh::SimulationMesh)
    px, py = point
    ox, oy = oldindex
    sx, sy = mesh.cellsize

    vx = ox * sx
    vy = oy * sy
    dx=ox
    dy=oy
    while(vx<px)
        vx += sx
        dx +=1
    end
    vx -= sx
    while(vx>px)
        vx -= sx
        dx -= 1
    end
    while(vy<py)
        vy += sy
        dy +=1
    end
    vy -= sy
    while(vy>py)
        vy -= sy
        dy -= 1
    end

    return dx, dy
end


function addwall!(mesh::SimulationMesh, a, b)
    wall = Wall(a, b)

    # Add the new wall to the cell list
    Nx, Ny = mesh.n_cells
    ax, ay = index(a, mesh)
    bx, by = index(b, mesh)#index(b, (ax, ay), mesh)
    rx = ax < bx ? range(ax-1,bx+1) : range(bx-1,ax+1) #rangeup(ax, bx)
    ry = ay < by ? range(ay-1,by+1) : range(by-1,ay+1) #rangeup(ay, by)
    for x in rx, y in ry
        (x < 1 || y < 1 || x > Nx || y > Ny) && continue
        cell = mesh.cells[x, y]
        cell.n_walls >= mesh.max_walls && continue

        cell.n_walls += 1
        cell.walls[cell.n_walls] = wall
    end
end

