WITH
    'HN_USERNAME' AS target_author,
    512 AS vec_size,
    toDateTime('2023-01-01 00:00:00') AS cutoff,

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
          AND by = target_author
        GROUP BY id
    ),

    comments AS
    (
        SELECT
            id,
            first_version.2 AS comment_time,
            first_version.3 AS comment_text

        FROM first_versions

        WHERE first_version.4 = 0
          AND first_version.5 = 0
          AND trimBoth(first_version.3) != ''
          AND lower(
              trimBoth(first_version.3)
          ) NOT IN ('[flagged]', '[dead]')
    ),

    bucket_counts AS
    (
        SELECT
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
        GROUP BY half_year, bucket
    ),

    eligible_buckets AS
    (
        SELECT half_year, bucket, n
        FROM
        (
            SELECT
                half_year,
                bucket,
                n,

                sum(n) OVER (
                    PARTITION BY half_year
                ) AS period_token_count

            FROM bucket_counts
        )
        WHERE period_token_count > 500
    ),

    labelled_buckets AS
    (
        SELECT
            arrayJoin(
                [
                    concat('half_year:', toString(half_year)),
                    if(
                        half_year < cutoff,
                        'before_2023',
                        'after_2023'
                    )
                ]
            ) AS period,
            bucket,
            n

        FROM eligible_buckets
    ),

    combined_buckets AS
    (
        SELECT
            period,
            bucket,
            sum(n) AS n

        FROM labelled_buckets
        GROUP BY period, bucket
    ),

    profiles AS
    (
        SELECT
            period,
            sum(n) AS token_count,

            mapFromArrays(
                groupArray(bucket),
                groupArray(n)
            ) AS histogram,

            arrayMap(
                i -> toFloat64(
                    histogram[toUInt64(i)]
                ),
                range(vec_size)
            ) AS vec

        FROM combined_buckets
        GROUP BY period
    ),

    baseline AS
    (
        SELECT vec
        FROM profiles
        WHERE period = 'before_2023'
    )

SELECT
    p.period,
    p.token_count,

    round(
        100 * (1 - cosineDistance(p.vec, b.vec)),
        3
    ) AS similarity_score,

    round(
        100 * cosineDistance(p.vec, b.vec),
        3
    ) AS difference_from_before

FROM profiles AS p
CROSS JOIN baseline AS b

ORDER BY
    if(startsWith(p.period, 'half_year:'), 1, 0),
    p.period;