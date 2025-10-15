CREATE OR REPLACE FUNCTION bqutils.geo.decode_openlr(openLRString STRING)
RETURNS JSON
LANGUAGE js
OPTIONS (
    library
    = ["https://storage.googleapis.com/bqutils.replicahq.com/openlr-js.min.js"],
    description = """Example usage:
  SELECT bqutils.string.decode_openlr('CwNhbCU+jzPLAwD0/34zGw==') as decoded_location;
Output:
  {
    "properties": {
      "_id": "binary",
      "_locationType": 1,
      "_offsets": {
        "properties": {
          "_nOffRelative": 0,
          "_nOffset": 0,
          "_pOffRelative": 0,
          "_pOffset": 0,
          "_version": 3
        },
        "type": "n"
      },
      "_points": {
        "properties": [
          {
            "properties": {
              "_bearing": 129.375,
              "_distanceToNext": 205,
              "_fow": 3,
              "_frc": 6,
              "_isLast": false,
              "_latitude": 52.374883889902236,
              "_lfrcnp": 6,
              "_longitude": 4.7538936137926395,
              "_sequenceNumber": 1
            },
            "type": "s"
          },
          {
            "properties": {
              "_bearing": 309.375,
              "_distanceToNext": 0,
              "_fow": 3,
              "_frc": 6,
              "_isLast": true,
              "_latitude": 52.373583889902235,
              "_lfrcnp": 7,
              "_longitude": 4.7563336137926395,
              "_sequenceNumber": 2
            },
            "type": "s"
          }
        ],
        "type": "Array"
      },
      "_returnCode": null
    },
    "type": "a"
  }"""
)
AS r"""
  try {
    const binaryDecoder = new OpenLR.BinaryDecoder();
    const openLrBinary = OpenLR.Buffer.from(openLRString, 'base64');
    const locationReference = OpenLR.LocationReference.fromIdAndBuffer('binary', openLrBinary);
    const rawLocationReference = binaryDecoder.decodeData(locationReference);
    return OpenLR.Serializer.serialize(rawLocationReference);
  } catch (error) {
    return {
      error: 'Failed to decode OpenLR: ' + error.message
    };
  }
""";

CREATE OR REPLACE FUNCTION bqutils.geo.openlr_to_geography(openLRString STRING)
RETURNS GEOGRAPHY
OPTIONS (
    description = """Decodes an OpenLR string and returns a GEOGRAPHY linestring.

Example usage:
  SELECT bqutils.geo.openlr_to_geography('CwNhbCU+jzPLAwD0/34zGw==') as geom;

Returns a GEOGRAPHY linestring connecting all points in the decoded OpenLR location reference.
If decoding fails, returns NULL."""
)
AS (
  ST_MAKELINE(
    ARRAY(
      SELECT
        ST_GEOGPOINT(
          CAST(JSON_EXTRACT_SCALAR(point, '$.properties._longitude') AS FLOAT64),
          CAST(JSON_EXTRACT_SCALAR(point, '$.properties._latitude') AS FLOAT64)
        )
      FROM UNNEST(JSON_EXTRACT_ARRAY(bqutils.geo.decode_openlr(openLRString), '$.properties._points.properties')) as point
    )
  )
);
