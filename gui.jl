const LANG_ENGLISH = true # Set true to use english labels, otherwise german

if LANG_ENGLISH
    const STRING_ParticLas = "ParticLas"
    const STRING_HEIGHT = "Height"
    const STRING_PARTICLE = "Particles"
    const STRING_VELOCITY = "Velocity"
    const STRING_DENSITY = "Density"
    const STRING_TEMPERATURE = "Temperature"
    const STRING_CONDITIONS = "Conditions"
    const STRING_DOCOLLISIONS = "Particle collisions"
    const STRING_WALLINTERACTION = "Wall interaction"
    const STRING_DIFFUSE = "Diffuse"
    const STRING_REFLECTIVE = "Reflective"
    const STRING_VIEW = "View"
else
    const STRING_ParticLas = "ParticLas"
    const STRING_HEIGHT = "Flughöhe"
    const STRING_PARTICLE = "Partikel"
    const STRING_VELOCITY = "Geschwindigkeit"
    const STRING_DENSITY = "Dichte"
    const STRING_TEMPERATURE = "Temperatur"
    const STRING_CONDITIONS = "Bedingungen"
    const STRING_DOCOLLISIONS = "Teilchenkollisionen"
    const STRING_WALLINTERACTION = "Wandinteraktion"
    const STRING_DIFFUSE = "Diffus"
    const STRING_REFLECTIVE = "Reflektierend"
    const STRING_VIEW = "Darstellung"
end

const STRING_PLAY = "Play"
const STRING_PAUSE = "Pause"


const DEFAULT_VIEW = STRING_PARTICLE
const DEFAULT_HEIGHT = 100.0
const DEFAULT_VELOCITY = 10000.0

const MENU_WIDTH = 1/5
#const MENU_COLOR = RGBf(0.2, 0.2, 0.2)
const FPS = 60
const MAX_LINE_LENGTH = 5


mutable struct GUI
    points :: Observable{Vector{Point2f}}
    cellvalue :: Observable{Matrix{Float64}}
    celllimits :: Observable{NTuple{2, Float64}}
    view :: Observable{String}
    lines :: Observable{Vector{Point2f}}
    line_index :: Int64

    density :: Float64
    velocity :: Float64

    new_wall :: NTuple{2, Point2{Float64}}

    drawing :: Bool
    cursor :: Bool

    pause :: Bool
    reset :: Bool
    terminate :: Bool
    toggle :: Union{Nothing, Toggle}
    wallcoeff :: Float64
end
GUI(number_of_points::Number, number_of_cells::NTuple{2, Integer}, maximum_lines::Number) = GUI(
    Observable([Point2f(NaN) for _ in 1:number_of_points]),
    Observable(zeros(Float64, number_of_cells)),
    Observable((0., 0.)),
    Observable(DEFAULT_VIEW),
    Observable([Point2f(NaN) for _ in 1:(3 * maximum_lines)]),
    0,
    airdensity(DEFAULT_HEIGHT),
    DEFAULT_VELOCITY,
    (Point2{Float64}(NaN), Point2{Float64}(NaN)),
    false, false, true, false, false,
    nothing,
    0
)

function setup(gui::GUI)
    scene = Scene()
    campixel!(scene)

    setup_settings(scene, gui)
    resolution = setup_display(scene, gui)

    screen = GLMakie.Screen(scene; start_renderloop=false)#focus_on_show=true, float=true, start_renderloop=false)
    glscreen = screen.glscreen

    on(events(scene).keyboardbutton) do button
        if button.key == Keyboard.delete
            gui.terminate = true
        elseif button.key == Keyboard.space && button.action == Makie.Keyboard.press
            gui.cursor = !gui.cursor
            GLFW.SetInputMode(glscreen, GLFW.CURSOR,
                gui.cursor ? GLFW.CURSOR_NORMAL : GLFW.CURSOR_DISABLED)
        end
    end

    # Disable cursor
    #GLFW.SetInputMode(glscreen, GLFW.CURSOR, GLFW.CURSOR_DISABLED)

    # Fullscreen
    GLFW.make_fullscreen!(glscreen)

    return screen, resolution
end

function setup_display(scene::Scene, gui::GUI)
    px, py = 2 .* GLFW.standard_screen_resolution()
    resolution = ceil(Int64, px * (1 - MENU_WIDTH)), py
    area = Rect(0, 0, resolution...)

    window = Scene(
        scene,
        px_area=area,
        backgroundcolor=:white
    )

    campixel!(window)

    scatter!(
        window,
        @lift($(gui.points) .* resolution[2]),
        marker = GLMakie.FastPixel(),
        markersize = 4,
        color = :black,
        visible = @lift($(gui.view) == STRING_PARTICLE)
    )

    xs = range(0, resolution[1], length=140)
    ys = range(0, resolution[2], length=80) # TODO
    heatmap!(
        window,
        xs, ys,
        gui.cellvalue,
        interpolate = true,
        colormap = :afmhot,
        colorrange = gui.celllimits,
        visible = @lift($(gui.view) != STRING_PARTICLE)
    )


    lines!(
        window,
        gui.lines,
        linewidth = 3,
        color = (:blue, 0.5)
    )


    on(events(window).mouseposition) do position

        pressed = ispressed(window, Mouse.left)
        inside = isinside(position, resolution)
        drawing = gui.drawing

        if pressed && inside && drawing
            continuedrawing(gui, position, resolution[2])
        elseif pressed && inside && !drawing
            startdrawing(gui, position)
        elseif drawing && (!inside || !pressed)
            stopdrawing(gui, position, resolution[2])
        end
    end

    return resolution
end

function isinside(position, resolution)
    return 0 < position[1] < resolution[1] && 0 < position[2] < resolution[2]
end


function continuedrawing(gui, position, scaling)
    setpoint!(gui, position)

    start = gui.lines[][gui.line_index-1]
    stop = gui.lines[][gui.line_index]

    if norm(stop - start) > MAX_LINE_LENGTH
        gui.new_wall = gui.lines[][gui.line_index-1] / scaling,
                       gui.lines[][gui.line_index] / scaling
        pushpoint!(gui, position)
    end
    notify(gui.lines)
end


function startdrawing(gui, position)
    gui.drawing = true
    pushpoint!(gui, position)
    pushpoint!(gui, position)
    notify(gui.lines)
end


function stopdrawing(gui, position, scaling)
    gui.drawing = false
    gui.new_wall = gui.lines[][gui.line_index-1] / scaling,
                   gui.lines[][gui.line_index] / scaling
    pushpoint!(gui, Point2f(NaN))
    notify(gui.lines)
end


function setpoint!(gui::GUI, position)
    gui.lines[][gui.line_index] = position
end


function pushpoint!(gui::GUI, position)
    gui.line_index += 1
    gui.lines[][gui.line_index] = position
end


function setup_settings(scene::Scene, gui::GUI)
    px, py = 2 .* GLFW.standard_screen_resolution()
    area = Rect(floor(Int64, px * (1 - MENU_WIDTH)), 0, ceil(Int64, px * MENU_WIDTH), py)
    window = Scene(
        scene,
        px_area=area,
        clear=true,
        backgroundcolor=RGBf(0.8, 0.8, 0.8),
        camera=scene.camera
    )

    layout = GridLayout(window)
    layout.parent = scene

    Label(layout[0,1], STRING_ParticLas, fontsize=50, halign=:center)

    Label(layout[1,1], STRING_CONDITIONS, fontsize=20, halign=:left)

    slidergrid = SliderGrid(
        layout[2,1],
        width=trunc(Int64, 0.95*px*MENU_WIDTH),
        (label = STRING_HEIGHT,
            range = 80:1:120,
            format = "",
            startvalue = DEFAULT_HEIGHT,
            linewidth=trunc(Int64, 0.02*py)),
        (label = STRING_VELOCITY,
            range = 1000:10:20000,
            format = "",
            startvalue = DEFAULT_VELOCITY,
            linewidth=trunc(Int64, 0.02*py))
    )

    gui.toggle = Toggle(scene, active=true)
    layout[3, 1] = grid!(hcat(Label(scene, STRING_DOCOLLISIONS), gui.toggle), halign=:left)

    Label(layout[4,1], STRING_WALLINTERACTION, fontsize=20, halign=:left)
    wallsg = SliderGrid(
        layout[5,1],
        width=trunc(Int64, 0.95*px*MENU_WIDTH),
        (label = STRING_DIFFUSE,
            range = 0:0.1:1,
            format = STRING_REFLECTIVE,
            startvalue = 0.5,
            linewidth=trunc(Int64, 0.02*py))
    )

    Label(layout[6,1], STRING_VIEW, fontsize=20, halign=:left)

    menu = Menu(
        layout[7,1],
        dropdown_arrow_size = 40,
        options = [STRING_PARTICLE, STRING_DENSITY, STRING_VELOCITY, STRING_TEMPERATURE],
        default = DEFAULT_VIEW
    )

    buttonlabel = Observable(STRING_PLAY)
    playbutton = Button(
        layout[8, 1],
        label = buttonlabel,
        #buttoncolor = RGBf(0.2, 0.2, 0.2),
        #buttoncolor_hover = RGBf(0.2, 0.2, 0.2),
        #buttoncolor_active = RGBf(0.2, 0.2, 0.2),
        cornerradius = 4,
        cornersegments = 10,
        height=50,
        width=200
    )

    resetbutton =  Button(
        layout[9, 1],
        label = "Reset",
        #buttoncolor = RGBf(1., 0.6, 0.6),
        #buttoncolor_hover = RGBf(1., 0.8, 0.8),
        #buttoncolor_active = RGBf(1., 0.2, 0.2),
        cornerradius = 4,
        cornersegments = 10,
        height=50,
        width=200
    )

    closebutton = Button(
        layout[10, 1],
        label = "Close",
        buttoncolor = RGBf(1., 0.6, 0.6),
        buttoncolor_hover = RGBf(1., 0.8, 0.8),
        buttoncolor_active = RGBf(1., 0.2, 0.2),
        cornerradius = 4,
        cornersegments = 10,
        height=50,
        width=200
    )

    rowgap!(layout, 1, 100)
    rowgap!(layout, 4, 50)
    rowgap!(layout, 6, 50)
    rowgap!(layout, 8, 100)


    on(slidergrid.sliders[1].value) do height
        gui.density = airdensity(height)
        if gui.view[] == STRING_DENSITY
            gui.celllimits[] = (0, 20 * gui.density)
        end
    end


    on(slidergrid.sliders[2].value) do velocity
        gui.velocity = velocity
        if gui.view[] == STRING_VELOCITY
            gui.celllimits[] = (0, gui.velocity)
        elseif gui.view[] == STRING_TEMPERATURE
            gui.celllimits[] = (0, SPECIES_MASS * gui.velocity^2 / (3*BOLTZMANN_CONST) + TEMPERATURE)
        end
    end

    on(wallsg.sliders[1].value) do coefficient
        gui.wallcoeff = coefficient
    end

    on(menu.selection) do selection
        gui.view[] = selection
        if gui.view[] == STRING_DENSITY
            gui.celllimits[] = (0, 20 * gui.density)
        elseif gui.view[] == STRING_VELOCITY
            gui.celllimits[] = (0, gui.velocity)
        elseif gui.view[] == STRING_TEMPERATURE
            gui.celllimits[] = (0, SPECIES_MASS * gui.velocity^2 / (3*BOLTZMANN_CONST) + TEMPERATURE)
        end
    end

    on(playbutton.clicks) do _
        gui.pause = !gui.pause
        buttonlabel[] = gui.pause ? STRING_PLAY : STRING_PAUSE
    end

    on(resetbutton.clicks) do _
        gui.reset = true
        gui.lines[] .= Point2f.(NaN)
        gui.line_index = 0
        notify(gui.lines)
    end

    on(closebutton.clicks) do _
        gui.terminate = true
    end


end

airdensity(height::Number) = 1.225 * exp(-0.11856 * height)


function renderloop(
        screen::GLMakie.Screen,
        gui::GUI,
        thread::ComputationThread,
        mesh::SimulationMesh,
        globsync::Synchronizer
    )
    glscreen = GLMakie.to_native(screen)

    while !gui.terminate
        try
            starttime = frametime(FPS)

            GLMakie.pollevents(screen)
            GLMakie.render_frame(screen)
            GLFW.SwapBuffers(glscreen)

            synchronize(globsync)

            get_simulation_data(gui, thread, mesh)

            dur = (0.8 + starttime - frametime(FPS)) / 60
            dur > 0.001 && sleep(dur)

            synchronize(globsync)

            gui.new_wall = (Point2{Float64}(NaN), Point2{Float64}(NaN))
            gui.reset = false

            while frametime(FPS) - starttime < 1; end
        catch e
            GLFW.make_windowed!(glscreen)
            close(screen)
            @warn "Error in renderloop" exception=(e, catch_backtrace())
            interrupt()
        end
    end
    GLFW.make_windowed!(glscreen)
    GLFW.close
    close(screen)
end

"""
    frametime()

Returns the time frames given the FPS.
"""
frametime(fps) = (time_ns() / 1e9) * fps

function get_simulation_data(gui::GUI, thread, mesh)
    if gui.view[] == STRING_PARTICLE
        for (index, particle) in pairs(thread.particles)
            if index <= thread.n_particles[]

                gui.points[][index] = particle.position
            else
                gui.points[][index] = Point2f(NaN)
            end
        end
        notify(gui.points)
    else
        for (index, cell) in pairs(mesh.cells)
            if gui.view[] == STRING_DENSITY
                gui.cellvalue[][index] = cell.density
            elseif gui.view[] == STRING_VELOCITY
                gui.cellvalue[][index] = norm(cell.velocity)
            elseif gui.view[] == STRING_TEMPERATURE
                gui.cellvalue[][index] = cell.temperature
            end
        end
        notify(gui.cellvalue)
        notify(gui.celllimits)
    end
    return nothing
end
