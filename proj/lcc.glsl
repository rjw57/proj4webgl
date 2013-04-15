/*******************************************************************************
NAME                            LAMBERT CONFORMAL CONIC

PURPOSE:	Transforms input longitude and latitude to Easting and
		Northing for the Lambert Conformal Conic projection.  The
		longitude and latitude must be in radians.  The Easting
		and Northing values will be returned in meters.


ALGORITHM REFERENCES

1.  Snyder, John P., "Map Projections--A Working Manual", U.S. Geological
    Survey Professional Paper 1395 (Supersedes USGS Bulletin 1532), United
    State Government Printing Office, Washington D.C., 1987.

2.  Snyder, John P. and Voxland, Philip M., "An Album of Map Projections",
    U.S. Geological Survey Professional Paper 1453 , United State Government
*******************************************************************************/


// Lambert Conformal Conic inverse equations--mapping x,y to lat/long
// -----------------------------------------------------------------
vec2 lcc_backwards(vec2 p, lcc_params params)
{

    float rh1, con, ts;
    float lat, lon;
    float x = (p.x - params.x0) / params.k0;
    float y = (params.rh - (p.y - params.y0) / params.k0);
    if (params.ns > 0.) {
	rh1 = sqrt(x * x + y * y);
	con = 1.0;
    } else {
	rh1 = -sqrt(x * x + y * y);
	con = -1.0;
    }
    float theta = 0.0;
    if (rh1 != 0.) {
	theta = atan((con * x), (con * y));
    }
    if ((rh1 != 0.) || (params.ns > 0.0)) {
	con = 1.0 / params.ns;
	ts = pow((rh1 / (params.a * params.f0)), con);
	lat = phi2z(params.e, ts);
	if (lat == -9999.)
	    return vec2(0.,0.);
    } else {
	lat = -HALF_PI;
    }
    lon = adjust_lon(theta / params.ns + params.long0);

    p.x = lon;
    p.y = lat;
    return p;
}


// vim:syntax=c:sw=4:sts=4:et
