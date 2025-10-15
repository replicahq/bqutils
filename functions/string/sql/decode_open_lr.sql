CREATE OR REPLACE FUNCTION bqutils.string.decode_openlr(openLRString STRING)
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
