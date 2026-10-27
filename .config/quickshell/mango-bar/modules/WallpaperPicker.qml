import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    color: "#1e1e2e"
    radius: Scaling.px(8)
    border.color: "#313244"
    border.width: Scaling.px(1)

    property bool open: false
    signal closeRequested()

    // "local" (imágenes en ~/wallpapers) o "wallhaven" (buscador de wallhaven.cc)
    property string activeTab: "local"

    // ============================================================
    // --- Pestaña Local (sin cambios de comportamiento respecto de antes) ---
    // ============================================================
    property var images: []
    property int selectedIndex: 0

    // Busca solo en ~/wallpapers (maxdepth 2 por si tenés subcarpetas --
    // esto incluye ~/wallpapers/wallhaven, adonde se descargan las
    // imágenes elegidas en la pestaña Wallhaven).
    // IMPORTANTE: sin "sort" al final -- un "sort" en el pipe tiene que
    // leer TODA la entrada antes de poder imprimir la primera línea, así
    // que con muchas imágenes (probado con ~1000) nada aparecía hasta que
    // find terminaba de recorrer la carpeta entera. Sin sort, find va
    // emitiendo cada archivo apenas lo encuentra.
    readonly property string scanScript: `
d="$HOME/wallpapers"
[ -d "$d" ] && find "$d" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \\) 2>/dev/null
`

    function scan() {
        root.images = []
        scanner._pending = []
        scanner._flushedCount = 0
        scanner.command = ["sh", "-c", root.scanScript]
        scanner.running = true
    }

    // Aplica el fondo SIN cerrar el selector, para poder ir probando varios.
    function apply(index) {
        if (index < 0 || index >= root.images.length) return
        Wallpaper.setWallpaper(root.images[index])
        root.selectedIndex = index
        Wallpaper.lastIndex = index
    }

    Process {
        id: scanner
        // Antes cada línea reasignaba root.images completo -- con ~1000
        // imágenes eso son ~1000 reinicios del modelo de la GridView, uno
        // por archivo, que es lo que más pesaba (más que la decodificación
        // en sí). Ahora las líneas se juntan en este buffer, y un timer
        // aparte las va volcando a root.images de a lotes: las primeras
        // ~40 aparecen apenas están listas (para poder navegar de
        // inmediato), y el resto se sigue agregando de a poco en segundo
        // plano sin trabar la interfaz.
        property var _pending: []
        property int _flushedCount: 0

        stdout: SplitParser {
            onRead: (line) => {
                let p = line.trim()
                if (p.length === 0) return
                scanner._pending.push(p)
                // Primer lote (las primeras ~40): se muestra apenas está
                // completo, sin esperar al timer, para que se pueda
                // empezar a navegar cuanto antes.
                if (scanner._flushedCount === 0 && scanner._pending.length >= 40) {
                    flushTimer.triggered()
                }
            }
        }
        // El escaneo es asíncrono (las imágenes van llegando línea por
        // línea), así que recién cuando termina (running pasa a false)
        // sabemos que "images" ya está completo y podemos ubicarnos en el
        // fondo actual.
        onRunningChanged: {
            if (!running) {
                flushTimer.triggered() // último lote, por si quedó algo pendiente
                if (root.open) {
                    let idx = root.images.indexOf(Wallpaper.current)
                    if (idx === -1) idx = Math.min(Wallpaper.lastIndex, Math.max(0, root.images.length - 1))
                    root.selectedIndex = idx
                    grid.positionViewAtIndex(idx, GridView.Contain)
                }
            }
        }
    }

    Timer {
        id: flushTimer
        interval: 200
        running: scanner.running
        repeat: true
        onTriggered: {
            if (scanner._pending.length === 0) return
            root.images = root.images.concat(scanner._pending)
            scanner._flushedCount += scanner._pending.length
            scanner._pending = []
        }
    }

    // ============================================================
    // --- Pestaña Wallhaven (nueva) ---
    // ============================================================
    property var whResults: []
    property int whSelectedIndex: 0
    property string whQuery: ""
    // Bitmask de 3 dígitos que usa la API de wallhaven: General/Anime/
    // Personas, en ese orden fijo (ej. "111" = las tres, "100" = solo
    // General). Empieza con las tres activas, igual que el comportamiento
    // de antes de agregar esto.
    property string whCategories: "111"

    function toggleCategory(bitIndex) {
        let bits = root.whCategories.split("")
        let newVal = bits[bitIndex] === "1" ? "0" : "1"
        // Nunca se permite dejar las 3 apagadas -- wallhaven no tiene
        // "ninguna categoría", y una búsqueda así no devolvería nada.
        if (newVal === "0" && bits.filter(b => b === "1").length <= 1) return
        bits[bitIndex] = newVal
        root.whCategories = bits.join("")
        root.searchWallhaven(root.whQuery, 1)
    }
    property int whPage: 1
    property int whLastPage: 1
    property bool whLoading: false
    // Vacío = sin error. Se muestra en rojo debajo de la grilla.
    property string whError: ""
    property bool whDownloading: false
    // id de wallhaven que se está descargando ahora mismo (para mostrar
    // el spinner solo sobre ESA miniatura).
    property string whDownloadingId: ""

    // ============================================================
    // --- Tags de Wallhaven (nuevo) ---
    // ============================================================
    // Tags derivados de los resultados actuales de la búsqueda, ordenados
    // por frecuencia (los más repetidos primero). La API de wallhaven NO
    // tiene un endpoint de tags populares ni devuelve tags dentro de los
    // resultados de /search -- solo vienen en el detalle de cada wallpaper
    // (/api/v1/w/<id>). Por eso se piden los tags de una MUESTRA chica de
    // los resultados de la página actual (tagSampleSize) en vez de usar
    // todos los resultados o inventar una lista fija.
    property var whTags: []               // [{ name, count }], ordenado desc por count
    property var whSelectedTags: []       // ["Batman", "Dark"] -- tags activos como filtro
    property int maxVisibleTags: 15       // cuántos tags se muestran como máximo en el panel
    property int tagSampleSize: 8         // de cuántos resultados de la página actual se derivan los tags (limita peticiones -- wallhaven permite 45/min)
    property bool whTagsLoading: false
    property var _whTagDetailCache: ({})  // id de wallhaven -> array de nombres de tags, para no repetir pedidos ya hechos
    property var _tagFreq: ({})           // acumulador temporal nombre en minúsculas -> {name, count} mientras se arma whTags
    property int _tagFetchGen: 0          // se incrementa en cada búsqueda nueva, para descartar respuestas de tags ya obsoletas

    // Selecciona/deselecciona un tag como filtro. El cambio visual (chip
    // marcado) es inmediato; la búsqueda a wallhaven se debounce un poco
    // (tagSearchDebounce) para no disparar una petición por cada click si
    // el usuario selecciona varios tags seguidos.
    function toggleTag(name) {
        let tags = root.whSelectedTags.slice()
        let idx = tags.indexOf(name)
        if (idx === -1) tags.push(name)
        else tags.splice(idx, 1)
        root.whSelectedTags = tags
        tagSearchDebounce.restart()
    }

    // Quita SOLO los filtros de tags -- el texto buscado, las categorías,
    // Local/Wallhaven y el modo de ajuste quedan intactos. Vuelve a
    // página 1 y repite la búsqueda de inmediato (sin esperar el debounce).
    function clearTagFilters() {
        if (root.whSelectedTags.length === 0) return
        tagSearchDebounce.stop()
        root.whSelectedTags = []
        root.searchWallhaven(root.whQuery, 1)
    }

    Timer {
        id: tagSearchDebounce
        interval: 250
        repeat: false
        onTriggered: root.searchWallhaven(root.whQuery, 1)
    }

    // Resolución máxima entre TODAS las pantallas conectadas (ancho y
    // alto tomados de forma independiente, por si hay monitores de
    // proporciones distintas) -- así el filtro "atleast" de wallhaven no
    // deja pasar imágenes más chicas que cualquiera de tus pantallas
    // (se verían borrosas al escalarlas). devicePixelRatio multiplica
    // por si el compositor tiene configurado un escalado HiDPI: lo que
    // importa es la resolución FÍSICA real, no la lógica.
    function maxScreenResolution() {
        let maxW = 0, maxH = 0
        let screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++) {
            let w = Math.round(screens[i].width * screens[i].devicePixelRatio)
            let h = Math.round(screens[i].height * screens[i].devicePixelRatio)
            if (w > maxW) maxW = w
            if (h > maxH) maxH = h
        }
        if (maxW === 0 || maxH === 0) { maxW = 1920; maxH = 1080 }
        return maxW + "x" + maxH
    }

    // Arma la URL de búsqueda combinando texto libre + categorías + tags
    // seleccionados + purity/atleast/sorting/página, en un solo lugar para
    // no duplicar esta lógica en cada sitio que dispara una búsqueda.
    // Sin query y sin tags: se muestran las más populares del último mes
    // (toplist). Con query y/o tags: se ordena por relevancia.
    // purity=100 (SFW) va siempre fijo, sin excepción.
    function buildWallhavenSearchUrl(query, page) {
        let q = query.trim()
        // Sintaxis real de búsqueda de wallhaven (wallhaven.cc/help/api):
        // "+tag1 +tag2" significa "debe tener tag1 Y tag2". Cada tag
        // seleccionado se agrega como término obligatorio; el texto libre
        // (si hay) queda como búsqueda difusa normal, sin "+", igual que
        // antes de agregar tags.
        // Limitación conocida de la API: no hay forma documentada de
        // agrupar un tag de varias palabras (ej. "digital art") como una
        // sola frase obligatoria -- wallhaven interpreta cada palabra por
        // separado. Solo afecta a tags compuestos por más de una palabra.
        for (let i = 0; i < root.whSelectedTags.length; i++) {
            q += (q.length > 0 ? " " : "") + "+" + root.whSelectedTags[i]
        }
        return "https://wallhaven.cc/api/v1/search?purity=100&categories=" + root.whCategories
            + "&atleast=" + root.maxScreenResolution()
            + "&page=" + page
            + (q.length > 0
                ? ("&sorting=relevance&q=" + encodeURIComponent(q))
                : "&sorting=toplist&topRange=1M")
    }

    function searchWallhaven(query, page) {
        root.whLoading = true
        root.whError = ""
        root.whQuery = query
        let url = root.buildWallhavenSearchUrl(query, page)

        let xhr = new XMLHttpRequest()
        xhr.timeout = 10000
        xhr.ontimeout = function() {
            root.whLoading = false
            root.whError = "wallhaven.cc no respondió a tiempo. Probá de nuevo."
        }
        xhr.onerror = function() {
            root.whLoading = false
            root.whError = "No se pudo conectar a wallhaven.cc -- revisá tu conexión a internet."
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            root.whLoading = false
            if (xhr.status === 429) {
                root.whError = "Demasiadas búsquedas seguidas -- esperá un momento y probá de nuevo."
                return
            }
            if (xhr.status !== 200) {
                root.whError = "wallhaven.cc respondió con un error (código " + xhr.status + ")."
                return
            }
            try {
                let data = JSON.parse(xhr.responseText)
                root.whResults = data.data || []
                root.whPage = page
                root.whLastPage = (data.meta && data.meta.last_page) || 1
                root.whSelectedIndex = 0
                whGrid.positionViewAtIndex(0, GridView.Contain)
                root.fetchTagsFromResults()
            } catch (e) {
                root.whError = "Respuesta inesperada de wallhaven.cc."
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    // Descarga la imagen completa a ~/wallpapers/wallhaven/ (crea la
    // carpeta si hace falta), y si ya la habías descargado antes no la
    // vuelve a bajar. Antes de guardar, la reduce (nunca la agranda) a la
    // resolución máxima entre TODAS tus pantallas -- la misma que ya se
    // usa como filtro mínimo de búsqueda (maxScreenResolution()) -- así
    // el archivo que queda en disco no pesa más de lo que tu pantalla más
    // grande puede llegar a mostrar. Al terminar, la aplica y refresca la
    // pestaña Local para que aparezca ahí también.
    function downloadWallhaven(item) {
        if (root.whDownloading) return
        root.whDownloading = true
        root.whDownloadingId = item.id
        root.whError = ""
        let filename = item.path.substring(item.path.lastIndexOf("/") + 1)
        let b64Url = Qt.btoa(item.path)
        let b64Name = Qt.btoa(filename)
        let res = root.maxScreenResolution()
        downloader.command = ["sh", "-c",
            "url=$(printf '%s' '" + b64Url + "' | base64 -d); " +
            "name=$(printf '%s' '" + b64Name + "' | base64 -d); " +
            "mkdir -p \"$HOME/wallpapers/wallhaven\" && " +
            "dest=\"$HOME/wallpapers/wallhaven/$name\" && " +
            "if [ -f \"$dest\" ]; then :; else " +
            "(command -v curl >/dev/null 2>&1 && curl -fsSL \"$url\" -o \"$dest\") || " +
            "(command -v wget >/dev/null 2>&1 && wget -q \"$url\" -O \"$dest\") || exit 1; " +
            // Reducción real de resolución -- "WxH>" de ImageMagick
            // encoge SOLO si hace falta (nunca agranda) y mantiene la
            // proporción original (no recorta ni distorsiona -- eso lo
            // sigue resolviendo el modo de ajuste de la imagen al
            // mostrarla, no esto). Se escribe primero a un archivo
            // temporal y se reemplaza con "mv" recién si termina bien,
            // para no dejar el archivo final a medio escribir si algo
            // falla a mitad de camino. Si no hay ni convert ni magick
            // instalados, se deja la imagen original tal cual descargada
            // (sigue siendo un fondo de pantalla que funciona perfecto,
            // solo que más pesado de lo necesario) en vez de fallar toda
            // la descarga por esto.
            "(command -v convert >/dev/null 2>&1 && convert \"$dest\" -resize \"" + res + ">\" \"$dest.tmp\" && mv \"$dest.tmp\" \"$dest\") || " +
            "(command -v magick >/dev/null 2>&1 && magick \"$dest\" -resize \"" + res + ">\" \"$dest.tmp\" && mv \"$dest.tmp\" \"$dest\") || " +
            "rm -f \"$dest.tmp\"; " +
            "fi && printf '%s' \"$dest\""]
        downloader.running = true
    }

    property Process downloader: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.whDownloading = false
                root.whDownloadingId = ""
                let path = text.trim()
                if (path.length > 0) {
                    Wallpaper.setWallpaper(path)
                    root.scan()
                } else {
                    root.whError = "No se pudo descargar la imagen (revisá tu conexión, o que curl/wget estén instalados)."
                }
            }
        }
    }

    // Deriva los tags "populares/relacionados" a partir de los resultados
    // actuales, ya que wallhaven no ofrece un endpoint de tags populares y
    // los resultados de /search no traen tags (solo el detalle de cada
    // wallpaper, /api/v1/w/<id>, los incluye). Para no gastar de más la
    // cuota de 45 peticiones/minuto de la API, solo se consulta el detalle
    // de una muestra chica (tagSampleSize) de la página actual, uno por
    // uno (nunca en paralelo), y se cachea por id para no repetir pedidos
    // si ese wallpaper ya se consultó antes. Es completamente asíncrono y
    // no bloquea ni la grilla ni el resto de la interfaz -- si falla o
    // tarda, como mucho el panel de tags queda vacío o desactualizado un
    // rato, pero la búsqueda y descarga de wallpapers no se ven afectadas.
    function fetchTagsFromResults() {
        root._tagFetchGen++
        let gen = root._tagFetchGen
        let sample = root.whResults.slice(0, root.tagSampleSize)
        root._tagFreq = {}
        root.whTagsLoading = sample.length > 0
        root._fetchTagDetailChain(sample.map(w => w.id), gen)
    }

    function _fetchTagDetailChain(queue, gen) {
        // Una búsqueda más nueva ya reemplazó a esta tanda -- se descarta
        // en silencio en vez de seguir acumulando tags de resultados viejos.
        if (gen !== root._tagFetchGen) return
        if (queue.length === 0) {
            root._finishTagAggregation(gen)
            return
        }
        let id = queue[0]
        let rest = queue.slice(1)
        if (root._whTagDetailCache[id] !== undefined) {
            root._accumulateTags(root._whTagDetailCache[id])
            root._fetchTagDetailChain(rest, gen)
            return
        }
        let xhr = new XMLHttpRequest()
        xhr.timeout = 8000
        xhr.ontimeout = function() { root._fetchTagDetailChain(rest, gen) }
        xhr.onerror = function() { root._fetchTagDetailChain(rest, gen) }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (gen !== root._tagFetchGen) return
            if (xhr.status === 429) {
                // Ya estamos limitados por wallhaven -- no seguir insistiendo
                // con el resto de la muestra.
                root._finishTagAggregation(gen)
                return
            }
            if (xhr.status === 200) {
                try {
                    let data = JSON.parse(xhr.responseText)
                    let names = ((data.data && data.data.tags) || []).map(t => t.name)
                    root._whTagDetailCache[id] = names
                    root._accumulateTags(names)
                } catch (e) { /* se descarta solo este item, no es crítico */ }
            }
            root._fetchTagDetailChain(rest, gen)
        }
        xhr.open("GET", "https://wallhaven.cc/api/v1/w/" + id)
        xhr.send()
    }

    function _accumulateTags(names) {
        for (let i = 0; i < names.length; i++) {
            let key = names[i].toLowerCase()
            if (!root._tagFreq[key]) root._tagFreq[key] = { name: names[i], count: 0 }
            root._tagFreq[key].count++
        }
    }

    function _finishTagAggregation(gen) {
        if (gen !== root._tagFetchGen) return
        root.whTagsLoading = false
        let keys = Object.keys(root._tagFreq)
        let arr = keys.map(k => root._tagFreq[k])
        arr.sort((a, b) => b.count - a.count)
        arr = arr.slice(0, root.maxVisibleTags)
        // Los tags ya seleccionados se mantienen visibles aunque no estén
        // entre los más frecuentes de esta tanda de resultados.
        for (let i = 0; i < root.whSelectedTags.length; i++) {
            let sel = root.whSelectedTags[i]
            if (!arr.some(t => t.name.toLowerCase() === sel.toLowerCase())) {
                arr.unshift({ name: sel, count: 0 })
            }
        }
        root.whTags = arr
    }

    // ============================================================
    // --- Navegación compartida entre las 2 pestañas ---
    // ============================================================
    function currentList() { return root.activeTab === "local" ? root.images : root.whResults }
    function currentIndex() { return root.activeTab === "local" ? root.selectedIndex : root.whSelectedIndex }
    function setCurrentIndex(i) {
        if (root.activeTab === "local") root.selectedIndex = i
        else root.whSelectedIndex = i
    }
    function activeGrid() { return root.activeTab === "local" ? grid : whGrid }

    function columns() {
        let g = root.activeGrid()
        return Math.max(1, Math.floor(g.width / g.cellWidth))
    }

    function moveSelection(dx, dy) {
        let list = root.currentList()
        if (list.length === 0) return
        let cols = root.columns()
        let i = root.currentIndex() + dx + dy * cols
        i = Math.max(0, Math.min(list.length - 1, i))
        root.setCurrentIndex(i)
        root.activeGrid().positionViewAtIndex(i, GridView.Contain)
    }

    // Enter: en Local aplica directo; en Wallhaven descarga y aplica.
    function activate() {
        if (root.activeTab === "local") {
            root.apply(root.selectedIndex)
        } else if (root.whSelectedIndex >= 0 && root.whSelectedIndex < root.whResults.length) {
            root.downloadWallhaven(root.whResults[root.whSelectedIndex])
        }
    }

    onOpenChanged: {
        if (root.open) {
            root.scan()
            // Primera vez que se abre en la sesión: trae los populares de
            // wallhaven de una, para que la pestaña no arranque vacía.
            // Búsquedas posteriores quedan en memoria (no se repiten
            // solas cada vez que se reabre el selector).
            if (root.whResults.length === 0 && !root.whLoading) root.searchWallhaven("", 1)
            root.forceActiveFocus()
        }
    }

    onImagesChanged: {
        if (root.activeTab === "local" && root.selectedIndex >= root.images.length) {
            root.selectedIndex = Math.max(0, root.images.length - 1)
        }
    }

    focus: true
    Keys.onEscapePressed: root.closeRequested()
    Keys.onLeftPressed: root.moveSelection(-1, 0)
    Keys.onRightPressed: root.moveSelection(1, 0)
    Keys.onUpPressed: root.moveSelection(0, -1)
    Keys.onDownPressed: root.moveSelection(0, 1)
    Keys.onReturnPressed: root.activate()

    // Absorbe clicks internos para que no se propaguen al fondo de la
    // ventana contenedora (que cierra el selector al hacer click afuera)
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaling.px(14)
        spacing: Scaling.px(8)

        // --- Fila 1: título, selector de ajuste de imagen, cerrar ---
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Fondo de pantalla"
                color: "#f5e0dc"
                font.bold: true
                font.pixelSize: Scaling.px(14)
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Ajuste:"
                color: "#9399b2"
                font.pixelSize: Scaling.px(11)
            }

            Row {
                spacing: Scaling.px(2)
                Repeater {
                    model: [
                        { key: "center", label: "Centrada" },
                        { key: "fill", label: "Full" },
                        { key: "stretch", label: "Estirada" }
                    ]
                    delegate: Rectangle {
                        readonly property bool isActive: Wallpaper.fillMode === modelData.key
                        implicitWidth: fmLabel.implicitWidth + Scaling.px(14)
                        implicitHeight: Scaling.px(22)
                        radius: Scaling.px(4)
                        color: isActive ? "#89b4fa" : (fmHover.containsMouse ? "#313244" : "transparent")
                        Text {
                            id: fmLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Scaling.px(11)
                            color: parent.isActive ? "#1e1e2e" : "#cdd6f4"
                        }
                        MouseArea {
                            id: fmHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Wallpaper.setFillMode(modelData.key)
                        }
                    }
                }
            }

            Item { implicitWidth: Scaling.px(8) }

            Rectangle {
                implicitWidth: Scaling.px(22)
                implicitHeight: Scaling.px(22)
                radius: Scaling.px(4)
                color: closeHoverWallpaper.containsMouse ? "#f38ba8" : "#313244"
                Text {
                    anchors.centerIn: parent
                    text: "\uf00d"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Scaling.px(11)
                    color: closeHoverWallpaper.containsMouse ? "#1e1e2e" : "#cdd6f4"
                }
                MouseArea {
                    id: closeHoverWallpaper
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.closeRequested()
                }
            }
        }

        // --- Fila 2: pestañas, buscador (solo Wallhaven), atajos ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Scaling.px(8)

            Row {
                spacing: Scaling.px(2)
                Repeater {
                    model: [
                        { key: "local", label: "Local" },
                        { key: "wallhaven", label: "Wallhaven" }
                    ]
                    delegate: Rectangle {
                        readonly property bool isActive: root.activeTab === modelData.key
                        implicitWidth: tabLabel.implicitWidth + Scaling.px(18)
                        implicitHeight: Scaling.px(24)
                        radius: Scaling.px(4)
                        color: isActive ? "#313244" : (tabHover.containsMouse ? "#313244" : "transparent")
                        border.width: isActive ? Scaling.px(1) : 0
                        border.color: "#89b4fa"
                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Scaling.px(12)
                            font.bold: parent.isActive
                            color: parent.isActive ? "#89b4fa" : "#cdd6f4"
                        }
                        MouseArea {
                            id: tabHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.activeTab = modelData.key
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.activeTab === "local"
                    ? "Flechas: moverse · Enter: aplicar"
                    : "Flechas: moverse · Enter: descargar y aplicar"
                color: "#9399b2"
                font.pixelSize: Scaling.px(11)
            }
        }

        // --- Fila 2.5: buscador y categorías (solo pestaña Wallhaven) ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Scaling.px(8)
            visible: root.activeTab === "wallhaven"

            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.preferredHeight: Scaling.px(24)
                placeholderText: "Buscar en wallhaven.cc (vacío = populares)…"
                font.pixelSize: Scaling.px(11)
                text: root.whQuery
                onAccepted: root.searchWallhaven(text, 1)
            }

            Text {
                text: "Categoría:"
                color: "#9399b2"
                font.pixelSize: Scaling.px(11)
            }

            Row {
                spacing: Scaling.px(2)
                Repeater {
                    model: [
                        { bit: 0, label: "General" },
                        { bit: 1, label: "Anime" },
                        { bit: 2, label: "Personas" }
                    ]
                    delegate: Rectangle {
                        readonly property bool isActive: root.whCategories.charAt(modelData.bit) === "1"
                        implicitWidth: catLabel.implicitWidth + Scaling.px(14)
                        implicitHeight: Scaling.px(22)
                        radius: Scaling.px(4)
                        color: isActive ? "#89b4fa" : (catHover.containsMouse ? "#313244" : "transparent")
                        border.width: isActive ? 0 : Scaling.px(1)
                        border.color: "#45475a"
                        Text {
                            id: catLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Scaling.px(11)
                            color: parent.isActive ? "#1e1e2e" : "#cdd6f4"
                        }
                        MouseArea {
                            id: catHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.toggleCategory(modelData.bit)
                        }
                    }
                }
            }
        }

        // --- Cuerpo: grilla Local ---
        GridView {
            id: grid
            visible: root.activeTab === "local"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: Scaling.px(168)
            cellHeight: Scaling.px(106)
            model: root.images

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Item {
                id: delegateRoot
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight

                readonly property bool isApplied: delegateRoot.modelData === Wallpaper.current
                readonly property bool isSelected: root.activeTab === "local" && delegateRoot.index === root.selectedIndex

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Scaling.px(4)
                    radius: Scaling.px(6)
                    color: delegateRoot.isSelected ? "#313244" : "transparent"
                    border.width: delegateRoot.isApplied ? Scaling.px(3) : (delegateRoot.isSelected ? Scaling.px(2) : 0)
                    border.color: delegateRoot.isApplied ? "#a6e3a1" : "#89b4fa"
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: (delegateRoot.isApplied || delegateRoot.isSelected) ? Scaling.px(2) : 0
                        source: "file://" + delegateRoot.modelData
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        // Antes solo se fijaba sourceSize.width a 220px
                        // fijos (sin height), así que el decodificador
                        // igual tenía que procesar bastante más de lo que
                        // se termina mostrando -- con imágenes grandes,
                        // eso es lo que más pesa al abrir el selector. Acá
                        // se decodifica directo al tamaño real de la
                        // celda.
                        sourceSize.width: grid.cellWidth
                        sourceSize.height: grid.cellHeight
                        cache: true
                    }

                    // Marca discreta de "este es el fondo activo ahora mismo"
                    Rectangle {
                        visible: delegateRoot.isApplied
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Scaling.px(4)
                        width: Scaling.px(16)
                        height: Scaling.px(16)
                        radius: Scaling.px(8)
                        color: "#a6e3a1"

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "#1e1e2e"
                            font.pixelSize: Scaling.px(10)
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.apply(delegateRoot.index)
                    }
                }
            }
        }

        Text {
            visible: root.activeTab === "local" && root.images.length === 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "No se encontraron imágenes en ~/wallpapers. Copiá algunas ahí (jpg/jpeg/png/webp/bmp), o descargá alguna desde la pestaña Wallhaven."
            color: "#9399b2"
            font.pixelSize: Scaling.px(11)
        }

        // --- Cuerpo: pestaña Wallhaven ---
        ColumnLayout {
            visible: root.activeTab === "wallhaven"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Scaling.px(6)

            // Grilla de resultados + panel de tags, lado a lado.
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Scaling.px(8)

                GridView {
                    id: whGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: Scaling.px(168)
                    cellHeight: Scaling.px(106)
                    model: root.whResults
                    opacity: root.whDownloading ? 0.6 : 1.0

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Item {
                        id: whDelegateRoot
                        required property var modelData
                        required property int index
                        width: whGrid.cellWidth
                        height: whGrid.cellHeight

                        readonly property bool isSelected: root.activeTab === "wallhaven" && whDelegateRoot.index === root.whSelectedIndex
                        readonly property bool isDownloadingThis: root.whDownloadingId === whDelegateRoot.modelData.id

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Scaling.px(4)
                            radius: Scaling.px(6)
                            color: whDelegateRoot.isSelected ? "#313244" : "transparent"
                            border.width: whDelegateRoot.isSelected ? Scaling.px(2) : 0
                            border.color: "#89b4fa"
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: whDelegateRoot.isSelected ? Scaling.px(2) : 0
                                source: whDelegateRoot.modelData.thumbs.large
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                cache: true
                            }

                            // Resolución real, para saber de un vistazo si va
                            // a verse nítida en la pantalla.
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.margins: Scaling.px(3)
                                implicitWidth: resText.implicitWidth + Scaling.px(6)
                                implicitHeight: resText.implicitHeight + Scaling.px(2)
                                radius: Scaling.px(3)
                                color: "#1e1e2ecc"
                                Text {
                                    id: resText
                                    anchors.centerIn: parent
                                    text: whDelegateRoot.modelData.dimension_x + "×" + whDelegateRoot.modelData.dimension_y
                                    color: "#cdd6f4"
                                    font.pixelSize: Scaling.px(9)
                                }
                            }

                            Rectangle {
                                visible: whDelegateRoot.isDownloadingThis
                                anchors.fill: parent
                                color: "#1e1e2ecc"
                                radius: Scaling.px(6)
                                Text {
                                    anchors.centerIn: parent
                                    text: "Descargando…"
                                    color: "#cdd6f4"
                                    font.pixelSize: Scaling.px(11)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.whDownloading
                                onClicked: {
                                    root.whSelectedIndex = whDelegateRoot.index
                                    root.downloadWallhaven(whDelegateRoot.modelData)
                                }
                            }
                        }
                    }
                }

                // --- Panel lateral: tags populares/relacionados con la búsqueda ---
                Rectangle {
                    Layout.preferredWidth: Scaling.px(160)
                    Layout.fillHeight: true
                    radius: Scaling.px(6)
                    color: "#181825"
                    border.width: Scaling.px(1)
                    border.color: "#313244"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Scaling.px(8)
                        spacing: Scaling.px(6)

                        Text {
                            text: "Tags"
                            color: "#f5e0dc"
                            font.bold: true
                            font.pixelSize: Scaling.px(12)
                        }

                        ListView {
                            id: tagsList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: Scaling.px(3)
                            model: root.whTags

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }

                            delegate: Rectangle {
                                width: tagsList.width
                                implicitHeight: tagChipLabel.implicitHeight + Scaling.px(8)
                                radius: Scaling.px(4)
                                readonly property bool isSelected: root.whSelectedTags.indexOf(modelData.name) !== -1
                                color: isSelected ? "#89b4fa" : (tagHover.containsMouse ? "#313244" : "transparent")
                                border.width: isSelected ? 0 : Scaling.px(1)
                                border.color: "#45475a"

                                Text {
                                    id: tagChipLabel
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: Scaling.px(6)
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    text: modelData.name + (parent.isSelected ? " ✓" : "")
                                    font.pixelSize: Scaling.px(11)
                                    color: parent.isSelected ? "#1e1e2e" : "#cdd6f4"
                                }

                                MouseArea {
                                    id: tagHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.toggleTag(modelData.name)
                                }
                            }
                        }

                        Text {
                            visible: root.whTagsLoading
                            Layout.fillWidth: true
                            text: "Cargando tags…"
                            color: "#9399b2"
                            font.pixelSize: Scaling.px(10)
                        }

                        Text {
                            visible: !root.whTagsLoading && root.whTags.length === 0
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: "Sin tags disponibles."
                            color: "#9399b2"
                            font.pixelSize: Scaling.px(10)
                        }

                        Rectangle {
                            visible: root.whSelectedTags.length > 0
                            Layout.fillWidth: true
                            implicitHeight: Scaling.px(1)
                            color: "#313244"
                        }

                        Text {
                            visible: root.whSelectedTags.length > 0
                            text: "Filtros activos:"
                            color: "#9399b2"
                            font.pixelSize: Scaling.px(10)
                        }

                        Flow {
                            visible: root.whSelectedTags.length > 0
                            Layout.fillWidth: true
                            spacing: Scaling.px(4)
                            Repeater {
                                model: root.whSelectedTags
                                delegate: Rectangle {
                                    implicitWidth: activeChipLabel.implicitWidth + Scaling.px(16)
                                    implicitHeight: Scaling.px(20)
                                    radius: Scaling.px(4)
                                    color: "#313244"
                                    Text {
                                        id: activeChipLabel
                                        anchors.centerIn: parent
                                        text: modelData + " ×"
                                        color: "#cdd6f4"
                                        font.pixelSize: Scaling.px(10)
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.toggleTag(modelData)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: root.whSelectedTags.length > 0
                            Layout.fillWidth: true
                            implicitHeight: Scaling.px(22)
                            radius: Scaling.px(4)
                            color: clearTagsHover.containsMouse ? "#f38ba8" : "#313244"
                            Text {
                                anchors.centerIn: parent
                                text: "Limpiar filtros"
                                font.pixelSize: Scaling.px(11)
                                color: clearTagsHover.containsMouse ? "#1e1e2e" : "#cdd6f4"
                            }
                            MouseArea {
                                id: clearTagsHover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.clearTagFilters()
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.whLoading
                Layout.fillWidth: true
                text: "Buscando en wallhaven.cc…"
                color: "#9399b2"
                font.pixelSize: Scaling.px(11)
            }

            Text {
                visible: !root.whLoading && root.whError.length > 0
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: root.whError
                color: "#f38ba8"
                font.pixelSize: Scaling.px(11)
            }

            Text {
                visible: !root.whLoading && root.whError.length === 0 && root.whResults.length === 0
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Sin resultados para esa búsqueda."
                color: "#9399b2"
                font.pixelSize: Scaling.px(11)
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.whResults.length > 0

                Rectangle {
                    implicitWidth: prevLabel.implicitWidth + Scaling.px(16)
                    implicitHeight: Scaling.px(22)
                    radius: Scaling.px(4)
                    readonly property bool enabled_: root.whPage > 1 && !root.whLoading
                    color: prevHover.containsMouse && enabled_ ? "#313244" : "transparent"
                    opacity: enabled_ ? 1.0 : 0.4
                    Text {
                        id: prevLabel
                        anchors.centerIn: parent
                        text: "‹ Anterior"
                        color: "#cdd6f4"
                        font.pixelSize: Scaling.px(11)
                    }
                    MouseArea {
                        id: prevHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.enabled_
                        onClicked: root.searchWallhaven(root.whQuery, root.whPage - 1)
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Página " + root.whPage + " de " + root.whLastPage
                    color: "#9399b2"
                    font.pixelSize: Scaling.px(11)
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: nextLabel.implicitWidth + Scaling.px(16)
                    implicitHeight: Scaling.px(22)
                    radius: Scaling.px(4)
                    readonly property bool enabled_: root.whPage < root.whLastPage && !root.whLoading
                    color: nextHover.containsMouse && enabled_ ? "#313244" : "transparent"
                    opacity: enabled_ ? 1.0 : 0.4
                    Text {
                        id: nextLabel
                        anchors.centerIn: parent
                        text: "Siguiente ›"
                        color: "#cdd6f4"
                        font.pixelSize: Scaling.px(11)
                    }
                    MouseArea {
                        id: nextHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.enabled_
                        onClicked: root.searchWallhaven(root.whQuery, root.whPage + 1)
                    }
                }
            }
        }
    }
}
