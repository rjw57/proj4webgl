/*******************************************************************************
NAME                     ALBERS CONICAL EQUAL AREA 

PURPOSE:	Transforms input longitude and latitude to Easting and Northing
		for the Albers Conical Equal Area projection.  The longitude
		and latitude must be in radians.  The Easting and Northing
		values will be returned in meters.

PROGRAMMER              DATE
----------              ----
T. Mittan,       	Feb, 1992

ALGORITHM REFERENCES

1.  Snyder, John P., "Map Projections--A Working Manual", U.S. Geological
    Survey Professional Paper 1395 (Supersedes USGS Bulletin 1532), United
    State Government Printing Office, Washington D.C., 1987.

2.  Snyder, John P. and Voxland, Philip M., "An Album of Map Projections",
    U.S. Geological Survey Professional Paper 1453 , United State Government
    Printing Office, Washington D.C., 1989.
*******************************************************************************/

/* Function to compute phi1, the latitude for the inverse of the
   Albers Conical Equal-Area projection.
-------------------------------------------*/
float phi1z(float eccent, float qs)
{
    float sinphi, cosphi, con, com, dphi;
    float phi = asinz(.5 * qs);
    if (eccent < EPSLN)
	return phi;

    float eccnts = eccent * eccent;
    for (int i = 1; i <= 25; i++) {
	sinphi = sin(phi);
	cosphi = cos(phi);
	con = eccent * sinphi;
	com = 1.0 - con * con;
	dphi =
	    .5 * com * com / cosphi * (qs / (1.0 - eccnts) - sinphi / com +
				       .5 / eccent * log((1.0 - con) /
							 (1.0 + con)));
	phi = phi + dphi;
	if (abs(dphi) <= 1e-7)
	    return phi;
    }
    return 0.;
}

vec2 aea_backwards(vec2 p, aea_params params)
{
    float rh1, qs, con, theta, lon, lat;

    p.x -= params.x0;
    p.y = params.rh - p.y + params.y0;
    if (params.ns0 >= 0.) {
	rh1 = sqrt(p.x * p.x + p.y * p.y);
	con = 1.0;
    } else {
	rh1 = -sqrt(p.x * p.x + p.y * p.y);
	con = -1.0;
    }
    theta = 0.0;
    if (rh1 != 0.0) {
	theta = atan(con * p.x, con * p.y);
    }
    con = rh1 * params.ns0 / params.a;
    qs = (params.c - con * con) / params.ns0;
    if (params.e3 >= 1e-10) {
	con =
	    1. - .5 * (1.0 -
		      params.es) * log((1.0 - params.e3) / (1.0 +
							    params.e3)) /
	    params.e3;
	if (abs(abs(con) - abs(qs)) > .0000000001) {
	    lat = phi1z(params.e3, qs);
	} else {
	    if (qs >= 0.) {
		lat = .5 * PI;
	    } else {
		lat = -.5 * PI;
	    }
	}
    } else {
	lat = phi1z(params.e3, qs);
    }

    lon = adjust_lon(theta / params.ns0 + params.long0);
    p.x = lon;
    p.y = lat;
    return p;
}


// vim:syntax=c:sw=4:sts=4:et
