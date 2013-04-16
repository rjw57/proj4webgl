  /**
    Transverse Mercator Forward  - long/lat to x/y
    long/lat in radians
  */
vec2 tmerc_forwards(vec2 p, tmerc_params params)
{
    float lon = p.x;
    float lat = p.y;

    float delta_lon = adjust_lon(lon - params.long0);	// Delta longitude
    float con;			// cone constant
    float x, y;
    float sin_phi = sin(lat);
    float cos_phi = cos(lat);

    if (0 != params.sphere) {	/* spherical form */
	float b = cos_phi * sin(delta_lon);
	if ((abs(abs(b) - 1.0)) < .0000000001) {
	    //Proj4js.reportError("tmerc:forward: Point projects into infinity");
	    return vec2(0., 0.);
	} else {
	    x = .5 * params.a * params.k0 * log((1.0 + b) / (1.0 - b));
	    con = acos(cos_phi * cos(delta_lon) / sqrt(1.0 - b * b));
	    if (lat < 0.)
		con = -con;
	    y = params.a * params.k0 * (con - params.lat0);
	}
    } else {
	float al = cos_phi * delta_lon;
	float als = pow(al,2.0);
	float c = params.ep2 * pow(cos_phi,2.0);
	float tq = tan(lat);
	float t = pow(tq,2.0);
	con = 1.0 - params.es * pow(sin_phi,2.0);
	float n = params.a / sqrt(con);
	float ml =
	    params.a * mlfn(params.e0, params.e1, params.e2, params.e3,
			    lat);

	x = params.k0 * n * al * (1.0 +
				  als / 6.0 * (1.0 - t + c +
					       als / 20.0 * (5.0 -
							     18.0 * t +
							     pow(t,
								2.0) +
							     72.0 * c -
							     58.0 *
							     params.
							     ep2))) +
	    params.x0;
	y = params.k0 * (ml - params.ml0 +
			 n * tq * (als *
				   (0.5 +
				    als / 24.0 * (5.0 - t + 9.0 * c +
						  4.0 * pow(c,
							   2.0) +
						  als / 30.0 * (61.0 -
								58.0 * t +
								pow(t,
								   2.0) +
								600.0 * c -
								330.0 *
								params.ep2)))))
	    + params.y0;

    }

    p.x = x;
    p.y = y;
    return p;
}

// backwards, i.e. x, y -> lon, lat
vec2 tmerc_backwards(vec2 p, tmerc_params params)
{
    float lon = p.x, lat = p.y;
    float con, phi;		/* temporary angles       */
    float delta_phi;		/* difference between longitudes    */
    const int max_iter = 6;	/* maximun number of iterations */

    if (params.sphere != 0) {	/* spherical form */
	float f = exp(p.x / (params.a * params.k0));
	float g = .5 * (f - 1. / f);
	float temp = params.lat0 + p.y / (params.a * params.k0);
	float h = cos(temp);
	con = sqrt((1.0 - h * h) / (1.0 + g * g));
	lat = asinz(con);
	if (temp < 0.)
	    lat = -lat;
	if ((g == 0.) && (h == 0.)) {
	    lon = params.long0;
	} else {
	    lon = adjust_lon(atan(g, h) + params.long0);
	}
    } else {			// ellipsoidal form
	float x = p.x - params.x0;
	float y = p.y - params.y0;

	con = (params.ml0 + y / params.k0) / params.a;
	phi = con;
	for (int i = 0; i <= max_iter; i++) {
	    delta_phi =
		((con + params.e1 * sin(2.0 * phi) -
		  params.e2 * sin(4.0 * phi) +
		  params.e3 * sin(6.0 * phi)) / params.e0) - phi;
	    phi += delta_phi;
	    if (abs(delta_phi) <= EPSLN)
		break;
	    if (i >= max_iter) {
		return vec2(0., 0.);
	    }
	}			// for()
	if (abs(phi) < HALF_PI) {
	    // sincos(phi, &sin_phi, &cos_phi);
	    float sin_phi = sin(phi);
	    float cos_phi = cos(phi);
	    float tan_phi = tan(phi);
	    float c = params.ep2 * pow(cos_phi, 2.);
	    float cs = pow(c, 2.);
	    float t = pow(tan_phi, 2.);
	    float ts = pow(t, 2.);
	    con = 1.0 - params.es * pow(sin_phi, 2.);
	    float n = params.a / sqrt(con);
	    float r = n * (1.0 - params.es) / con;
	    float d = x / (n * params.k0);
	    float ds = pow(d, 2.);
	    lat =
		phi - (n * tan_phi * ds / r) * (0.5 -
						ds / 24.0 * (5.0 +
							     3.0 * t +
							     10.0 * c -
							     4.0 * cs -
							     9.0 *
							     params.ep2 -
							     ds / 30.0 *
							     (61.0 +
							      90.0 * t +
							      298.0 * c +
							      45.0 * ts -
							      252.0 *
							      params.ep2 -
							      3.0 * cs)));
	    lon =
		adjust_lon(params.long0 +
			   (d *
			    (1.0 -
			     ds / 6.0 * (1.0 + 2.0 * t + c -
					 ds / 20.0 * (5.0 - 2.0 * c +
						      28.0 * t - 3.0 * cs +
						      8.0 * params.ep2 +
						      24.0 * ts))) /
			    cos_phi));
	} else {
	    lat = HALF_PI * sign(y);
	    lon = params.long0;
	}
    }
    p.x = lon;
    p.y = lat;
    return p;
}

// vim:syntax=c:sw=4:sts=4:et
