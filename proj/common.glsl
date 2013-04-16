// constants
#define HALF_PI     1.5707963267948966
#define PI          3.141592653589793
#define TWO_PI      6.283185307179586
#define EPSLN       1e-10
#define FORTPI      0.78539816339744833
#define R2D         57.29577951308232088
#define D2R         0.01745329251994329577
#define SEC_TO_RAD  4.84813681109535993589914102357e-6 /* SEC_TO_RAD = Pi/180/3600 */
#define MAX_ITER    20
#define COS_67P5    0.38268343236508977  /* cosine of 67.5 degrees */
#define AD_C        1.0026000                /* Toms region 1 constant */

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

// Function to compute the constant small t for use in the forward
//   computations in the Lambert Conformal Conic and the Polar
//   Stereographic projections.
// -----------------------------------------------------------------
float tsfnz(float eccent, float phi, float sinphi)
{
    float con = eccent * sinphi;
    float com = .5 * eccent;
    con = pow(((1.0 - con) / (1.0 + con)), com);
    return (tan(.5 * (HALF_PI - phi))/con);
}

float mlfn(float e0, float e1, float e2, float e3, float phi) {
    return(e0*phi-e1*sin(2.0*phi)+e2*sin(4.0*phi)-e3*sin(6.0*phi));
}

// vim:syntax=c:sw=4:sts=4:et
