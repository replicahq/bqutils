-- Internal JS UDF that accepts WKT string
CREATE OR REPLACE FUNCTION bqutils.geo._encode_openlr_wkt(
  wkt STRING,    -- LineString as WKT
  frc INT64,     -- Functional Road Class (0-7)
  fow INT64      -- Form of Way (0-7)
) RETURNS STRING -- base64 OpenLR code
LANGUAGE js
OPTIONS (
    library = ["https://storage.googleapis.com/bqutils.replicahq.com/openlr-js.min.js"],
    description = "Internal: encodes WKT LineString to OpenLR. Use bqutils.geo.encode_openlr instead."
)
AS r"""
  const EARTH_RADIUS_M = 6371000;
  const DEG_TO_RAD = Math.PI / 180;
  const RAD_TO_DEG = 180 / Math.PI;

  function parseWkt(wkt) {
    if (!wkt) return null;
    const match = wkt.match(/LINESTRING\s*\(\s*(.+)\s*\)/i);
    if (!match) return null;
    const coords = match[1].split(',').map(s => {
      const [lon, lat] = s.trim().split(/\s+/).map(parseFloat);
      return { lon, lat };
    }).filter(c => !isNaN(c.lon) && !isNaN(c.lat));
    return coords.length >= 2 ? coords : null;
  }

  function haversine(lat1, lon1, lat2, lon2) {
    const dLat = (lat2 - lat1) * DEG_TO_RAD;
    const dLon = (lon2 - lon1) * DEG_TO_RAD;
    const a = Math.sin(dLat/2)**2 + Math.cos(lat1*DEG_TO_RAD) * Math.cos(lat2*DEG_TO_RAD) * Math.sin(dLon/2)**2;
    return EARTH_RADIUS_M * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  }

  function bearing(lat1, lon1, lat2, lon2) {
    const dLon = (lon2 - lon1) * DEG_TO_RAD;
    const y = Math.sin(dLon) * Math.cos(lat2 * DEG_TO_RAD);
    const x = Math.cos(lat1 * DEG_TO_RAD) * Math.sin(lat2 * DEG_TO_RAD) -
              Math.sin(lat1 * DEG_TO_RAD) * Math.cos(lat2 * DEG_TO_RAD) * Math.cos(dLon);
    return (Math.atan2(y, x) * RAD_TO_DEG + 360) % 360;
  }

  function pathDistance(coords) {
    let d = 0;
    for (let i = 0; i < coords.length - 1; i++)
      d += haversine(coords[i].lat, coords[i].lon, coords[i+1].lat, coords[i+1].lon);
    return d;
  }

  try {
    if (frc < 0 || frc > 7 || fow < 0 || fow > 7) return null;
    const coords = parseWkt(wkt);
    if (!coords) return null;

    const dist = pathDistance(coords);
    const startBearing = bearing(coords[0].lat, coords[0].lon, coords[1].lat, coords[1].lon);
    const n = coords.length;
    const endBearing = bearing(coords[n-2].lat, coords[n-2].lon, coords[n-1].lat, coords[n-1].lon);

    const json = {
      type: "RawLineLocationReference",
      properties: {
        _id: "binary", _locationType: 1, _returnCode: null,
        _points: {
          type: "Array",
          properties: [
            { type: "LocationReferencePoint", properties: {
              _longitude: coords[0].lon, _latitude: coords[0].lat,
              _bearing: startBearing, _distanceToNext: Math.round(dist),
              _frc: frc, _fow: fow, _lfrcnp: frc, _isLast: false, _sequenceNumber: 1
            }},
            { type: "LocationReferencePoint", properties: {
              _longitude: coords[n-1].lon, _latitude: coords[n-1].lat,
              _bearing: endBearing, _distanceToNext: 0,
              _frc: frc, _fow: fow, _lfrcnp: 7, _isLast: true, _sequenceNumber: 2
            }}
          ]
        },
        _offsets: { type: "Offsets", properties: { _pOffset: 0, _nOffset: 0, _pOffRelative: 0, _nOffRelative: 0, _version: 3 }}
      }
    };

    const rawLoc = OpenLR.Serializer.deserialize(json);
    const encoder = new OpenLR.BinaryEncoder();
    return encoder.encodeDataFromRLR(rawLoc).getLocationReferenceData().toString('base64');
  } catch (e) { return null; }
""";

-- Public SQL wrapper that accepts GEOGRAPHY and converts to WKT
CREATE OR REPLACE FUNCTION bqutils.geo.encode_openlr(
  geometry GEOGRAPHY,  -- LineString
  frc INT64,           -- Functional Road Class (0-7)
  fow INT64            -- Form of Way (0-7)
)
RETURNS STRING
OPTIONS (
    description = """Encodes a GEOGRAPHY LineString to an OpenLR base64 string.

Parameters:
  - geometry: A GEOGRAPHY LineString (minimum 2 points)
  - frc: Functional Road Class (0=main road to 7=other)
  - fow: Form of Way (0=undefined, 1=motorway, 2=multiple carriageway,
         3=single carriageway, 4=roundabout, 5=traffic square, 6=sliproad, 7=other)

Example:
  SELECT bqutils.geo.encode_openlr(
    ST_GEOGFROMTEXT('LINESTRING(4.7538936 52.3748839, 4.7563336 52.3735839)'),
    6, 3
  ) as openlr_code;

Returns NULL if encoding fails."""
)
AS (
  bqutils.geo._encode_openlr_wkt(ST_ASTEXT(geometry), frc, fow)
);
