function start_simulation_thread(
        threads::NTuple{N_THREADS, ComputationThread},
        mesh::SimulationMesh,
        parameters::Parameters,
        gui::GUI,
        compsync::Synchronizer,
        globsync::Synchronizer
    )
    ID = synchronize(compsync)
    while !parameters.state.terminate

        if !parameters.state.pause
            insert_particles(threads[ID], mesh, parameters)
            move_particles(threads[ID], mesh, parameters)
            calculate_moments(threads[ID])

            synchronize(compsync)

            calculate_macros(mesh, threads, parameters, ID)

            if parameters.state.collisions
                synchronize(compsync)

                collide_particles(threads[ID], mesh)
                calculate_moments(threads[ID])

                synchronize(compsync)

                calculate_ratio(mesh, threads, parameters, ID)

                synchronize(globsync)

                correct_velocity(threads[ID], mesh)
            else
                synchronize(globsync)
            end
        else
            synchronize(globsync)
        end
        ID == 1 && get_gui_data(mesh, parameters, gui)
        synchronize(globsync)
        if parameters.state.reset
            ID == 1 && reset!(mesh)
            reset!(threads[ID])
            synchronize(compsync)
        end
    end
end


function get_gui_data(mesh, parameters, gui::GUI)
    parameters.state.pause = gui.pause
    parameters.state.reset = gui.reset
    parameters.state.terminate = gui.terminate
    parameters.state.collisions = gui.toggle.active[]
    parameters.state.wallcoeff = gui.wallcoeff

    set_condition!(parameters.inflow, gui.density, gui.velocity)

    if !isnan(gui.new_wall[1])
        addwall!(mesh, gui.new_wall...)
    end

    return nothing
end