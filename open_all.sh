#!/usr/bin/env bash
# Opens all 16 Chrome Web Store extension pages in tabs

URLS=(
    "https://chromewebstore.google.com/detail/gighmmpiobklfepjocnamgkkbiglidom"
    "https://chromewebstore.google.com/detail/efaidnbmnnnibpcajpcglclefindmkaj"
    "https://chromewebstore.google.com/detail/nfmlkliedggdodlbgghmmchhgckjoaml"
    "https://chromewebstore.google.com/detail/fchdfdnnpkphopmdaochdfnmcahndmnb"
    "https://chromewebstore.google.com/detail/fdpohaocaechififmbbbbbknoalclacl"
    "https://chromewebstore.google.com/detail/oocalbipljegheefhdjlglmimnigimjk"
    "https://chromewebstore.google.com/detail/ldgfbffkinooeloadekpmfoklnobpien"
    "https://chromewebstore.google.com/detail/gebbhagfogifgggkldgodflihgfeippi"
    "https://chromewebstore.google.com/detail/kpdjmbiefanbdgnkcikhllpmjnnllbbc"
    "https://chromewebstore.google.com/detail/mmioliijnhnoblpgimnlajmefafdfilb"
    "https://chromewebstore.google.com/detail/kdbmhfkmnlmbkgbabkdealhhbfhlmmon"
    "https://chromewebstore.google.com/detail/ioimlbgefgadofblnajllknopjboejda"
    "https://chromewebstore.google.com/detail/khncfooichmfjbepaaaebmommgaepoid"
    "https://chromewebstore.google.com/detail/nffaoalbilbmmfgbnbgppjihopabppdk"
    "https://chromewebstore.google.com/detail/jghecgabfgfdldnmbfkhmffcabddioke"
    "https://chromewebstore.google.com/detail/idcemhhjdleodchiihagkfehahofmibc"
)

echo "Opening all 16 extensions in your browser..."

for url in "${URLS[@]}"; do
    if [[ "$(uname -s)" == "Darwin" ]]; then
        open "$url"
    else
        xdg-open "$url" >/dev/null 2>&1 || true
    fi
done

echo "Done!"
