"""
Needs: ComputationThread, SimulationMesh, Parameters

Functions:
    move_particles(thread::ComputationThread, mesh::SimulationMesh, parameters::Parameters)
        collide!(particle::Particle, wall::Wall)
        isoutside(particle::Particle, mesh::SimMesh) -> true/false
        rangeup(a, b) -> UnitRange
"""

function move_particles(thread::ComputationThread, mesh::SimulationMesh, parameters::Parameters)
    Nx, Ny = mesh.n_cells
    # Loop in reverse direction:
    # When a particle is removed, it is swapped with the particle at the last index
    # By then, the last particle must have been checked already!
    for i in thread.n_particles[]:-1:1
        particle = thread.particles[i]

        lastwall = nothing
        dt = parameters.timestep
        for _ in 1:1000 # Tunnel, if we hit more than 1000 walls
            fraction = 1.0
            wall = nothing

            # Path of particle
            path = Line(particle.position, dt * Point2{Float64}(particle.velocity))
            newpos = path.point + path.vector

            # Find next wall that is hit
            ax, ay = particle.index
            bx, by = newindex = index(newpos, particle.index, mesh)

            # a. Loop over all cells in question
            for x in rangeup(ax, bx), y in rangeup(ay, by)
                (x < 1 || y < 1 || x > Nx || y > Ny) && continue
                cell = mesh.cells[x, y]

                # b. Loop over all walls in each cell
                for j in 1:cell.n_walls # TODO UnitRange is slow here, store it in cell?
                    locwall = cell.walls[j]

                    # c. get the interection with the wall and the path
                    locfraction = intersect(path, locwall.line)
                    if !isnothing(locfraction) && locfraction < fraction && locwall != lastwall
                        fraction = locfraction
                        wall = locwall
                    end
                end
            end


            if isnothing(wall)
                particle.position = newpos
                particle.index = newindex
                break
            end
            particle.position += path.vector * fraction
            dt = (1 - fraction) * dt
            if rand() > parameters.state.wallcoeff
                collide!(particle, wall, 600, parameters.mass) # hard coded 600 TODO make it adjustable
            else
                collide!(particle, wall)
            end
            lastwall = wall
        end

        isoutside(particle, mesh) && remove_particle!(thread, i)
    end
    return nothing
end


function collide!(particle::Particle, wall::Wall)
    normal_velocity = dot(particle.velocity, wall.normal)
    particle.velocity -= 2 * normal_velocity * wall.normal
end


function collide!(particle::Particle, wall, temperature, mass)
    most_probable_velocity = √(2 * BOLTZMANN_CONST * temperature / mass)
    v1 = most_probable_velocity * √(-log(rand()))
    v2 = √0.5 * most_probable_velocity * randn()
    if particle.velocity[1] * wall.normal[1] + particle.velocity[2] * wall.normal[2] > 0
        v1 = -v1
    end
    vx = v1 * wall.normal[1] - v2 * wall.normal[2]
    vy = v1 * wall.normal[2] + v2 * wall.normal[1]
    vz = √0.5 * most_probable_velocity * randn()

    particle.velocity = Vec3{Float64}(vx, vy, vz)
end



function isoutside(particle::Particle, mesh::SimulationMesh)
    ix, iy = particle.index
    nx, ny = mesh.n_cells

    return !(1<=ix<=nx && 1<=iy<=ny)
end