# BoumPif

Premier prototype de bac à sable 3D avec Godot 4, GDScript et rendu Compatibility.

## Jouer sur Windows

Ouvrir `boum-pif/project.godot` dans Godot 4.6 ou ultérieur, puis appuyer sur **F5**.
La scène principale est `scenes/main.tscn`. Le quartier et ses collisions sont créés par `scripts/main.gd`.

- ZQSD, WASD ou flèches : marcher / conduire.
- Souris : regarder autour de soi.
- E : monter dans la voiture orange à proximité, ou descendre une fois arrêté.
- Espace : sauter à pied, freiner en voiture.
- R : remettre le personnage et la voiture au départ.
- Échap : libérer la souris ; clic dans le jeu : la capturer.

La conduite est arcade, avec une voiture qui reste droite : pas encore de suspension,
de dégâts, de circulation ou de sauvegarde. Si une sortie est bloquée, le jeu essaie
l'autre côté du véhicule. La ville est délimitée par des murs.

## Validation

Depuis la racine du dépôt, avec Godot accessible dans le terminal :

```sh
godot --headless --path boum-pif --editor --import --quit
godot --headless --path boum-pif --script res://tests/smoke.gd
```

Le test vérifie le sol, la marche, l'entrée et la sortie de voiture, la conduite,
le freinage, les collisions avec les bâtiments et la limite de ville, et la réinitialisation.
La qualité visuelle et les sensations de conduite restent à évaluer dans l'éditeur.
