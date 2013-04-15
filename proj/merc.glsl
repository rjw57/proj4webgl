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

/* Mercator inverse equations--mapping x,y to lat/long
--------------------------------------------------*/
vec2 merc_backwards(vec2 p, merc_params params)
{
    float x = p.x - params.x0;
    float y = p.y - params.y0;
    float lon, lat;

    if (0 != params.sphere) {
	lat =
	    HALF_PI -
	    2.0 * atan(exp(-y / (params.a * params.k0)));
    } else {
	float ts = exp(-y / (params.a * params.k0));
	lat = phi2z(params.e, ts);
	if (lat == -9999.) {
            return vec2(0.,0.);
	}
    }
    lon = adjust_lon(params.long0 + x / (params.a * params.k0));

    p.x = lon;
    p.y = lat;
    return p;
}

// vim:syntax=c:sw=4:sts=4:et
