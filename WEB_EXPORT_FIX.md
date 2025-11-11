# Web Export Fix für GitLab Pages

## Problem
Sprites wurden nicht geladen und alles war schwarz auf GitLab Pages.

## Ursache
Der `export_path` in `export_presets.cfg` war leer, was zu Problemen beim Export führte.

## Lösung

### 1. Export-Konfiguration korrigiert
- `export_path` auf `"build/web/index.html"` gesetzt
- Web-Export-Preset korrekt konfiguriert

### 2. Wichtige Einstellungen für Web-Export
```
variant/thread_support=false  # WICHTIG für Web!
vram_texture_compression/for_desktop=true
compress/mode=0  # Für Pixel-Art
```

### 3. Lokaler Test-Export
Um lokal zu testen:
```bash
cd /Users/e.steffen/godot/wool
mkdir -p build/web
godot --headless --export-release "Web" build/web/index.html
```

Dann mit lokalem Server testen:
```bash
cd build/web
python3 -m http.server 8000
# Öffne http://localhost:8000
```

### 4. GitLab CI/CD
Die Pipeline sollte jetzt korrekt funktionieren:
1. `export-web` Stage: Exportiert das Spiel nach `build/web/`
2. `pages` Stage: Kopiert alles nach `public/` für GitLab Pages

### 5. CORS-Headers
Die `_headers` Datei wird automatisch erstellt für SharedArrayBuffer Support:
```
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Opener-Policy: same-origin
```

## Nach dem Fix
1. Commit & Push die Änderungen
2. Warte auf Pipeline-Erfolg
3. GitLab Pages sollten jetzt die Sprites korrekt laden
