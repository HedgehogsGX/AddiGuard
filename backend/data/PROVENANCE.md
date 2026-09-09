# Open Food Facts additive taxonomy snapshot

`additives.txt` is an unmodified raw taxonomy from Open Food Facts and its
contributors, downloaded successfully on 2026-09-09 from:

https://raw.githubusercontent.com/openfoodfacts/openfoodfacts-server/main/taxonomies/additives.txt

Size: 1,114,164 bytes.

SHA-256: `e30d5ad1316f8ecdaa3710e7b1632437c206843d0f9ff28b2068cd2dfe5445a5`

Source project: https://openfoodfacts.org and
https://github.com/openfoodfacts/openfoodfacts-server.

Open Food Facts publishes its database under the Open Database License (ODbL)
1.0 and individual database contents under the Database Contents License:
https://world.openfoodfacts.org/data and
https://world.openfoodfacts.org/terms-of-use.
Attribution and applicable share-alike obligations must be retained on reuse.

The importer reads English entries with concrete E-numbers, including letter
and Roman-numeral subtypes. It skips wildcard codes and generic taxonomy
categories without an E-number. Escaped commas in synonyms are preserved.
Entries without an English descriptive name use their E-number as the name.
Names shared by distinct E-numbers are disambiguated with the code in the
database, while the original name remains an alias.

The snapshot supplies detection vocabulary only. It does not supply AddiGuard
risk factors; the five placeholder ratings remain solely in `seed.py`.
All newly imported additives have null risk factors.

To refresh, download the raw URL to `additives.txt`, update this provenance and
checksum, run importer and label tests, then restart the running API after
importing so that other processes discard their cached alias indexes.
