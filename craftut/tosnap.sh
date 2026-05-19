jq -r '.[] | select(
      .downloaded == true and
      .snapped == false) | "\(.id): \(.title)"' videos.json
