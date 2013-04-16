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

/* Lambert Azimuthal Equal Area forward equations--mapping lat,long to x,y
  -----------------------------------------------------------------------*/
vec2 laea_forwards(vec2 p, laea_params params)
{
    /* Forward equations
       ----------------- */
    float x, y;
    float lam = p.x;
    float phi = p.y;
    lam = adjust_lon(lam - params.long0);

    if (0 != params.sphere) {
	float coslam, cosphi, sinphi;

	sinphi = sin(phi);
	cosphi = cos(phi);
	coslam = cos(lam);
	if ((params.mode == OBLIQ) || (params.mode == EQUIT)) {
	    y = (params.mode ==
		 EQUIT) ? 1. + cosphi * coslam : 1. +
		params.sinph0 * sinphi + params.cosph0 * cosphi * coslam;
	    if (y <= EPSLN) {
		//Proj4js.reportError("laea:fwd:y less than eps");
		return vec2(0., 0.);
	    }
	    y = sqrt(2. / y);
	    x = y * cosphi * sin(lam);
	    y *= (params.mode ==
		  EQUIT) ? sinphi : params.cosph0 * sinphi -
		params.sinph0 * cosphi * coslam;
	} else if ((params.mode == N_POLE) || (params.mode == S_POLE)) {
	    if (params.mode == N_POLE) {
		coslam = -coslam;
	    }
	    if (abs(phi + params.phi0) < EPSLN) {
		// Proj4js.reportError("laea:fwd:phi < eps");
		return vec2(0., 0.);
	    }
	    y = FORTPI - phi * .5;
	    y = 2. * ((params.mode == S_POLE) ? cos(y) : sin(y));
	    x = y * sin(lam);
	    y *= coslam;
	}
    } else {
	float coslam, sinlam, sinphi, q, sinb = 0.0, cosb = 0.0, b = 0.0;

	coslam = cos(lam);
	sinlam = sin(lam);
	sinphi = sin(phi);
	q = qsfnz(params.e, sinphi);
	if (params.mode == OBLIQ || params.mode == EQUIT) {
	    sinb = q / params.qp;
	    cosb = sqrt(1. - sinb * sinb);
	}
	if (params.mode == OBLIQ) {
	    b = 1. + params.sinb1 * sinb + params.cosb1 * cosb * coslam;
	} else if (params.mode == EQUIT) {
	    b = 1. + cosb * coslam;
	} else if (params.mode == N_POLE) {
	    b = HALF_PI + phi;
	    q = params.qp - q;
	} else if (params.mode == S_POLE) {
	    b = phi - HALF_PI;
	    q = params.qp + q;
	}
	if (abs(b) < EPSLN) {
	    // Proj4js.reportError("laea:fwd:b < eps");
	    return vec2(0., 0.);
	}

	if ((params.mode == OBLIQ) || (params.mode == EQUIT)) {
	    b = sqrt(2. / b);
	    if (params.mode == OBLIQ) {
		y = params.ymf * b * (params.cosb1 * sinb -
				      params.sinb1 * cosb * coslam);
	    } else {
		y = (b =
		     sqrt(2. / (1. + cosb * coslam))) * sinb * params.ymf;
	    }
	    x = params.xmf * b * cosb * sinlam;
	} else if ((params.mode == N_POLE) || (params.mode == S_POLE)) {
	    if (q >= 0.) {
		x = (b = sqrt(q)) * sinlam;
		y = coslam * ((params.mode == S_POLE) ? b : -b);
	    } else {
		x = y = 0.;
	    }
	}
    }

    p.x = params.a * x + params.x0;
    p.y = params.a * y + params.y0;
    return p;
}				//lamazFwd()

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
