// constants
#define  TOL	1.e-8
#define  NITER	8
#define  CONV	1.e-10
#define  S_POLE	0
#define  N_POLE	1
#define  OBLIQ	2
#define  EQUIT	3

// Stereographic forward equations--mapping lat,long to x,y
vec2 stere_forwards(vec2 p, stere_params params)
{
    float lon = p.x;
    float lat = p.y;
    float sinlat = sin(lat);
    float coslat = cos(lat);
    float x, y, A, X, sinX, cosX;
    float dlon = adjust_lon(lon - params.long0);

    if (abs(abs(lon - params.long0) - PI) <= EPSLN
	&& abs(lat + params.lat0) <= EPSLN) {
	//case of the origine point
	//trace('stere:params.is the origin point');
	//p.x=NaN;
	//p.y=NaN;
	return vec2(0., 0.);
    }

    if (0 != params.sphere) {
	//trace('stere:sphere case');
	A = 2 * params.k0 / (1.0 + params.sinlat0 * sinlat +
			     params.coslat0 * coslat * cos(dlon));
	p.x = params.a * A * coslat * sin(dlon) + params.x0;
	p.y =
	    params.a * A * (params.coslat0 * sinlat -
			    params.sinlat0 * coslat * cos(dlon)) +
	    params.y0;
	return p;
    } else {
	X = 2.0 * atan(params.ssfn_(lat, sinlat, params.e)) - HALF_PI;
	cosX = cos(X);
	sinX = sin(X);
	if (abs(params.coslat0) <= EPSLN) {
	    float ts =
		tsfnz(params.e, lat * params.con, params.con * sinlat);
	    float rh = 2.0 * params.a * params.k0 * ts / params.cons;

	    p.x = params.x0 + rh * sin(lon - params.long0);
	    p.y = params.y0 - params.con * rh * cos(lon - params.long0);
	    //trace(p.toString());
	    return p;
	} else if (abs(params.sinlat0) < EPSLN) {
	    //Eq
	    //trace('stere:equateur');
	    A = 2.0 * params.a * params.k0 / (1.0 + cosX * cos(dlon));
	    p.y = A * sinX;
	} else {
	    //other case
	    //trace('stere:normal case');
	    A = 2.0 * params.a * params.k0 * params.ms1 / (params.cosX0 *
							   (1.0 +
							    params.sinX0 *
							    sinX +
							    params.cosX0 *
							    cosX *
							    cos(dlon)));
	    p.y =
		A * (params.cosX0 * sinX -
		     params.sinX0 * cosX * cos(dlon)) + params.y0;
	}
	p.x = A * cosX * sin(dlon) + params.x0;

    }

    //trace(p.toString());
    return p;
}

,
// backwards, i.e. x, y -> lon, lat
    vec2 stere_backwards(vec2 p, stere_params params)
{
    float x = (p.x - params.x0) / params.a;	/* descale and de-offset */
    float y = (p.y - params.y0) / params.a;
    float lon, lat;

    float cosphi, sinphi, tp = 0.0, phi_l = 0.0, rho, halfe = 0.0, pi2 =
	0.0;
    float i;

    if (0 != params.sphere) {
	float c, rh, sinc, cosc;

	rh = sqrt(x * x + y * y);
	c = 2. * atan(rh / params.akm1);
	sinc = sin(c);
	cosc = cos(c);
	lon = 0.;
	if (params.mode == EQUIT) {
	    if (abs(rh) <= EPSLN) {
		lat = 0.;
	    } else {
		lat = asin(y * sinc / rh);
	    }
	    if (cosc != 0. || x != 0.)
		lon = atan(x * sinc, cosc * rh);
	} else if (params.mode == OBLIQ) {
	    if (abs(rh) <= EPSLN) {
		lat = params.phi0;
	    } else {
		lat =
		    asin(cosc * params.sinph0 +
			 y * sinc * params.cosph0 / rh);
	    }
	    c = cosc - params.sinph0 * sin(lat);
	    if (c != 0. || x != 0.) {
		lon = atan(x * sinc * params.cosph0, c * rh);
	    }
	} else if (params.mode == N_POLE) {
	    y = -y;
	    if (abs(rh) <= EPSLN) {
		lat = params.phi0;
	    } else {
		lat = asin(params.mode == S_POLE ? -cosc : cosc);
	    }
	    if ((x == 0.) && (y == 0.)) {
		lon = 0.;
	    } else {
		lon = atan(x, y);
	    }
	} else if (params.mode == S_POLE) {
	    if (abs(rh) <= EPSLN) {
		lat = params.phi0;
	    } else {
		lat = asin(params.mode == S_POLE ? -cosc : cosc);
	    }
	    lon = (x == 0. && y == 0.) ? 0. : atan(x, y);
	}
	p.x = adjust_lon(lon + params.long0);
	p.y = lat;
    } else {
	rho = sqrt(x * x + y * y);
	if ((params.mode == OBLIQ) || (params.mode == EQUIT)) {
	    tp = 2. * atan(rho * params.cosX1, params.akm1);
	    cosphi = cos(tp);
	    sinphi = sin(tp);
	    if (rho == 0.0) {
		phi_l = asin(cosphi * params.sinX1);
	    } else {
		phi_l =
		    asin(cosphi * params.sinX1 +
			 (y * sinphi * params.cosX1 / rho));
	    }

	    tp = tan(.5 * (HALF_PI + phi_l));
	    x *= sinphi;
	    y = rho * params.cosX1 * cosphi - y * params.sinX1 * sinphi;
	    pi2 = HALF_PI;
	    halfe = .5 * params.e;
	} else if ((params.mode == N_POLE) || (params.mode == S_POLE)) {
	    if (params.mode == N_POLE) {
		y = -y;
	    }
	    tp = -rho / params.akm1;
	    phi_l = HALF_PI - 2. * atan(tp);
	    pi2 = -HALF_PI;
	    halfe = -.5 * params.e;
	}
	for (int i = 0; i < NITER; i++) {
	    phi_l = lat;
	    sinphi = params.e * sin(phi_l);
	    lat =
		2. * atan(tp * pow((1. + sinphi) / (1. - sinphi), halfe)) -
		pi2;
	    if (abs(phi_l - lat) < CONV) {
		if (params.mode == S_POLE)
		    lat = -lat;
		lon = (x == 0. && y == 0.) ? 0. : atan(x, y);
		p.x = adjust_lon(lon + params.long0);
		p.y = lat;
		return p;
	    }
	}
    }
}

// vim:syntax=c:sw=4:sts=4:et
