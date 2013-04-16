/*******************************************************************************
NAME                            MERCATOR

PURPOSE:	Transforms input longitude and latitude to Easting and
		Northing for the Mercator projection.  The
		longitude and latitude must be in radians.  The Easting
		and Northing values will be returned in meters.

PROGRAMMER              DATE
----------              ----
D. Steinwand, EROS      Nov, 1991
T. Mittan		Mar, 1993

ALGORITHM REFERENCES

1.  Snyder, John P., "Map Projections--A Working Manual", U.S. Geological
    Survey Professional Paper 1395 (Supersedes USGS Bulletin 1532), United
    State Government Printing Office, Washington D.C., 1987.

2.  Snyder, John P. and Voxland, Philip M., "An Album of Map Projections",
    U.S. Geological Survey Professional Paper 1453 , United State Government
    Printing Office, Washington D.C., 1989.
*******************************************************************************/

/* Mercator forward equations--mapping lat,long to x,y
  --------------------------------------------------*/
vec2 merc_forwards(vec2 p, merc_params params)
{
    float lon = p.x;
    float lat = p.y;
    // convert to radians
    if (lat * R2D > 90.0 &&
	lat * R2D < -90.0 && lon * R2D > 180.0 && lon * R2D < -180.0) {
	return vec2(0., 0.);
    }

    float x, y;
    if (abs(abs(lat) - HALF_PI) <= EPSLN) {
	// Proj4js.reportError("merc:forward: ll2mAtPoles");
	return vec2(0., 0.);
    } else {
	if (0 != params.sphere) {
	    x = params.x0 + params.a * params.k0 * adjust_lon(lon -
							      params.
							      long0);
	    y = params.y0 +
		params.a * params.k0 * log(tan(FORTPI + 0.5 * lat));
	} else {
	    float sinphi = sin(lat);
	    float ts = tsfnz(params.e, lat, sinphi);
	    x = params.x0 + params.a * params.k0 * adjust_lon(lon -
							      params.
							      long0);
	    y = params.y0 - params.a * params.k0 * log(ts);
	}
	p.x = x;
	p.y = y;
	return p;
    }
}

/* Mercator inverse equations--mapping x,y to lat/long
--------------------------------------------------*/
vec2 merc_backwards(vec2 p, merc_params params)
{
    float x = p.x - params.x0;
    float y = p.y - params.y0;
    float lon, lat;

    if (0 != params.sphere) {
	lat = HALF_PI - 2.0 * atan(exp(-y / (params.a * params.k0)));
    } else {
	float ts = exp(-y / (params.a * params.k0));
	lat = phi2z(params.e, ts);
	if (lat == -9999.) {
	    return vec2(0., 0.);
	}
    }
    lon = adjust_lon(params.long0 + x / (params.a * params.k0));

    p.x = lon;
    p.y = lat;
    return p;
}

// vim:syntax=c:sw=4:sts=4:et
