jq -c '.[] | select(
        .downloaded == false and 
        (.skip_reason == null or .skip_reason == "") and
        .available != false and
        .snapped == false
    )| .id' videos.json
