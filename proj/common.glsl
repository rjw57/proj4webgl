// constants
#define HALF_PI     1.5707963267948966
#define PI          3.141592653589793
#define TWO_PI      6.283185307179586
#define EPSLN       1e-10

// utility functions
float asinz(float x)
{
    if (abs(x) > 1.0) {
	x = (x > 1.0) ? 1.0 : -1.0;
    }
    return asin(x);
}

float adjust_lon(float x)
{
    x = (abs(x) < PI) ? x : (x - (sign(x) * TWO_PI));
    return x;
}

float adjust_lat(float x) {
    x = (abs(x) < HALF_PI) ? x: (x - (sign(x)*PI) );
    return x;
}

// Function to compute the latitude angle, phi2, for the inverse of the
//   Lambert Conformal Conic and Polar Stereographic projections.
// ----------------------------------------------------------------
float phi2z(float eccent, float ts)
{
    float eccnth = .5 * eccent;
    float con, dphi;
    float phi = HALF_PI - 2. * atan(ts);

    for (int i = 0; i <= 15; i++) {
	con = eccent * sin(phi);
	dphi =
	    HALF_PI -
	    2. * atan(ts *
		     (pow(((1.0 - con) / (1.0 + con)), eccnth))) -
	    phi;
	phi += dphi;
	if (abs(dphi) <= .0000000001)
	    return phi;
    }

    return (-9999.);
}

// vim:syntax=c:sw=4:sts=4:et
