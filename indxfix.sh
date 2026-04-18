for dir in */; do
  folder="${dir%/}"
  index="$folder/index.html"
  [ ! -f "$index" ] && continue

  # Fix relative sw.js
  sed -i "s|register('sw.js')|register('/my-pwa-apps/$folder/sw.js')|g" "$index"
  sed -i "s|register(\"sw.js\")|register(\"/my-pwa-apps/$folder/sw.js\")|g" "$index"

  # Fix /foldername/sw.js missing /my-pwa-apps/
  sed -i "s|register('/$folder/sw.js')|register('/my-pwa-apps/$folder/sw.js')|g" "$index"
  sed -i "s|register(\"/$folder/sw.js\")|register(\"/my-pwa-apps/$folder/sw.js\")|g" "$index"

  # Fix manifest link
  sed -i "s|href=\"manifest.json\"|href=\"/my-pwa-apps/$folder/manifest.json\"|g" "$index"
  sed -i "s|href='manifest.json'|href='/my-pwa-apps/$folder/manifest.json'|g" "$index"

  # Prom firebase special case
  if [ "$folder" = "prom" ]; then
    sed -i "s|getRegistration('/prom/firebase-messaging-sw.js')|getRegistration('/my-pwa-apps/prom/firebase-messaging-sw.js')|g" "$index"
    sed -i "s|register('/prom/firebase-messaging-sw.js')|register('/my-pwa-apps/prom/firebase-messaging-sw.js')|g" "$index"
  fi

  echo "[✓] $folder/index.html fixed"
done
