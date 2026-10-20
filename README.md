# IGLESIA — Godot 4.6 / Android landscape

**Comienzo limpio, 20 de octubre de 2026.** Proyecto INDEPENDIENTE de código Virin, Quake y NZ:P. No importar escenas, menús, movimiento ni controladores viejos. El material histórico es *referencia*, no autoridad runtime.

## Primer vertical slice
- Nave nueva construida con nodos Godot 3D, suelo y paredes sólidos, pasillo central y corredores laterales.
- 14 bancos con colisión simple y altar con colisión real (no atravesable). El altar apunta hacia la congregación (+Z), sobre la nave nueva, y la colisión es 4.8 × 1.65 × 2.7 m.
- AStarGrid2D bloquea bancos/altar para navegación de zombies, rondas continuas, hitscan y economía mínima.
- FPS WASD/mouse o toque Android en paisaje; sprint y recarga son independientes (correr NO cancela recarga).
- Viewmodel **2D/2.5D** MP40: HIP frontal (origen XZombie aprobado) alineado por punto óptico al centro, retocado con paleta oscura/ piel pálida y fogonazo de prueba. ADS alineado mediante alza real, no por marco del PNG. **El repintado automático de manos aún requiere aprobación visual**, no afirmar calidad final.
- Botones táctiles independientes **FIRE**, **AIM** (toggle), y **AIM+FIRE** (hold simultáneo), además recarga/interact/jump; multitouch por identificador de dedo y arrastre para cámara sin cancelar disparo. Solo iconos oficiales XZIEL; texto es fallback de depuración.

## Fuentes verificadas, no copiadas a ciegas
- Iglesia/Tripo: `config-old-3`, rama `feature/sanctum-ash-tripo-furniture-swap-20261020`, ruta `xogot/assets/environment/church`. Contiene `altar.glb`, `bench.glb`, arquitectura GLB y 4K stone wall (albedo/normal/roughness).
- Touch PNG originales: `config-old-3`, commit `0119c5b0f9109c4c88dbdd4173a9a2ba523abc3d`, ruta `assets/xziel/official_touch_skins_v1`.
- MP40 2D: `XZombie`, rama `experiment/nun-universal-bone2d-hands-v1-20261019`, `bukkbeek-mobile/pixel_assets/WWII MP40 Pixel Art Sprite Sheet.png`, 1448×1086, división 3×3.
- Investigación: `temp-files-2/docs/zombies-design-research`; mapa/horror: `config-old-3/docs`.
- `hayuya-studio` para pipeline futuro de arte; `legacy-cache-staging-03` para herramientas/contratos; `Drag-mini` es otro juego, sin fuentes Zombies reutilizables. **APEX no se tocó.**

## Importación y QA
`python3 tools/ingest_assets.py` verifica por SHA de objeto Git los PNG originales y los 4 WAV auténticos de MP40. **Disparo**: Project Aether `config-old-3/xogot/assets/audio/weapons/mapmod/mp40/fire.wav`. **Recarga**: `XZombie/bukkbeek-mobile/audio/aether/mp40/{mag_out,mag_in,charge}.wav`. Al recargar vacío, añade carga; al recargar con balas, no. No se inventan efectos.

El Android preview ejecuta `python3 tools/ingest_assets.py --with-furniture`: incluye originales Tripo `altar.glb` + `bench.glb`, no importa arquitectura de otro mapa. Es un **gate de fidelidad**, todavía no hay LOD móvil validado: render/fps/colisiones/escala deben probarse físicamente en teléfono. La validación de scripts usa geometría de respaldo; producción no debe sustituir arte hero por cajas.

`godot --headless --path . --editor --import --quit`
`godot --headless --path . --script res://tests/smoke.gd`

**Estado**: vertical slice revisado. Tests verifican fuente WAV, HUD, reload-sprint, eje de mira y altar (cuando GLB importado). CI GREEN no significa FPS móvil, aprobación de arte ni APK de producción. Derechos de redistribución de los archivos del juego de origen pendientes de confirmar. No se reutilizaron mapas viejos.
