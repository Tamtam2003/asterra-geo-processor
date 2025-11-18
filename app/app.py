
import os
import json
import logging

import boto3
import geopandas as gpd
from flask import Flask, jsonify, request
from shapely.geometry import shape
import psycopg2


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
s3 = boto3.client("s3")


def get_db_connection():
    conn = psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ.get("DB_NAME", "postgres"),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        sslmode="require",
    )
    return conn


def process_geojson(bucket: str, key: str):
    """
    1. מוריד GeoJSON מ-S3.
    2. בודק שהוא FeatureCollection.
    3. מכניס נקודות לטבלת cities ב-PostGIS.
    """

    logger.info("Downloading %s/%s from S3", bucket, key)
    obj = s3.get_object(Bucket=bucket, Key=key)
    body = obj["Body"].read()
    data = json.loads(body)

    if data.get("type") != "FeatureCollection":
        raise ValueError("GeoJSON must be a FeatureCollection")

    features = data["features"]
    geometries = [shape(f["geometry"]) for f in features]
    properties = [f.get("properties", {}) for f in features]

    gdf = gpd.GeoDataFrame(properties, geometry=geometries, crs="EPSG:4326")

    conn = get_db_connection()
    cur = conn.cursor()

    inserted = 0
    for _, row in gdf.iterrows():
        if row.geometry.geom_type != "Point":
            logger.info("Skipping non-point feature")
            continue

        name = row.get("name", "unknown")
        population = row.get("population", 0)

        wkt = row.geometry.wkt
        cur.execute(
            """
            INSERT INTO cities (name, population, geom)
            VALUES (%s, %s, ST_GeomFromText(%s, 4326))
            """,
            (name, population, wkt),
        )
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()

    logger.info("Inserted %d rows into cities", inserted)
    return inserted


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/process", methods=["POST"])
def process_handler():
    """
    מקבל JSON:
    {
      "bucket": "my-bucket",
      "key": "path/to/file.geojson"
    }
    ואז קורא ל-process_geojson
    """
    payload = request.get_json() or {}
    bucket = payload.get("bucket")
    key = payload.get("key")

    if not bucket or not key:
        return jsonify({"error": "bucket and key are required"}), 400

    try:
        inserted = process_geojson(bucket, key)
        return jsonify({"status": "ok", "inserted": inserted}), 200
    except Exception as e:
        logger.exception("Error processing geojson")
        return jsonify({"status": "error", "error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
