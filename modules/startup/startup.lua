function init()
    connect(g_app, {
        onExit = exit
    })

    local platformType = g_window.getPlatformType()
    local isX11 = type(platformType) == 'string' and platformType:find('X11', 1, true) == 1
    -- Cocoa entra al mismo espacio de metricas FISICO que X11 (Duelfall 2026-07-26):
    -- desde que el backend de macOS pide superficie Retina nativa, la geometria de
    -- g_window (size/pos/displaySize) esta en pixeles fisicos, no en puntos.
    local isCocoa = type(platformType) == 'string' and platformType:find('COCOA', 1, true) == 1
    local isPhysicalMetrics = isX11 or isCocoa
    local density = (isPhysicalMetrics and g_window.getDisplayDensity()) or 1
    local displaySize = g_window.getDisplaySize()
    local metricsSpace = g_settings.getString('window-metrics-space', '')
    local shouldScaleLegacySavedMetrics = isPhysicalMetrics and density ~= 1 and
                                              metricsSpace ~= 'physical-v1'

    if g_platform.isMobile() then
        g_window.setMinimumSize({ width = 640, height = 360 })
    else
        -- El minimo esta expresado en unidades de UI; en espacio fisico hay que
        -- escalarlo por la densidad para que la ventana minima se vea igual de grande.
        local minSize = { width = 1020 * density, height = 644 * density }
        if isPhysicalMetrics then
            minSize.width = math.max(1, math.min(minSize.width, displaySize.width))
            minSize.height = math.max(1, math.min(minSize.height, displaySize.height))
        end
        g_window.setMinimumSize(minSize)
    end

    -- window size
    local hasSavedWindowSize = g_settings.exists('window-size')
    -- El default tambien va en espacio fisico: sin escalarlo, el primer arranque en
    -- una pantalla Retina abriria una ventana de la mitad del tamano esperado.
    local size = { width = 1020 * density, height = 644 * density }
    size = g_settings.getSize('window-size', size)
    if shouldScaleLegacySavedMetrics and hasSavedWindowSize then
        size = {
            width = math.floor((size.width * density) + 0.5),
            height = math.floor((size.height * density) + 0.5)
        }
    end

    if isPhysicalMetrics then
        size.width = math.max(1, math.min(size.width, displaySize.width))
        size.height = math.max(1, math.min(size.height, displaySize.height))
    end
    g_window.resize(size)

    -- window position, default is the screen center
    local defaultPos = {
        x = (displaySize.width - size.width) / 2,
        y = (displaySize.height - size.height) / 2
    }
    local pos = defaultPos
    if not isX11 then
        pos = g_settings.getPoint('window-pos', defaultPos)
        -- Una posicion guardada por una version previa esta en puntos: migrarla.
        if shouldScaleLegacySavedMetrics and g_settings.exists('window-pos') then
            pos = {
                x = math.floor((pos.x * density) + 0.5),
                y = math.floor((pos.y * density) + 0.5)
            }
        end
    end
    if isX11 then
        local maxX = math.max(displaySize.width - size.width, 0)
        local maxY = math.max(displaySize.height - size.height, 0)
        pos.x = math.max(0, math.min(pos.x, maxX))
        pos.y = math.max(0, math.min(pos.y, maxY))
    else
        pos.x = math.max(pos.x, 0)
        pos.y = math.max(pos.y, 0)
    end
    g_window.move(pos)

    -- window maximized?
    local maximized = g_settings.getBoolean('window-maximized', false)
    if maximized then g_window.maximize() end

    g_window.setTitle(g_app.getName())
    g_window.setIcon('/images/clienticon')

    -- poll resize events
    g_window.poll()

    -- generate machine uuid, this is a security measure for storing passwords
    if not g_crypt.setMachineUUID(g_settings.get('uuid')) then
        g_settings.set('uuid', g_crypt.getMachineUUID())
        g_settings.save()
    end
end

function terminate()
    disconnect(g_app, {
        onExit = exit
    })

    local platformType = g_window.getPlatformType()
    local isX11 = type(platformType) == 'string' and platformType:find('X11', 1, true) == 1
    local isCocoa = type(platformType) == 'string' and platformType:find('COCOA', 1, true) == 1

    -- save window configs
    local windowSize = g_window.getUnmaximizedSize()
    local windowPos = g_window.getUnmaximizedPos()
    g_settings.set('window-size', windowSize)
    if isX11 then
        -- NOTE: Keep window-pos disabled on X11.
        -- Persisting it causes a second-launch sizing/position regression with current metrics flow.
        g_settings.remove('window-pos')
        g_settings.set('window-metrics-space', 'physical-v1')
    else
        g_settings.set('window-pos', windowPos)
        if isCocoa then
            -- Cocoa guarda en espacio fisico igual que X11, pero SI persiste la
            -- posicion (el workaround de arriba es especifico de X11).
            g_settings.set('window-metrics-space', 'physical-v1')
        else
            g_settings.remove('window-metrics-space')
        end
    end
    g_settings.set('window-maximized', g_window.isMaximized())
    g_settings.save()
end

function exit()
    g_logger.info('Exiting application..')
end
