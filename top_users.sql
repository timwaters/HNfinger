WITH
    512 AS vec_size,
    toDateTime('2023-01-01 00:00:00') AS cutoff,
    24 AS batch_count,
    0 AS batch_number,

    first_versions AS
    (
        SELECT
            id,

            argMin(
                tuple(by, time, text, deleted, dead),
                update_time
            ) AS first_version

        FROM hackernews_history
        WHERE type = 'comment'
          AND by != ''
          AND cityHash64(by) % batch_count = batch_number

        GROUP BY id
    ),
    
    comments AS
    (
        SELECT
            id,
            first_version.1 AS author,
            first_version.2 AS comment_time,
            first_version.3 AS comment_text

        FROM first_versions

        WHERE first_version.4 = 0
          AND first_version.5 = 0
          AND first_version.1 != ''
          AND trimBoth(first_version.3) != ''
          AND lower(
              trimBoth(first_version.3)
          ) NOT IN ('[flagged]', '[dead]')
    ),

    bucket_counts AS
    (
        SELECT
            author AS name,

            toStartOfInterval(
                comment_time,
                INTERVAL 6 MONTH
            ) AS half_year,

            cityHash64(
                arrayJoin(
                    tokens(
                        lower(
                            decodeHTMLComponent(
                                extractTextFromHTML(comment_text)
                            )
                        )
                    )
                )
            ) % vec_size AS bucket,

            count() AS n

        FROM comments
        GROUP BY name, half_year, bucket
    ),

    eligible_buckets AS
    (
        SELECT name, half_year, bucket, n
        FROM
        (
            SELECT
                name,
                half_year,
                bucket,
                n,

                sum(n) OVER (
                    PARTITION BY name, half_year
                ) AS period_token_count

            FROM bucket_counts
        )
        WHERE period_token_count > 500
    ),

    user_counts AS
    (
        SELECT
            name,

            uniqExactIf(
                half_year,
                half_year < cutoff
            ) AS before_periods,

            uniqExactIf(
                half_year,
                half_year >= cutoff
            ) AS after_periods,

            sumIf(
                n,
                half_year < cutoff
            ) AS before_tokens,

            sumIf(
                n,
                half_year >= cutoff
            ) AS after_tokens,

            sumMapIf(
                [bucket],
                [n],
                half_year < cutoff
            ) AS before_counts,

            sumMapIf(
                [bucket],
                [n],
                half_year >= cutoff
            ) AS after_counts

        FROM eligible_buckets
        GROUP BY name

        HAVING before_periods >= 3
           AND after_periods >= 3
    ),

    user_vectors AS
    (
        SELECT
            name,
            before_tokens,
            after_tokens,
            before_periods,
            after_periods,

            mapFromArrays(
                before_counts.1,
                before_counts.2
            ) AS before_histogram,

            mapFromArrays(
                after_counts.1,
                after_counts.2
            ) AS after_histogram,

            arrayMap(
                i -> toFloat64(
                    before_histogram[toUInt64(i)]
                ),
                range(vec_size)
            ) AS before_vec,

            arrayMap(
                i -> toFloat64(
                    after_histogram[toUInt64(i)]
                ),
                range(vec_size)
            ) AS after_vec

        FROM user_counts
    ),

    scored AS
    (
        SELECT
            name,
            before_tokens,
            after_tokens,
            before_periods,
            after_periods,

            cosineDistance(
                before_vec,
                after_vec
            ) AS distance

        FROM user_vectors
    )

SELECT
    name,
    before_periods,
    after_periods,
    before_tokens,
    after_tokens,
    distance AS raw_distance,

    round(
        100 * (1 - distance),
        3
    ) AS after_2023_similarity_score,

    round(
        100 * distance,
        3
    ) AS difference_from_before

FROM scored
ORDER BY distance DESC, name ASC
LIMIT 200;
