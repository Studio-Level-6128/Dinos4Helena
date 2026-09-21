# Environment model sources

These self-contained GLB models are published by 3DAssets.dev under the Creative Commons CC0 1.0 Universal public-domain dedication. They may be used, modified, and distributed commercially without attribution. Source links are retained here for provenance.

| Local file | Asset | Source | Original size |
| --- | --- | --- | --- |
| `araucaria_conifer.glb` | Araucaria-style Conifer, Primeval Frontier | https://3dassets.dev/assets/primeval-frontier-araucaria-conifer-98083967 | 4.46 × 5.567 × 3.978 m |
| `forest_fern.glb` | Forest Floor Fern, Primeval Frontier | https://3dassets.dev/assets/primeval-frontier-forest-floor-fern-2dbb2626 | 2.223 × 0.616 × 2.068 m |
| `mossy_basalt_rock.glb` | Moss-capped Basalt Boulder, Primeval Frontier | https://3dassets.dev/assets/primeval-frontier-basalt-boulder-9e710885 | 2.219 × 1.573 × 1.744 m |
| `cycad.glb` | Cycad, Botanical Glasshouse and Palm House | https://3dassets.dev/assets/botanical-glasshouse-and-palm-house-botanical-glasshou-a3fc5c9e | 1.485 × 0.669 × 1.505 m |
| `forest_undergrowth.glb` | Forest Undergrowth Clump, FPS Survival Forest Outpost | https://3dassets.dev/assets/fps-survival-forest-outpost-undergrowth-clump-d68b2daa | 1.94 × 0.762 × 1.789 m |
| `grass_cluster.glb` | Tall Grass Tuft Cluster, Safari Camp and Bush Lodge | https://3dassets.dev/assets/safari-camp-and-bush-lodge-grass-tuft-cluster-8eaa2b17 | 1.593 × 0.718 × 1.336 m |
| `tree_fern.glb` | Tree fern, Botanical Glasshouse and Palm House | https://3dassets.dev/assets/botanical-glasshouse-and-palm-house-botanical-glasshou-50b3c76a | 2.873 × 2.461 × 2.571 m |
| `dead_tree_snag.glb` | Dead Tree Snag, Primeval Frontier | https://3dassets.dev/assets/primeval-frontier-dead-tree-snag-1ef0c535 | 2.123 × 3.535 × 1.92 m |
| `fallen_rainforest_log.glb` | Fallen Log, Jungle Temple and Stone City | https://3dassets.dev/assets/jungle-temple-and-stone-city-fallen-log-b1bcdf2f | 6.87 × 1.451 × 1.843 m |
| `horsetail_colony.glb` | Horsetail Colony, Primeval Frontier | https://3dassets.dev/assets/primeval-frontier-horsetail-colony-e86061a3 | 1.232 × 1.41 × 1.242 m |
| `fiddlehead_cluster.glb` | Fiddlehead Cluster, Primeval Frontier | https://3dassets.dev/assets/primeval-frontier-fiddlehead-cluster-5204256c | 1.048 × 1.037 × 0.94 m |

License: https://creativecommons.org/publicdomain/zero/1.0/

Some source pages disclose AI assistance in model creation. All downloaded files remain CC0 and are stored locally; the game makes no runtime network requests.

The upstream files use `KHR_mesh_quantization`, which this project's Godot build does not import. `scripts/download-environment-assets.sh` reproducibly dequantizes geometry with the MIT-licensed glTF Transform CLI 3.10.1. This is a lossless compatibility conversion; materials, embedded textures, dimensions, and model topology are retained.
