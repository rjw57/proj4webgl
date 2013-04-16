float ssfn_(float phit, float sinphi, float eccen)
{
    sinphi *= eccen;
    return (tan(.5 * (HALF_PI + phit)) *
	    pow((1. - sinphi) / (1. + sinphi), .5 * eccen));
}

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
	A = 2. * params.k0 / (1.0 + params.sinlat0 * sinlat +
			     params.coslat0 * coslat * cos(dlon));
	p.x = params.a * A * coslat * sin(dlon) + params.x0;
	p.y =
	    params.a * A * (params.coslat0 * sinlat -
			    params.sinlat0 * coslat * cos(dlon)) +
	    params.y0;
	return p;
    } else {
	X = 2.0 * atan(ssfn_(lat, sinlat, params.e)) - HALF_PI;
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

// backwards, i.e. x, y -> lon, lat
vec2 stere_backwards(vec2 p, stere_params params)
{
	p.x-=params.x0;
	p.y-=params.y0;
	float lon, lat;
	float rh = sqrt(p.x*p.x + p.y*p.y);
	if (0 != params.sphere){
		float c=2.*atan(rh/(0.5*params.a*params.k0));
		lon=params.long0;
		lat=params.lat0;
		if (rh<=EPSLN){
			p.x=lon;
			p.y=lat;
			return p;
		}
		lat=asin(cos(c)*params.sinlat0+p.y*sin(c)*params.coslat0/rh);
		if (abs(params.coslat0)<EPSLN){
			if (params.lat0>0.0){
				lon=adjust_lon(params.long0+atan(p.x,-1.0*p.y));
			} else {
				lon=adjust_lon(params.long0+atan(p.x,p.y));
			}
		} else {
			lon=adjust_lon(params.long0+atan(p.x*sin(c),rh*params.coslat0*cos(c)-p.y*params.sinlat0*sin(c)));
		}
		p.x=lon;
		p.y=lat;
		return p;
				
	} else {
		if (abs(params.coslat0)<=EPSLN){
			if (rh<=EPSLN){
				lat=params.lat0;
				lon=params.long0;
				p.x=lon;
				p.y=lat;
				
				//trace(p.toString());
				return p;
			}
			p.x*=params.con;
			p.y*=params.con;

			float ts = rh*params.cons/(2.0*params.a*params.k0);
			lat=params.con*phi2z(params.e,ts);
			lon=params.con*adjust_lon(params.con*params.long0+atan(p.x,-1.0*p.y));
		} else {
			float ce = 2.0*atan(rh*params.cosX0/(2.0*params.a*params.k0*params.ms1));
			lon=params.long0;
			float Chi;
			if (rh<=EPSLN){
				Chi=params.X0;
			} else {
				Chi=asin(cos(ce)*params.sinX0+p.y*sin(ce)*params.cosX0/rh);
				lon=adjust_lon(params.long0+atan(p.x*sin(ce),rh*params.cosX0*cos(ce)-p.y*params.sinX0*sin(ce)));
			}
			lat=-1.0*phi2z(params.e,tan(0.5*(HALF_PI+Chi)));
			
		}
	}
	
			
	p.x=lon;
	p.y=lat;
		
	//trace(p.toString());
	return p;
}

// vim:syntax=c:sw=4:sts=4:et
