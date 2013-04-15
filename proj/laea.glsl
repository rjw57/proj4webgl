/*******************************************************************************
NAME                  LAMBERT AZIMUTHAL EQUAL-AREA
 
PURPOSE:	Transforms input longitude and latitude to Easting and
		Northing for the Lambert Azimuthal Equal-Area projection.  The
		longitude and latitude must be in radians.  The Easting
		and Northing values will be returned in meters.

PROGRAMMER              DATE            
----------              ----           
D. Steinwand, EROS      March, 1991   

This function was adapted from the Lambert Azimuthal Equal Area projection
code (FORTRAN) in the General Cartographic Transformation Package software
which is available from the U.S. Geological Survey National Mapping Division.
 
ALGORITHM REFERENCES

1.  "New Equal-Area Map Projections for Noncircular Regions", John P. Snyder,
    The American Cartographer, Vol 15, No. 4, October 1988, pp. 341-355.

2.  Snyder, John P., "Map Projections--A Working Manual", U.S. Geological
    Survey Professional Paper 1395 (Supersedes USGS Bulletin 1532), United
    State Government Printing Office, Washington D.C., 1987.

3.  "Software Documentation for GCTP General Cartographic Transformation
    Package", U.S. Geological Survey National Mapping Division, May 1982.
*******************************************************************************/

#define S_POLE 1
#define N_POLE 2
#define EQUIT  3
#define OBLIQ  4

float authlat(float beta, float APA[3])
{
    float t = beta + beta;
    return (beta + APA[0] * sin(t) + APA[1] * sin(t + t) +
	    APA[2] * sin(t + t + t));
}

// backwards, i.e. x, y -> lon, lat
vec2 laea_backwards(vec2 p, laea_params params)
{
    p.x -= params.x0;
    p.y -= params.y0;
    float x = p.x / params.a;
    float y = p.y / params.a;
    float lam, phi;

    if (0 != params.sphere) {
	float cosz = 0.0, rh, sinz = 0.0;

	rh = sqrt(x * x + y * y);
	phi = rh * .5;
	if (phi > 1.) {
	    return vec2(0., 0.);
	}
	phi = 2. * asin(phi);
	if (params.mode == OBLIQ || params.mode == EQUIT) {
	    sinz = sin(phi);
	    cosz = cos(phi);
	}

	if (params.mode == EQUIT) {
	    phi = (abs(rh) <= EPSLN) ? 0. : asin(y * sinz / rh);
	    x *= sinz;
	    y = cosz * rh;
	} else if (params.mode == OBLIQ) {
	    phi =
		(abs(rh) <=
		 EPSLN) ? params.phi0 : asin(cosz *
					     params.sinph0
					     +
					     y * sinz *
					     params.cosph0 / rh);
	    x *= sinz * params.cosph0;
	    y = (cosz - sin(phi) * params.sinph0) * rh;
	} else if (params.mode == N_POLE) {
	    y = -y;
	    phi = HALF_PI - phi;
	} else if (params.mode == S_POLE) {
	    phi -= HALF_PI;
	}
	lam = (y == 0.
	       && (params.mode == EQUIT
		   || params.mode == OBLIQ)) ? 0. : atan(x, y);
    } else {
	float cCe, sCe, q, rho, ab = 0.0;

	if ((params.mode == EQUIT) || (params.mode == OBLIQ)) {
	    x /= params.dd;
	    y *= params.dd;
	    rho = sqrt(x * x + y * y);
	    if (rho < EPSLN) {
		p.x = 0.;
		p.y = params.phi0;
		return p;
	    }
	    sCe = 2. * asin(.5 * rho / params.rq);
	    cCe = cos(sCe);
	    x *= (sCe = sin(sCe));
	    if (params.mode == OBLIQ) {
		ab = cCe * params.sinb1 + y * sCe * params.cosb1 / rho;
		q = params.qp * ab;
		y = rho * params.cosb1 * cCe - y * params.sinb1 * sCe;
	    } else {
		ab = y * sCe / rho;
		q = params.qp * ab;
		y = rho * cCe;
	    }
	} else if ((params.mode == N_POLE) || (params.mode == S_POLE)) {
	    if (params.mode == N_POLE) {
		y = -y;
	    }
	    q = (x * x + y * y);
	    if (q < EPSLN) {
		p.x = 0.;
		p.y = params.phi0;
		return p;
	    }
	    /*
	       q = params.qp - q;
	     */
	    ab = 1. - q / params.qp;
	    if (params.mode == S_POLE) {
		ab = -ab;
	    }
	}
	lam = atan(x, y);
	phi = authlat(asin(ab), params.apa);
    }

    p.x = adjust_lon(params.long0 + lam);
    p.y = phi;
    return p;
}

// vim:syntax=c:sw=4:sts=4:et
