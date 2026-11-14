# SploitGoldHEN 14.02 — source mirror

Mirror du host `https://sploitupdatedhen.pages.dev/` (Cloudflare Pages, clean URLs :
`/` = `index.html`, `/jb` = `jb.html`). PS4 firmware 14.02, chaîne WebKit
(slopkit-core) → stage kernel `afterglow` (apm-UAF) → payload `hen.bin` / `goldhen.bin`.

## Arborescence

```
index.html          landing : launch-shell, marque "SG", barre de progression
launch.js           redirige vers jb.html?log=1&afterglow=run&mode=goldhen
jb.html             page d'exécution, CSS inline (zéro subresource: le groom en dépend)
jb.js               orchestrateur : garde referrer, watchdog 45s, table de gadgets,
                    resolveur de stubs syscall, ROP, appel d'afterglow
core.js             primitive WebKit : UAF history.state, fake cell, addrof/rw 0x100
mem.js              promotion fake-cell → vraie paire ArrayBuffer, window.p (read/write)
int64.js            arithmétique 64 bits (low/hi u32)
ps4_offsets.js      table firmware 11.00 → 14.02 : gadgets, stubs, RVA kernel
afterglow.js        stage kernel 14.00/14.02, AGPL-3.0, copyright well0nez
style.css           thème bleu partagé (landing uniquement)
meme.png            image de la landing d'origine
cache.appcache      manifeste offline du host
patchset-XXXX.bin   blobs de patch kernel par firmware (641 o)
hen.bin             payload PS4-HEN (500 864 o)
goldhen.bin         payload actif (298 776 o, jmp rel32)
goldhen.bin.prev    payload alternatif, conservé
goldhen.bin.orig    payload d'origine du host
payloads\           les trois builds nommés par leur hash (pioche pour basculer)
serve.ps1           serveur statique
check-payload.ps1   préflight : octet 0, jmp, patchset, hash du manifeste
```

## Lancer

```powershell
cd D:\Télechargement\sploit\sploitgoldhen-1402
.\serve.ps1
```

Puis depuis le navigateur de la console : `http://<ip-du-pc>:8000/`.
Le bind LAN demande l'élévation (ou une URL ACL) ; sinon `serve.ps1` retombe en
loopback et le dit à l'écran.

## Payload : remplacer `goldhen.bin`

Le fichier en place est le payload fourni (`a_integrer\goldhen.bin`), l'original est
conservé en `goldhen.bin.orig`.

```
goldhen.bin        payload actif  — sha256 F59CB7EF262D8D49718C0A8D9F277A2B96FD16D6AE34A4EF4F211C836CCB6D26
goldhen.bin.prev   payload précédent — sha256 E1BDFC405EE959DD2F1D3D58E2EDE6E2DECDFD03BE9A1780FB446B86E06E1E8C

payloads\goldhen-F59CB7.bin   actif
payloads\goldhen-E1BDFC.bin   build précédent
payloads\goldhen-E20AD8.bin   build antérieur
payloads\goldhen-C54805.bin   build antérieur
payloads\goldhen-E4190C.bin   autre build (testé, écarté)
payloads\goldhen-FD6805.bin   payload d'origine du host
```

Les quatre font 298 776 o et commencent par `e9 a6 16 00 00`. Basculer d'un build à
l'autre, sans toucher au reste :

```powershell
Copy-Item .\payloads\goldhen-E20AD8.bin .\goldhen.bin -Force
# puis régénérer le hash de cache.appcache (ou relancer check-payload.ps1 pour le voir)
```

Avant de servir, la vérification qui rejoue les tests d'`afterglow.js` :

```powershell
.\check-payload.ps1 -File goldhen.bin -Mode goldhen -Firmware 14.02
```

Il contrôle : octet 0 / cible du jmp rel32, longueur composite `964440`, présence et
taille du `patchset-<fw>.bin`, et la cohérence du hash dans `cache.appcache`.
Sortie non nulle = ne pas lancer la console.

## Notes de la chaîne

- `jb.js` refuse de s'armer sans referrer venant de `index.html` du même dossier :
  une page restaurée par le navigateur ne relance pas la chaîne sans personne devant l'écran.
- Firmware sans stage kernel → refus avant tout accès mémoire (`FW-UNSUPPORTED`).
- `?attempts=N` (défaut 8) borne les essais WebKit, `?mem=1..5` choisit le profil de heap,
  `?probe=1` sonde sans patcher, `?stop=primitive` s'arrête après la primitive.
- `jb.html` ne charge aucun sous-ressource, volontairement : chaque allocation décale le groom.
- `?log=1` affiche le journal d'étapes ; `#ramBox` poll les compteurs heap toutes les 500 ms.

## Récupérer à nouveau

```powershell
$base = "https://sploitupdatedhen.pages.dev/"
$files = @("","jb","style.css","launch.js","jb.js","core.js","mem.js","int64.js",
           "ps4_offsets.js","afterglow.js","cache.appcache","meme.png",
           "hen.bin","goldhen.bin")
foreach ($f in $files) {
  $out = if ($f -eq "") { "index.html" } elseif ($f -eq "jb") { "jb.html" } else { $f }
  Invoke-WebRequest -Uri ($base + $f) -OutFile $out -UseBasicParsing
}
1..1402 | ForEach-Object { } # patchsets : patchset-<fw>.bin
```
