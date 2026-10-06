import csv
import json
import os
import re
from pathlib import Path

import requests

BATCH_COUNT = 24

template = Path("top_users.sql").read_text()

def replace_constant(sql, name, value):
    sql, replacements = re.subn(
        rf"\b\d+\s+AS\s+{name}\b",
        f"{value} AS {name}",
        sql,
        count=1,
        flags=re.IGNORECASE,
    )
    if replacements != 1:
        raise ValueError(f"Could not find constant: {name}")
    return sql

template = replace_constant(
    template, "batch_count", BATCH_COUNT
)

rows = []

with requests.Session() as session:
    for batch in range(BATCH_COUNT):
        sql = replace_constant(
            template, "batch_number", batch
        )

        # The saved query should not already have a FORMAT clause.
        sql = sql.rstrip().rstrip(";")
        sql += "\nFORMAT JSONEachRow"

        print(f"Running batch {batch + 1}/{BATCH_COUNT}...")

        response = session.post(
            "https://play.clickhouse.com/",
             params={
                "user": "play",
                "password": "",
            },
            data=sql.encode("utf-8"),
            timeout=900,
        )
     

        if not response.ok:
            raise RuntimeError(
                f"Batch {batch} failed:\n{response.text}"
            )

        batch_rows = [
            json.loads(line)
            for line in response.text.splitlines()
            if line.strip()
        ]

        rows.extend(batch_rows)
        print(f"  Returned {len(batch_rows)} users")

        # save the progress
        Path(f"batch_{batch:02d}.json").write_text(
            json.dumps(batch_rows, indent=2)
        )

# Match the SQL ordering, using the unrounded score.
rows.sort(
    key=lambda row: (
        -float(row["raw_distance"]),
        row["name"],
    )
)

top_100 = rows[:100]

if top_100:
    with open(
        "top_100.csv", "w", newline="", encoding="utf-8"
    ) as output:
        writer = csv.DictWriter(
            output,
            fieldnames=list(top_100[0].keys()),
        )
        writer.writeheader()
        writer.writerows(top_100)

    print(f"Saved {len(top_100)} users to top_100.csv")
else:
    print("No qualifying users found.")