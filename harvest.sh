#!/bin/bash

function http() {
    local url="https://api.droplabs.pl/user-api/facilities/1073/online_groups/13211/$1"
    curl -s "$url"
}

export -f http

NOW=`date -u +"%Y-%m-%d/%H:%M:%S"`
OUTPUT="data/$NOW"

mkdir -p "$OUTPUT"

http "activities" \
    > "$OUTPUT/activities.raw.json"

cat "$OUTPUT/activities.raw.json" \
    | jq '.[] | { id, name, variants: [ .variants[] | { id, name } ] }' \
    | jq -s \
    | jq '[ .[] | select(.id == 14590) ]' \
    > "$OUTPUT/activities.ids.json"

cat "$OUTPUT/activities.ids.json" \
    | jq -c '.[]' \
    | while read -r line
        do
            activity_id=`echo $line | jq '.id'`

            echo $line \
            | jq -c '.variants[]' \
            | jq '.id' \
            | while read -r variant_id
                do
                    if [ $variant_id != 32793 ]
                    then
                        continue
                    fi

                    echo $activity_id : $variant_id

                    http "activities/$activity_id/admission_date_day_offers?activityVariants=$variant_id&locale=en&sinceDate=2025-01-01&untilDate=2025-01-31" \
                        > "$OUTPUT/activities-dates-$activity_id-$variant_id.raw.json"

                    cat "$OUTPUT/activities-dates-$activity_id-$variant_id.raw.json" \
                        | jq '[ .[] | select(.isAvailable == true) ]' \
                        > "$OUTPUT/activities-dates-$activity_id-$variant_id.ids.json"

                    cat "$OUTPUT/activities-dates-$activity_id-$variant_id.ids.json" \
                        | jq -r '.[].date' \
                        | while read -r date_id
                            do
                                http "activities/$activity_id/admission_dates?activityVariants=$variant_id&locale=en&sinceDate=$date_id&untilDate=$date_id" \
                                    > "$OUTPUT/activities-offers-$activity_id-$variant_id-$date_id.raw.json"

                                cat "$OUTPUT/activities-offers-$activity_id-$variant_id-$date_id.raw.json" \
                                    | jq '[ .[] | select(.isAvailable == true) ]' \
                                    | jq '.[] | { date, numberOfSeats }' \
                                    | jq -s \
                                    > "$OUTPUT/activities-offers-$activity_id-$variant_id-$date_id.ids.json"
                            done
                done
        done
