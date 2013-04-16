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

// Lambert Conformal conic forward equations--mapping lat,long to x,y
// -----------------------------------------------------------------
vec2 lcc_forwards(vec2 p, lcc_params params)
{

    float lon = p.x;
    float lat = p.y;

    // singular cases :
    if (abs(2. * abs(lat) - PI) <= EPSLN) {
	lat = sign(lat) * (HALF_PI - 2. * EPSLN);
    }

    float con = abs(abs(lat) - HALF_PI);
    float ts, rh1;
    if (con > EPSLN) {
	ts = tsfnz(params.e, lat, sin(lat));
	rh1 = params.a * params.f0 * pow(ts, params.ns);
    } else {
	con = lat * params.ns;
	if (con <= 0.) {
	    // Proj4js.reportError("lcc:forward: No Projection");
	    return vec2(0., 0.);
	}
	rh1 = 0.;
    }
    float theta = params.ns * adjust_lon(lon - params.long0);
    p.x = params.k0 * (rh1 * sin(theta)) + params.x0;
    p.y = params.k0 * (params.rh - rh1 * cos(theta)) + params.y0;

    return p;
}

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
	    return vec2(0., 0.);
    } else {
	lat = -HALF_PI;
    }
    lon = adjust_lon(theta / params.ns + params.long0);

    p.x = lon;
    p.y = lat;
    return p;
}


// vim:syntax=c:sw=4:sts=4:et
