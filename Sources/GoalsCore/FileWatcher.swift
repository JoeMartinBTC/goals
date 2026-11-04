import Foundation

/// Beobachtet einen Pfad, nicht eine Inode. Werkzeuge speichern oft atomar (Temp-Datei, `rename`):
/// Am alten Deskriptor kommt dann nur `.delete` oder `.rename` an, nie wieder `.write`.
/// Bei diesen Ereignissen öffnet der Watcher den Pfad neu.
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var debounce: DispatchWorkItem?
    private var path = ""
    private var onChange: (() -> Void)?
    private var isRunning = false
    private let queue = DispatchQueue(label: "Goals.FileWatcher", qos: .utility)

    /// `onChange` kommt entprellt auf der Hauptwarteschlange.
    func start(path: String, onChange: @escaping () -> Void) {
        queue.sync {
            cancel()
            self.path = path
            self.onChange = onChange
            isRunning = true
            arm(attempt: 0)
        }
    }

    func stop() {
        queue.sync {
            isRunning = false
            cancel()
            debounce?.cancel()
        }
    }

    private func cancel() {
        source?.cancel()
        source = nil
    }

    // Läuft auf `queue`. Fehlt der Pfad kurz (löschen und neu anlegen), versucht es weiter.
    private func arm(attempt: Int) {
        guard isRunning else { return }
        cancel()
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            if attempt < 20 {
                queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.arm(attempt: attempt + 1) }
            }
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: queue)
        src.setEventHandler { [weak self, weak src] in
            guard let self, let src else { return }
            if !src.data.isDisjoint(with: [.delete, .rename]) { self.arm(attempt: 0) }
            self.scheduleReload()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
        // Die Datei kam nach einer Lücke zurück; ihr Inhalt entstand unbeobachtet.
        if attempt > 0 { scheduleReload() }
    }

    private func scheduleReload() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange?() }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}
