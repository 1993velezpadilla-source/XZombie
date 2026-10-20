# IGLESIA — Godot 4.6 / Android landscape

**Comienzo limpio, 20 de octubre de 2026.** Proyecto INDEPENDIENTE de código Virin, Quake y NZ:P. No importar escenas, menús, movimiento ni controladores viejos. El material histórico es *referencia*, no autoridad runtime.

## Primer vertical slice
- Nave nueva construida con nodos Godot 3D, suelo y paredes sólidos, pasillo central y corredores laterales.
- **14 bancos reales Tripo y altar real Tripo** (solo originales del usuario): bounds de cada mesh anidada transformados con sus 8 esquinas y medidos en espacio local del collider para ajustar el tamaño real **y subir cada base al suelo, y=0**. Altar orientado hacia la nave; collider 4.8 × 1.65 × 2.7 m. Cada banco validado individualmente en CI.
- AStarGrid2D bloquea bancos/altar para navegación de zombies, rondas continuas, hitscan y economía mínima.
- FPS WASD/mouse o toque Android en paisaje; sprint y recarga son independientes (correr NO cancela recarga).
- **MP40 artstyle 3 NUEVA**: 13 PNG transparentes 960×720, ilustración original estilizada 2.5D construida directamente en código editable `tools/draw_nun_mp40_v3.py` (NO otro recorte/recolor del arma militar antigua). Incluye dos manos pálidas y uñas oscuras de la monja, mangas negras con puño claro, HIP/ADS centrados ópticamente, fogonazo, sprint y 4 fases de recarga normal y en vacío con carga del cerrojo solo en vacío. La calidad artística requiere inspección en móvil antes de aprobarse.
- Botones táctiles independientes **FIRE**, **AIM** (toggle), y **AIM+FIRE** (hold simultáneo), además recarga/interact/jump; multitouch por identificador de dedo y arrastre para cámara sin cancelar disparo. **Android rechaza explícitamente el LEFT MOUSE sintético que genera al tocar cualquier área**: cámara/joystick/HUD no disparan. CI inyecta mouse sintético y finger touch adversarial para evitar regresión.

## Fuentes verificadas, no copiadas a ciegas
- Iglesia/Tripo: `config-old-3`, rama `feature/sanctum-ash-tripo-furniture-swap-20261020`, ruta `xogot/assets/environment/church`. Contiene `altar.glb`, `bench.glb`, arquitectura GLB y 4K stone wall (albedo/normal/roughness).
- Touch PNG originales: `config-old-3`, commit `0119c5b0f9109c4c88dbdd4173a9a2ba523abc3d`, ruta `assets/xziel/official_touch_skins_v1`.
- MP40 nuevo (tercer artstyle): vector drawing code editable `tools/draw_nun_mp40_v3.py`. Conservamos la investigación del paquete `XZombie` como referencia histórica, pero **la nueva build NO usa su viejo sprite sheet ni sus manos militares**.
- Investigación: `temp-files-2/docs/zombies-design-research`; mapa/horror: `config-old-3/docs`.
- `hayuya-studio` para pipeline futuro de arte; `legacy-cache-staging-03` para herramientas/contratos; `Drag-mini` es otro juego, sin fuentes Zombies reutilizables. **APEX no se tocó.**

## Importación y QA
`python3 tools/ingest_assets.py` verifica por SHA de objeto Git los PNG originales y los 4 WAV auténticos de MP40. **Disparo**: Project Aether `config-old-3/xogot/assets/audio/weapons/mapmod/mp40/fire.wav`. **Recarga**: `XZombie/bukkbeek-mobile/audio/aether/mp40/{mag_out,mag_in,charge}.wav`. Al recargar vacío, añade carga; al recargar con balas, no. No se inventan efectos.

La validación y el Android preview ejecutan `python3 tools/ingest_assets.py --with-furniture`: incluye originales Tripo `altar.glb` + `bench.glb`, miden y colocan sus auténticos meshes en runtime, no importa arquitectura de otro mapa. Es un **gate de fidelidad**, todavía no hay LOD móvil validado: render/fps/colisiones/escala deben probarse físicamente en teléfono. La validación de scripts usa geometría de respaldo; producción no debe sustituir arte hero por cajas.

`godot --headless --path . --editor --import --quit`
`godot --headless --path . --script res://tests/smoke.gd`

**Estado**: vertical slice nuevo, artstyle 3 en revisión. CI valida archivo de los 13 sprites, fuente WAV, HUD y rechazo ghost-fire, reload-sprint, todas las 14 piezas Tripo sobre suelo, dimensión y dirección altar. GREEN no significa FPS móvil, aprobación estética de nueva MP40 ni APK final de producción. Derechos de redistribución de los archivos del juego de origen pendientes de confirmar. No se reutilizaron mapas viejos.
