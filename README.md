# IGLESIA — Godot 4.6 / Android landscape

**Comienzo limpio, 20 de octubre de 2026.** Proyecto INDEPENDIENTE de código Virin, Quake y NZ:P. No importar escenas, menús, movimiento ni controladores viejos. El material histórico es *referencia*, no autoridad runtime.

## Primer vertical slice
- Nave nueva construida con nodos Godot 3D, suelo y paredes sólidos, pasillo central y corredores laterales.
- 14 bancos con colisión simple y altar con colisión real (no atravesable).
- AStarGrid2D bloquea bancos/altar para navegación de zombies, rondas continuas, hitscan y economía mínima.
- FPS WASD/mouse o toque Android en paisaje; sprint y recarga son independientes (correr NO cancela recarga).
- Viewmodel **2D** MP40: se muestra SOLO si los fotogramas de calidad aprobados están importados. Nunca se inventa un arma 3D ni se declara final un placeholder.
- Botones táctiles: solo texturas oficiales recuperadas en GitHub; el texto de respaldo sirve para probar entradas, no es diseño aprobado.

## Fuentes verificadas, no copiadas a ciegas
- Iglesia/Tripo: `config-old-3`, rama `feature/sanctum-ash-tripo-furniture-swap-20261020`, ruta `xogot/assets/environment/church`. Contiene `altar.glb`, `bench.glb`, arquitectura GLB y 4K stone wall (albedo/normal/roughness).
- Touch PNG originales: `config-old-3`, commit `0119c5b0f9109c4c88dbdd4173a9a2ba523abc3d`, ruta `assets/xziel/official_touch_skins_v1`.
- MP40 2D: `XZombie`, rama `experiment/nun-universal-bone2d-hands-v1-20261019`, `bukkbeek-mobile/pixel_assets/WWII MP40 Pixel Art Sprite Sheet.png`, 1448×1086, división 3×3.
- Investigación: `temp-files-2/docs/zombies-design-research`; mapa/horror: `config-old-3/docs`.
- `hayuya-studio` para pipeline futuro de arte; `legacy-cache-staging-03` para herramientas/contratos; `Drag-mini` es otro juego, sin fuentes Zombies reutilizables. **APEX no se tocó.**

## Importación y QA
`python3 tools/ingest_assets.py` obtiene los assets originales y separa los fotogramas sin redibujarlos. Importa GLB **solo bajo gate**; los modelos de Tripo (~millones de triángulos por modelo) requieren reducción LOD antes de distribuir APK móvil. La escena funciona sin esos binarios con geometría de validación explícitamente provisional.

`godot --headless --path . --editor --import --quit`
`godot --headless --path . --script res://tests/smoke.gd`

**Estado**: código de primer vertical slice. No se debe llamar APK final ni optimización AAA hasta obtener GREEN en CI, comparar fotogramas reales y probar en teléfono. No se reutilizaron mapas viejos.
